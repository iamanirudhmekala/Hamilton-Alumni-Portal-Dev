/**
 * HAM_TransactionItemBatch
 * ─────────────────────────────────────────────────────────────────────────────
 * Creates CventEvents__Transaction_Item__c records (one per migrated transaction)
 * from bt_stripe__Transaction__c.
 *
 * Key behaviours:
 *  - Creates one Transaction Item per BT Transaction capturing the line-level amount
 *  - Resolves CventEvents__Transaction__c via CventEvents__Transaction__c.HAM_BT_Source_Id__c
 *  - CventEvents__Cvent_Product__c left null — no direct BT Transaction → Product link;
 *    Product is optionally resolvable if the source is extended in future
 *  - Idempotent: upsert on HAM_BT_Source_Id__c (External ID)
 *  - Chains → HAM_TransactionOrderBatch on finish()
 *
 * Prerequisites:
 *  - HAM_TransactionMigrationBatch must have run first
 *
 * Change Log:
 *   v1.0  05/08/2026  NVV: ASC-XXXXX - Phase 2 initial build
 *
 * @description Batch class to create CventEvents__Transaction_Item__c records from
 *              bt_stripe__Transaction__c.
 */
public class HAM_TransactionItemBatch
        implements Database.Batchable<SObject>, Database.Stateful {

    // Map: BT Transaction Id → Cvent Transaction Id
    @TestVisible private Map<Id, Id> btToCventTransactionMap = new Map<Id, Id>();
    // Set: Cvent Order BT Source IDs (scopes transactions to migrated orders)
    private Set<Id>                  migratedSalesDocIds     = new Set<Id>();

    public Integer successCount = 0;
    public Integer failCount    = 0;

    // ── start() ───────────────────────────────────────────────────────────────
    /**
     * @description Builds the BT-to-Cvent Transaction map and returns a QueryLocator
     *              for all transactions in migrated order scope.
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
            SELECT HAM_BT_Source_Id__c
            FROM   CventEvents__Cvent_Order__c
            WHERE  HAM_BT_Source_Id__c != null
        ]) {
            migratedSalesDocIds.add((Id) co.HAM_BT_Source_Id__c);
        }

        return Database.getQueryLocator([
            SELECT Id,
                   bt_stripe__Amount__c,
                   bt_stripe__Currency_ISO__c
            FROM   bt_stripe__Transaction__c
            WHERE  bt_stripe__Sales_Document__c IN :migratedSalesDocIds
        ]);
    }

    // ── execute() ─────────────────────────────────────────────────────────────
    /**
     * @description Upserts a batch of Transaction Item records into
     *              CventEvents__Transaction_Item__c.
     * @param bc           BatchableContext provided by the platform.
     * @param transactions Chunk of bt_stripe__Transaction__c records to process.
     */
    public void execute(
        Database.BatchableContext bc,
        List<bt_stripe__Transaction__c> transactions
    ) {
        List<CventEvents__Transaction_Item__c> toUpsert = new List<CventEvents__Transaction_Item__c>();

        for (bt_stripe__Transaction__c t : transactions) {
            Id cventTransactionId = btToCventTransactionMap.get(t.Id);
            if (cventTransactionId == null) { continue; }

            toUpsert.add(new CventEvents__Transaction_Item__c(
                CventEvents__Transaction__c = cventTransactionId,
                CventEvents__Amount__c      = t.bt_stripe__Amount__c,
                CventEvents__Currency__c    = HAM_MigrationUtil.truncate(
                                                 t.bt_stripe__Currency_ISO__c, 12),
                HAM_BT_Source_Id__c         = t.Id
            ));
        }

        List<Database.UpsertResult> results =
            Database.upsert(toUpsert, CventEvents__Transaction_Item__c.HAM_BT_Source_Id__c, false);

        for (Database.UpsertResult r : results) {
            if (r.isSuccess()) { successCount++; }
            else               { failCount++; }
        }
        HAM_MigrationUtil.logErrors(results, toUpsert, 'CventEvents__Transaction_Item__c');
    }

    // ── finish() ──────────────────────────────────────────────────────────────
    /**
     * @description Logs completion summary and chains to HAM_TransactionOrderBatch.
     * @param bc BatchableContext provided by the platform.
     */
    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.DEBUG, 'HAM_TransactionItemBatch complete — '
            + successCount + ' succeeded, ' + failCount + ' failed.');
        HAM_MigrationUtil.logSummary('CventEvents__Transaction_Item__c', successCount + failCount, successCount);
        Database.executeBatch(new HAM_TransactionOrderBatch(), 200);
    }
}