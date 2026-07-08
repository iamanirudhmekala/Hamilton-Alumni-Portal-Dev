/**
 * HAM_EmailTemplateMigrationBatch
 * ─────────────────────────────────────────────────────────────────────────────
 * Migrates conference360__Email_Template__c → HAM_Event_Email_Template__c.
 * Chains → HAM_TrackSessionMigrationBatch on finish().
 *
 * Key behaviours:
 *  - Derives HAM_Template_Type__c from which field on the event referenced it:
 *      conference360__Confirmation_Email__c   → 'Confirmation'
 *      conference360__Waitlisted_Email__c     → 'Waitlist'
 *      conference360__Waitlisted_Pending_Email__c → 'Waitlist Pending'
 *  - Queries templates directly via conference360__Event__c (faster than subquery)
 *  - Idempotent: upsert on HAM_BT_Source_Id__c
 *  - Populates HAM_BT_Email_Template__c (lookup → conference360__Email_Template__c)
 *  - Chains → HAM_TrackSessionMigrationBatch on finish()
 *
 * Live data (ref event a6KU1000008006uMAA):
 *   1 template: 'Registration Email' (a65U10000009LurIAE)
 *   SF Template Id: 00XU1000007SUS9MAO
 *   Confirmation_Email__c references this template
 *
 * NOTE: Cvent manages its own email system. These templates are stored in
 * Salesforce for historical reference and reporting only — they are not
 * consumed by the Cvent platform directly.
 *
 * Change Log:
 *   v1.0  2026-04-09  Initial deployment
 *   v1.1  2026-04-14  Fixed CventEvents_Event__c field name (single underscore)
 *   v1.2  2026-04-14  Fixed shared template bug — use templateToEventMap instead of
 *                     t.conference360__Event__c (templates point to master event, not
 *                     the migrated event; silent skip caused 0 templates to migrate)
 *   v1.3  2026-04-21  NVV: ASC-XXXXX - Chain finish() to HAM_TrackSessionMigrationBatch
 */
/**
 * @description Batch class that migrates conference360__Email_Template__c records to
 *              HAM_Event_Email_Template__c. This is the last batch in the
 *              Blackthorn → Cvent migration pipeline.
 */
