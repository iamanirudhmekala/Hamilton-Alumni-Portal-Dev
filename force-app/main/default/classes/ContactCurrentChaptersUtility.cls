/**
 * @class       ContactCurrentChaptersUtility
 * @description Invocable utility class called by the HAM_Chapter_Constituent_Current Flow
 *              (Record-Triggered, After Save, Create & Update on
 *              ucinn_ascendv2__Address_Relation__c).
 *
 *              Purpose:
 *              For each qualifying Address Relation (HAM_Chapter__c populated,
 *              Status = 'Current'), creates a HAM_Current_Chapter__c junction record
 *              (Chapter__c, Constituent__c, Is_Active__c = true, Source__c = 'Address Update')
 *              if one does not already exist.  Then aggregates ALL HAM_Current_Chapter__c
 *              records for the Contact to produce:
 *                  - HAM_Current_Chapters__c: comma-separated, alphabetically ordered
 *                    Chapter__r.Name values (e.g. "Boston, New York City").
 *                  - HAM_Current_Regions__c: semicolon-separated unique Region__c values
 *                    from all HAM_Current_Chapter__c records for the Contact.
 *              When a Contact has no HAM_Current_Chapter__c records, both fields are
 *              explicitly cleared to an empty string.
 *
 *              Flow integration:
 *              The Flow passes the triggering Address Relation records directly into
 *              updateCurrentChapterOnContact() as a Record Collection variable.  The
 *              method extracts the unique set of Contact Ids and delegates all SOQL
 *              and DML work to updateContacts(), which can also be called directly
 *              from Apex for ad-hoc backfills.
 

 *

 *
 * @author      Cody Culp (Zuri Team)
 * @version     1.0 6/2/2025 Initial implementation
 * @author      Hamilton College - Ameya
 * @version     2.0  2026-04-21  Region implementation.
 * @version     3.0  2026-04-28  HAM_Current_Chapter__c creation before string aggregation.
 * @version     4.0  2026-04-30  Deactivate HAM_Current_Chapter__c records whose Address
 *                               Relation has become Former (Status != 'Current') and whose
 *                               Source__c = 'Address Update', before re-aggregating.
 */
public class ContactCurrentChaptersUtility {

    // -------------------------------------------------------------------------
    // Invocable entry point
    // -------------------------------------------------------------------------

    /**
     * @method  updateCurrentChapterOnContact
     * @description Entry point called by the HAM_Chapter_Constituent_Current Flow.
     *              Receives the collection of Address Relation records that triggered
     *              the Flow, extracts the associated Contact Ids, and delegates
     *              processing to updateContacts().
     *
     *              Null Contact references are skipped safely so that Address Relations
     *              linked only to an Account (ucinn_ascendv2__Account__c) do not cause
     *              a NullPointerException.
     *
     * @param   addressRelations  List of ucinn_ascendv2__Address_Relation__c records
     *                            supplied by the Flow's Record Collection variable.
     *                            The Flow guarantees at least one element; the method
     *                            handles an empty list gracefully.
     */
    @InvocableMethod(label='Build and Update Current Chapters String on Constituent')
    public static void updateCurrentChapterOnContact(List<ucinn_ascendv2__Address_Relation__c> addressRelations) {

        Set<Id> contactIds = new Set<Id>();

        for (ucinn_ascendv2__Address_Relation__c ar : addressRelations) {
            if (ar.ucinn_ascendv2__Contact__c != null) {
                contactIds.add(ar.ucinn_ascendv2__Contact__c);
            }
        }

        updateContacts(contactIds);
    }

    // -------------------------------------------------------------------------
    // Core processing
    // -------------------------------------------------------------------------

