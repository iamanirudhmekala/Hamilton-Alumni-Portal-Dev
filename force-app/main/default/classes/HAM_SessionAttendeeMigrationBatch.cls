/**
 * HAM_SessionAttendeeMigrationBatch
 * ─────────────────────────────────────────────────────────────────────────────
 * Migrates conference360__Session_Attendee__c → HAM_Event_Session_Attendee__c.
 *
 * Key behaviours:
 *  - Resolves HAM_Session__c via HAM_Event_Session__c.HAM_BT_Source_Id__c
 *  - Resolves HAM_Attendee__c via CventEvents__Attendee__c.HAM_BT_Attendee_Id__c
 *  - Resolves HAM_Event_Item_Session__c via HAM_Event_Item_Session__c.HAM_BT_Source_Id__c
 *  - Derives CventEvents_Event__c from the migrated session's event field
 *  - HAM_Contact__c passed directly from BT (Contact OWD = ReadWrite, no access issues)
 *  - Idempotent: upsert on HAM_BT_Source_Id__c (External ID)
 *  - Populates HAM_BT_Session_Attendee__c (lookup → conference360__Session_Attendee__c)
 *  - Chains → HAM_FormMigrationBatch on finish()
 *
 * Prerequisites:
 *  - HAM_ItemSessionMigrationBatch and HAM_AttendeeMigrationBatch must have run first
 *
 * Change Log:
 *   v1.0  2026-04-17  Initial build
 *   v1.1  2026-04-28  NVV: ASC-XXXXX - Move btToCventAttendeeMap from start() to execute() to avoid 50K SOQL row limit
 * @description Batch class to migrate conference360__Session_Attendee__c records to HAM_Event_Session_Attendee__c.
 */
public class HAM_SessionAttendeeMigrationBatch
        implements Database.Batchable<SObject>, Database.Stateful {

    // Map: BT Session Id → HAM_Event_Session__c Id
    private Map<Id, Id> btToHamSessionMap    = new Map<Id, Id>();
    // Map: BT Session Id → Cvent Event Id
    private Map<Id, Id> btSessionToEventMap  = new Map<Id, Id>();
    // Map: BT Event Item Session Id → HAM_Event_Item_Session__c Id
    private Map<Id, Id> btToHamEisMap        = new Map<Id, Id>();

    public Integer successCount = 0;
    public Integer failCount    = 0;

    // ── start() ───────────────────────────────────────────────────────────────
    /**
     * @description Builds all lookup maps and returns a QueryLocator for all session attendees.
     * @param bc BatchableContext provided by the platform
     * @return Database.QueryLocator scoped to session attendees for migrated sessions
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        for (HAM_Event_Session__c s : [
            SELECT Id, HAM_BT_Source_Id__c, CventEvents_Event__c
            FROM   HAM_Event_Session__c
            WHERE  HAM_BT_Source_Id__c != null
        ]) {
            btToHamSessionMap.put((Id) s.HAM_BT_Source_Id__c, s.Id);
            btSessionToEventMap.put((Id) s.HAM_BT_Source_Id__c, s.CventEvents_Event__c);
        }
        Set<Id> cventEventIds = new Set<Id>(btSessionToEventMap.values());

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
                   conference360__Session__c,
                   conference360__Attendee__c,
                   conference360__Contact__c,
                   conference360__Event_Item_Session__c,
                   conference360__Registration_Status__c
            FROM   conference360__Session_Attendee__c
            WHERE  conference360__Session__c IN :btToHamSessionMap.keySet()
        ]);
    }

    // ── execute() ─────────────────────────────────────────────────────────────
    /**
     * @description Upserts a batch of session attendees into HAM_Event_Session_Attendee__c.
     * @param bc              BatchableContext provided by the platform
     * @param sessionAttendees Chunk of conference360__Session_Attendee__c records to process
     */
    public void execute(
        Database.BatchableContext bc,
        List<conference360__Session_Attendee__c> sessionAttendees
    ) {
        Set<Id> chunkAttendeeIds = new Set<Id>();
        for (conference360__Session_Attendee__c sa : sessionAttendees) {
            if (sa.conference360__Attendee__c != null) { chunkAttendeeIds.add(sa.conference360__Attendee__c); }
        }
        Map<Id, Id> chunkAttendeeMap = new Map<Id, Id>();
        for (CventEvents__Attendee__c ca : [
            SELECT Id, HAM_BT_Attendee_Id__c
            FROM   CventEvents__Attendee__c
            WHERE  HAM_BT_Attendee_Id__c IN :chunkAttendeeIds
        ]) {
            chunkAttendeeMap.put((Id) ca.HAM_BT_Attendee_Id__c, ca.Id);
        }

        List<HAM_Event_Session_Attendee__c> toUpsert = new List<HAM_Event_Session_Attendee__c>();

        for (conference360__Session_Attendee__c sa : sessionAttendees) {
            Id hamSessionId = btToHamSessionMap.get(sa.conference360__Session__c);
            Id cventEventId = btSessionToEventMap.get(sa.conference360__Session__c);
            if (hamSessionId == null || cventEventId == null) { continue; }

            toUpsert.add(new HAM_Event_Session_Attendee__c(
                CventEvents_Event__c        = cventEventId,
                HAM_Session__c              = hamSessionId,
                HAM_Attendee__c             = chunkAttendeeMap.get(sa.conference360__Attendee__c),
                HAM_Contact__c              = sa.conference360__Contact__c,
                HAM_Event_Item_Session__c   = btToHamEisMap.get(sa.conference360__Event_Item_Session__c),
                HAM_Registration_Status__c  = HAM_MigrationUtil.truncate(
                                                 sa.conference360__Registration_Status__c, 255),
                HAM_BT_Source_Id__c         = sa.Id,
                HAM_BT_Session_Attendee__c  = sa.Id
            ));
        }

        List<Database.UpsertResult> results =
            Database.upsert(toUpsert, HAM_Event_Session_Attendee__c.HAM_BT_Source_Id__c, false);

        for (Database.UpsertResult r : results) {
            if (r.isSuccess()) { successCount++; }
            else               { failCount++; }
        }
        HAM_MigrationUtil.logErrors(results, toUpsert, 'HAM_Event_Session_Attendee__c');
    }

    // ── finish() ──────────────────────────────────────────────────────────────
    /**
     * @description Logs completion summary and chains to HAM_FormMigrationBatch.
     * @param bc BatchableContext provided by the platform
     */
    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.DEBUG, 'HAM_SessionAttendeeMigrationBatch complete — '
            + successCount + ' succeeded, ' + failCount + ' failed.');
        HAM_MigrationUtil.logSummary('HAM_Event_Session_Attendee__c', successCount + failCount, successCount);
        Database.executeBatch(new HAM_FormMigrationBatch(), 200);
    }
}