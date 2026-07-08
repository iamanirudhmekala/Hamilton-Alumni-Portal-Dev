@IsTest
private class HamGivingPageControllerTest {

    @testSetup
    static void setupData() {
        Account acc = new Account(
            Name = 'Test Giving Account'
        );
        insert acc;

        Contact con = new Contact(
            FirstName = 'John',
            LastName = 'Doe',
            Email = 'john.doe@testexample.com',
            AccountId = acc.Id
        );
        insert con;
    }

    @IsTest
    static void testCreateExperienceCloudUser_ProfileNotFound() {
        Test.startTest();
        String result = HamGivingPageController.createExperienceCloudUser(
            'john.doe@testexample.com',
            'Definitely Not A Real Profile Name'
        );
        Test.stopTest();

        System.assertEquals(
            'Unable to create Experience Cloud User. Profile not found.',
            result
        );
    }

    @IsTest
    static void testCreateExperienceCloudUser_ContactNotFound() {
        Profile p = [
            SELECT Id, Name
            FROM Profile
            LIMIT 1
        ];

        Test.startTest();
        String result = HamGivingPageController.createExperienceCloudUser(
            'missing.contact@testexample.com',
            p.Name
        );
        Test.stopTest();

        System.assertEquals(
            'Unable to create Experience Cloud User. Contact not found.',
            result
        );
    }

    @IsTest
    static void testCreateExperienceCloudUser_DmlExceptionBranch() {
        Contact con = [
            SELECT Id, Email, FirstName, LastName, AccountId
            FROM Contact
            WHERE Email = 'john.doe@testexample.com'
            LIMIT 1
        ];

        Profile p = [
            SELECT Id, Name
            FROM Profile
            LIMIT 1
        ];

        Test.startTest();
        String result = HamGivingPageController.createExperienceCloudUser(
            con.Email,
            p.Name
        );
        Test.stopTest();

        System.assertNotEquals('User created successfully.', result);
        System.assert(result != null && result.length() > 0,
            'Expected a DML error message to be returned.'
        );
    }

    @IsTest
    static void testBuildUser() {
        Contact con = [
            SELECT Id, Email, FirstName, LastName, AccountId
            FROM Contact
            WHERE Email = 'john.doe@testexample.com'
            LIMIT 1
        ];

        Profile p = [
            SELECT Id, Name
            FROM Profile
            LIMIT 1
        ];

        Test.startTest();
        User builtUser = HamGivingPageController.buildUser(con, p);
        Test.stopTest();

        System.assertEquals(con.Id, builtUser.ContactId);
        System.assertEquals(con.Email, builtUser.Email);
        System.assertEquals(con.FirstName, builtUser.FirstName);
        System.assertEquals(con.LastName, builtUser.LastName);
        System.assertEquals(p.Id, builtUser.ProfileId);
        System.assertEquals('en_US', builtUser.LocaleSidKey);
        System.assertEquals('America/Los_Angeles', builtUser.TimeZoneSidKey);
        System.assertEquals('en_US', builtUser.LanguageLocaleKey);
        System.assertEquals('UTF-8', builtUser.EmailEncodingKey);
        System.assertEquals('JD', builtUser.Alias);
        System.assert(builtUser.Username.contains('+giving_page@'));
        System.assert(builtUser.CommunityNickname != null);
    }

    @IsTest
    static void testGenerateUserName() {
        Contact con = [
            SELECT Id, Email, FirstName, LastName, AccountId
            FROM Contact
            WHERE Email = 'john.doe@testexample.com'
            LIMIT 1
        ];

        Test.startTest();
        String username = HamGivingPageController.generateUserName(con);
        Test.stopTest();

        System.assertEquals(
            'john.doe+giving_page@testexample.com',
            username
        );
    }
}