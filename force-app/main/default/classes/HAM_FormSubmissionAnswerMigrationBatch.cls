/**
 * HAM_FormSubmissionAnswerMigrationBatch
 * ─────────────────────────────────────────────────────────────────────────────
 * Migrates conference360__Form_Submission_Answer__c → HAM_Event_Form_Submission_Answer__c.
 *
 * Key behaviours:
 *  - Resolves HAM_Form_Submission__c (Master-Detail) via HAM_Event_Form_Submission__c.HAM_BT_Source_Id__c
 *    Records where submission cannot be resolved are skipped (null parent = DML failure)
 *  - Resolves HAM_Form_Element__c via HAM_Event_Form_Element__c.HAM_BT_Source_Id__c
 *  - Resolves HAM_Attendee__c via CventEvents__Attendee__c.HAM_BT_Attendee_Id__c
 *  - Copies answer text (short + long) and question verbatim from BT
 *  - Idempotent: upsert on HAM_BT_Source_Id__c (External ID)
 *  - Populates HAM_BT_Form_Submission_Answer__c (lookup → conference360__Form_Submission_Answer__c)
 *  - Chains → HAM_EmailTemplateMigrationBatch on finish()
 *
 * Prerequisites:
 *  - HAM_FormSubmissionMigrationBatch and HAM_FormElementMigrationBatch must have run first
 *
 * Change Log:
 *   v1.0  2026-04-17  Initial build
 *   v1.1  2026-04-28  NVV: ASC-XXXXX - Move btToCventAttendeeMap from start() to execute() to avoid 50K SOQL row limit
 * @description Batch class to migrate conference360__Form_Submission_Answer__c records to HAM_Event_Form_Submission_Answer__c.
 */
