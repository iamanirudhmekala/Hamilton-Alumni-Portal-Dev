/**
 * HAM_TransactionOrderBatch
 * ─────────────────────────────────────────────────────────────────────────────
 * Creates CventEvents__Transaction_Order__c junction records from
 * bt_stripe__Transaction__c records that are linked to a Sales Document.
 *
 * Key behaviours:
 *  - Scoped to transactions whose Sales Document belongs to a migrated Cvent Order
 *  - Resolves CventEvents__Transaction__c (Master-Detail) via
 *    CventEvents__Transaction__c.HAM_BT_Source_Id__c
 *  - Resolves CventEvents__Cvent_Order__c (Master-Detail) via
 *    CventEvents__Cvent_Order__c.HAM_BT_Source_Id__c (using bt_stripe__Sales_Document__c)
 *  - Records where either Master-Detail parent cannot be resolved are skipped
 *  - Idempotent: upsert on HAM_BT_Source_Id__c (External ID)
 *  - Chains → HAM_GeneralLedgerBatch on finish()
 *
 * Prerequisites:
 *  - HAM_TransactionMigrationBatch and HAM_OrderMigrationBatch must have run first
 *
 * Change Log:
 *   v1.0  05/08/2026  NVV: ASC-XXXXX - Phase 2 initial build
 *
 * @description Batch class to create CventEvents__Transaction_Order__c junction records
 *              linking migrated Transactions to migrated Orders.
 */
public class HAM_TransactionOrderBatch
        implements Database.Batchable<SObject>, Database.Stateful {

    // Map: BT Transaction Id → Cvent Transaction Id
    @TestVisible private Map<Id, Id> btToCventTransactionMap = new Map<Id, Id>();
    // Map: BT Sales Document Id → Cvent Order Id
    @TestVisible private Map<Id, Id> btToCventOrderMap       = new Map<Id, Id>();

    public Integer successCount = 0;
    public Integer failCount    = 0;

    // ── start() ───────────────────────────────────────────────────────────────
    /**
     * @description Builds Transaction and Order maps, then returns a QueryLocator
     *              for transactions with a Sales Document link.
     * @param bc BatchableContext provided by the platform.
     * @return Database.QueryLocator for bt_stripe__Transaction__c records.
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        for (CventEvents__Transaction__c ct : [
            SELECT Id, HAM_BT_Source_Id__c
            FROM   CventEvents__Transaction__c
            WHERE  HAM_BT_Source_Id__c != null
        ]) {
            btToCventTransactionMap.put((Id) ct.HAM_BT_Source_Id__c, ct.Id);
        }

        for (CventEvents__Cvent_Order__c co : [
            SELECT Id, HAM_BT_Source_Id__c
            FROM   CventEvents__Cvent_Order__c
            WHERE  HAM_BT_Source_Id__c != null
        ]) {
            btToCventOrderMap.put((Id) co.HAM_BT_Source_Id__c, co.Id);
        }

        return Database.getQueryLocator([
            SELECT Id,
                   bt_stripe__Sales_Document__c
            FROM   bt_stripe__Transaction__c
            WHERE  bt_stripe__Sales_Document__c IN :btToCventOrderMap.keySet()
        ]);
    }

    // ── execute() ─────────────────────────────────────────────────────────────
    /**
     * @description Upserts Transaction Order junction records into
     *              CventEvents__Transaction_Order__c.
     * @param bc           BatchableContext provided by the platform.
     * @param transactions Chunk of bt_stripe__Transaction__c records to process.
     */
    public void execute(
        Database.BatchableContext bc,
        List<bt_stripe__Transaction__c> transactions
    ) {
        List<CventEvents__Transaction_Order__c> toUpsert = new List<CventEvents__Transaction_Order__c>();

        for (bt_stripe__Transaction__c t : transactions) {
            Id cventTransactionId = btToCventTransactionMap.get(t.Id);
            Id cventOrderId       = btToCventOrderMap.get(t.bt_stripe__Sales_Document__c);

            // Both Master-Detail parents required — skip if either unresolved
            if (cventTransactionId == null || cventOrderId == null) { continue; }

            toUpsert.add(new CventEvents__Transaction_Order__c(
                CventEvents__Transaction__c  = cventTransactionId,
                CventEvents__Cvent_Order__c  = cventOrderId,
                HAM_BT_Source_Id__c          = t.Id
            ));
        }

        List<Database.UpsertResult> results =
            Database.upsert(toUpsert, CventEvents__Transaction_Order__c.HAM_BT_Source_Id__c, false);

        for (Database.UpsertResult r : results) {
            if (r.isSuccess()) { successCount++; }
            else               { failCount++; }
        }
        HAM_MigrationUtil.logErrors(results, toUpsert, 'CventEvents__Transaction_Order__c');
    }

    // ── finish() ──────────────────────────────────────────────────────────────
    /**
     * @description Logs completion summary and chains to HAM_GeneralLedgerBatch.
     * @param bc BatchableContext provided by the platform.
     */
    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.DEBUG, 'HAM_TransactionOrderBatch complete — '
            + successCount + ' succeeded, ' + failCount + ' failed.');
        HAM_MigrationUtil.logSummary('CventEvents__Transaction_Order__c', successCount + failCount, successCount);
        Database.executeBatch(new HAM_GeneralLedgerBatch(), 200);
    }
}