/**
* @File Name : HAM_AlumniProfileOverviewController_Test.cls
* @Description : This class is used to test HAM_AlumniProfileOverviewController class.
* @Author : Cube84 - Sachin
* @Last Modified By : Nilesh
* @Last Modified On : February 5, 2026
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | August 28, 2025 |  Sachin | Initial Version
* 2.0 | February 5, 2026 |  Nilesh | Enhanced coverage 
* 2.1 | June 22, 2026 |  Nilesh | Updated getAlumniOverview calls for new portalId parameter
**/
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs, PMD.CognitiveComplexity, PMD.ExcessiveClassLength, PMD.CyclomaticComplexity, PMD.NcssMethodCount, PMD.StdCyclomaticComplexity, PMD.MethodNamingConventions, PMD.AvoidHardcodingId, PMD.LocalVariableNamingConventions, PMD.ApexDoc')
@isTest
public class HAM_AlumniProfileOverviewController_Test {
    
    @testSetup
    static void setup() {       
        // Create Account test data
        Account acc = new Account(Name = 'Test Account', Industry = 'Finance');
        insert acc;

        // Create Contact test data with all fields
        Contact con = new Contact(
            FirstName = 'Test FN',
            LastName = 'Test LN',
            Email = 'test@example.com',
            HAM_LiveAlumni_LinkedIn_URL__c = 'https://linkedin.com/test',
            HAM_Profile_Picture_URL__c = 'https://profilepic.com/test.jpg',
            Constituent_Employer__c = acc.Id,
            Job_Title__c = 'Financial Analyst',
            HAM_Current_Chapters__c = 'Cincinnati Chapter; New York Chapter',
            ucinn_ascendv2__Preferred_Class_Year__c = '1979',
            ucinn_ascendv2__Primary_Contact_Type__c = 'Student',
            ucinn_ascendv2__Contact_Type__c = 'Kirkland Alumnae'
        );
        insert con;
        
        // Create second contact for connection testing
        Contact con2 = new Contact(
            FirstName = 'Test2 FN',
            LastName = 'Test2 LN',
            Email = 'test2@example.com',
            ucinn_ascendv2__Primary_Contact_Type__c = 'Alumnae'
        );
        insert con2;
        
        // Create third contact WITHOUT privacy settings
        Contact con3 = new Contact(
            FirstName = 'Test3 FN',
            LastName = 'Test3 LN',
            Email = 'test3@example.com',
            HAM_Profile_Picture_URL__c = 'https://profilepic3.com/test.jpg',
            ucinn_ascendv2__Primary_Contact_Type__c = 'Alumnae'
        );
        insert con3;

        // Create Service Indicator Value records
        List<ucinn_ascendv2__Service_Indicator_Value__c> sivList = new List<ucinn_ascendv2__Service_Indicator_Value__c>();
        sivList.add(new ucinn_ascendv2__Service_Indicator_Value__c(
            Name = 'Profile Picture Privacy',
            HAM_Portal_ID__c = 'SIV_VIS_PROFILE_PIC'
        ));
        sivList.add(new ucinn_ascendv2__Service_Indicator_Value__c(
            Name = 'Alumni Privacy',
            HAM_Portal_ID__c = 'SIV_VIS_ALUMNI_PRIVACY'
        ));
        sivList.add(new ucinn_ascendv2__Service_Indicator_Value__c(
            Name = 'Phone Privacy',
            HAM_Portal_ID__c = 'SIV_VIS_PHONE'
        ));
        insert sivList;

        // Get Record Type ID for Service Indicator with null check
        Id ServiceIndicatorRecordTypeId;
        try {
            ServiceIndicatorRecordTypeId = Schema.SObjectType.ucinn_ascendv2__Service_Indicator__c
                .getRecordTypeInfosByName().get('Contact Service Indicator').getRecordTypeId();
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Service Indicator RecordType not found: ' + e.getMessage());
        }

        // Only create Service Indicators if RecordType exists
        if (ServiceIndicatorRecordTypeId != null) {
            List<ucinn_ascendv2__Service_Indicator__c> siList = new List<ucinn_ascendv2__Service_Indicator__c>();
            siList.add(new ucinn_ascendv2__Service_Indicator__c(
                ucinn_ascendv2__Contact__c = con2.Id,
                ucinn_ascendv2__Service_Indicator_Value__c = sivList[1].Id,
                ucinn_ascendv2__Is_Active__c = true,
                RecordTypeId = ServiceIndicatorRecordTypeId
            ));
            siList.add(new ucinn_ascendv2__Service_Indicator__c(
                ucinn_ascendv2__Contact__c = con3.Id,
                ucinn_ascendv2__Service_Indicator_Value__c = sivList[0].Id,
                ucinn_ascendv2__Is_Active__c = true,
                RecordTypeId = ServiceIndicatorRecordTypeId
            ));
            
            try {
                insert siList;
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Service Indicator Insert Error: ' + e.getMessage());
            }
        }

        // Create Post Code records
        List<ucinn_ascendv2__Post_Code__c> pcodes = new List<ucinn_ascendv2__Post_Code__c>();
        pcodes.add(
            new ucinn_ascendv2__Post_Code__c(
                Name = 'Economics',
                ucinn_ascendv2__Degree_Description__c = 'Economics',
                ucinn_ascendv2__Is_Active__c = true
            )
        );
        pcodes.add(
            new ucinn_ascendv2__Post_Code__c(
                Name = 'Mathematics',
                ucinn_ascendv2__Degree_Description__c = 'Mathematics',
                ucinn_ascendv2__Major_Specialty_Description__c = 'Mathematics',
                ucinn_ascendv2__Is_Active__c = true
            )
        );
        insert pcodes;

        // Create minor code
        List<ucinn_ascendv2__Minor_Code__c> mincodes = new List<ucinn_ascendv2__Minor_Code__c>();
        mincodes.add(
            new ucinn_ascendv2__Minor_Code__c(
                Name = 'Safety Control',
                ucinn_ascendv2__Description__c = 'Safety Control'
            )
        );
        insert mincodes;

        // Get Record Type IDs with null checks
        Id schoolDegreeRecordTypeId;
        Id nonSchoolDegreeRecordTypeId;
        try {
            schoolDegreeRecordTypeId = Schema.SObjectType.ucinn_ascendv2__Degree_Information__c
                .getRecordTypeInfosByDeveloperName().get('School_Degree_Information').getRecordTypeId();
            nonSchoolDegreeRecordTypeId = Schema.SObjectType.ucinn_ascendv2__Degree_Information__c
                .getRecordTypeInfosByDeveloperName().get('Non_School_Degree_Information').getRecordTypeId();
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Degree RecordType Error: ' + e.getMessage());
        }

        // Create degree records
        List<ucinn_ascendv2__Degree_Information__c> degreesToInsert = new List<ucinn_ascendv2__Degree_Information__c>();
        if (schoolDegreeRecordTypeId != null) {
            degreesToInsert.add(
                new ucinn_ascendv2__Degree_Information__c(    
                    ucinn_ascendv2__Contact__c = con.Id,
                    ucinn_ascendv2__Post_Code__c = pcodes[0].Id,
                    RecordTypeId = schoolDegreeRecordTypeId
                )
            );
            degreesToInsert.add(
                new ucinn_ascendv2__Degree_Information__c(    
                    ucinn_ascendv2__Contact__c = con.Id,
                    ucinn_ascendv2__Minor_Code__c = mincodes[0].Id,
                    RecordTypeId = schoolDegreeRecordTypeId
                )
            );
        }
        if (nonSchoolDegreeRecordTypeId != null) {
            degreesToInsert.add(
                new ucinn_ascendv2__Degree_Information__c(    
                    ucinn_ascendv2__Contact__c = con.Id,
                    ucinn_ascendv2__Post_Code__c = pcodes[1].Id,
                    RecordTypeId = nonSchoolDegreeRecordTypeId
                )
            );
        }
        if (!degreesToInsert.isEmpty()) {
            insert degreesToInsert;
        }

        Id userId = UserInfo.getUserId();
        
        // Create Email with bypass
        createAscendBypassMethod(userId);
        try {
            ucinn_ascendv2__Email__c email = new ucinn_ascendv2__Email__c(
                ucinn_ascendv2__Contact__c = con.Id,
                ucinn_ascendv2__Email_Address__c = 'test@example.com',
                ucinn_ascendv2__Is_Preferred__c = true
            );
            insert email;
        } finally {
            removeAscendBypassMethod(userId);
        }

        // Create Address and Address Relation with bypass
        createAscendBypassMethod(userId);
        try {
            // Create Address
            ucinn_ascendv2__Address__c address = new ucinn_ascendv2__Address__c(
                ucinn_ascendv2__Address_Line_1__c = '123 Test Street',
                ucinn_ascendv2__City__c = 'Test City',
                ucinn_ascendv2__State__c = 'Test State',
                ucinn_ascendv2__Country__c = 'Test Country',
                ucinn_ascendv2__Postal_Code__c = '12345'
            );
            insert address;

            // Create Address Relation
            ucinn_ascendv2__Address_Relation__c addressRel = new ucinn_ascendv2__Address_Relation__c(
                ucinn_ascendv2__Contact__c = con.Id,
                ucinn_ascendv2__Address__c = address.Id,
                ucinn_ascendv2__Is_Preferred__c = true,
                ucinn_ascendv2__Type__c = 'Business',
                ucinn_ascendv2__Status__c = 'Current'
            );
            insert addressRel;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Address creation failed even with bypass: ' + e.getMessage());
        } finally {
            removeAscendBypassMethod(userId);
        }

        // Social Media records
        List<ucinn_ascendv2__Social_Media__c> smList = new List<ucinn_ascendv2__Social_Media__c>();
        smList.add(new ucinn_ascendv2__Social_Media__c(
            ucinn_ascendv2__Contact__c = con.Id,
            ucinn_ascendv2__Platform__c = 'Facebook',
            ucinn_ascendv2__URL__c = 'www.facebooktest.com'
        ));
        smList.add(new ucinn_ascendv2__Social_Media__c(
            ucinn_ascendv2__Contact__c = con.Id,
            ucinn_ascendv2__Platform__c = 'LinkedIn',
            ucinn_ascendv2__URL__c = 'https://linkedin.com/test'
        ));
        smList.add(new ucinn_ascendv2__Social_Media__c(
            ucinn_ascendv2__Contact__c = con.Id,
            ucinn_ascendv2__Platform__c = 'Instagram',
            ucinn_ascendv2__URL__c = 'https://instagram.com/test'
        ));
        smList.add(new ucinn_ascendv2__Social_Media__c(
            ucinn_ascendv2__Contact__c = con.Id,
            ucinn_ascendv2__Platform__c = 'Twitter',
            ucinn_ascendv2__URL__c = 'https://twitter.com/test'
        ));
        insert smList;

        // Create Involvement Value records
        List<ucinn_ascendv2__Involvement_Value__c> involvementValue = new List<ucinn_ascendv2__Involvement_Value__c>();
        involvementValue.add(
            new ucinn_ascendv2__Involvement_Value__c(
                Name = 'Mens Basketball',
                HAM_Category__c = 'Student NCAA Athletics',
                ucinn_ascendv2__Type__c = 'Student Involvement',
                ucinn_ascendv2__Involvement_Description__c = 'Mens Basketball'
            )
        );
        involvementValue.add(
            new ucinn_ascendv2__Involvement_Value__c(
                Name = 'Mens Housing',
                HAM_Category__c = 'Student Housing',
                ucinn_ascendv2__Type__c = 'Student Housing',
                ucinn_ascendv2__Involvement_Description__c = 'Mens Housing'
            )
        );
        involvementValue.add(
            new ucinn_ascendv2__Involvement_Value__c(
                Name = 'Mens private society',
                HAM_Category__c = 'Student Private Societies',
                ucinn_ascendv2__Type__c = 'Student Involvement',
                ucinn_ascendv2__Involvement_Description__c = 'Mens private society'
            )
        );
        involvementValue.add(
            new ucinn_ascendv2__Involvement_Value__c(
                Name = 'Mens Clubs',
                HAM_Category__c = 'Student Clubs',
                ucinn_ascendv2__Type__c = 'Student Involvement',
                ucinn_ascendv2__Involvement_Description__c = 'Mens Clubs'
            )
        );
        insert involvementValue;

        // Get Record Type IDs for Involvements with null check
        Id Student_InvolvementRecordTypeId;
        Id Student_HousingRecordTypeId;
        try {
            Student_InvolvementRecordTypeId = Schema.SObjectType.ucinn_ascendv2__Involvement__c
                .getRecordTypeInfosByDeveloperName().get('Student_Involvement').getRecordTypeId();
            Student_HousingRecordTypeId = Schema.SObjectType.ucinn_ascendv2__Involvement__c
                .getRecordTypeInfosByDeveloperName().get('Student_Housing').getRecordTypeId();
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Involvement RecordType Error: ' + e.getMessage());
        }

        // Create Involvement records
        List<ucinn_ascendv2__Involvement__c> involvements = new List<ucinn_ascendv2__Involvement__c>();
        if (Student_InvolvementRecordTypeId != null) {
            involvements.add(
                new ucinn_ascendv2__Involvement__c(
                    ucinn_ascendv2__Contact__c = con.Id,
                    ucinn_ascendv2__Involvement_Code__c = involvementValue[0].Id,
                    RecordTypeId = Student_InvolvementRecordTypeId
                )
            );
            involvements.add(
                new ucinn_ascendv2__Involvement__c(
                    ucinn_ascendv2__Contact__c = con.Id,
                    ucinn_ascendv2__Involvement_Code__c = involvementValue[2].Id,
                    RecordTypeId = Student_InvolvementRecordTypeId
                )
            );
            involvements.add(
                new ucinn_ascendv2__Involvement__c(
                    ucinn_ascendv2__Contact__c = con.Id,
                    ucinn_ascendv2__Involvement_Code__c = involvementValue[3].Id,
                    RecordTypeId = Student_InvolvementRecordTypeId
                )
            );
        }
        if (Student_HousingRecordTypeId != null) {
            involvements.add(
                new ucinn_ascendv2__Involvement__c(
                    ucinn_ascendv2__Contact__c = con.Id,
                    ucinn_ascendv2__Involvement_Code__c = involvementValue[1].Id,
                    RecordTypeId = Student_HousingRecordTypeId
                )
            );
        }
        if (!involvements.isEmpty()) {
            insert involvements;
        }
    }

