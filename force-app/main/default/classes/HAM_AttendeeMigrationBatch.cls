/**
 * HAM_AttendeeMigrationBatch
 * ─────────────────────────────────────────────────────────────────────────────
 * Migrates conference360__Attendee__c → CventEvents__Attendee__c.
 *
 * Key behaviours:
 *  - CventEvents__Status__c is a REQUIRED field — mapAttendeeStatus() guarantees
 *    it never resolves to null regardless of source value
 *  - Generates a fresh UUID AttendeeStub per attendee (required by Cvent)
 *  - Resolves parent Cvent Event and HAM_Event_Attendee_Group__c lookups via Stateful maps
 *  - Populates both HAM_BT_Attendee_Id__c (text ext ID) and HAM_BT_Attendee__c (lookup)
 *  - Preserves Hamilton-specific Affiliation and Class Year fields
 *  - Chains → HAM_FormMigrationBatch on finish()
 *
 * Live data (ref event a6KU1000008006uMAA): 548 attendees
 *   Status breakdown: Registered (502), Canceled (42), Declined (2), null (2)
 *   Status mapping confirmed from FullQA live data
 *
 * Prerequisites:
 *  - HAM_AttendeeGroupMigrationBatch and HAM_SalesDocumentMigrationBatch must have run first
 *    (SalesDoc must run before Attendee so HAM_Sales_Document__c lookup can resolve)
 *  - CventEvents__Attendee__c fields:
 *      HAM_BT_Attendee_Id__c           (Text 18, External ID = true)
 *      HAM_BT_Attendee__c              (Lookup → conference360__Attendee__c)
 *      HAM_Attendee_Affiliation__c     (Picklist)
 *      HAM_Attendee_Class_Year__c      (Text 10)
 *      HAM_BT_Attendee_Link__c         (URL)
 *      HAM_BT_Document_Link__c         (URL)
 *      HAM_BT_Attendee_Viewed_Link__c  (DateTime)
 *      HAM_Sales_Document__c           (Lookup → HAM_Event_Sales_Document__c)
 *
 * Change Log:
 *   v1.0  2026-04-09  Initial deployment
 *   v1.1  2026-04-14  PMD static analysis fixes
 *   v1.2  2026-04-16  Fix HAM_Attendee_Group__c — pass BT group Id directly
 *   v1.3  2026-04-17  NVV: ASC-XXXXX - Add Source field mapping (conference360__Source__c → HAM_Source__c)
 *   v1.4  2026-04-17  NVV: ASC-XXXXX - Add Attendee Link / Document Link / Viewed Link / Sales Document
 *                     mappings. Chain reordered: AttendeeGroup → SalesDoc → Attendee → LineItem.
 *   v1.5  2026-04-27  NVV: ASC-XXXXX - Add conference360__Event_Item__c → HAM_Event_Item__c and
 *                     conference360__Attendance_Status__c → HAM_BT_Attendance_Status__c mappings.
 * @description Batch class to migrate conference360__Attendee__c records to CventEvents__Attendee__c.
 */
