/**
 * HAM_LineItemMigrationBatch
 * ─────────────────────────────────────────────────────────────────────────────
 * Migrates bt_stripe__Line_Item__c → HAM_Event_Line_Item__c.
 *
 * Key behaviours:
 *  - Resolves HAM_Sales_Document__c via HAM_Event_Sales_Document__c.HAM_BT_Source_Id__c
 *  - Resolves HAM_Attendee__c via CventEvents__Attendee__c.HAM_BT_Attendee_Id__c
 *  - Resolves HAM_Ticket__c via HAM_Event_Ticket__c.HAM_BT_Source_Id__c
 *  - Resolves HAM_Item_Session__c via HAM_Event_Item_Session__c.HAM_BT_Source_Id__c
 *  - Idempotent: upsert on HAM_BT_Source_Id__c (External ID)
 *  - Populates HAM_BT_Line_Item__c (lookup → bt_stripe__Line_Item__c)
 *  - Chains → HAM_SessionAttendeeMigrationBatch on finish()
 *
 * Prerequisites:
 *  - HAM_SalesDocumentMigrationBatch, HAM_ItemSessionMigrationBatch,
 *    HAM_TicketMigrationBatch, and HAM_AttendeeMigrationBatch must have run first
 *
 * Change Log:
 *   v1.0  2026-04-17  Initial build
 *   v1.1  2026-04-17  NVV: ASC-XXXXX - Add Unit_Price mapping
 *   v1.2  2026-04-28  NVV: ASC-XXXXX - Move btToCventAttendeeMap and btToHamSalesDocMap from start() to execute() to avoid 50K SOQL row limit
 * @description Batch class to migrate bt_stripe__Line_Item__c records to HAM_Event_Line_Item__c.
 */
