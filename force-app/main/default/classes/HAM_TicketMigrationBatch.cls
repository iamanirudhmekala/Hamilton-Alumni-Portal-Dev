/**
 * HAM_TicketMigrationBatch
 * ─────────────────────────────────────────────────────────────────────────────
 * Migrates conference360__Event_Item__c → HAM_Event_Ticket__c.
 *
 * Key behaviours:
 *  - Scoped to items whose parent event was successfully migrated
 *  - Idempotent: upsert on HAM_BT_Source_Id__c
 *  - Preserves Hamilton-specific GL Number and Gift Designation fields
 *  - Populates HAM_BT_Event_Item__c (lookup → conference360__Event_Item__c)
 *  - Chains → HAM_SpeakerMigrationBatch on finish()
 *
 * Live data (ref event a6KU1000008006uMAA): 5 items
 *   EI-012872: NBA GAME ($200, sold 29)
 *   EI-012873: 1812 LCW Registration (free, sold 483)
 *   EI-012874: Broadway 'Art' ($200, sold 60)
 *   EI-012875: Broadway 'Just in Time' ($210, sold 37)
 *   EI-012876: Staff/Senior Staff (free, sold 0)
 *
 * Change Log:
 *   v1.0  2026-04-09  Initial deployment
 *   v1.1  2026-04-14  Fixed CventEvents_Event__c field name (single underscore)
 *   v1.2  2026-04-14  PMD static analysis fixes
 *   v1.3  2026-04-16  logSummary call in finish() to capture BT/Cvent counts
 * @description Batch class to migrate conference360__Event_Item__c records to HAM_Event_Ticket__c.
 */
public class HAM_TicketMigrationBatch
        implements Database.Batchable<SObject>, Database.Stateful {

    @TestVisible private Map<Id, Id> btToCventEventMap = new Map<Id, Id>();
    public  Integer successCount = 0;
    public  Integer failCount    = 0;

    // ── start() ───────────────────────────────────────────────────────────────
    /**
     * @description Builds the BT-to-Cvent event map and returns a QueryLocator for all event items.
     * @param bc BatchableContext provided by the platform
     * @return Database.QueryLocator scoped to event items for migrated events
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
                   Name,
                   conference360__Event__c,
                   conference360__Item_Name__c,
                   conference360__Description__c,
                   conference360__Description2__c,
                   conference360__Type__c,
                   conference360__Price__c,
                   conference360__Quantity_Made_Available__c,
                   conference360__Sold_Quantity__c,
                   conference360__Status__c,
                   conference360__Free__c,
                   conference360__Sales_Start_Date__c,
                   conference360__Sales_End_Date__c,
                   conference360__Sort_Order__c,
                   HAM_Event_Revenue_GL_Number__c,
                   HAM_Gift_Designation__c,
                   HAM_Event_Revenue_Amount__c,
                   HAM_Gift_Amount__c
            FROM   conference360__Event_Item__c
            WHERE  conference360__Event__c IN :btToCventEventMap.keySet()
        ]);
    }

    // ── execute() ─────────────────────────────────────────────────────────────
    /**
     * @description Upserts a batch of event items into HAM_Event_Ticket__c.
     * @param bc    BatchableContext provided by the platform
     * @param items Chunk of conference360__Event_Item__c records to process
     */
    public void execute(
        Database.BatchableContext bc,
        List<conference360__Event_Item__c> items
    ) {
        List<HAM_Event_Ticket__c> toUpsert = new List<HAM_Event_Ticket__c>();

        for (conference360__Event_Item__c ei : items) {
            Id cventEventId = btToCventEventMap.get(ei.conference360__Event__c);
            if (cventEventId == null) { continue; }

            toUpsert.add(new HAM_Event_Ticket__c(
                // Parent event lookup
                CventEvents_Event__c           = cventEventId,

                // Core fields
                HAM_Item_Name__c               = HAM_MigrationUtil.truncate(
                                                     ei.conference360__Item_Name__c, 255),
                HAM_Internal_Name__c           = HAM_MigrationUtil.truncate(ei.Name, 80),
                HAM_Type__c                    = ei.conference360__Type__c,
                HAM_Price__c                   = ei.conference360__Price__c,
                HAM_Quantity_Available__c      = (ei.conference360__Quantity_Made_Available__c != null)
                                                   ? (Integer) ei.conference360__Quantity_Made_Available__c
                                                   : null,
                HAM_Quantity_Sold__c           = (ei.conference360__Sold_Quantity__c != null)
                                                   ? (Integer) ei.conference360__Sold_Quantity__c
                                                   : null,
                HAM_Status__c                  = ei.conference360__Status__c,
                HAM_Free__c                    = ei.conference360__Free__c,
                HAM_Sales_Start_Date__c        = ei.conference360__Sales_Start_Date__c,
                HAM_Sales_End_Date__c          = ei.conference360__Sales_End_Date__c,
                HAM_Description__c             = ei.conference360__Description2__c,
                HAM_Sort_Order__c              = (ei.conference360__Sort_Order__c != null)
                                                   ? (Integer) ei.conference360__Sort_Order__c
                                                   : null,

                // Hamilton-specific fields
                HAM_Event_Revenue_GL__c        = HAM_MigrationUtil.truncate(
                                                     ei.HAM_Event_Revenue_GL_Number__c, 100),
                HAM_Gift_Designation__c        = ei.HAM_Gift_Designation__c,
                HAM_Event_Revenue_Amount__c    = ei.HAM_Event_Revenue_Amount__c,
                HAM_Gift_Amount__c             = ei.HAM_Gift_Amount__c,

                // Traceability
                HAM_BT_Source_Id__c            = ei.Id,
                HAM_BT_Event_Item__c           = ei.Id  // Lookup → conference360__Event_Item__c
            ));
        }

        List<Database.UpsertResult> results =
            Database.upsert(toUpsert, HAM_Event_Ticket__c.HAM_BT_Source_Id__c, false);

        for (Database.UpsertResult r : results) {
            if (r.isSuccess()) { successCount++; }
            else               { failCount++; }
        }
        HAM_MigrationUtil.logErrors(results, toUpsert, 'HAM_Event_Ticket__c');
    }

    // ── finish() ──────────────────────────────────────────────────────────────
    /**
     * @description Logs completion summary and chains to HAM_SpeakerMigrationBatch.
     * @param bc BatchableContext provided by the platform
     */
    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.DEBUG, 'HAM_TicketMigrationBatch complete — '
            + successCount + ' succeeded, ' + failCount + ' failed.');
        HAM_MigrationUtil.logSummary(
            'HAM_Event_Ticket__c',
            successCount + failCount,
            successCount
        );
        Database.executeBatch(new HAM_ItemSessionMigrationBatch(), 200);
    }
}