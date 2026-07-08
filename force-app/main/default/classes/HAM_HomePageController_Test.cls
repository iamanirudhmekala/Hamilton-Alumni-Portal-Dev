/**
* @File Name : HAM_HomePageController_Test.cls
* @Description : This class is used to test HAM_HomePageController class.
* @Author : Cube84 - Asheesh
* @Last Modified By : Asheesh
* @Last Modified On : Dec 22, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | Dec 22, 2025 |  Asheesh | Initial Version
**/
@SuppressWarnings('PMD.NoTrailingWhitespace, PMD.ExcessiveClassLength,PMD.ApexDoc,PMD.DebugsShouldUseLoggingLevel,PMD.ApexUnitTestClassShouldHaveRunAs, PME.ExcessivePublicCount, PMD.ApexCRUDViolation, PMD.EmptyIfStmt, PMD.EmptyStatementBlock, PMD.AvoidNonRestrictiveQueries, PMD.CyclomaticComplexity, PMD.CognitiveComplexity, PMD.NcssCount, PMD.NcssTypeCount, PMD.DetectCopyPasteForApex, PMD.LocalVariableNamingConventions, PMD.ExcessiveParameterList, PMD.ApexSOQLInjection, PMD.AvoidDeeplyNestedIfStmts, PMD.AvoidDebugStatements, PMD.StdCyclomaticComplexity, PMD.NcssMethodCount')
@isTest
public class HAM_HomePageController_Test {
    
    @testSetup
    static void setup() {       
        // Create Account test data
        Account acc = new Account(Name = 'Test Account', Industry = 'Finance');
        insert acc;

        // Create Contact test data
        Contact con = new Contact(
            LastName = 'TestUser',
            Email = 'test@example.com',
            //HAM_Name_w_Suffix__c = 'Test Name',
            HAM_LiveAlumni_LinkedIn_URL__c = 'https://linkedin.com/test',
            HAM_Profile_Picture_URL__c = 'https://profilepic.com/test.jpg',
            Constituent_Employer__c = acc.Id,
            HAM_JBA__c = true,
            HAM_Couper_Guild__c = true,
            Job_Title__c = 'Financial Analyst',
            HAM_Current_Chapters__c = 'Cincinnati Chapter; New York Chapter',
            ucinn_ascendv2__Preferred_Class_Year__c = '1979'
        );
        insert con;
        
        // ---- Step 2: Create Users in Isolated Context ----
        Profile sysAdmin = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        Profile portalProfile = [SELECT Id FROM Profile WHERE Name LIKE '%Community%' LIMIT 1];
        Id roleId;
        try {
            roleId = [SELECT Id FROM UserRole WHERE DeveloperName = 'Portal_User' LIMIT 1].Id;
        } catch (Exception e) {
            // fallback if not found
            UserRole role = new UserRole(Name = 'Portal_User_Role');
            insert role;
            roleId = role.Id;
        }
    
        // Create a temporary system context user to own the next runAs
        User tempSysUser = new User(
            Alias = 'tempsys',
            Email = 'tempsys' + System.currentTimeMillis() + '@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'TempSys',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = sysAdmin.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'tempsys' + System.currentTimeMillis() + '@test.com'
        );
        insert tempSysUser;
    
        System.runAs(tempSysUser) {
            // Account Owner
            User acctOwner = new User(
                Alias = 'acctown',
                Email = 'acctown' + System.currentTimeMillis() + '@test.com',
                EmailEncodingKey = 'UTF-8',
                LastName = 'AcctOwner',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                ProfileId = sysAdmin.Id,
                TimeZoneSidKey = 'America/Los_Angeles',
                UserRoleId = roleId,
                UserName = 'acctown' + System.currentTimeMillis() + '@test.com'
            );
            insert acctOwner;
    
           
    
            // Portal user (linked to Contact)
            User portalUser = new User(
                Alias = 'testuser',
                Email = 'testuser' + System.currentTimeMillis() + '@test.com',
                EmailEncodingKey = 'UTF-8',
                LastName = 'Testing',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                ProfileId = portalProfile.Id,
                TimeZoneSidKey = 'America/Los_Angeles',
                UserName = 'testuser' + System.currentTimeMillis() + '@test.com',
                ContactId = con.Id
            );
            insert portalUser;
        }
    }
    
    /*
    * @description: Test method to test getNewsConfig method and subsequent private method getCustomFieldValue.
    */
	@isTest
    static void getNewsConfigTestMethod() {
        Test.startTest();
		Contact con = [Select Id,Name,Email from Contact Where Email = 'test@example.com'];
		HAM_HomePageController.ComponentConfigData componentConfigData = HAM_HomePageController.getNewsConfig('NewsFeedLWC');
        //HAM_HomePageController.ComponentConfigData emptyComponentConfigData = HAM_HomePageController.getNewsConfig('');
        Test.stopTest();

        System.assertNotEquals(null, componentConfigData, 'ComponentConfigData should not be null');
        System.assertNotEquals(null, componentConfigData.displayFields, 'Display fields should not be null');
        System.assert(componentConfigData.displayFields.size() > 0, 'Display fields should have data');
    }
    
