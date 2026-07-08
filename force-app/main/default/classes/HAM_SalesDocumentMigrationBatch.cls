/**
 * HAM_SalesDocumentMigrationBatch
 * ─────────────────────────────────────────────────────────────────────────────
 * Migrates bt_stripe__Sales_Document__c → HAM_Event_Sales_Document__c.
 *
 * Key behaviours:
 *  - Scoped to sales documents whose event was successfully migrated
 *  - Resolves CventEvents_Event__c via btToCventEventMap
 *  - HAM_Attendee__c and HAM_Attendee_Group__c left null — no direct attendee
 *    link on the BT sales document; populated downstream if needed
 *  - Idempotent: upsert on HAM_BT_Source_Id__c (External ID)
 *  - Populates HAM_BT_Sales_Document__c (lookup → bt_stripe__Sales_Document__c)
 *  - Chains → HAM_AttendeeMigrationBatch on finish()
 *    (Runs BEFORE Attendee so HAM_Sales_Document__c lookup on CventEvents__Attendee__c
 *    can resolve via btToHamSalesDocMap.)
 *
 * Prerequisites:
 *  - HAM_EventMigrationBatch must have run first (event map is the only dependency)
 *
 * Change Log:
 *   v1.0  2026-04-17  Initial build
 *   v1.1  2026-04-17  NVV: ASC-XXXXX - Add Subtotal, Tax, Total, Discount, Bill_To_Contact mappings
 *   v1.2  2026-04-17  NVV: ASC-XXXXX - Chain reordered to run before Attendee (enables
 *                     HAM_Sales_Document__c lookup resolution during Attendee migration)
 *   v1.3  2026-04-24  NVV: ASC-XXXXX - Add 24 missing field mappings: status, full billing
 *                     address, email, phone, dates, payment gateway, Stripe audit fields
 * @description Batch class to migrate bt_stripe__Sales_Document__c records to HAM_Event_Sales_Document__c.
 */
