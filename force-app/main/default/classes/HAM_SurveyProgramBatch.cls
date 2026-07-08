/**
 * HAM_SurveyProgramBatch
 * ─────────────────────────────────────────────────────────────────────────────
 * Migrates conference360__Form__c → CventEvents__SurveyProgram__c.
 *
 * Key behaviours:
 *  - Collects form IDs from all 4 form relationship fields on each migrated event
 *    (same collection pattern as HAM_FormMigrationBatch)
 *  - HAM_BT_Source_Id__c populated for downstream Survey Question and Respondent
 *    lookup resolution
 *  - CventEvents__SurveyProgram__c has no parent event lookup — standalone survey
 *  - Idempotent: upsert on HAM_BT_Source_Id__c (External ID)
 *  - Chains → HAM_SurveyQuestionBatch on finish()
 *
 * Prerequisites:
 *  - HAM_EventMigrationBatch must have run first
 *
 * Change Log:
 *   v1.0  05/08/2026  NVV: ASC-XXXXX - Phase 2 initial build
 *
 * @description Batch class to migrate conference360__Form__c records to
 *              CventEvents__SurveyProgram__c.
 */
public class HAM_SurveyProgramBatch
        implements Database.Batchable<SObject>, Database.Stateful {

    // Map: Form Id → derived survey type (from event field reference)
    @TestVisible private Map<Id, String> formTypeMap                  = new Map<Id, String>();
    // Test-only override: injected BT→Cvent event map bypasses CventEvents__Event__c SOQL in start()
    @TestVisible private Map<Id, Id>     testBtToCventEventOverride   = null;

    public Integer successCount = 0;
    public Integer failCount    = 0;

    // ── start() ───────────────────────────────────────────────────────────────
    /**
     * @description Collects all form IDs referenced by migrated events, infers
     *              survey type, and returns a QueryLocator for those forms.
     * @param bc BatchableContext provided by the platform.
     * @return Database.QueryLocator scoped to forms referenced by migrated events.
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Test-only override bypasses CventEvents__Event__c SOQL (managed pkg, not insertable in tests)
        Map<Id, Id> btToCventEventMap = (testBtToCventEventOverride != null)
            ? testBtToCventEventOverride
            : new Map<Id, Id>();
        if (testBtToCventEventOverride == null) {
            for (CventEvents__Event__c cv : [
                SELECT Id, HAM_BT_Event_Id__c
                FROM   CventEvents__Event__c
                WHERE  HAM_BT_Event_Id__c != null
            ]) {
                btToCventEventMap.put((Id) cv.HAM_BT_Event_Id__c, cv.Id);
            }
        }

        Set<Id> formIds = new Set<Id>();
        for (conference360__Event__c ev : [
            SELECT Id,
                   conference360__Form2__c,
                   conference360__Registration_Questions__c,
                   conference360__Form_Post_Registration__c,
                   conference360__Post_Event_Questions__c
            FROM   conference360__Event__c
            WHERE  Id IN :btToCventEventMap.keySet()
        ]) {
            if (ev.conference360__Form2__c != null) {
                formIds.add(ev.conference360__Form2__c);
                if (!formTypeMap.containsKey(ev.conference360__Form2__c)) {
                    formTypeMap.put(ev.conference360__Form2__c, 'Pre-registration');
                }
            }
            if (ev.conference360__Registration_Questions__c != null) {
                formIds.add(ev.conference360__Registration_Questions__c);
                if (!formTypeMap.containsKey(ev.conference360__Registration_Questions__c)) {
                    formTypeMap.put(ev.conference360__Registration_Questions__c, 'Pre-registration');
                }
            }
            if (ev.conference360__Form_Post_Registration__c != null) {
                formIds.add(ev.conference360__Form_Post_Registration__c);
                if (!formTypeMap.containsKey(ev.conference360__Form_Post_Registration__c)) {
                    formTypeMap.put(ev.conference360__Form_Post_Registration__c, 'Post-registration');
                }
            }
            if (ev.conference360__Post_Event_Questions__c != null) {
                formIds.add(ev.conference360__Post_Event_Questions__c);
                if (!formTypeMap.containsKey(ev.conference360__Post_Event_Questions__c)) {
                    formTypeMap.put(ev.conference360__Post_Event_Questions__c, 'Survey');
                }
            }
        }

        return Database.getQueryLocator([
            SELECT Id,
                   Name,
                   conference360__Type__c,
                   conference360__Submitted_Message__c
            FROM   conference360__Form__c
            WHERE  Id IN :formIds
        ]);
    }

    // ── execute() ─────────────────────────────────────────────────────────────
    /**
     * @description Upserts a batch of forms into CventEvents__SurveyProgram__c.
     * @param bc    BatchableContext provided by the platform.
     * @param forms Chunk of conference360__Form__c records to process.
     */
    public void execute(
        Database.BatchableContext bc,
        List<conference360__Form__c> forms
    ) {
        List<CventEvents__SurveyProgram__c> toUpsert = new List<CventEvents__SurveyProgram__c>();

        for (conference360__Form__c f : forms) {
            String surveyType = formTypeMap.get(f.Id);

            toUpsert.add(new CventEvents__SurveyProgram__c(
                CventEvents__SurveyTitle__c  = HAM_MigrationUtil.truncate(f.Name, 255),
                CventEvents__Description__c  = HAM_MigrationUtil.truncate(
                                                  f.conference360__Submitted_Message__c, 255),
                CventEvents__Type__c         = HAM_MigrationUtil.truncate(surveyType != null
                                                  ? surveyType
                                                  : f.conference360__Type__c, 255),
                HAM_BT_Source_Id__c          = f.Id
            ));
        }

        List<Database.UpsertResult> results =
            Database.upsert(toUpsert, CventEvents__SurveyProgram__c.HAM_BT_Source_Id__c, false);

        for (Database.UpsertResult r : results) {
            if (r.isSuccess()) { successCount++; }
            else               { failCount++; }
        }
        HAM_MigrationUtil.logErrors(results, toUpsert, 'CventEvents__SurveyProgram__c');
    }

    // ── finish() ──────────────────────────────────────────────────────────────
    /**
     * @description Logs completion summary and chains to HAM_SurveyQuestionBatch.
     * @param bc BatchableContext provided by the platform.
     */
    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.DEBUG, 'HAM_SurveyProgramBatch complete — '
            + successCount + ' succeeded, ' + failCount + ' failed.');
        HAM_MigrationUtil.logSummary('CventEvents__SurveyProgram__c', successCount + failCount, successCount);
        Database.executeBatch(new HAM_SurveyQuestionBatch(), 100);
    }
}