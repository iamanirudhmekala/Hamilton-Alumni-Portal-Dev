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
**/

@isTest
public class HAM_VolunteerOpportunityController_Test {
    
    @testSetup
    static void setup() {       
        // Create Account test data
        Account acc = new Account(Name = 'Test Account', Industry = 'Finance');
        insert acc;

        // Create Contact test data
        Contact con = new Contact(
            LastName = 'TestUser',
            Email = 'testvolunteer@example.com',
            HAM_LiveAlumni_LinkedIn_URL__c = 'https://linkedin.com/test',
            HAM_Profile_Picture_URL__c = 'https://profilepic.com/test.jpg',
            Constituent_Employer__c = acc.Id,
            Job_Title__c = 'Financial Analyst',
            ucinn_ascendv2__Preferred_Class_Year__c = '1979'
        );
        insert con;
        
        RecordType volunteerEngagementRT = [SELECT Id from RecordType where DeveloperName = 'Volunteer_Engagement'];
        
        // Create Users in Isolated Context
        Profile sysAdmin = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        Profile portalProfile = [SELECT Id FROM Profile WHERE Name LIKE '%Community%' LIMIT 1];
        Id roleId;
        try {
            roleId = [SELECT Id FROM UserRole WHERE DeveloperName = 'Portal_User' LIMIT 1].Id;
        } catch (Exception e) {
            UserRole role = new UserRole(Name = 'Portal_User_Role');
            insert role;
            roleId = role.Id;
        }
    
        // Create temporary system context user
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
     * @description Test method for getMyVolunteerActivities
     */
    @isTest
    static void getMyVolunteerActivitiesTestMethod() {
        Contact testContact = [SELECT Id FROM Contact WHERE Email = 'testvolunteer@example.com' LIMIT 1];
        
        Test.startTest();
        List<HAM_VolunteerOpportunityController.MyActivityWrapper> activities = 
            HAM_VolunteerOpportunityController.getMyVolunteerActivities(testContact.Id, null, null);
        Test.stopTest();
        
        System.assertNotEquals(null, activities, 'Activities list should not be null');
        System.assertEquals(2, activities.size(), 'Should return current and upcoming activities only');
        
        // Verify Record Type is correctly assigned
        Id volunteerRTId = [SELECT Id FROM RecordType 
                           WHERE SobjectType = 'ucinn_ascendv2__Involvement__c' 
                           AND DeveloperName = 'Volunteer_Engagement' 
                           LIMIT 1].Id;
        
        List<ucinn_ascendv2__Involvement__c> involvementsWithRT = [
            SELECT Id, RecordTypeId FROM ucinn_ascendv2__Involvement__c 
            WHERE ucinn_ascendv2__Contact__c = :testContact.Id 
            AND ucinn_ascendv2__End_Date__c = null
        ];
        
        // Check for current and upcoming activities
        Boolean hasCurrentActivity = false;
        Boolean hasUpcomingActivity = false;
        for(HAM_VolunteerOpportunityController.MyActivityWrapper act : activities) {
            if(act.computedTab == 'Current') hasCurrentActivity = true;
            if(act.computedTab == 'Upcoming') hasUpcomingActivity = true;
        }
        
        System.assert(hasCurrentActivity, 'Should have at least one current activity');
        System.assert(hasUpcomingActivity, 'Should have at least one upcoming activity');
    }
    
    /**
     * @description Test method for getPastActivityCount
     */
    @isTest
    static void getPastActivityCountTestMethod() {
        Contact testContact = [SELECT Id FROM Contact WHERE Email = 'testvolunteer@example.com' LIMIT 1];
        
        Test.startTest();
        Integer count = HAM_VolunteerOpportunityController.getPastActivityCount(testContact.Id, null, null);
        Test.stopTest();
        
        System.assertNotEquals(null, count, 'Count should not be null');
        System.assertEquals(11, count, 'Should count all past activities');
    }
    
    /**
     * @description Test method for getPastVolunteerActivities with pagination
     */
    @isTest
    static void getPastVolunteerActivitiesTestMethod() {
        Contact testContact = [SELECT Id FROM Contact WHERE Email = 'testvolunteer@example.com' LIMIT 1];
        
        Test.startTest();
        // Test first page
        List<HAM_VolunteerOpportunityController.MyActivityWrapper> page1 = 
            HAM_VolunteerOpportunityController.getPastVolunteerActivities(5, 0, testContact.Id, null, null);
        
        // Test second page
        List<HAM_VolunteerOpportunityController.MyActivityWrapper> page2 = 
            HAM_VolunteerOpportunityController.getPastVolunteerActivities(5, 5, testContact.Id, null, null);
        Test.stopTest();
        
        System.assertEquals(5, page1.size(), 'First page should have 5 records');
        System.assertEquals(5, page2.size(), 'Second page should have 5 records');
        System.assertNotEquals(page1[0].id, page2[0].id, 'Pages should contain different records');
        
        // Verify all activities are marked as Past and have correct Record Type
        Id volunteerRTId = [SELECT Id FROM RecordType 
                           WHERE SobjectType = 'ucinn_ascendv2__Involvement__c' 
                           AND DeveloperName = 'Volunteer_Engagement' 
                           LIMIT 1].Id;
        
        for(HAM_VolunteerOpportunityController.MyActivityWrapper act : page1) {
            System.assertEquals('Past', act.computedTab, 'Activity should be marked as Past');
            
            // Verify Record Type
            ucinn_ascendv2__Involvement__c inv = [SELECT RecordTypeId FROM ucinn_ascendv2__Involvement__c WHERE Id = :act.id];
            System.assertEquals(volunteerRTId, inv.RecordTypeId, 'Record Type should be Volunteer Engagement');
        }
    }
    
    /**
     * @description Test method for getPastVolunteerActivities with date filtering
     */
    @isTest
    static void getPastVolunteerActivitiesWithDateFilterTestMethod() {
        Contact testContact = [SELECT Id FROM Contact WHERE Email = 'testvolunteer@example.com' LIMIT 1];
        Date fromDate = Date.today().addDays(-100);
        Date toDate = Date.today().addDays(-50);
        
        Test.startTest();
        List<HAM_VolunteerOpportunityController.MyActivityWrapper> filteredActivities = 
            HAM_VolunteerOpportunityController.getPastVolunteerActivities(10, 0, testContact.Id, fromDate, toDate);
        Test.stopTest();
        
        System.assertNotEquals(null, filteredActivities, 'Filtered activities should not be null');
        // Verify activities fall within date range
        for(HAM_VolunteerOpportunityController.MyActivityWrapper act : filteredActivities) {
            System.assert(act.startDate >= fromDate && act.startDate <= toDate, 
                         'Activity start date should be within filter range');
        }
    }
    
    /**
     * @description Test method for error handling with invalid contact ID
     */
    @isTest
    static void errorHandlingTestMethod() {
        Test.startTest();
        List<HAM_VolunteerOpportunityController.OpportunityWrapper> opps = 
            HAM_VolunteerOpportunityController.getOpportunities(0, 0, null);
        
        List<HAM_VolunteerOpportunityController.MyActivityWrapper> activities = 
            HAM_VolunteerOpportunityController.getMyVolunteerActivities(null, null, null);
        
        Integer count = HAM_VolunteerOpportunityController.getPastActivityCount(null, null, null);
        Test.stopTest();
        
        System.assertNotEquals(null, opps, 'Should return empty list, not null');
        System.assertNotEquals(null, activities, 'Should return empty list, not null');
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
     * @description Tests retrieval and count of Committee/Board activities.
     */
    @isTest
    static void testCommitteeActivities() {
        Contact con = [SELECT Id FROM Contact WHERE Email = 'testvolunteer@example.com' LIMIT 1];

        Test.startTest();
        Integer count = HAM_VolunteerOpportunityController.getCommitteesCount(con.Id);
        List<HAM_VolunteerOpportunityController.MyActivityWrapper> committees = 
            HAM_VolunteerOpportunityController.getCommitteeActivities(10, 0, con.Id);
        Test.stopTest();

        System.assertEquals(5, count, 'Should count 3 Committees and 2 Boards.');
        System.assertEquals(5, committees.size(), 'Should return 5 committee wrappers.');
        System.assertEquals('Committees', committees[0].computedTab, 'Computed tab should be Committees.');
    }

    /**
     * @description Validates Committee pagination using limit and offset.
     */
    @isTest
    static void testCommitteePagination() {
        Contact con = [SELECT Id FROM Contact WHERE Email = 'testvolunteer@example.com' LIMIT 1];

        Test.startTest();
        List<HAM_VolunteerOpportunityController.MyActivityWrapper> paged = 
            HAM_VolunteerOpportunityController.getCommitteeActivities(2, 0, con.Id);
        Test.stopTest();

        System.assertEquals(2, paged.size(), 'Should respect the limit of 2.');
    }

}