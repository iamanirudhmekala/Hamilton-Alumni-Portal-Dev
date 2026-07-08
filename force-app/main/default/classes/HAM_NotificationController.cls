/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : HAM_NotificationController
 * Author          : <Sachin Sharma>
 * Created Date    : Jan 5, 2026
 * Last Modified By: <Sachin Sharma>
 * Last Modified On: Jan 5, 2026
 * Description     : This class is implemented to handle data fetching and updates for the UI.
 *  
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Jan 5, 2026  │ <Sachin Sharma>   │ Initial version
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */
@SuppressWarnings('PMD.NoTrailingWhitespace, PMD.ExcessiveClassLength, PME.ExcessivePublicCount, PMD.ApexCRUDViolation, PMD.EmptyIfStmt, PMD.EmptyStatementBlock, PMD.AvoidNonRestrictiveQueries, PMD.CyclomaticComplexity, PMD.CognitiveComplexity, PMD.NcssCount, PMD.NcssTypeCount, PMD.DetectCopyPasteForApex, PMD.LocalVariableNamingConventions, PMD.ExcessiveParameterList, PMD.ApexSOQLInjection, PMD.AvoidDeeplyNestedIfStmts, PMD.AvoidDebugStatements, PMD.StdCyclomaticComplexity, PMD.NcssMethodCount')
public without sharing class HAM_NotificationController {

    /**
     * @description Fetches the Contact ID associated with the currently logged-in User.
     * Delegates to the main controller to reuse central logic.
     * Used to make the LWC component context-aware.
     * @return String The Salesforce ID of the Contact record for the current user.
     */
    @AuraEnabled(cacheable=true)
    public static String getCurrentUserContactId() {
        Contact con = HAM_MainController.fetchLoggedInUserInfo();
        return (con != null) ? (String)con.Id : null;
    }

    /**
     * @description Returns the total number of unread, non-dismissed notifications 
     * for a specific constituent. Used to drive the badge count on the bell icon.
     * @param contactId The ID of the constituent (Contact) to query for.
     * @return Integer The count of unread notifications. Returns 0 if contactId is null.
     */
	@AuraEnabled(cacheable=true)
    public static Integer getUnreadCount(Id contactId) {

        // Handle null contactId gracefully
        if (contactId == null) return 0;

        return [SELECT Count() 
                FROM HAM_Notification__c 
                WHERE HAM_Constituent__c = :contactId 
                AND HAM_Is_Dismissed__c = FALSE 
                AND HAM_Status__c =: HAM_ConstantsUtil.UNREAD];
    }

    /**
     * @description Retrieves the most recent list of notifications for the UI dropdown.
     * Fetches details including the sender's name and profile picture.
     * Limited to the latest 20 records for performance.
     * @param contactId The ID of the constituent (Contact) whose notifications to fetch.
     * @return List<HAM_Notification__c> A list of notification records ordered by creation date (newest first).
     */
    @AuraEnabled(cacheable=true)
    public static List<HAM_Notification__c> getNotifications(Id contactId) {

        if (contactId == null) return new List<HAM_Notification__c>();

        return [SELECT Id, HAM_Title__c, HAM_Body__c, HAM_Status__c, HAM_Source_Type__c,HAM_Source_Object_ID__c, HAM_Action_URL__c, CreatedDate, HAM_Sender_Contact__r.Name, HAM_Sender_Contact__r.HAM_Profile_Picture_URL__c
                FROM HAM_Notification__c 
                WHERE HAM_Constituent__c = :contactId 
                AND HAM_Is_Dismissed__c = FALSE 
                ORDER BY CreatedDate DESC 
                LIMIT 20];
    }

    /**
     * @description Marks all active notifications for the user as 'Read' and 'Dismissed'.
     * This performs a "soft delete" from the UI perspective (HAM_Is_Dismissed__c = TRUE),
     * while keeping the record in the database for history/audit.
     * @param contactId The ID of the constituent performing the action.
     */
    @AuraEnabled
    public static void markAllAsRead(Id contactId) {
        List<HAM_Notification__c> listToUpdate = [SELECT Id FROM HAM_Notification__c 
                                              WHERE HAM_Constituent__c = :contactId 
                                              AND HAM_Is_Dismissed__c = FALSE];
        for(HAM_Notification__c n : listToUpdate) {
            n.HAM_Is_Dismissed__c = TRUE; // Hide from UI, keep in DB
            n.HAM_Status__c = HAM_ConstantsUtil.READ;
        }
        update listToUpdate;
    }

    /**
     * @description Processes a response to a Connection Request (Accept/Reject).
     * 1. Updates the HAM_Connection__c record status.
     * 2. Dismisses the 'Request Received' notification for the current user.
     * 3. If approved, sends a new 'Request Accepted' notification back to the requester.
     * @param connectionId The ID of the HAM_Connection__c record being acted upon.
     * @param action The action taken ('Connected' or 'Rejected').
     */
    @AuraEnabled
    public static void approveRejectConnection(Id connectionId, String action) {
        Contact fetchedContact = HAM_MainController.fetchLoggedInUserInfo();
        Id currentContactId = fetchedContact.Id;

        // Update connection
        HAM_Connection__c con = [
            SELECT Id, HAM_Portal_User__c, HAM_Linked_Constituent__c,HAM_Connection_Status__c
            FROM HAM_Connection__c
            WHERE Id = :connectionId
            LIMIT 1
        ];
        
        String result;
        if(action == 'Connected'){
            result = HAM_AlumniConnectionService.handleAccept(con.HAM_Linked_Constituent__c, con.HAM_Portal_User__c);
        }else{
            result = HAM_AlumniConnectionService.handleReject(con.HAM_Linked_Constituent__c, con.HAM_Portal_User__c);
        }
    }

    /**
     * @description Retrieves the polling frequency configuration from Custom Metadata.
     * Allows admins to control how often the UI checks for new notifications
     * without deploying code changes.
     * @return Integer The interval in seconds (Defaults to 15 if config is missing).
     */
    @AuraEnabled(cacheable=true)
    public static Integer getPollingInterval() {
        HAM_Notification_Setting__mdt setting = [
            SELECT Polling_Interval_Seconds__c 
            FROM HAM_Notification_Setting__mdt 
            WHERE DeveloperName =: HAM_ConstantsUtil.DEFAULTNOTIFICATIONSETTINGS LIMIT 1
        ];
        return setting.Polling_Interval_Seconds__c != null 
               ? Integer.valueOf(setting.Polling_Interval_Seconds__c) 
               : 15;
    }

}