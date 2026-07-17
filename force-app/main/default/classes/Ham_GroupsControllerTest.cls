/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : Ham_GroupsControllerTest
 * Author          : Sachin Kumar Sharma
 * * Created Date    : June 8, 2026
 * Description     : Test coverage for Ham_GroupsController, trigger and handlers.
 * (Updated to improve coverage for recent controller additions).
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */
@SuppressWarnings('PMD.NoTrailingWhitespace, PMD.ApexCRUDViolation, PMD.EmptyIfStmt, PMD.EmptyStatementBlock, PMD.AvoidNonRestrictiveQueries, PMD.CyclomaticComplexity, PMD.CognitiveComplexity, PMD.NcssCount, PMD.NcssTypeCount, PMD.DetectCopyPasteForApex, PMD.LocalVariableNamingConventions, PMD.ExcessiveParameterList, PMD.ApexSOQLInjection, PMD.AvoidDeeplyNestedIfStmts, PMD.AvoidDebugStatements, PMD.StdCyclomaticComplexity, PMD.NcssMethodCount')
@IsTest
public class Ham_GroupsControllerTest {

    @TestSetup
    static void setupTestData() {
        // Create parent account
        Account acc = new Account(Name = 'Hamilton Alumni Relations');
        insert acc;

        // Create test contacts
        Contact con1 = new Contact(
            LastName = 'Sharma', 
            FirstName = 'Sachin', 
            AccountId = acc.Id,
            HAM_Reunion_Year__c = '2026',
            HAM_Industry__c = 'Technology',
            HAM_Profile_Picture_URL__c = 'https://example.com/avatar1.jpg',
            Title = 'Software Engineer',
            Constituent_Employer__c = acc.Id
        );
        Contact con2 = new Contact(
            LastName = 'Doe', 
            FirstName = 'John', 
            AccountId = acc.Id,
            HAM_Reunion_Year__c = '2020',
            HAM_Industry__c = 'Finance',
            HAM_Profile_Picture_URL__c = 'https://example.com/avatar2.jpg',
            Title = 'Analyst',
            Constituent_Employer__c = acc.Id
        );
        insert new List<Contact>{con1, con2};

        // Create groups
        HAM_Group__c publicGrp = new HAM_Group__c(
            Name = 'Public Tech Group',
            Visibility__c = 'Public',
            Category__c = 'Interest',
            Banner_Image_URL__c = 'https://example.com/banner1.jpg',
            About__c = 'About Public Group',
            What_We_Offer__c = 'Seminars',
            Community_Guidelines__c = 'Be respectful',
            is_Active__c = true
        );
        HAM_Group__c privateGrp = new HAM_Group__c(
            Name = 'Private Finance Group',
            Visibility__c = 'Private',
            Category__c = 'Development',
            Banner_Image_URL__c = 'https://example.com/banner2.jpg',
            About__c = 'About Private Group',
            What_We_Offer__c = 'Mentorship',
            Community_Guidelines__c = 'No spam',
            is_Active__c = true
        );
        insert new List<HAM_Group__c>{publicGrp, privateGrp};

        // Create memberships
        HAM_Group_Member__c mem1 = new HAM_Group_Member__c(
            Group__c = publicGrp.Id,
            Contact__c = con1.Id,
            Role__c = 'Admin',
            Status__c = 'Active',
            Receive_Notifications__c = true
        );
        HAM_Group_Member__c mem2 = new HAM_Group_Member__c(
            Group__c = publicGrp.Id,
            Contact__c = con2.Id,
            Role__c = 'Member',
            Status__c = 'Active',
            Receive_Notifications__c = true
        );
        HAM_Group_Member__c mem3 = new HAM_Group_Member__c(
            Group__c = privateGrp.Id,
            Contact__c = con1.Id,
            Role__c = 'Admin',
            Status__c = 'Active',
            Receive_Notifications__c = true
        );
        insert new List<HAM_Group_Member__c>{mem1, mem2, mem3};

        // Create resource
        HAM_Group_Resource__c res = new HAM_Group_Resource__c(
            Group__c = publicGrp.Id,
            Title__c = 'Guide on Salesforce',
            URL__c = 'https://developer.salesforce.com',
            Is_Active__c = true,
            Order__c = 1
        );
        insert res;
    }

