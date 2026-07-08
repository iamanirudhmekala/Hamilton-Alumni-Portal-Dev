/**
 * HAM_SurveyQuestionBatch
 * ─────────────────────────────────────────────────────────────────────────────
 * Migrates conference360__Form_Element__c → CventEvents__SurveyQuestion__c.
 *
 * Key behaviours:
 *  - Scoped to form elements whose parent form was migrated to a SurveyProgram
 *  - Resolves CventEvents__SurveyProgram__c (Master-Detail) via
 *    CventEvents__SurveyProgram__c.HAM_BT_Source_Id__c (from Form_Element's Form)
 *  - Records where SurveyProgram cannot be resolved are skipped
 *  - HAM_BT_Source_Id__c populated for downstream Survey Answer lookup resolution
 *  - Idempotent: upsert on HAM_BT_Source_Id__c (External ID)
 *  - Batch size 100 (conservative — form elements can be numerous)
 *  - Chains → HAM_RespondentBatch on finish()
 *
 * Prerequisites:
 *  - HAM_SurveyProgramBatch must have run first
 *
 * Change Log:
 *   v1.0  05/08/2026  NVV: ASC-XXXXX - Phase 2 initial build
 *
 * @description Batch class to migrate conference360__Form_Element__c records to
 *              CventEvents__SurveyQuestion__c.
 */
public class HAM_SurveyQuestionBatch
        implements Database.Batchable<SObject>, Database.Stateful {

    // Map: BT Form Id → Cvent SurveyProgram Id
    @TestVisible private Map<Id, Id> btFormToSurveyProgramMap = new Map<Id, Id>();

    public Integer successCount = 0;
    public Integer failCount    = 0;

    // ── start() ───────────────────────────────────────────────────────────────
    /**
     * @description Builds the Form-to-SurveyProgram map and returns a QueryLocator
     *              for all form elements in migrated forms.
     * @param bc BatchableContext provided by the platform.
     * @return Database.QueryLocator for conference360__Form_Element__c records.
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
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
                   conference360__Question__c,
                   conference360__Type__c,
                   conference360__Required__c,
                   conference360__Sort_Order__c
            FROM   conference360__Form_Element__c
            WHERE  conference360__Form__c IN :btFormToSurveyProgramMap.keySet()
            ORDER BY conference360__Sort_Order__c ASC NULLS LAST
        ]);
    }

    // ── execute() ─────────────────────────────────────────────────────────────
    /**
     * @description Upserts a batch of form elements into CventEvents__SurveyQuestion__c.
     *              Records without a resolved SurveyProgram parent are skipped.
     * @param bc       BatchableContext provided by the platform.
     * @param elements Chunk of conference360__Form_Element__c records to process.
     */
    public void execute(
        Database.BatchableContext bc,
        List<conference360__Form_Element__c> elements
    ) {
        List<CventEvents__SurveyQuestion__c> toUpsert = new List<CventEvents__SurveyQuestion__c>();

        for (conference360__Form_Element__c fe : elements) {
            Id surveyProgramId = btFormToSurveyProgramMap.get(fe.conference360__Form__c);

            // Master-Detail parent required — skip if unresolved
            if (surveyProgramId == null) { continue; }

            toUpsert.add(new CventEvents__SurveyQuestion__c(
                CventEvents__SurveyProgram__c    = surveyProgramId,
                CventEvents__QuestionText__c     = HAM_MigrationUtil.truncate(
                                                      fe.conference360__Question__c, 255),
                CventEvents__FullQuestionText__c = fe.conference360__Question__c,
                CventEvents__Type__c             = HAM_MigrationUtil.truncate(
                                                      fe.conference360__Type__c, 255),
                HAM_BT_Source_Id__c              = fe.Id
            ));
        }

        List<Database.UpsertResult> results =
            Database.upsert(toUpsert, CventEvents__SurveyQuestion__c.HAM_BT_Source_Id__c, false);

        for (Database.UpsertResult r : results) {
            if (r.isSuccess()) { successCount++; }
            else               { failCount++; }
        }
        HAM_MigrationUtil.logErrors(results, toUpsert, 'CventEvents__SurveyQuestion__c');
    }

    // ── finish() ──────────────────────────────────────────────────────────────
    /**
     * @description Logs completion summary and chains to HAM_RespondentBatch.
     * @param bc BatchableContext provided by the platform.
     */
    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.DEBUG, 'HAM_SurveyQuestionBatch complete — '
            + successCount + ' succeeded, ' + failCount + ' failed.');
        HAM_MigrationUtil.logSummary('CventEvents__SurveyQuestion__c', successCount + failCount, successCount);
        Database.executeBatch(new HAM_RespondentBatch(), 200);
    }
}