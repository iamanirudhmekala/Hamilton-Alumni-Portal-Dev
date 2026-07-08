/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : HAM_GroupNotificationHandler
 * Author          : Sachin 
 * Created Date    : May 6, 2026
 * Last Modified By: Sachin
 * Last Modified On: May 6, 2026
 * Description     : This class implements for......
 *  
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  May 6, 2026  │ Sachin   │ Initial version
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */

public class HAM_GroupNotificationHandler {

	public static void processNotifications(List<HAM_Group_Notification__e> events) {
        Set<Id> groupIds = new Set<Id>();
        for (HAM_Group_Notification__e evt : events) {
            if (String.isNotBlank(evt.Group_Id__c)) groupIds.add((Id)evt.Group_Id__c);
        }
        if (groupIds.isEmpty()) return;

        // Fetch members who have Opted-In to notifications
        List<HAM_Group_Member__c> optedInMembers = [
            SELECT Contact__c, Contact__r.Name, Group__c, Group__r.Name 
            FROM HAM_Group_Member__c 
            WHERE Group__c IN :groupIds 
            AND Status__c = 'Active' 
            AND Receive_Notifications__c = true
        ];

        // Map Contacts to Users (Required for CustomNotification.send)
        Set<Id> contactIds = new Set<Id>();
        for(HAM_Group_Member__c m : optedInMembers) contactIds.add(m.Contact__c);
        
        Map<Id, Id> contactToUserIdMap = new Map<Id, Id>();
        for(User u : [SELECT Id, ContactId FROM User WHERE ContactId IN :contactIds AND IsActive = true]) {
            contactToUserIdMap.put(u.ContactId, u.Id);
        }

        // Build the Requests for your existing Service
        List<HAM_NotificationService.NotificationRequest> pushRequests = new List<HAM_NotificationService.NotificationRequest>();
        
        for (HAM_Group_Member__c member : optedInMembers) {
            Id userId = contactToUserIdMap.get(member.Contact__c);
            if (userId == null) continue; // Skip if user is inactive or missing

            HAM_NotificationService.NotificationRequest req = new HAM_NotificationService.NotificationRequest();
            req.recipientContactId = member.Contact__c;
            req.recipientUserId = userId;
            req.title = 'New Activity in ' + member.Group__r.Name;
            req.body = 'There is a new post in your group. Tap to view.';
            req.type = 'Groups';
            req.sourceId = member.Group__c; 
            req.actionUrl = '?view=community&tab=Groups&groupId=' + member.Group__c; // Triggers SPA router
            
            pushRequests.add(req);
        }

        // Hand off to your standard service
        if (!pushRequests.isEmpty()) {
            HAM_NotificationService.sendNotifications(pushRequests);
        }
    }

}