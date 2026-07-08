/**
 * HAM_FAQMigrationBatch
 * ─────────────────────────────────────────────────────────────────────────────
 * Migrates conference360__Event_FAQ__c → HAM_Event_FAQ__c.
 *
 * Key behaviours:
 *  - Builds btToCventEventMap in start() once (Stateful) to resolve parent
 *  - Scoped to FAQs whose parent event was successfully migrated
 *  - Excludes orphaned FAQs (no conference360__Event__c)
 *  - Idempotent: upsert on HAM_Key__c (External ID)
 *  - HAM_Key__c falls back to BT record Id when conference360__Key__c is null
 *  - Chains → HAM_SessionMigrationBatch on finish()
 *
 * Change Log:
 *   v1.0  2026-04-21  NVV: ASC-XXXXX - Initial deployment
 *
 * @description Batch class to migrate conference360__Event_FAQ__c records to HAM_Event_FAQ__c.
 *              Runs after HAM_TrackMigrationBatch and chains to HAM_SessionMigrationBatch.
 */
public class HAM_FAQMigrationBatch
        implements Database.Batchable<SObject>, Database.Stateful {

    @TestVisible private Map<Id, Id> btToCventEventMap = new Map<Id, Id>();
    public  Integer successCount = 0;
    public  Integer failCount    = 0;

    // ── start() ───────────────────────────────────────────────────────────────
    /**
     * @description Builds the BT-to-Cvent event map and returns a QueryLocator
     *              for all FAQs linked to a migrated event.
     * @param bc BatchableContext provided by the platform.
     * @return Database.QueryLocator scoped to FAQs for migrated events.
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        for (CventEvents__Event__c cv : [
            SELECT Id, HAM_BT_Event_Id__c
            FROM   CventEvents__Event__c
            WHERE  HAM_BT_Event_Id__c != null
            WITH SECURITY_ENFORCED
        ]) {
            btToCventEventMap.put((Id) cv.HAM_BT_Event_Id__c, cv.Id);
        }

        return Database.getQueryLocator([
            SELECT Id,
                   Name,
                   conference360__Event__c,
                   conference360__Question__c,
                   conference360__Answer__c,
                   conference360__Category__c,
                   conference360__Sort_Order__c,
                   conference360__Key__c,
                   conference360__Last_Publish_To_Platform_Requested_At__c
            FROM   conference360__Event_FAQ__c
            WHERE  conference360__Event__c IN :btToCventEventMap.keySet()
        ]);
    }

    // ── execute() ─────────────────────────────────────────────────────────────
    /**
     * @description Upserts a batch of FAQs into HAM_Event_FAQ__c.
     * @param bc   BatchableContext provided by the platform.
     * @param faqs Chunk of conference360__Event_FAQ__c records to process.
     */
    public void execute(
        Database.BatchableContext bc,
        List<conference360__Event_FAQ__c> faqs
    ) {
        List<HAM_Event_FAQ__c> toUpsert = new List<HAM_Event_FAQ__c>();

        for (conference360__Event_FAQ__c f : faqs) {
            Id cventEventId = btToCventEventMap.get(f.conference360__Event__c);
            if (cventEventId == null) { continue; }

            // Use BT Key if available, fall back to record Id for the 9 null-key records
            String upsertKey = String.isNotBlank(f.conference360__Key__c)
                ? f.conference360__Key__c
                : f.Id;

            toUpsert.add(new HAM_Event_FAQ__c(
                HAM_Event__c          = cventEventId,
                HAM_Question__c       = HAM_MigrationUtil.truncate(
                                            f.conference360__Question__c, 255),
                HAM_Answer__c         = f.conference360__Answer__c,
                HAM_Category__c       = HAM_MigrationUtil.truncate(
                                            f.conference360__Category__c, 255),
                HAM_Sort_Order__c     = f.conference360__Sort_Order__c,
                HAM_Key__c            = upsertKey,
                HAM_Last_Published_At__c
                                      = f.conference360__Last_Publish_To_Platform_Requested_At__c
            ));
        }

        List<Database.UpsertResult> results =
            Database.upsert(toUpsert, HAM_Event_FAQ__c.HAM_Key__c, false);

        for (Database.UpsertResult r : results) {
            if (r.isSuccess()) { successCount++; }
            else               { failCount++; }
        }
        HAM_MigrationUtil.logErrors(results, toUpsert, 'HAM_Event_FAQ__c');
    }

    // ── finish() ──────────────────────────────────────────────────────────────
    /**
     * @description Logs completion summary and chains to HAM_SessionMigrationBatch.
     * @param bc BatchableContext provided by the platform.
     */
    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.DEBUG, 'HAM_FAQMigrationBatch complete — '
            + successCount + ' succeeded, ' + failCount + ' failed.');
        HAM_MigrationUtil.logSummary('HAM_Event_FAQ__c', successCount + failCount, successCount);
        Database.executeBatch(new HAM_SessionMigrationBatch(), 200);
    }
}