/**
 * HAM_GeneralLedgerBatch
 * ─────────────────────────────────────────────────────────────────────────────
 * Migrates conference360__Budget_Expense__c → CventEvents__General_Ledger__c.
 *
 * Key behaviours:
 *  - Scoped to budget expenses whose event was successfully migrated
 *  - HAM_BT_Source_Id__c populated for downstream General Ledger Item lookup
 *  - Idempotent: upsert on HAM_BT_Source_Id__c (External ID)
 *  - Chains → HAM_GeneralLedgerItemBatch on finish()
 *
 * Prerequisites:
 *  - HAM_EventMigrationBatch must have run first
 *
 * Change Log:
 *   v1.0  05/08/2026  NVV: ASC-XXXXX - Phase 2 initial build
 *
 * @description Batch class to migrate conference360__Budget_Expense__c records to
 *              CventEvents__General_Ledger__c.
 */
public class HAM_GeneralLedgerBatch
        implements Database.Batchable<SObject>, Database.Stateful {

    // Set: BT Event IDs for migrated events
    @TestVisible private Set<Id> btEventIds = new Set<Id>();

    public Integer successCount = 0;
    public Integer failCount    = 0;

    // ── start() ───────────────────────────────────────────────────────────────
    /**
     * @description Collects migrated event IDs and returns a QueryLocator for all
     *              budget expense records in those events.
     * @param bc BatchableContext provided by the platform.
     * @return Database.QueryLocator for conference360__Budget_Expense__c records.
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        for (CventEvents__Event__c cv : [
            SELECT HAM_BT_Event_Id__c
            FROM   CventEvents__Event__c
            WHERE  HAM_BT_Event_Id__c != null
        ]) {
            btEventIds.add((Id) cv.HAM_BT_Event_Id__c);
        }

        return Database.getQueryLocator([
            SELECT Id,
                   Name,
                   conference360__Category__c,
                   conference360__Subcategory__c,
                   conference360__Description__c
            FROM   conference360__Budget_Expense__c
            WHERE  conference360__Event__c IN :btEventIds
        ]);
    }

    // ── execute() ─────────────────────────────────────────────────────────────
    /**
     * @description Upserts a batch of budget expenses into CventEvents__General_Ledger__c.
     * @param bc       BatchableContext provided by the platform.
     * @param expenses Chunk of conference360__Budget_Expense__c records to process.
     */
    public void execute(
        Database.BatchableContext bc,
        List<conference360__Budget_Expense__c> expenses
    ) {
        List<CventEvents__General_Ledger__c> toUpsert = new List<CventEvents__General_Ledger__c>();

        for (conference360__Budget_Expense__c be : expenses) {
            toUpsert.add(new CventEvents__General_Ledger__c(
                CventEvents__Code__c        = HAM_MigrationUtil.truncate(
                                                 be.conference360__Subcategory__c, 100),
                CventEvents__Item_Name__c   = HAM_MigrationUtil.truncate(
                                                 be.conference360__Category__c, 36),
                CventEvents__Description__c = HAM_MigrationUtil.truncate(
                                                 be.conference360__Description__c, 500),
                HAM_BT_Source_Id__c         = be.Id
            ));
        }

        List<Database.UpsertResult> results =
            Database.upsert(toUpsert, CventEvents__General_Ledger__c.HAM_BT_Source_Id__c, false);

        for (Database.UpsertResult r : results) {
            if (r.isSuccess()) { successCount++; }
            else               { failCount++; }
        }
        HAM_MigrationUtil.logErrors(results, toUpsert, 'CventEvents__General_Ledger__c');
    }

    // ── finish() ──────────────────────────────────────────────────────────────
    /**
     * @description Logs completion summary and chains to HAM_GeneralLedgerItemBatch.
     * @param bc BatchableContext provided by the platform.
     */
    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.DEBUG, 'HAM_GeneralLedgerBatch complete — '
            + successCount + ' succeeded, ' + failCount + ' failed.');
        HAM_MigrationUtil.logSummary('CventEvents__General_Ledger__c', successCount + failCount, successCount);
        Database.executeBatch(new HAM_GeneralLedgerItemBatch(), 200);
    }
}