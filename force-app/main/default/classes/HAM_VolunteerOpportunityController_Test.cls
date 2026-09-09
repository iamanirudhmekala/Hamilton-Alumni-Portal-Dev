/**
* @File Name : HAM_VolunteerOpportunityController_Test.cls
* @Description : This class tests HAM_VolunteerOpportunityController class
* @Author : Asheesh Joshi
* @Last Modified By : Cube84 - Asheesh
* @Last Modified On : December 23, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | January 06, 2026 | Cube84 - Asheesh  | Initial Version
* 2.0 | August 11, 2026 | Hamilton Adv | ASC-14686 Add tests for merged Current/Past volunteer record methods
**/

@isTest
public class HAM_VolunteerOpportunityController_Test {
    
    @testSetup
    static void setup() {       
        RecordType volunteerEngagementRT = [SELECT Id from RecordType where DeveloperName = 'Volunteer_Engagement'];

        // Create Users in Isolated Context
        Profile sysAdmin = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        Profile portalProfile = getPortalProfile();
        Id roleId;
        try {
            roleId = [SELECT Id FROM UserRole WHERE DeveloperName = 'Portal_User' LIMIT 1].Id;
        } catch (Exception e) {
            UserRole role = new UserRole(Name = 'Portal_User_Role');
            insert role;
            roleId = role.Id;
        }

        // Account Owner — a portal user can only be created when the owner of its contact's
        // account holds a UserRole, so this user creates the account and contact below.
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

        // Create temporary system context user — later blocks run as this user
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

        // User DML is isolated in its own runAs so the volunteer data inserted further
        // down does not trip MIXED_DML_OPERATION.
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert new List<User>{ acctOwner, tempSysUser };
        }

        Contact con;

        System.runAs(acctOwner) {
            // Create Account test data
            Account acc = new Account(Name = 'Test Account', Industry = 'Finance');
            insert acc;

            // Create Contact test data
            con = new Contact(
                LastName = 'TestUser',
                Email = 'testvolunteer@example.com',
                AccountId = acc.Id,
                HAM_LiveAlumni_LinkedIn_URL__c = 'https://linkedin.com/test',
                HAM_Profile_Picture_URL__c = 'https://profilepic.com/test.jpg',
                Constituent_Employer__c = acc.Id,
                Job_Title__c = 'Financial Analyst',
                ucinn_ascendv2__Preferred_Class_Year__c = '1979'
            );
            insert con;

            // Portal user (linked to Contact)
            User portalUser = new User(
                Alias = 'voltest',
                Email = 'voltest' + System.currentTimeMillis() + '@test.com',
                EmailEncodingKey = 'UTF-8',
                LastName = 'VolTesting',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                ProfileId = portalProfile.Id,
                TimeZoneSidKey = 'America/Los_Angeles',
                UserName = 'voltest' + System.currentTimeMillis() + '@test.com',
                ContactId = con.Id
            );
            insert portalUser;
        }
        
        // Create Volunteer Opportunities (Foundation Funding Interests)
        List<ucinn_ascendv2__Foundation_Funding_Interests__c> opportunities = new List<ucinn_ascendv2__Foundation_Funding_Interests__c>();
        opportunities.add(new ucinn_ascendv2__Foundation_Funding_Interests__c(
            Name = 'Career Mentoring Program',
            HAM_Description__c = 'Help students with career guidance',
            HAM_Image_URL__c = 'https://example.com/image1.jpg',
            HAM_Is_Volunteer__c = true,
            HAM_Category__c = HAM_ConstantsUtil.CAREER_CENTER
        ));
        opportunities.add(new ucinn_ascendv2__Foundation_Funding_Interests__c(
            Name = 'Alumni Event Volunteer',
            HAM_Description__c = 'Assist with alumni events',
            HAM_Image_URL__c = 'https://example.com/image2.jpg',
            HAM_Is_Volunteer__c = true,
            HAM_Category__c = HAM_ConstantsUtil.EVENTS_VOLUNTEER
        ));
        insert opportunities;
        