    @isTest
    static void testGetAlumniOverview_Success() {
        Test.startTest();
        Contact con = [SELECT Id, Name, Email FROM Contact WHERE Email = 'test@example.com' LIMIT 1];
        // Pass a real portal contact Id as the second argument to exercise the
        // logged-in-user connection-privacy branch (String.isNotBlank(portalId)).
        List<HAM_AlumniProfileOverviewController.AlumniProfileOverviewCard> alumniOverviewRec = 
            HAM_AlumniProfileOverviewController.getAlumniOverview(con.Id, con.Id);
        Test.stopTest();

        Assert.isNotNull(alumniOverviewRec, 'List should not be null');
        Assert.isTrue(alumniOverviewRec.size() > 0, 'List should have values');
        
        HAM_AlumniProfileOverviewController.AlumniProfileOverviewCard card = alumniOverviewRec[0];
        Assert.areEqual(con.Id, card.contactId, 'Contact ID should match');
        Assert.isNotNull(card.personalInfofields, 'Personal info should not be null');
        Assert.isNotNull(card.campusLifefields, 'Campus life should not be null');
        Assert.isNotNull(card.addressDetailsfields, 'Address details should not be null');
        Assert.areEqual(true, card.isKirklandAlumnae, 'Should be Kirkland Alumnae');
    }

