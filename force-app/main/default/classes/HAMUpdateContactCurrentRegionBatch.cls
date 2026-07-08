/**
 * @class       HAMUpdateContactCurrentRegionBatch
 * @description Backfill batch job that mirrors ContactCurrentChaptersUtility.updateContacts()
 *              across all Contact records:
 *
 *              1. Creates HAM_Current_Chapter__c junction records for every qualifying
 *                 Address Relation (HAM_Chapter__c populated, Status = 'Current') that
 *                 does not already have one.
 *              2. Deactivates HAM_Current_Chapter__c records (Source = 'Address Update')
 *                 whose backing Address Relation is no longer 'Current'.
 *              3. Aggregates all active HAM_Current_Chapter__c records per Contact to build:
 *                     - HAM_Current_Chapters__c: comma-separated, alphabetically ordered
 *                       Chapter__r.Name values (e.g. "Florida (Orlando), New York City").
 *                     - HAM_Current_Regions__c: semicolon-separated, deduplicated, sorted
 *                       Region__c values (e.g. "Anytown;Chicago;NYC").
 *              Contacts with no active HAM_Current_Chapter__c records are explicitly
 *              cleared on both fields.
 *
 *              Usage:
 *              Execute once from Anonymous Apex:
 *                  Database.executeBatch(new HAMUpdateContactCurrentRegionBatch(), 200);
 *
 *              The batch scope is intentionally set to 200 so that the inner SOQL
 *              queries stay well within the 50,000-row query limit.
 *
 * @author      Hamilton College - Advancement Information Systems (AIS)
 * @version     1.0  2026-04-21  Initial implementation.
 * @version     2.0  2026-05-21  Also creates/deactivates HAM_Current_Chapter__c records
 *                               and writes HAM_Current_Chapters__c alongside regions.
 */
public class HAMUpdateContactCurrentRegionBatch implements Database.Batchable<SObject> {

    // -------------------------------------------------------------------------
    // Start
    // -------------------------------------------------------------------------

