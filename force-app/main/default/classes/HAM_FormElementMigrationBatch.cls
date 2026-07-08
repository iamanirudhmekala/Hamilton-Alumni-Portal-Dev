/**
 * HAM_FormElementMigrationBatch
 * ─────────────────────────────────────────────────────────────────────────────
 * Migrates conference360__Form_Element__c → HAM_Event_Form_Element__c.
 *
 * Key behaviours:
 *  - Resolves parent HAM_Event_Form__c via HAM_BT_Source_Id__c map
 *  - Sort Order is preserved from BT Sort_Order__c (critical for question sequence)
 *  - Picklist values stored as-is (newline-delimited text)
 *  - Controlling Form Element cross-reference resolved post-upsert (see note below)
 *  - Idempotent: upsert on HAM_BT_Source_Id__c
 *  - Populates HAM_BT_Form_Element__c (lookup → conference360__Form_Element__c)
 *  - Chains → HAM_EmailTemplateMigrationBatch on finish()
 *
 * Live data (ref event a6KU1000008006uMAA — '1812 LCW FORM'):
 *   FE-0214: Will you attend formal board meeting? (Picklist, Required, Sort 0)
 *   FE-0203: Affiliation with Hamilton/Kirkland (Picklist, Required, Sort 1)
 *   FE-0204: Additional food allergies (Text, Required, Sort 2)
 *   FE-0205: Dietary restrictions (Multi-Select Picklist, Required, Sort 3)
 *
 * NOTE on controlling elements:
 *   If conference360__Controlling_Form_Element__c is populated on any element,
 *   the cross-reference cannot be resolved in-flight (the controlling element
 *   may not yet exist in HAM_Event_Form_Element__c). After this batch completes,
 *   run the post-migration script to update HAM_Controlling_Element__c using
 *   HAM_BT_Source_Id__c lookups.
 *
 * Change Log:
 *   v1.0  2026-04-09  Initial deployment
 *   v1.1  2026-04-14  PMD static analysis fixes
 * @description Batch class to migrate conference360__Form_Element__c records to HAM_Event_Form_Element__c.
 */
