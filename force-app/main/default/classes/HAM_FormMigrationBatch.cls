/**
 * HAM_FormMigrationBatch
 * ─────────────────────────────────────────────────────────────────────────────
 * Migrates conference360__Form__c → HAM_Event_Form__c.
 *
 * Key behaviours:
 *  - Collects form IDs from all 4 form relationship fields on each event:
 *      conference360__Form2__c                  (Pre-Registration)
 *      conference360__Registration_Questions__c (Registration Questions)
 *      conference360__Form_Post_Registration__c (Post-Registration)
 *      conference360__Post_Event_Questions__c   (Post-Event Survey)
 *  - Derives HAM_Form_Type__c from which relationship field pointed to the form
 *  - MUST run before HAM_FormElementMigrationBatch
 *  - Idempotent: upsert on HAM_BT_Source_Id__c
 *  - Populates HAM_BT_Form__c (lookup → conference360__Form__c)
 *  - Chains → HAM_FormElementMigrationBatch on finish()
 *
 * Live data (ref event a6KU1000008006uMAA):
 *   conference360__Form2__c = a6UU10000003EMbMAM ('1812 LCW FORM', 4 elements)
 *   All other form fields = null
 *
 * Change Log:
 *   v1.0  2026-04-09  Initial deployment
 *   v1.1  2026-04-14  Fixed CventEvents_Event__c field name (single underscore)
 *   v1.2  2026-04-14  PMD static analysis fixes
 * @description Batch class to migrate conference360__Form__c records to HAM_Event_Form__c.
 */
public class HAM_FormMigrationBatch
        implements Database.Batchable<SObject>, Database.Stateful {

    private Map<Id, Id>     btToCventEventMap = new Map<Id, Id>();
    // formId → HAM_Form_Type__c value (derived from which field referenced it)
    private Map<Id, String> formTypeMap       = new Map<Id, String>();
    // formId → Cvent Event Id (for parent lookup on HAM_Event_Form__c)
    private Map<Id, Id>     formToEventMap    = new Map<Id, Id>();

    public Integer successCount = 0;
    public Integer failCount    = 0;

    // ── start() ───────────────────────────────────────────────────────────────
    /**
     * @description Builds event, form type, and form-to-event maps, then returns a QueryLocator for forms.
     * @param bc BatchableContext provided by the platform
     * @return Database.QueryLocator scoped to forms referenced by migrated events
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Build event map
        for (CventEvents__Event__c cv : [
            SELECT Id, HAM_BT_Event_Id__c
            FROM   CventEvents__Event__c
            WHERE  HAM_BT_Event_Id__c != null
        ]) {
            btToCventEventMap.put((Id) cv.HAM_BT_Event_Id__c, cv.Id);
        }

        // Collect all form IDs and infer type from the relationship field
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
            Id cventEvId = btToCventEventMap.get(ev.Id);

            if (ev.conference360__Form2__c != null) {
                formIds.add(ev.conference360__Form2__c);
                // Only set type/event if not already set by another event
                if (!formTypeMap.containsKey(ev.conference360__Form2__c)) {
                    formTypeMap.put(ev.conference360__Form2__c, 'Pre-registration');
                    formToEventMap.put(ev.conference360__Form2__c, cventEvId);
                }
            }
            if (ev.conference360__Registration_Questions__c != null) {
                formIds.add(ev.conference360__Registration_Questions__c);
                if (!formTypeMap.containsKey(ev.conference360__Registration_Questions__c)) {
                    formTypeMap.put(ev.conference360__Registration_Questions__c, 'Pre-registration');
                    formToEventMap.put(ev.conference360__Registration_Questions__c, cventEvId);
                }
            }
            if (ev.conference360__Form_Post_Registration__c != null) {
                formIds.add(ev.conference360__Form_Post_Registration__c);
                if (!formTypeMap.containsKey(ev.conference360__Form_Post_Registration__c)) {
                    formTypeMap.put(ev.conference360__Form_Post_Registration__c, 'Post-registration');
                    formToEventMap.put(ev.conference360__Form_Post_Registration__c, cventEvId);
                }
            }
            if (ev.conference360__Post_Event_Questions__c != null) {
                formIds.add(ev.conference360__Post_Event_Questions__c);
                if (!formTypeMap.containsKey(ev.conference360__Post_Event_Questions__c)) {
                    formTypeMap.put(ev.conference360__Post_Event_Questions__c, 'Survey');
                    formToEventMap.put(ev.conference360__Post_Event_Questions__c, cventEvId);
                }
            }
        }

        return Database.getQueryLocator([
            SELECT Id,
                   Name,
                   conference360__Type__c,
                   conference360__Submitted_Message__c,
                   conference360__Root_Object__c
            FROM   conference360__Form__c
            WHERE  Id IN :formIds
        ]);
    }

    // ── execute() ─────────────────────────────────────────────────────────────
    /**
     * @description Upserts a batch of forms into HAM_Event_Form__c.
     * @param bc    BatchableContext provided by the platform
     * @param forms Chunk of conference360__Form__c records to process
     */
    public void execute(
        Database.BatchableContext bc,
        List<conference360__Form__c> forms
    ) {
        List<HAM_Event_Form__c> toUpsert = new List<HAM_Event_Form__c>();

        for (conference360__Form__c f : forms) {
            Id cventEventId = formToEventMap.get(f.Id);
            String formType = formTypeMap.get(f.Id);

            toUpsert.add(new HAM_Event_Form__c(
                // Parent event lookup
                CventEvents_Event__c       = cventEventId,

                // Core fields
                HAM_Form_Name__c           = HAM_MigrationUtil.truncate(f.Name, 80),
                HAM_Form_Type__c           = (formType != null) ? formType
                                             : f.conference360__Type__c,
                HAM_Submitted_Message__c   = f.conference360__Submitted_Message__c,

                // Traceability
                HAM_BT_Source_Id__c        = f.Id,
                HAM_BT_Form__c             = f.Id  // Lookup → conference360__Form__c
            ));
        }

        List<Database.UpsertResult> results =
            Database.upsert(toUpsert, HAM_Event_Form__c.HAM_BT_Source_Id__c, false);

        for (Database.UpsertResult r : results) {
            if (r.isSuccess()) { successCount++; }
            else               { failCount++; }
        }
        HAM_MigrationUtil.logErrors(results, toUpsert, 'HAM_Event_Form__c');
    }

    // ── finish() ──────────────────────────────────────────────────────────────
    /**
     * @description Logs completion summary and chains to HAM_FormElementMigrationBatch.
     * @param bc BatchableContext provided by the platform
     */
    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.DEBUG, 'HAM_FormMigrationBatch complete — '
            + successCount + ' succeeded, ' + failCount + ' failed.');
        HAM_MigrationUtil.logSummary('HAM_Event_Form__c', successCount + failCount, successCount);
        Database.executeBatch(new HAM_FormElementMigrationBatch(), 100);
        // batch size 100 — form elements can be numerous; conservative for safety
    }
}