    /**
     * @method  start
     * @description Returns the full scope of Contacts to process.  All Contacts
     *              are included so that records with no qualifying Address Relations
     *              are also cleared if they previously held stale values.
     *
     * @param   bc  The batch context provided by the platform.
     * @return      QueryLocator over all Contact records.
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, HAM_Current_Regions__c, HAM_Current_Chapters__c
            FROM   Contact
        ]);
    }

    // -------------------------------------------------------------------------
    // Execute
    // -------------------------------------------------------------------------

    /**
     * @method  execute
     * @description Processes one batch of Contacts:
     *              1. Collects all Contact Ids in scope.
     *              2. Queries qualifying Address Relations (HAM_Chapter__c populated,
     *                 Status = 'Current').
     *              3. Queries existing HAM_Current_Chapter__c records to avoid duplicates.
     *              4. Inserts new HAM_Current_Chapter__c records for new memberships.
     *              5. Deactivates HAM_Current_Chapter__c records (Source = 'Address Update')
     *                 whose Address Relation is now non-Current.
     *              6. Queries all active HAM_Current_Chapter__c records and aggregates
     *                 chapter names and region values per Contact.
     *              7. Builds HAM_Current_Chapters__c (comma-separated) and
     *                 HAM_Current_Regions__c (semicolon-separated, sorted) per Contact.
     *              8. Contacts with no active records have both fields cleared.
     *              9. Single bulk Contact update.
     *
     * @param   bc     The batch context provided by the platform.
     * @param   scope  The current chunk of Contact records.
     */
    public void execute(Database.BatchableContext bc, List<Contact> scope) {

        // 1. Collect all Contact Ids in this chunk.
        Set<Id> contactIds = new Set<Id>();
        for (Contact c : scope) {
            contactIds.add(c.Id);
        }

        // 2. Query qualifying Address Relations (current, chapter-bearing).
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

        // 3. Identify existing HAM_Current_Chapter__c Chapter/Constituent pairs
        //    to avoid inserting duplicates.
        Set<String> existingKeys = new Set<String>();
        for (HAM_Current_Chapter__c existing : [
            SELECT Chapter__c, Constituent__c
            FROM HAM_Current_Chapter__c
            WHERE Constituent__c IN :contactIds
        ]) {
            existingKeys.add((String) existing.Constituent__c + '_' + (String) existing.Chapter__c);
        }

        // 4. Insert new HAM_Current_Chapter__c records for new chapter memberships.
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

        // 5. Deactivate HAM_Current_Chapter__c records (Source = 'Address Update')
        //    whose backing Address Relation is no longer 'Current'.
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
            Set<String> formerKeys = new Set<String>();
            for (ucinn_ascendv2__Address_Relation__c ar : formerARs) {
                if (ar.ucinn_ascendv2__Contact__c != null) {
                    formerKeys.add((String) ar.ucinn_ascendv2__Contact__c + '_' + (String) ar.HAM_Chapter__c);
                }
            }

            List<HAM_Current_Chapter__c> toDeactivate = new List<HAM_Current_Chapter__c>();
            for (HAM_Current_Chapter__c hcc : [
                SELECT Id, Chapter__c, Constituent__c
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

        // 6. Query all active HAM_Current_Chapter__c records for these Contacts
        //    (includes newly inserted, excludes newly deactivated), ordered by chapter
        //    name for alphabetically consistent output.
        Set<Id> remainingIds = new Set<Id>(contactIds);
        Map<Id, String> contactChapterStringMap = new Map<Id, String>();
        Map<Id, Set<String>> contactRegionSetMap = new Map<Id, Set<String>>();

        for (HAM_Current_Chapter__c hcc : [
            SELECT
                Constituent__c,
                Chapter__r.Name,
                Region__c
            FROM HAM_Current_Chapter__c
            WHERE Constituent__c IN :contactIds
              AND Is_Active__c = true
            ORDER BY Chapter__r.Name ASC
        ]) {
            Id conId = hcc.Constituent__c;
            String chapterName = hcc.Chapter__r.Name;

            // 7a. Aggregate chapter names (comma-separated, order preserved from query).
            if (!contactChapterStringMap.containsKey(conId)) {
                contactChapterStringMap.put(conId, chapterName);
            } else {
                String existing = contactChapterStringMap.get(conId);
                if (!existing.contains(chapterName)) {
                    contactChapterStringMap.put(conId, existing + ', ' + chapterName);
                }
            }

            // 7b. Collect unique region values for deduplication and sorting.
            if (String.isNotBlank(hcc.Region__c)) {
                if (!contactRegionSetMap.containsKey(conId)) {
                    contactRegionSetMap.put(conId, new Set<String>{ hcc.Region__c });
                } else {
                    contactRegionSetMap.get(conId).add(hcc.Region__c);
                }
            }

            remainingIds.remove(conId);
        }

        // 8. Build the Contact update list.
        List<Contact> contactsToUpdate = new List<Contact>();

        // Contacts with at least one active HAM_Current_Chapter__c record.
        for (Id contactId : contactChapterStringMap.keySet()) {
            String regionString = '';
            if (contactRegionSetMap.containsKey(contactId)) {
                List<String> sortedRegions = new List<String>(contactRegionSetMap.get(contactId));
                sortedRegions.sort();
                regionString = String.join(sortedRegions, ';');
            }
            contactsToUpdate.add(new Contact(
                Id                      = contactId,
                HAM_Current_Chapters__c = contactChapterStringMap.get(contactId),
                HAM_Current_Regions__c  = regionString
            ));
        }

        // Contacts with no active HAM_Current_Chapter__c records — clear both fields.
        for (Id contactId : remainingIds) {
            contactsToUpdate.add(new Contact(
                Id                      = contactId,
                HAM_Current_Chapters__c = '',
                HAM_Current_Regions__c  = ''
            ));
        }

        // 9. Single bulk DML for this chunk.
        if (!contactsToUpdate.isEmpty()) {
            update contactsToUpdate;
        }
    }

    // -------------------------------------------------------------------------
    // Finish
    // -------------------------------------------------------------------------

    /**
     * @method  finish
     * @description Called by the platform after all chunks have been processed.
     *              No post-processing is required for this one-time backfill job.
     *
     * @param   bc  The batch context provided by the platform.
     */
    public void finish(Database.BatchableContext bc) {
        // One-time batch — no follow-on action required.
    }
}