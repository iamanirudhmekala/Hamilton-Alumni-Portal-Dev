/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : HAM_NotificationService
 * Author          : <Sachin Sharma>
 * Created Date    : Jan 5, 2026
 * Last Modified By: <Sachin Sharma>
 * Last Modified On: Jan 5, 2026
 * Description     : This service class is implemented to handle Notification creation, Push, and Event publishing.
 * 					 Designed to be called by ANY object trigger (Connection, News, etc.)
 *  
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Jan 5, 2026  │ <Sachin Sharma>   │ Initial version
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */

public without sharing class HAM_NotificationService {

    /**
     * @description Public entry point to process a list of notification requests. 
     * This method handles:
     * 1. Creating a persistent 'HAM_Notification__c' record in the database for the history feed.
     * 2. Triggering a Salesforce Mobile/Desktop Push Notification (standard bell icon).
     * @param requests List of 'NotificationRequest' wrapper objects containing all necessary data payload.
     */
	public static void sendNotifications(List<NotificationRequest> requests) {
        List<HAM_Notification__c> notifsToInsert = new List<HAM_Notification__c>();
        
        // Prepare Data
        CustomNotificationType typeConfig = [SELECT Id FROM CustomNotificationType WHERE DeveloperName = 'HAM_Portal_General_Notification' LIMIT 1];
        
        for(NotificationRequest req : requests) {
            // Create DB Record
            HAM_Notification__c n = new HAM_Notification__c();
            n.HAM_Constituent__c = req.recipientContactId;
            n.HAM_Sender_Contact__c = req.senderContactId;
            n.HAM_Title__c = req.title;
            n.HAM_Body__c = stripHtml(req.body);
            n.HAM_Source_Object_ID__c = req.sourceId;
            n.HAM_Source_Type__c = req.type;
            n.HAM_Status__c = HAM_ConstantsUtil.UNREAD_S;
            n.HAM_Expiration_Date__c = System.today().addDays(30);
            n.HAM_Action_URL__c = req.actionUrl;
            notifsToInsert.add(n);
            
            // Send Mobile Push (Immediate)
            sendMobilePush(typeConfig.Id, req);
        }
        
        // Commit to DB
        if(!notifsToInsert.isEmpty()) {
            insert notifsToInsert;
        }
    }

    /**
     * @description Sends a standard Salesforce Push/In-App Notification to the user.
     * Uses the 'Messaging.CustomNotification' class.
     * @param typeId The ID of the 'CustomNotificationType' metadata record.
     * @param req The request wrapper containing the notification payload (title, body, target).
     */
    private static void sendMobilePush(Id typeId, NotificationRequest req) {
        try {
            Messaging.CustomNotification currNotification = new Messaging.CustomNotification();
            
            String pushTitle = req.title;
            if (String.isNotBlank(req.senderName)) {
                pushTitle = req.senderName + ' ' + req.title;
            }
            currNotification.setTitle(pushTitle);
            String pushBody = req.body;
            if (String.isBlank(pushBody)) {
                if (req.type == HAM_ConstantsUtil.CONNECTION_T) {
                    pushBody = Label.HAM_Connection_Request_Default_Mobile_Body;
                } else {
                    pushBody = pushTitle;
                }
            }
            currNotification.setBody(pushBody);
            currNotification.setNotificationTypeId(typeId);

            // Standard targetId opens a native record page, breaking Experience Cloud.
            // If the notification actionUrl is provided, we inject a JSON PageRef to route inside LWC Wrapper.
            if (String.isNotBlank(req.actionUrl)) {
                String pageRefJson = '{"type": "standard__webPage", "attributes": {"url": "/' + req.actionUrl + '"}}';
                currNotification.setTargetPageRef(pageRefJson);
            } else {
                currNotification.setTargetId(req.sourceId); 
            }
            
            currNotification.send(new Set<String>{req.recipientUserId});
        } catch (Exception e) {
            System.debug('Push Notification Failed: ' + e.getMessage());
        }
    }

    /**
     * @description Wrapper class to standardize notification requests from different source objects.
     * Decouples the logic so Triggers don't need to know the 'HAM_Notification__c' schema.
     */
    public class NotificationRequest {
        public Id recipientContactId;
        public String recipientUserId; // Needed for Mobile Push
        public Id senderContactId;
        public String senderName; // Prepend for mobile push title
        public String title;
        public String body;
        public String status;
        public String sourceId;
        public String type; // 'Connection', 'News'
        public String actionUrl;
    }

    /**
     * @description Utility method to strip HTML tags from Rich Text fields.
     * Ensures notification body text is clean and readable in plain-text environments (Push notifications).
     * @param richText The raw string potentially containing HTML tags (e.g., <p>, <br>).
     * @return String The cleaned plain text with HTML entities decoded.
     */
    public static String stripHtml(String richText) {
        if (String.isBlank(richText)) {
            return '';
        }

        // Remove all HTML tags
        String plainText = richText.replaceAll('<[^>]*>', '');

        // Decode common HTML entities
        plainText = plainText.replace('&nbsp;', ' ');
        plainText = plainText.replace('&amp;', '&');
        plainText = plainText.replace('&lt;', '<');
        plainText = plainText.replace('&gt;', '>');
        plainText = plainText.replace('&quot;', '"');
        plainText = plainText.replace('&#39;', '\'');

        return plainText.trim();
    }


}