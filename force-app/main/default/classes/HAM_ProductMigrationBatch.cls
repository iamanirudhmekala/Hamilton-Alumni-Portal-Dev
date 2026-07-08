/**
 * HAM_ProductMigrationBatch
 * ─────────────────────────────────────────────────────────────────────────────
 * Migrates conference360__Event_Item__c → CventEvents__Cvent_Product__c.
 *
 * Key behaviours:
 *  - Scoped to event items whose event was successfully migrated
 *  - HAM_BT_Source_Id__c populated for downstream Order Item and Transaction Item
 *    lookup resolution
 *  - Idempotent: upsert on HAM_BT_Source_Id__c (External ID)
 *  - Chains → HAM_DiscountMigrationBatch on finish()
 *
 * Prerequisites:
 *  - HAM_EventMigrationBatch must have run first
 *
 * Change Log:
 *   v1.0  05/08/2026  NVV: ASC-XXXXX - Phase 2 initial build
 *
 * @description Batch class to migrate conference360__Event_Item__c records to
 *              CventEvents__Cvent_Product__c.
 */
public class HAM_ProductMigrationBatch
        implements Database.Batchable<SObject>, Database.Stateful {

    // Map: BT Event Id → Cvent Event Id
    @TestVisible private Map<Id, Id> btToCventEventMap = new Map<Id, Id>();

    public Integer successCount = 0;
    public Integer failCount    = 0;

    // ── start() ───────────────────────────────────────────────────────────────
    /**
     * @description Builds the BT-to-Cvent event map and returns a QueryLocator
     *              for all event items in migrated events.
     * @param bc BatchableContext provided by the platform.
     * @return Database.QueryLocator for conference360__Event_Item__c records.
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
                   conference360__Type__c
            FROM   conference360__Event_Item__c
            WHERE  conference360__Event__c IN :btToCventEventMap.keySet()
        ]);
    }

    // ── execute() ─────────────────────────────────────────────────────────────
    /**
     * @description Upserts a batch of event items into CventEvents__Cvent_Product__c.
     * @param bc    BatchableContext provided by the platform.
     * @param items Chunk of conference360__Event_Item__c records to process.
     */
    public void execute(
        Database.BatchableContext bc,
        List<conference360__Event_Item__c> items
    ) {
        List<CventEvents__Cvent_Product__c> toUpsert = new List<CventEvents__Cvent_Product__c>();

        for (conference360__Event_Item__c ei : items) {
            toUpsert.add(new CventEvents__Cvent_Product__c(
                CventEvents__Type__c  = HAM_MigrationUtil.truncate(ei.conference360__Type__c, 255),
                HAM_BT_Source_Id__c   = ei.Id
            ));
        }

        List<Database.UpsertResult> results =
            Database.upsert(toUpsert, CventEvents__Cvent_Product__c.HAM_BT_Source_Id__c, false);

        for (Database.UpsertResult r : results) {
            if (r.isSuccess()) { successCount++; }
            else               { failCount++; }
        }
        HAM_MigrationUtil.logErrors(results, toUpsert, 'CventEvents__Cvent_Product__c');
    }

    // ── finish() ──────────────────────────────────────────────────────────────
    /**
     * @description Logs completion summary and chains to HAM_DiscountMigrationBatch.
     * @param bc BatchableContext provided by the platform.
     */
    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.DEBUG, 'HAM_ProductMigrationBatch complete — '
            + successCount + ' succeeded, ' + failCount + ' failed.');
        HAM_MigrationUtil.logSummary('CventEvents__Cvent_Product__c', successCount + failCount, successCount);
        Database.executeBatch(new HAM_DiscountMigrationBatch(), 200);
    }
}