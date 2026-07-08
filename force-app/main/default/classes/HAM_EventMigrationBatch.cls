/**
 * HAM_EventMigrationBatch
 * ─────────────────────────────────────────────────────────────────────────────
 * Migrates conference360__Event__c → CventEvents__Event__c.
 *
 * Key behaviours:
 *  - Date-range filter on Event_Start_Date__c (inclusive)
 *  - Null start-date events (test/template records) excluded automatically
 *  - Idempotent: upsert on HAM_BT_Event_Id__c (External ID)
 *  - Populates both HAM_BT_Event_Id__c (text) AND HAM_BT_Event__c (lookup)
 *  - Chains → HAM_TrackMigrationBatch on finish()
 *
 * Prerequisites (must exist before deploying):
 *  - CventEvents__Event__c.HAM_BT_Event_Id__c  (Text 18, External ID = true)
 *  - CventEvents__Event__c.HAM_BT_Event__c     (Lookup → conference360__Event__c)
 *
 * Change Log:
 *   v1.0  2026-04-09  Initial deployment
 *   v1.1  2026-04-14  Added CventEvents__pkg_PlannerEmail__c and HAMImageURL__c mappings
 *   v1.2  2026-04-21  NVV: ASC-XXXXX - Chain finish() to HAM_TrackMigrationBatch (was HAM_SessionMigrationBatch)
 *   v1.3  2026-04-24  NVV: ASC-XXXXX - Add HAM_Private_Event__c, HAM_BT_Organizer_Contact__c, HAM_BT_Organizer_Account__c, HAM_BT_Venue_Account__c mappings
 *   v1.4  2026-04-28  NVV: ASC-XXXXX - Default CventEvents__pkg_Category__c to 'Blackthorn (null)' when BT category is blank
 *   v1.5  2026-05-04  NVV: ASC-XXXXX - Map ADVPublicPrivate__c from HAM_Private_Event__c (Private→Private, else Public)
 */
/**
 * @description Batch class that migrates conference360__Event__c records to
 *              CventEvents__Event__c. Runs as part of the Blackthorn → Cvent
 *              migration pipeline and chains to HAM_SessionMigrationBatch on completion.
 */
