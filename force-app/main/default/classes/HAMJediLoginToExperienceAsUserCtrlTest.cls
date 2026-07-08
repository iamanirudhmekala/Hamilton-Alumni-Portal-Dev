@IsTest
public class HAMJediLoginToExperienceAsUserCtrlTest {

    @IsTest
    static void canLoginAsUserReturnsFalseWhenNoCommunityUser() {
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;

        Contact testContact = new Contact(
            LastName = 'Test Contact',
            AccountId = testAccount.Id
        );
        insert testContact;

        User adminUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        Test.startTest();
        Boolean result;
        System.runAs(adminUser) {
            result = HAMJediLoginToExperienceAsUserCtrl.canLoginAsUser(testContact.Id);
        }
        Test.stopTest();

        System.assertEquals(false, result, 'Should return false when no community user exists');
    }

    @IsTest
    static void canLoginAsUserReturnsFalseForNullContactId() {
        User adminUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        Test.startTest();
        Boolean result;
        System.runAs(adminUser) {
            result = HAMJediLoginToExperienceAsUserCtrl.canLoginAsUser(null);
        }
        Test.stopTest();

        System.assertEquals(false, result, 'Should return false for null contactId');
    }

    @IsTest
    static void canLoginAsUserReturnsFalseForBlankContactId() {
        User adminUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        Test.startTest();
        Boolean result;
        System.runAs(adminUser) {
            result = HAMJediLoginToExperienceAsUserCtrl.canLoginAsUser('');
        }
        Test.stopTest();

        System.assertEquals(false, result, 'Should return false for blank contactId');
    }

    @IsTest
    static void canLoginAsUserReturnsFalseForNonAdminWithoutPermissionSet() {
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;

        Contact testContact = new Contact(
            LastName = 'Test Contact',
            AccountId = testAccount.Id
        );
        insert testContact;

        Profile stdProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = new User(
            FirstName = 'Test',
            LastName = 'NonAdmin',
            Email = 'testnonadmin@test.com',
            Username = 'testnonadmin' + System.currentTimeMillis() + '@test.com',
            Alias = 'tnadmin',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = stdProfile.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert testUser;

        Test.startTest();
        Boolean result;
        System.runAs(testUser) {
            result = HAMJediLoginToExperienceAsUserCtrl.canLoginAsUser(testContact.Id);
        }
        Test.stopTest();

        System.assertEquals(false, result, 'Should return false for non-admin without permission set');
    }

    @IsTest
    static void constructorShowsErrorWhenNoContactId() {
        User adminUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        Test.startTest();
        HAMJediLoginToExperienceAsUserCtrl ctrl;
        System.runAs(adminUser) {
            PageReference pageRef = Page.HAMLoginToExperienceAsUser;
            Test.setCurrentPage(pageRef);
            ctrl = new HAMJediLoginToExperienceAsUserCtrl();
        }
        Test.stopTest();

        System.assertEquals('No Contact ID provided.', ctrl.errorMessage, 'Should show error when no contactId');
        System.assertEquals(null, ctrl.loginUrl, 'loginUrl should be null');
    }

    @IsTest
    static void constructorShowsErrorWhenBlankContactId() {
        User adminUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        Test.startTest();
        System.runAs(adminUser) {
            PageReference pageRef = Page.HAMLoginToExperienceAsUser;
            pageRef.getParameters().put('contactId', '');
            Test.setCurrentPage(pageRef);
            HAMJediLoginToExperienceAsUserCtrl ctrl = new HAMJediLoginToExperienceAsUserCtrl();
            System.assertEquals('No Contact ID provided.', ctrl.errorMessage, 'Should show error for blank contactId');
        }
        Test.stopTest();
    }

    @IsTest
    static void constructorShowsErrorWhenNoNetwork() {
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;

        Contact testContact = new Contact(
            LastName = 'Test Contact',
            AccountId = testAccount.Id
        );
        insert testContact;

        User adminUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        Test.startTest();
        HAMJediLoginToExperienceAsUserCtrl ctrl;
        System.runAs(adminUser) {
            PageReference pageRef = Page.HAMLoginToExperienceAsUser;
            pageRef.getParameters().put('contactId', testContact.Id);
            Test.setCurrentPage(pageRef);
            ctrl = new HAMJediLoginToExperienceAsUserCtrl();
        }
        Test.stopTest();

        System.assertNotEquals(null, ctrl.errorMessage, 'Should have an error message');
    }

    @IsTest(SeeAllData=true)
    static void constructorShowsErrorWhenNoMember() {
        List<Network> networks = [
            SELECT Id FROM Network
            WHERE Status = 'Live' AND Name = 'Hamilton Portal'
            LIMIT 1
        ];
        if (networks.isEmpty()) {
            return;
        }

        Account testAccount = new Account(Name = 'Test Account SeeAll');
        insert testAccount;

        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'SeeAll',
            AccountId = testAccount.Id
        );
        insert testContact;

        User adminUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        Test.startTest();
        HAMJediLoginToExperienceAsUserCtrl ctrl;
        System.runAs(adminUser) {
            PageReference pageRef = Page.HAMLoginToExperienceAsUser;
            pageRef.getParameters().put('contactId', testContact.Id);
            Test.setCurrentPage(pageRef);
            ctrl = new HAMJediLoginToExperienceAsUserCtrl();
        }
        Test.stopTest();

        System.assertEquals('No active Hamilton Portal user found for this contact.', ctrl.errorMessage);
    }
}