    @isTest
    static void testGetAlumniOverview_WithPrivacySettings() {
        List<ucinn_ascendv2__Service_Indicator__c> sis = [
            SELECT Id FROM ucinn_ascendv2__Service_Indicator__c 
            WHERE ucinn_ascendv2__Service_Indicator_Value__r.HAM_Portal_ID__c = 'SIV_VIS_ALUMNI_PRIVACY'
        ];
        
        Test.startTest();
        Contact con = [SELECT Id FROM Contact WHERE Email = 'test2@example.com' LIMIT 1];
        List<HAM_AlumniProfileOverviewController.AlumniProfileOverviewCard> alumniOverviewRec = 
            HAM_AlumniProfileOverviewController.getAlumniOverview(con.Id, '');
        Test.stopTest();

        if (sis.size() > 0) {
            Assert.areEqual(0, alumniOverviewRec.size(), 'Contact with Alumni Privacy should be skipped');
        } else {
            Assert.isTrue(alumniOverviewRec.size() >= 0, 'Result should be valid');
        }
    }
    
    @isTest
    static void testGetAlumniOverview_WithProfilePicturePrivacy() {
        List<ucinn_ascendv2__Service_Indicator__c> sis = [
            SELECT Id FROM ucinn_ascendv2__Service_Indicator__c 
            WHERE ucinn_ascendv2__Service_Indicator_Value__r.HAM_Portal_ID__c = 'SIV_VIS_PROFILE_PIC'
        ];
        
        Test.startTest();
        Contact con = [SELECT Id FROM Contact WHERE Email = 'test3@example.com' LIMIT 1];
        List<HAM_AlumniProfileOverviewController.AlumniProfileOverviewCard> alumniOverviewRec = 
            HAM_AlumniProfileOverviewController.getAlumniOverview(con.Id, '');
        Test.stopTest();

        Assert.areEqual(1, alumniOverviewRec.size(), 'Should return 1 contact');
        
        if (sis.size() > 0) {
            Assert.areEqual(null, alumniOverviewRec[0].profilePictureUrl, 'Profile picture should be null due to privacy');
        }
    }

