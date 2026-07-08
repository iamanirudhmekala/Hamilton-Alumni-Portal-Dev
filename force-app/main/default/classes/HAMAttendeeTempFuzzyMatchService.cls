/**
 * HAMAttendeeTempFuzzyMatchService
 * ---------------------------------------------------------------------------
 * Invocable Apex service called from the Record-Triggered Flow
 * HAM_Cvent_Attendee_Temp_Constituent_Match when a new Attendee Temp record
 * is created with no pre-matched constituent.
 *
 * Matching logic
 * --------------
 * 1. Name search  -> ucinn_ascendv2__Contact_Name__c
 *    Requires BOTH CventEvents__pkg_FirstName__c AND CventEvents__pkg_LastName__c
 *    to match against ucinn_ascendv2__Constructed_Name_Formula__c via SOSL.
 *    A partial match on only first name or only last name is discarded
 *    (e.g. "John" or "Smith" alone would produce too many false positives).
 *
 * 2. Email search -> ucinn_ascendv2__Email__c
 *    Exact match on ucinn_ascendv2__Email_Address__c.
 *
 * 3. Decision
 *    - Both IDs match  -> populate HAM_Matching_Constituent__c
 *    - Only one found  -> populate HAM_Suggested_Constituent__c
 *    - Neither found   -> no update
 *
 * 4. Event match -> CventEvents__Event__c
 *    CventEvents__pkg_EventStub__c on the Attendee Temp is a guaranteed 1:1
 *    match against CventEvents__pkg_EventStub__c on CventEvents__Event__c.
 *    Unlike the constituent matches, this is a direct key match with no
 *    confidence tiers, so the resolved Event Id is always returned when a
 *    stub value is present and a corresponding Event record exists.
 *    The Flow is expected to write this onto the new Attendee Temp lookup
 *    field to CventEvents__Event__c (assumed API name below: HAM_Event__c —
 *    update EVENT_LOOKUP_FIELD_NAME_NOTE if the actual field name differs).
 *
 * Version history
 * ---------------
 * v1.0  2026-05-04  Initial build for ASC-13380
 * v1.1  2026-05-04  Name match now requires both first AND last name tokens
 * v1.2  2026-05-04  Guard empty tempIds; expose evaluateMatch as @TestVisible
 * v1.3  2026-05-04  Extract processTemps as @TestVisible to cover the
 *                   tempMap loop without requiring the Cvent package
 * v1.4  2026-05-05  Fix object API name: CventEvents__AttendeeTemp__c
 *                   (was CventEvents__pkg_Attendee_Temp__c)
 * v1.5  2026-05-18  BULK FIX (ASC-XXXXX): Hoist SOSL out of per-record loop.
 *                   findConstituentByName() replaced by bulk counterparts:
 *                   buildNameSearchTerms() + findConstituentsByNameBulk().
 *                   Eliminates "Too many SOSL queries: 21" governor error.
 *                   Add safeGet() helper to guard SObjectException when
 *                   processTemps() receives a stand-in SObject in test context.
 * v1.6  2026-07-07  Add Event resolution: pull CventEvents__pkg_EventStub__c
 *                   from the Attendee Temp query, bulk-match it against
 *                   CventEvents__Event__c.CventEvents__pkg_EventStub__c (one
 *                   SOQL for the whole batch), and surface the resolved
 *                   Event Id via a new MatchResult.matchingEventId output so
 *                   the calling Flow can populate the Attendee Temp's Event
 *                   lookup field. No confidence tiers here — stub match is
 *                   always exact/1:1, so there's no "suggested" state.
 * ---------------------------------------------------------------------------
 */
