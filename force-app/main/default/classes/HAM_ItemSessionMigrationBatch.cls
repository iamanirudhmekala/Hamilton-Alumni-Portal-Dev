/**
 * HAM_ItemSessionMigrationBatch
 * ─────────────────────────────────────────────────────────────────────────────
 * Migrates conference360__Event_Item_Session__c → HAM_Event_Item_Session__c.
 *
 * Key behaviours:
 *  - Resolves HAM_Ticket__c via HAM_Event_Ticket__c.HAM_BT_Source_Id__c map
 *  - Resolves HAM_Session__c via HAM_Event_Session__c.HAM_BT_Source_Id__c map
 *  - Derives CventEvents_Event__c from the migrated ticket's event field
 *  - Idempotent: upsert on HAM_BT_Source_Id__c (External ID)
 *  - Populates HAM_BT_Event_Item_Session__c (lookup → conference360__Event_Item_Session__c)
 *  - Chains → HAM_SpeakerMigrationBatch on finish()
 *
 * Prerequisites:
 *  - HAM_SessionMigrationBatch and HAM_TicketMigrationBatch must have run first
 *
 * Change Log:
 *   v1.0  2026-04-17  Initial build
 * @description Batch class to migrate conference360__Event_Item_Session__c records to HAM_Event_Item_Session__c.
 */
public class HAM_ItemSessionMigrationBatch
        implements Database.Batchable<SObject>, Database.Stateful {

    // Map: BT Event Item Id → HAM_Event_Ticket__c Id
    @TestVisible private Map<Id, Id> btToHamTicketMap          = new Map<Id, Id>();
    // Map: BT Event Item Id → Cvent Event Id (derived from migrated ticket)
    @TestVisible private Map<Id, Id> btEventItemToCventEventMap = new Map<Id, Id>();
    // Map: BT Session Id → HAM_Event_Session__c Id
    private Map<Id, Id> btToHamSessionMap          = new Map<Id, Id>();

    public Integer successCount = 0;
    public Integer failCount    = 0;

    // ── start() ───────────────────────────────────────────────────────────────
    /**
     * @description Builds ticket, session, and event maps, then returns a QueryLocator for all event item sessions.
     * @param bc BatchableContext provided by the platform
     * @return Database.QueryLocator scoped to event item sessions for migrated tickets
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        Map<Id, Id> btToCventEventMap = new Map<Id, Id>();
        for (CventEvents__Event__c cv : [
            SELECT Id, HAM_BT_Event_Id__c
            FROM   CventEvents__Event__c
            WHERE  HAM_BT_Event_Id__c != null
        ]) {
            btToCventEventMap.put((Id) cv.HAM_BT_Event_Id__c, cv.Id);
        }
        Set<Id> cventEventIds = new Set<Id>(btToCventEventMap.values());

        for (HAM_Event_Ticket__c t : [
            SELECT Id, HAM_BT_Source_Id__c, CventEvents_Event__c
            FROM   HAM_Event_Ticket__c
            WHERE  HAM_BT_Source_Id__c != null
            AND    CventEvents_Event__c IN :cventEventIds
        ]) {
            btToHamTicketMap.put((Id) t.HAM_BT_Source_Id__c, t.Id);
            btEventItemToCventEventMap.put((Id) t.HAM_BT_Source_Id__c, t.CventEvents_Event__c);
        }

        for (HAM_Event_Session__c s : [
            SELECT Id, HAM_BT_Source_Id__c
            FROM   HAM_Event_Session__c
            WHERE  HAM_BT_Source_Id__c != null
            AND    CventEvents_Event__c IN :cventEventIds
        ]) {
            btToHamSessionMap.put((Id) s.HAM_BT_Source_Id__c, s.Id);
        }

        return Database.getQueryLocator([
            SELECT Id,
                   conference360__Event_Item__c,
                   conference360__Session__c,
                   conference360__Free__c,
                   conference360__Price__c,
                   conference360__Required__c
            FROM   conference360__Event_Item_Session__c
            WHERE  conference360__Event_Item__c IN :btToHamTicketMap.keySet()
        ]);
    }

    // ── execute() ─────────────────────────────────────────────────────────────
    /**
     * @description Upserts a batch of event item sessions into HAM_Event_Item_Session__c.
     * @param bc           BatchableContext provided by the platform
     * @param itemSessions Chunk of conference360__Event_Item_Session__c records to process
     */
    public void execute(
        Database.BatchableContext bc,
        List<conference360__Event_Item_Session__c> itemSessions
    ) {
        List<HAM_Event_Item_Session__c> toUpsert = new List<HAM_Event_Item_Session__c>();

        for (conference360__Event_Item_Session__c eis : itemSessions) {
            Id hamTicketId  = btToHamTicketMap.get(eis.conference360__Event_Item__c);
            Id cventEventId = btEventItemToCventEventMap.get(eis.conference360__Event_Item__c);
            if (hamTicketId == null || cventEventId == null) { continue; }

            Id hamSessionId = btToHamSessionMap.get(eis.conference360__Session__c);

            toUpsert.add(new HAM_Event_Item_Session__c(
                CventEvents_Event__c          = cventEventId,
                HAM_Ticket__c                 = hamTicketId,
                HAM_Session__c                = hamSessionId,
                HAM_Free__c                   = (eis.conference360__Free__c == true),
                HAM_Price__c                  = eis.conference360__Price__c,
                HAM_Required__c               = (eis.conference360__Required__c == true),
                HAM_BT_Source_Id__c           = eis.Id,
                HAM_BT_Event_Item_Session__c  = eis.Id
            ));
        }

        List<Database.UpsertResult> results =
            Database.upsert(toUpsert, HAM_Event_Item_Session__c.HAM_BT_Source_Id__c, false);

        for (Database.UpsertResult r : results) {
            if (r.isSuccess()) { successCount++; }
            else               { failCount++; }
        }
        HAM_MigrationUtil.logErrors(results, toUpsert, 'HAM_Event_Item_Session__c');
    }

    // ── finish() ──────────────────────────────────────────────────────────────
    /**
     * @description Logs completion summary and chains to HAM_SpeakerMigrationBatch.
     * @param bc BatchableContext provided by the platform
     */
    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.DEBUG, 'HAM_ItemSessionMigrationBatch complete — '
            + successCount + ' succeeded, ' + failCount + ' failed.');
        HAM_MigrationUtil.logSummary('HAM_Event_Item_Session__c', successCount + failCount, successCount);
        Database.executeBatch(new HAM_SpeakerMigrationBatch(), 200);
    }
}