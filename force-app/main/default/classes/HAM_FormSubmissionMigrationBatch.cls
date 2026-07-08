/**
 * HAM_FormSubmissionMigrationBatch
 * ─────────────────────────────────────────────────────────────────────────────
 * Migrates conference360__Form_Submission__c → HAM_Event_Form_Submission__c.
 *
 * Key behaviours:
 *  - Resolves CventEvents_Event__c via btToCventEventMap
 *  - Resolves HAM_Event_Form__c via HAM_Event_Form__c.HAM_BT_Source_Id__c
 *  - Resolves HAM_Attendee__c via CventEvents__Attendee__c.HAM_BT_Attendee_Id__c
 *  - Idempotent: upsert on HAM_BT_Source_Id__c (External ID)
 *  - Populates HAM_BT_Form_Submission__c (lookup → conference360__Form_Submission__c)
 *  - Chains → HAM_FormSubmissionAnswerMigrationBatch on finish()
 *
 * Prerequisites:
 *  - HAM_FormMigrationBatch and HAM_AttendeeMigrationBatch must have run first
 *
 * Change Log:
 *   v1.0  2026-04-17  Initial build
 *   v1.1  2026-04-28  NVV: ASC-XXXXX - Move btToCventAttendeeMap from start() to execute() to avoid 50K SOQL row limit
 * @description Batch class to migrate conference360__Form_Submission__c records to HAM_Event_Form_Submission__c.
 */
public class HAM_FormSubmissionMigrationBatch
        implements Database.Batchable<SObject>, Database.Stateful {

    // Map: BT Event Id → Cvent Event Id
    private Map<Id, Id> btToCventEventMap    = new Map<Id, Id>();
    // Map: BT Form Id → HAM_Event_Form__c Id
    private Map<Id, Id> btToHamFormMap       = new Map<Id, Id>();
    public Integer successCount = 0;
    public Integer failCount    = 0;

    // ── start() ───────────────────────────────────────────────────────────────
    /**
     * @description Builds event, form, and attendee maps, then returns a QueryLocator for all form submissions.
     * @param bc BatchableContext provided by the platform
     * @return Database.QueryLocator scoped to form submissions for migrated events
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

        for (HAM_Event_Form__c hf : [
            SELECT Id, HAM_BT_Source_Id__c
            FROM   HAM_Event_Form__c
            WHERE  HAM_BT_Source_Id__c != null
            AND    CventEvents_Event__c IN :cventEventIds
        ]) {
            btToHamFormMap.put((Id) hf.HAM_BT_Source_Id__c, hf.Id);
        }

        return Database.getQueryLocator([
            SELECT Id,
                   conference360__Event__c,
                   conference360__Form__c,
                   conference360__Attendee__c
            FROM   conference360__Form_Submission__c
            WHERE  conference360__Event__c IN :btToCventEventMap.keySet()
        ]);
    }

    // ── execute() ─────────────────────────────────────────────────────────────
    /**
     * @description Upserts a batch of form submissions into HAM_Event_Form_Submission__c.
     * @param bc          BatchableContext provided by the platform
     * @param submissions Chunk of conference360__Form_Submission__c records to process
     */
    public void execute(
        Database.BatchableContext bc,
        List<conference360__Form_Submission__c> submissions
    ) {
        Set<Id> chunkAttendeeIds = new Set<Id>();
        for (conference360__Form_Submission__c fs : submissions) {
            if (fs.conference360__Attendee__c != null) { chunkAttendeeIds.add(fs.conference360__Attendee__c); }
        }
        Map<Id, Id> chunkAttendeeMap = new Map<Id, Id>();
        for (CventEvents__Attendee__c ca : [
            SELECT Id, HAM_BT_Attendee_Id__c
            FROM   CventEvents__Attendee__c
            WHERE  HAM_BT_Attendee_Id__c IN :chunkAttendeeIds
        ]) {
            chunkAttendeeMap.put((Id) ca.HAM_BT_Attendee_Id__c, ca.Id);
        }

        List<HAM_Event_Form_Submission__c> toUpsert = new List<HAM_Event_Form_Submission__c>();

        for (conference360__Form_Submission__c fs : submissions) {
            Id cventEventId = btToCventEventMap.get(fs.conference360__Event__c);
            if (cventEventId == null) { continue; }

            toUpsert.add(new HAM_Event_Form_Submission__c(
                CventEvents_Event__c       = cventEventId,
                HAM_Event_Form__c          = btToHamFormMap.get(fs.conference360__Form__c),
                HAM_Attendee__c            = chunkAttendeeMap.get(fs.conference360__Attendee__c),
                HAM_BT_Source_Id__c        = fs.Id,
                HAM_BT_Form_Submission__c  = fs.Id
            ));
        }

        List<Database.UpsertResult> results =
            Database.upsert(toUpsert, HAM_Event_Form_Submission__c.HAM_BT_Source_Id__c, false);

        for (Database.UpsertResult r : results) {
            if (r.isSuccess()) { successCount++; }
            else               { failCount++; }
        }
        HAM_MigrationUtil.logErrors(results, toUpsert, 'HAM_Event_Form_Submission__c');
    }

    // ── finish() ──────────────────────────────────────────────────────────────
    /**
     * @description Logs completion summary and chains to HAM_FormSubmissionAnswerMigrationBatch.
     * @param bc BatchableContext provided by the platform
     */
    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.DEBUG, 'HAM_FormSubmissionMigrationBatch complete — '
            + successCount + ' succeeded, ' + failCount + ' failed.');
        HAM_MigrationUtil.logSummary('HAM_Event_Form_Submission__c', successCount + failCount, successCount);
        Database.executeBatch(new HAM_FormSubmissionAnswerMigrationBatch(), 200);
    }
}