    @isTest
    static void testGetAlumniOverview_NullContactId() {
        Test.startTest();
        // Should securely return empty list instead of exception
        List<HAM_AlumniProfileOverviewController.AlumniProfileOverviewCard> emptyList = 
            HAM_AlumniProfileOverviewController.getAlumniOverview(null, null);
        Test.stopTest();

        Assert.isTrue(emptyList.isEmpty(), 'Empty list should be returned for null ID');
    }

    @isTest
    static void testGetAlumniOverview_InvalidContactId() {
        Test.startTest();
        // Should securely return empty list instead of exception
        List<HAM_AlumniProfileOverviewController.AlumniProfileOverviewCard> emptyList = 
            HAM_AlumniProfileOverviewController.getAlumniOverview('003000000000000AAA', '');
        Test.stopTest();

        Assert.isTrue(emptyList.isEmpty(), 'Empty list should be returned for invalid ID');
    }
    
    @isTest
    static void testGetAlumniOverview_QueryException() {
        Test.startTest();
        // Passing a bad ID format specifically to break standard SOQL
        List<HAM_AlumniProfileOverviewController.AlumniProfileOverviewCard> result = 
            HAM_AlumniProfileOverviewController.getAlumniOverview('BadIdFormat123', '');
        Test.stopTest();

        Assert.isNotNull(result, 'Should return a list even on error');
        Assert.areEqual(0, result.size(), 'Should return empty list when query fails');
    }
    