    /**
     * @method  updateContacts
     * @description Queries all qualifying Address Relations for the supplied Contact
     *              Ids, creates HAM_Current_Chapter__c junction records for any new
     *              chapter memberships, deactivates junction records whose Address
     *              Relation has become Former, then aggregates all active
     *              HAM_Current_Chapter__c records per Contact to build the chapter
     *              and region strings.
     *
     *              Algorithm:
     *              1. Query Address Relations where HAM_Chapter__c is populated,
     *                 Status is 'Current', and Contact is in the supplied Id set.
     *              2. Query existing HAM_Current_Chapter__c records for these Contacts
     *                 to determine which Chapter/Constituent combinations are new.
     *              3. Insert new HAM_Current_Chapter__c records (Chapter__c, Constituent__c,
     *                 Is_Active__c = true, Source__c = 'Address Update').
     *              3a. Query Address Relations for these Contacts where HAM_Chapter__c is
     *                  populated but Status is NOT 'Current' (i.e. Former/blank).
     *                  For each such Address Relation, find any HAM_Current_Chapter__c
     *                  record with Is_Active__c = true AND Source__c = 'Address Update'
     *                  matching that Chapter/Constituent pair and flip Is_Active__c = false.
     *              4. Query ALL active HAM_Current_Chapter__c records for these Contacts
     *                 (pre-existing + newly inserted, minus newly deactivated), ordered
     *                 by Chapter name.
     *              5. Build a comma-separated Chapter__r.Name string per Contact
     *                 for HAM_Current_Chapters__c.
     *              6. Build a unique semicolon-separated Region__c set per Contact
     *                 for HAM_Current_Regions__c.
     *              7. Contacts with no active HAM_Current_Chapter__c records have both
     *                 fields explicitly cleared.
     *              8. Single bulk Contact update.
     *
     * @param   contactIds  Set of Contact Ids to process.  May be called directly
     *                      from Apex for backfill scenarios.
     */
    public static void updateContacts(Set<Id> contactIds) {

        // 1. Fetch all current, chapter-bearing Address Relations for these Contacts.
        List<ucinn_ascendv2__Address_Relation__c> relatedARs = [
            SELECT
                Id,
                ucinn_ascendv2__Contact__c,
                HAM_Chapter__c
            FROM ucinn_ascendv2__Address_Relation__c
            WHERE HAM_Chapter__c != ''
              AND ucinn_ascendv2__Status__c = 'Current'
              AND ucinn_ascendv2__Contact__c IN :contactIds
        ];

        // 2. Identify Chapter/Constituent pairs that already have a HAM_Current_Chapter__c
        //    record so we do not create duplicates.
        Set<String> existingKeys = new Set<String>();
        for (HAM_Current_Chapter__c existing : [
            SELECT Chapter__c, Constituent__c
            FROM HAM_Current_Chapter__c
            WHERE Constituent__c IN :contactIds
        ]) {
            existingKeys.add((String) existing.Constituent__c + '_' + (String) existing.Chapter__c);
        }

        // 3. Build and insert new HAM_Current_Chapter__c records.
        List<HAM_Current_Chapter__c> newChapterRecords = new List<HAM_Current_Chapter__c>();
        for (ucinn_ascendv2__Address_Relation__c ar : relatedARs) {
            String key = (String) ar.ucinn_ascendv2__Contact__c + '_' + (String) ar.HAM_Chapter__c;
            if (!existingKeys.contains(key)) {
                newChapterRecords.add(new HAM_Current_Chapter__c(
                    Chapter__c     = ar.HAM_Chapter__c,
                    Constituent__c = ar.ucinn_ascendv2__Contact__c,
                    Is_Active__c   = true,
                    Source__c      = 'Address Update'
                ));
                existingKeys.add(key);
            }
        }
        if (!newChapterRecords.isEmpty()) {
            insert newChapterRecords;
        }

        // 3a. Deactivate HAM_Current_Chapter__c records whose backing Address Relation
        //     is no longer 'Current' (i.e. has become Former or blank).
        //
        //     Query all chapter-bearing Address Relations for these Contacts that are
        //     NOT 'Current'.  For each such AR, if a HAM_Current_Chapter__c exists with
        //     Is_Active__c = true AND Source__c = 'Address Update' for that
        //     Chapter/Constituent pair, flip Is_Active__c to false.

        // Collect the Chapter/Constituent keys that are now Former.
        List<ucinn_ascendv2__Address_Relation__c> formerARs = [
            SELECT
                Id,
                ucinn_ascendv2__Contact__c,
                HAM_Chapter__c
            FROM ucinn_ascendv2__Address_Relation__c
            WHERE HAM_Chapter__c != ''
              AND ucinn_ascendv2__Status__c != 'Current'
              AND ucinn_ascendv2__Contact__c IN :contactIds
        ];

        if (!formerARs.isEmpty()) {
            // Build a set of Contact+Chapter composite keys that are now Former.
            Set<String> formerKeys = new Set<String>();
            for (ucinn_ascendv2__Address_Relation__c ar : formerARs) {
                if (ar.ucinn_ascendv2__Contact__c != null) {
                    formerKeys.add((String) ar.ucinn_ascendv2__Contact__c + '_' + (String) ar.HAM_Chapter__c);
                }
            }

            // Find any active, Address-Update-sourced HAM_Current_Chapter__c records
            // that match those Former keys and need to be deactivated.
            List<HAM_Current_Chapter__c> toDeactivate = new List<HAM_Current_Chapter__c>();
            for (HAM_Current_Chapter__c hcc : [
                SELECT Id, Chapter__c, Constituent__c, Is_Active__c, Source__c
                FROM HAM_Current_Chapter__c
                WHERE Constituent__c IN :contactIds
                  AND Is_Active__c = true
                  AND Source__c = 'Address Update'
            ]) {
                String key = (String) hcc.Constituent__c + '_' + (String) hcc.Chapter__c;
                if (formerKeys.contains(key)) {
                    hcc.Is_Active__c = false;
                    toDeactivate.add(hcc);
                }
            }

            if (!toDeactivate.isEmpty()) {
                update toDeactivate;
            }
        }

        // 4. Query ALL active HAM_Current_Chapter__c records for these Contacts
        //    (pre-existing + newly inserted, minus newly deactivated),
        //    ordered by chapter name for a sorted output.
        List<HAM_Current_Chapter__c> allChapterRecords = [
            SELECT
                Constituent__c,
                Chapter__r.Name,
                Region__c
            FROM HAM_Current_Chapter__c
            WHERE Constituent__c IN :contactIds
              AND Is_Active__c = true
            ORDER BY Chapter__r.Name ASC
        ];

        // 5 & 6. Aggregate chapter names and collect unique region values per Contact.
        Map<Id, String> contactChapterStringMap = new Map<Id, String>();
        Map<Id, Set<String>> contactRegionSetMap = new Map<Id, Set<String>>();

        for (HAM_Current_Chapter__c hcc : allChapterRecords) {
            Id conId = hcc.Constituent__c;
            String chapterName = hcc.Chapter__r.Name;

            if (!contactChapterStringMap.containsKey(conId)) {
                contactChapterStringMap.put(conId, chapterName);
            } else {
                String existing = contactChapterStringMap.get(conId);
                if (!existing.contains(chapterName)) {
                    contactChapterStringMap.put(conId, existing + ', ' + chapterName);
                }
            }

            if (String.isNotBlank(hcc.Region__c)) {
                if (!contactRegionSetMap.containsKey(conId)) {
                    contactRegionSetMap.put(conId, new Set<String>{ hcc.Region__c });
                } else {
                    contactRegionSetMap.get(conId).add(hcc.Region__c);
                }
            }

            contactIds.remove(conId);
        }

        // 7. Build the Contact update list for Contacts that have active chapter records.
        List<Contact> processedCons = new List<Contact>();

        for (Id contactId : contactChapterStringMap.keySet()) {
            String regionString = '';
            if (contactRegionSetMap.containsKey(contactId)) {
                regionString = String.join(new List<String>(contactRegionSetMap.get(contactId)), '; ');
            }
            processedCons.add(new Contact(
                Id                      = contactId,
                HAM_Current_Chapters__c = contactChapterStringMap.get(contactId),
                HAM_Current_Regions__c  = regionString
            ));
        }

        // Any Ids remaining in contactIds had no active HAM_Current_Chapter__c records;
        // clear both fields explicitly.
        for (Id contactId : contactIds) {
            processedCons.add(new Contact(
                Id                      = contactId,
                HAM_Current_Chapters__c = '',
                HAM_Current_Regions__c  = ''
            ));
        }

        // 8. Single bulk DML for all affected Contacts.
        update processedCons;

        Results response = new Results();
        response.updatedContacts = processedCons;
    }

    // -------------------------------------------------------------------------
    // Output wrapper
    // -------------------------------------------------------------------------

    /**
     * @class   Results
     * @description Output wrapper exposed to the Flow via @InvocableVariable.
     *              Holds the list of Contact records updated by updateContacts()
     *              so that downstream Flow elements can reference the post-update
     *              state if needed (e.g. for logging or conditional branching).
     */
    public class Results {

        /**
         * The Contact records written during this invocation, each populated with
         * the new HAM_Current_Chapters__c value (or empty string if cleared).
         */
        @InvocableVariable(label='Updated Contacts Output')
        public List<Contact> updatedContacts;
    }
}