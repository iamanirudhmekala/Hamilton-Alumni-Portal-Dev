/**
 * HAM_OrderDiscountBatch
 * ─────────────────────────────────────────────────────────────────────────────
 * Creates CventEvents__Order_Discount__c junction records from
 * bt_stripe__Sales_Document__c records that have a discount code applied.
 *
 * Key behaviours:
 *  - Scoped to sales documents with a discount code (bt_stripe__Discount_Code__c != null)
 *    whose event was successfully migrated
 *  - Resolves CventEvents__Order__c (Master-Detail) via CventEvents__Cvent_Order__c.HAM_BT_Source_Id__c
 *  - Resolves CventEvents__Discount__c via CventEvents__Discount__c.HAM_BT_Source_Id__c
 *  - Records where either parent cannot be resolved are skipped
 *  - Idempotent: upsert on HAM_BT_Source_Id__c (External ID)
 *  - Chains → HAM_OrderItemDiscountBatch on finish()
 *
 * Prerequisites:
 *  - HAM_DiscountMigrationBatch and HAM_OrderMigrationBatch must have run first
 *
 * Change Log:
 *   v1.0  05/08/2026  NVV: ASC-XXXXX - Phase 2 initial build
 *
 * @description Batch class to create CventEvents__Order_Discount__c junction records
 *              from bt_stripe__Sales_Document__c records with applied discount codes.
 */
public class HAM_OrderDiscountBatch
        implements Database.Batchable<SObject>, Database.Stateful {

    // Map: BT Sales Document Id → Cvent Order Id
    @TestVisible private Map<Id, Id> btToCventOrderMap    = new Map<Id, Id>();
    // Map: BT Code Id → Cvent Discount Id
    @TestVisible private Map<Id, Id> btToCventDiscountMap = new Map<Id, Id>();

    public Integer successCount = 0;
    public Integer failCount    = 0;

    // ── start() ───────────────────────────────────────────────────────────────
    /**
     * @description Builds Order and Discount maps, then returns a QueryLocator for
     *              sales documents with an applied discount code.
     * @param bc BatchableContext provided by the platform.
     * @return Database.QueryLocator for bt_stripe__Sales_Document__c records.
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        for (CventEvents__Cvent_Order__c co : [
            SELECT Id, HAM_BT_Source_Id__c
            FROM   CventEvents__Cvent_Order__c
            WHERE  HAM_BT_Source_Id__c != null
        ]) {
            btToCventOrderMap.put((Id) co.HAM_BT_Source_Id__c, co.Id);
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
                   bt_stripe__Discount_Code__c,
                   bt_stripe__Discount_Amount__c
            FROM   bt_stripe__Sales_Document__c
            WHERE  bt_stripe__Discount_Code__c != null
            AND    conference360__Event__c IN :btEventIds
        ]);
    }

    // ── execute() ─────────────────────────────────────────────────────────────
    /**
     * @description Upserts Order Discount junction records into CventEvents__Order_Discount__c.
     * @param bc       BatchableContext provided by the platform.
     * @param salesDocs Chunk of bt_stripe__Sales_Document__c records to process.
     */
    public void execute(
        Database.BatchableContext bc,
        List<bt_stripe__Sales_Document__c> salesDocs
    ) {
        List<CventEvents__Order_Discount__c> toUpsert = new List<CventEvents__Order_Discount__c>();

        for (bt_stripe__Sales_Document__c sd : salesDocs) {
            Id cventOrderId    = btToCventOrderMap.get(sd.Id);
            Id cventDiscountId = btToCventDiscountMap.get(sd.bt_stripe__Discount_Code__c);

            // Both Master-Detail parents required — skip if either unresolved
            if (cventOrderId == null || cventDiscountId == null) { continue; }

            toUpsert.add(new CventEvents__Order_Discount__c(
                CventEvents__Order__c    = cventOrderId,
                CventEvents__Discount__c = cventDiscountId,
                CventEvents__Amount__c   = (sd.bt_stripe__Discount_Amount__c != null)
                                           ? sd.bt_stripe__Discount_Amount__c.longValue()
                                           : 0,
                HAM_BT_Source_Id__c      = sd.Id
            ));
        }

        List<Database.UpsertResult> results =
            Database.upsert(toUpsert, CventEvents__Order_Discount__c.HAM_BT_Source_Id__c, false);

        for (Database.UpsertResult r : results) {
            if (r.isSuccess()) { successCount++; }
            else               { failCount++; }
        }
        HAM_MigrationUtil.logErrors(results, toUpsert, 'CventEvents__Order_Discount__c');
    }

    // ── finish() ──────────────────────────────────────────────────────────────
    /**
     * @description Logs completion summary and chains to HAM_OrderItemDiscountBatch.
     * @param bc BatchableContext provided by the platform.
     */
    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.DEBUG, 'HAM_OrderDiscountBatch complete — '
            + successCount + ' succeeded, ' + failCount + ' failed.');
        HAM_MigrationUtil.logSummary('CventEvents__Order_Discount__c', successCount + failCount, successCount);
        Database.executeBatch(new HAM_OrderItemDiscountBatch(), 200);
    }
}