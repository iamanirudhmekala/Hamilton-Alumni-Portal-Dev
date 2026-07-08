/**
 * HAM_DiscountMigrationBatch
 * ─────────────────────────────────────────────────────────────────────────────
 * Migrates bt_stripe__Code__c → CventEvents__Discount__c.
 *
 * Key behaviours:
 *  - Queries all BT discount codes (global, not scoped to an event)
 *  - HAM_BT_Source_Id__c populated for downstream Order Discount and Order Item
 *    Discount lookup resolution
 *  - Idempotent: upsert on HAM_BT_Source_Id__c (External ID)
 *  - Chains → HAM_OrderMigrationBatch on finish()
 *
 * Prerequisites:
 *  - HAM_ProductMigrationBatch must have run first
 *
 * Change Log:
 *   v1.0  05/08/2026  NVV: ASC-XXXXX - Phase 2 initial build
 *
 * @description Batch class to migrate bt_stripe__Code__c records to
 *              CventEvents__Discount__c.
 */
public class HAM_DiscountMigrationBatch
        implements Database.Batchable<SObject>, Database.Stateful {

    public Integer successCount = 0;
    public Integer failCount    = 0;

    // ── start() ───────────────────────────────────────────────────────────────
    /**
     * @description Returns a QueryLocator for all BT discount code records.
     * @param bc BatchableContext provided by the platform.
     * @return Database.QueryLocator for bt_stripe__Code__c records.
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id,
                   Name,
                   bt_stripe__Type__c,
                   bt_stripe__Discount_Amount__c,
                   bt_stripe__Discount_Percentage__c
            FROM   bt_stripe__Code__c
        ]);
    }

    // ── execute() ─────────────────────────────────────────────────────────────
    /**
     * @description Upserts a batch of discount codes into CventEvents__Discount__c.
     * @param bc    BatchableContext provided by the platform.
     * @param codes Chunk of bt_stripe__Code__c records to process.
     */
    public void execute(
        Database.BatchableContext bc,
        List<bt_stripe__Code__c> codes
    ) {
        List<CventEvents__Discount__c> toUpsert = new List<CventEvents__Discount__c>();

        for (bt_stripe__Code__c c : codes) {
            // Value: prefer flat amount; fall back to percentage
            Decimal discountValue = (c.bt_stripe__Discount_Amount__c != null
                                    && c.bt_stripe__Discount_Amount__c > 0)
                                    ? c.bt_stripe__Discount_Amount__c
                                    : c.bt_stripe__Discount_Percentage__c;

            toUpsert.add(new CventEvents__Discount__c(
                CventEvents__Code__c    = HAM_MigrationUtil.truncate(c.Name, 36),
                CventEvents__Type__c    = HAM_MigrationUtil.truncate(c.bt_stripe__Type__c, 255),
                CventEvents__Value__c   = discountValue,
                HAM_BT_Source_Id__c     = c.Id
            ));
        }

        List<Database.UpsertResult> results =
            Database.upsert(toUpsert, CventEvents__Discount__c.HAM_BT_Source_Id__c, false);

        for (Database.UpsertResult r : results) {
            if (r.isSuccess()) { successCount++; }
            else               { failCount++; }
        }
        HAM_MigrationUtil.logErrors(results, toUpsert, 'CventEvents__Discount__c');
    }

    // ── finish() ──────────────────────────────────────────────────────────────
    /**
     * @description Logs completion summary and chains to HAM_OrderMigrationBatch.
     * @param bc BatchableContext provided by the platform.
     */
    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.DEBUG, 'HAM_DiscountMigrationBatch complete — '
            + successCount + ' succeeded, ' + failCount + ' failed.');
        HAM_MigrationUtil.logSummary('CventEvents__Discount__c', successCount + failCount, successCount);
        Database.executeBatch(new HAM_OrderMigrationBatch(), 200);
    }
}