public class HAM_EventMigrationBatch
        implements Database.Batchable<SObject>, Database.Stateful {

    // ── Date range set by orchestrator ────────────────────────────────────────
    private Date rangeStart;
    private Date rangeEnd;

    // ── Stateful counters (persist across execute() chunks) ───────────────────
    public Integer successCount = 0;
    public Integer failCount    = 0;

    /**
     * @description Constructor — pass the inclusive date range for this migration run.
     * @param startDate Start of date range
     * @param endDate   End of date range
     */
    public HAM_EventMigrationBatch(Date startDate, Date endDate) {
        this.rangeStart = startDate;
        this.rangeEnd   = endDate;
    }

    // ── start() ───────────────────────────────────────────────────────────────
    /**
     * @description Returns a QueryLocator for all conference360__Event__c records
     *              within the configured date range.
     * @param bc BatchableContext provided by the platform.
     * @return Database.QueryLocator scoped to the migration date range.
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id,
                   Name,
                   conference360__Event_Start_Date__c,
                   conference360__Event_End_Date__c,
                   conference360__Event_Start_Time__c,
                   conference360__Event_End_Time__c,
                   conference360__Status__c,
                   conference360__Category__c,
                   conference360__Description__c,
                   conference360__Short_Description__c,
                   conference360__Success_Message__c,
                   conference360__AttendeeLink_Message__c,
                   conference360__Attendee_Limit__c,
                   conference360__Venue_Name__c,
                   conference360__Venue_Street__c,
                   conference360__Venue_City__c,
                   conference360__Venue_State_Province__c,
                   conference360__Venue_Postal_Code__c,
                   conference360__Venue_Country__c,
                   conference360__Event_Location__c,
                   conference360__Time_Zone__c,
                   conference360__Free__c,
                   conference360__Visible__c,
                   conference360__Registration_End_Date__c,
                   conference360__Event_Page_URL__c,
                   conference360__Contactus_Email__c,
                   conference360__Image_URL__c,
                   HAM_Private_Event__c,
                   conference360__Organizer_Contact__c,
                   conference360__Organizer_Account__c,
                   conference360__Venue__c
            FROM   conference360__Event__c
            WHERE  conference360__Event_Start_Date__c >= :rangeStart
            AND    conference360__Event_Start_Date__c <= :rangeEnd
            AND    conference360__Event_Start_Date__c != null
        ]);
    }

    // ── execute() ─────────────────────────────────────────────────────────────
    /**
     * @description Transforms each Blackthorn Event into a CventEvents__Event__c
     *              record and upserts using HAM_BT_Event_Id__c as the external ID key.
     * @param bc BatchableContext provided by the platform.
     * @param btEvents Chunk of conference360__Event__c records to process.
     */
    public void execute(
        Database.BatchableContext bc,
        List<conference360__Event__c> btEvents
    ) {
        List<CventEvents__Event__c> toUpsert = new List<CventEvents__Event__c>();

        for (conference360__Event__c bt : btEvents) {

            String evtDesc = bt.conference360__Description__c;

            toUpsert.add(new CventEvents__Event__c(
                // ── 5 Required fields ─────────────────────────────────────────
                CventEvents__pkg_Title__c
                    = HAM_MigrationUtil.truncate(bt.Name, 255),
                CventEvents__pkg_Code__c
                    = HAM_MigrationUtil.generateCode(),
                CventEvents__pkg_EventStub__c
                    = HAM_MigrationUtil.generateUUID(),
                CventEvents__pkg_Category__c
                    = HAM_MigrationUtil.truncate(
                        String.isBlank(bt.conference360__Category__c) ? 'Blackthorn (null)' : bt.conference360__Category__c,
                        30
                    ),
                CventEvents__pkg_EventStatus__c
                    = HAM_MigrationUtil.mapEventStatus(bt.conference360__Status__c),

                // ── Registration status ────────────────────────────────────────
                CventEvents__pkg_Status__c = 'Active',

                // ── Dates & times ──────────────────────────────────────────────
                CventEvents__pkg_StartDate__c = bt.conference360__Event_Start_Date__c,
                CventEvents__pkg_EndDate__c   = bt.conference360__Event_End_Date__c,
                CventEvents__pkg_StartTime__c = bt.conference360__Event_Start_Time__c,
                CventEvents__pkg_EndTime__c   = bt.conference360__Event_End_Time__c,

                // ── Description ────────────────────────────────────────────────
                CventEvents__pkg_Description__c = bt.conference360__Short_Description__c,
                HAM_Description__c              = evtDesc,
                HAM_Success_Message__c          = bt.conference360__Success_Message__c,
                HAM_AttendeeLink_Message__c     = bt.conference360__AttendeeLink_Message__c,

                // ── Venue / location ───────────────────────────────────────────
                CventEvents__pkg_Location__c
                    = HAM_MigrationUtil.truncate(bt.conference360__Venue_Name__c, 255),
                CventEvents__pkg_Address1__c
                    = HAM_MigrationUtil.truncate(bt.conference360__Venue_Street__c, 40),
                CventEvents__pkg_City__c
                    = HAM_MigrationUtil.truncate(bt.conference360__Venue_City__c, 40),
                CventEvents__pkg_StateName__c
                    = HAM_MigrationUtil.truncate(bt.conference360__Venue_State_Province__c, 50),
                CventEvents__pkg_PostalCode__c
                    = HAM_MigrationUtil.truncate(bt.conference360__Venue_Postal_Code__c, 25),
                CventEvents__pkg_CountryName__c
                    = HAM_MigrationUtil.truncate(bt.conference360__Venue_Country__c, 40),
                CventEvents__pkg_TimeZone__c
                    = HAM_MigrationUtil.truncate(bt.conference360__Time_Zone__c, 50),
                CventEvents__pkg_EventFormat__c = bt.conference360__Event_Location__c,

                // ── Capacity / registration ────────────────────────────────────
                CventEvents__pkg_Capacity__c
                    = HAM_MigrationUtil.mapCapacity(bt.conference360__Attendee_Limit__c),
                CventEvents__pkg_HasFee__c
                    = !(bt.conference360__Free__c == true),
                CventEvents__pkg_IsHidden__c
                    = !(bt.conference360__Visible__c == true),
                CventEvents__pkg_RegistrationDeadlineDate__c
                    = bt.conference360__Registration_End_Date__c,
                CventEvents__pkg_RegistrationLink__c
                    = bt.conference360__Event_Page_URL__c,

                // ── Additional fields ─────────────────────────────────────────
                CventEvents__pkg_PlannerEmail__c
                    = bt.conference360__Contactus_Email__c,
                HAMImageURL__c
                    = bt.conference360__Image_URL__c,

                // ── Additional BT traceability fields ─────────────────────────
                HAM_Private_Event__c          = bt.HAM_Private_Event__c,
                ADVPublicPrivate__c           = bt.HAM_Private_Event__c == true ? 'Private' : 'Public',
                HAM_BT_Organizer_Contact__c   = bt.conference360__Organizer_Contact__c,
                HAM_BT_Organizer_Account__c   = bt.conference360__Organizer_Account__c,
                HAM_BT_Venue_Account__c       = bt.conference360__Venue__c,

                // ── Traceability — BOTH fields populated with same BT record Id ─
                HAM_BT_Event_Id__c = bt.Id,   // Text Ext ID → upsert key
                HAM_BT_Event__c    = bt.Id    // Lookup → conference360__Event__c
            ));
        }

        List<Database.UpsertResult> results =
            Database.upsert(toUpsert, CventEvents__Event__c.HAM_BT_Event_Id__c, false);

        for (Database.UpsertResult r : results) {
            if (r.isSuccess()) {
                successCount++;
            } else {
                failCount++;
            }
        }
        HAM_MigrationUtil.logErrors(results, toUpsert, 'CventEvents__Event__c');
    }

    // ── finish() ──────────────────────────────────────────────────────────────
    /**
     * @description Logs batch completion counts and chains to HAM_TrackMigrationBatch.
     * @param bc BatchableContext provided by the platform.
     */
    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.DEBUG, 'HAM_EventMigrationBatch complete — '
            + successCount + ' succeeded, ' + failCount + ' failed.');
        HAM_MigrationUtil.logSummary('CventEvents__Event__c', successCount + failCount, successCount);
        Database.executeBatch(new HAM_TrackMigrationBatch(), 200);
    }
}