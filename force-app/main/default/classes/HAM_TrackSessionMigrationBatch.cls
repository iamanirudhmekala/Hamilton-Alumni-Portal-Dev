/**
 * HAM_TrackSessionMigrationBatch
 * ─────────────────────────────────────────────────────────────────────────────
 * Migrates conference360__Track_Session__c → HAM_Track_Session__c.
 *
 * Key behaviours:
 *  - Builds btToHamTrackMap and btToHamSessionMap in start() once (Stateful)
 *  - Requires HAM_Track__c and HAM_Event_Session__c to exist (runs last in pipeline)
 *  - Records with no matching Track or Session in HAM are skipped
 *  - Idempotent: upsert on HAM_BT_Track_Session_Id__c (External ID)
 *  - Chains → HAM_EventSettingsMigrationBatch on finish()
 *
 * Change Log:
 *   v1.0  2026-04-21  NVV: ASC-XXXXX - Initial deployment
 *
 * @description Batch class to migrate conference360__Track_Session__c records to
 *              HAM_Track_Session__c. Runs as the final step in the migration pipeline.
 */
public class HAM_TrackSessionMigrationBatch
        implements Database.Batchable<SObject>, Database.Stateful {

    @TestVisible private Map<Id, Id> btToHamTrackMap   = new Map<Id, Id>();
    @TestVisible private Map<Id, Id> btToHamSessionMap = new Map<Id, Id>();
    public  Integer successCount = 0;
    public  Integer failCount    = 0;

    // ── start() ───────────────────────────────────────────────────────────────
    /**
     * @description Builds BT-to-HAM maps for tracks and sessions, then returns
     *              a QueryLocator for all BT track session junction records.
     * @param bc BatchableContext provided by the platform.
     * @return Database.QueryLocator for all conference360__Track_Session__c records.
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        for (HAM_Track__c t : [
            SELECT Id, HAM_BT_Track_Id__c
            FROM   HAM_Track__c
            WHERE  HAM_BT_Track_Id__c != null
            WITH SECURITY_ENFORCED
        ]) {
            btToHamTrackMap.put((Id) t.HAM_BT_Track_Id__c, t.Id);
        }

        for (HAM_Event_Session__c s : [
            SELECT Id, HAM_BT_Source_Id__c
            FROM   HAM_Event_Session__c
            WHERE  HAM_BT_Source_Id__c != null
            WITH SECURITY_ENFORCED
        ]) {
            btToHamSessionMap.put((Id) s.HAM_BT_Source_Id__c, s.Id);
        }

        return Database.getQueryLocator([
            SELECT Id,
                   conference360__Track__c,
                   conference360__Session__c
            FROM   conference360__Track_Session__c
            WHERE  conference360__Track__c   IN :btToHamTrackMap.keySet()
            AND    conference360__Session__c IN :btToHamSessionMap.keySet()
        ]);
    }

    // ── execute() ─────────────────────────────────────────────────────────────
    /**
     * @description Upserts a batch of track sessions into HAM_Track_Session__c.
     * @param bc            BatchableContext provided by the platform.
     * @param trackSessions Chunk of conference360__Track_Session__c records to process.
     */
    public void execute(
        Database.BatchableContext bc,
        List<conference360__Track_Session__c> trackSessions
    ) {
        List<HAM_Track_Session__c> toUpsert = new List<HAM_Track_Session__c>();

        for (conference360__Track_Session__c ts : trackSessions) {
            Id hamTrackId   = btToHamTrackMap.get(ts.conference360__Track__c);
            Id hamSessionId = btToHamSessionMap.get(ts.conference360__Session__c);
            if (hamTrackId == null || hamSessionId == null) { continue; }

            toUpsert.add(new HAM_Track_Session__c(
                HAM_Track__c               = hamTrackId,
                HAM_Session__c             = hamSessionId,
                HAM_BT_Track_Session_Id__c = ts.Id
            ));
        }

        List<Database.UpsertResult> results =
            Database.upsert(toUpsert, HAM_Track_Session__c.HAM_BT_Track_Session_Id__c, false);

        for (Database.UpsertResult r : results) {
            if (r.isSuccess()) { successCount++; }
            else               { failCount++; }
        }
        HAM_MigrationUtil.logErrors(results, toUpsert, 'HAM_Track_Session__c');
    }

    // ── finish() ──────────────────────────────────────────────────────────────
    /**
     * @description Logs completion summary and chains to HAM_EventSettingsMigrationBatch.
     * @param bc BatchableContext provided by the platform.
     */
    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.DEBUG, 'HAM_TrackSessionMigrationBatch complete — '
            + successCount + ' succeeded, ' + failCount + ' failed.');
        HAM_MigrationUtil.logSummary('HAM_Track_Session__c', successCount + failCount, successCount);
        Database.executeBatch(new HAM_EventSettingsMigrationBatch(), 200);
    }
}