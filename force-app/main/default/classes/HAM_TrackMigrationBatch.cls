/**
 * HAM_TrackMigrationBatch
 * ─────────────────────────────────────────────────────────────────────────────
 * Migrates conference360__Track__c → HAM_Track__c.
 *
 * Key behaviours:
 *  - Builds btToCventEventMap in start() once (Stateful) to resolve parent
 *  - Scoped to tracks whose parent event was successfully migrated
 *  - Excludes orphaned tracks (no conference360__Event__c)
 *  - Idempotent: upsert on HAM_BT_Track_Id__c (External ID)
 *  - Chains → HAM_FAQMigrationBatch on finish()
 *
 * Change Log:
 *   v1.0  2026-04-21  NVV: ASC-XXXXX - Initial deployment
 *
 * @description Batch class to migrate conference360__Track__c records to HAM_Track__c.
 *              Runs after HAM_EventMigrationBatch and chains to HAM_FAQMigrationBatch.
 */
public class HAM_TrackMigrationBatch
        implements Database.Batchable<SObject>, Database.Stateful {

    @TestVisible private Map<Id, Id> btToCventEventMap = new Map<Id, Id>();
    public  Integer successCount = 0;
    public  Integer failCount    = 0;

    // ── start() ───────────────────────────────────────────────────────────────
    /**
     * @description Builds the BT-to-Cvent event map and returns a QueryLocator
     *              for all tracks linked to a migrated event.
     * @param bc BatchableContext provided by the platform.
     * @return Database.QueryLocator scoped to tracks for migrated events.
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
                   conference360__Event__c
            FROM   conference360__Track__c
            WHERE  conference360__Event__c IN :btToCventEventMap.keySet()
        ]);
    }

    // ── execute() ─────────────────────────────────────────────────────────────
    /**
     * @description Upserts a batch of tracks into HAM_Track__c.
     * @param bc     BatchableContext provided by the platform.
     * @param tracks Chunk of conference360__Track__c records to process.
     */
    public void execute(
        Database.BatchableContext bc,
        List<conference360__Track__c> tracks
    ) {
        List<HAM_Track__c> toUpsert = new List<HAM_Track__c>();

        for (conference360__Track__c t : tracks) {
            Id cventEventId = btToCventEventMap.get(t.conference360__Event__c);
            if (cventEventId == null) { continue; }

            toUpsert.add(new HAM_Track__c(
                Name               = HAM_MigrationUtil.truncate(t.Name, 80),
                HAM_Event__c       = cventEventId,
                HAM_BT_Track_Id__c = t.Id
            ));
        }

        List<Database.UpsertResult> results =
            Database.upsert(toUpsert, HAM_Track__c.HAM_BT_Track_Id__c, false);

        for (Database.UpsertResult r : results) {
            if (r.isSuccess()) { successCount++; }
            else               { failCount++; }
        }
        HAM_MigrationUtil.logErrors(results, toUpsert, 'HAM_Track__c');
    }

    // ── finish() ──────────────────────────────────────────────────────────────
    /**
     * @description Logs completion summary and chains to HAM_FAQMigrationBatch.
     * @param bc BatchableContext provided by the platform.
     */
    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.DEBUG, 'HAM_TrackMigrationBatch complete — '
            + successCount + ' succeeded, ' + failCount + ' failed.');
        HAM_MigrationUtil.logSummary('HAM_Track__c', successCount + failCount, successCount);
        Database.executeBatch(new HAM_FAQMigrationBatch(), 200);
    }
}