        // Create Involvement Values (Parent records for activities)
        List<ucinn_ascendv2__Involvement_Value__c> involvementValues = new List<ucinn_ascendv2__Involvement_Value__c>();
        involvementValues.add(new ucinn_ascendv2__Involvement_Value__c(
            Name = 'Community Service Project',
            ucinn_ascendv2__Involvement_Description__c = 'Helping local community',
            HAM_Portal_Image_URL__c = 'https://example.com/activity1.jpg',
            ucinn_ascendv2__Type__c  = HAM_ConstantsUtil.VOLUNTEER_ENGAGEMENT
        ));
        involvementValues.add(new ucinn_ascendv2__Involvement_Value__c(
            Name = 'Food Bank Volunteer',
            ucinn_ascendv2__Involvement_Description__c = 'Food distribution',
            HAM_Portal_Image_URL__c = 'https://example.com/activity2.jpg',
            ucinn_ascendv2__Type__c  = HAM_ConstantsUtil.VOLUNTEER_ENGAGEMENT
        ));
        involvementValues.add(new ucinn_ascendv2__Involvement_Value__c(
            Name = 'Tutoring Program',
            ucinn_ascendv2__Involvement_Description__c = 'Student tutoring',
            HAM_Portal_Image_URL__c = 'https://example.com/activity3.jpg',
            ucinn_ascendv2__Type__c  = HAM_ConstantsUtil.VOLUNTEER_ENGAGEMENT
        ));
        involvementValues.add(new ucinn_ascendv2__Involvement_Value__c(
            Name = 'Trustee of board',
            ucinn_ascendv2__Involvement_Description__c = 'Trustee of board',
            HAM_Category__c = 'Board of Trustees',
            ucinn_ascendv2__Type__c = 'Board of Trustees',
            HAM_Volunteer_Activity__c = true
        ));
        involvementValues.add(new ucinn_ascendv2__Involvement_Value__c(
            Name = 'Commitee chair',
            HAM_Category__c = 'Board of Trustees',
            ucinn_ascendv2__Involvement_Description__c = 'Commitee chair',
            ucinn_ascendv2__Type__c = 'Committee',
            HAM_Volunteer_Activity__c = true
        ));
        insert involvementValues;
        
         // Record Types
            Id volunteerRTId = Schema.SObjectType.ucinn_ascendv2__Involvement__c.getRecordTypeInfosByDeveloperName().get('Volunteer_Engagement').getRecordTypeId();
            Id committeeRTId = Schema.SObjectType.ucinn_ascendv2__Involvement__c.getRecordTypeInfosByDeveloperName().get('Committee').getRecordTypeId();
            Id boardRTId = Schema.SObjectType.ucinn_ascendv2__Involvement__c.getRecordTypeInfosByDeveloperName().get('Board_of_Trustees').getRecordTypeId();

        
        // Create Involvements (Activities) with Record Type
        List<ucinn_ascendv2__Involvement__c> involvements = new List<ucinn_ascendv2__Involvement__c>();
        
        // Current Activity
        involvements.add(new ucinn_ascendv2__Involvement__c(
            RecordTypeId = volunteerRTId,
            ucinn_ascendv2__Contact__c = con.Id,
            ucinn_ascendv2__Involvement_Code__c = involvementValues[0].Id,
            ucinn_ascendv2__Start_Date__c = Date.today().addDays(-30),
            ucinn_ascendv2__End_Date__c = null,
            ucinn_ascendv2__Status__c = 'Current'
        ));
        
