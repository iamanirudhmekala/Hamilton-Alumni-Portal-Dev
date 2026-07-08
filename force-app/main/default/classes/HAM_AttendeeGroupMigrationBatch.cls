/**
 * HAM_AttendeeGroupMigrationBatch
 * ─────────────────────────────────────────────────────────────────────────────
 * Migrates conference360__Attendee_Group__c → HAM_Event_Attendee_Group__c.
 *
 * Key behaviours:
 *  - MUST run before HAM_AttendeeMigrationBatch (attendees reference group records)
 *  - High volume: 188+ groups on reference event alone
 *  - Idempotent: upsert on HAM_BT_Source_Id__c
 *  - Populates HAM_BT_Attendee_Group__c (lookup → conference360__Attendee_Group__c)
 *  - Chains → HAM_SalesDocumentMigrationBatch on finish() (SalesDoc now runs before Attendee
 *    so the attendee Sales Document lookup can be resolved)
 *
 * Live data (ref event a6KU1000008006uMAA): 188+ attendee groups
 *   Each group has Bill_To_Contact__c and Bill_To_Account__c populated
 *
 * Change Log:
 *   v1.0  2026-04-09  Initial deployment
 *   v1.1  2026-04-14  Fixed CventEvents_Event__c field name (single underscore)
 *   v1.2  2026-04-14  PMD static analysis fixes
 * @description Batch class to migrate conference360__Attendee_Group__c records to HAM_Event_Attendee_Group__c.
 */
public class HAM_AttendeeGroupMigrationBatch
        implements Database.Batchable<SObject>, Database.Stateful {

    private Map<Id, Id> btToCventEventMap = new Map<Id, Id>();
    public  Integer successCount = 0;
    public  Integer failCount    = 0;

    // ── start() ───────────────────────────────────────────────────────────────
    /**
     * @description Builds the BT-to-Cvent event map and returns a QueryLocator for all attendee groups.
     * @param bc BatchableContext provided by the platform
     * @return Database.QueryLocator scoped to attendee groups for migrated events
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        for (CventEvents__Event__c cv : [
            SELECT Id, HAM_BT_Event_Id__c
            FROM   CventEvents__Event__c
            WHERE  HAM_BT_Event_Id__c != null
        ]) {
            btToCventEventMap.put((Id) cv.HAM_BT_Event_Id__c, cv.Id);
        }

        return Database.getQueryLocator([
            SELECT Id,
                   Name,
                   conference360__Event__c,
                   conference360__Bill_To_Contact__c,
                   conference360__Bill_To_Account__c
            FROM   conference360__Attendee_Group__c
            WHERE  conference360__Event__c IN :btToCventEventMap.keySet()
        ]);
    }

    // ── execute() ─────────────────────────────────────────────────────────────
    /**
     * @description Upserts a batch of attendee groups into HAM_Event_Attendee_Group__c.
     * @param bc     BatchableContext provided by the platform
     * @param groups Chunk of conference360__Attendee_Group__c records to process
     */
    public void execute(
        Database.BatchableContext bc,
        List<conference360__Attendee_Group__c> groups
    ) {
        List<HAM_Event_Attendee_Group__c> toUpsert = new List<HAM_Event_Attendee_Group__c>();

        for (conference360__Attendee_Group__c ag : groups) {
            Id cventEventId = btToCventEventMap.get(ag.conference360__Event__c);
            if (cventEventId == null) { continue; }

            toUpsert.add(new HAM_Event_Attendee_Group__c(
                // Parent event lookup
                CventEvents_Event__c      = cventEventId,

                // Core fields
                HAM_Group_Name__c         = HAM_MigrationUtil.truncate(ag.Name, 255),
                HAM_Bill_To_Contact__c    = ag.conference360__Bill_To_Contact__c,
                HAM_Bill_To_Account__c    = ag.conference360__Bill_To_Account__c,

                // Traceability
                HAM_BT_Source_Id__c       = ag.Id,
                HAM_BT_Attendee_Group__c  = ag.Id  // Lookup → conference360__Attendee_Group__c
            ));
        }

        List<Database.UpsertResult> results =
            Database.upsert(toUpsert, HAM_Event_Attendee_Group__c.HAM_BT_Source_Id__c, false);

        for (Database.UpsertResult r : results) {
            if (r.isSuccess()) { successCount++; }
            else               { failCount++; }
        }
        HAM_MigrationUtil.logErrors(results, toUpsert, 'HAM_Event_Attendee_Group__c');
    }

    // ── finish() ──────────────────────────────────────────────────────────────
    /**
     * @description Logs completion summary and chains to HAM_SalesDocumentMigrationBatch.
     * @param bc BatchableContext provided by the platform
     */
    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.DEBUG, 'HAM_AttendeeGroupMigrationBatch complete — '
            + successCount + ' succeeded, ' + failCount + ' failed.');
        HAM_MigrationUtil.logSummary('HAM_Event_Attendee_Group__c', successCount + failCount, successCount);
        Database.executeBatch(new HAM_SalesDocumentMigrationBatch(), 200);
    }
}