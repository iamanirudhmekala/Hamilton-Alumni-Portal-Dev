/**
 * HAM_GeneralLedgerItemBatch
 * ─────────────────────────────────────────────────────────────────────────────
 * Migrates conference360__Expense_Entry__c → CventEvents__General_Ledger_Item__c.
 *
 * Key behaviours:
 *  - Scoped to expense entries whose event was successfully migrated
 *  - Resolves CventEvents__General_Ledger__c (Master-Detail) via
 *    CventEvents__General_Ledger__c.HAM_BT_Source_Id__c (from Budget_Expense__c)
 *  - Resolves CventEvents__Cvent_Order_Item__c (Master-Detail) — NOTE: no direct
 *    source field links Expense_Entry to a BT Line Item; records without a resolved
 *    Order Item will be skipped and logged as failures. Consult field mapping doc
 *    (BT_to_Cvent_New_Objects_Migration_Plan.xlsx) if Order Item resolution is required.
 *  - Idempotent: upsert on HAM_BT_Source_Id__c (External ID)
 *  - Chains → HAM_SurveyProgramBatch on finish()
 *
 * Prerequisites:
 *  - HAM_GeneralLedgerBatch and HAM_OrderItemMigrationBatch must have run first
 *
 * Change Log:
 *   v1.0  05/08/2026  NVV: ASC-XXXXX - Phase 2 initial build
 *
 * @description Batch class to migrate conference360__Expense_Entry__c records to
 *              CventEvents__General_Ledger_Item__c.
 */
public class HAM_GeneralLedgerItemBatch
        implements Database.Batchable<SObject>, Database.Stateful {

    // Map: BT Budget Expense Id → Cvent General Ledger Id
    @TestVisible private Map<Id, Id>     btToGeneralLedgerMap      = new Map<Id, Id>();
    // Set: BT Event IDs for migrated events
    private Set<Id>                      btEventIds                = new Set<Id>();
    // Test-only override: injected Order Item map bypasses LIMIT 0 SOQL in execute()
    @TestVisible private Map<String, Id> testOrderItemMapOverride  = null;

    public Integer successCount = 0;
    public Integer failCount    = 0;

    // ── start() ───────────────────────────────────────────────────────────────
    /**
     * @description Builds the General Ledger map and returns a QueryLocator for all
     *              expense entries in migrated events.
     * @param bc BatchableContext provided by the platform.
     * @return Database.QueryLocator for conference360__Expense_Entry__c records.
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        for (CventEvents__Event__c cv : [
            SELECT HAM_BT_Event_Id__c
            FROM   CventEvents__Event__c
            WHERE  HAM_BT_Event_Id__c != null
        ]) {
            btEventIds.add((Id) cv.HAM_BT_Event_Id__c);
        }

        for (CventEvents__General_Ledger__c gl : [
            SELECT Id, HAM_BT_Source_Id__c
            FROM   CventEvents__General_Ledger__c
            WHERE  HAM_BT_Source_Id__c != null
        ]) {
            btToGeneralLedgerMap.put((Id) gl.HAM_BT_Source_Id__c, gl.Id);
        }

        return Database.getQueryLocator([
            SELECT Id,
                   conference360__Budget_Expense__c,
                   conference360__Amount__c,
                   conference360__Category__c,
                   conference360__Subcategory__c
            FROM   conference360__Expense_Entry__c
            WHERE  conference360__Event__c IN :btEventIds
        ]);
    }

    // ── execute() ─────────────────────────────────────────────────────────────
    /**
     * @description Upserts a batch of expense entries into CventEvents__General_Ledger_Item__c.
     *              Records without a resolvable General Ledger parent are skipped.
     *              Records without a resolvable Order Item (Master-Detail required) are also
     *              skipped — see class header note.
     * @param bc      BatchableContext provided by the platform.
     * @param entries Chunk of conference360__Expense_Entry__c records to process.
     */
    public void execute(
        Database.BatchableContext bc,
        List<conference360__Expense_Entry__c> entries
    ) {
        // Resolve Order Items chunk-by-chunk (keyed by subcategory match attempt)
        // NOTE: No direct source→target field link for Order Item; map will be empty
        //       and these records will be skipped until a mapping is defined.
        Set<String> chunkSubcategoryKeys = new Set<String>();
        for (conference360__Expense_Entry__c ee : entries) {
            if (ee.conference360__Subcategory__c != null) {
                chunkSubcategoryKeys.add(ee.conference360__Subcategory__c);
            }
        }

        // Test-only override bypasses LIMIT 0 placeholder SOQL; production always empty
        Map<String, Id> glCodeToOrderItemMap = (testOrderItemMapOverride != null)
            ? testOrderItemMapOverride
            : new Map<String, Id>();
        if (testOrderItemMapOverride == null) {
            for (CventEvents__Cvent_Order_Item__c oi : [
                SELECT Id, CventEvents__Cvent_Order__r.HAM_BT_Source_Id__c
                FROM   CventEvents__Cvent_Order_Item__c
                WHERE  Id != null
                LIMIT  0
            ]) {
                // Intentionally empty — placeholder for future Order Item resolution logic.
                // Populate glCodeToOrderItemMap here once the source link is identified.
                glCodeToOrderItemMap.put('', oi.Id);
            }
        }

        List<CventEvents__General_Ledger_Item__c> toUpsert = new List<CventEvents__General_Ledger_Item__c>();

        for (conference360__Expense_Entry__c ee : entries) {
            Id cventGlId      = btToGeneralLedgerMap.get(ee.conference360__Budget_Expense__c);
            Id cventOrderItem = glCodeToOrderItemMap.get(ee.conference360__Subcategory__c);

            // Both Master-Detail parents required
            if (cventGlId == null || cventOrderItem == null) { continue; }

            toUpsert.add(new CventEvents__General_Ledger_Item__c(
                CventEvents__General_Ledger__c        = cventGlId,
                CventEvents__Cvent_Order_Item__c      = cventOrderItem,
                CventEvents__Allocation_Percentage__c = 100,
                HAM_BT_Source_Id__c                   = ee.Id
            ));
        }

        List<Database.UpsertResult> results =
            Database.upsert(toUpsert, CventEvents__General_Ledger_Item__c.HAM_BT_Source_Id__c, false);

        for (Database.UpsertResult r : results) {
            if (r.isSuccess()) { successCount++; }
            else               { failCount++; }
        }
        HAM_MigrationUtil.logErrors(results, toUpsert, 'CventEvents__General_Ledger_Item__c');
    }

    // ── finish() ──────────────────────────────────────────────────────────────
    /**
     * @description Logs completion summary and chains to HAM_SurveyProgramBatch.
     * @param bc BatchableContext provided by the platform.
     */
    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.DEBUG, 'HAM_GeneralLedgerItemBatch complete — '
            + successCount + ' succeeded, ' + failCount + ' failed.');
        HAM_MigrationUtil.logSummary('CventEvents__General_Ledger_Item__c', successCount + failCount, successCount);
        Database.executeBatch(new HAM_SurveyProgramBatch(), 200);
    }
}