/**
 * HAM_OrderMigrationBatch
 * ─────────────────────────────────────────────────────────────────────────────
 * Migrates bt_stripe__Sales_Document__c → CventEvents__Cvent_Order__c.
 *
 * Key behaviours:
 *  - Scoped to sales documents whose event was successfully migrated
 *  - Resolves CventEvents__Attendee__c via CventEvents__Attendee__c.HAM_BT_Attendee_Id__c
 *    (chunk-based in execute() to avoid 50K SOQL row limit)
 *  - HAM_BT_Source_Id__c populated for downstream Order Item, Order Discount,
 *    and Transaction Order lookup resolution
 *  - Idempotent: upsert on HAM_BT_Source_Id__c (External ID)
 *  - Chains → HAM_OrderItemMigrationBatch on finish()
 *
 * Prerequisites:
 *  - HAM_EventMigrationBatch and HAM_AttendeeMigrationBatch must have run first
 *
 * Change Log:
 *   v1.0  05/08/2026  NVV: ASC-XXXXX - Phase 2 initial build
 *
 * @description Batch class to migrate bt_stripe__Sales_Document__c records to
 *              CventEvents__Cvent_Order__c.
 */
public class HAM_OrderMigrationBatch
        implements Database.Batchable<SObject>, Database.Stateful {

    // Map: BT Event Id → Cvent Event Id
    @TestVisible private Map<Id, Id> btToCventEventMap = new Map<Id, Id>();

    public Integer successCount = 0;
    public Integer failCount    = 0;

    // ── start() ───────────────────────────────────────────────────────────────
    /**
     * @description Builds the BT-to-Cvent event map and returns a QueryLocator
     *              for all sales documents scoped to migrated events.
     * @param bc BatchableContext provided by the platform.
     * @return Database.QueryLocator for bt_stripe__Sales_Document__c records.
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
                   bt_stripe__Contact__c,
                   bt_stripe__Balance_Due_Amount__c,
                   bt_stripe__Balance_Paid_Amount__c,
                   bt_stripe__Total_Amount__c,
                   bt_stripe__Stripe_Invoice_Id__c,
                   bt_stripe__Payment_Status__c,
                   bt_stripe__Billing_Method__c,
                   bt_stripe__Discount_Amount__c,
                   bt_stripe__Status__c,
                   bt_stripe__Issue_Date__c
            FROM   bt_stripe__Sales_Document__c
            WHERE  conference360__Event__c IN :btToCventEventMap.keySet()
        ]);
    }

    // ── execute() ─────────────────────────────────────────────────────────────
    /**
     * @description Upserts a batch of sales documents into CventEvents__Cvent_Order__c.
     * @param bc       BatchableContext provided by the platform.
     * @param salesDocs Chunk of bt_stripe__Sales_Document__c records to process.
     */
    public void execute(
        Database.BatchableContext bc,
        List<bt_stripe__Sales_Document__c> salesDocs
    ) {
        // Resolve Attendee via Contact (Sales Document has no direct Attendee lookup)
        // bt_stripe__Contact__c maps to the bill-to contact; find their Cvent Attendee record
        Set<Id> chunkContactIds = new Set<Id>();
        for (bt_stripe__Sales_Document__c sd : salesDocs) {
            if (sd.bt_stripe__Contact__c != null) {
                chunkContactIds.add(sd.bt_stripe__Contact__c);
            }
        }

        Map<Id, Id> chunkAttendeeMap = new Map<Id, Id>();
        for (CventEvents__Attendee__c ca : [
            SELECT Id, CventEvents__Contact__c
            FROM   CventEvents__Attendee__c
            WHERE  CventEvents__Contact__c IN :chunkContactIds
            AND    HAM_BT_Attendee_Id__c != null
        ]) {
            if (!chunkAttendeeMap.containsKey(ca.CventEvents__Contact__c)) {
                chunkAttendeeMap.put(ca.CventEvents__Contact__c, ca.Id);
            }
        }

        List<CventEvents__Cvent_Order__c> toUpsert = new List<CventEvents__Cvent_Order__c>();

        for (bt_stripe__Sales_Document__c sd : salesDocs) {
            toUpsert.add(new CventEvents__Cvent_Order__c(
                CventEvents__Attendee__c          = chunkAttendeeMap.get(sd.bt_stripe__Contact__c),
                CventEvents__Amount_Due__c         = sd.bt_stripe__Balance_Due_Amount__c,
                CventEvents__Amount_Paid__c        = sd.bt_stripe__Balance_Paid_Amount__c,
                CventEvents__Amount_Ordered__c     = sd.bt_stripe__Total_Amount__c,
                CventEvents__Invoice_Number__c     = HAM_MigrationUtil.truncate(
                                                        sd.bt_stripe__Stripe_Invoice_Id__c, 255),
                CventEvents__Payment_method__c     = HAM_MigrationUtil.truncate(
                                                        sd.bt_stripe__Payment_Status__c, 255),
                CventEvents__Type__c               = HAM_MigrationUtil.truncate(
                                                        sd.bt_stripe__Billing_Method__c, 255),
                CventEvents__Cancelled__c          = (sd.bt_stripe__Status__c == 'Cancelled'),
                CventEvents__Order_Created_Date__c = sd.bt_stripe__Issue_Date__c,
                HAM_BT_Source_Id__c                = sd.Id
            ));
        }

        List<Database.UpsertResult> results =
            Database.upsert(toUpsert, CventEvents__Cvent_Order__c.HAM_BT_Source_Id__c, false);

        for (Database.UpsertResult r : results) {
            if (r.isSuccess()) { successCount++; }
            else               { failCount++; }
        }
        HAM_MigrationUtil.logErrors(results, toUpsert, 'CventEvents__Cvent_Order__c');
    }

    // ── finish() ──────────────────────────────────────────────────────────────
    /**
     * @description Logs completion summary and chains to HAM_OrderItemMigrationBatch.
     * @param bc BatchableContext provided by the platform.
     */
    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.DEBUG, 'HAM_OrderMigrationBatch complete — '
            + successCount + ' succeeded, ' + failCount + ' failed.');
        HAM_MigrationUtil.logSummary('CventEvents__Cvent_Order__c', successCount + failCount, successCount);
        Database.executeBatch(new HAM_OrderItemMigrationBatch(), 200);
    }
}