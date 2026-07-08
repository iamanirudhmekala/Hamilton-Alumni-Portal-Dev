/**
 * HAM_SponsorMigrationBatch
 * ─────────────────────────────────────────────────────────────────────────────
 * Migrates conference360__Sponsor__c → HAM_Associated_People__c (Role = Sponsor/Host).
 *
 * Key behaviours:
 *  - Writes to same HAM_Associated_People__c as HAM_SpeakerMigrationBatch
 *  - Uses 'SP-' prefix on HAM_BT_Source_Id__c to guarantee uniqueness vs. Speakers
 *  - Idempotent: upsert on HAM_BT_Source_Id__c
 *  - Populates HAM_BT_Sponsor__c (lookup → conference360__Sponsor__c)
 *  - HAM_BT_Speaker__c left null on Sponsor records
 *  - Chains → HAM_AttendeeGroupMigrationBatch on finish()
 *
 * Live data (ref event a6KU1000008006uMAA): 0 sponsors
 *   Pattern still applies to all other events in migration scope.
 *
 * Change Log:
 *   v1.0  2026-04-09  Initial deployment
 *   v1.1  2026-04-14  Fixed object name HAM_Associated_People__c, Cvent_Event__c,
 *                     Constituent__c field names
 *   v1.2  2026-04-14  PMD static analysis fixes
 * @description Batch class to migrate conference360__Sponsor__c records to HAM_Associated_People__c.
 */
public class HAM_SponsorMigrationBatch
        implements Database.Batchable<SObject>, Database.Stateful {

    private Map<Id, Id> btToCventEventMap = new Map<Id, Id>();
    public  Integer successCount = 0;
    public  Integer failCount    = 0;

    // ── start() ───────────────────────────────────────────────────────────────
    /**
     * @description Builds the BT-to-Cvent event map and returns a QueryLocator for all sponsors.
     * @param bc BatchableContext provided by the platform
     * @return Database.QueryLocator scoped to sponsors for migrated events
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        for (CventEvents__Event__c cv : [
            SELECT Id, HAM_BT_Event_Id__c
            FROM   CventEvents__Event__c
            WHERE  HAM_BT_Event_Id__c != null
        ]) {
            btToCventEventMap.put((Id) cv.HAM_BT_Event_Id__c, cv.Id);
        }

        return Database.getQueryLocator([
            SELECT Id,
                   Name,
                   conference360__Event__c,
                   conference360__Display_Name__c,
                   conference360__Bio_Rich__c,
                   conference360__Account__c,
                   conference360__Image_URL__c,
                   conference360__Website__c,
                   conference360__Status__c,
                   conference360__Tier__c,
                   conference360__Hide_On_Event_Page__c,
                   HAM_Constituent__c,
                   Role__c,
                   Notes__c
            FROM   conference360__Sponsor__c
            WHERE  conference360__Event__c IN :btToCventEventMap.keySet()
        ]);
    }

    // ── execute() ─────────────────────────────────────────────────────────────
    /**
     * @description Upserts a batch of sponsors into HAM_Associated_People__c.
     * @param bc       BatchableContext provided by the platform
     * @param sponsors Chunk of conference360__Sponsor__c records to process
     */
    public void execute(
        Database.BatchableContext bc,
        List<conference360__Sponsor__c> sponsors
    ) {
        List<HAM_Associated_People__c> toUpsert = new List<HAM_Associated_People__c>();

        for (conference360__Sponsor__c sp : sponsors) {
            Id cventEventId = btToCventEventMap.get(sp.conference360__Event__c);
            if (cventEventId == null) { continue; }

            toUpsert.add(new HAM_Associated_People__c(
                // Parent event lookup (existing field on HAM_Associated_People__c)
                Cvent_Event__c         = cventEventId,

                // Role — from BT Role__c picklist (Sponsor / Host)
                HAM_Role__c            = (sp.Role__c != null) ? sp.Role__c : 'Sponsor',

                // Sponsor-specific fields
                HAM_Display_Name__c    = HAM_MigrationUtil.truncate(sp.conference360__Display_Name__c, 255),
                HAM_Bio__c             = sp.conference360__Bio_Rich__c,
                HAM_Account__c         = sp.conference360__Account__c,
                Constituent__c         = sp.HAM_Constituent__c,  // Sponsor uses HAM_Constituent__c for Contact
                HAM_Image_URL__c       = sp.conference360__Image_URL__c,
                HAM_Website__c         = sp.conference360__Website__c,
                HAM_Status__c          = sp.conference360__Status__c,
                HAM_Sponsor_Tier__c    = sp.conference360__Tier__c,
                HAM_Hide_On_Page__c    = sp.conference360__Hide_On_Event_Page__c,
                HAM_Notes__c           = sp.Notes__c,

                // Traceability — Salesforce IDs are globally unique; no prefix needed
                HAM_BT_Source_Id__c    = sp.Id,
                HAM_BT_Sponsor__c      = sp.Id   // Lookup → conference360__Sponsor__c
                // HAM_BT_Speaker__c intentionally null on Sponsor records
            ));
        }

        List<Database.UpsertResult> results =
            Database.upsert(toUpsert, HAM_Associated_People__c.HAM_BT_Source_Id__c, false);

        for (Database.UpsertResult r : results) {
            if (r.isSuccess()) { successCount++; }
            else               { failCount++; }
        }
        HAM_MigrationUtil.logErrors(results, toUpsert, 'HAM_Associated_People__c(Sponsor)');
    }

    // ── finish() ──────────────────────────────────────────────────────────────
    /**
     * @description Logs completion summary and chains to HAM_AttendeeGroupMigrationBatch.
     * @param bc BatchableContext provided by the platform
     */
    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.DEBUG, 'HAM_SponsorMigrationBatch complete — '
            + successCount + ' succeeded, ' + failCount + ' failed.');
        HAM_MigrationUtil.logSummary('HAM_Associated_People__c(Sponsor)', successCount + failCount, successCount);
        Database.executeBatch(new HAM_AttendeeGroupMigrationBatch(), 200);
    }
}