public class HAM_EmailTemplateMigrationBatch
        implements Database.Batchable<SObject>, Database.Stateful {

    private Map<Id, Id>     btToCventEventMap  = new Map<Id, Id>();
    // templateId → derived type label
    private Map<Id, String> templateTypeMap    = new Map<Id, String>();
    // templateId → Cvent Event Id (resolved from which event referenced the template)
    private Map<Id, Id>     templateToEventMap = new Map<Id, Id>();

    public Integer successCount = 0;
    public Integer failCount    = 0;

    // ── start() ───────────────────────────────────────────────────────────────
    /**
     * @description Builds event and template type maps, then returns a QueryLocator
     *              for all conference360__Email_Template__c records referenced by migrated events.
     * @param bc BatchableContext provided by the platform.
     * @return Database.QueryLocator scoped to templates referenced by migrated events.
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

        // Derive template type from the referencing field on each event
        Set<Id> templateIds = new Set<Id>();
        for (conference360__Event__c ev : [
            SELECT Id,
                   conference360__Confirmation_Email__c,
                   conference360__Waitlisted_Email__c,
                   conference360__Waitlisted_Pending_Email__c
            FROM   conference360__Event__c
            WHERE  Id IN :btToCventEventMap.keySet()
            AND   (conference360__Confirmation_Email__c != null
                OR conference360__Waitlisted_Email__c != null
                OR conference360__Waitlisted_Pending_Email__c != null)
        ]) {
            Id cventEvId = btToCventEventMap.get(ev.Id);
            if (ev.conference360__Confirmation_Email__c != null) {
                templateIds.add(ev.conference360__Confirmation_Email__c);
                templateTypeMap.put(ev.conference360__Confirmation_Email__c, 'Confirmation');
                if (!templateToEventMap.containsKey(ev.conference360__Confirmation_Email__c)) {
                    templateToEventMap.put(ev.conference360__Confirmation_Email__c, cventEvId);
                }
            }
            if (ev.conference360__Waitlisted_Email__c != null) {
                templateIds.add(ev.conference360__Waitlisted_Email__c);
                if (!templateTypeMap.containsKey(ev.conference360__Waitlisted_Email__c)) {
                    templateTypeMap.put(ev.conference360__Waitlisted_Email__c, 'Waitlist');
                    templateToEventMap.put(ev.conference360__Waitlisted_Email__c, cventEvId);
                }
            }
            if (ev.conference360__Waitlisted_Pending_Email__c != null) {
                templateIds.add(ev.conference360__Waitlisted_Pending_Email__c);
                if (!templateTypeMap.containsKey(ev.conference360__Waitlisted_Pending_Email__c)) {
                    templateTypeMap.put(ev.conference360__Waitlisted_Pending_Email__c, 'Waitlist Pending');
                    templateToEventMap.put(ev.conference360__Waitlisted_Pending_Email__c, cventEvId);
                }
            }
        }

        return Database.getQueryLocator([
            SELECT Id,
                   Name,
                   conference360__Event__c,
                   conference360__SF_Template_Id__c,
                   conference360__JSON_File_1__c,
                   conference360__JSON_File_2__c
            FROM   conference360__Email_Template__c
            WHERE  Id IN :templateIds
        ]);
    }

    // ── execute() ─────────────────────────────────────────────────────────────
    /**
     * @description Transforms each Blackthorn Email Template into a
     *              HAM_Event_Email_Template__c record and upserts using
     *              HAM_BT_Source_Id__c as the external ID key.
     * @param bc BatchableContext provided by the platform.
     * @param templates Chunk of conference360__Email_Template__c records to process.
     */
    public void execute(
        Database.BatchableContext bc,
        List<conference360__Email_Template__c> templates
    ) {
        List<HAM_Event_Email_Template__c> toUpsert = new List<HAM_Event_Email_Template__c>();

        for (conference360__Email_Template__c t : templates) {
            Id cventEventId = templateToEventMap.get(t.Id);
            if (cventEventId == null) { continue; }

            String templateType = templateTypeMap.containsKey(t.Id)
                ? templateTypeMap.get(t.Id)
                : 'Custom';

            toUpsert.add(new HAM_Event_Email_Template__c(
                // Parent event lookup
                CventEvents_Event__c        = cventEventId,

                // Core fields
                HAM_Template_Name__c        = HAM_MigrationUtil.truncate(t.Name, 80),
                HAM_Template_Type__c        = templateType,
                HAM_SF_Template_Id__c       = HAM_MigrationUtil.truncate(
                                                  t.conference360__SF_Template_Id__c, 20),
                // JSON content fields — stored as-is (up to 131,072 chars each)
                HAM_JSON_Content_1__c       = t.conference360__JSON_File_1__c,
                HAM_JSON_Content_2__c       = t.conference360__JSON_File_2__c,

                // Traceability
                HAM_BT_Source_Id__c         = t.Id,
                HAM_BT_Email_Template__c    = t.Id  // Lookup → conference360__Email_Template__c
            ));
        }

        List<Database.UpsertResult> results =
            Database.upsert(toUpsert, HAM_Event_Email_Template__c.HAM_BT_Source_Id__c, false);

        for (Database.UpsertResult r : results) {
            if (r.isSuccess()) {
                successCount++;
            } else {
                failCount++;
            }
        }
        HAM_MigrationUtil.logErrors(results, toUpsert, 'HAM_Event_Email_Template__c');
    }

    // ── finish() ──────────────────────────────────────────────────────────────
    /**
     * @description Logs completion summary and chains to HAM_TrackSessionMigrationBatch.
     * @param bc BatchableContext provided by the platform.
     */
    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.DEBUG, 'HAM_EmailTemplateMigrationBatch complete — '
            + successCount + ' succeeded, ' + failCount + ' failed.');
        HAM_MigrationUtil.logSummary('HAM_Event_Email_Template__c', successCount + failCount, successCount);
        Database.executeBatch(new HAM_TrackSessionMigrationBatch(), 200);
    }
}