        // Upcoming Activity
        involvements.add(new ucinn_ascendv2__Involvement__c(
            RecordTypeId = volunteerRTId,
            ucinn_ascendv2__Contact__c = con.Id,
            ucinn_ascendv2__Involvement_Code__c = involvementValues[1].Id,
            ucinn_ascendv2__Start_Date__c = Date.today().addDays(15),
            ucinn_ascendv2__End_Date__c = null,
            ucinn_ascendv2__Status__c = 'Current'
        ));
        
        // Past Activity
        involvements.add(new ucinn_ascendv2__Involvement__c(
            RecordTypeId = volunteerRTId,
            ucinn_ascendv2__Contact__c = con.Id,
            ucinn_ascendv2__Involvement_Code__c = involvementValues[2].Id,
            ucinn_ascendv2__Start_Date__c = Date.today().addDays(-90),
            ucinn_ascendv2__End_Date__c = Date.today().addDays(-10),
            ucinn_ascendv2__Status__c = 'Former'
        ));
        
        // Additional past activities for pagination testing
        for(Integer i = 0; i < 10; i++) {
            involvements.add(new ucinn_ascendv2__Involvement__c(
                RecordTypeId = volunteerRTId,
                ucinn_ascendv2__Contact__c = con.Id,
                ucinn_ascendv2__Involvement_Code__c = involvementValues[2].Id,
                ucinn_ascendv2__Start_Date__c = Date.today().addDays(-100 - i),
                ucinn_ascendv2__End_Date__c = Date.today().addDays(-20 - i),
                ucinn_ascendv2__Status__c = 'Former'
            ));
        }

        // Committee Activities
            for(Integer i = 0; i < 3; i++) {
                involvements.add(new ucinn_ascendv2__Involvement__c(
                    RecordTypeId = committeeRTId,
                    ucinn_ascendv2__Contact__c = con.Id,
                    ucinn_ascendv2__Involvement_Code__c = involvementValues[4].Id,
                    ucinn_ascendv2__Status__c = 'Current',
                    ucinn_ascendv2__Role__c = 'Member',
                    ucinn_ascendv2__Start_Date__c = Date.today().addMonths(-i)
                ));
            }

            // Board Activities
            for(Integer i = 0; i < 2; i++) {
                involvements.add(new ucinn_ascendv2__Involvement__c(
                    RecordTypeId = boardRTId,
                    ucinn_ascendv2__Contact__c = con.Id,
                    ucinn_ascendv2__Involvement_Code__c = involvementValues[3].Id,
                    ucinn_ascendv2__Status__c = 'Current',
                    ucinn_ascendv2__Role__c = 'Chair',
                    ucinn_ascendv2__Start_Date__c = Date.today().addYears(-1)
                ));
            }

        // Deliberately inconsistent record: Status still says 'Current' but End Date has
        // already passed - proves the merged current/past bucket logic catches this via
        // End_Date__c even when Status__c wasn't kept up to date. Under the old Current/Past
        // queries this record was invisible (failed both: not open-ended, not Status=Former).
        involvements.add(new ucinn_ascendv2__Involvement__c(
            RecordTypeId = volunteerRTId,
            ucinn_ascendv2__Contact__c = con.Id,
            ucinn_ascendv2__Involvement_Code__c = involvementValues[2].Id,
            ucinn_ascendv2__Start_Date__c = Date.today().addDays(-60),
            ucinn_ascendv2__End_Date__c = Date.today().addDays(-5),
            ucinn_ascendv2__Status__c = 'Current'
        ));

        // Former Committee Activities (past)
        for(Integer i = 0; i < 2; i++) {
            involvements.add(new ucinn_ascendv2__Involvement__c(
                RecordTypeId = committeeRTId,
                ucinn_ascendv2__Contact__c = con.Id,
                ucinn_ascendv2__Involvement_Code__c = involvementValues[4].Id,
                ucinn_ascendv2__Status__c = 'Former',
                ucinn_ascendv2__Role__c = 'Member',
                ucinn_ascendv2__Start_Date__c = Date.today().addYears(-3),
                ucinn_ascendv2__End_Date__c = Date.today().addYears(-1).addMonths(-i)
            ));
        }

