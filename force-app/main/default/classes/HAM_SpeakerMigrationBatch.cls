/**
 * HAM_SpeakerMigrationBatch
 * ─────────────────────────────────────────────────────────────────────────────
 * Migrates conference360__Speaker__c → HAM_Associated_People__c (Role = Speaker).
 *
 * Key behaviours:
 *  - Writes to HAM_Associated_People__c — same target as HAM_SponsorMigrationBatch
 *  - Uses 'S-' prefix on HAM_BT_Source_Id__c to guarantee uniqueness vs. Sponsors
 *  - Idempotent: upsert on HAM_BT_Source_Id__c
 *  - Populates HAM_BT_Speaker__c (lookup → conference360__Speaker__c)
 *  - HAM_BT_Sponsor__c left null on Speaker records
 *  - Chains → HAM_SponsorMigrationBatch on finish()
 *
 * Live data (ref event a6KU1000008006uMAA): 6 confirmed speakers
 *   J. Emerson, D. Solomon, D. Blood, D. Wippman, K. Emerson, N. Rostow
 *   All have conference360__Contact__c populated
 *
 * Change Log:
 *   v1.0  2026-04-09  Initial deployment
 *   v1.1  2026-04-14  Fixed object name HAM_Associated_People__c, Cvent_Event__c,
 *                     Constituent__c field names
 *   v1.2  2026-04-14  PMD static analysis fixes
 *   v1.3  2026-04-17  NVV: ASC-XXXXX - Add Website field mapping (conference360__Website__c → HAM_Website__c)
 *   v1.4  2026-04-24  NVV: ASC-XXXXX - Map conference360__Speaker_Visibility__c → HAM_Speaker_Visibility__c
 * @description Batch class to migrate conference360__Speaker__c records to HAM_Associated_People__c.
 */
public class HAM_SpeakerMigrationBatch
        implements Database.Batchable<SObject>, Database.Stateful {

    private Map<Id, Id> btToCventEventMap = new Map<Id, Id>();
    public  Integer successCount = 0;
    public  Integer failCount    = 0;

    // ── start() ───────────────────────────────────────────────────────────────
    /**
     * @description Builds the BT-to-Cvent event map and returns a QueryLocator for all speakers.
     * @param bc BatchableContext provided by the platform
     * @return Database.QueryLocator scoped to speakers for migrated events
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
                   conference360__First_Name__c,
                   conference360__Last_Name__c,
                   conference360__Title__c,
                   conference360__Bio_Rich__c,
                   conference360__Short_Description2__c,
                   conference360__Email__c,
                   conference360__Phone__c,
                   conference360__Account_Name__c,
                   conference360__Account__c,
                   conference360__Contact__c,
                   conference360__Image_URL__c,
                   conference360__LinkedIn__c,
                   conference360__Twitter__c,
                   conference360__Website__c,
                   conference360__Status__c,
                   conference360__Speaker_Visibility__c,
                   conference360__Hide_On_Event_Page__c,
                   Role__c,
                   Notes__c
            FROM   conference360__Speaker__c
            WHERE  conference360__Event__c IN :btToCventEventMap.keySet()
        ]);
    }

    // ── execute() ─────────────────────────────────────────────────────────────
    /**
     * @description Upserts a batch of speakers into HAM_Associated_People__c.
     * @param bc       BatchableContext provided by the platform
     * @param speakers Chunk of conference360__Speaker__c records to process
     */
    public void execute(
        Database.BatchableContext bc,
        List<conference360__Speaker__c> speakers
    ) {
        List<HAM_Associated_People__c> toUpsert = new List<HAM_Associated_People__c>();

        for (conference360__Speaker__c sp : speakers) {
            Id cventEventId = btToCventEventMap.get(sp.conference360__Event__c);
            if (cventEventId == null) { continue; }

            toUpsert.add(new HAM_Associated_People__c(
                // Parent event lookup (existing field on HAM_Associated_People__c)
                Cvent_Event__c         = cventEventId,

                // Role — from BT Role__c picklist (Speaker / Presenter / Moderator)
                HAM_Role__c            = (sp.Role__c != null) ? sp.Role__c : 'Speaker',

                // Personal details
                HAM_First_Name__c      = HAM_MigrationUtil.truncate(sp.conference360__First_Name__c, 255),
                HAM_Last_Name__c       = HAM_MigrationUtil.truncate(sp.conference360__Last_Name__c, 255),
                // HAM_Title__c and HAM_Email__c — create these fields on HAM_Associated_People__c first,
                // then uncomment and redeploy this class:
                // HAM_Title__c        = HAM_MigrationUtil.truncate(sp.conference360__Title__c, 255),
                // HAM_Email__c        = sp.conference360__Email__c,
                HAM_Bio__c             = sp.conference360__Bio_Rich__c,
                HAM_Short_Bio__c       = HAM_MigrationUtil.truncate(sp.conference360__Short_Description2__c, 255),
                HAM_Phone__c           = sp.conference360__Phone__c,
                HAM_Company__c         = HAM_MigrationUtil.truncate(sp.conference360__Account_Name__c, 255),
                HAM_Account__c         = sp.conference360__Account__c,
                Constituent__c         = sp.conference360__Contact__c,
                HAM_Image_URL__c       = sp.conference360__Image_URL__c,
                HAM_LinkedIn__c        = sp.conference360__LinkedIn__c,
                HAM_Twitter__c         = sp.conference360__Twitter__c,
                HAM_Website__c         = sp.conference360__Website__c,
                HAM_Status__c          = sp.conference360__Status__c,
                HAM_Hide_On_Page__c       = sp.conference360__Hide_On_Event_Page__c,
                HAM_Speaker_Visibility__c = sp.conference360__Speaker_Visibility__c,
                HAM_Notes__c           = sp.Notes__c,

                // Traceability — Salesforce IDs are globally unique; no prefix needed
                HAM_BT_Source_Id__c    = sp.Id,
                HAM_BT_Speaker__c      = sp.Id   // Lookup → conference360__Speaker__c
                // HAM_BT_Sponsor__c intentionally null on Speaker records
            ));
        }

        List<Database.UpsertResult> results =
            Database.upsert(toUpsert, HAM_Associated_People__c.HAM_BT_Source_Id__c, false);

        for (Database.UpsertResult r : results) {
            if (r.isSuccess()) { successCount++; }
            else               { failCount++; }
        }
        HAM_MigrationUtil.logErrors(results, toUpsert, 'HAM_Associated_People__c(Speaker)');
    }

    // ── finish() ──────────────────────────────────────────────────────────────
    /**
     * @description Logs completion summary and chains to HAM_SponsorMigrationBatch.
     * @param bc BatchableContext provided by the platform
     */
    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.DEBUG, 'HAM_SpeakerMigrationBatch complete — '
            + successCount + ' succeeded, ' + failCount + ' failed.');
        HAM_MigrationUtil.logSummary('HAM_Associated_People__c(Speaker)', successCount + failCount, successCount);
        Database.executeBatch(new HAM_SponsorMigrationBatch(), 200);
    }
}