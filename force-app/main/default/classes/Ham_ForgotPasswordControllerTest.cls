/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : Ham_ForgotPasswordControllerTest
 * Author          : Sachin Kumar sharma
 * Created Date    : June 02, 2026
 * Description     : Comprehensive unit tests for Ham_ForgotPasswordController
 *                   maximizing code coverage (95%+) and validating FLS/CRUD security paths.
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */
@IsTest
public with sharing class Ham_ForgotPasswordControllerTest {

    @TestSetup
    static void setupData() {
        SObjectType bypassSettingType = Schema.getGlobalDescribe().get('ucinn_ascendv2__Bypass_Settings__c');
        if (bypassSettingType != null) {
            SObject bypassSetting = bypassSettingType.newSObject();
            bypassSetting.put('SetupOwnerId', UserInfo.getOrganizationId());
            Map<String, SObjectField> bypassFieldsMap = bypassSettingType.getDescribe().fields.getMap();
            if (bypassFieldsMap.containsKey('ucinn_ascendv2__Bypass_Triggers__c')) bypassSetting.put('ucinn_ascendv2__Bypass_Triggers__c', true);
            if (bypassFieldsMap.containsKey('ucinn_ascendv2__Bypass_Validation_Rules__c')) bypassSetting.put('ucinn_ascendv2__Bypass_Validation_Rules__c', true);
            if (bypassFieldsMap.containsKey('ucinn_ascendv2__Bypass_All__c')) bypassSetting.put('ucinn_ascendv2__Bypass_All__c', true);
            insert bypassSetting;
        }

        List<ucinn_ascendv2__Reciprocal_Relationships__c> settings = new List<ucinn_ascendv2__Reciprocal_Relationships__c>();
        settings.add(new ucinn_ascendv2__Reciprocal_Relationships__c(Name = 'Child', ucinn_ascendv2__Reciprocal__c = 'Parent'));
        settings.add(new ucinn_ascendv2__Reciprocal_Relationships__c(Name = 'Parent', ucinn_ascendv2__Reciprocal__c = 'Child'));
        insert settings;

        Account acc = new Account(Name = 'Test ForgotPassword Account');
        insert acc;

        Contact con = new Contact(FirstName = 'Tier2', LastName = 'Contact', AccountId = acc.Id, Email = 'tier2@test.com');
        Contact con3 = new Contact(FirstName = 'Tier3', LastName = 'Contact', AccountId = acc.Id, Email = 'different_email@test.com');
        insert new List<Contact>{con, con3};

        Id emailRTId;
        try { emailRTId = [SELECT Id FROM RecordType WHERE SobjectType = 'ucinn_ascendv2__Email__c' AND DeveloperName = 'Contact_Email' LIMIT 1].Id; } catch(Exception e) {}

        ucinn_ascendv2__Email__c ascendEmail = new ucinn_ascendv2__Email__c(
            ucinn_ascendv2__Contact__c = con3.Id,
            ucinn_ascendv2__Email_Address__c = 'tier3@test.com',
            ucinn_ascendv2__Is_Preferred__c = true,
            ucinn_ascendv2__Status__c = 'Current',
            ucinn_ascendv2__Type__c = 'Personal'
        );
        Map<String, SObjectField> emailFieldsMap = ucinn_ascendv2__Email__c.SObjectType.getDescribe().fields.getMap();
        if (emailFieldsMap != null && emailFieldsMap.containsKey('ucinn_ascendv2__account__c')) ascendEmail.put('ucinn_ascendv2__Account__c', acc.Id);
        if (emailRTId != null) ascendEmail.RecordTypeId = emailRTId;
        insert ascendEmail;
    }

    private static User createPortalUser(String lastName, String email, Id contactId) {
        Profile portalProfile;
        try {
            portalProfile = [SELECT Id, Name FROM Profile WHERE UserType IN ('PowerPartner', 'CspLitePortal', 'PowerCustomerSuccess') LIMIT 1];
        } catch(Exception e) {
            portalProfile = [SELECT Id, Name FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        }

        User u = new User(
            Alias = lastName.substring(0, Math.min(lastName.length(), 5)),
            Email = email,
            EmailEncodingKey = 'UTF-8',
            LastName = lastName,
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = portalProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'portal_' + lastName.toLowerCase() + System.currentTimeMillis() + '@test.com',
            ContactId = (portalProfile.Name == 'Standard User') ? null : contactId
        );
        return u;
    }

    @IsTest
    static void testInitializePasswordResetGuards() {
        Test.startTest();
        // Null/Blank Email
        Ham_ForgotPasswordController.ResetResult res1 = Ham_ForgotPasswordController.initiateReset('', 'VALID_CAPTCHA', null);
        System.assertEquals('ERROR', res1.status);

        // Null Captcha
        Ham_ForgotPasswordController.ResetResult res2 = Ham_ForgotPasswordController.initiateReset('test@example.com', null, null);
        System.assertEquals('ERROR', res2.status);

        // Invalid Captcha
        Ham_ForgotPasswordController.ResetResult res3 = Ham_ForgotPasswordController.initiateReset('test@example.com', 'INVALID', null);
        System.assertEquals('ERROR', res3.status);
        Test.stopTest();
    }

    @IsTest
    static void testPasswordResetSuccessMockUser() {
        User adminUser = [SELECT Id FROM User WHERE Profile.Name = 'System Administrator' AND IsActive = true LIMIT 1];
        Test.startTest();
        Ham_ForgotPasswordController.ResetResult res;
        System.runAs(adminUser) {
            res = Ham_ForgotPasswordController.initiateReset('unregistered@test.com', 'VALID_CAPTCHA', null);
        }
        Test.stopTest();
        System.assertEquals('SUCCESS', res.status);
        System.assertEquals(System.Label.Ham_ForgotPasswordSuccessMsg, res.message);
        System.assertEquals(null, res.debugForgotResult);
    }

    @IsTest
    static void testPasswordResetSuccessTier1() {
        User adminUser = [SELECT Id FROM User WHERE Profile.Name = 'System Administrator' AND IsActive = true LIMIT 1];
        Contact con = [SELECT Id FROM Contact WHERE LastName = 'Contact' LIMIT 1];
        User portalUser;

        System.runAs(adminUser) {
            portalUser = createPortalUser('Tier1Reset', 'tier1reset@test.com', con.Id);
            insert portalUser;
        }

        Test.startTest();
        Ham_ForgotPasswordController.ResetResult res;
        System.runAs(adminUser) {
            Ham_ForgotPasswordController.mockVerifiedEmail = true;
            res = Ham_ForgotPasswordController.initiateReset('tier1reset@test.com', 'VALID_CAPTCHA', null);
        }
        Test.stopTest();
        System.assertEquals('SUCCESS', res.status);
        System.assertEquals(true, res.debugForgotResult);
    }

    @IsTest
    static void testPasswordResetSuccessTier2() {
        User adminUser = [SELECT Id FROM User WHERE Profile.Name = 'System Administrator' AND IsActive = true LIMIT 1];
        Contact con = [SELECT Id FROM Contact WHERE LastName = 'Contact' AND Email = 'tier2@test.com' LIMIT 1];
        User portalUser;

        System.runAs(adminUser) {
            portalUser = createPortalUser('Tier2Reset', 'tier2_reset@test.com', con.Id);
            insert portalUser;
        }

        Test.startTest();
        Ham_ForgotPasswordController.ResetResult res;
        System.runAs(adminUser) {
            Ham_ForgotPasswordController.mockVerifiedEmail = true;
            res = Ham_ForgotPasswordController.initiateReset('tier2@test.com', 'VALID_CAPTCHA', null);
        }
        Test.stopTest();
        System.assertEquals('SUCCESS', res.status);
        System.assertEquals(true, res.debugForgotResult);
    }

    @IsTest
    static void testPasswordResetSuccessTier3() {
        User adminUser = [SELECT Id FROM User WHERE Profile.Name = 'System Administrator' AND IsActive = true LIMIT 1];
        Contact con3 = [SELECT Id FROM Contact WHERE LastName = 'Contact' AND Email = 'different_email@test.com' LIMIT 1];
        User portalUser;

        System.runAs(adminUser) {
            portalUser = createPortalUser('Tier3Reset', 'tier3_reset@test.com', con3.Id);
            insert portalUser;
        }

        Test.startTest();
        Ham_ForgotPasswordController.ResetResult res;
        System.runAs(adminUser) {
            Ham_ForgotPasswordController.mockVerifiedEmail = true;
            res = Ham_ForgotPasswordController.initiateReset('tier3@test.com', 'VALID_CAPTCHA', null);
        }
        Test.stopTest();
        System.assertEquals('SUCCESS', res.status);
        System.assertEquals(true, res.debugForgotResult);
    }

    @IsTest
    static void testPasswordResetUnverifiedTier1() {
        User adminUser = [SELECT Id FROM User WHERE Profile.Name = 'System Administrator' AND IsActive = true LIMIT 1];
        Contact con = [SELECT Id FROM Contact WHERE LastName = 'Contact' LIMIT 1];
        User portalUser;

        System.runAs(adminUser) {
            portalUser = createPortalUser('Tier1Unverified', 'tier1unverified@test.com', con.Id);
            insert portalUser;
        }

        Test.startTest();
        Ham_ForgotPasswordController.ResetResult res;
        System.runAs(adminUser) {
            Ham_ForgotPasswordController.mockVerifiedEmail = false;
            res = Ham_ForgotPasswordController.initiateReset('tier1unverified@test.com', 'VALID_CAPTCHA', null);
        }
        Test.stopTest();
        System.assertEquals('VERIFICATION_SENT', res.status);
        System.assertEquals(System.Label.Ham_ErrEmailUnverified, res.message);
        System.assertEquals(false, res.debugForgotResult);
    }

    @IsTest
    static void testPasswordResetRateLimit() {
        User adminUser = [SELECT Id FROM User WHERE Profile.Name = 'System Administrator' AND IsActive = true LIMIT 1];
        String testEmail = 'ratelimitreset@test.com';

        Boolean isLogWritable = Schema.getGlobalDescribe().containsKey('OTP_Request_Log__c') && 
                                 Schema.getGlobalDescribe().get('OTP_Request_Log__c').getDescribe().isCreateable() &&
                                 Schema.getGlobalDescribe().get('OTP_Request_Log__c').getDescribe().fields.getMap().containsKey('Target_Email__c') &&
                                 Schema.getGlobalDescribe().get('OTP_Request_Log__c').getDescribe().fields.getMap().get('Target_Email__c').getDescribe().isCreateable() &&
                                 Schema.getGlobalDescribe().get('OTP_Request_Log__c').getDescribe().fields.getMap().containsKey('Request_Type__c') &&
                                 Schema.getGlobalDescribe().get('OTP_Request_Log__c').getDescribe().fields.getMap().get('Request_Type__c').getDescribe().isCreateable();

        if (isLogWritable) {
            System.runAs(adminUser) {
                List<SObject> logs = new List<SObject>();
                for (Integer i = 0; i < 3; i++) {
                    SObject newLog = Schema.getGlobalDescribe().get('OTP_Request_Log__c').newSObject();
                    newLog.put('Target_Email__c', testEmail);
                    newLog.put('Request_Type__c', 'Forgot_Password');
                    logs.add(newLog);
                }
                insert logs;
            }
        }

        Test.startTest();
        Ham_ForgotPasswordController.ResetResult res;
        System.runAs(adminUser) {
            res = Ham_ForgotPasswordController.initiateReset(testEmail, 'VALID_CAPTCHA', null);
        }
        Test.stopTest();

        if (isLogWritable) {
            System.assertEquals('ERROR', res.status);
            System.assertEquals(System.Label.Ham_ErrRateLimitExceeded, res.message);
        } else {
            System.assertEquals('SUCCESS', res.status);
        }
    }

    @IsTest
    static void testPasswordResetSecurityException() {
        User adminUser = [SELECT Id FROM User WHERE Profile.Name = 'System Administrator' AND IsActive = true LIMIT 1];
        Contact con = [SELECT Id FROM Contact WHERE LastName = 'Contact' LIMIT 1];
        User portalUser;

        System.runAs(adminUser) {
            portalUser = createPortalUser('Tier1Reset', 'tier1reset@test.com', con.Id);
            insert portalUser;
        }

        Test.startTest();
        Ham_ForgotPasswordController.ResetResult res;
        System.runAs(adminUser) {
            Ham_ForgotPasswordController.mockVerifiedEmail = true;
            Ham_ForgotPasswordController.throwSecurityException = true;
            res = Ham_ForgotPasswordController.initiateReset('tier1reset@test.com', 'VALID_CAPTCHA', null);
        }
        Test.stopTest();
        System.assertEquals('SUCCESS', res.status);
    }

    @IsTest
    static void testPasswordResetGenericException() {
        User adminUser = [SELECT Id FROM User WHERE Profile.Name = 'System Administrator' AND IsActive = true LIMIT 1];
        
        Test.startTest();
        System.runAs(adminUser) {
            Ham_ForgotPasswordController.throwGenericException = true;
            try {
                Ham_ForgotPasswordController.initiateReset('test@test.com', 'VALID_CAPTCHA', null);
                System.assert(false, 'Expected an AuraHandledException to be thrown');
            } catch (AuraHandledException e) {
                System.assert(e.getMessage() != null);
            }
        }
        Test.stopTest();
    }

    @IsTest
    static void testPasswordResetBulkSimulation() {
        User adminUser = [SELECT Id FROM User WHERE Profile.Name = 'System Administrator' AND IsActive = true LIMIT 1];
        
        Test.startTest();
        System.runAs(adminUser) {
            for (Integer i = 0; i < 20; i++) {
                Ham_ForgotPasswordController.ResetResult res = Ham_ForgotPasswordController.initiateReset('bulkuser' + i + '@test.com', 'VALID_CAPTCHA', null);
                System.assertEquals('SUCCESS', res.status);
            }
        }
        Test.stopTest();
    }

    @IsTest
    static void testPasswordResetRateLimitAsGuest() {
        List<User> guestUsers = [SELECT Id FROM User WHERE UserType = 'Guest' AND IsActive = true LIMIT 1];
        if (guestUsers.isEmpty()) {
            return;
        }
        User guestUser = guestUsers[0];

        // Determine if the Guest User has read/write permissions for the log object
        Boolean isLogAccessibleToGuest = false;
        System.runAs(guestUser) {
            isLogAccessibleToGuest = Schema.getGlobalDescribe().containsKey('OTP_Request_Log__c') && 
                                     Schema.getGlobalDescribe().get('OTP_Request_Log__c').getDescribe().isAccessible() &&
                                     Schema.getGlobalDescribe().get('OTP_Request_Log__c').getDescribe().isCreateable() &&
                                     Schema.getGlobalDescribe().get('OTP_Request_Log__c').getDescribe().fields.getMap().containsKey('Target_Email__c') &&
                                     Schema.getGlobalDescribe().get('OTP_Request_Log__c').getDescribe().fields.getMap().get('Target_Email__c').getDescribe().isCreateable() &&
                                     Schema.getGlobalDescribe().get('OTP_Request_Log__c').getDescribe().fields.getMap().containsKey('Request_Type__c') &&
                                     Schema.getGlobalDescribe().get('OTP_Request_Log__c').getDescribe().fields.getMap().get('Request_Type__c').getDescribe().isCreateable();
        }

        Test.startTest();
        System.runAs(guestUser) {
            String testEmail = 'guest_ratelimit@test.com';
            
            if (isLogAccessibleToGuest) {
                // First 3 requests should succeed
                for (Integer i = 0; i < 3; i++) {
                    Ham_ForgotPasswordController.ResetResult res = Ham_ForgotPasswordController.initiateReset(testEmail, 'VALID_CAPTCHA', null);
                    System.assertEquals('SUCCESS', res.status);
                }
                
                // 4th request should fail with Rate Limit Exceeded error
                Ham_ForgotPasswordController.ResetResult res4 = Ham_ForgotPasswordController.initiateReset(testEmail, 'VALID_CAPTCHA', null);
                System.assertEquals('ERROR', res4.status);
                System.assertEquals(System.Label.Ham_ErrRateLimitExceeded, res4.message);
            } else {
                // If not accessible/writable, requests should succeed because rate limiting is bypassed
                Ham_ForgotPasswordController.ResetResult res = Ham_ForgotPasswordController.initiateReset(testEmail, 'VALID_CAPTCHA', null);
                System.assertEquals('SUCCESS', res.status);
            }
        }
        Test.stopTest();
    }
}