public class HAM_LineItemMigrationBatch
        implements Database.Batchable<SObject>, Database.Stateful {

    // Map: BT Event Id → Cvent Event Id
    @TestVisible private Map<Id, Id> btToCventEventMap   = new Map<Id, Id>();
    // Map: BT Event Item Id → HAM_Event_Ticket__c Id
    private Map<Id, Id> btToHamTicketMap    = new Map<Id, Id>();
    // Map: BT Event Item Session Id → HAM_Event_Item_Session__c Id
    private Map<Id, Id> btToHamEisMap       = new Map<Id, Id>();

    public Integer successCount = 0;
    public Integer failCount    = 0;

    // ── start() ───────────────────────────────────────────────────────────────
    /**
     * @description Builds all lookup maps and returns a QueryLocator for all line items.
     * @param bc BatchableContext provided by the platform
     * @return Database.QueryLocator scoped to line items for migrated events
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        for (CventEvents__Event__c cv : [
            SELECT Id, HAM_BT_Event_Id__c
            FROM   CventEvents__Event__c
            WHERE  HAM_BT_Event_Id__c != null
        ]) {
            btToCventEventMap.put((Id) cv.HAM_BT_Event_Id__c, cv.Id);
        }
        Set<Id> cventEventIds = new Set<Id>(btToCventEventMap.values());

        for (HAM_Event_Ticket__c t : [
            SELECT Id, HAM_BT_Source_Id__c
            FROM   HAM_Event_Ticket__c
            WHERE  HAM_BT_Source_Id__c != null
            AND    CventEvents_Event__c IN :cventEventIds
        ]) {
            btToHamTicketMap.put((Id) t.HAM_BT_Source_Id__c, t.Id);
        }

        for (HAM_Event_Item_Session__c eis : [
            SELECT Id, HAM_BT_Source_Id__c
            FROM   HAM_Event_Item_Session__c
            WHERE  HAM_BT_Source_Id__c != null
            AND    CventEvents_Event__c IN :cventEventIds
        ]) {
            btToHamEisMap.put((Id) eis.HAM_BT_Source_Id__c, eis.Id);
        }

        return Database.getQueryLocator([
            SELECT Id,
                   conference360__Event__c,
                   conference360__Attendee__c,
                   conference360__Event_Item__c,
                   conference360__Event_Item_Session__c,
                   bt_stripe__Sales_Document__c,
                   bt_stripe__Item_Name__c,
                   bt_stripe__Quantity__c,
                   bt_stripe__Unit_Price__c,
                   bt_stripe__Net_Amount__c,
                   bt_stripe__Discount_Amount__c,
                   bt_stripe__Tax_Amount__c,
                   bt_stripe__Total_Amount__c
            FROM   bt_stripe__Line_Item__c
            WHERE  conference360__Event__c IN :btToCventEventMap.keySet()
        ]);
    }

    // ── execute() ─────────────────────────────────────────────────────────────
    /**
     * @description Upserts a batch of line items into HAM_Event_Line_Item__c.
     * @param bc        BatchableContext provided by the platform
     * @param lineItems Chunk of bt_stripe__Line_Item__c records to process
     */
    public void execute(
        Database.BatchableContext bc,
        List<bt_stripe__Line_Item__c> lineItems
    ) {
        Set<Id> chunkAttendeeIds   = new Set<Id>();
        Set<Id> chunkSalesDocIds   = new Set<Id>();
        for (bt_stripe__Line_Item__c li : lineItems) {
            if (li.conference360__Attendee__c   != null) { chunkAttendeeIds.add(li.conference360__Attendee__c); }
            if (li.bt_stripe__Sales_Document__c != null) { chunkSalesDocIds.add(li.bt_stripe__Sales_Document__c); }
        }

        Map<Id, Id> chunkAttendeeMap = new Map<Id, Id>();
        for (CventEvents__Attendee__c ca : [
            SELECT Id, HAM_BT_Attendee_Id__c
            FROM   CventEvents__Attendee__c
            WHERE  HAM_BT_Attendee_Id__c IN :chunkAttendeeIds
        ]) {
            chunkAttendeeMap.put((Id) ca.HAM_BT_Attendee_Id__c, ca.Id);
        }

        Map<Id, Id> chunkSalesDocMap = new Map<Id, Id>();
        for (HAM_Event_Sales_Document__c sd : [
            SELECT Id, HAM_BT_Source_Id__c
            FROM   HAM_Event_Sales_Document__c
            WHERE  HAM_BT_Source_Id__c IN :chunkSalesDocIds
        ]) {
            chunkSalesDocMap.put((Id) sd.HAM_BT_Source_Id__c, sd.Id);
        }

        List<HAM_Event_Line_Item__c> toUpsert = new List<HAM_Event_Line_Item__c>();

        for (bt_stripe__Line_Item__c li : lineItems) {
            Id cventEventId = btToCventEventMap.get(li.conference360__Event__c);
            if (cventEventId == null) { continue; }

            toUpsert.add(new HAM_Event_Line_Item__c(
                CventEvents_Event__c   = cventEventId,
                HAM_Attendee__c        = chunkAttendeeMap.get(li.conference360__Attendee__c),
                HAM_Sales_Document__c  = chunkSalesDocMap.get(li.bt_stripe__Sales_Document__c),
                HAM_Ticket__c          = btToHamTicketMap.get(li.conference360__Event_Item__c),
                HAM_Item_Session__c    = btToHamEisMap.get(li.conference360__Event_Item_Session__c),
                HAM_Item_Name__c       = HAM_MigrationUtil.truncate(li.bt_stripe__Item_Name__c, 255),
                HAM_Quantity__c        = li.bt_stripe__Quantity__c,
                HAM_Unit_Price__c      = li.bt_stripe__Unit_Price__c,
                HAM_Net_Amount__c      = li.bt_stripe__Net_Amount__c,
                HAM_Discount_Amount__c = li.bt_stripe__Discount_Amount__c,
                HAM_Tax_Amount__c      = li.bt_stripe__Tax_Amount__c,
                HAM_Total_Amount__c    = li.bt_stripe__Total_Amount__c,
                HAM_BT_Source_Id__c    = li.Id,
                HAM_BT_Line_Item__c    = li.Id
            ));
        }

        List<Database.UpsertResult> results =
            Database.upsert(toUpsert, HAM_Event_Line_Item__c.HAM_BT_Source_Id__c, false);

        for (Database.UpsertResult r : results) {
            if (r.isSuccess()) { successCount++; }
            else               { failCount++; }
        }
        HAM_MigrationUtil.logErrors(results, toUpsert, 'HAM_Event_Line_Item__c');
    }

    // ── finish() ──────────────────────────────────────────────────────────────
    /**
     * @description Logs completion summary and chains to HAM_SessionAttendeeMigrationBatch.
     * @param bc BatchableContext provided by the platform
     */
    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.DEBUG, 'HAM_LineItemMigrationBatch complete — '
            + successCount + ' succeeded, ' + failCount + ' failed.');
        HAM_MigrationUtil.logSummary('HAM_Event_Line_Item__c', successCount + failCount, successCount);
        Database.executeBatch(new HAM_SessionAttendeeMigrationBatch(), 200);
    }
}