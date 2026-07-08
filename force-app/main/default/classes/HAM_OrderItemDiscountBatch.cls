/**
 * HAM_OrderItemDiscountBatch
 * ─────────────────────────────────────────────────────────────────────────────
 * Creates CventEvents__Order_Item_Discount__c junction records from
 * bt_stripe__Line_Item__c records that have a discount code applied.
 *
 * Key behaviours:
 *  - Scoped to line items with a discount code (bt_stripe__Code__c != null)
 *    whose event was successfully migrated
 *  - Resolves CventEvents__Order_Item__c (Master-Detail) via
 *    CventEvents__Cvent_Order_Item__c.HAM_BT_Source_Id__c
 *  - Resolves CventEvents__Discount__c via CventEvents__Discount__c.HAM_BT_Source_Id__c
 *  - Records where either parent cannot be resolved are skipped
 *  - Idempotent: upsert on HAM_BT_Source_Id__c (External ID)
 *  - Chains → HAM_TransactionMigrationBatch on finish()
 *
 * Prerequisites:
 *  - HAM_DiscountMigrationBatch and HAM_OrderItemMigrationBatch must have run first
 *
 * Change Log:
 *   v1.0  05/08/2026  NVV: ASC-XXXXX - Phase 2 initial build
 *
 * @description Batch class to create CventEvents__Order_Item_Discount__c junction
 *              records from bt_stripe__Line_Item__c records with applied discount codes.
 */
public class HAM_OrderItemDiscountBatch
        implements Database.Batchable<SObject>, Database.Stateful {

    // Map: BT Line Item Id → Cvent Order Item Id
    @TestVisible private Map<Id, Id> btToCventOrderItemMap = new Map<Id, Id>();
    // Map: BT Code Id → Cvent Discount Id
    @TestVisible private Map<Id, Id> btToCventDiscountMap  = new Map<Id, Id>();

    public Integer successCount = 0;
    public Integer failCount    = 0;

    // ── start() ───────────────────────────────────────────────────────────────
    /**
     * @description Builds Order Item and Discount maps, then returns a QueryLocator
     *              for line items with an applied discount code.
     * @param bc BatchableContext provided by the platform.
     * @return Database.QueryLocator for bt_stripe__Line_Item__c records.
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        for (CventEvents__Cvent_Order_Item__c oi : [
            SELECT Id, HAM_BT_Source_Id__c
            FROM   CventEvents__Cvent_Order_Item__c
            WHERE  HAM_BT_Source_Id__c != null
        ]) {
            btToCventOrderItemMap.put((Id) oi.HAM_BT_Source_Id__c, oi.Id);
        }

        for (CventEvents__Discount__c cd : [
            SELECT Id, HAM_BT_Source_Id__c
            FROM   CventEvents__Discount__c
            WHERE  HAM_BT_Source_Id__c != null
        ]) {
            btToCventDiscountMap.put((Id) cd.HAM_BT_Source_Id__c, cd.Id);
        }

        // Build event scope
        Set<Id> btEventIds = new Set<Id>();
        for (CventEvents__Event__c cv : [
            SELECT HAM_BT_Event_Id__c
            FROM   CventEvents__Event__c
            WHERE  HAM_BT_Event_Id__c != null
        ]) {
            btEventIds.add((Id) cv.HAM_BT_Event_Id__c);
        }

        return Database.getQueryLocator([
            SELECT Id,
                   bt_stripe__Code__c,
                   bt_stripe__Code_Discount_Amount__c
            FROM   bt_stripe__Line_Item__c
            WHERE  bt_stripe__Code__c != null
            AND    conference360__Event__c IN :btEventIds
        ]);
    }

    // ── execute() ─────────────────────────────────────────────────────────────
    /**
     * @description Upserts Order Item Discount junction records into
     *              CventEvents__Order_Item_Discount__c.
     * @param bc        BatchableContext provided by the platform.
     * @param lineItems Chunk of bt_stripe__Line_Item__c records to process.
     */
    public void execute(
        Database.BatchableContext bc,
        List<bt_stripe__Line_Item__c> lineItems
    ) {
        List<CventEvents__Order_Item_Discount__c> toUpsert = new List<CventEvents__Order_Item_Discount__c>();

        for (bt_stripe__Line_Item__c li : lineItems) {
            Id cventOrderItemId = btToCventOrderItemMap.get(li.Id);
            Id cventDiscountId  = btToCventDiscountMap.get(li.bt_stripe__Code__c);

            // Both Master-Detail parents required — skip if either unresolved
            if (cventOrderItemId == null || cventDiscountId == null) { continue; }

            toUpsert.add(new CventEvents__Order_Item_Discount__c(
                CventEvents__Order_Item__c = cventOrderItemId,
                CventEvents__Discount__c   = cventDiscountId,
                CventEvents__Amount__c     = (li.bt_stripe__Code_Discount_Amount__c != null)
                                             ? li.bt_stripe__Code_Discount_Amount__c.longValue()
                                             : 0,
                HAM_BT_Source_Id__c        = li.Id
            ));
        }

        List<Database.UpsertResult> results =
            Database.upsert(toUpsert, CventEvents__Order_Item_Discount__c.HAM_BT_Source_Id__c, false);

        for (Database.UpsertResult r : results) {
            if (r.isSuccess()) { successCount++; }
            else               { failCount++; }
        }
        HAM_MigrationUtil.logErrors(results, toUpsert, 'CventEvents__Order_Item_Discount__c');
    }

    // ── finish() ──────────────────────────────────────────────────────────────
    /**
     * @description Logs completion summary and chains to HAM_TransactionMigrationBatch.
     * @param bc BatchableContext provided by the platform.
     */
    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.DEBUG, 'HAM_OrderItemDiscountBatch complete — '
            + successCount + ' succeeded, ' + failCount + ' failed.');
        HAM_MigrationUtil.logSummary('CventEvents__Order_Item_Discount__c', successCount + failCount, successCount);
        Database.executeBatch(new HAM_TransactionMigrationBatch(), 200);
    }
}