/**
 * miltonAlumniSearchAction
 * -------------------
 * Invocable Apex action for Agentforce (Alumni Search topic).
 * Accepts optional inputs — Name, Major/Degree, Class of Year, Constituent Type, Region.
 * At least ONE must be provided by the calling agent topic (enforced here
 * as a safety net even though the topic instructions already require it).
 *
 * NOTE ON HAM_Reunion_Year__c:
 * This sample assumes the field resolves to a TEXT value (common for
 * Ascendv2 formula fields used for display, e.g. "1992").
 * If it is actually a NUMBER field in your org, change the WHERE clause
 * for year from a LIKE bind to an exact Integer equality bind
 * (see comment in buildYearFilter()).
 */
global with sharing class miltonAlumniSearchAction {

    // Portal IDs of the Service Indicator Value records that gate what's shown on a search result.
    private static final String DO_NOT_DISPLAY_EMAIL_SVID = 'SIV_VIS_EMAIL';
    private static final String DO_NOT_DISPLAY_CONNECTION_SVID = 'SIV_VIS_CONNECTION';
    private static final String ALUMNI_PRIVACY_SVID = 'SIV_VIS_ALUMNI_PRIVACY';

    // ---------- INPUT ----------
    @JsonAccess(serializable='always' deserializable='always')
    global class AlumniSearchRequest {
        @InvocableVariable(label='Alumni Name' description='Full or partial contact name' required=false)
        global String alumniName;

        @InvocableVariable(label='Major / Degree' description='Full or partial major/degree text' required=false)
        global String majorDegree;

        @InvocableVariable(label='Class of Year' description='Graduation year' required=false)
        global String classOfYear;

        @InvocableVariable(label='Constituent Type' description='Primary Contact Type of the alumni/Employee' required=false)
        global String constituentType;

        @InvocableVariable(label='Region' description='Region/Chapter name(s) the alumni currently belongs to. Comma-separate multiple values.' required=false)
        global String region;

        @InvocableVariable(label='Contact Id' description='Contact Id of the currently authenticated user (the chat viewer). Must be bound to the Contact Id of the authenticated session; never accept as free text or infer from conversation.' required=true)
        global Id contactId;
    }

    // ---------- OUTPUT (invocable action output) ----------
    // miltonAlumniSearchResponse (top-level, global, @AuraEnabled/@JsonAccess — see
    // miltonAlumniSearchResponse.cls) is bound to the miltonAlumniSearchResult
    // Custom Lightning Type so Agentforce can render it via miltonAlumniSearchResultsCard.
    // It's nested here as a field so the field itself stays @InvocableVariable,
    // which is what makes it show up as an action output in Agent Builder.
    @JsonAccess(serializable='always' deserializable='always')
    global class AlumniSearchOutput {
        @InvocableVariable(label='Alumni Search Result')
        global miltonAlumniSearchResponse result;
    }

    @InvocableMethod(
        label='Alumni Search'
        description='Searches Alumni Degree Information records by name, major/degree, class of year, constituent type, and/or region. Requires at least one parameter.'
        category='Alumni'
    )
    global static List<AlumniSearchOutput> searchAlumni(List<AlumniSearchRequest> requests) {
        List<AlumniSearchOutput> responses = new List<AlumniSearchOutput>();

        for (AlumniSearchRequest req : requests) {
            responses.add(wrap(buildResponse(req.alumniName, req.majorDegree, req.classOfYear, req.constituentType, req.region, req.contactId)));
        }

        return responses;
    }

    private static miltonAlumniSearchResponse buildResponse(String name, String degree, String year, String constituentType, String region, Id viewerContactId) {
        miltonAlumniSearchResponse resp = new miltonAlumniSearchResponse();
        resp.alumniRecords = new List<miltonAlumniResult>();
        resp.contactId = viewerContactId;

        // Safety-net validation (topic should already enforce this)
        if (String.isBlank(name) && String.isBlank(degree) && String.isBlank(year) && String.isBlank(constituentType) && String.isBlank(region)) {
            System.debug('[miltonAlumniSearchAction] buildResponse: all inputs blank, returning early.');
            resp.isSuccess = false;
            resp.totalCount = 0;
            resp.statusMessage = 'No search criteria provided. Please provide at least one of: name, major/degree, class of year, constituent type, or region.';
            return resp;
        }

        List<String> whereClauses = new List<String>();

        // Bind variables must be in scope at the point Database.query() executes.
        String namePattern;
        String degreePattern;
        String yearPattern;

        if (String.isNotBlank(name)) {
            namePattern = '%' + name.trim() + '%';
            whereClauses.add('ucinn_ascendv2__Contact__r.Name LIKE :namePattern');
        }
        if (String.isNotBlank(degree)) {
            degreePattern = '%' + degree.trim() + '%';
            whereClauses.add('ucinn_ascendv2__Major_Degree_Formula__c LIKE :degreePattern');
        }
        if (String.isNotBlank(year)) {
            yearPattern = '%' + year.trim() + '%';
            // If HAM_Reunion_Year__c is a Number field, replace the line above/below with:
            //   Integer yearVal = Integer.valueOf(year.trim());
            //   whereClauses.add('ucinn_ascendv2__Contact__r.HAM_Reunion_Year__c = :yearVal');
            whereClauses.add('ucinn_ascendv2__Contact__r.HAM_Reunion_Year__c LIKE :yearPattern');
        }
        if (String.isNotBlank(constituentType)) {
            // constituentType is a Milton_Constituent_Type__mdt DeveloperName (e.g. 'Alumni'), whose
            // Constituent_Type__c field holds the comma-separated multi-select picklist value(s) it
            // maps to (e.g. 'Hamilton Alumini,Kirkland Alumnae'). ucinn_ascendv2__Contact_Type__c is
            // itself a multi-select picklist, so membership must be checked with INCLUDES.
            List<String> contactTypeValues = getConstituentTypeValues(constituentType);
            if (!contactTypeValues.isEmpty()) {
                // INCLUDES does not support a bound List<String> in dynamic SOQL (Database.query
                // throws "missing value at ':'"), so the values are embedded as literals instead.
                List<String> quotedContactTypeValues = new List<String>();
                for (String contactTypeValue : contactTypeValues) {
                    quotedContactTypeValues.add('\'' + String.escapeSingleQuotes(contactTypeValue) + '\'');
                }
                whereClauses.add('ucinn_ascendv2__Contact__r.ucinn_ascendv2__Contact_Type__c INCLUDES (' +
                    String.join(quotedContactTypeValues, ',') + ')');
            } else {
                // Unknown constituent type - fail safe to zero results rather than silently
                // dropping the filter and returning everything.
                whereClauses.add('ucinn_ascendv2__Contact__r.Id = null');
            }
        }
        if (String.isNotBlank(region)) {
            // Same pattern as HAM_AlumniFilterHelper.getSpecificWhereClause('Region', ...):
            // a contact's current region/chapter is tracked via the HAM_Current_Chapter__c
            // junction object, and only the active record for that chapter counts.
            List<String> regionValues = new List<String>();
            for (String val : region.split(',')) {
                if (String.isNotBlank(val)) {
                    regionValues.add(val.trim());
                }
            }
            if (!regionValues.isEmpty()) {
                List<String> quotedRegionValues = new List<String>();
                for (String regionValue : regionValues) {
                    quotedRegionValues.add('\'' + String.escapeSingleQuotes(regionValue) + '\'');
                }
                whereClauses.add('ucinn_ascendv2__Contact__c IN (SELECT Constituent__c FROM HAM_Current_Chapter__c ' +
                    'WHERE Chapter__r.Name IN (' + String.join(quotedRegionValues, ',') + ') AND Is_Active__c = true)');
            }
        }

        String query =
            'SELECT Id, ' +
            '       ucinn_ascendv2__Contact__r.Id, ' +
            '       ucinn_ascendv2__Contact__r.Name, ' +
            '       ucinn_ascendv2__Contact__r.LastName, ' +
            '       ucinn_ascendv2__Contact__r.HAM_Profile_Picture_URL__c, ' +
            '       ucinn_ascendv2__Major_Degree_Formula__c, ' +
            '       ucinn_ascendv2__Contact__r.HAM_Reunion_Year__c, ' +
            '       ucinn_ascendv2__Contact__r.HAM_Is_Active__c, ' +
            '       ucinn_ascendv2__Contact__r.ucinn_ascendv2__Is_Deceased__c, ' +
            '       ucinn_ascendv2__Contact__r.Email ' +
            'FROM ucinn_ascendv2__Degree_Information__c ' +
            'WHERE ' + String.join(whereClauses, ' AND ') +
            ' WITH SECURITY_ENFORCED ' +
            'LIMIT 50';

        System.debug('[miltonAlumniSearchAction] buildResponse query: ' + query);

        List<ucinn_ascendv2__Degree_Information__c> records;
        try {
            records = Database.query(query);
            System.debug('[miltonAlumniSearchAction] buildResponse records returned: ' + records.size());
        } catch (Exception e) {
            System.debug('[miltonAlumniSearchAction] buildResponse query threw: ' + e.getMessage());
            resp.isSuccess = false;
            resp.totalCount = 0;
            resp.statusMessage = 'An error occurred while searching alumni records: ' + e.getMessage();
            return resp;
        }

        // A contact can have multiple ucinn_ascendv2__Degree_Information__c records (one per
        // degree/major). Collapse those into a single result per contact, concatenating the
        // distinct ucinn_ascendv2__Major_Degree_Formula__c values with a comma - the first
        // record seen for a contact is kept as the representative record for the other fields.
        List<Id> orderedContactIds = new List<Id>();
        Map<Id, ucinn_ascendv2__Degree_Information__c> representativeRecordByContact = new Map<Id, ucinn_ascendv2__Degree_Information__c>();
        Map<Id, List<String>> degreeValuesByContact = new Map<Id, List<String>>();

        for (ucinn_ascendv2__Degree_Information__c rec : records) {
            if (rec.ucinn_ascendv2__Contact__r == null) {
                continue;
            }
            Id contactId = rec.ucinn_ascendv2__Contact__r.Id;
            if (!representativeRecordByContact.containsKey(contactId)) {
                representativeRecordByContact.put(contactId, rec);
                degreeValuesByContact.put(contactId, new List<String>());
                orderedContactIds.add(contactId);
            }

            String degreeValue = rec.ucinn_ascendv2__Major_Degree_Formula__c;
            if (String.isNotBlank(degreeValue) && !degreeValuesByContact.get(contactId).contains(degreeValue)) {
                degreeValuesByContact.get(contactId).add(degreeValue);
            }
        }

        Set<Id> alumniContactIds = new Set<Id>(orderedContactIds);
        ServiceIndicatorVisibilityHelper visibilityHelper = new ServiceIndicatorVisibilityHelper();

        // Alumni who have opted out of directory visibility entirely must not appear in the
        // results at all - filter them out before doing any further per-contact work.
        Set<Id> alumniPrivacyContactIds = visibilityHelper.getContactIdsWithActiveIndicator(
            new List<Id>(alumniContactIds), ALUMNI_PRIVACY_SVID
        );
        if (!alumniPrivacyContactIds.isEmpty()) {
            List<Id> visibleContactIds = new List<Id>();
            for (Id contactId : orderedContactIds) {
                if (!alumniPrivacyContactIds.contains(contactId)) {
                    visibleContactIds.add(contactId);
                }
            }
            orderedContactIds = visibleContactIds;
            alumniContactIds = new Set<Id>(orderedContactIds);
        }

        Map<Id, miltonAlumniConnectionAction.ConnectionFlags> flagsByContactId =
            miltonAlumniConnectionAction.getConnectionFlags(viewerContactId, new List<Id>(alumniContactIds));
        Set<Id> hideEmailContactIds = visibilityHelper.getContactIdsWithActiveIndicator(
            new List<Id>(alumniContactIds), DO_NOT_DISPLAY_EMAIL_SVID
        );
        // Alumni with this indicator active still appear in the results, but without a
        // Send/Cancel/Remove Connection action on their card.
        Set<Id> hideConnectionContactIds = visibilityHelper.getContactIdsWithActiveIndicator(
            new List<Id>(alumniContactIds), DO_NOT_DISPLAY_CONNECTION_SVID
        );

        // Connected alumni first, then everyone else, each group in last-name alphabetical order.
        List<AlumniSortEntry> sortEntries = new List<AlumniSortEntry>();
        for (Id contactId : orderedContactIds) {
            Boolean isConnected = flagsByContactId.containsKey(contactId) && flagsByContactId.get(contactId).isConnected;
            String lastName = representativeRecordByContact.get(contactId).ucinn_ascendv2__Contact__r.LastName;
            sortEntries.add(new AlumniSortEntry(contactId, isConnected, lastName));
        }
        sortEntries.sort();

        for (AlumniSortEntry sortEntry : sortEntries) {
            Id contactId = sortEntry.contactId;
            ucinn_ascendv2__Degree_Information__c rec = representativeRecordByContact.get(contactId);

            miltonAlumniResult ar = new miltonAlumniResult();
            ar.recordId            = rec.Id;
            ar.contactId           = contactId;
            ar.alumniName          = rec.ucinn_ascendv2__Contact__r.Name;
            ar.profilePictureUrl   = rec.ucinn_ascendv2__Contact__r.HAM_Profile_Picture_URL__c;
            ar.classOfYear         = rec.ucinn_ascendv2__Contact__r.HAM_Reunion_Year__c != null
                                        ? String.valueOf(rec.ucinn_ascendv2__Contact__r.HAM_Reunion_Year__c)
                                        : null;

            ar.isActive = rec.ucinn_ascendv2__Contact__r.HAM_Is_Active__c == true;
            ar.isDeceased = rec.ucinn_ascendv2__Contact__r.ucinn_ascendv2__Is_Deceased__c == true;
            ar.connectionPrivacyEnabled = hideConnectionContactIds.contains(contactId);

            ar.email = hideEmailContactIds.contains(contactId)
                ? null
                : rec.ucinn_ascendv2__Contact__r.Email;

            miltonAlumniConnectionAction.ConnectionFlags flags = flagsByContactId.get(contactId);
            if (flags != null) {
                ar.isConnected      = flags.isConnected;
                ar.isBookmarked     = flags.isBookmarked;
                ar.isRequestSent    = flags.isRequestSent;
                ar.isSelf           = flags.isSelf;
            }

            ar.majorDegree = String.join(degreeValuesByContact.get(contactId), ', ');

            resp.alumniRecords.add(ar);
        }

        resp.totalCount     = resp.alumniRecords.size();
        resp.isSuccess      = true;
        resp.statusMessage  = resp.totalCount + ' alumni record(s) found.';
        System.debug('[miltonAlumniSearchAction] buildResponse final: totalCount=' + resp.totalCount
            + ', statusMessage=' + resp.statusMessage);
        return resp;
    }

    /**
     * Resolves a Milton_Constituent_Type__mdt DeveloperName (e.g. 'Alumni', 'Current_Employee') to
     * the list of ucinn_ascendv2__Contact_Type__c multi-select picklist values it represents, by
     * splitting that record's comma-separated Constituent_Type__c field (e.g. a single 'Alumni'
     * metadata record maps to both 'Hamilton Alumini' and 'Kirkland Alumnae').
     */
    private static List<String> getConstituentTypeValues(String constituentType) {
        List<String> values = new List<String>();

        List<Milton_Constituent_Type__mdt> mdtRecords = [
            SELECT Constituent_Type__c
            FROM Milton_Constituent_Type__mdt
            WHERE DeveloperName = :constituentType
            LIMIT 1
        ];

        if (!mdtRecords.isEmpty() && String.isNotBlank(mdtRecords[0].Constituent_Type__c)) {
            for (String val : mdtRecords[0].Constituent_Type__c.split(',')) {
                if (String.isNotBlank(val)) {
                    values.add(val.trim());
                }
            }
        }

        return values;
    }

    private static AlumniSearchOutput wrap(miltonAlumniSearchResponse resp) {
        AlumniSearchOutput output = new AlumniSearchOutput();
        output.result = resp;
        return output;
    }

    /**
     * Sort key for ordering search results: connected alumni first, then everyone else,
     * each group in last-name alphabetical order.
     */
    private class AlumniSortEntry implements Comparable {
        private Id contactId;
        private Boolean isConnected;
        private String lastNameLower;

        private AlumniSortEntry(Id contactId, Boolean isConnected, String lastName) {
            this.contactId = contactId;
            this.isConnected = isConnected == true;
            this.lastNameLower = String.isBlank(lastName) ? '' : lastName.toLowerCase();
        }

        public Integer compareTo(Object other) {
            AlumniSortEntry otherEntry = (AlumniSortEntry) other;
            if (this.isConnected != otherEntry.isConnected) {
                return this.isConnected ? -1 : 1;
            }
            return this.lastNameLower.compareTo(otherEntry.lastNameLower);
        }
    }

    /**
     * Determines which searched alumni have an active (latest child record has no End Date)
     * Service Indicator for the given parent Service Indicator Value Portal ID - e.g. hiding
     * email (SIV_VIS_EMAIL), hiding the connection action (SIV_VIS_CONNECTION), or hiding the
     * alumni from the directory entirely (SIV_VIS_ALUMNI_PRIVACY).
     * Declared 'without sharing' for the same reason miltonAlumniConnectionAction
     * (see its class comment) is split out without sharing: the portal/guest
     * viewer has no sharing access to another alumni's own Service Indicator
     * records, so this lookup must bypass sharing to see them at all.
     */
    private without sharing class ServiceIndicatorVisibilityHelper {
        // Apex does not allow static methods on inner classes, so this lookup is an instance method.
        private Set<Id> getContactIdsWithActiveIndicator(List<Id> contactIds, String portalId) {
            Set<Id> activeContactIds = new Set<Id>();
            if (contactIds == null || contactIds.isEmpty()) {
                return activeContactIds;
            }

            Id contactIndicatorRtId = Schema.SObjectType.ucinn_ascendv2__Service_Indicator__c
                .getRecordTypeInfosByName().get(HAM_ConstantsUtil.CONTACT_SERVICE_INDICATOR_RECORD_TYPE).getRecordTypeId();

            // A contact can have multiple child Service Indicator records for the same parent
            // Service Indicator Value over time (one per toggle on/off). Only the latest one (by
            // CreatedDate) reflects the current choice - an End Date on it means the setting was
            // turned back off, so it must NOT count as active.
            Map<Id, ucinn_ascendv2__Service_Indicator__c> latestByContact = new Map<Id, ucinn_ascendv2__Service_Indicator__c>();
            for (ucinn_ascendv2__Service_Indicator__c si : [
                SELECT ucinn_ascendv2__Contact__c, ucinn_ascendv2__End_Date__c
                FROM ucinn_ascendv2__Service_Indicator__c
                WHERE RecordTypeId = :contactIndicatorRtId
                AND ucinn_ascendv2__Contact__c IN :contactIds
                AND ucinn_ascendv2__Service_Indicator_Value__r.HAM_Portal_ID__c = :portalId
                ORDER BY ucinn_ascendv2__Contact__c ASC, CreatedDate DESC
            ]) {
                // First record seen per contact is the latest one, thanks to the ORDER BY above
                if (!latestByContact.containsKey(si.ucinn_ascendv2__Contact__c)) {
                    latestByContact.put(si.ucinn_ascendv2__Contact__c, si);
                }
            }

            for (ucinn_ascendv2__Service_Indicator__c latest : latestByContact.values()) {
                if (latest.ucinn_ascendv2__End_Date__c == null) {
                    activeContactIds.add(latest.ucinn_ascendv2__Contact__c);
                }
            }
            return activeContactIds;
        }
    }
}