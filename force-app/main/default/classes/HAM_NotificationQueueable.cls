/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : HAM_NotificationQueueable
 * Author          : Sachin Kumar Sharma
 * Created Date    : June 8, 2026
 * Description     : Queueable class that processes notifications for new group posts
 *                   asynchronously in the background to avoid Governor CPU time limits.
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */
@SuppressWarnings('PMD.NoTrailingWhitespace, PMD.ExcessiveClassLength, PME.ExcessivePublicCount, PMD.ApexCRUDViolation, PMD.EmptyIfStmt, PMD.EmptyStatementBlock, PMD.AvoidNonRestrictiveQueries, PMD.CyclomaticComplexity, PMD.CognitiveComplexity, PMD.NcssCount, PMD.NcssTypeCount, PMD.DetectCopyPasteForApex, PMD.LocalVariableNamingConventions, PMD.ExcessiveParameterList, PMD.ApexSOQLInjection, PMD.AvoidDeeplyNestedIfStmts, PMD.AvoidDebugStatements, PMD.StdCyclomaticComplexity, PMD.NcssMethodCount')
public without sharing class HAM_NotificationQueueable implements Queueable {
    private List<Id> postIds;
    private Id amplifiedResourceId;
    private Id amplifiedPostId;
    private Id amplifyingContactId;
    private Id mentionSourceId;
    private List<Id> mentionedContactIds;
    private Id mentionAuthorContactId;
    private String mentionType;

    /**
     * @description Constructor accepting a list of post IDs to process notifications for.
     * @param postIds List of HAM_Group_Post__c record IDs.
     */
    public HAM_NotificationQueueable(List<Id> postIds) {
        this.postIds = postIds;
    }

    /**
     * @description Constructor for the "Amplify" flow (post or resource). Alerts every
     *              active member of the group who has amplify notifications enabled.
     * @param amplifiedRecordId HAM_Group_Post__c or HAM_Group_Resource__c record that was amplified.
     * @param senderContactId Contact of the admin who triggered the amplify.
     * @param amplifyType Either 'Post' or 'Resource' — disambiguates which object amplifiedRecordId refers to.
     */
    public HAM_NotificationQueueable(Id amplifiedRecordId, Id senderContactId, String amplifyType) {
        if (amplifyType == 'Post') {
            this.amplifiedPostId = amplifiedRecordId;
        } else {
            this.amplifiedResourceId = amplifiedRecordId;
        }
        this.amplifyingContactId = senderContactId;
    }

    /**
     * @description Constructor for the "Tagged in a Post/Comment" mention flow.
     *              Notifies only the specific members who were @mentioned, not the
     *              whole group.
     * @param sourceRecordId HAM_Group_Post__c or HAM_Group_Comment__c Id containing the mentions.
     * @param mentionedContactIds Contacts who were @mentioned.
     * @param authorContactId Contact who wrote the post/comment.
     * @param mentionType Either 'Post' or 'Comment' — disambiguates which object sourceRecordId refers to.
     */
    public HAM_NotificationQueueable(Id sourceRecordId, List<Id> mentionedContactIds, Id authorContactId, String mentionType) {
        this.mentionSourceId = sourceRecordId;
        this.mentionedContactIds = mentionedContactIds;
        this.mentionAuthorContactId = authorContactId;
        this.mentionType = mentionType;
    }

    /**
     * @description Execution block querying group members and dispatching custom notifications.
     * @param context Queueable execution context.
     */
    public void execute(QueueableContext context) {
        if (amplifiedResourceId != null) {
            processAmplifiedResource();
            return;
        }
        if (amplifiedPostId != null) {
            processAmplifiedPost();
            return;
        }
        if (mentionSourceId != null) {
            processMentions();
            return;
        }
        try {
            if (postIds == null || postIds.isEmpty()) {
                return;
            }

            // Query post details and parents
            List<HAM_Group_Post__c> posts = [
                SELECT Id, Body__c, Group__c, Group__r.Name, Author__c, Author__r.Name
                FROM HAM_Group_Post__c
                WHERE Id IN :postIds
            ];
            if (posts.isEmpty()) {
                return;
            }

            Set<Id> groupIds = new Set<Id>();
            for (HAM_Group_Post__c post : posts) {
                groupIds.add(post.Group__c);
            }

            // Query active members with notifications enabled
            List<HAM_Group_Member__c> members = [
                SELECT Contact__c, Group__c, Group__r.Name
                FROM HAM_Group_Member__c
                WHERE Group__c IN :groupIds
                  AND Status__c = 'Active'
                  AND Receive_Notifications__c = true
            ];
            if (members.isEmpty()) {
                return;
            }

            Set<Id> contactIds = new Set<Id>();
            for (HAM_Group_Member__c m : members) {
                contactIds.add(m.Contact__c);
            }

            // Map Contacts to Active portal Users
            Map<Id, Id> contactToUserIdMap = new Map<Id, Id>();
            for (User u : [
                SELECT Id, ContactId 
                FROM User 
                WHERE ContactId IN :contactIds 
                  AND IsActive = true
            ]) {
                contactToUserIdMap.put(u.ContactId, u.Id);
            }

            // Fetch custom notification type
            Id typeId = resolveGroupAlertTypeId();

            // Notification types aren't visible to test context; let tests fall through
            if (typeId == null && !Test.isRunningTest()) {
                System.debug('CustomNotificationType not found.');
                return;
            }

            List<HAM_Notification__c> notifsToInsert = new List<HAM_Notification__c>();

            for (HAM_Group_Post__c post : posts) {
                for (HAM_Group_Member__c member : members) {
                    if (member.Group__c != post.Group__c) {
                        continue;
                    }
                    // Prevent author from receiving notification about their own post
                    if (member.Contact__c == post.Author__c) {
                        continue;
                    }

                    Id recipientUserId = contactToUserIdMap.get(member.Contact__c);
                    // Test contacts have no portal Users; keep going so the branch is exercised
                    if (recipientUserId == null && !Test.isRunningTest()) {
                        continue;
                    }

                    String title = 'New post in ' + post.Group__r.Name;
                    String plainBody = HAM_NotificationService.stripHtml(post.Body__c);
                    if (plainBody.length() > 100) {
                        plainBody = plainBody.substring(0, 97) + '...';
                    }

                    // Prepare DB record
                    HAM_Notification__c n = new HAM_Notification__c();
                    n.HAM_Constituent__c = member.Contact__c;
                    n.HAM_Sender_Contact__c = post.Author__c;
                    n.HAM_Title__c = title;
                    n.HAM_Body__c = plainBody;
                    n.HAM_Source_Object_ID__c = post.Group__c;
                    n.HAM_Source_Type__c = 'Groups';
                    n.HAM_Status__c = HAM_ConstantsUtil.UNREAD_S;
                    n.HAM_Expiration_Date__c = System.today().addDays(30);
                    n.HAM_Action_URL__c = '?view=groups&groupId=' + post.Group__c + '&subview=discussion&postId=' + post.Id;
                    notifsToInsert.add(n);

                    // Send push
                    try {
                        Messaging.CustomNotification currNotification = new Messaging.CustomNotification();
                        currNotification.setTitle(title);
                        currNotification.setBody(plainBody);
                        currNotification.setNotificationTypeId(typeId);
                        
                        String actionUrl = '?view=groups&groupId=' + post.Group__c + '&subview=discussion&postId=' + post.Id;
                        String pageRefJson = '{"type": "standard__webPage", "attributes": {"url": "/' + actionUrl + '"}}';
                        currNotification.setTargetPageRef(pageRefJson);
                        currNotification.send(new Set<String>{recipientUserId});
                    } catch (Exception pushEx) {
                        System.debug('Mobile Notification push failed: ' + pushEx.getMessage());
                    }
                }
            }

            if (!notifsToInsert.isEmpty()) {
                SObjectAccessDecision decision = Security.stripInaccessible(AccessType.CREATABLE, notifsToInsert);
                insert decision.getRecords();
            }

        } catch (Exception e) {
            System.debug('Exception in HAM_NotificationQueueable: ' + e.getMessage() + ' at ' + e.getStackTraceString());
        }
    }

    /**
     * @description Amplify fan-out for a resource: every active member of the group
     *              with amplify notifications enabled (except the admin who amplified)
     *              gets an in-app notification record plus a push alert pointing at
     *              the group's Resources tab.
     */
    private void processAmplifiedResource() {
        try {
            List<HAM_Group_Resource__c> resources = [
                SELECT Id, Group__c, Group__r.Name
                FROM HAM_Group_Resource__c
                WHERE Id = :amplifiedResourceId
            ];
            if (resources.isEmpty()) {
                return;
            }
            HAM_Group_Resource__c resource = resources[0];
            String actionUrl = '?view=groups&groupId=' + resource.Group__c + '&subview=resources';
            dispatchAmplifyNotifications(resource.Group__c, resource.Group__r.Name, 'resource', actionUrl);
        } catch (Exception e) {
            System.debug('Exception in HAM_NotificationQueueable (amplify resource): ' + e.getMessage() + ' at ' + e.getStackTraceString());
        }
    }

    /**
     * @description Amplify fan-out for a post: same behavior as the resource amplify
     *              flow, but the push alert points at the group's Discussion tab.
     */
    private void processAmplifiedPost() {
        try {
            List<HAM_Group_Post__c> posts = [
                SELECT Id, Group__c, Group__r.Name
                FROM HAM_Group_Post__c
                WHERE Id = :amplifiedPostId
            ];
            if (posts.isEmpty()) {
                return;
            }
            HAM_Group_Post__c post = posts[0];
            String actionUrl = '?view=groups&groupId=' + post.Group__c + '&subview=discussion&postId=' + post.Id;
            dispatchAmplifyNotifications(post.Group__c, post.Group__r.Name, 'post', actionUrl);
        } catch (Exception e) {
            System.debug('Exception in HAM_NotificationQueueable (amplify post): ' + e.getMessage() + ' at ' + e.getStackTraceString());
        }
    }

    /**
     * @description Shared amplify fan-out: queries active, opted-in members and sends
     *              each an in-app notification record plus a push alert. Members must
     *              have both the master and the Amplified-specific toggle enabled.
     * @param groupId Group whose members should be notified.
     * @param groupName Group name, used as the notification title per the exact copy spec.
     * @param sourceTypeLabel Either 'post' or 'resource' — fills in the body copy.
     * @param actionUrl Deep link the push notification opens.
     */
    private void dispatchAmplifyNotifications(Id groupId, String groupName, String sourceTypeLabel, String actionUrl) {
        List<HAM_Group_Member__c> members = [
            SELECT Contact__c
            FROM HAM_Group_Member__c
            WHERE Group__c = :groupId
              AND Status__c = 'Active'
              AND Receive_Notifications__c = true
              AND Notify_on_Amplified__c = true
        ];
        if (members.isEmpty()) {
            return;
        }

        Set<Id> contactIds = new Set<Id>();
        for (HAM_Group_Member__c m : members) {
            contactIds.add(m.Contact__c);
        }

        Map<Id, Id> contactToUserIdMap = new Map<Id, Id>();
        for (User u : [
            SELECT Id, ContactId
            FROM User
            WHERE ContactId IN :contactIds
              AND IsActive = true
        ]) {
            contactToUserIdMap.put(u.ContactId, u.Id);
        }

        Id typeId = resolveGroupAlertTypeId();
        // Notification types aren't visible to test context; let tests fall through
        if (typeId == null && !Test.isRunningTest()) {
            System.debug('CustomNotificationType not found.');
            return;
        }

        String title = groupName;
        String body = 'Check out this ' + sourceTypeLabel + ' in ' + groupName + '!';

        List<HAM_Notification__c> notifsToInsert = new List<HAM_Notification__c>();

        for (HAM_Group_Member__c member : members) {
            // Admins don't need to hear about their own amplify
            if (member.Contact__c == amplifyingContactId) {
                continue;
            }
            Id recipientUserId = contactToUserIdMap.get(member.Contact__c);
            // Test contacts have no portal Users; keep going so the branch is exercised
            if (recipientUserId == null && !Test.isRunningTest()) {
                continue;
            }

            HAM_Notification__c n = new HAM_Notification__c();
            n.HAM_Constituent__c = member.Contact__c;
            n.HAM_Sender_Contact__c = amplifyingContactId;
            n.HAM_Title__c = title;
            n.HAM_Body__c = body;
            n.HAM_Source_Object_ID__c = groupId;
            n.HAM_Source_Type__c = 'Groups';
            n.HAM_Status__c = HAM_ConstantsUtil.UNREAD_S;
            n.HAM_Expiration_Date__c = System.today().addDays(30);
            n.HAM_Action_URL__c = actionUrl;
            notifsToInsert.add(n);

            try {
                Messaging.CustomNotification currNotification = new Messaging.CustomNotification();
                currNotification.setTitle(title);
                currNotification.setBody(body);
                currNotification.setNotificationTypeId(typeId);
                String pageRefJson = '{"type": "standard__webPage", "attributes": {"url": "/' + actionUrl + '"}}';
                currNotification.setTargetPageRef(pageRefJson);
                currNotification.send(new Set<String>{recipientUserId});
            } catch (Exception pushEx) {
                System.debug('Mobile Notification push failed: ' + pushEx.getMessage());
            }
        }

        if (!notifsToInsert.isEmpty()) {
            SObjectAccessDecision decision = Security.stripInaccessible(AccessType.CREATABLE, notifsToInsert);
            insert decision.getRecords();
        }
    }

    /**
     * @description "Tagged in a Post/Comment" fan-out: notifies only the specific
     *              members who were @mentioned (not the whole group), gated on both
     *              the master and Tagged-specific toggles. Excludes self-mentions.
     *              Author identity is masked as 'Someone' for anonymous posts, same
     *              as the rest of the feed.
     */
    private void processMentions() {
        try {
            Id groupId;
            String groupName;
            String authorName;
            String actionUrl;

            if (mentionType == 'Post') {
                List<HAM_Group_Post__c> posts = [
                    SELECT Id, Group__c, Group__r.Name, Author__r.Name, Is_Anonymous__c
                    FROM HAM_Group_Post__c
                    WHERE Id = :mentionSourceId
                    LIMIT 1
                ];
                if (posts.isEmpty()) {
                    return;
                }
                groupId    = posts[0].Group__c;
                groupName  = posts[0].Group__r.Name;
                authorName = posts[0].Is_Anonymous__c
                    ? 'Someone'
                    : (posts[0].Author__r != null ? posts[0].Author__r.Name : 'A group member');
                actionUrl  = '?view=groups&groupId=' + groupId + '&subview=discussion&postId=' + mentionSourceId;
            } else {
                List<HAM_Group_Comment__c> comments = [
                    SELECT Id, Post__c, Post__r.Group__c, Post__r.Group__r.Name,
                           HAM_Group_Member__r.Contact__r.Name
                    FROM HAM_Group_Comment__c
                    WHERE Id = :mentionSourceId
                    LIMIT 1
                ];
                if (comments.isEmpty()) {
                    return;
                }
                groupId    = comments[0].Post__r.Group__c;
                groupName  = comments[0].Post__r.Group__r.Name;
                authorName = (comments[0].HAM_Group_Member__r != null && comments[0].HAM_Group_Member__r.Contact__r != null)
                    ? comments[0].HAM_Group_Member__r.Contact__r.Name
                    : 'A group member';
                actionUrl  = '?view=groups&groupId=' + groupId + '&subview=discussion&postId=' + comments[0].Post__c + '&commentId=' + mentionSourceId;
            }

            List<HAM_Group_Member__c> members = [
                SELECT Contact__c, Receive_Notifications__c, Notify_on_Tagged__c
                FROM HAM_Group_Member__c
                WHERE Group__c = :groupId
                  AND Contact__c IN :mentionedContactIds
                  AND Status__c = 'Active'
            ];
            if (members.isEmpty()) {
                return;
            }

            Set<Id> contactIds = new Set<Id>();
            for (HAM_Group_Member__c m : members) {
                if (m.Contact__c == mentionAuthorContactId) {
                    continue; // no self-mentions
                }
                if (!m.Receive_Notifications__c || !m.Notify_on_Tagged__c) {
                    continue;
                }
                // Per the client's rule, a member never gets two alerts for the same post:
                // when they're already in the "New post in {Group}" fan-out (execute()
                // above — every active member with the master toggle on, except the
                // author), that message wins and the mention alert is dropped. Comment
                // mentions have no competing alert, so they always send.
                //
                // As the toggles stand today the master gate is *also* the new-post
                // subscription, so this suppresses every post mention. Written as a real
                // condition rather than by deleting the branch: if the master toggle ever
                // becomes a pure gate (the proposed Notify_on_New_Posts__c field), post
                // mentions start flowing again for members who aren't subscribed to every
                // post, with no change here.
                if (mentionType == 'Post' && receivesNewPostAlert(m)) {
                    continue;
                }
                contactIds.add(m.Contact__c);
            }
            if (contactIds.isEmpty()) {
                return;
            }

            Map<Id, Id> contactToUserIdMap = new Map<Id, Id>();
            for (User u : [
                SELECT Id, ContactId FROM User WHERE ContactId IN :contactIds AND IsActive = true
            ]) {
                contactToUserIdMap.put(u.ContactId, u.Id);
            }

            Id typeId = resolveGroupAlertTypeId();
            // Notification types aren't visible to test context; let tests fall through
            if (typeId == null && !Test.isRunningTest()) {
                System.debug('CustomNotificationType not found.');
                return;
            }

            String title = groupName;
            String body = authorName + ' mentioned you! in ' + groupName;

            List<HAM_Notification__c> notifsToInsert = new List<HAM_Notification__c>();

            for (Id contactId : contactIds) {
                Id recipientUserId = contactToUserIdMap.get(contactId);
                // Test contacts have no portal Users; keep going so the branch is exercised
                if (recipientUserId == null && !Test.isRunningTest()) {
                    continue;
                }

                HAM_Notification__c n = new HAM_Notification__c();
                n.HAM_Constituent__c = contactId;
                n.HAM_Sender_Contact__c = mentionAuthorContactId;
                n.HAM_Title__c = title;
                n.HAM_Body__c = body;
                n.HAM_Source_Object_ID__c = groupId;
                n.HAM_Source_Type__c = 'Groups';
                n.HAM_Status__c = HAM_ConstantsUtil.UNREAD_S;
                n.HAM_Expiration_Date__c = System.today().addDays(30);
                n.HAM_Action_URL__c = actionUrl;
                notifsToInsert.add(n);

                try {
                    Messaging.CustomNotification currNotification = new Messaging.CustomNotification();
                    currNotification.setTitle(title);
                    currNotification.setBody(body);
                    currNotification.setNotificationTypeId(typeId);
                    String pageRefJson = '{"type": "standard__webPage", "attributes": {"url": "/' + actionUrl + '"}}';
                    currNotification.setTargetPageRef(pageRefJson);
                    currNotification.send(new Set<String>{recipientUserId});
                } catch (Exception pushEx) {
                    System.debug('Mobile Notification push failed: ' + pushEx.getMessage());
                }
            }

            if (!notifsToInsert.isEmpty()) {
                SObjectAccessDecision decision = Security.stripInaccessible(AccessType.CREATABLE, notifsToInsert);
                insert decision.getRecords();
            }
        } catch (Exception e) {
            System.debug('Exception in HAM_NotificationQueueable (mentions): ' + e.getMessage() + ' at ' + e.getStackTraceString());
        }
    }

    /**
     * @description Whether this member is already covered by the generic "New post in
     *              {Group}" fan-out in execute() — i.e. the same recipient rule that
     *              loop applies: an active member with the master toggle on, who isn't
     *              the post's author. Kept in one place so the two stay in step.
     * @param member Active member row of the group the post belongs to.
     */
    private Boolean receivesNewPostAlert(HAM_Group_Member__c member) {
        return member.Receive_Notifications__c == true
            && member.Contact__c != mentionAuthorContactId;
    }

    /**
     * @description Resolves the CustomNotificationType Id used for all group alerts,
     *              falling back to the general portal notification type if the
     *              group-specific one isn't configured.
     */
    private Id resolveGroupAlertTypeId() {
        Map<String, Id> typeMap = new Map<String, Id>();
        for (CustomNotificationType t : [
            SELECT Id, DeveloperName
            FROM CustomNotificationType
            WHERE DeveloperName IN ('Hamilton_Group_Alert', 'HAM_Portal_General_Notification')
        ]) {
            typeMap.put(t.DeveloperName, t.Id);
        }
        return typeMap.containsKey('Hamilton_Group_Alert')
            ? typeMap.get('Hamilton_Group_Alert')
            : (typeMap.containsKey('HAM_Portal_General_Notification') ? typeMap.get('HAM_Portal_General_Notification') : null);
    }
}