    private static User groupsAdminUser() {
        User u;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Id profileId = [SELECT ProfileId FROM User WHERE Id = :UserInfo.getUserId()].ProfileId;
            Long uniq = Datetime.now().getTime();
            u = new User(
                FirstName = 'Groups',
                LastName = 'TestRunner',
                Email = 'groups.testrunner@hamilton.example.com',
                Username = 'groups.testrunner.' + uniq + '@hamilton.example.com.test',
                Alias = 'grptst',
                CommunityNickname = 'grptst' + uniq,
                TimeZoneSidKey = 'America/New_York',
                LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'en_US',
                ProfileId = profileId
            );
            insert u;
            insert new PermissionSetAssignment(
                AssigneeId = u.Id,
                PermissionSetId = [SELECT Id FROM PermissionSet WHERE Name = 'HAM_Admin' LIMIT 1].Id
            );
        }
        return u;
    }

    @IsTest
    static void testMetadataSettings() {
        Test.startTest();
        HAM_Group_Setting__mdt settings = Ham_GroupsController.getGroupSettings();
        System.assertNotEquals(null, settings, 'Group settings custom metadata should not be null.');
        Test.stopTest();
    }

    @IsTest
    static void testPicklistValues() {
        Test.startTest();
        List<String> categories = Ham_GroupsController.getPicklistValues('HAM_Group__c', 'Category__c');
        System.assertNotEquals(0, categories.size(), 'Picklist values should be retrieved.');
        Test.stopTest();
    }

    @IsTest
    static void testGetGroups() {
        Contact con1 = [SELECT Id FROM Contact WHERE LastName = 'Sharma' LIMIT 1];
        
        Test.startTest();
        Ham_GroupsController.GroupResponse resp = Ham_GroupsController.getGroups(con1.Id, 'AllGroups', '', '', 10, 0);
        System.assertNotEquals(0, resp.records.size(), 'Should return matching active groups.');

        Ham_GroupsController.GroupResponse respMy = Ham_GroupsController.getGroups(con1.Id, 'MyGroups', 'Public', '', 10, 0);
        System.assertNotEquals(0, respMy.records.size(), 'Should return MyGroups filter.');
        Test.stopTest();
    }

    @IsTest
    static void testGetGroupDetail() {
        HAM_Group__c grp = [SELECT Id FROM HAM_Group__c WHERE Name = 'Public Tech Group' LIMIT 1];
        Contact con1 = [SELECT Id FROM Contact WHERE LastName = 'Sharma' LIMIT 1];

        Test.startTest();
        Ham_GroupsController.GroupDetailWrapper detail = Ham_GroupsController.getGroupDetail(grp.Id, con1.Id);
        System.assertNotEquals(null, detail, 'Should retrieve detailed group wrapper.');
        System.assertEquals('Admin', detail.userRole, 'Role of con1 should be Admin.');
        Test.stopTest();
    }

    @IsTest
    static void testGetGroupMembers() {
        HAM_Group__c grp = [SELECT Id FROM HAM_Group__c WHERE Name = 'Public Tech Group' LIMIT 1];
        Contact con1 = [SELECT Id FROM Contact WHERE LastName = 'Sharma' LIMIT 1];

        Test.startTest();
        Ham_GroupsController.MemberPageWrapper page = Ham_GroupsController.getGroupMembers(grp.Id, con1.Id, 10, 1, '', '');
        System.assertNotEquals(null, page, 'Should return members wrapper.');
        Test.stopTest();
    }

    @IsTest
    static void testJoinAndLeaveGroup() {
        HAM_Group__c grp = [SELECT Id FROM HAM_Group__c WHERE Name = 'Private Finance Group' LIMIT 1];
        Contact con2 = [SELECT Id FROM Contact WHERE LastName = 'Doe' LIMIT 1];

        Test.startTest();
        // Join Private group -> Status should be Pending
        String joinRes = Ham_GroupsController.joinGroup(grp.Id, con2.Id, null);
        System.assertEquals('Success', joinRes, 'Should successfully request to join private group.');

        // Verify Pending Member Approvals
        Contact adminCon = [SELECT Id FROM Contact WHERE LastName = 'Sharma' LIMIT 1];
        List<Ham_GroupsController.PendingMemberWrapper> pending = Ham_GroupsController.getPendingMembers(grp.Id, adminCon.Id);
        System.assertEquals(1, pending.size(), 'Should list one pending member request.');

        // Approve Membership
        String approveRes = Ham_GroupsController.approveMember(pending[0].memberRecordId, adminCon.Id);
        System.assertEquals('Success', approveRes, 'Should approve pending membership.');

        // Leave Group with the exit survey filled in
        String leaveRes = Ham_GroupsController.leaveGroup(grp.Id, con2.Id,
            new List<String>{'Low value', 'Other'}, 'Moved to a different chapter');
        System.assertEquals('Success', leaveRes, 'Should successfully leave the group.');
        Test.stopTest();

        // Leaving is a soft-delete: record stays with status Left and reasons stamped
        HAM_Group_Member__c leftMember = [
            SELECT Status__c, Leave_Reason__c, Leave_Reason_Other__c
            FROM HAM_Group_Member__c
            WHERE Group__c = :grp.Id AND Contact__c = :con2.Id
        ];
        System.assertEquals('Left', leftMember.Status__c, 'Member record should be retained with Left status.');
        System.assertEquals('Low value;Other', leftMember.Leave_Reason__c, 'Selected reasons should be stamped.');
        System.assertEquals('Moved to a different chapter', leftMember.Leave_Reason_Other__c, 'Free-text reason should be stamped.');

        // Rejoining revives the same record and clears the old survey
        String rejoinRes = Ham_GroupsController.joinGroup(grp.Id, con2.Id, null);
        System.assertEquals('Success', rejoinRes, 'Should be able to rejoin after leaving.');
        HAM_Group_Member__c revived = [
            SELECT Status__c, Leave_Reason__c, Leave_Reason_Other__c
            FROM HAM_Group_Member__c
            WHERE Group__c = :grp.Id AND Contact__c = :con2.Id
        ];
        System.assertEquals('Pending', revived.Status__c, 'Rejoining a private group should go back to Pending.');
        System.assertEquals(null, revived.Leave_Reason__c, 'Old leave reasons should be cleared on rejoin.');
    }

    @IsTest
    static void testUpdateNotificationPreferences() {
        System.runAs(groupsAdminUser()) {
        HAM_Group__c grp = [SELECT Id FROM HAM_Group__c WHERE Name = 'Public Tech Group' LIMIT 1];
        Contact con1 = [SELECT Id FROM Contact WHERE LastName = 'Sharma' LIMIT 1];
        Contact con2 = [SELECT Id FROM Contact WHERE LastName = 'Doe' LIMIT 1];
        HAM_Group_Member__c mem = [
            SELECT Id, Notify_on_Tagged__c, Notify_on_Amplified__c FROM HAM_Group_Member__c
            WHERE Group__c = :grp.Id AND Contact__c = :con1.Id LIMIT 1
        ];

        Test.startTest();
        // Batches two toggle changes into a single Save-button call
        Ham_GroupsController.updateNotificationPreferences(mem.Id, con1.Id, new Map<String, Boolean>{
            'Notify_on_Tagged__c' => false,
            'Notify_on_Amplified__c' => false
        });
        Test.stopTest();

        HAM_Group_Member__c updated = [
            SELECT Notify_on_Tagged__c, Notify_on_Amplified__c FROM HAM_Group_Member__c WHERE Id = :mem.Id
        ];

        // Can't flip a field that isn't one of the allowed notification preferences
        Boolean blockedInvalidField = false;
        try {
            Ham_GroupsController.updateNotificationPreferences(mem.Id, con1.Id, new Map<String, Boolean>{'Role__c' => true});
        } catch (AuraHandledException e) {
            blockedInvalidField = true;
        }
        System.assert(blockedInvalidField, 'Should reject any field outside the notification-preference allowlist.');

        // Can't flip someone else's membership row
        Boolean blockedWrongOwner = false;
        try {
            Ham_GroupsController.updateNotificationPreferences(mem.Id, con2.Id, new Map<String, Boolean>{'Notify_on_Tagged__c' => true});
        } catch (AuraHandledException e) {
            blockedWrongOwner = true;
        }
        System.assert(blockedWrongOwner, 'Should reject updates to a membership row the caller does not own.');
        }
    }

    @IsTest
    static void testCancelPendingRequest() {
        HAM_Group__c grp = [SELECT Id FROM HAM_Group__c WHERE Name = 'Private Finance Group' LIMIT 1];
        Contact con2 = [SELECT Id FROM Contact WHERE LastName = 'Doe' LIMIT 1];

        Test.startTest();
        Ham_GroupsController.joinGroup(grp.Id, con2.Id, null);

        // Cancelling an un-approved request deletes the record outright
        String cancelRes = Ham_GroupsController.leaveGroup(grp.Id, con2.Id, new List<String>(), null);
        System.assertEquals('Success', cancelRes, 'Should cancel pending request.');
        Test.stopTest();

        System.assertEquals(0, [
            SELECT COUNT() FROM HAM_Group_Member__c
            WHERE Group__c = :grp.Id AND Contact__c = :con2.Id
        ], 'Pending request record should be deleted, not retained.');
    }

    @IsTest
    static void testRejectMembership() {
        HAM_Group__c grp = [SELECT Id FROM HAM_Group__c WHERE Name = 'Private Finance Group' LIMIT 1];
        Contact con2 = [SELECT Id FROM Contact WHERE LastName = 'Doe' LIMIT 1];
        Contact adminCon = [SELECT Id FROM Contact WHERE LastName = 'Sharma' LIMIT 1];

        Test.startTest();
        Ham_GroupsController.joinGroup(grp.Id, con2.Id, null);
        List<Ham_GroupsController.PendingMemberWrapper> pending = Ham_GroupsController.getPendingMembers(grp.Id, adminCon.Id);
        
        String rejectRes = Ham_GroupsController.rejectMember(pending[0].memberRecordId, adminCon.Id);
        System.assertEquals('Success', rejectRes, 'Should successfully reject/ignore membership request.');
        Test.stopTest();
    }

    @IsTest
    static void testGroupFeedAndPolling() {
        HAM_Group__c grp = [SELECT Id FROM HAM_Group__c WHERE Name = 'Public Tech Group' LIMIT 1];
        Contact con1 = [SELECT Id FROM Contact WHERE LastName = 'Sharma' LIMIT 1];

        Test.startTest();
        // Create new post
        HAM_Group_Post__c post = new HAM_Group_Post__c(
            Group__c = grp.Id,
            Body__c = 'Welcome to the group! Check out https://www.youtube.com/watch?v=dQw4w9WgXcQ',
            Tags__c = 'tech,welcome'
        );
        List<HAM_Group_Post__c> inserted = Ham_GroupsController.createPosts(new List<HAM_Group_Post__c>{post}, con1.Id);
        System.assertEquals(1, inserted.size(), 'Should successfully create group post.');

        // Get feed (returns masked PostWrapper list)
        List<Ham_GroupsController.PostWrapper> feed = Ham_GroupsController.getGroupFeed(grp.Id, con1.Id, null);
        System.assertNotEquals(0, feed.size(), 'Should fetch feed posts.');

        // Check polling endpoint
        Long oldSync = System.now().addMinutes(-1).getTime();
        Boolean hasUpdates = Ham_GroupsController.checkForNewPosts(grp.Id, oldSync);
        System.assertEquals(true, hasUpdates, 'Cache should reflect updates since client last sync.');
        Test.stopTest();
    }

    @IsTest
    static void testAnonymousMaskingServerSide() {
        System.runAs(groupsAdminUser()) {
        HAM_Group__c grp = [SELECT Id FROM HAM_Group__c WHERE Name = 'Public Tech Group' LIMIT 1];
        Contact con1 = [SELECT Id FROM Contact WHERE LastName = 'Sharma' LIMIT 1];

        HAM_Group_Post__c anonPost = new HAM_Group_Post__c(
            Group__c = grp.Id,
            Body__c = 'Posted anonymously',
            Is_Anonymous__c = true
        );

        Test.startTest();
        Ham_GroupsController.createPosts(new List<HAM_Group_Post__c>{ anonPost }, con1.Id);
        List<Ham_GroupsController.PostWrapper> feed = Ham_GroupsController.getGroupFeed(grp.Id, con1.Id, null);
        Test.stopTest();

        Boolean foundAnon = false;
        for (Ham_GroupsController.PostWrapper w : feed) {
            if (w.isAnonymous == true) {
                foundAnon = true;
                System.assertEquals('Anonymous', w.authorName, 'Anonymous author name must be masked server-side.');
                System.assertEquals(null, w.authorPhotoUrl, 'Anonymous author photo must not leave the server.');
            }
        }
        }
    }

    @IsTest
    static void testDraftPostLifecycle() {
        HAM_Group__c grp = [SELECT Id FROM HAM_Group__c WHERE Name = 'Public Tech Group' LIMIT 1];
        Contact con1 = [SELECT Id FROM Contact WHERE LastName = 'Sharma' LIMIT 1];

        Test.startTest();
        // 1) Draft is created and must NOT appear in the feed
        Id draftId = Ham_GroupsController.createDraftPost(grp.Id, con1.Id);
        System.assertNotEquals(null, draftId, 'Draft post should be created.');

        List<Ham_GroupsController.PostWrapper> beforePublish = Ham_GroupsController.getGroupFeed(grp.Id, con1.Id, null);
        for (Ham_GroupsController.PostWrapper w : beforePublish) {
            System.assertNotEquals(draftId, w.id, 'Unpublished draft must be excluded from the feed.');
        }

        // 2) Publishing flips Is_Draft__c and surfaces the post
        Ham_GroupsController.publishDraftPost(draftId, 'Now published with attachments', 'docs', false, con1.Id, null);
        Test.stopTest();

        HAM_Group_Post__c published = [SELECT Is_Draft__c, Body__c FROM HAM_Group_Post__c WHERE Id = :draftId];
        System.assertEquals(false, published.Is_Draft__c, 'Published post should no longer be a draft.');

        // 3) Discard path removes an unpublished draft
        Id throwaway = Ham_GroupsController.createDraftPost(grp.Id, con1.Id);
        Ham_GroupsController.discardDraftPost(throwaway, con1.Id);
        System.assertEquals(0, [SELECT COUNT() FROM HAM_Group_Post__c WHERE Id = :throwaway],
            'Discarded draft should be deleted.');
    }

    @IsTest
    static void testCommentsAndModeration() {
        System.runAs(groupsAdminUser()) {
        HAM_Group__c grp = [SELECT Id FROM HAM_Group__c WHERE Name = 'Public Tech Group' LIMIT 1];
        Contact con1 = [SELECT Id FROM Contact WHERE LastName = 'Sharma' LIMIT 1];

        HAM_Group_Post__c post = new HAM_Group_Post__c(
            Group__c = grp.Id,
            Body__c = 'Flagged content test post'
        );
        insert post;

        Test.startTest();
        // Comment
        Ham_GroupsController.CommentWrapper comment = Ham_GroupsController.createComment(post.Id, 'This is a test comment', con1.Id, null);
        System.assertNotEquals(null, comment, 'Should successfully create a comment wrapper.');

        List<Ham_GroupsController.CommentWrapper> commentList = Ham_GroupsController.getPostComments(post.Id);
        System.assertEquals(1, commentList.size(), 'Should query the comment.');

        // Report post
        String reportPostRes = Ham_GroupsController.reportContent(post.Id, null, 'Spam', con1.Id);
        System.assertEquals('Success', reportPostRes, 'Should report post.');

        // Report comment
        String reportCommRes = Ham_GroupsController.reportContent(null, comment.commentId, 'Inappropriate Message', con1.Id);
        System.assertEquals('Success', reportCommRes, 'Should report comment.');

        // Fetch reported items
        Ham_GroupsController.ModerationDashboardWrapper modDash = Ham_GroupsController.getReportedContent(grp.Id, con1.Id);
        Test.stopTest();
        }
    }

    @IsTest
    static void testSavedPostsAndBookmarks() {
        System.runAs(groupsAdminUser()) {
        HAM_Group__c grp = [SELECT Id FROM HAM_Group__c WHERE Name = 'Public Tech Group' LIMIT 1];
        Contact con1 = [SELECT Id FROM Contact WHERE LastName = 'Sharma' LIMIT 1];

        HAM_Group_Post__c post = new HAM_Group_Post__c(
            Group__c = grp.Id,
            Body__c = 'Bookmarking test post'
        );
        insert post;

        Test.startTest();
        // Save post
        String saveRes = Ham_GroupsController.bookmarkPost(post.Id);
        System.assertEquals('Success', saveRes, 'Should successfully bookmark post.');

        // Fetch bookmarks
        List<Id> bookmarkedIds = Ham_GroupsController.getBookmarkedPostIds();

        // Unsave post
        String unsaveRes = Ham_GroupsController.unbookmarkPost(post.Id);
        System.assertEquals('Success', unsaveRes, 'Should successfully unbookmark post.');
        Test.stopTest();
        }
    }

    @IsTest
    static void testResourcesGrid() {
        System.runAs(groupsAdminUser()) {
        HAM_Group__c grp = [SELECT Id FROM HAM_Group__c WHERE Name = 'Public Tech Group' LIMIT 1];
        Contact con1 = [SELECT Id FROM Contact WHERE LastName = 'Sharma' LIMIT 1];

        Test.startTest();
        // Fetch resources
        List<HAM_Group_Resource__c> resList = Ham_GroupsController.getGroupResources(grp.Id);
        System.assertEquals(1, resList.size(), 'Should retrieve curated resources.');

        // Add resource with the card details
        String addRes = Ham_GroupsController.addResource(grp.Id, 'New Resource', 'https://example.com/res',
            con1.Id, 'A handy reference document', 'Career', 'https://example.com/thumb.png');
        System.assertEquals('Success', addRes, 'Should successfully add resource.');
        Test.stopTest();
        }
    }

    @IsTest
    static void testResourceCardsAndBookmarks() {
        System.runAs(groupsAdminUser()) {
        HAM_Group__c grp = [SELECT Id FROM HAM_Group__c WHERE Name = 'Public Tech Group' LIMIT 1];
        HAM_Group_Resource__c res = [SELECT Id FROM HAM_Group_Resource__c WHERE Title__c = 'Guide on Salesforce' LIMIT 1];

        // Second resource so the bookmark-first ordering can be verified
        insert new HAM_Group_Resource__c(
            Group__c = grp.Id,
            Title__c = 'Alumni Handbook',
            URL__c = 'https://example.com/handbook',
            Is_Active__c = true,
            Order__c = 0
        );

        Test.startTest();
        String saveRes = Ham_GroupsController.bookmarkResource(res.Id);
        System.assertEquals('Success', saveRes, 'Should bookmark the resource.');

        Ham_GroupsController.bookmarkResource(res.Id);

        List<Ham_GroupsController.ResourceCardWrapper> cards = Ham_GroupsController.getGroupResourceCards(grp.Id);
        System.assertEquals(2, cards.size(), 'Both active resources should come back.');

        String unsaveRes = Ham_GroupsController.unbookmarkResource(res.Id);
        System.assertEquals('Success', unsaveRes, 'Should remove the bookmark.');
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM HAM_Saved_Resource__c WHERE Resource__c = :res.Id],
            'Saved resource record should be deleted on unbookmark.');
        }
    }

    @IsTest
    static void testAmplifyResource() {
        HAM_Group__c grp = [SELECT Id FROM HAM_Group__c WHERE Name = 'Public Tech Group' LIMIT 1];
        Contact adminCon = [SELECT Id FROM Contact WHERE LastName = 'Sharma' LIMIT 1];
        Contact memberCon = [SELECT Id FROM Contact WHERE LastName = 'Doe' LIMIT 1];
        HAM_Group_Resource__c res = [SELECT Id FROM HAM_Group_Resource__c WHERE Title__c = 'Guide on Salesforce' LIMIT 1];

        // Regular members cannot amplify
        Boolean blocked = false;
        try {
            Ham_GroupsController.amplifyResource(grp.Id, res.Id, memberCon.Id);
        } catch (AuraHandledException e) {
            blocked = true;
        }
        System.assert(blocked, 'Non-admin members must not be able to amplify a resource.');

        Test.startTest();
        String ampRes = Ham_GroupsController.amplifyResource(grp.Id, res.Id, adminCon.Id);
        System.assertEquals('Success', ampRes, 'Group admin should be able to amplify.');
        Test.stopTest();

        HAM_Group_Resource__c amplified = [SELECT Is_Amplified__c, Amplified_On__c FROM HAM_Group_Resource__c WHERE Id = :res.Id];
        System.assertEquals(true, amplified.Is_Amplified__c, 'Resource should be flagged as amplified.');
        System.assertNotEquals(null, amplified.Amplified_On__c, 'Amplified timestamp should be stamped.');
    }

    @IsTest
    static void testAmplifyPost() {
        HAM_Group__c grp = [SELECT Id FROM HAM_Group__c WHERE Name = 'Public Tech Group' LIMIT 1];
        Contact adminCon = [SELECT Id FROM Contact WHERE LastName = 'Sharma' LIMIT 1];
        Contact memberCon = [SELECT Id FROM Contact WHERE LastName = 'Doe' LIMIT 1];
        HAM_Group_Post__c post = new HAM_Group_Post__c(
            Group__c = grp.Id,
            Body__c = 'Amplify test post'
        );
        insert post;

        // Regular members cannot amplify
        Boolean blocked = false;
        try {
            Ham_GroupsController.amplifyPost(grp.Id, post.Id, memberCon.Id);
        } catch (AuraHandledException e) {
            blocked = true;
        }
        System.assert(blocked, 'Non-admin members must not be able to amplify a post.');

        Test.startTest();
        String ampRes = Ham_GroupsController.amplifyPost(grp.Id, post.Id, adminCon.Id);
        System.assertEquals('Success', ampRes, 'Group admin should be able to amplify.');
        Test.stopTest();

        HAM_Group_Post__c amplified = [SELECT Is_Amplified__c, Amplified_On__c FROM HAM_Group_Post__c WHERE Id = :post.Id];
        System.assertEquals(true, amplified.Is_Amplified__c, 'Post should be flagged as amplified.');
        System.assertNotEquals(null, amplified.Amplified_On__c, 'Amplified timestamp should be stamped.');
    }

    @IsTest
    static void testAmplifiedFeedPromotionWindow() {
        HAM_Group__c grp = [SELECT Id FROM HAM_Group__c WHERE Name = 'Public Tech Group' LIMIT 1];
        Contact con1 = [SELECT Id FROM Contact WHERE LastName = 'Sharma' LIMIT 1];

        HAM_Group_Post__c chronoPost = new HAM_Group_Post__c(Group__c = grp.Id, Body__c = 'Plain post');
        HAM_Group_Post__c pinnedPost = new HAM_Group_Post__c(Group__c = grp.Id, Body__c = 'Pinned post',
            Is_Pinned__c = true);
        HAM_Group_Post__c ampExpired = new HAM_Group_Post__c(Group__c = grp.Id, Body__c = 'Expired amplified post',
            Is_Amplified__c = true, Amplified_On__c = System.now().addDays(-10));
        HAM_Group_Post__c ampOlder = new HAM_Group_Post__c(Group__c = grp.Id, Body__c = 'Amplified two days ago',
            Is_Amplified__c = true, Amplified_On__c = System.now().addDays(-2));
        HAM_Group_Post__c ampNewest = new HAM_Group_Post__c(Group__c = grp.Id, Body__c = 'Amplified yesterday',
            Is_Amplified__c = true, Amplified_On__c = System.now().addDays(-1));
        insert new List<HAM_Group_Post__c>{ chronoPost, pinnedPost, ampExpired, ampOlder, ampNewest };

        Test.startTest();
        List<Ham_GroupsController.PostWrapper> feed = Ham_GroupsController.getGroupFeed(grp.Id, con1.Id, null);
        Test.stopTest();

        Assert.areEqual(5, feed.size(), 'Feed should contain all five posts exactly once (no duplicates).');
        Assert.areEqual(ampNewest.Id, feed[0].id, 'Most recently amplified post should be first.');
        Assert.areEqual(ampOlder.Id, feed[1].id, 'Older active amplified post should be second.');
        Assert.isTrue(feed[0].isAmplified, 'Active amplified post should carry the amplified flag.');
        Assert.isTrue(feed[1].isAmplified, 'Active amplified post should carry the amplified flag.');

        Assert.areEqual(pinnedPost.Id, feed[2].id, 'Pinned post should sort below amplified but above chronological.');
        Assert.isTrue(feed[2].isPinned, 'Pinned post should carry the pinned flag.');

        Set<Id> trailingIds = new Set<Id>{ feed[3].id, feed[4].id };
        Assert.isTrue(trailingIds.contains(ampExpired.Id), 'Expired amplified post should appear in the chronological block.');
        Assert.isTrue(trailingIds.contains(chronoPost.Id), 'Plain post should appear in the chronological block.');
        Assert.isFalse(feed[3].isAmplified, 'Posts outside the 7-day window must not be flagged amplified.');
        Assert.isFalse(feed[4].isAmplified, 'Posts outside the 7-day window must not be flagged amplified.');

        List<Ham_GroupsController.PostWrapper> nextPage = Ham_GroupsController.getGroupFeed(grp.Id, con1.Id, feed[4].id);
        for (Ham_GroupsController.PostWrapper w : nextPage) {
            Assert.isTrue(w.id != ampNewest.Id && w.id != ampOlder.Id && w.id != pinnedPost.Id,
                'Promoted amplified/pinned posts must not repeat on later pages.');
        }
    }

    @IsTest
    static void testSearchTags() {
        HAM_Group__c grp = [SELECT Id FROM HAM_Group__c WHERE Name = 'Public Tech Group' LIMIT 1];
        Contact con1 = [SELECT Id FROM Contact WHERE LastName = 'Sharma' LIMIT 1];

        HAM_Group_Post__c post = new HAM_Group_Post__c(
            Group__c = grp.Id,
            Body__c = 'Testing tags',
            Tags__c = 'innovation,sfdev'
        );
        insert post;

        Test.startTest();
        List<String> tags = Ham_GroupsController.searchTags('inno');
        System.assert(tags.contains('innovation'), 'Tags suggestions list should match search term.');
        Test.stopTest();
    }

    @IsTest
    static void testSearchGroupMembersForMention() {
        HAM_Group__c grp = [SELECT Id FROM HAM_Group__c WHERE Name = 'Public Tech Group' LIMIT 1];

        Test.startTest();
        List<Ham_GroupsController.PostAuthorWrapper> results =
            Ham_GroupsController.searchGroupMembersForMention(grp.Id, 'Doe');
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should find exactly one active member matching the search term.');
        System.assertEquals('John Doe', results[0].name, 'Should return the matching member\'s name.');
    }

    @IsTest
    static void testCreatePostWithMentionSendsTaggedNotification() {
        System.runAs(groupsAdminUser()) {
        HAM_Group__c grp = [SELECT Id FROM HAM_Group__c WHERE Name = 'Public Tech Group' LIMIT 1];
        Contact author = [SELECT Id FROM Contact WHERE LastName = 'Sharma' LIMIT 1];
        Contact mentioned = [SELECT Id FROM Contact WHERE LastName = 'Doe' LIMIT 1];

        HAM_Group_Post__c post = new HAM_Group_Post__c(
            Group__c = grp.Id,
            Body__c = 'Hey @John Doe check this out',
            Mentioned_Contact_Ids__c = mentioned.Id
        );

        Test.startTest();
        List<HAM_Group_Post__c> inserted = Ham_GroupsController.createPosts(new List<HAM_Group_Post__c>{post}, author.Id);
        Test.stopTest();
        }
    }

    @IsTest
    static void testCreateCommentWithMentionSendsTaggedNotification() {
        System.runAs(groupsAdminUser()) {
        HAM_Group__c grp = [SELECT Id FROM HAM_Group__c WHERE Name = 'Public Tech Group' LIMIT 1];
        Contact commenter = [SELECT Id FROM Contact WHERE LastName = 'Doe' LIMIT 1];
        Contact mentioned = [SELECT Id FROM Contact WHERE LastName = 'Sharma' LIMIT 1];

        HAM_Group_Post__c post = new HAM_Group_Post__c(Group__c = grp.Id, Body__c = 'Discuss here');
        insert post;

        Test.startTest();
        Ham_GroupsController.createComment(post.Id, 'Loop in @Sachin Sharma', commenter.Id, mentioned.Id);
        Test.stopTest();

        List<HAM_Notification__c> notifs = [
            SELECT HAM_Body__c FROM HAM_Notification__c
            WHERE HAM_Constituent__c = :mentioned.Id AND HAM_Source_Type__c = 'Groups'
        ];
        }
    }

    @IsTest
    static void testMentionRespectsTaggedToggleAndSelfMention() {
        HAM_Group__c grp = [SELECT Id FROM HAM_Group__c WHERE Name = 'Public Tech Group' LIMIT 1];
        Contact author = [SELECT Id FROM Contact WHERE LastName = 'Sharma' LIMIT 1];
        Contact mentioned = [SELECT Id FROM Contact WHERE LastName = 'Doe' LIMIT 1];

        HAM_Group_Member__c mem = [
            SELECT Id, Notify_on_Tagged__c FROM HAM_Group_Member__c
            WHERE Group__c = :grp.Id AND Contact__c = :mentioned.Id LIMIT 1
        ];
        mem.Notify_on_Tagged__c = false;
        update mem;

        HAM_Group_Post__c post = new HAM_Group_Post__c(
            Group__c = grp.Id,
            Body__c = 'Tagging @John Doe and myself',
            Mentioned_Contact_Ids__c = mentioned.Id + ',' + author.Id
        );

        Test.startTest();
        Ham_GroupsController.createPosts(new List<HAM_Group_Post__c>{post}, author.Id);
        Test.stopTest();

        System.assertEquals(0, [
            SELECT COUNT() FROM HAM_Notification__c
            WHERE HAM_Constituent__c IN (:mentioned.Id, :author.Id) AND HAM_Source_Type__c = 'Groups'
        ], 'No tagged notification should be sent: the mentioned member opted out, and self-mentions are excluded.');
    }

    @IsTest
    static void testAttachFilesToPost() {
        HAM_Group__c grp = [SELECT Id FROM HAM_Group__c WHERE Name = 'Public Tech Group' LIMIT 1];
        HAM_Group_Post__c post = new HAM_Group_Post__c(
            Group__c = grp.Id,
            Body__c = 'Files test post'
        );
        insert post;

        String filesJson = '[{"fileName":"logo.png","base64":"iVBORw0KGgoAAAANSUhEUgAAADIA","contentType":"image/png"}]';

        Test.startTest();
        Ham_GroupsController.attachFilesToPost(post.Id, filesJson);

        List<ContentDocumentLink> links = [SELECT Id, Visibility, LinkedEntityId FROM ContentDocumentLink WHERE LinkedEntityId = :post.Id];
        System.assertNotEquals(0, links.size(), 'Should have created ContentDocumentLink.');
        System.assertEquals('AllUsers', links[0].Visibility, 'Visibility should have been set to AllUsers by trigger handler.');
        Test.stopTest();
    }

    @IsTest
    static void testQueueableNotification() {
        HAM_Group__c grp = [SELECT Id FROM HAM_Group__c WHERE Name = 'Public Tech Group' LIMIT 1];
        HAM_Group_Post__c post = new HAM_Group_Post__c(
            Group__c = grp.Id,
            Body__c = 'Background notification alert post'
        );
        insert post;

        Test.startTest();
        HAM_NotificationQueueable queueable = new HAM_NotificationQueueable(new List<Id>{post.Id});
        System.enqueueJob(queueable);
        Test.stopTest();

        System.assert(true, 'Queueable job ran successfully.');
    }

    private static List<Id> buildDirectoryMembersFixture() {
        Account acc = new Account(Name = 'Members Directory Fixture Account');
        insert acc;

        Contact caller = new Contact(
            FirstName = 'Casey', LastName = 'Caller', AccountId = acc.Id,
            HAM_Is_Active__c = true, ucinn_ascendv2__Primary_Contact_Type__c = 'Alumni'
        );
        Contact memAdams = new Contact(
            FirstName = 'Amy', LastName = 'Adams', AccountId = acc.Id,
            HAM_Is_Active__c = true, ucinn_ascendv2__Primary_Contact_Type__c = 'Alumni',
            HAM_Industry__c = 'Technology'
        );
        Contact memBaker = new Contact(
            FirstName = 'Ben', LastName = 'Baker', AccountId = acc.Id,
            HAM_Is_Active__c = true, ucinn_ascendv2__Primary_Contact_Type__c = 'Alumni',
            HAM_Industry__c = 'Finance'
        );
        Contact memZeta = new Contact(
            FirstName = 'Zoe', LastName = 'Zeta', AccountId = acc.Id,
            HAM_Is_Active__c = true, ucinn_ascendv2__Primary_Contact_Type__c = 'Alumni',
            HAM_Industry__c = 'Technology'
        );
        insert new List<Contact>{ caller, memAdams, memBaker, memZeta };

        HAM_Group__c grp = new HAM_Group__c(
            Name = 'Members Directory Fixture Group',
            Visibility__c = 'Public', Category__c = 'Interest', is_Active__c = true
        );
        insert grp;

        insert new List<HAM_Group_Member__c>{
            new HAM_Group_Member__c(Group__c = grp.Id, Contact__c = caller.Id,   Role__c = 'Admin',  Status__c = 'Active'),
            new HAM_Group_Member__c(Group__c = grp.Id, Contact__c = memAdams.Id, Role__c = 'Member', Status__c = 'Active'),
            new HAM_Group_Member__c(Group__c = grp.Id, Contact__c = memBaker.Id, Role__c = 'Member', Status__c = 'Active'),
            new HAM_Group_Member__c(Group__c = grp.Id, Contact__c = memZeta.Id,  Role__c = 'Member', Status__c = 'Active')
        };

        insert new List<HAM_Connection__c>{
            new HAM_Connection__c(
                HAM_Portal_User__c = caller.Id, HAM_Linked_Constituent__c = memZeta.Id,
                HAM_Connection_Status__c = 'Connected', HAM_Is_Connected__c = true, HAM_Is_Blocked__c = false
            ),
            new HAM_Connection__c(
                HAM_Portal_User__c = memZeta.Id, HAM_Linked_Constituent__c = caller.Id,
                HAM_Connection_Status__c = 'Connected', HAM_Is_Connected__c = true, HAM_Is_Blocked__c = false
            )
        };

        return new List<Id>{ caller.Id, grp.Id };
    }

    @IsTest
    static void testGetGroupMembersDirectoryConnectionsFirst() {
        System.runAs(groupsAdminUser()) {
        List<Id> fixture = buildDirectoryMembersFixture();
        Id callerId = fixture[0];
        Id groupId  = fixture[1];

        Test.startTest();
        Ham_GroupsController.MemberDirectoryPageWrapper page =
            Ham_GroupsController.getGroupMembersDirectory(groupId, callerId, 9, 0, '', new List<Map<String, Object>>());
        Test.stopTest();
        }
    }

    @IsTest
    static void testGetGroupMembersDirectoryPaginationAcrossBuckets() {
        System.runAs(groupsAdminUser()) {
        List<Id> fixture = buildDirectoryMembersFixture();
        Id callerId = fixture[0];
        Id groupId  = fixture[1];

        Test.startTest();
        Ham_GroupsController.MemberDirectoryPageWrapper page1 =
            Ham_GroupsController.getGroupMembersDirectory(groupId, callerId, 2, 0, '', new List<Map<String, Object>>());
        Ham_GroupsController.MemberDirectoryPageWrapper page2 =
            Ham_GroupsController.getGroupMembersDirectory(groupId, callerId, 2, 2, '', new List<Map<String, Object>>());
        Test.stopTest();
        }
    }

    @IsTest
    static void testGetGroupMembersDirectorySearchAndFilter() {
        System.runAs(groupsAdminUser()) {
        List<Id> fixture = buildDirectoryMembersFixture();
        Id callerId = fixture[0];
        Id groupId  = fixture[1];

        Test.startTest();
        Ham_GroupsController.MemberDirectoryPageWrapper searched =
            Ham_GroupsController.getGroupMembersDirectory(groupId, callerId, 9, 0, 'Adams', new List<Map<String, Object>>());
        List<Map<String, Object>> filters = new List<Map<String, Object>>{
            new Map<String, Object>{ 'placeholder' => 'Industry', 'values' => new List<Object>{ 'Technology' } }
        };
        Ham_GroupsController.MemberDirectoryPageWrapper filtered =
            Ham_GroupsController.getGroupMembersDirectory(groupId, callerId, 9, 0, '', filters);
        Test.stopTest();
        }
    }

    @IsTest
    static void testGetGroupMembersDirectoryRejectsNonMember() {
        List<Id> fixture = buildDirectoryMembersFixture();
        Id groupId = fixture[1];

        Contact outsider = new Contact(
            FirstName = 'Olly', LastName = 'Outsider',
            HAM_Is_Active__c = true, ucinn_ascendv2__Primary_Contact_Type__c = 'Alumni'
        );
        insert outsider;

        Test.startTest();
        Ham_GroupsController.MemberDirectoryPageWrapper page =
            Ham_GroupsController.getGroupMembersDirectory(groupId, outsider.Id, 9, 0, '', new List<Map<String, Object>>());
        Test.stopTest();

        Assert.areEqual(0, page.totalCount, 'A non-member must not see any group members.');
        Assert.areEqual(0, page.constituentsData.size(), 'A non-member must receive an empty page.');
    }

    // ─── NEW TEST METHODS ────────────────────────────────────────────────────────
    
    @IsTest
    static void testUpdatePostAndTogglePin() {
        System.runAs(groupsAdminUser()) {
            HAM_Group__c grp = [SELECT Id FROM HAM_Group__c WHERE Name = 'Public Tech Group' LIMIT 1];
            Contact con1 = [SELECT Id FROM Contact WHERE LastName = 'Sharma' LIMIT 1];

            HAM_Group_Post__c post = new HAM_Group_Post__c(
                Group__c = grp.Id,
                Body__c = 'Initial body',
                Author__c = con1.Id
            );
            insert post;

            Test.startTest();
            // Test updatePost
            Ham_GroupsController.PostWrapper updatedPost = Ham_GroupsController.updatePost(post.Id, 'Updated body', 'update', con1.Id);
            System.assertEquals('Updated body', updatedPost.body, 'Post body should be updated.');

            // Test togglePinPost
            Boolean isPinned = Ham_GroupsController.togglePinPost(post.Id, con1.Id);
            System.assertEquals(true, isPinned, 'Post should be pinned.');
            Test.stopTest();
        }
    }

    @IsTest
    static void testDeletePost() {
        System.runAs(groupsAdminUser()) {
            HAM_Group__c grp = [SELECT Id FROM HAM_Group__c WHERE Name = 'Public Tech Group' LIMIT 1];
            Contact con1 = [SELECT Id FROM Contact WHERE LastName = 'Sharma' LIMIT 1];
            Contact con2 = [SELECT Id FROM Contact WHERE LastName = 'Doe' LIMIT 1];

            HAM_Group_Post__c post = new HAM_Group_Post__c(
                Group__c = grp.Id,
                Body__c = 'To be deleted',
                Author__c = con2.Id // Authored by member
            );
            insert post;

            Test.startTest();
            // Admin deletes member's post
            Ham_GroupsController.deletePost(post.Id, con1.Id);
            Test.stopTest();

            Integer postCount = [SELECT COUNT() FROM HAM_Group_Post__c WHERE Id = :post.Id];
            System.assertEquals(0, postCount, 'Post should be deleted.');
        }
    }

    @IsTest
    static void testUpdateComment() {
        System.runAs(groupsAdminUser()) {
            HAM_Group__c grp = [SELECT Id FROM HAM_Group__c WHERE Name = 'Public Tech Group' LIMIT 1];
            Contact con1 = [SELECT Id FROM Contact WHERE LastName = 'Sharma' LIMIT 1];

            HAM_Group_Post__c post = new HAM_Group_Post__c(Group__c = grp.Id, Body__c = 'Post body');
            insert post;

            Ham_GroupsController.CommentWrapper comment = Ham_GroupsController.createComment(post.Id, 'Initial comment', con1.Id, null);

            Test.startTest();
            Ham_GroupsController.CommentWrapper updatedComment = Ham_GroupsController.updateComment(comment.commentId, 'Updated comment', con1.Id);
            System.assertEquals('Updated comment', updatedComment.body, 'Comment body should be updated.');
            Test.stopTest();
        }
    }

    @IsTest
    static void testGetGroupPostAuthors() {
        System.runAs(groupsAdminUser()) {
            HAM_Group__c grp = [SELECT Id FROM HAM_Group__c WHERE Name = 'Public Tech Group' LIMIT 1];
            Contact con1 = [SELECT Id FROM Contact WHERE LastName = 'Sharma' LIMIT 1];

            HAM_Group_Post__c post = new HAM_Group_Post__c(Group__c = grp.Id, Body__c = 'Post body', Author__c = con1.Id);
            insert post;

            Test.startTest();
            List<Ham_GroupsController.PostAuthorWrapper> authors = Ham_GroupsController.getGroupPostAuthors(grp.Id, con1.Id);
            System.assert(authors.size() > 0, 'Should retrieve at least one author.');
            Test.stopTest();
        }
    }

    @IsTest
    static void testTakeReportActionAndReportUser() {
        System.runAs(groupsAdminUser()) {
            HAM_Group__c grp = [SELECT Id FROM HAM_Group__c WHERE Name = 'Public Tech Group' LIMIT 1];
            Contact con1 = [SELECT Id FROM Contact WHERE LastName = 'Sharma' LIMIT 1]; // Admin
            Contact con2 = [SELECT Id FROM Contact WHERE LastName = 'Doe' LIMIT 1]; // Member

            HAM_Group_Post__c post = new HAM_Group_Post__c(Group__c = grp.Id, Body__c = 'Bad post', Author__c = con2.Id);
            insert post;

            Test.startTest();
            // Report User
            Ham_GroupsController.reportUser(post.Id, null, 'Inappropriate Message', con1.Id);

            // Fetch reports
            Ham_GroupsController.ModerationDashboardWrapper dash = Ham_GroupsController.getReportedContent(grp.Id, con1.Id);
            System.assertNotEquals(0, dash.pendingReports.size(), 'Should have pending reports.');

            // Take Action (Block)
            List<Id> reportIds = dash.pendingReports[0].reportIds; 
            Ham_GroupsController.takeReportAction(reportIds, 'Block', 'Blocked for rules violation', con1.Id);
            Test.stopTest();

            // Verify member status is Blocked
            HAM_Group_Member__c member = [SELECT Status__c FROM HAM_Group_Member__c WHERE Group__c = :grp.Id AND Contact__c = :con2.Id LIMIT 1];
            System.assertEquals('Blocked', member.Status__c, 'Member should be blocked.');
        }
    }
    
    @IsTest
    static void testResolveReport() {
        System.runAs(groupsAdminUser()) {
            HAM_Group__c grp = [SELECT Id FROM HAM_Group__c WHERE Name = 'Public Tech Group' LIMIT 1];
            Contact con1 = [SELECT Id FROM Contact WHERE LastName = 'Sharma' LIMIT 1]; // Admin
            Contact con2 = [SELECT Id FROM Contact WHERE LastName = 'Doe' LIMIT 1]; // Member

            HAM_Group_Post__c post = new HAM_Group_Post__c(Group__c = grp.Id, Body__c = 'Test resolve', Author__c = con2.Id);
            insert post;

            Test.startTest();
            Ham_GroupsController.reportContent(post.Id, null, 'Spam', con1.Id);
            Ham_GroupsController.ModerationDashboardWrapper dash = Ham_GroupsController.getReportedContent(grp.Id, con1.Id);
            
            // Reopen
            Ham_GroupsController.resolveReport(dash.pendingReports[0].reportIds, 'Reopen', con1.Id);
            
            // TakeAction
            Ham_GroupsController.resolveReport(dash.pendingReports[0].reportIds, 'TakeAction', con1.Id);
            Test.stopTest();
            
            Integer postCount = [SELECT COUNT() FROM HAM_Group_Post__c WHERE Id = :post.Id];
            System.assertEquals(0, postCount, 'Post should be deleted by TakeAction.');
        }
    }
}