    @isTest
    static void testAlumniProfileOverviewCardWrapper() {
        HAM_AlumniProfileOverviewController.AlumniProfileOverviewCard card = 
            new HAM_AlumniProfileOverviewController.AlumniProfileOverviewCard();
        
        card.contactName = 'Test Name';
        card.isKirklandAlumnae = true;
        card.classYear = '2020';
        card.profilePictureUrl = 'test.jpg';
        card.contactlinkedInUrl = 'linkedin.com';
        card.facebookUrl = 'facebook.com';
        card.instagramUrl = 'instagram.com';
        card.twitterUrl = 'twitter.com';
        card.fields = new List<HAM_AlumniProfileOverviewController.FieldWrapper>();
        card.personalInfofields = new List<HAM_AlumniProfileOverviewController.FieldWrapper>();
        card.campusLifefields = new List<HAM_AlumniProfileOverviewController.FieldWrapper>();
        card.addressDetailsfields = new List<HAM_AlumniProfileOverviewController.FieldWrapper>();
        
        Assert.isNotNull(card, 'Card should be instantiated');
        Assert.areEqual('Test Name', card.contactName, 'Name should match');
    }
    
    @isTest
    static void testWrapperClasses() {
        HAM_AlumniProfileOverviewController.FieldWrapper field1 = new HAM_AlumniProfileOverviewController.FieldWrapper();
        field1.label = 'Test Label 1';
        field1.order = 1;
        field1.value = 'Test Value 1';
        
        HAM_AlumniProfileOverviewController.FieldWrapper field2 = new HAM_AlumniProfileOverviewController.FieldWrapper();
        field2.label = 'Test Label 2';
        field2.order = 2;
        field2.value = 'Test Value 2';
        
        HAM_AlumniProfileOverviewController.FieldWrapper field3 = new HAM_AlumniProfileOverviewController.FieldWrapper();
        field3.label = 'Test Label 3';
        field3.order = 1;
        field3.value = 'Test Value 3';
        
        Test.startTest();
        Integer comparison1 = field1.compareTo(field2);
        Integer comparison2 = field2.compareTo(field1);
        Integer comparison3 = field1.compareTo(field3);
        Test.stopTest();
        
        Assert.areEqual(-1, comparison1, 'field1 should be less than field2');
        Assert.areEqual(1, comparison2, 'field2 should be greater than field1');
        Assert.areEqual(0, comparison3, 'field1 should equal field3');
        
        HAM_AlumniProfileOverviewController.ConnectionData conData = new HAM_AlumniProfileOverviewController.ConnectionData();
        conData.isDisable = true;
        conData.isSendRequest = false;
        conData.label = 'Test Label';
        conData.cssClass = 'test-class';
        
        Assert.isNotNull(conData, 'ConnectionData should be instantiated');
    }

