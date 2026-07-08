/**
 * HAM_SurveyAnswerBatch
 * ─────────────────────────────────────────────────────────────────────────────
 * Migrates conference360__Form_Submission_Answer__c → CventEvents__SurveyAnswer__c.
 *
 * Key behaviours:
 *  - Scoped to answers whose parent submission has a migrated Respondent record
 *  - Resolves CventEvents__Respondent__c (Master-Detail) via
 *    CventEvents__Respondent__c.HAM_BT_Source_Id__c (chunk-based in execute()
 *    to avoid 50K SOQL row limit)
 *  - Resolves CventEvents__Question__c (Lookup) via
 *    CventEvents__SurveyQuestion__c.HAM_BT_Source_Id__c (start-time map)
 *  - Records where Respondent Master-Detail cannot be resolved are skipped
 *  - Idempotent: upsert on HAM_BT_Source_Id__c (External ID)
 *  - Final batch in the Phase 2 pipeline — logs COMPLETE on finish()
 *
 * Prerequisites:
 *  - HAM_RespondentBatch and HAM_SurveyQuestionBatch must have run first
 *
 * Change Log:
 *   v1.0  05/08/2026  NVV: ASC-XXXXX - Phase 2 initial build
 *   v1.1  05/08/2026  NVV: ASC-XXXXX - Removed chain to EventSettings (Phase 2 is now true terminus)
 *
 * @description Batch class to migrate conference360__Form_Submission_Answer__c records
 *              to CventEvents__SurveyAnswer__c. Final batch in the migration pipeline.
 */
public class HAM_SurveyAnswerBatch
        implements Database.Batchable<SObject>, Database.Stateful {

    // Map: BT Form Element Id → Cvent SurveyQuestion Id
    @TestVisible private Map<Id, Id> btToSurveyQuestionMap    = new Map<Id, Id>();
    // Set: BT Form Submission IDs with migrated Respondents (scopes query)
    private Set<Id>                  migratedSubmissionIds     = new Set<Id>();
    // Test-only override: injected respondent map bypasses SOQL in execute()
    @TestVisible private Map<Id, Id> testRespondentMapOverride = null;

    public Integer successCount = 0;
    public Integer failCount    = 0;

    // ── start() ───────────────────────────────────────────────────────────────
    /**
     * @description Builds SurveyQuestion map, collects migrated Respondent submission
     *              IDs, and returns a QueryLocator for all answers in scope.
     * @param bc BatchableContext provided by the platform.
     * @return Database.QueryLocator for conference360__Form_Submission_Answer__c records.
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        for (CventEvents__SurveyQuestion__c sq : [
            SELECT Id, HAM_BT_Source_Id__c
            FROM   CventEvents__SurveyQuestion__c
            WHERE  HAM_BT_Source_Id__c != null
        ]) {
            btToSurveyQuestionMap.put((Id) sq.HAM_BT_Source_Id__c, sq.Id);
        }

        for (CventEvents__Respondent__c r : [
            SELECT HAM_BT_Source_Id__c
            FROM   CventEvents__Respondent__c
            WHERE  HAM_BT_Source_Id__c != null
        ]) {
            migratedSubmissionIds.add((Id) r.HAM_BT_Source_Id__c);
        }

        return Database.getQueryLocator([
            SELECT Id,
                   conference360__Form_Submission__c,
                   conference360__Form_Element__c,
                   conference360__Answer__c,
                   conference360__Answer_Date__c,
                   conference360__Answer_Number__c,
                   conference360__Answer_Text_Long__c
            FROM   conference360__Form_Submission_Answer__c
            WHERE  conference360__Form_Submission__c IN :migratedSubmissionIds
        ]);
    }

    // ── execute() ─────────────────────────────────────────────────────────────
    /**
     * @description Upserts a batch of form submission answers into
     *              CventEvents__SurveyAnswer__c. Resolves Respondent chunk-by-chunk.
     * @param bc      BatchableContext provided by the platform.
     * @param answers Chunk of conference360__Form_Submission_Answer__c records to process.
     */
    public void execute(
        Database.BatchableContext bc,
        List<conference360__Form_Submission_Answer__c> answers
    ) {
        // Resolve Respondents chunk-by-chunk to avoid 50K row limit
        Set<Id> chunkSubmissionIds = new Set<Id>();
        for (conference360__Form_Submission_Answer__c fsa : answers) {
            if (fsa.conference360__Form_Submission__c != null) {
                chunkSubmissionIds.add(fsa.conference360__Form_Submission__c);
            }
        }

        Map<Id, Id> chunkRespondentMap = (testRespondentMapOverride != null)
            ? testRespondentMapOverride
            : new Map<Id, Id>();
        if (testRespondentMapOverride == null) {
            for (CventEvents__Respondent__c r : [
                SELECT Id, HAM_BT_Source_Id__c
                FROM   CventEvents__Respondent__c
                WHERE  HAM_BT_Source_Id__c IN :chunkSubmissionIds
            ]) {
                chunkRespondentMap.put((Id) r.HAM_BT_Source_Id__c, r.Id);
            }
        }

        List<CventEvents__SurveyAnswer__c> toUpsert = new List<CventEvents__SurveyAnswer__c>();

        for (conference360__Form_Submission_Answer__c fsa : answers) {
            Id respondentId = chunkRespondentMap.get(fsa.conference360__Form_Submission__c);

            // Master-Detail parent required — skip if unresolved
            if (respondentId == null) { continue; }

            toUpsert.add(new CventEvents__SurveyAnswer__c(
                CventEvents__Respondent__c  = respondentId,
                CventEvents__Question__c    = btToSurveyQuestionMap.get(
                                                 fsa.conference360__Form_Element__c),
                CventEvents__Value__c       = HAM_MigrationUtil.truncate(
                                                 fsa.conference360__Answer__c, 255),
                CventEvents__ValueDate__c   = fsa.conference360__Answer_Date__c,
                CventEvents__ValueNumber__c = fsa.conference360__Answer_Number__c,
                CventEvents__ValueText__c   = fsa.conference360__Answer_Text_Long__c,
                HAM_BT_Source_Id__c         = fsa.Id
            ));
        }

        List<Database.UpsertResult> results =
            Database.upsert(toUpsert, CventEvents__SurveyAnswer__c.HAM_BT_Source_Id__c, false);

        for (Database.UpsertResult r : results) {
            if (r.isSuccess()) { successCount++; }
            else               { failCount++; }
        }
        HAM_MigrationUtil.logErrors(results, toUpsert, 'CventEvents__SurveyAnswer__c');
    }

    // ── finish() ──────────────────────────────────────────────────────────────
    /**
     * @description Logs Phase 2 completion. Final batch in the full migration pipeline.
     * @param bc BatchableContext provided by the platform.
     */
    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.DEBUG, 'HAM_SurveyAnswerBatch complete — '
            + successCount + ' succeeded, ' + failCount + ' failed.');
        HAM_MigrationUtil.logSummary('CventEvents__SurveyAnswer__c', successCount + failCount, successCount);
        System.debug(LoggingLevel.DEBUG, '═══════════════════════════════════════════════');
        System.debug(LoggingLevel.DEBUG, 'HAM Migration Phase 2 Pipeline COMPLETE.');
        System.debug(LoggingLevel.DEBUG, '═══════════════════════════════════════════════');
    }
}