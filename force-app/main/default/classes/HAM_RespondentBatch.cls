/**
 * HAM_RespondentBatch
 * ─────────────────────────────────────────────────────────────────────────────
 * Migrates conference360__Form_Submission__c → CventEvents__Respondent__c.
 *
 * Key behaviours:
 *  - Scoped to form submissions whose event was successfully migrated
 *  - Resolves CventEvents__SurveyProgram__c (Lookup) via
 *    CventEvents__SurveyProgram__c.HAM_BT_Source_Id__c (from Submission's Form)
 *  - Resolves CventEvents__Contact__c directly from conference360__Contact__c
 *  - HAM_BT_Source_Id__c populated for downstream Survey Answer lookup resolution
 *  - Idempotent: upsert on HAM_BT_Source_Id__c (External ID)
 *  - Chains → HAM_SurveyAnswerBatch on finish()
 *
 * Prerequisites:
 *  - HAM_SurveyProgramBatch must have run first
 *
 * Change Log:
 *   v1.0  05/08/2026  NVV: ASC-XXXXX - Phase 2 initial build
 *
 * @description Batch class to migrate conference360__Form_Submission__c records to
 *              CventEvents__Respondent__c.
 */
public class HAM_RespondentBatch
        implements Database.Batchable<SObject>, Database.Stateful {

    // Map: BT Event Id → Cvent Event Id
    @TestVisible private Map<Id, Id> btToCventEventMap        = new Map<Id, Id>();
    // Map: BT Form Id → Cvent SurveyProgram Id
    @TestVisible private Map<Id, Id> btFormToSurveyProgramMap = new Map<Id, Id>();

    public Integer successCount = 0;
    public Integer failCount    = 0;

    // ── start() ───────────────────────────────────────────────────────────────
    /**
     * @description Builds event and SurveyProgram maps, then returns a QueryLocator
     *              for all form submissions in migrated events.
     * @param bc BatchableContext provided by the platform.
     * @return Database.QueryLocator for conference360__Form_Submission__c records.
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        for (CventEvents__Event__c cv : [
            SELECT Id, HAM_BT_Event_Id__c
            FROM   CventEvents__Event__c
            WHERE  HAM_BT_Event_Id__c != null
        ]) {
            btToCventEventMap.put((Id) cv.HAM_BT_Event_Id__c, cv.Id);
        }

        for (CventEvents__SurveyProgram__c sp : [
            SELECT Id, HAM_BT_Source_Id__c
            FROM   CventEvents__SurveyProgram__c
            WHERE  HAM_BT_Source_Id__c != null
        ]) {
            btFormToSurveyProgramMap.put((Id) sp.HAM_BT_Source_Id__c, sp.Id);
        }

        return Database.getQueryLocator([
            SELECT Id,
                   conference360__Form__c,
                   conference360__Contact__c,
                   conference360__Status__c,
                   conference360__Key__c
            FROM   conference360__Form_Submission__c
            WHERE  conference360__Event__c IN :btToCventEventMap.keySet()
        ]);
    }

    // ── execute() ─────────────────────────────────────────────────────────────
    /**
     * @description Upserts a batch of form submissions into CventEvents__Respondent__c.
     * @param bc          BatchableContext provided by the platform.
     * @param submissions Chunk of conference360__Form_Submission__c records to process.
     */
    public void execute(
        Database.BatchableContext bc,
        List<conference360__Form_Submission__c> submissions
    ) {
        List<CventEvents__Respondent__c> toUpsert = new List<CventEvents__Respondent__c>();

        for (conference360__Form_Submission__c fs : submissions) {
            toUpsert.add(new CventEvents__Respondent__c(
                CventEvents__Contact__c        = fs.conference360__Contact__c,
                CventEvents__SurveyProgram__c  = btFormToSurveyProgramMap.get(fs.conference360__Form__c),
                CventEvents__Status__c         = HAM_MigrationUtil.truncate(
                                                    fs.conference360__Status__c, 255),
                CventEvents__RespondentCode__c = HAM_MigrationUtil.truncate(
                                                    fs.conference360__Key__c, 255),
                HAM_BT_Source_Id__c            = fs.Id
            ));
        }

        List<Database.UpsertResult> results =
            Database.upsert(toUpsert, CventEvents__Respondent__c.HAM_BT_Source_Id__c, false);

        for (Database.UpsertResult r : results) {
            if (r.isSuccess()) { successCount++; }
            else               { failCount++; }
        }
        HAM_MigrationUtil.logErrors(results, toUpsert, 'CventEvents__Respondent__c');
    }

    // ── finish() ──────────────────────────────────────────────────────────────
    /**
     * @description Logs completion summary and chains to HAM_SurveyAnswerBatch.
     * @param bc BatchableContext provided by the platform.
     */
    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.DEBUG, 'HAM_RespondentBatch complete — '
            + successCount + ' succeeded, ' + failCount + ' failed.');
        HAM_MigrationUtil.logSummary('CventEvents__Respondent__c', successCount + failCount, successCount);
        Database.executeBatch(new HAM_SurveyAnswerBatch(), 200);
    }
}