public with sharing class HAMAttendeeTempFuzzyMatchService {

    // NOTE: Update this if the actual API name of the new lookup field on
    // the Attendee Temp object differs. This constant is documentation only —
    // the Flow (not this class) performs the actual field write, since the
    // existing architecture has this Invocable service return Ids and lets
    // the Flow handle DML on the Attendee Temp record.
    @TestVisible
    private static final String EVENT_LOOKUP_FIELD_NAME_NOTE = 'HAM_Event__c';

    // -------------------------------------------------------------------------
    // Inner classes
    // -------------------------------------------------------------------------

    public class MatchRequest {
        @InvocableVariable(label='Attendee Temp Record Id' required=true)
        public Id attendeeTempId;
    }

    public class MatchResult {
        @InvocableVariable(label='Matching Constituent Id')
        public Id matchingConstituentId;

        @InvocableVariable(label='Suggested Constituent Id')
        public Id suggestedConstituentId;

        @InvocableVariable(label='Match Status')
        public String matchStatus; // CONFIRMED | SUGGESTED_NAME | SUGGESTED_EMAIL | NO_MATCH

        @InvocableVariable(label='Matching Event Id')
        public Id matchingEventId;
    }

    // -------------------------------------------------------------------------
    // Invocable entry point
    // -------------------------------------------------------------------------

    @InvocableMethod(
        label='HAM - Match Attendee Temp to Constituent'
        description='Performs name and email matching to find a constituent for a Cvent Attendee Temp record, and resolves the related Event via EventStub. Called from HAM_Cvent_Attendee_Temp_Constituent_Match flow.'
        category='HAM Cvent'
    )
    public static List<MatchResult> matchAttendeeTemps(List<MatchRequest> requests) {
        List<MatchResult> results = new List<MatchResult>();

        // Collect non-null IDs
        Set<Id> tempIds = new Set<Id>();
        for (MatchRequest req : requests) {
            if (req.attendeeTempId != null) {
                tempIds.add(req.attendeeTempId);
            }
        }

        // Guard: if all IDs were null skip the Cvent package query entirely
        if (tempIds.isEmpty()) {
            for (MatchRequest req : requests) {
                MatchResult result = new MatchResult();
                result.matchStatus = 'NO_MATCH';
                results.add(result);
            }
            return results;
        }

        Map<Id, SObject> tempMap = new Map<Id, SObject>(
            Database.query(buildAttendeeTempQuery(tempIds))
        );

        return processTemps(requests, tempMap);
    }

    // -------------------------------------------------------------------------
    // processTemps — bulk-safe: ONE SOSL + ONE Event SOQL for entire batch
    // -------------------------------------------------------------------------

    /**
     * Processes the tempMap loop after the Cvent query.
     * Extracted as @TestVisible so tests can inject a mock SObject map
     * (using Contact records as stand-in) to cover this branch without
     * needing the CventEvents package installed.
     *
     * Field reads use safeGet() so that stand-in SObject types in test context
     * do not throw SObjectException for missing Cvent package fields.
     */
    @TestVisible
    private static List<MatchResult> processTemps(
        List<MatchRequest> requests,
        Map<Id, SObject>   tempMap
    ) {
        // ── 1. Extract name/email/eventStub data for every request in the batch ──
        Map<String, Id> nameKeyToTempId   = new Map<String, Id>();
        Set<String>     allEmails         = new Set<String>();
        Set<String>     allEventStubs     = new Set<String>();

        Map<Id, String> tempIdToFirstName  = new Map<Id, String>();
        Map<Id, String> tempIdToLastName   = new Map<Id, String>();
        Map<Id, String> tempIdToEmail      = new Map<Id, String>();
        Map<Id, String> tempIdToEventStub  = new Map<Id, String>();

        for (MatchRequest req : requests) {
            if (req.attendeeTempId == null || !tempMap.containsKey(req.attendeeTempId)) {
                continue;
            }
            SObject tempRec = tempMap.get(req.attendeeTempId);

            // safeGet guards against SObjectException when a stand-in SObject
            // type (e.g. Contact in test context) lacks the Cvent package fields.
            String firstName = safeGet(tempRec, 'CventEvents__pkg_FirstName__c');
            String lastName  = safeGet(tempRec, 'CventEvents__pkg_LastName__c');
            String emailAddr = safeGet(tempRec, 'CventEvents__pkg_Email__c');
            String eventStub = safeGet(tempRec, 'CventEvents__pkg_EventStub__c');

            tempIdToFirstName.put(req.attendeeTempId, firstName);
            tempIdToLastName.put(req.attendeeTempId,  lastName);
            tempIdToEmail.put(req.attendeeTempId,     emailAddr);
            tempIdToEventStub.put(req.attendeeTempId, eventStub);

            if (String.isNotBlank(firstName) && String.isNotBlank(lastName)) {
                String nameKey = lastName.trim().toLowerCase() + '|' + firstName.trim().toLowerCase();
                nameKeyToTempId.put(nameKey, req.attendeeTempId);
            }
            if (String.isNotBlank(emailAddr)) {
                allEmails.add(emailAddr.trim());
            }
            if (String.isNotBlank(eventStub)) {
                allEventStubs.add(eventStub.trim());
            }
        }

        // ── 2. ONE bulk SOSL for all names in the batch ───────────────────
        Map<String, Id> nameKeyToConstituentId = findConstituentsByNameBulk(nameKeyToTempId.keySet());

        // ── 3. ONE bulk SOQL for all emails in the batch ─────────────────
        Map<String, Id> emailToConstituentId = findConstituentsByEmailBulk(allEmails);

        // ── 4. ONE bulk SOQL for all event stubs in the batch ────────────
        Map<String, Id> eventStubToEventId = findEventsByStubBulk(allEventStubs);

        // ── 5. Apply decision rules per request ───────────────────────────
        List<MatchResult> results = new List<MatchResult>();

        for (MatchRequest req : requests) {
            MatchResult result = new MatchResult();
            result.matchStatus = 'NO_MATCH';

            if (req.attendeeTempId == null || !tempMap.containsKey(req.attendeeTempId)) {
                results.add(result);
                continue;
            }

            String firstName = tempIdToFirstName.get(req.attendeeTempId);
            String lastName  = tempIdToLastName.get(req.attendeeTempId);
            String emailAddr = tempIdToEmail.get(req.attendeeTempId);
            String eventStub = tempIdToEventStub.get(req.attendeeTempId);

            Id nameConstId  = null;
            Id emailConstId = null;

            if (String.isNotBlank(firstName) && String.isNotBlank(lastName)) {
                String nameKey = lastName.trim().toLowerCase() + '|' + firstName.trim().toLowerCase();
                nameConstId = nameKeyToConstituentId.get(nameKey);
            }
            if (String.isNotBlank(emailAddr)) {
                emailConstId = emailToConstituentId.get(emailAddr.trim());
            }

            result = buildMatchResult(nameConstId, emailConstId);

            if (String.isNotBlank(eventStub)) {
                result.matchingEventId = eventStubToEventId.get(eventStub.trim());
            }

            results.add(result);
        }

        return results;
    }

    /**
     * @TestVisible overload for processTemps used in unit tests.
     * Accepts explicit firstName/lastName/email/eventStub values so tests
     * don't need to pass a mock SObject map with Cvent package fields.
     */
    @TestVisible
    private static List<MatchResult> processTemps(
        List<MatchRequest> requests,
        Id                 mockRecordId,
        String             firstName,
        String             lastName,
        String             emailAddr,
        String             eventStub
    ) {
        List<MatchResult> results = new List<MatchResult>();

        Map<String, Id> nameKeyToConstituentId = new Map<String, Id>();
        Map<String, Id> emailToConstituentId   = new Map<String, Id>();
        Map<String, Id> eventStubToEventId     = new Map<String, Id>();

        if (String.isNotBlank(firstName) && String.isNotBlank(lastName)) {
            Set<String> nameKeys = new Set<String>{
                lastName.trim().toLowerCase() + '|' + firstName.trim().toLowerCase()
            };
            nameKeyToConstituentId = findConstituentsByNameBulk(nameKeys);
        }
        if (String.isNotBlank(emailAddr)) {
            emailToConstituentId = findConstituentsByEmailBulk(
                new Set<String>{ emailAddr.trim() }
            );
        }
        if (String.isNotBlank(eventStub)) {
            eventStubToEventId = findEventsByStubBulk(
                new Set<String>{ eventStub.trim() }
            );
        }

        for (MatchRequest req : requests) {
            MatchResult result = new MatchResult();
            result.matchStatus = 'NO_MATCH';

            if (req.attendeeTempId == null || req.attendeeTempId != mockRecordId) {
                results.add(result);
                continue;
            }

            Id nameConstId  = null;
            Id emailConstId = null;

            if (String.isNotBlank(firstName) && String.isNotBlank(lastName)) {
                String nameKey = lastName.trim().toLowerCase() + '|' + firstName.trim().toLowerCase();
                nameConstId = nameKeyToConstituentId.get(nameKey);
            }
            if (String.isNotBlank(emailAddr)) {
                emailConstId = emailToConstituentId.get(emailAddr.trim());
            }

            result = buildMatchResult(nameConstId, emailConstId);

            if (String.isNotBlank(eventStub)) {
                result.matchingEventId = eventStubToEventId.get(eventStub.trim());
            }

            results.add(result);
        }

        return results;
    }

    /**
     * Backwards-compatible 4-arg overload (no eventStub) retained in case any
     * existing test callers still invoke processTemps with the pre-v1.6
     * signature. Delegates to the 5-arg version with a null eventStub.
     */
    @TestVisible
    private static List<MatchResult> processTemps(
        List<MatchRequest> requests,
        Id                 mockRecordId,
        String             firstName,
        String             lastName,
        String             emailAddr
    ) {
        return processTemps(requests, mockRecordId, firstName, lastName, emailAddr, null);
    }

    // -------------------------------------------------------------------------
    // evaluateMatch — kept @TestVisible for existing unit tests that call it
    // directly. Delegates to the single-record helpers then buildMatchResult.
    // -------------------------------------------------------------------------

    @TestVisible
    private static MatchResult evaluateMatch(String firstName, String lastName, String emailAddr) {
        Id nameConstId  = findConstituentByName(firstName, lastName);
        Id emailConstId = findConstituentByEmail(emailAddr);
        return buildMatchResult(nameConstId, emailConstId);
    }

    /**
     * Pure decision logic — no DML/SOSL/SOQL. Called by both the bulk
     * processTemps path and the single-record evaluateMatch test helper.
     * Note: Event matching is intentionally NOT part of this decision logic —
     * it's a direct 1:1 stub match with no confidence tiers, so it's applied
     * separately in processTemps() rather than folded into this method.
     */
    @TestVisible
    private static MatchResult buildMatchResult(Id nameConstId, Id emailConstId) {
        MatchResult result = new MatchResult();
        result.matchStatus = 'NO_MATCH';

        if (nameConstId != null && emailConstId != null && nameConstId == emailConstId) {
            result.matchingConstituentId = nameConstId;
            result.matchStatus = 'CONFIRMED';

        } else if (nameConstId != null && emailConstId == null) {
            result.suggestedConstituentId = nameConstId;
            result.matchStatus = 'SUGGESTED_NAME';

        } else if (emailConstId != null && nameConstId == null) {
            result.suggestedConstituentId = emailConstId;
            result.matchStatus = 'SUGGESTED_EMAIL';

        } else if (nameConstId != null && emailConstId != null && nameConstId != emailConstId) {
            result.suggestedConstituentId = nameConstId;
            result.matchStatus = 'SUGGESTED_NAME';
        }

        return result;
    }

    // -------------------------------------------------------------------------
    // Bulk helpers (name/email from v1.5, event stub added in v1.6)
    // -------------------------------------------------------------------------

    /**
     * Fires ONE SOSL for all name keys in the batch.
     * nameKeys format: "lastname|firstname" (lower-case).
     * Returns a map of the same key format -> constituent Id.
     *
     * In test context seed with Test.setFixedSearchResults() before calling.
     */
    @TestVisible
    private static Map<String, Id> findConstituentsByNameBulk(Set<String> nameKeys) {
        Map<String, Id> result = new Map<String, Id>();

        if (nameKeys == null || nameKeys.isEmpty()) {
            return result;
        }

        // Build one SOSL combining every "lastname firstname" term with OR
        List<String> soslTerms = new List<String>();
        for (String nameKey : nameKeys) {
            // nameKey = "lastname|firstname" — convert back to "lastname firstname"
            String term = escapeSosl(nameKey.replace('|', ' '));
            soslTerms.add('"' + term + '"'); // quoted phrase for tighter match
        }
        String combinedTerms = String.join(soslTerms, ' OR ');

        String soslQuery =
            'FIND {' + combinedTerms + '} '
          + 'IN ALL FIELDS '
          + 'RETURNING ucinn_ascendv2__Contact_Name__c('
          +     'Id, '
          +     'ucinn_ascendv2__Constructed_Name_Formula__c, '
          +     'ucinn_ascendv2__Contact__c '
          +     'WHERE ucinn_ascendv2__Contact__c != null'
          + ') '
          + 'LIMIT 200';

        List<List<SObject>> soslResults = Search.query(soslQuery); // ← THE ONE SOSL

        if (soslResults == null || soslResults.isEmpty() || soslResults[0].isEmpty()) {
            return result;
        }

        // Post-filter: ensure both tokens appear in Constructed_Name_Formula__c,
        // then map back to the correct nameKey
        for (SObject nameRec : soslResults[0]) {
            String constructedName = ((String) nameRec.get('ucinn_ascendv2__Constructed_Name_Formula__c') ?? '').toLowerCase();
            Id     constituentId   = (Id) nameRec.get('ucinn_ascendv2__Contact__c');

            for (String nameKey : nameKeys) {
                if (result.containsKey(nameKey)) {
                    continue; // already matched this key — keep first hit
                }
                String[] parts     = nameKey.split('\\|');
                String   lowerLast  = parts[0];
                String   lowerFirst = parts.size() > 1 ? parts[1] : '';

                if (constructedName.contains(lowerLast) && constructedName.contains(lowerFirst)) {
                    result.put(nameKey, constituentId);
                }
            }
        }

        return result;
    }

    /**
     * Bulk SOQL email lookup — single query with IN clause.
     * Returns map: email (trimmed, original case) -> constituent Id.
     */
    @TestVisible
    private static Map<String, Id> findConstituentsByEmailBulk(Set<String> emails) {
        Map<String, Id> result = new Map<String, Id>();

        if (emails == null || emails.isEmpty()) {
            return result;
        }

        for (ucinn_ascendv2__Email__c emailRec : [
            SELECT ucinn_ascendv2__Email_Address__c,
                   ucinn_ascendv2__Contact__c
            FROM   ucinn_ascendv2__Email__c
            WHERE  ucinn_ascendv2__Email_Address__c IN :emails
              AND  ucinn_ascendv2__Contact__c != null
        ]) {
            String addr = emailRec.ucinn_ascendv2__Email_Address__c;
            if (!result.containsKey(addr)) {
                result.put(addr, emailRec.ucinn_ascendv2__Contact__c);
            }
        }

        return result;
    }

    /**
     * Bulk SOQL event-stub lookup — single query with IN clause against
     * CventEvents__Event__c. The relationship between an Attendee Temp's
     * CventEvents__pkg_EventStub__c and an Event's CventEvents__pkg_EventStub__c
     * is guaranteed 1:1, so no post-filtering/confidence logic is needed here
     * — first (and only expected) row per stub wins.
     * Returns map: eventStub (trimmed, original case) -> Event Id.
     */
    @TestVisible
    private static Map<String, Id> findEventsByStubBulk(Set<String> eventStubs) {
        Map<String, Id> result = new Map<String, Id>();

        if (eventStubs == null || eventStubs.isEmpty()) {
            return result;
        }

        for (CventEvents__Event__c eventRec : [
            SELECT Id,
                   CventEvents__pkg_EventStub__c
            FROM   CventEvents__Event__c
            WHERE  CventEvents__pkg_EventStub__c IN :eventStubs
        ]) {
            String stub = eventRec.CventEvents__pkg_EventStub__c;
            if (String.isNotBlank(stub) && !result.containsKey(stub)) {
                result.put(stub, eventRec.Id);
            }
        }

        return result;
    }

    // -------------------------------------------------------------------------
    // Single-record helpers — retained ONLY for evaluateMatch (test path)
    // -------------------------------------------------------------------------

    /**
     * Name search using SOSL against ucinn_ascendv2__Contact_Name__c.
     * Both tokens must be present in Constructed_Name_Formula__c to qualify.
     * In test context seed with Test.setFixedSearchResults() before calling.
     */
    @TestVisible
    private static Id findConstituentByName(String firstName, String lastName) {
        if (String.isBlank(firstName) || String.isBlank(lastName)) {
            return null;
        }

        String safeLast  = escapeSosl(lastName.trim());
        String safeFirst = escapeSosl(firstName.trim());
        String searchTerm = safeLast + ' ' + safeFirst;

        String soslQuery =
            'FIND {' + searchTerm + '} '
          + 'IN ALL FIELDS '
          + 'RETURNING ucinn_ascendv2__Contact_Name__c('
          +     'Id, '
          +     'ucinn_ascendv2__Constructed_Name_Formula__c, '
          +     'ucinn_ascendv2__Contact__c '
          +     'WHERE ucinn_ascendv2__Contact__c != null'
          + ') '
          + 'LIMIT 20';

        List<List<SObject>> soslResults = Search.query(soslQuery);

        if (soslResults == null || soslResults.isEmpty() || soslResults[0].isEmpty()) {
            return null;
        }

        String lowerLast  = lastName.trim().toLowerCase();
        String lowerFirst = firstName.trim().toLowerCase();

        for (SObject nameRec : soslResults[0]) {
            String constructedName = ((String) nameRec.get('ucinn_ascendv2__Constructed_Name_Formula__c') ?? '').toLowerCase();

            if (constructedName.contains(lowerLast) && constructedName.contains(lowerFirst)) {
                return (Id) nameRec.get('ucinn_ascendv2__Contact__c');
            }
        }

        return null;
    }

    /**
     * Exact email match against ucinn_ascendv2__Email__c.
     */
    @TestVisible
    private static Id findConstituentByEmail(String emailAddress) {
        if (String.isBlank(emailAddress)) {
            return null;
        }

        List<ucinn_ascendv2__Email__c> emailRecs = [
            SELECT ucinn_ascendv2__Contact__c
            FROM   ucinn_ascendv2__Email__c
            WHERE  ucinn_ascendv2__Email_Address__c = :emailAddress.trim()
              AND  ucinn_ascendv2__Contact__c != null
            LIMIT  1
        ];

        return emailRecs.isEmpty() ? null : emailRecs[0].ucinn_ascendv2__Contact__c;
    }

    // -------------------------------------------------------------------------
    // Shared utilities
    // -------------------------------------------------------------------------

    @TestVisible
    private static String buildAttendeeTempQuery(Set<Id> tempIds) {
        return 'SELECT Id, '
             + 'CventEvents__pkg_FirstName__c, '
             + 'CventEvents__pkg_LastName__c, '
             + 'CventEvents__pkg_Email__c, '
             + 'CventEvents__pkg_EventStub__c '
             + 'FROM CventEvents__AttendeeTemp__c '
             + 'WHERE Id IN :tempIds';
    }

    /**
     * Safely retrieves a String field from an SObject without throwing
     * SObjectException if the field is not valid for that object type.
     * This protects processTemps() when called from test context with a
     * stand-in SObject (e.g. Contact) that lacks Cvent package fields.
     */
    @TestVisible
    private static String safeGet(SObject record, String fieldName) {
        try {
            return (String) record.get(fieldName);
        } catch (SObjectException e) {
            return null;
        }
    }

    /**
     * Escapes SOSL reserved characters to prevent injection / query errors.
     */
    @TestVisible
    private static String escapeSosl(String input) {
        String escaped = input.replaceAll('[?&|!{}\\[\\]()\\^~*:\\"+\\-]', '\\\\$0');
        escaped = escaped.replace('\'', '\\\'');
        return escaped;
    }
}