/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : HAM_GroupNotificationHandler_Test
 * Author          : Anirudh
 * Created Date    : July 16, 2026
 * Description     : Test class for HAM_GroupNotificationHandler and HAMGroupNotificationTrigger.
 *                   Validates that opted-in, active group members mapped to active Community
 *                   users receive a HAM_Notification__c when a HAM_Group_Notification__e platform
 *                   event fires, and that ineligible members and empty/blank payloads are handled.
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */
@isTest
private class HAM_GroupNotificationHandler_Test {

    // Contact last names let each test look up the specific member it created in @testSetup.
    private static final String ELIGIBLE_NAME  = 'GN_Eligible';
    private static final String OPTEDOUT_NAME  = 'GN_OptedOut';
    private static final String INACTIVE_NAME  = 'GN_Inactive';

    /**
     * @description Setup: one group with three members - an eligible (Active + opted-in),
     *              an opted-out, and an inactive one - so filtering can be asserted.
     */
    @testSetup
    static void setupData() {
        User runAsUser;
        List<User> usersWithRole = [SELECT Id FROM User WHERE IsActive = true AND UserRole.Name != null AND Profile.Name = 'System Administrator' LIMIT 1];
        if (usersWithRole.isEmpty()) {
            usersWithRole = [SELECT Id FROM User WHERE IsActive = true AND UserRole.Name != null LIMIT 1];
        }
        
        if (!usersWithRole.isEmpty()) {
            runAsUser = usersWithRole[0];
        } else {
            UserRole r = new UserRole(DeveloperName = 'MyCustomRole', Name = 'My Custom Role');
            insert r;
            
            Profile sysAdmin = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
            runAsUser = new User(
                Alias = 'roleusr',
                Email = 'roleusr@test.com',
                EmailEncodingKey = 'UTF-8',
                LastName = 'RoleUser',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                ProfileId = sysAdmin.Id,
                TimeZoneSidKey = 'America/Los_Angeles',
                UserName = 'roleusr' + System.currentTimeMillis() + '@hamtest.com',
                UserRoleId = r.Id,
                IsActive = true
            );
            insert runAsUser;
        }

        System.runAs(runAsUser) {
            Account acc = new Account(Name = 'Group Notification Test Account');
            insert acc;

            Contact eligible = new Contact(LastName = ELIGIBLE_NAME, AccountId = acc.Id, Email = 'gn_eligible@test.com');
            Contact optedOut = new Contact(LastName = OPTEDOUT_NAME, AccountId = acc.Id, Email = 'gn_optedout@test.com');
            Contact inactive = new Contact(LastName = INACTIVE_NAME, AccountId = acc.Id, Email = 'gn_inactive@test.com');
            insert new List<Contact>{ eligible, optedOut, inactive };

            HAM_Group__c grp = new HAM_Group__c(
                Name = 'Test Notification Group',
                is_Active__c = true,
                Visibility__c = 'Public'
            );
            insert grp;

            List<HAM_Group_Member__c> members = new List<HAM_Group_Member__c>{
                new HAM_Group_Member__c(
                    Group__c = grp.Id, Contact__c = eligible.Id,
                    Status__c = 'Active', Receive_Notifications__c = true
                ),
                new HAM_Group_Member__c(
                    Group__c = grp.Id, Contact__c = optedOut.Id,
                    Status__c = 'Active', Receive_Notifications__c = false
                ),
                new HAM_Group_Member__c(
                    Group__c = grp.Id, Contact__c = inactive.Id,
                    Status__c = 'Pending', Receive_Notifications__c = true
                )
            };
            insert members;
        }
    }