public class HAM_SalesDocumentMigrationBatch
        implements Database.Batchable<SObject>, Database.Stateful {

    // Map: BT Event Id → Cvent Event Id
    @TestVisible private Map<Id, Id> btToCventEventMap = new Map<Id, Id>();

    public Integer successCount = 0;
    public Integer failCount    = 0;

    // ── start() ───────────────────────────────────────────────────────────────
    /**
     * @description Builds the BT-to-Cvent event map and returns a QueryLocator for all sales documents.
     * @param bc BatchableContext provided by the platform
     * @return Database.QueryLocator scoped to sales documents for migrated events
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
                   conference360__Event__c,
                   bt_stripe__Balance_Due_Amount__c,
                   bt_stripe__Balance_Paid_Amount__c,
                   bt_stripe__Payment_Status__c,
                   bt_stripe__Subtotal_Amount__c,
                   bt_stripe__Tax_Amount__c,
                   bt_stripe__Total_Amount__c,
                   bt_stripe__Discount_Amount__c,
                   bt_stripe__Bill_To_Contact__c,
                   bt_stripe__Status__c,
                   bt_stripe__Bill_To__c,
                   bt_stripe__Bill_To_First_Name__c,
                   bt_stripe__Bill_To_Last_Name__c,
                   bt_stripe__Bill_To_Name__c,
                   bt_stripe__Bill_To_Street__c,
                   bt_stripe__Street_2_Bill_To__c,
                   bt_stripe__Bill_To_City__c,
                   bt_stripe__Bill_To_State__c,
                   bt_stripe__Bill_To_Postal_Code__c,
                   bt_stripe__Bill_To_Country__c,
                   bt_stripe__Email__c,
                   bt_stripe__Phone__c,
                   bt_stripe__Issue_Date__c,
                   bt_stripe__Due_Date__c,
                   bt_stripe__Paid_In_Full__c,
                   bt_stripe__Payment_Gateway__c,
                   bt_stripe__Net_Amount__c,
                   bt_stripe__Currency_ISO__c,
                   bt_stripe__Stripe_Invoice_Id__c,
                   bt_stripe__Stripe_Hosted_Invoice_Link__c,
                   bt_stripe__Memo__c,
                   bt_stripe__Billing_Method__c,
                   bt_stripe__Tax_Rate__c
            FROM   bt_stripe__Sales_Document__c
            WHERE  conference360__Event__c IN :btToCventEventMap.keySet()
        ]);
    }

    // ── execute() ─────────────────────────────────────────────────────────────
    /**
     * @description Upserts a batch of sales documents into HAM_Event_Sales_Document__c.
     * @param bc       BatchableContext provided by the platform
     * @param salesDocs Chunk of bt_stripe__Sales_Document__c records to process
     */
    public void execute(
        Database.BatchableContext bc,
        List<bt_stripe__Sales_Document__c> salesDocs
    ) {
        List<HAM_Event_Sales_Document__c> toUpsert = new List<HAM_Event_Sales_Document__c>();

        for (bt_stripe__Sales_Document__c sd : salesDocs) {
            Id cventEventId = btToCventEventMap.get(sd.conference360__Event__c);
            if (cventEventId == null) { continue; }

            toUpsert.add(new HAM_Event_Sales_Document__c(
                CventEvents_Event__c      = cventEventId,
                HAM_Balance_Due__c        = sd.bt_stripe__Balance_Due_Amount__c,
                HAM_Balance_Paid__c       = sd.bt_stripe__Balance_Paid_Amount__c,
                HAM_Payment_Status__c     = HAM_MigrationUtil.truncate(
                                               sd.bt_stripe__Payment_Status__c, 255),
                HAM_Subtotal_Amount__c    = sd.bt_stripe__Subtotal_Amount__c,
                HAM_Tax_Amount__c         = sd.bt_stripe__Tax_Amount__c,
                HAM_Total_Amount__c       = sd.bt_stripe__Total_Amount__c,
                HAM_Discount_Amount__c    = sd.bt_stripe__Discount_Amount__c,
                HAM_Bill_To_Contact__c    = sd.bt_stripe__Bill_To_Contact__c,

                // ── Status & billing details ───────────────────────────────────
                HAM_Status__c             = HAM_MigrationUtil.truncate(sd.bt_stripe__Status__c, 255),
                HAM_Bill_To_Account__c    = sd.bt_stripe__Bill_To__c,
                HAM_Bill_To_First_Name__c = HAM_MigrationUtil.truncate(sd.bt_stripe__Bill_To_First_Name__c, 255),
                HAM_Bill_To_Last_Name__c  = HAM_MigrationUtil.truncate(sd.bt_stripe__Bill_To_Last_Name__c, 255),
                HAM_Bill_To_Name__c       = HAM_MigrationUtil.truncate(sd.bt_stripe__Bill_To_Name__c, 255),
                HAM_Bill_To_Street__c     = HAM_MigrationUtil.truncate(sd.bt_stripe__Bill_To_Street__c, 255),
                HAM_Bill_To_Street_2__c   = HAM_MigrationUtil.truncate(sd.bt_stripe__Street_2_Bill_To__c, 255),
                HAM_Bill_To_City__c       = HAM_MigrationUtil.truncate(sd.bt_stripe__Bill_To_City__c, 80),
                HAM_Bill_To_State__c      = HAM_MigrationUtil.truncate(sd.bt_stripe__Bill_To_State__c, 80),
                HAM_Bill_To_Postal_Code__c= HAM_MigrationUtil.truncate(sd.bt_stripe__Bill_To_Postal_Code__c, 20),
                HAM_Bill_To_Country__c    = HAM_MigrationUtil.truncate(sd.bt_stripe__Bill_To_Country__c, 80),
                HAM_Email__c              = sd.bt_stripe__Email__c,
                HAM_Phone__c              = sd.bt_stripe__Phone__c,

                // ── Dates & payment audit trail ────────────────────────────────
                HAM_Issue_Date__c         = sd.bt_stripe__Issue_Date__c,
                HAM_Due_Date__c           = sd.bt_stripe__Due_Date__c,
                HAM_Paid_In_Full__c       = sd.bt_stripe__Paid_In_Full__c,
                HAM_Payment_Gateway__c    = sd.bt_stripe__Payment_Gateway__c,

                // ── Financial fields ───────────────────────────────────────────
                HAM_Net_Amount__c         = sd.bt_stripe__Net_Amount__c,
                HAM_Currency_ISO__c       = HAM_MigrationUtil.truncate(sd.bt_stripe__Currency_ISO__c, 10),
                HAM_Tax_Rate__c           = sd.bt_stripe__Tax_Rate__c,
                HAM_Billing_Method__c     = HAM_MigrationUtil.truncate(sd.bt_stripe__Billing_Method__c, 255),

                // ── Stripe audit trail ─────────────────────────────────────────
                HAM_Stripe_Invoice_Id__c  = HAM_MigrationUtil.truncate(sd.bt_stripe__Stripe_Invoice_Id__c, 255),
                HAM_Stripe_Invoice_Link__c= sd.bt_stripe__Stripe_Hosted_Invoice_Link__c,
                HAM_Memo__c               = sd.bt_stripe__Memo__c,

                HAM_BT_Source_Id__c       = sd.Id,
                HAM_BT_Sales_Document__c  = sd.Id
            ));
        }

        List<Database.UpsertResult> results =
            Database.upsert(toUpsert, HAM_Event_Sales_Document__c.HAM_BT_Source_Id__c, false);

        for (Database.UpsertResult r : results) {
            if (r.isSuccess()) { successCount++; }
            else               { failCount++; }
        }
        HAM_MigrationUtil.logErrors(results, toUpsert, 'HAM_Event_Sales_Document__c');
    }

    // ── finish() ──────────────────────────────────────────────────────────────
    /**
     * @description Logs completion summary and chains to HAM_AttendeeMigrationBatch.
     * @param bc BatchableContext provided by the platform
     */
    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.DEBUG, 'HAM_SalesDocumentMigrationBatch complete — '
            + successCount + ' succeeded, ' + failCount + ' failed.');
        HAM_MigrationUtil.logSummary('HAM_Event_Sales_Document__c', successCount + failCount, successCount);
        Database.executeBatch(new HAM_AttendeeMigrationBatch(), 200);
    }
}