public class HAM_AttendeeMigrationBatch
        implements Database.Batchable<SObject>, Database.Stateful {

    // Map: BT Event Id → Cvent Event Id
    private Map<Id, Id> btToCventEventMap  = new Map<Id, Id>();
    // Map: BT Sales Document Id → HAM_Event_Sales_Document__c Id
    private Map<Id, Id> btToHamSalesDocMap = new Map<Id, Id>();

    public Integer successCount = 0;
    public Integer failCount    = 0;

    // ── start() ───────────────────────────────────────────────────────────────
    /**
     * @description Builds event and attendee group maps, then returns a QueryLocator for all attendees.
     * @param bc BatchableContext provided by the platform
     * @return Database.QueryLocator scoped to attendees for migrated events
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
        Set<Id> cventEventIds = new Set<Id>(btToCventEventMap.values());

        // Build BT Sales Document → HAM Sales Document map (SalesDoc batch must have run first)
        for (HAM_Event_Sales_Document__c sd : [
            SELECT Id, HAM_BT_Source_Id__c
            FROM   HAM_Event_Sales_Document__c
            WHERE  HAM_BT_Source_Id__c != null
            AND    CventEvents_Event__c IN :cventEventIds
        ]) {
            btToHamSalesDocMap.put((Id) sd.HAM_BT_Source_Id__c, sd.Id);
        }

        return Database.getQueryLocator([
            SELECT Id,
                   conference360__Event__c,
                   conference360__Contact__c,
                   conference360__Registration_Status__c,
                   conference360__Registration_DateTime__c,
                   conference360__Attendance_Status__c,
                   conference360__Attendee_Group__c,
                   conference360__Email2__c,
                   conference360__First_Name2__c,
                   conference360__Last_Name2__c,
                   conference360__Source__c,
                   conference360__AttendeeLink__c,
                   conference360__Attendee_Viewed_Link__c,
                   conference360__Sales_Document__c,
                   conference360__Event_Item__c,
                   HAM_External_System_ID__c,
                   HAM_Attendee_Affiliation__c,
                   HAM_Attendee_Class_Year__c,
                   HAM_Document_Link__c
            FROM   conference360__Attendee__c
            WHERE  conference360__Event__c IN :btToCventEventMap.keySet()
        ]);
    }

    // ── execute() ─────────────────────────────────────────────────────────────
    /**
     * @description Upserts a batch of attendees into CventEvents__Attendee__c.
     * @param bc        BatchableContext provided by the platform
     * @param attendees Chunk of conference360__Attendee__c records to process
     */
    public void execute(
        Database.BatchableContext bc,
        List<conference360__Attendee__c> attendees
    ) {
        List<CventEvents__Attendee__c> toUpsert = new List<CventEvents__Attendee__c>();

        for (conference360__Attendee__c a : attendees) {
            Id cventEventId = btToCventEventMap.get(a.conference360__Event__c);
            if (cventEventId == null) { continue; }

            // Status is REQUIRED — mapAttendeeStatus() always returns a valid value
            String cventStatus = HAM_MigrationUtil.mapAttendeeStatus(
                a.conference360__Registration_Status__c
            );

            // Registration date: Datetime → Date
            Date regDate = (a.conference360__Registration_DateTime__c != null)
                ? a.conference360__Registration_DateTime__c.dateGmt()
                : null;

            toUpsert.add(new CventEvents__Attendee__c(
                // Parent event
                CventEvents__Event__c               = cventEventId,

                // Contact match (primary matching key)
                CventEvents__Contact__c             = a.conference360__Contact__c,

                // Required field — never null
                CventEvents__Status__c              = cventStatus,

                // Cvent-required stub — unique UUID per attendee
                CventEvents__AttendeeStub__c        = HAM_MigrationUtil.generateUUID(),

                // Registration metadata
                CventEvents__RegistrationDate__c    = regDate,
                CventEvents__ConfirmationNumber__c  = HAM_MigrationUtil.truncate(
                                                          a.HAM_External_System_ID__c, 18),

                // Attendee group link — lookup to conference360__Attendee_Group__c, pass BT Id directly
                HAM_Attendee_Group__c               = a.conference360__Attendee_Group__c,

                // Source — registration channel from Blackthorn
                HAM_Source__c                       = HAM_MigrationUtil.truncate(
                                                          a.conference360__Source__c, 255),

                // Hamilton-specific custom fields
                HAM_Attendee_Affiliation__c         = a.HAM_Attendee_Affiliation__c,
                HAM_Attendee_Class_Year__c          = a.HAM_Attendee_Class_Year__c,

                // BT link/document traceability — preserved from source before package removal
                HAM_BT_Attendee_Link__c             = a.conference360__AttendeeLink__c,
                HAM_BT_Document_Link__c             = a.HAM_Document_Link__c,
                HAM_BT_Attendee_Viewed_Link__c      = a.conference360__Attendee_Viewed_Link__c,

                // Event Item — lookup to conference360__Event_Item__c, pass BT Id directly
                HAM_Event_Item__c                   = a.conference360__Event_Item__c,

                // Attendance outcome — post-event status from Blackthorn
                HAM_BT_Attendance_Status__c         = a.conference360__Attendance_Status__c,

                // Sales Document lookup — resolved via BT Sales Doc Id → HAM Sales Doc
                HAM_Sales_Document__c               = btToHamSalesDocMap.get(a.conference360__Sales_Document__c),

                // Traceability — BOTH fields same BT record Id
                HAM_BT_Attendee_Id__c               = a.Id,  // External ID (upsert key)
                HAM_BT_Attendee__c                  = a.Id   // Lookup → conference360__Attendee__c
            ));
        }

        List<Database.UpsertResult> results =
            Database.upsert(toUpsert, CventEvents__Attendee__c.HAM_BT_Attendee_Id__c, false);

        for (Database.UpsertResult r : results) {
            if (r.isSuccess()) { successCount++; }
            else               { failCount++; }
        }
        HAM_MigrationUtil.logErrors(results, toUpsert, 'CventEvents__Attendee__c');
    }

    // ── finish() ──────────────────────────────────────────────────────────────
    /**
     * @description Logs completion summary and chains to HAM_LineItemMigrationBatch.
     * @param bc BatchableContext provided by the platform
     */
    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.DEBUG, 'HAM_AttendeeMigrationBatch complete — '
            + successCount + ' succeeded, ' + failCount + ' failed.');
        HAM_MigrationUtil.logSummary('CventEvents__Attendee__c', successCount + failCount, successCount);
        Database.executeBatch(new HAM_LineItemMigrationBatch(), 200);
    }
}