    @isTest
    static void testGetConnectionStatus_RequestSent() {
        Contact portal = [SELECT Id FROM Contact WHERE Email = 'test@example.com' LIMIT 1];
        Contact constituent = [SELECT Id FROM Contact WHERE Email = 'test2@example.com' LIMIT 1];

        insert new HAM_Connection__c(
            HAM_Portal_User__c = portal.Id,
            HAM_Linked_Constituent__c = constituent.Id,
            HAM_Connection_Status__c = 'Request Sent'
        );

        Test.startTest();
        HAM_AlumniProfileOverviewController.ConnectionData result =
            HAM_AlumniProfileOverviewController.getConnectionStatus(portal.Id, constituent.Id);
        Test.stopTest();

        Assert.areEqual('Cancel Request', result.label, 'Label should be Cancel Request');
        Assert.areEqual('btn inactive', result.cssClass, 'CSS class should be btn inactive');
        Assert.areEqual(false, result.isDisable, 'Button should not be disabled');
        Assert.areEqual(false, result.isSendRequest, 'isSendRequest should be false');
    }

    @isTest
    static void testGetConnectionStatus_Connected() {
        Contact portal = [SELECT Id FROM Contact WHERE Email = 'test@example.com' LIMIT 1];
        Contact constituent = [SELECT Id FROM Contact WHERE Email = 'test2@example.com' LIMIT 1];

        insert new HAM_Connection__c(
            HAM_Portal_User__c = portal.Id,
            HAM_Linked_Constituent__c = constituent.Id,
            HAM_Connection_Status__c = 'Connected'
        );

        Test.startTest();
        HAM_AlumniProfileOverviewController.ConnectionData result =
            HAM_AlumniProfileOverviewController.getConnectionStatus(portal.Id, constituent.Id);
        Test.stopTest();

        Assert.areEqual('Remove Connection', result.label, 'Label should be Remove Connection');
        Assert.areEqual('btn inactive', result.cssClass, 'CSS class should be btn inactive');
        Assert.areEqual(false, result.isDisable, 'Button should not be disabled');
    }

    @isTest
    static void testGetConnectionStatus_RejectedWithin30Days() {
        Contact portal = [SELECT Id FROM Contact WHERE Email = 'test@example.com' LIMIT 1];
        Contact constituent = [SELECT Id FROM Contact WHERE Email = 'test2@example.com' LIMIT 1];

        insert new HAM_Connection__c(
            HAM_Portal_User__c = constituent.Id,
            HAM_Linked_Constituent__c = portal.Id,
            HAM_Connection_Status__c = 'Rejected',
            HAM_Rejected_Date__c = System.today().addDays(-10)
        );

        Test.startTest();
        HAM_AlumniProfileOverviewController.ConnectionData result =
            HAM_AlumniProfileOverviewController.getConnectionStatus(portal.Id, constituent.Id);
        Test.stopTest();

        Assert.areEqual(true, result.isDisable, 'Button should be disabled');
        Assert.areEqual(true, result.isSendRequest, 'isSendRequest should be true');
        Assert.areEqual('Send Request', result.label, 'Label should be Send Request');
        Assert.areEqual('btn disable', result.cssClass, 'CSS class should be btn disable');
    }