    /*
    * @description: Test method to test getGalleryConfig method and subsequent private method getCustomFieldValue.
    */
	@isTest
    static void getGalleryConfigTestMethod() {
        Test.startTest();
		Contact con = [Select Id,Name,Email from Contact Where Email = 'test@example.com'];
		HAM_HomePageController.ComponentConfigData componentConfigData = HAM_HomePageController.getGalleryConfig('GalleryGridLWC');
        //HAM_HomePageController.ComponentConfigData emptyComponentConfigData = HAM_HomePageController.getNewsConfig('');
        Test.stopTest();

        System.assertNotEquals(null, componentConfigData, 'ComponentConfigData should not be null');
        System.assertNotEquals(null, componentConfigData.displayFields, 'Display fields should not be null');
        System.assert(componentConfigData.displayFields.size() > 0, 'Display fields should have data');
    }
    
    /*
    * @description: Test method to test getGivingDayConfig method and subsequent private method getCustomFieldValue.
    */
	@isTest
    static void getGivingDayConfigTestMethod() {
        Test.startTest();
		Contact con = [Select Id,Name,Email from Contact Where Email = 'test@example.com'];
		HAM_HomePageController.ComponentConfigData componentConfigData = HAM_HomePageController.getGivingDayConfig('GivingDayComponent');
        //HAM_HomePageController.ComponentConfigData emptyComponentConfigData = HAM_HomePageController.getNewsConfig('');
        Test.stopTest();

        System.assertNotEquals(null, componentConfigData, 'ComponentConfigData should not be null');
        System.assertNotEquals(null, componentConfigData.displayFields, 'Display fields should not be null');
        System.assert(componentConfigData.displayFields.size() > 0, 'Display fields should have data');
    }
    
    /*
    * @description: Test method to test getEventsConfig method and subsequent private method getCustomFieldValue.
    */
	@isTest
    static void getEventsConfigTestMethod() {
        Test.startTest();
		Contact con = [Select Id,Name,Email from Contact Where Email = 'test@example.com'];
		HAM_HomePageController.ComponentConfigData componentConfigData = HAM_HomePageController.getEventsConfig('EventsListLWC');
        //HAM_HomePageController.ComponentConfigData emptyComponentConfigData = HAM_HomePageController.getNewsConfig('');
        Test.stopTest();

        System.assertNotEquals(null, componentConfigData, 'ComponentConfigData should not be null');
        System.assertNotEquals(null, componentConfigData.displayFields, 'Display fields should not be null');
        System.assert(componentConfigData.displayFields.size() > 0, 'Display fields should have data');
    }
    
    /*
    * @description: Test method to test getEventsConfig method and subsequent private method getCustomFieldValue.
    */
	@isTest
        static void getVolunteerConfigTestMethod() {
            Test.startTest();
            Contact con = [
                SELECT Id, Name, Email 
                FROM Contact 
                WHERE Email = 'test@example.com' 
                LIMIT 1
            ];
        
            HAM_HomePageController.ComponentConfigData componentConfigData =
                HAM_HomePageController.getVolunteerConfig('VolunterOppLWC');
            Test.stopTest();
        
            System.assertNotEquals(
                null,
                componentConfigData,
                'ComponentConfigData should not be null'
            );
        
            System.assertNotEquals(
                null,
                componentConfigData.records,
                'Volunteer opportunities list should not be null'
            );
        
            System.assertNotEquals(
                null,
                componentConfigData.interestIdMap,
                'InterestIdMap should not be null'
            );
        
            // Optional but safe consistency check
            if (!componentConfigData.records.isEmpty()) {
                for (SObject opp : componentConfigData.records) {
                    System.assert(
                        componentConfigData.interestIdMap.containsKey(opp.Id),
                        'Each opportunity must have an interest config'
                    );
                }
            }
        }
            
    /*
    * @description: Test method to test getContactAndPhilanthropyDataForHome method and subsequent private method getCustomFieldValue.
    */
	@isTest
    static void getContactAndPhilanthropyDataForHomeTestMethod() {
        // Get the test user and contact
        User testUser = [SELECT Id, ContactId FROM User WHERE Alias = 'testuser' LIMIT 1];
        Contact testContact = [SELECT Id,HAM_Name_w_Suffix__c FROM Contact WHERE LastName = 'TestUser' LIMIT 1];

        Test.startTest();
        // Call the main method with the contact's ID
        HAM_MyImpactController.MyImpactDataWrapper result = HAM_HomePageController.getContactAndPhilanthropyDataForHome(testUser.ContactId);
        HAM_MyImpactController.MyImpactDataWrapper failedResult = HAM_HomePageController.getContactAndPhilanthropyDataForHome('');
        Test.stopTest();
        System.debug('result:'+failedResult.error);
        // Assert the results
        System.assertNotEquals(null, result, 'Response wrapper should not be null.');
        System.assertNotEquals(null, result.contact, 'ContactInfo wrapper should not be null.');
        System.assertEquals(testContact.Id, result.contact.Id, 'Contact Id should match.');
    }
    
    
     /*
    * @description: Test method to test fetchLoggedInUserInfo method and subsequent private method getCustomFieldValue.
    */
    @isTest
    static void fetchLoggedInUserInfoTestMethod() {
        User portalUser = [
            SELECT Id 
            FROM User 
            WHERE Alias = 'testuser' 
            LIMIT 1
        ];
    
        System.runAs(portalUser) {
            Test.startTest();
            String userContactId = HAM_HomePageController.fetchLoggedInUserInfo();
            Test.stopTest();
    
            System.assertNotEquals(
                null,
                userContactId,
                'Contact Id should be returned for portal user'
            );
        }
    }
    
    
}