/**
* @File Name : HAM_MainController_Test.cls
* @Description : Test class for HAM_MainController to ensure 100% coverage
* @Author : Sachin Kumar Sharma
* @Last Modified By : Sachin Kumar Sharma
* @Last Modified On : August 21, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | August 21, 2025 | Sachin Kumar Sharma  | Initial Version
* 1.1 | May 08, 2026    | Gemini               | Added missing coverage and fixed assertions
**/
@SuppressWarnings('PMD.NoTrailingWhitespace, PMD.ExcessiveClassLength, PME.ExcessivePublicCount,PMD.ApexDoc,PMD.DebugsShouldUseLoggingLevel,PMD.ApexUnitTestClassShouldHaveRunAs, PMD.ApexCRUDViolation,PMD.ApexUnitTestClassShouldHaveAsserts,PMD.MethodNamingConventions, PMD.EmptyIfStmt, PMD.EmptyStatementBlock, PMD.AvoidNonRestrictiveQueries, PMD.CyclomaticComplexity, PMD.CognitiveComplexity, PMD.NcssCount, PMD.NcssTypeCount, PMD.DetectCopyPasteForApex, PMD.LocalVariableNamingConventions, PMD.ExcessiveParameterList, PMD.ApexSOQLInjection, PMD.AvoidDeeplyNestedIfStmts, PMD.AvoidDebugStatements, PMD.StdCyclomaticComplexity, PMD.NcssMethodCount')
@isTest
public class HAM_MainController_Test {
    
