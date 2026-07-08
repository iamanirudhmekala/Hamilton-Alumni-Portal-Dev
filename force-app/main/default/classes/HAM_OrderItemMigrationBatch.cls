/**
 * HAM_OrderItemMigrationBatch
 * ─────────────────────────────────────────────────────────────────────────────
 * Migrates bt_stripe__Line_Item__c → CventEvents__Cvent_Order_Item__c.
 *
 * Key behaviours:
 *  - Scoped to line items whose event was successfully migrated
 *  - Resolves CventEvents__Cvent_Order__c via CventEvents__Cvent_Order__c.HAM_BT_Source_Id__c
 *  - Resolves CventEvents__Attendee__c via CventEvents__Attendee__c.HAM_BT_Attendee_Id__c
 *    (chunk-based in execute() to avoid 50K SOQL row limit)
 *  - Resolves CventEvents__Product__c via CventEvents__Cvent_Product__c.HAM_BT_Source_Id__c
 *  - HAM_BT_Source_Id__c populated for downstream Order Item Discount and
 *    General Ledger Item lookup resolution
 *  - Idempotent: upsert on HAM_BT_Source_Id__c (External ID)
 *  - Chains → HAM_OrderDiscountBatch on finish()
 *
 * Prerequisites:
 *  - HAM_ProductMigrationBatch, HAM_OrderMigrationBatch, and
 *    HAM_AttendeeMigrationBatch must have run first
 *
 * Change Log:
 *   v1.0  05/08/2026  NVV: ASC-XXXXX - Phase 2 initial build
 *
 * @description Batch class to migrate bt_stripe__Line_Item__c records to
 *              CventEvents__Cvent_Order_Item__c.
 */
public class HAM_OrderItemMigrationBatch
        implements Database.Batchable<SObject>, Database.Stateful {

    // Map: BT Event Id → Cvent Event Id
    @TestVisible private Map<Id, Id> btToCventEventMap  = new Map<Id, Id>();
    // Map: BT Sales Document Id → Cvent Order Id
    private Map<Id, Id>              btToCventOrderMap  = new Map<Id, Id>();
    // Map: BT Event Item Id → Cvent Product Id
    private Map<Id, Id>              btToProductMap     = new Map<Id, Id>();

    public Integer successCount = 0;
    public Integer failCount    = 0;

    // ── start() ───────────────────────────────────────────────────────────────
    /**
     * @description Builds event, order, and product maps, then returns a
     *              QueryLocator for all line items in migrated events.
     * @param bc BatchableContext provided by the platform.
     * @return Database.QueryLocator for bt_stripe__Line_Item__c records.
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        for (CventEvents__Event__c cv : [
            SELECT Id, HAM_BT_Event_Id__c
            FROM   CventEvents__Event__c
            WHERE  HAM_BT_Event_Id__c != null
        ]) {
            btToCventEventMap.put((Id) cv.HAM_BT_Event_Id__c, cv.Id);
        }

        for (CventEvents__Cvent_Order__c co : [
            SELECT Id, HAM_BT_Source_Id__c
            FROM   CventEvents__Cvent_Order__c
            WHERE  HAM_BT_Source_Id__c != null
        ]) {
            btToCventOrderMap.put((Id) co.HAM_BT_Source_Id__c, co.Id);
        }

        for (CventEvents__Cvent_Product__c cp : [
            SELECT Id, HAM_BT_Source_Id__c
            FROM   CventEvents__Cvent_Product__c
            WHERE  HAM_BT_Source_Id__c != null
        ]) {
            btToProductMap.put((Id) cp.HAM_BT_Source_Id__c, cp.Id);
        }

        return Database.getQueryLocator([
            SELECT Id,
                   conference360__Event__c,
                   conference360__Attendee__c,
                   conference360__Event_Item__c,
                   bt_stripe__Sales_Document__c,
                   bt_stripe__Item_Name__c,
                   bt_stripe__Balance_Due_Amount__c,
                   bt_stripe__Balance_Paid_Amount__c,
                   bt_stripe__Total_Amount__c,
                   bt_stripe__Quantity__c
            FROM   bt_stripe__Line_Item__c
            WHERE  conference360__Event__c IN :btToCventEventMap.keySet()
        ]);
    }

    // ── execute() ─────────────────────────────────────────────────────────────
    /**
     * @description Upserts a batch of line items into CventEvents__Cvent_Order_Item__c.
     * @param bc        BatchableContext provided by the platform.
     * @param lineItems Chunk of bt_stripe__Line_Item__c records to process.
     */
    public void execute(
        Database.BatchableContext bc,
        List<bt_stripe__Line_Item__c> lineItems
    ) {
        // Resolve attendees chunk-by-chunk to avoid 50K row limit
        Set<Id> chunkAttendeeIds = new Set<Id>();
        for (bt_stripe__Line_Item__c li : lineItems) {
            if (li.conference360__Attendee__c != null) {
                chunkAttendeeIds.add(li.conference360__Attendee__c);
            }
        }

        Map<Id, Id> chunkAttendeeMap = new Map<Id, Id>();
        for (CventEvents__Attendee__c ca : [
            SELECT Id, HAM_BT_Attendee_Id__c
            FROM   CventEvents__Attendee__c
            WHERE  HAM_BT_Attendee_Id__c IN :chunkAttendeeIds
        ]) {
            chunkAttendeeMap.put((Id) ca.HAM_BT_Attendee_Id__c, ca.Id);
        }

        List<CventEvents__Cvent_Order_Item__c> toUpsert = new List<CventEvents__Cvent_Order_Item__c>();

        for (bt_stripe__Line_Item__c li : lineItems) {
            toUpsert.add(new CventEvents__Cvent_Order_Item__c(
                CventEvents__Cvent_Order__c        = btToCventOrderMap.get(li.bt_stripe__Sales_Document__c),
                CventEvents__Attendee__c           = chunkAttendeeMap.get(li.conference360__Attendee__c),
                CventEvents__Product__c            = btToProductMap.get(li.conference360__Event_Item__c),
                CventEvents__Name__c               = HAM_MigrationUtil.truncate(li.bt_stripe__Item_Name__c, 255),
                CventEvents__Amount_Due__c         = li.bt_stripe__Balance_Due_Amount__c,
                CventEvents__Amount_Paid__c        = li.bt_stripe__Balance_Paid_Amount__c,
                CventEvents__Amount_Ordered__c     = li.bt_stripe__Total_Amount__c,
                HAM_BT_Source_Id__c                = li.Id
            ));
        }

        List<Database.UpsertResult> results =
            Database.upsert(toUpsert, CventEvents__Cvent_Order_Item__c.HAM_BT_Source_Id__c, false);

        for (Database.UpsertResult r : results) {
            if (r.isSuccess()) { successCount++; }
            else               { failCount++; }
        }
        HAM_MigrationUtil.logErrors(results, toUpsert, 'CventEvents__Cvent_Order_Item__c');
    }

    // ── finish() ──────────────────────────────────────────────────────────────
    /**
     * @description Logs completion summary and chains to HAM_OrderDiscountBatch.
     * @param bc BatchableContext provided by the platform.
     */
    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.DEBUG, 'HAM_OrderItemMigrationBatch complete — '
            + successCount + ' succeeded, ' + failCount + ' failed.');
        HAM_MigrationUtil.logSummary('CventEvents__Cvent_Order_Item__c', successCount + failCount, successCount);
        Database.executeBatch(new HAM_OrderDiscountBatch(), 200);
    }
}