public class HAM_FormSubmissionAnswerMigrationBatch
        implements Database.Batchable<SObject>, Database.Stateful {

    // Map: BT Form Submission Id → HAM_Event_Form_Submission__c Id
    private Map<Id, Id> btToHamSubmissionMap  = new Map<Id, Id>();
    // Map: BT Form Element Id → HAM_Event_Form_Element__c Id
    private Map<Id, Id> btToHamElementMap     = new Map<Id, Id>();
    public Integer successCount = 0;
    public Integer failCount    = 0;

    // ── start() ───────────────────────────────────────────────────────────────
    /**
     * @description Builds submission, element, and attendee maps, then returns a QueryLocator for all answers.
     * @param bc BatchableContext provided by the platform
     * @return Database.QueryLocator scoped to answers for migrated submissions
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Derive Cvent event IDs to scope all maps
        Map<Id, Id> btToCventEventMap = new Map<Id, Id>();
        for (CventEvents__Event__c cv : [
            SELECT Id, HAM_BT_Event_Id__c
            FROM   CventEvents__Event__c
            WHERE  HAM_BT_Event_Id__c != null
        ]) {
            btToCventEventMap.put((Id) cv.HAM_BT_Event_Id__c, cv.Id);
        }
        Set<Id> cventEventIds = new Set<Id>(btToCventEventMap.values());

        for (HAM_Event_Form_Submission__c hs : [
            SELECT Id, HAM_BT_Source_Id__c
            FROM   HAM_Event_Form_Submission__c
            WHERE  HAM_BT_Source_Id__c != null
            AND    CventEvents_Event__c IN :cventEventIds
        ]) {
            btToHamSubmissionMap.put((Id) hs.HAM_BT_Source_Id__c, hs.Id);
        }

        for (HAM_Event_Form_Element__c he : [
            SELECT Id, HAM_BT_Source_Id__c
            FROM   HAM_Event_Form_Element__c
            WHERE  HAM_BT_Source_Id__c != null
            AND    HAM_Event_Form__c IN (
                SELECT Id FROM HAM_Event_Form__c
                WHERE CventEvents_Event__c IN :cventEventIds
            )
        ]) {
            btToHamElementMap.put((Id) he.HAM_BT_Source_Id__c, he.Id);
        }

        return Database.getQueryLocator([
            SELECT Id,
                   conference360__Form_Submission__c,
                   conference360__Form_Element__c,
                   conference360__Attendee__c,
                   conference360__Answer__c,
                   conference360__Answer_Text_Long__c,
                   conference360__Question__c
            FROM   conference360__Form_Submission_Answer__c
            WHERE  conference360__Form_Submission__c IN :btToHamSubmissionMap.keySet()
        ]);
    }

    // ── execute() ─────────────────────────────────────────────────────────────
    /**
     * @description Upserts a batch of form submission answers into HAM_Event_Form_Submission_Answer__c.
     * @param bc      BatchableContext provided by the platform
     * @param answers Chunk of conference360__Form_Submission_Answer__c records to process
     */
    public void execute(
        Database.BatchableContext bc,
        List<conference360__Form_Submission_Answer__c> answers
    ) {
        Set<Id> chunkAttendeeIds = new Set<Id>();
        for (conference360__Form_Submission_Answer__c fsa : answers) {
            if (fsa.conference360__Attendee__c != null) { chunkAttendeeIds.add(fsa.conference360__Attendee__c); }
        }
        Map<Id, Id> chunkAttendeeMap = new Map<Id, Id>();
        for (CventEvents__Attendee__c ca : [
            SELECT Id, HAM_BT_Attendee_Id__c
            FROM   CventEvents__Attendee__c
            WHERE  HAM_BT_Attendee_Id__c IN :chunkAttendeeIds
        ]) {
            chunkAttendeeMap.put((Id) ca.HAM_BT_Attendee_Id__c, ca.Id);
        }

        List<HAM_Event_Form_Submission_Answer__c> toUpsert = new List<HAM_Event_Form_Submission_Answer__c>();

        for (conference360__Form_Submission_Answer__c fsa : answers) {
            Id hamSubmissionId = btToHamSubmissionMap.get(fsa.conference360__Form_Submission__c);
            // Master-Detail parent is required — skip if unresolved
            if (hamSubmissionId == null) { continue; }

            toUpsert.add(new HAM_Event_Form_Submission_Answer__c(
                HAM_Form_Submission__c              = hamSubmissionId,
                HAM_Form_Element__c                 = btToHamElementMap.get(
                                                         fsa.conference360__Form_Element__c),
                HAM_Attendee__c                     = chunkAttendeeMap.get(
                                                         fsa.conference360__Attendee__c),
                HAM_Answer__c                       = HAM_MigrationUtil.truncate(
                                                         fsa.conference360__Answer__c, 255),
                HAM_Answer_Text_Long__c             = fsa.conference360__Answer_Text_Long__c,
                HAM_Question__c                     = fsa.conference360__Question__c,
                HAM_BT_Source_Id__c                 = fsa.Id,
                HAM_BT_Form_Submission_Answer__c    = fsa.Id
            ));
        }

        List<Database.UpsertResult> results =
            Database.upsert(toUpsert, HAM_Event_Form_Submission_Answer__c.HAM_BT_Source_Id__c, false);

        for (Database.UpsertResult r : results) {
            if (r.isSuccess()) { successCount++; }
            else               { failCount++; }
        }
        HAM_MigrationUtil.logErrors(results, toUpsert, 'HAM_Event_Form_Submission_Answer__c');
    }

    // ── finish() ──────────────────────────────────────────────────────────────
    /**
     * @description Logs completion summary and chains to HAM_EmailTemplateMigrationBatch.
     * @param bc BatchableContext provided by the platform
     */
    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.DEBUG, 'HAM_FormSubmissionAnswerMigrationBatch complete — '
            + successCount + ' succeeded, ' + failCount + ' failed.');
        HAM_MigrationUtil.logSummary('HAM_Event_Form_Submission_Answer__c', successCount + failCount, successCount);
        Database.executeBatch(new HAM_EmailTemplateMigrationBatch(), 200);
    }
}