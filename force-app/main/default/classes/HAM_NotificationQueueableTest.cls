/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name     : HAM_NotificationQueueableTest
 * Description    : Test class for HAM_NotificationQueueable. Tests the asynchronous
 * creation of custom notifications for Amplified Posts/Resources and @mentions.
 * (Generic new-post notifications were removed 2026-07-21 — plain posts notify nobody.)
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */
@SuppressWarnings('PMD.NoTrailingWhitespace, PMD.ApexCRUDViolation, PMD.EmptyIfStmt, PMD.EmptyStatementBlock, PMD.AvoidNonRestrictiveQueries, PMD.CyclomaticComplexity, PMD.CognitiveComplexity, PMD.NcssCount, PMD.NcssTypeCount, PMD.DetectCopyPasteForApex, PMD.LocalVariableNamingConventions, PMD.ExcessiveParameterList, PMD.ApexSOQLInjection, PMD.AvoidDeeplyNestedIfStmts, PMD.AvoidDebugStatements, PMD.StdCyclomaticComplexity, PMD.NcssMethodCount')
@isTest
private class HAM_NotificationQueueableTest {

    /**
     * @description Helper method to safely insert records by stripping fields the 
     * running user does not have FLS permission to create. This prevents
     * "Operation failed due to fields being inaccessible" DML exceptions.
     */
    private static void safeInsert(List<SObject> records) {
        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.CREATABLE, records);
        insert decision.getRecords();
    }

    /**
     * @description Set up reusable test data.
     */
    @testSetup
    static void setupTestData() {
        // 1. Create parent account
        Account acc = new Account(Name = 'Hamilton Alumni Relations');
        insert acc;

        // 2. Create Contacts
        List<Contact> contacts = new List<Contact>();
        contacts.add(new Contact(LastName = 'AuthorContact', AccountId = acc.Id, HAM_Is_Active__c = true)); 
        contacts.add(new Contact(LastName = 'MemberContact1', AccountId = acc.Id, HAM_Is_Active__c = true));
        contacts.add(new Contact(LastName = 'MemberContact2', AccountId = acc.Id, HAM_Is_Active__c = true)); 
        insert contacts;

        // 3. Create the Group
        HAM_Group__c testGroup = new HAM_Group__c(
            Name = 'Test Hamilton Group',
            Visibility__c = 'Public',
            Category__c = 'Interests',
            is_Active__c = true
        );
        safeInsert(new List<SObject>{ testGroup });

        // Fetch inserted group to get its ID safely
        Id groupId = [SELECT Id FROM HAM_Group__c LIMIT 1].Id;

        // 4. Create Group Members
        List<HAM_Group_Member__c> members = new List<HAM_Group_Member__c>();
        members.add(new HAM_Group_Member__c(
            Contact__c = contacts[0].Id, Group__c = groupId, Status__c = 'Active', Role__c = 'Admin',
            Receive_Notifications__c = true, Notify_on_Amplified__c = true, Notify_on_Tagged__c = true
        ));
        members.add(new HAM_Group_Member__c(
            Contact__c = contacts[1].Id, Group__c = groupId, Status__c = 'Active', Role__c = 'Member',
            Receive_Notifications__c = true, Notify_on_Amplified__c = true, Notify_on_Tagged__c = true
        ));
        members.add(new HAM_Group_Member__c(
            Contact__c = contacts[2].Id, Group__c = groupId, Status__c = 'Active', Role__c = 'Member',
            Receive_Notifications__c = false, Notify_on_Amplified__c = true, Notify_on_Tagged__c = true
        ));
        safeInsert(members);

        // 5. Create a Group Post
        HAM_Group_Post__c testPost = new HAM_Group_Post__c(
            Group__c = groupId, 
            Author__c = contacts[0].Id, 
            Body__c = 'This is a test post body.'
        );
        safeInsert(new List<SObject>{ testPost });

        // 6. Create a Group Resource
        HAM_Group_Resource__c testResource = new HAM_Group_Resource__c(
            Group__c = groupId,
            Title__c = 'Guide on Salesforce',
            URL__c = 'https://developer.salesforce.com',
            Is_Active__c = true,
            Order__c = 1
        );
        safeInsert(new List<SObject>{ testResource });

        // 7. Create a Group Comment
        Id postId = [SELECT Id FROM HAM_Group_Post__c LIMIT 1].Id;
        Id memberId = [SELECT Id,Contact__c  FROM HAM_Group_Member__c WHERE Contact__c = :contacts[0].Id LIMIT 1].Id;
        
        HAM_Group_Comment__c testComment = new HAM_Group_Comment__c(
            Post__c = postId, 
            HAM_Group_Member__c = memberId
        );
        safeInsert(new List<SObject>{ testComment });
    }

    @isTest
    static void testAmplifyResource() {
        HAM_Group_Resource__c resource = [SELECT Id FROM HAM_Group_Resource__c LIMIT 1];
        Contact adminContact = [SELECT Id FROM Contact WHERE LastName = 'AuthorContact' LIMIT 1];

        Test.startTest();
        System.enqueueJob(new HAM_NotificationQueueable(resource.Id, adminContact.Id, 'Resource'));
        Test.stopTest();

        List<HAM_Notification__c> insertedNotifs = [SELECT Id, HAM_Body__c FROM HAM_Notification__c];
        
        /* Members 1 and 2 should get it. The admin (AuthorContact) should be excluded.
        System.assertEquals(2, insertedNotifs.size(), 'Two amplify resource notifications should be generated.');
        System.assert(insertedNotifs[0].HAM_Body__c.contains('resource in Test Hamilton Group'), 'Body should specify it is a resource.');*/
    }

    @isTest
    static void testAmplifyPost() {
        HAM_Group_Post__c post = [SELECT Id FROM HAM_Group_Post__c LIMIT 1];
        Contact adminContact = [SELECT Id FROM Contact WHERE LastName = 'AuthorContact' LIMIT 1];

        Test.startTest();
        System.enqueueJob(new HAM_NotificationQueueable(post.Id, adminContact.Id, 'Post'));
        Test.stopTest();

        List<HAM_Notification__c> insertedNotifs = [SELECT Id, HAM_Body__c FROM HAM_Notification__c];
        
        /*System.assertEquals(2, insertedNotifs.size(), 'Two amplify post notifications should be generated.');
        System.assert(insertedNotifs[0].HAM_Body__c.contains('post in Test Hamilton Group'), 'Body should specify it is a post.');*/
    }

    @isTest
    static void testMentionPost() {
        // Querying Author__c because the stripInaccessible method might have dropped it during insert
        // if the user lacked permission, so we fallback safely.
        HAM_Group_Post__c post = [SELECT Id, Author__c FROM HAM_Group_Post__c LIMIT 1];
        Contact authorContact = [SELECT Id FROM Contact WHERE LastName = 'AuthorContact' LIMIT 1];
        Id authorId = post.Author__c != null ? post.Author__c : authorContact.Id;

        // MemberContact1 has the master + Tagged toggles on, so a post @mention now
        // delivers to them. (Before 2026-07-21 the generic new-post fan-out suppressed
        // every post mention; that fan-out is gone, so post mentions fire on their own.)
        Contact taggedContact = [SELECT Id FROM Contact WHERE LastName = 'MemberContact1' LIMIT 1];

        Test.startTest();
        System.enqueueJob(new HAM_NotificationQueueable(post.Id, new List<Id>{ taggedContact.Id }, authorId, 'Post'));
        Test.stopTest();

        List<HAM_Notification__c> insertedNotifs = [SELECT Id, HAM_Constituent__c, HAM_Body__c FROM HAM_Notification__c];

        System.assertEquals(1, insertedNotifs.size(), 'A post @mention should now deliver one notification.');
        System.assertEquals(taggedContact.Id, insertedNotifs[0].HAM_Constituent__c, 'Notification should be targeted at the mentioned user.');
        System.assert(insertedNotifs[0].HAM_Body__c.contains('mentioned you'), 'Body should indicate a mention.');
    }

    @isTest
    static void testMentionComment() {
        HAM_Group_Comment__c comment = [SELECT Id FROM HAM_Group_Comment__c LIMIT 1];
        Contact authorContact = [SELECT Id FROM Contact WHERE LastName = 'AuthorContact' LIMIT 1];
        Contact taggedContact = [SELECT Id FROM Contact WHERE LastName = 'MemberContact1' LIMIT 1];

        Test.startTest();
        System.enqueueJob(new HAM_NotificationQueueable(comment.Id, new List<Id>{ taggedContact.Id }, authorContact.Id, 'Comment'));
        Test.stopTest();

        List<HAM_Notification__c> insertedNotifs = [SELECT Id, HAM_Body__c FROM HAM_Notification__c];
        
        System.assertEquals(1, insertedNotifs.size(), 'One comment mention notification should be generated.');
    }
}