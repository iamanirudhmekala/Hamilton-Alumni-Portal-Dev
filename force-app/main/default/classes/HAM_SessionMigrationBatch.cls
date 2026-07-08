/**
 * HAM_SessionMigrationBatch
 * ─────────────────────────────────────────────────────────────────────────────
 * Migrates conference360__Session__c → HAM_Event_Session__c.
 *
 * Key behaviours:
 *  - Builds btToCventEventMap in start() once (Stateful) to resolve parent
 *  - Scoped to sessions whose parent event was successfully migrated
 *  - Idempotent: upsert on HAM_BT_Source_Id__c (External ID)
 *  - Populates HAM_BT_Session__c (lookup → conference360__Session__c)
 *  - Chains → HAM_TicketMigrationBatch on finish()
 *
 * Live data (ref event a6KU1000008006uMAA): 11 sessions
 *
 * Change Log:
 *   v1.0  2026-04-09  Initial deployment
 *   v1.1  2026-04-14  Fixed CventEvents_Event__c field name (single underscore)
 *   v1.2  2026-04-14  PMD static analysis fixes
 *   v1.3  2026-04-21  NVV: ASC-XXXXX - Now chains from HAM_FAQMigrationBatch (was HAM_EventMigrationBatch)
 * @description Batch class to migrate conference360__Session__c records to HAM_Event_Session__c.
 */
public class HAM_SessionMigrationBatch
        implements Database.Batchable<SObject>, Database.Stateful {

    private Map<Id, Id> btToCventEventMap = new Map<Id, Id>();
    public  Integer successCount = 0;
    public  Integer failCount    = 0;

    // ── start() ───────────────────────────────────────────────────────────────
    /**
     * @description Builds the BT-to-Cvent event map and returns a QueryLocator for all sessions.
     * @param bc BatchableContext provided by the platform
     * @return Database.QueryLocator scoped to sessions for migrated events
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
                   conference360__Start_Date__c,
                   conference360__End_Date__c,
                   conference360__Start_Time__c,
                   conference360__End_Time__c,
                   conference360__Description__c,
                   conference360__Room_Text__c,
                   conference360__Maximum_Registrants__c,
                   conference360__Status__c,
                   conference360__Type__c,
                   conference360__Session_Category__c,
                   conference360__Sort_Order__c
            FROM   conference360__Session__c
            WHERE  conference360__Event__c IN :btToCventEventMap.keySet()
        ]);
    }

    // ── execute() ─────────────────────────────────────────────────────────────
    /**
     * @description Upserts a batch of sessions into HAM_Event_Session__c.
     * @param bc       BatchableContext provided by the platform
     * @param sessions Chunk of conference360__Session__c records to process
     */
    public void execute(
        Database.BatchableContext bc,
        List<conference360__Session__c> sessions
    ) {
        List<HAM_Event_Session__c> toUpsert = new List<HAM_Event_Session__c>();

        for (conference360__Session__c s : sessions) {
            Id cventEventId = btToCventEventMap.get(s.conference360__Event__c);
            if (cventEventId == null) { continue; }

            toUpsert.add(new HAM_Event_Session__c(
                CventEvents_Event__c       = cventEventId,
                HAM_Session_Name__c        = HAM_MigrationUtil.truncate(s.Name, 255),
                HAM_Start_Date__c          = s.conference360__Start_Date__c,
                HAM_End_Date__c            = s.conference360__End_Date__c,
                HAM_Start_Time__c          = s.conference360__Start_Time__c,
                HAM_End_Time__c            = s.conference360__End_Time__c,
                HAM_Description__c         = s.conference360__Description__c,
                HAM_Location__c            = HAM_MigrationUtil.truncate(
                                                 s.conference360__Room_Text__c, 255),
                HAM_Capacity__c            = (s.conference360__Maximum_Registrants__c != null)
                                               ? (Integer) s.conference360__Maximum_Registrants__c
                                               : null,
                HAM_Status__c              = s.conference360__Status__c,
                HAM_Type__c                = s.conference360__Type__c,
                HAM_Session_Category__c    = s.conference360__Session_Category__c,
                HAM_Sort_Order__c          = (s.conference360__Sort_Order__c != null)
                                               ? (Integer) s.conference360__Sort_Order__c
                                               : null,
                HAM_BT_Source_Id__c        = s.Id,
                HAM_BT_Session__c          = s.Id
            ));
        }

        List<Database.UpsertResult> results =
            Database.upsert(toUpsert, HAM_Event_Session__c.HAM_BT_Source_Id__c, false);

        for (Database.UpsertResult r : results) {
            if (r.isSuccess()) { successCount++; }
            else               { failCount++; }
        }
        HAM_MigrationUtil.logErrors(results, toUpsert, 'HAM_Event_Session__c');
    }

    // ── finish() ──────────────────────────────────────────────────────────────
    /**
     * @description Logs completion summary and chains to HAM_TicketMigrationBatch.
     * @param bc BatchableContext provided by the platform
     */
    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.DEBUG, 'HAM_SessionMigrationBatch complete — '
            + successCount + ' succeeded, ' + failCount + ' failed.');
        HAM_MigrationUtil.logSummary('HAM_Event_Session__c', successCount + failCount, successCount);
        Database.executeBatch(new HAM_TicketMigrationBatch(), 200);
    }
}