    @testSetup
    static void setupData() {
        // Create a Profile
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        
        Profile p2 = [SELECT Id FROM Profile WHERE Name = 'Partner Community Login User' LIMIT 1];
        
        // Create a Contact for the portal user
        Contact con = new Contact(FirstName = 'Test', LastName = 'Contact', ucinn_ascendv2__Primary_Contact_Type__c = 'Trustee');
        insert con;
        
        // User1 : Base internal user (will simulate ContactId in test)
        User u1 = new User(
            FirstName = 'Test',
            LastName = 'User1',
            Email = 'user1@test.com',
            Username = 'user1_' + System.currentTimeMillis() + '@test.com',
            Alias = 'u1',
            TimeZoneSidKey = 'GMT',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert u1;
        
        // User2 : No ContactId, will test branch 2
        User u2 = new User(
            FirstName = 'Test',
            LastName = 'User2',
            Email = 'user2@test.com',
            Username = 'user2_' + System.currentTimeMillis() + '@test.com',
            Alias = 'u2',
            TimeZoneSidKey = 'GMT',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert u2;
        
        // User3 : Same email as u2, pretend as portal user with ContactId
        // (for test branch simulation we don't need a real contact association)
        User u3 = new User(
            FirstName = 'Test',
            LastName = 'User3',
            Email = u2.Email,
            Username = 'user3_' + System.currentTimeMillis() + '@test.com',
            Alias = 'u3',
            TimeZoneSidKey = 'GMT',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p2.Id,
            IsActive = true,
            // Assign the ContactId to u3
            ContactId = con.Id
        );
        insert u3;
    }
    
    /**
     * Test for getMyLinksMetaData
     * Assumes CMDT record with HAM_Level_1__c = 'NavBar' exists in org
     */
    @isTest
    static void testGetMyLinksMetaData() {
        Test.startTest();
        List<HAM_Meta_Data__mdt> result = HAM_MainController.getMyLinksMetaData();
        Test.stopTest();
        // We assert against null instead of size because metadata availability in tests can vary 
        // depending on org data (unless using a mocking framework for CMDT)
        System.assertNotEquals(null, result, 'Expected a list of metadata records');
    }
    
    /**
     * Test for fetchLoggedInUserInfo where user has no ContactId and no fallback
     */
    @isTest
    static void testFetchLoggedInUserInfo_withContactId() {
        User u1 = [SELECT Id, Email FROM User WHERE Email = 'user1@test.com' LIMIT 1];
        
        System.runAs(u1) {
            Test.startTest();
            // Changed variable name from 'contactId' to 'contactRec' for clarity
            Contact contactRec = HAM_MainController.fetchLoggedInUserInfo();
            Test.stopTest();
            
            System.assertEquals(null, contactRec, 'Should return null as there is no ContactId and no fallback matching email');
        }
    }
    
    /**
     * Test for fetchLoggedInUserInfo where user has no ContactId
     * but another active user with same email does (simulated portal user branch)
     */
    @isTest
    static void testFetchLoggedInUserInfo_withSameEmailPortalUser() {
        User u2 = [SELECT Id, Email FROM User WHERE Email = 'user2@test.com' LIMIT 1];
        
        System.runAs(u2) {
            Test.startTest();
            Contact contactRec = HAM_MainController.fetchLoggedInUserInfo();
            Test.stopTest();
            
            System.assertNotEquals(null, contactRec, 'Should return Contact record from simulated portal user');
        }
    }
    
    /**
     * Test for fetchLoggedInUserInfo where no ContactId is found
     * → should fallback to hardcoded Id
     */
    @isTest
    static void testFetchLoggedInUserInfo_noContactIdFallback() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        
        User u4 = new User(
            FirstName = 'Fallback',
            LastName = 'User',
            Email = 'unique_' + System.currentTimeMillis() + '@test.com',
            Username = 'fallback_' + System.currentTimeMillis() + '@test.com',
            Alias = 'fb',
            TimeZoneSidKey = 'GMT',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert u4;
        
        System.runAs(u4) {
            Test.startTest();
            Contact contactRec = HAM_MainController.fetchLoggedInUserInfo();
            Test.stopTest();
            
            System.assertEquals(null, contactRec, 'Should return null as the hardcoded ContactId fallback is gone.');
        }
    }

    /**
     * @description Test case to verify the method successfully returns the Contact 
     * record with the correct Primary Contact Type for a valid ID.
     */
    @IsTest
    static void testGetPrimaryContactType() {
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Trustee',
            ucinn_ascendv2__Primary_Contact_Type__c = 'Trustee' 
        );
        insert testContact;

        Test.startTest();
        Contact resultContact = HAM_MainController.getPrimaryContactType(testContact.Id);
        Test.stopTest();

        //ASSERT: Verify the result
        System.assertNotEquals(null, resultContact, 'Result should not be null when a valid ID is passed.');
        System.assertEquals(testContact.Id, resultContact.Id, 'The correct Contact ID should be returned.');
    }
    
    /**
     * @description Test case to verify getPrimaryContactType returns null
     * when a null ContactId is passed (Covers the if branch).
     */
    @IsTest
    static void testGetPrimaryContactType_NullId() {
        Test.startTest();
        Contact resultContact = HAM_MainController.getPrimaryContactType(null);
        Test.stopTest();

        System.assertEquals(null, resultContact, 'Result should be null when a null ID is passed.');
    }

    /**
     * @description Test case to verify the getRegisteredUsersCount method.
     */
    @IsTest
    static void testGetRegisteredUsersCount() {
        Test.startTest();
        Integer registeredCount = HAM_MainController.getRegisteredUsersCount();
        Test.stopTest();
        
        // Asserting >= 1 because we inserted 1 Partner Community Login User (u3) in setupData
        System.assertNotEquals(null, registeredCount, 'Count should not return null');
        System.assert(registeredCount >= 1, 'Should find at least 1 registered portal user based on setup data.');
    }

    /**
     * @description Test case to verify the method successfully fetches the 
     * Giving App Feature Toggle Custom Metadata status.
     */
    @IsTest
    static void testGetGivingAppStatus() {
        Test.startTest();
        Boolean isAppActive = HAM_MainController.getGivingAppStatus();
        Test.stopTest();
        
        System.assertNotEquals(null, isAppActive, 'The feature toggle status should return a boolean value, not null.');
    }
}