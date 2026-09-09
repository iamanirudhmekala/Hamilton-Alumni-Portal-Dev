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
        // ---- Step 1: Account owner with a role ----
        // A portal user can only be created when the owner of its contact's account holds a
        // UserRole, so the account and contact are created by that user rather than by
        // whoever happens to be running the test.
        Profile sysAdmin = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        Profile portalProfile = getPortalProfile();

        Id roleId;
        try {
            roleId = [SELECT Id FROM UserRole WHERE DeveloperName = 'Portal_User' LIMIT 1].Id;
        } catch (Exception e) {
            // fallback if not found
            UserRole role = new UserRole(Name = 'Portal_User_Role');
            insert role;
            roleId = role.Id;
        }

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

        // ---- Step 2: Data and portal user, owned by the role-bearing user ----
        System.runAs(acctOwner) {

            // Create Account test data
            Account acc = new Account(Name = 'Test Account', Industry = 'Finance');
            insert acc;

            // Create Contact test data
            Contact con = new Contact(
                LastName = 'TestUser',
                Email = 'test@example.com',
                //HAM_Name_w_Suffix__c = 'Test Name',
                AccountId = acc.Id,
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

    /**
     * @description Resolves a portal profile by UserType, which holds regardless of how the
     * org names its community profiles, falling back to a name match.
     */
    private static Profile getPortalProfile() {
        List<Profile> portalProfiles = [
            SELECT Id FROM Profile
            WHERE UserType IN ('PowerPartner', 'CspLitePortal', 'PowerCustomerSuccess')
            LIMIT 1
        ];

        return portalProfiles.isEmpty()
            ? [SELECT Id FROM Profile WHERE Name LIKE '%Community%' LIMIT 1]
            : portalProfiles[0];
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
    
    

    /*
    * @description: Redirection card thumbnails — Directory takes the latest connection's
    * photo, News the first article shown, Gallery the first non-video listing, and Webcam
    * the resource's image plus its click-through link.
    */
    @isTest
    static void getRedirectionCardImagesTestMethod() {
        Contact portalContact = [SELECT Id FROM Contact WHERE Email = 'test@example.com' LIMIT 1];

        // An older connection and a newer one — only the newer photo should surface
        Contact olderConnection = new Contact(
            LastName = 'OlderConnection',
            HAM_Is_Active__c = true,
            HAM_Profile_Picture_URL__c = 'https://images.test/older-connection.jpg'
        );
        Contact latestConnection = new Contact(
            LastName = 'LatestConnection',
            HAM_Is_Active__c = true,
            HAM_Profile_Picture_URL__c = 'https://images.test/latest-connection.jpg'
        );
        insert new List<Contact>{ olderConnection, latestConnection };

        HAM_Connection__c olderLink = new HAM_Connection__c(
            HAM_Portal_User__c        = portalContact.Id,
            HAM_Linked_Constituent__c = olderConnection.Id,
            HAM_Is_Connected__c       = true,
            HAM_Is_Blocked__c         = false
        );
        HAM_Connection__c latestLink = new HAM_Connection__c(
            HAM_Portal_User__c        = portalContact.Id,
            HAM_Linked_Constituent__c = latestConnection.Id,
            HAM_Is_Connected__c       = true,
            HAM_Is_Blocked__c         = false
        );
        insert new List<HAM_Connection__c>{ olderLink, latestLink };

        // Records inserted in one transaction share a CreatedDate, so age them apart
        // to prove the card really is picking the most recent connection.
        Test.setCreatedDate(olderLink.Id, DateTime.now().addDays(-10));
        Test.setCreatedDate(latestLink.Id, DateTime.now().addDays(-1));

        insert new List<HAM_Listing__c>{
            new HAM_Listing__c(
                HAM_Title__c        = 'Latest News Article',
                HAM_Category__c     = 'News',
                HAM_Is_Active__c    = true,
                HAM_Is_Trending__c  = true,
                HAM_Display_Order__c = 1,
                HAM_Image_URL__c    = 'https://images.test/news.jpg'
            ),
            // Gallery leads with a video, which the card has to step over
            new HAM_Listing__c(
                HAM_Title__c            = 'Gallery Video',
                HAM_Category__c         = 'Homepage image',
                HAM_Is_Active__c        = true,
                HAM_Is_Trending__c      = true,
                HAM_Is_Video_Content__c = true,
                HAM_Display_Order__c    = 1,
                HAM_Image_URL__c        = 'https://images.test/gallery-video.mp4'
            ),
            new HAM_Listing__c(
                HAM_Title__c            = 'Gallery Photo',
                HAM_Category__c         = 'Homepage image',
                HAM_Is_Active__c        = true,
                HAM_Is_Trending__c      = true,
                HAM_Is_Video_Content__c = false,
                HAM_Display_Order__c    = 2,
                HAM_Image_URL__c        = 'https://images.test/gallery-photo.jpg'
            ),
            new HAM_Listing__c(
                HAM_Title__c       = 'Webcam Live View',
                HAM_Category__c    = 'Resources',
                HAM_Is_Active__c   = true,
                HAM_Image_URL__c   = 'https://images.test/webcam.jpg',
                HAM_Actual_link__c = 'https://webcam.test/live'
            )
        };

        Test.startTest();
        Map<String, HAM_HomePageController.RedirectionCardImage> cardImages =
            HAM_HomePageController.getRedirectionCardImages(portalContact.Id);
        Test.stopTest();

        System.assertNotEquals(null, cardImages, 'Card image map should not be null');

        System.assert(cardImages.containsKey('directory'), 'Directory card should resolve');
        System.assertEquals(
            'https://images.test/latest-connection.jpg',
            cardImages.get('directory').imageUrl,
            'Directory shows the most recently made connection'
        );

        System.assert(cardImages.containsKey('news'), 'News card should resolve');
        System.assertEquals(
            'https://images.test/news.jpg',
            cardImages.get('news').imageUrl,
            'News shows the first article the widget lists'
        );

        System.assert(cardImages.containsKey('gallery'), 'Gallery card should resolve');
        System.assertEquals(
            'https://images.test/gallery-photo.jpg',
            cardImages.get('gallery').imageUrl,
            'Gallery skips video entries to reach a real image'
        );

        System.assert(cardImages.containsKey('webcam'), 'Webcam card should resolve');
        System.assertEquals(
            'https://images.test/webcam.jpg',
            cardImages.get('webcam').imageUrl,
            'Webcam shows the resource thumbnail'
        );
        System.assertEquals(
            'https://webcam.test/live',
            cardImages.get('webcam').linkUrl,
            'Webcam carries the resource link for click-through'
        );

        System.assert(!cardImages.containsKey('impact'), 'My Impact has no rule and stays static');
        System.assert(!cardImages.containsKey('trivia'), 'Trivia has no rule and stays static');
    }

    /*
    * @description: A connection whose constituent has no photo is treated the same as
    * having no connections at all — the Directory card keeps its production image.
    */
    @isTest
    static void getRedirectionCardImagesConnectionWithoutPhotoTestMethod() {
        Contact portalContact = [SELECT Id FROM Contact WHERE Email = 'test@example.com' LIMIT 1];

        Contact photolessConnection = new Contact(
            LastName = 'PhotolessConnection',
            HAM_Is_Active__c = true
            // HAM_Profile_Picture_URL__c intentionally blank
        );
        insert photolessConnection;

        insert new HAM_Connection__c(
            HAM_Portal_User__c        = portalContact.Id,
            HAM_Linked_Constituent__c = photolessConnection.Id,
            HAM_Is_Connected__c       = true,
            HAM_Is_Blocked__c         = false
        );

        Test.startTest();
        Map<String, HAM_HomePageController.RedirectionCardImage> cardImages =
            HAM_HomePageController.getRedirectionCardImages(portalContact.Id);
        Test.stopTest();

        System.assert(!cardImages.containsKey('directory'),
            'A connection without a photo leaves the Directory card on its static image');
    }

    /*
    * @description: No contact id — nothing to resolve, and nothing blows up.
    */
    @isTest
    static void getRedirectionCardImagesBlankContactTestMethod() {
        Test.startTest();
        Map<String, HAM_HomePageController.RedirectionCardImage> cardImages =
            HAM_HomePageController.getRedirectionCardImages('');
        Test.stopTest();

        System.assertNotEquals(null, cardImages, 'An empty map is returned, never null');
        System.assertEquals(0, cardImages.size(), 'A blank contact id resolves no cards');
    }
}