public class HAM_FormElementMigrationBatch
        implements Database.Batchable<SObject>, Database.Stateful {

    // Map: BT Form Id → HAM_Event_Form__c Id
    private Map<Id, Id> btToNewFormMap = new Map<Id, Id>();
    public  Integer successCount = 0;
    public  Integer failCount    = 0;

    // ── start() ───────────────────────────────────────────────────────────────
    /**
     * @description Builds the form map and returns a QueryLocator for all form elements.
     * @param bc BatchableContext provided by the platform
     * @return Database.QueryLocator scoped to form elements for migrated forms
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Build form map — forms migrated by previous batch
        for (HAM_Event_Form__c hf : [
            SELECT Id, HAM_BT_Source_Id__c
            FROM   HAM_Event_Form__c
            WHERE  HAM_BT_Source_Id__c != null
        ]) {
            btToNewFormMap.put((Id) hf.HAM_BT_Source_Id__c, hf.Id);
        }

        return Database.getQueryLocator([
            SELECT Id,
                   conference360__Form__c,
                   conference360__Question__c,
                   conference360__Type__c,
                   conference360__Required__c,
                   conference360__Sort_Order__c,
                   conference360__Picklist_Values__c,
                   conference360__Maps_To_Object__c,
                   conference360__Maps_To_Field__c,
                   conference360__Hint__c,
                   conference360__Default_Picklist_Value2__c,
                   conference360__Character_Length__c,
                   conference360__Controlling_Form_Element__c,
                   conference360__Controlling_Form_Element_Answer__c
            FROM   conference360__Form_Element__c
            WHERE  conference360__Form__c IN :btToNewFormMap.keySet()
            ORDER BY conference360__Sort_Order__c ASC NULLS LAST
        ]);
    }

    // ── execute() ─────────────────────────────────────────────────────────────
    /**
     * @description Upserts a batch of form elements into HAM_Event_Form_Element__c.
     * @param bc       BatchableContext provided by the platform
     * @param elements Chunk of conference360__Form_Element__c records to process
     */
    public void execute(
        Database.BatchableContext bc,
        List<conference360__Form_Element__c> elements
    ) {
        List<HAM_Event_Form_Element__c> toUpsert = new List<HAM_Event_Form_Element__c>();

        for (conference360__Form_Element__c fe : elements) {
            Id newFormId = btToNewFormMap.get(fe.conference360__Form__c);
            if (newFormId == null) { continue; }

            // Sanitise Maps_To values — BT stores '--None--' when empty
            String mapsToObj   = ('--None--'.equals(fe.conference360__Maps_To_Object__c))
                                   ? null : fe.conference360__Maps_To_Object__c;
            String mapsToField = ('--None--'.equals(fe.conference360__Maps_To_Field__c))
                                   ? null : fe.conference360__Maps_To_Field__c;

            toUpsert.add(new HAM_Event_Form_Element__c(
                // Parent form (Master-Detail)
                HAM_Event_Form__c                   = newFormId,

                // Question definition
                HAM_Question__c                     = fe.conference360__Question__c,
                HAM_Question_Type__c                = fe.conference360__Type__c,
                HAM_Required__c                     = (fe.conference360__Required__c == true),
                HAM_Sort_Order__c                   = (fe.conference360__Sort_Order__c != null)
                                                        ? (Integer) fe.conference360__Sort_Order__c
                                                        : null,

                // Picklist configuration
                HAM_Picklist_Values__c              = fe.conference360__Picklist_Values__c,
                HAM_Default_Value__c                = HAM_MigrationUtil.truncate(
                                                          fe.conference360__Default_Picklist_Value2__c, 255),

                // Field mapping (for data sync questions)
                HAM_Maps_To_Object__c               = HAM_MigrationUtil.truncate(mapsToObj, 255),
                HAM_Maps_To_Field__c                = HAM_MigrationUtil.truncate(mapsToField, 255),

                // Display helpers
                HAM_Hint__c                         = fe.conference360__Hint__c,
                HAM_Character_Length__c             = (fe.conference360__Character_Length__c != null)
                                                        ? (Integer) fe.conference360__Character_Length__c
                                                        : null,
                // Controlling element stored as BT source ID for post-migration re-link
                // HAM_Controlling_Element__c is set by post-migration script
                HAM_BT_Controlling_Element_Id__c    = (fe.conference360__Controlling_Form_Element__c != null)
                                                        ? (String) fe.conference360__Controlling_Form_Element__c
                                                        : null,
                HAM_Controlling_Element_Answer__c   = HAM_MigrationUtil.truncate(
                                                          fe.conference360__Controlling_Form_Element_Answer__c, 255),

                // Traceability
                HAM_BT_Source_Id__c                 = fe.Id
                // HAM_BT_Form_Element__c points to conference360__Form__c (wrong target) — not set
            ));
        }

        List<Database.UpsertResult> results =
            Database.upsert(toUpsert, HAM_Event_Form_Element__c.HAM_BT_Source_Id__c, false);

        for (Database.UpsertResult r : results) {
            if (r.isSuccess()) { successCount++; }
            else               { failCount++; }
        }
        HAM_MigrationUtil.logErrors(results, toUpsert, 'HAM_Event_Form_Element__c');
    }

    // ── finish() ──────────────────────────────────────────────────────────────
    /**
     * @description Logs completion summary and chains to HAM_EmailTemplateMigrationBatch.
     * @param bc BatchableContext provided by the platform
     */
    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.DEBUG, 'HAM_FormElementMigrationBatch complete — '
            + successCount + ' succeeded, ' + failCount + ' failed.');
        HAM_MigrationUtil.logSummary('HAM_Event_Form_Element__c', successCount + failCount, successCount);
        Database.executeBatch(new HAM_FormSubmissionMigrationBatch(), 200);
    }
}