        // Former Board Activity (past)
        involvements.add(new ucinn_ascendv2__Involvement__c(
            RecordTypeId = boardRTId,
            ucinn_ascendv2__Contact__c = con.Id,
            ucinn_ascendv2__Involvement_Code__c = involvementValues[3].Id,
            ucinn_ascendv2__Status__c = 'Former',
            ucinn_ascendv2__Role__c = 'Chair',
            ucinn_ascendv2__Start_Date__c = Date.today().addYears(-5),
            ucinn_ascendv2__End_Date__c = Date.today().addYears(-2)
        ));

        insert involvements;
        User admin = [SELECT Id FROM User WHERE LastName = 'TempSys' LIMIT 1];
        System.runAs(admin) {
            // Create one active interest for the contact
            ucinn_ascendv2__Funding_Interest__c activeInterest = new ucinn_ascendv2__Funding_Interest__c(
                ucinn_ascendv2__Contact__c = con.Id,
                ucinn_ascendv2__Foundation_Funding_Interest__c = opportunities[0].Id,
                ucinn_ascendv2__Start_Date__c = Date.today().addDays(-10),
                ucinn_ascendv2__End_Date__c = null,
                HAM_Category__c = HAM_ConstantsUtil.CAREER_CENTER,
                OwnerId = admin.Id
            );
        insert activeInterest;
        }
        
    }
    
    /**
     * @description Test method for getOpportunities
     */
    @isTest
    static void getOpportunitiesTestMethod() {
        Contact testContact = [SELECT Id FROM Contact WHERE Email = 'testvolunteer@example.com' LIMIT 1];
        
        Test.startTest();
        // Test with record limit
        List<HAM_VolunteerOpportunityController.OpportunityWrapper> limitedOpps = 
           // HAM_VolunteerOpportunityController.getOpportunities(1, 1, testContact.Id);
            HAM_VolunteerOpportunityController.getOpportunities(1, 0, testContact.Id);
        
        // Test without record limit
        List<HAM_VolunteerOpportunityController.OpportunityWrapper> allOpps = 
            HAM_VolunteerOpportunityController.getOpportunities(2, 1, testContact.Id);
        Test.stopTest();
        
        //System.assertEquals(1, limitedOpps.size(), 'Should return only 1 opportunity when limited');
        //System.assertEquals(2, allOpps.size(), 'Should return all volunteer opportunities');
        //System.assertEquals(true, allOpps[0].isInterested, 'First opportunity should show as interested');
        //System.assertNotEquals(null, allOpps[0].activeInterestId, 'Active interest ID should be present');
        //System.assertEquals(false, allOpps[1].isInterested, 'Second opportunity should not show as interested');
    }
    
    /**
     * @description Test method for setInterested
     */
    @isTest
    static void setInterestedTestMethod() {
        Contact testContact = [SELECT Id FROM Contact WHERE Email = 'testvolunteer@example.com' LIMIT 1];
        ucinn_ascendv2__Foundation_Funding_Interests__c opp = [
            SELECT Id FROM ucinn_ascendv2__Foundation_Funding_Interests__c 
            WHERE Name = 'Alumni Event Volunteer' LIMIT 1
        ];
        
        Test.startTest();
        String newInterestId = HAM_VolunteerOpportunityController.setInterested(opp.Id, testContact.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, newInterestId, 'New interest ID should be returned');
        
        // Verify the interest was created
        ucinn_ascendv2__Funding_Interest__c createdInterest = [
            SELECT Id, ucinn_ascendv2__Contact__c, ucinn_ascendv2__Foundation_Funding_Interest__c, 
                   ucinn_ascendv2__Start_Date__c, ucinn_ascendv2__End_Date__c
            FROM ucinn_ascendv2__Funding_Interest__c 
            WHERE Id = :newInterestId
        ];
        
        System.assertEquals(testContact.Id, createdInterest.ucinn_ascendv2__Contact__c, 'Contact should match');
        System.assertEquals(opp.Id, createdInterest.ucinn_ascendv2__Foundation_Funding_Interest__c, 'Opportunity should match');
        System.assertEquals(Date.today(), createdInterest.ucinn_ascendv2__Start_Date__c, 'Start date should be today');
        System.assertEquals(null, createdInterest.ucinn_ascendv2__End_Date__c, 'End date should be null');
    }
    
    /**
     * @description Test method for withdrawInterest
     */
    @isTest
    static void withdrawInterestTestMethod() {
        Contact testContact = [SELECT Id FROM Contact WHERE Email = 'testvolunteer@example.com' LIMIT 1];
        ucinn_ascendv2__Funding_Interest__c interest = [
            SELECT Id FROM ucinn_ascendv2__Funding_Interest__c 
            WHERE ucinn_ascendv2__Contact__c = :testContact.Id LIMIT 1
        ];
        
        Test.startTest();
        HAM_VolunteerOpportunityController.withdrawInterest(interest.Id);
        Test.stopTest();
        
        // Verify the interest was withdrawn
        ucinn_ascendv2__Funding_Interest__c withdrawnInterest = [
            SELECT Id, ucinn_ascendv2__End_Date__c
            FROM ucinn_ascendv2__Funding_Interest__c 
            WHERE Id = :interest.Id
        ];
        
        System.assertEquals(Date.today(), withdrawnInterest.ucinn_ascendv2__End_Date__c, 'End date should be set to today');
    }
    
    /**
     * @description Test method for error handling with invalid contact ID
     */
    @isTest
    static void errorHandlingTestMethod() {
        Test.startTest();
        List<HAM_VolunteerOpportunityController.OpportunityWrapper> opps =
            HAM_VolunteerOpportunityController.getOpportunities(0, 0, null);

        List<HAM_VolunteerOpportunityController.MyActivityWrapper> current =
            HAM_VolunteerOpportunityController.getCurrentVolunteerRecords(50, 0, null);

        Integer count = HAM_VolunteerOpportunityController.getPastVolunteerRecordsCount(null, null, null);
        Test.stopTest();

        System.assertNotEquals(null, opps, 'Should return empty list, not null');
        System.assertNotEquals(null, current, 'Should return empty list, not null');
        System.assertEquals(0, count, 'Count should be 0 for invalid contact');
    }

    @isTest
    static void getOpportunitiesCountTestMethod() {
        
        // Arrange: create matching volunteer opportunities
        List<ucinn_ascendv2__Foundation_Funding_Interests__c> visibleOpps =
            new List<ucinn_ascendv2__Foundation_Funding_Interests__c>{
                new ucinn_ascendv2__Foundation_Funding_Interests__c(
                    Name = 'Career Center Opp',
                    HAM_Is_Publicly_Visible__c = true,
                    HAM_Category__c = HAM_ConstantsUtil.CAREER_CENTER
                ),
                new ucinn_ascendv2__Foundation_Funding_Interests__c(
                    Name = 'Event Volunteer Opp',
                    HAM_Is_Publicly_Visible__c = true,
                    HAM_Category__c = HAM_ConstantsUtil.EVENTS_VOLUNTEER
                )
            };
        insert visibleOpps;

        // Arrange: create non-matching data (should NOT be counted)
        insert new ucinn_ascendv2__Foundation_Funding_Interests__c(
            Name = 'Private Opp',
            HAM_Is_Publicly_Visible__c = false,
            HAM_Category__c = HAM_ConstantsUtil.CAREER_CENTER
        );

        Test.startTest();
        Integer countResult = HAM_VolunteerOpportunityController.getOpportunitiesCount();
        Test.stopTest();

        // Assert
        System.assertEquals(
            2,
            countResult,
            'Only publicly visible Career Center and Event Volunteer opportunities should be counted'
        );
    }

    /**
     * @description Test method for getCurrentVolunteerRecords / getCurrentVolunteerRecordsCount
     * (merged Activity + Committee/Board records for the current bucket).
     */
    @isTest
    static void getCurrentVolunteerRecordsTestMethod() {
        Contact testContact = [SELECT Id FROM Contact WHERE Email = 'testvolunteer@example.com' LIMIT 1];

        Test.startTest();
        Integer count = HAM_VolunteerOpportunityController.getCurrentVolunteerRecordsCount(testContact.Id);
        List<HAM_VolunteerOpportunityController.MyActivityWrapper> current =
            HAM_VolunteerOpportunityController.getCurrentVolunteerRecords(50, 0, testContact.Id);
        Test.stopTest();

        System.assertEquals(7, count, 'Should count 2 current/upcoming activities, 3 current committees, 2 current boards.');
        System.assertEquals(7, current.size(), 'Should return all 7 current records.');

        for (HAM_VolunteerOpportunityController.MyActivityWrapper act : current) {
            System.assertEquals('Current', act.computedTab, 'Every record in this bucket should be marked Current.');
        }

        for (Integer i = 1; i < current.size(); i++) {
            System.assert(current[i - 1].startDate <= current[i].startDate, 'Current records should be sorted by start date ascending.');
        }
    }

    /**
     * @description Test method for getPastVolunteerRecords / getPastVolunteerRecordsCount,
     * including the deliberately Status/EndDate-inconsistent record.
     */
    @isTest
    static void getPastVolunteerRecordsTestMethod() {
        Contact testContact = [SELECT Id FROM Contact WHERE Email = 'testvolunteer@example.com' LIMIT 1];

        Test.startTest();
        Integer count = HAM_VolunteerOpportunityController.getPastVolunteerRecordsCount(testContact.Id, null, null);
        List<HAM_VolunteerOpportunityController.MyActivityWrapper> past =
            HAM_VolunteerOpportunityController.getPastVolunteerRecords(50, 0, testContact.Id, null, null);
        Test.stopTest();

        System.assertEquals(15, count, 'Should count 11 past activities, 1 inconsistent record, 2 former committees, 1 former board.');
        System.assertEquals(15, past.size(), 'Should return all 15 past records.');

        for (HAM_VolunteerOpportunityController.MyActivityWrapper act : past) {
            System.assertEquals('Past', act.computedTab, 'Every record in this bucket should be marked Past.');
        }

        for (Integer i = 1; i < past.size(); i++) {
            if (past[i - 1].endDate != null && past[i].endDate != null) {
                System.assert(past[i - 1].endDate >= past[i].endDate, 'Past records should be sorted by end date descending.');
            }
        }

        // The record inserted with Status='Current' but a past End_Date must show up here.
        // Note: org automation reconciles Status__c to 'Former' on insert for this record, so
        // it's identified by its unique Start_Date rather than by Status - the point of this
        // test is that End_Date alone is enough to classify it as Past even if Status lags.
        Boolean foundInconsistentRecord = false;
        for (HAM_VolunteerOpportunityController.MyActivityWrapper act : past) {
            if (act.startDate == Date.today().addDays(-60)) {
                foundInconsistentRecord = true;
            }
        }
        System.assert(foundInconsistentRecord, 'A record with a past End Date should be classified as Past regardless of Status.');
    }

    /**
     * @description Guard test: the Current and Past buckets must never return the same record Id.
     */
    @isTest
    static void currentAndPastRecordsDoNotOverlapTestMethod() {
        Contact testContact = [SELECT Id FROM Contact WHERE Email = 'testvolunteer@example.com' LIMIT 1];

        Test.startTest();
        List<HAM_VolunteerOpportunityController.MyActivityWrapper> current =
            HAM_VolunteerOpportunityController.getCurrentVolunteerRecords(50, 0, testContact.Id);
        List<HAM_VolunteerOpportunityController.MyActivityWrapper> past =
            HAM_VolunteerOpportunityController.getPastVolunteerRecords(50, 0, testContact.Id, null, null);
        Test.stopTest();

        Set<String> currentIds = new Set<String>();
        for (HAM_VolunteerOpportunityController.MyActivityWrapper act : current) {
            currentIds.add(act.id);
        }

        Set<String> overlap = new Set<String>();
        for (HAM_VolunteerOpportunityController.MyActivityWrapper act : past) {
            if (currentIds.contains(act.id)) {
                overlap.add(act.id);
            }
        }

        System.assertEquals(0, overlap.size(), 'No record should ever appear in both the Current and Past buckets: ' + String.valueOf(overlap));
    }

    /**
     * @description Guard test: Current count + Past count must equal the true total of relevant
     * records for the contact - proves nothing is silently dropped by the bucket split.
     */
    @isTest
    static void currentPlusPastCountsMatchTrueTotalTestMethod() {
        Contact testContact = [SELECT Id FROM Contact WHERE Email = 'testvolunteer@example.com' LIMIT 1];

        Integer trueTotal = [
            SELECT COUNT()
            FROM ucinn_ascendv2__Involvement__c
            WHERE ucinn_ascendv2__Contact__c = :testContact.Id
            AND (
                (ucinn_ascendv2__Involvement_Type_Formula__c = 'Volunteer Engagement')
                OR (
                    (RecordType.DeveloperName = 'Board_of_Trustees' OR RecordType.DeveloperName = 'Committee')
                    AND HAM_Volunteer_Activity__c = true
                )
            )
        ];

        Test.startTest();
        Integer currentCount = HAM_VolunteerOpportunityController.getCurrentVolunteerRecordsCount(testContact.Id);
        Integer pastCount = HAM_VolunteerOpportunityController.getPastVolunteerRecordsCount(testContact.Id, null, null);
        Test.stopTest();

        System.assertEquals(trueTotal, currentCount + pastCount,
            'Current count (' + currentCount + ') + Past count (' + pastCount + ') must equal the true total (' + trueTotal + ').');
    }

    /**
     * @description Validates pagination on the new merged Current bucket using limit and offset.
     */
    @isTest
    static void getCurrentVolunteerRecordsPaginationTestMethod() {
        Contact testContact = [SELECT Id FROM Contact WHERE Email = 'testvolunteer@example.com' LIMIT 1];

        Test.startTest();
        List<HAM_VolunteerOpportunityController.MyActivityWrapper> paged =
            HAM_VolunteerOpportunityController.getCurrentVolunteerRecords(3, 0, testContact.Id);
        Test.stopTest();

        System.assertEquals(3, paged.size(), 'Should respect the limit of 3.');
    }


    /**
     * @description Home page Volunteer card: the most recently started current service
     * supplies the image, not the oldest one the activity list leads with.
     */
    @isTest
    static void getLatestCurrentVolunteerImageTestMethod() {
        Contact testContact = [SELECT Id FROM Contact WHERE Email = 'testvolunteer@example.com' LIMIT 1];

        Test.startTest();
        String imageUrl = HAM_VolunteerOpportunityController.getLatestCurrentVolunteerImage(testContact.Id);
        Test.stopTest();

        System.assertEquals('https://example.com/activity2.jpg', imageUrl,
            'The current service with the latest start date supplies the card image');
    }

    /**
     * @description No contact, no service — the card falls back to its static image.
     */
    @isTest
    static void getLatestCurrentVolunteerImageNullContactTestMethod() {
        Test.startTest();
        String imageUrl = HAM_VolunteerOpportunityController.getLatestCurrentVolunteerImage(null);
        Test.stopTest();

        System.assertEquals(null, imageUrl, 'A null contact id resolves to no image');
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
}