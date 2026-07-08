/**
 * HAM_EventSettingsMigrationBatch
 * ─────────────────────────────────────────────────────────────────────────────
 * Migrates conference360__Event_Settings__c → HAM_Event_Settings__c.
 *
 * Key behaviours:
 *  - Builds btToCventEventMap and btEventToSettingsId in start() (Stateful)
 *  - Scoped to settings profiles referenced by at least one migrated event
 *  - Idempotent: upsert on HAM_BT_Event_Settings_Id__c (External ID)
 *  - Accumulates btSettingsToHamId map across execute() chunks (Stateful)
 *  - finish() second pass: stamps CventEvents__Event__c.HAM_Event_Settings__c
 *    for every migrated event whose source event had a settings profile
 *  - finish() chains to HAM_ProductMigrationBatch to kick off Phase 2 pipeline
 *
 * Change Log:
 *   v1.0  2026-04-24  NVV: Initial deployment
 *   v1.1  05/08/2026  NVV: ASC-XXXXX - Chain to HAM_ProductMigrationBatch (Phase 2 start)
 *
 * @description Batch class to migrate conference360__Event_Settings__c records
 *              to HAM_Event_Settings__c. Final step in the migration pipeline.
 */
public class HAM_EventSettingsMigrationBatch
        implements Database.Batchable<SObject>, Database.Stateful {

    @TestVisible private Map<Id, Id> btToCventEventMap   = new Map<Id, Id>();
    @TestVisible private Map<Id, Id> btEventToSettingsId = new Map<Id, Id>();
    @TestVisible private Map<Id, Id> btSettingsToHamId   = new Map<Id, Id>();
    public Integer successCount = 0;
    public Integer failCount    = 0;

    // ── start() ───────────────────────────────────────────────────────────────
    /**
     * @description Builds BT-to-Cvent event map, BT event-to-settings map, then
     *              returns a QueryLocator scoped to settings referenced by migrated events.
     * @param bc BatchableContext provided by the platform.
     * @return Database.QueryLocator for conference360__Event_Settings__c records.
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        for (CventEvents__Event__c cv : [
            SELECT Id, HAM_BT_Event_Id__c
            FROM   CventEvents__Event__c
            WHERE  HAM_BT_Event_Id__c != null
            WITH SECURITY_ENFORCED
        ]) {
            btToCventEventMap.put((Id) cv.HAM_BT_Event_Id__c, cv.Id);
        }

        for (conference360__Event__c ev : [
            SELECT Id, conference360__Event_Settings__c
            FROM   conference360__Event__c
            WHERE  Id IN :btToCventEventMap.keySet()
            AND    conference360__Event_Settings__c != null
        ]) {
            btEventToSettingsId.put(ev.Id, ev.conference360__Event_Settings__c);
        }

        Set<Id> btSettingsIds = new Set<Id>(btEventToSettingsId.values());

        return Database.getQueryLocator([
            SELECT Id,
                   Name,
                   conference360__Default__c,
                   conference360__Color_Theme__c,
                   conference360__Background_Color__c,
                   conference360__Font__c,
                   conference360__Card_Color_Theme__c,
                   conference360__Attendees__c,
                   conference360__Sessions__c,
                   conference360__Speakers__c,
                   conference360__Sponsors__c,
                   conference360__Venue__c,
                   conference360__FAQ__c,
                   conference360__Contact_Us__c,
                   conference360__Content__c,
                   conference360__Custom_Tabs__c,
                   conference360__WiFi__c,
                   conference360__Tracks__c,
                   conference360__Enable_Cancel_Registration__c,
                   conference360__Greeting_Name_Formality__c,
                   conference360__One_Unique_Attendee_Email_Per_Event__c,
                   conference360__Hide_Main_Contact_Address__c,
                   conference360__Hide_Main_Contact_Company_Name__c,
                   conference360__Hide_Price_Range__c,
                   conference360__Hide_QR_from_AttendeeLink__c,
                   conference360__Overview_Pricing__c,
                   conference360__Search_Bar__c,
                   conference360__Auto_update_Attendance_to_No_Show__c,
                   conference360__Waitlist_Automate__c,
                   conference360__Waitlist_Message__c,
                   conference360__Enabled_Payment_Methods__c,
                   conference360__Create_Opportunities_For_Donations__c,
                   conference360__Create_Opportunity_From_Checkout__c,
                   conference360__Create_Zero_Dollar_Opportunities__c,
                   conference360__Opportunity_Open_Stage_Name__c,
                   conference360__Opportunity_Successful_Stage_Name__c,
                   conference360__Require_At_Least_One_Ticket_To_Publish__c,
                   conference360__Show_Expired_Tickets__c,
                   conference360__Show_Sold_Out_Tickets__c,
                   conference360__Decimal_Separator__c,
                   conference360__Allow_Form_Responses_for_Attendee_Group__c,
                   conference360__Display_Donations_Products_Separately__c,
                   conference360__Remove_Info_Page_for_Free_Events__c,
                   conference360__Enable_Add_to_Wallet_from_AttendeeLink__c,
                   conference360__Show_Agenda__c,
                   conference360__Show_Attendees__c,
                   conference360__Show_Map__c,
                   conference360__Show_Profile__c,
                   conference360__Show_Ticket__c
            FROM   conference360__Event_Settings__c
            WHERE  Id IN :btSettingsIds
        ]);
    }

    // ── execute() ─────────────────────────────────────────────────────────────
    /**
     * @description Upserts a batch of Event Settings into HAM_Event_Settings__c
     *              and accumulates the btSettingsId-to-hamId map for finish().
     * @param bc       BatchableContext provided by the platform.
     * @param settings Chunk of conference360__Event_Settings__c records to process.
     */
    public void execute(
        Database.BatchableContext bc,
        List<conference360__Event_Settings__c> settings
    ) {
        List<HAM_Event_Settings__c> toUpsert = new List<HAM_Event_Settings__c>();

        for (conference360__Event_Settings__c s : settings) {
            toUpsert.add(new HAM_Event_Settings__c(
                Name                                = HAM_MigrationUtil.truncate(s.Name, 80),
                HAM_BT_Event_Settings_Id__c         = s.Id,
                HAM_BT_Event_Settings__c            = s.Id,
                HAM_Is_Default__c                   = s.conference360__Default__c,
                HAM_Primary_Color__c                = HAM_MigrationUtil.truncate(s.conference360__Color_Theme__c, 6),
                HAM_Background_Color__c             = HAM_MigrationUtil.truncate(s.conference360__Background_Color__c, 6),
                HAM_Font__c                         = HAM_MigrationUtil.truncate(s.conference360__Font__c, 255),
                HAM_Card_Color_Theme__c             = s.conference360__Card_Color_Theme__c,
                HAM_Attendees_Visibility__c         = s.conference360__Attendees__c,
                HAM_Sessions_Visibility__c          = s.conference360__Sessions__c,
                HAM_Speakers_Visibility__c          = s.conference360__Speakers__c,
                HAM_Sponsors_Visibility__c          = s.conference360__Sponsors__c,
                HAM_Venue_Visibility__c             = s.conference360__Venue__c,
                HAM_FAQ_Visibility__c               = s.conference360__FAQ__c,
                HAM_Contact_Us_Visibility__c        = s.conference360__Contact_Us__c,
                HAM_Content_Visibility__c           = s.conference360__Content__c,
                HAM_Custom_Tabs_Visibility__c       = s.conference360__Custom_Tabs__c,
                HAM_WiFi_Visibility__c              = s.conference360__WiFi__c,
                HAM_Tracks_Visibility__c            = s.conference360__Tracks__c,
                HAM_Enable_Cancel_Registration__c   = s.conference360__Enable_Cancel_Registration__c,
                HAM_Greeting_Formality__c           = s.conference360__Greeting_Name_Formality__c,
                HAM_One_Unique_Email_Per_Event__c   = s.conference360__One_Unique_Attendee_Email_Per_Event__c,
                HAM_Hide_Main_Contact_Address__c    = s.conference360__Hide_Main_Contact_Address__c,
                HAM_Hide_Main_Contact_Company__c    = s.conference360__Hide_Main_Contact_Company_Name__c,
                HAM_Hide_Price_Range__c             = s.conference360__Hide_Price_Range__c,
                HAM_Hide_QR_From_AttendeeLink__c    = s.conference360__Hide_QR_from_AttendeeLink__c,
                HAM_Overview_Pricing__c             = s.conference360__Overview_Pricing__c,
                HAM_Search_Bar__c                   = s.conference360__Search_Bar__c,
                HAM_Auto_Update_No_Show__c          = s.conference360__Auto_update_Attendance_to_No_Show__c,
                HAM_Waitlist_Automate__c            = s.conference360__Waitlist_Automate__c,
                HAM_Waitlist_Message__c             = s.conference360__Waitlist_Message__c,
                HAM_Enabled_Payment_Methods__c      = HAM_MigrationUtil.truncate(s.conference360__Enabled_Payment_Methods__c, 255),
                HAM_Create_Opps_For_Donations__c    = s.conference360__Create_Opportunities_For_Donations__c,
                HAM_Create_Opp_From_Checkout__c     = s.conference360__Create_Opportunity_From_Checkout__c,
                HAM_Create_Zero_Dollar_Opps__c      = s.conference360__Create_Zero_Dollar_Opportunities__c,
                HAM_Opp_Open_Stage__c               = HAM_MigrationUtil.truncate(s.conference360__Opportunity_Open_Stage_Name__c, 255),
                HAM_Opp_Success_Stage__c            = HAM_MigrationUtil.truncate(s.conference360__Opportunity_Successful_Stage_Name__c, 255),
                HAM_Require_Ticket_To_Publish__c    = s.conference360__Require_At_Least_One_Ticket_To_Publish__c,
                HAM_Show_Expired_Tickets__c         = s.conference360__Show_Expired_Tickets__c,
                HAM_Show_Sold_Out_Tickets__c        = s.conference360__Show_Sold_Out_Tickets__c,
                HAM_Decimal_Separator__c            = HAM_MigrationUtil.truncate(s.conference360__Decimal_Separator__c, 1),
                HAM_Allow_Form_Responses_Group__c   = s.conference360__Allow_Form_Responses_for_Attendee_Group__c,
                HAM_Display_Donations_Separately__c = s.conference360__Display_Donations_Products_Separately__c,
                HAM_Remove_Info_Page_Free__c        = s.conference360__Remove_Info_Page_for_Free_Events__c,
                HAM_Enable_Wallet_AttendeeLink__c   = s.conference360__Enable_Add_to_Wallet_from_AttendeeLink__c,
                HAM_Show_Agenda__c                  = s.conference360__Show_Agenda__c,
                HAM_Show_Attendees_Nav__c           = s.conference360__Show_Attendees__c,
                HAM_Show_Map__c                     = s.conference360__Show_Map__c,
                HAM_Show_Profile__c                 = s.conference360__Show_Profile__c,
                HAM_Show_Ticket__c                  = s.conference360__Show_Ticket__c
            ));
        }

        List<Database.UpsertResult> results =
            Database.upsert(toUpsert, HAM_Event_Settings__c.HAM_BT_Event_Settings_Id__c, false);

        for (Integer i = 0; i < results.size(); i++) {
            if (results[i].isSuccess()) {
                successCount++;
                btSettingsToHamId.put(
                    (Id) toUpsert[i].HAM_BT_Event_Settings_Id__c,
                    results[i].getId()
                );
            } else {
                failCount++;
            }
        }
        HAM_MigrationUtil.logErrors(results, toUpsert, 'HAM_Event_Settings__c');
    }

    // ── finish() ──────────────────────────────────────────────────────────────
    /**
     * @description Second pass: stamps HAM_Event_Settings__c lookup on every
     *              CventEvents__Event__c whose source BT event had a settings profile.
     *              Logs pipeline completion. Final step in the migration pipeline.
     * @param bc BatchableContext provided by the platform.
     */
    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.DEBUG, 'HAM_EventSettingsMigrationBatch complete — '
            + successCount + ' succeeded, ' + failCount + ' failed.');
        HAM_MigrationUtil.logSummary('HAM_Event_Settings__c', successCount + failCount, successCount);

        List<CventEvents__Event__c> eventsToUpdate = new List<CventEvents__Event__c>();
        for (Id btEventId : btEventToSettingsId.keySet()) {
            Id btSettingsId  = btEventToSettingsId.get(btEventId);
            Id hamSettingsId = btSettingsToHamId.get(btSettingsId);
            Id cventEventId  = btToCventEventMap.get(btEventId);

            if (hamSettingsId != null && cventEventId != null) {
                eventsToUpdate.add(new CventEvents__Event__c(
                    Id                    = cventEventId,
                    HAM_Event_Settings__c = hamSettingsId
                ));
            }
        }

        if (!eventsToUpdate.isEmpty()) {
            List<Database.SaveResult> updateResults =
                Database.update(eventsToUpdate, false);
            for (Integer i = 0; i < updateResults.size(); i++) {
                if (!updateResults[i].isSuccess()) {
                    System.debug(LoggingLevel.ERROR,
                        'HAM_EventSettingsMigrationBatch finish() — failed to stamp HAM_Event_Settings__c on '
                        + eventsToUpdate[i].Id + ': '
                        + updateResults[i].getErrors()[0].getMessage());
                }
            }
        }

        System.debug(LoggingLevel.DEBUG, '═══════════════════════════════════════════════');
        System.debug(LoggingLevel.DEBUG, 'HAM Migration Phase 1 Pipeline COMPLETE. Chaining to Phase 2.');
        System.debug(LoggingLevel.DEBUG, '═══════════════════════════════════════════════');
        // Phase 2 pipeline — chains through all 15 Phase 2 batches, ending at HAM_SurveyAnswerBatch
        // Guard prevents the chain from firing in test context (avoids async job limit errors
        // in Phase 1 tests that chain through to this batch)
        if (!Test.isRunningTest()) {
            Database.executeBatch(new HAM_ProductMigrationBatch(), 200);
        }
    }
}