    /**
     * @description Builds and inserts a Community (portal) user linked to the given contact so the
     *              handler's Contact -> User mapping resolves. Wrapped by callers in System.runAs to
     *              avoid MIXED_DML with the notification insert. Prefers a customer-portal profile
     *              (works with a standard business account); falls back to any portal profile.
     * @param contactId Contact to link the user to.
     * @return The inserted User, or null if the org has no portal profile available.
     */
    private static User createCommunityUser(Id contactId) {
        Profile portalProfile;
        for (Profile pr : [SELECT Id, UserType FROM Profile WHERE UserType != 'Standard']) {
            if (pr.UserType == 'CspLitePortal'
                || pr.UserType == 'CustomerSuccess'
                || pr.UserType == 'PowerCustomerSuccess') {
                portalProfile = pr;
                break;
            }
            if (portalProfile == null) {
                portalProfile = pr; // fallback (e.g. PowerPartner) if no customer profile exists
            }
        }
        if (portalProfile == null) {
            return null;
        }

        String uniq = String.valueOf(System.currentTimeMillis());
        User u = new User(
            Alias = 'gntst',
            Email = 'gn_community@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'CommunityMember',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = portalProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'gncommunity' + uniq + '@hamtest.com',
            ContactId = contactId,
            IsActive = true
        );
        insert u;
        return u;
    }

    /**
     * @description Full send path via the platform event trigger. An eligible member mapped to an
     *              active Community user should receive exactly one notification; the opted-out and
     *              inactive members are filtered out by the handler's SOQL.
     */
    @isTest
    static void testEligibleMemberReceivesNotification() {
        Contact eligible = [SELECT Id FROM Contact WHERE LastName = :ELIGIBLE_NAME LIMIT 1];
        HAM_Group__c grp = [SELECT Id FROM HAM_Group__c LIMIT 1];

        // Community user insert is a setup-object DML - isolate it from the notification insert.
        System.runAs(new User(Id = UserInfo.getUserId())) {
            createCommunityUser(eligible.Id);
        }

        Test.startTest();
        EventBus.publish(new HAM_Group_Notification__e(
            Group_Id__c = grp.Id,
            Post_Id__c = grp.Id // handler does not read Post_Id__c; any 18-char id is fine
        ));
        Test.stopTest(); // flushes the platform event, firing the trigger + handler

        List<HAM_Notification__c> notifs = [
            SELECT Id, HAM_Constituent__c, HAM_Title__c, HAM_Source_Type__c, HAM_Action_URL__c
            FROM HAM_Notification__c
        ];

        System.assertEquals(1, notifs.size(),
            'Only the eligible, opted-in, user-mapped member should be notified');
        System.assertEquals(eligible.Id, notifs[0].HAM_Constituent__c,
            'Notification should be addressed to the eligible member');
        System.assertEquals('Groups', notifs[0].HAM_Source_Type__c, 'Source type should be Groups');
        System.assert(notifs[0].HAM_Title__c.contains('Test Notification Group'),
            'Title should reference the group name');
        System.assert(notifs[0].HAM_Action_URL__c.contains('groupId=' + grp.Id),
            'Action URL should deep-link to the group');
    }

    /**
     * @description Opted-in active member exists but no matching Community user - every member hits
     *              the userId == null 'continue' branch, so no notification is created.
     */
    @isTest
    static void testNoMatchingUserSkips() {
        HAM_Group__c grp = [SELECT Id FROM HAM_Group__c LIMIT 1];

        Test.startTest();
        HAM_GroupNotificationHandler.processNotifications(new List<HAM_Group_Notification__e>{
            new HAM_Group_Notification__e(Group_Id__c = grp.Id)
        });
        Test.stopTest();

        System.assertEquals(0, [SELECT Count() FROM HAM_Notification__c],
            'No notification should be created when no member maps to an active user');
    }

    /**
     * @description Blank Group_Id__c yields an empty groupIds set - the method returns early.
     */
    @isTest
    static void testBlankGroupIdEarlyReturn() {
        Test.startTest();
        HAM_GroupNotificationHandler.processNotifications(new List<HAM_Group_Notification__e>{
            new HAM_Group_Notification__e(Group_Id__c = '')
        });
        Test.stopTest();

        System.assertEquals(0, [SELECT Count() FROM HAM_Notification__c],
            'Blank Group_Id should short-circuit before any notification is created');
    }

    /**
     * @description Empty event list is handled without error and creates nothing.
     */
    @isTest
    static void testEmptyEventListEarlyReturn() {
        Test.startTest();
        HAM_GroupNotificationHandler.processNotifications(new List<HAM_Group_Notification__e>());
        Test.stopTest();

        System.assertEquals(0, [SELECT Count() FROM HAM_Notification__c],
            'Empty event list should produce no notifications');
    }
}