/**
 * HAM_TransactionMigrationBatch
 * ─────────────────────────────────────────────────────────────────────────────
 * Migrates bt_stripe__Transaction__c → CventEvents__Transaction__c.
 *
 * Key behaviours:
 *  - Scoped to transactions whose Sales Document belongs to a migrated event
 *  - HAM_BT_Source_Id__c populated for downstream Transaction Item and
 *    Transaction Order lookup resolution
 *  - Idempotent: upsert on HAM_BT_Source_Id__c (External ID)
 *  - Chains → HAM_TransactionItemBatch on finish()
 *
 * Prerequisites:
 *  - HAM_OrderMigrationBatch must have run first (Sales Document scope)
 *
 * Change Log:
 *   v1.0  05/08/2026  NVV: ASC-XXXXX - Phase 2 initial build
 *
 * @description Batch class to migrate bt_stripe__Transaction__c records to
 *              CventEvents__Transaction__c.
 */
public class HAM_TransactionMigrationBatch
        implements Database.Batchable<SObject>, Database.Stateful {

    // Set: Cvent Order BT Source IDs (scopes transactions to migrated orders)
    @TestVisible private Set<Id> migratedSalesDocIds = new Set<Id>();

    public Integer successCount = 0;
    public Integer failCount    = 0;

    // ── start() ───────────────────────────────────────────────────────────────
    /**
     * @description Collects migrated Sales Document IDs and returns a QueryLocator
     *              for all transactions linked to those documents.
     * @param bc BatchableContext provided by the platform.
     * @return Database.QueryLocator for bt_stripe__Transaction__c records.
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
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
                   bt_stripe__Currency_ISO__c,
                   bt_stripe__Transaction_Id__c,
                   bt_stripe__Paid__c,
                   bt_stripe__Transaction_Type__c,
                   bt_stripe__Transaction_Sub_Type__c,
                   bt_stripe__Invoice_Number__c,
                   bt_stripe__Timestamp__c,
                   CreatedDate
            FROM   bt_stripe__Transaction__c
            WHERE  bt_stripe__Sales_Document__c IN :migratedSalesDocIds
        ]);
    }

    // ── execute() ─────────────────────────────────────────────────────────────
    /**
     * @description Upserts a batch of transactions into CventEvents__Transaction__c.
     * @param bc           BatchableContext provided by the platform.
     * @param transactions Chunk of bt_stripe__Transaction__c records to process.
     */
    public void execute(
        Database.BatchableContext bc,
        List<bt_stripe__Transaction__c> transactions
    ) {
        List<CventEvents__Transaction__c> toUpsert = new List<CventEvents__Transaction__c>();

        for (bt_stripe__Transaction__c t : transactions) {
            toUpsert.add(new CventEvents__Transaction__c(
                CventEvents__Amount__c                   = t.bt_stripe__Amount__c,
                CventEvents__Currency__c                 = HAM_MigrationUtil.truncate(
                                                              t.bt_stripe__Currency_ISO__c, 30),
                CventEvents__Reference_Number__c         = HAM_MigrationUtil.truncate(
                                                              t.bt_stripe__Transaction_Id__c, 50),
                CventEvents__Success__c                  = (t.bt_stripe__Paid__c == true),
                CventEvents__Payment_Method__c           = HAM_MigrationUtil.truncate(
                                                              t.bt_stripe__Transaction_Type__c, 50),
                CventEvents__Payment_Type__c             = HAM_MigrationUtil.truncate(
                                                              t.bt_stripe__Transaction_Sub_Type__c, 50),
                CventEvents__Journal_Number__c           = HAM_MigrationUtil.truncate(
                                                              t.bt_stripe__Invoice_Number__c, 50),
                CventEvents__Batch_Number__c             = HAM_MigrationUtil.truncate(
                                                              t.bt_stripe__Timestamp__c, 50),
                CventEvents__Transaction_Created_Date__c = t.CreatedDate,
                HAM_BT_Source_Id__c                      = t.Id
            ));
        }

        List<Database.UpsertResult> results =
            Database.upsert(toUpsert, CventEvents__Transaction__c.HAM_BT_Source_Id__c, false);

        for (Database.UpsertResult r : results) {
            if (r.isSuccess()) { successCount++; }
            else               { failCount++; }
        }
        HAM_MigrationUtil.logErrors(results, toUpsert, 'CventEvents__Transaction__c');
    }

    // ── finish() ──────────────────────────────────────────────────────────────
    /**
     * @description Logs completion summary and chains to HAM_TransactionItemBatch.
     * @param bc BatchableContext provided by the platform.
     */
    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.DEBUG, 'HAM_TransactionMigrationBatch complete — '
            + successCount + ' succeeded, ' + failCount + ' failed.');
        HAM_MigrationUtil.logSummary('CventEvents__Transaction__c', successCount + failCount, successCount);
        Database.executeBatch(new HAM_TransactionItemBatch(), 200);
    }
}