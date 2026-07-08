/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : HAM_ConnectionTriggerHandler
 * Author          : Sachin
 * Created Date    : Jan 15, 2026
 * Last Modified By: Sachin
 * Last Modified On: Jan 15, 2026
 * Description     : This is a trigger handler class for Ham_Connection__c object.
 *  
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Jan 15, 2026  │ Sachin   │ Initial version
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */

public without sharing class HAM_ConnectionTriggerHandler {

    /**
     * @description Handles After Insert logic (Sending Notifications)
     */
    public static void onAfterInsert(List<HAM_Connection__c> newRecords) {
        List<HAM_Connection__c> recordsToNotify = new List<HAM_Connection__c>();

        for(HAM_Connection__c con : newRecords) {
            // Scenario: New Connection created with 'Request Sent'
            if(con.HAM_Connection_Status__c == HAM_ConstantsUtil.REQUEST_SENT) {
                recordsToNotify.add(con);
            }
        }
        
        if(!recordsToNotify.isEmpty()) {
            processNotificationCreation(recordsToNotify);
        }
    }

    /**
     * @description Handles After Update logic
     * Logic:
     * 1. If Status changed TO 'Request Sent' -> Create Notification
     * 2. If Status changed TO null -> Delete Notification
     */
    public static void onAfterUpdate(List<HAM_Connection__c> newRecords, Map<Id, HAM_Connection__c> oldMap) {
        List<HAM_Connection__c> recordsToNotify = new List<HAM_Connection__c>();
        Set<Id> connectionIdsToDelete = new Set<Id>();

        for(HAM_Connection__c con : newRecords) {
            HAM_Connection__c oldCon = oldMap.get(con.Id);

            // Check if Status Changed
            if(con.HAM_Connection_Status__c != oldCon.HAM_Connection_Status__c) {
                
                // Case 1: Status changed TO 'Request Sent' (Create Notification)
                if(con.HAM_Connection_Status__c == HAM_ConstantsUtil.REQUEST_SENT) {
                    recordsToNotify.add(con);
                }
                
                // Case 2: Status changed TO NULL (Delete Notification)
                // Note: Explicitly check for null
                else if(con.HAM_Connection_Status__c == null) {
                    connectionIdsToDelete.add(con.Id);
                }
            }
        }

        // Execute Actions
        if(!recordsToNotify.isEmpty()) {
            processNotificationCreation(recordsToNotify);
        }

        if(!connectionIdsToDelete.isEmpty()) {
            processNotificationDeletion(connectionIdsToDelete);
        }
    }

    /**
     * @description Handles After Delete logic
     */
    public static void onAfterDelete(List<HAM_Connection__c> oldRecords) {
        Set<Id> connectionIds = new Set<Id>();
        for(HAM_Connection__c con : oldRecords) {
            connectionIds.add(con.Id);
        }

        if(!connectionIds.isEmpty()) {
            processNotificationDeletion(connectionIds);
        }
    }


    // --------------------------------------------------------------------------------
    // PRIVATE HELPER METHODS (REUSABLE LOGIC)
    // --------------------------------------------------------------------------------

    /**
     * @description Helper to create notification requests for a list of connections
     */
    private static void processNotificationCreation(List<HAM_Connection__c> connections) {
        List<HAM_NotificationService.NotificationRequest> notifRequests = new List<HAM_NotificationService.NotificationRequest>();
        
        // Collect Contact IDs to fetch related Users (for Mobile Push)
        Set<Id> contactIds = new Set<Id>();
        for(HAM_Connection__c c : connections) {
            if (c.HAM_Linked_Constituent__c != null) contactIds.add(c.HAM_Linked_Constituent__c);
            if (c.HAM_Portal_User__c != null) contactIds.add(c.HAM_Portal_User__c);
        }

        // Map ContactId to User
        Map<Id, Id> contactToUserMap = new Map<Id, Id>();
        if(!contactIds.isEmpty()) {
            for(User u : [SELECT Id, ContactId FROM User WHERE ContactId IN :contactIds]) {
                contactToUserMap.put(u.ContactId, u.Id);
            }
        }

        // Map ContactId to Name (for Mobile Push sender name)
        Map<Id, String> contactNameMap = new Map<Id, String>();
        if(!contactIds.isEmpty()) {
            for(Contact conObj : [SELECT Id, Name FROM Contact WHERE Id IN :contactIds]) {
                contactNameMap.put(conObj.Id, conObj.Name);
            }
        }

        // Build Requests
        for(HAM_Connection__c con : connections) {
            if (con.HAM_Linked_Constituent__c == null || con.HAM_Portal_User__c == null) continue;

            HAM_NotificationService.NotificationRequest req = new HAM_NotificationService.NotificationRequest();
            req.recipientContactId = con.HAM_Linked_Constituent__c;
            req.recipientUserId    = contactToUserMap.get(con.HAM_Linked_Constituent__c);
            req.senderContactId    = con.HAM_Portal_User__c;
            req.senderName         = contactNameMap.get(con.HAM_Portal_User__c);
            req.title              = HAM_ConstantsUtil.HAS_SENT_YOU_A_CONNECTION_REQUEST;
            req.body               = con.HAM_Connection_Message__c;
            req.sourceId           = con.Id;
            req.type               = HAM_ConstantsUtil.CONNECTION_T;
            req.actionUrl          = '?view=directory&tab=Manage%20Invitations';
            
            notifRequests.add(req);
        }

        // Send to Service
        if(!notifRequests.isEmpty()) {
            HAM_NotificationService.sendNotifications(notifRequests);
        }
    }

    /**
     * @description Helper to delete notifications related to a list of connection IDs
     */
    private static void processNotificationDeletion(Set<Id> connectionIds) {
        // Query related notifications using the Source Object ID
        List<HAM_Notification__c> notificationsToDelete = [
            SELECT Id 
            FROM HAM_Notification__c 
            WHERE HAM_Source_Object_ID__c IN :connectionIds
        ];

        if(!notificationsToDelete.isEmpty()) {
            delete notificationsToDelete;
        }
    }
}