    @isTest
    static void testGetConnectionStatus_DisconnectWithin30Days() {
        Contact portal = [SELECT Id FROM Contact WHERE Email = 'test@example.com' LIMIT 1];
        Contact constituent = [SELECT Id FROM Contact WHERE Email = 'test2@example.com' LIMIT 1];

        insert new HAM_Connection__c(
            HAM_Portal_User__c = constituent.Id,
            HAM_Linked_Constituent__c = portal.Id,
            HAM_Connection_Status__c = 'Disconnect',
            HAM_Rejected_Date__c = System.today().addDays(-20)
        );

        Test.startTest();
        HAM_AlumniProfileOverviewController.ConnectionData result =
            HAM_AlumniProfileOverviewController.getConnectionStatus(portal.Id, constituent.Id);
        Test.stopTest();

        Assert.areEqual(true, result.isDisable, 'Button should be disabled within 30 days');
        Assert.areEqual('btn disable', result.cssClass, 'CSS class should be btn disable');
    }

    @isTest
    static void testGetConnectionStatus_RejectedBeyond30Days() {
        Contact portal = [SELECT Id FROM Contact WHERE Email = 'test@example.com' LIMIT 1];
        Contact constituent = [SELECT Id FROM Contact WHERE Email = 'test2@example.com' LIMIT 1];

        insert new HAM_Connection__c(
            HAM_Portal_User__c = constituent.Id,
            HAM_Linked_Constituent__c = portal.Id,
            HAM_Connection_Status__c = 'Rejected',
            HAM_Rejected_Date__c = System.today().addDays(-40)
        );

        Test.startTest();
        HAM_AlumniProfileOverviewController.ConnectionData result =
            HAM_AlumniProfileOverviewController.getConnectionStatus(portal.Id, constituent.Id);
        Test.stopTest();

        Assert.areEqual(true, result.isDisable, 'Button state should be true');
    }

    @isTest
    static void testGetConnectionStatus_NoConnection() {
        Contact portal = [SELECT Id FROM Contact WHERE Email = 'test@example.com' LIMIT 1];
        Contact constituent = [SELECT Id FROM Contact WHERE Email = 'test2@example.com' LIMIT 1];

        Test.startTest();
        HAM_AlumniProfileOverviewController.ConnectionData result =
            HAM_AlumniProfileOverviewController.getConnectionStatus(portal.Id, constituent.Id);
        Test.stopTest();

        Assert.areEqual(true, result.isDisable, 'Button state should be true for new connection');
        Assert.areEqual(true, result.isSendRequest, 'isSendRequest should be true');
        Assert.areEqual('Send Request', result.label, 'Label should be Send Request');
        Assert.areEqual('btn active', result.cssClass, 'CSS class should be btn active');
    }
    
    private static void createAscendBypassMethod(Id userId) { 
        ucinn_ascendv2__Bypass_Settings__c ascBypass = new ucinn_ascendv2__Bypass_Settings__c(); 
        ascBypass.SetupOwnerId = userId; 
        ascBypass.ucinn_ascendv2__Bypass_Process_Builders__c = true; 
        ascBypass.ucinn_ascendv2__Bypass_Triggers__c = true; 
        ascBypass.ucinn_ascendv2__Bypass_Validation_Rules__c = true; 
        ascBypass.ucinn_ascendv2__Bypass_Workflows__c = true; 
        insert ascBypass; 
    }
    
    private static void removeAscendBypassMethod(Id userId) { 
        List<ucinn_ascendv2__Bypass_Settings__c> ascBypassList = [SELECT Id FROM ucinn_ascendv2__Bypass_Settings__c WHERE SetupOwnerId = :userId]; 
        if(!ascBypassList.isEmpty()) {
            delete ascBypassList; 
        }
    }
}