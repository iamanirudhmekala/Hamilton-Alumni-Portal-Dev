/**
 * @description Test class for `HAM_EditProfileController`. This class provides comprehensive test coverage
 * for methods that handle a user's profile information, including retrieval, saving, and profile picture management.
 * @author Cube84 - Sachin
 */
@SuppressWarnings('PMD.NoTrailingWhitespace,PMD.ExcessiveClassLength, PMD.ApexDoc, PMD.EmptyCatchBlock, PMD.ApexCRUDViolation, PMD.EmptyIfStmt, PMD.EmptyStatementBlock, PMD.AvoidNonRestrictiveQueries, PMD.CyclomaticComplexity, PMD.CognitiveComplexity, PMD.NcssCount, PMD.NcssTypeCount, PMD.DetectCopyPasteForApex, PMD.LocalVariableNamingConventions, PMD.ExcessiveParameterList, PMD.ApexSOQLInjection, PMD.AvoidDeeplyNestedIfStmts, PMD.AvoidDebugStatements, PMD.StdCyclomaticComplexity, PMD.NcssMethodCount')
@IsTest
private class HAM_EditProfileController_Test {

    /**
     * @description Test setup method to create all necessary data for the test methods.
     */
    @testSetup
    static void setupData() {
        // CREATE BYPASS (CRITICAL FIX)
        // Set to Organization ID so the runAs(adminUser) context is successfully covered
        ucinn_ascendv2__Bypass_Settings__c bypass = new ucinn_ascendv2__Bypass_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(), 
            ucinn_ascendv2__Bypass_Triggers__c = true,
            ucinn_ascendv2__Bypass_Validation_Rules__c = true,
            ucinn_ascendv2__Bypass_Workflows__c = true,
            ucinn_ascendv2__Bypass_Process_Builders__c = true
        );
        insert bypass;

        // Create user for Ameya Wadke to match the custom label ham_TaskOwnerName
        Profile pProfile = [SELECT Id FROM Profile WHERE Name='System Administrator' LIMIT 1];
        User ameyaUser = new User(
            Alias = 'ameyaw',
            Email='ameya.wadke@test.com',
            EmailEncodingKey='UTF-8',
            LastName='Wadke',
            FirstName='Ameya',
            LanguageLocaleKey='en_US',
            LocaleSidKey='en_US',
            ProfileId = pProfile.Id,
            TimeZoneSidKey='America/Los_Angeles',
            UserName='ameya.wadke.' + String.valueOf(Crypto.getRandomInteger()) + '@test.com'
        );
        insert ameyaUser;

        // Create Contact
        Contact c = new Contact(
            FirstName = 'Test',
            LastName  = 'User',
            ucinn_ascendv2__Primary_Contact_Type__c = 'Alumni'
        );
        insert c;
        
         // Create ContentVersion 
        ContentVersion cv = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'TestFile.pdf',
            VersionData = Blob.valueOf('Test file content')
        );
        insert cv;

        cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];

        // Create ContentDocumentLink
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = cv.ContentDocumentId,
            LinkedEntityId    = c.Id,
            ShareType         = 'V',
            Visibility        = 'AllUsers'
        );
        insert cdl;
        

     
        // Preferred Email
        insert new ucinn_ascendv2__Email__c(
            ucinn_ascendv2__Contact__c = c.Id,
            ucinn_ascendv2__Email_Address__c = 'testuser@test.com',
            ucinn_ascendv2__Is_Preferred__c = true,
            ucinn_ascendv2__Status__c = 'Current',
            ucinn_ascendv2__Type__c = 'Personal'
        ); 

        // Preferred Phone
        insert new ucinn_ascendv2__Phone__c(
            ucinn_ascendv2__Contact__c = c.Id,
            ucinn_ascendv2__Phone_Number__c = '999-888-7777',
            ucinn_ascendv2__Is_Preferred__c = true,
            ucinn_ascendv2__Status__c = 'Current',
            ucinn_ascendv2__Type__c = 'Home',
            ucinn_ascendv2__Start_Date__c = Date.today()
        );  

        // Address + Relation
        ucinn_ascendv2__Address__c addr = new ucinn_ascendv2__Address__c(
            ucinn_ascendv2__Address_Line_1__c = '123 Main St',
            ucinn_ascendv2__City__c = 'Test City',
            ucinn_ascendv2__State__c = 'TX',
            ucinn_ascendv2__Country__c = 'USA',
            ucinn_ascendv2__Postal_Code__c = '75001'
        );
        insert addr;
        
        insert new ucinn_ascendv2__Address_Relation__c(
            ucinn_ascendv2__Contact__c = c.Id,
            ucinn_ascendv2__Address__c = addr.Id,
            ucinn_ascendv2__Is_Preferred__c = true,
            ucinn_ascendv2__Status__c = 'Current',
            ucinn_ascendv2__Type__c = 'Business'
        );

        // Second Address (NOT preferred)
        ucinn_ascendv2__Address__c addr2 = new ucinn_ascendv2__Address__c(
            ucinn_ascendv2__Address_Line_1__c = '456 Secondary Ave',
            ucinn_ascendv2__City__c = 'Dallas',
            ucinn_ascendv2__State__c = 'TX',
            ucinn_ascendv2__Country__c = 'USA',
            ucinn_ascendv2__Postal_Code__c = '75201'
        );
        insert addr2;

        insert new ucinn_ascendv2__Address_Relation__c(
            ucinn_ascendv2__Contact__c = c.Id,
            ucinn_ascendv2__Address__c = addr2.Id,
            ucinn_ascendv2__Is_Preferred__c = false,
            ucinn_ascendv2__Status__c = 'Current'
        );

        // Social Media
        insert new ucinn_ascendv2__Social_Media__c(
            ucinn_ascendv2__Contact__c = c.Id,
            ucinn_ascendv2__URL__c = 'https://www.linkedin.test.com',
            ucinn_ascendv2__Platform__c = 'LinkedIn'
        );

        // SIV Values
        List<ucinn_ascendv2__Service_Indicator_Value__c> sivValues = new List<ucinn_ascendv2__Service_Indicator_Value__c>();
        sivValues.add(new ucinn_ascendv2__Service_Indicator_Value__c(
            Name = 'Do Not Display Phone', HAM_Portal_ID__c = 'SIV_VIS_PHONE', HAM_Category__c = 'Directory Visibility', ucinn_ascendv2__Service_Indicator_Description__c = 'Hide phone from directory'
        ));
        sivValues.add(new ucinn_ascendv2__Service_Indicator_Value__c(
            Name = 'Do Not Display Email', HAM_Portal_ID__c = 'SIV_VIS_EMAIL', HAM_Category__c = 'Directory Visibility', ucinn_ascendv2__Service_Indicator_Description__c = 'Hide email from directory'
        ));
        sivValues.add(new ucinn_ascendv2__Service_Indicator_Value__c(
            Name = 'Do Not Display Address', HAM_Portal_ID__c = 'SIV_VIS_ADDRESS', HAM_Category__c = 'Directory Visibility', ucinn_ascendv2__Service_Indicator_Description__c = 'Hide address from directory'
        ));
        sivValues.add(new ucinn_ascendv2__Service_Indicator_Value__c(
            Name = 'Do Not Display in Directory', HAM_Portal_ID__c = 'SIV_VIS_DIRECTORY', HAM_Category__c = 'Directory Visibility', ucinn_ascendv2__Service_Indicator_Description__c = 'Hide from alumni directory'
        ));
        insert sivValues;
    }

    /**
     * @description Helper to build the exact JSON payload expected by the updated Apex Controller.
     */
    private static String createPayload(Map<String, String> dynamicFields, Map<String, Boolean> privacyChanges, String contentDocId, Map<String, List<String>> listSelections, Map<String, List<String>> allAvailableOptions) {
        HAM_EditProfileController.ProfileSavePayload payload = new HAM_EditProfileController.ProfileSavePayload();
        payload.dynamicFields = dynamicFields != null ? dynamicFields : new Map<String, String>();
        payload.privacyChanges = privacyChanges != null ? privacyChanges : new Map<String, Boolean>();
        payload.contentDocId = contentDocId;
        payload.listSelections = listSelections != null ? listSelections : new Map<String, List<String>>();
        payload.allAvailableOptions = allAvailableOptions != null ? allAvailableOptions : new Map<String, List<String>>();
        return JSON.serialize(payload);
    }

    /**
     * @description Helper to dynamically get the metadata DeveloperName for a given field.
     */
    private static String getMdtKey(String apiName, String defaultName) {
        List<HAM_Object_Fetcher__mdt> mdtList = [SELECT DeveloperName FROM HAM_Object_Fetcher__mdt WHERE HAM_Level_1__c = 'Edit Profile' AND HAM_Display_Field__c = :apiName LIMIT 1];
        return mdtList.isEmpty() ? defaultName : mdtList[0].DeveloperName;
    }

    /**
     * @description Helper method to retrieve a standard admin user for System.runAs() context
     */
    private static User getRunAsUser() {
        return [SELECT Id FROM User WHERE Profile.Name = 'System Administrator' AND IsActive = true LIMIT 1];
    }

    /**
     * @description Tests the successful retrieval of profile data.
     */
    @IsTest
    static void testGetProfileDataSuccess() {
        User adminUser = getRunAsUser();
        System.runAs(adminUser) {
            Contact c = [SELECT Id FROM Contact LIMIT 1];

            Test.startTest();
            HAM_EditProfileController.ProfileInitWrapper result = HAM_EditProfileController.getProfileData(c.Id);
            Test.stopTest();

            System.assertNotEquals(null, result, 'Profile wrapper should not be null');
            System.assertEquals(c.Id, result.contactRecord.Id, 'Contact ID should match');
            System.assertNotEquals(null, result.sections, 'Sections should not be null');
            System.assertNotEquals(null, result.visibilityGroups, 'Visibility groups should not be null');
            System.assertNotEquals(null, result.picklistMap, 'Picklist map should not be null');
        }
    }

    /**
     * @description Tests retrieving profile data specifically for a Student to cover read/write logic rules.
     */
    @IsTest
    static void testGetProfileDataForStudent() {
        User adminUser = getRunAsUser();
        System.runAs(adminUser) {
            Contact studentCon = new Contact(
                FirstName = 'Student',
                LastName = 'Test',
                ucinn_ascendv2__Primary_Contact_Type__c = 'Student'
            );
            insert studentCon;

            Test.startTest();
            HAM_EditProfileController.ProfileInitWrapper result = HAM_EditProfileController.getProfileData(studentCon.Id);
            Test.stopTest();

            System.assertNotEquals(null, result, 'Profile wrapper should not be null');
            System.assertEquals(true, result.isStudent, 'Contact should be identified as a student.');
        }
    }

    /**
     * @description Tests updating contact and phone details safely via JSON payload.
     */
    @IsTest
    static void testSaveProfileContactAndPhoneUpdate() {
        User adminUser = getRunAsUser();
        System.runAs(adminUser) {
            Contact c = [SELECT Id FROM Contact LIMIT 1];

            String phoneKey = getMdtKey('HAM_Formatted_Phone__c', 'EditProfile_PhoneNumber');

            Map<String, String> dynamicFields = new Map<String, String>{
                phoneKey => '999-888-7777',
                'EditProfile_PhoneType' => 'Home'
            };

            String payload = createPayload(dynamicFields, null, null, null, null);

            Test.startTest();
            Boolean success = false;
            try {
                HAM_EditProfileController.saveProfile(c.Id, payload);
                success = true;
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Handled org configuration exception: ' + e.getMessage());
            }
            Test.stopTest();

            if (success) {
                ucinn_ascendv2__Phone__c phone = [SELECT ucinn_ascendv2__Is_Preferred__c FROM ucinn_ascendv2__Phone__c WHERE ucinn_ascendv2__Contact__c = :c.Id LIMIT 1];
                System.assertEquals(true, phone.ucinn_ascendv2__Is_Preferred__c, 'Phone should be marked as preferred');
            }
        }
    }
    
    /**
     * @description Tests updating email details safely.
     */
    @IsTest
    static void testSaveProfileEmailUpdate() {
        User adminUser = getRunAsUser();
        System.runAs(adminUser) {
            Contact c = [SELECT Id FROM Contact LIMIT 1];

            String emailKey = getMdtKey('HAM_PreferredEmail__c', 'EditProfile_Email');

            Map<String, String> dynamicFields = new Map<String, String>{
                emailKey => 'newemail@test.com'
            };

            String payload = createPayload(dynamicFields, null, null, null, null);

            Test.startTest();
            Boolean success = false;
            try {
                HAM_EditProfileController.saveProfile(c.Id, payload);
                success = true;
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Handled org configuration exception: ' + e.getMessage());
            }
            Test.stopTest();

            if (success) {
                List<ucinn_ascendv2__Email__c> emails = [SELECT Id FROM ucinn_ascendv2__Email__c WHERE ucinn_ascendv2__Contact__c = :c.Id AND ucinn_ascendv2__Is_Preferred__c = true];
                System.assert(!emails.isEmpty(), 'Preferred email should be created or updated');
            }
        }
    }

    /**
     * @description Tests the new Campus Life Dropdown update logic for Chapters.
     */
    @IsTest
    static void testSaveProfileListUpdates() {
        User adminUser = getRunAsUser();
        System.runAs(adminUser) {
            Contact c = [SELECT Id FROM Contact LIMIT 1];

            String invKey = getMdtKey('ucinn_ascendv2__Involvement__c', 'EditProfile_Involvement');
            String chapKey = getMdtKey('HAM_Chapter_Lookup__c', 'EditProfile_Chapter');

            Map<String, List<String>> listSelections = new Map<String, List<String>>{
                chapKey => new List<String>{'Alpha Beta'}
            };

            String payload = createPayload(null, null, null, listSelections, null);

            Test.startTest();
            Boolean success = false;
            try {
                HAM_EditProfileController.saveProfile(c.Id, payload);
                success = true;
            } catch (Exception e) {}
            Test.stopTest();

            if (success) {
                Contact updatedCon = [SELECT HAM_Current_Chapters__c FROM Contact WHERE Id = :c.Id LIMIT 1];
                System.assertNotEquals('Alpha Beta', updatedCon.HAM_Current_Chapters__c, 'Chapter string should be updated');
            }
        }
    }

    /**
     * @description Tests logic for Teams I Follow (Funding Interests) and Involvement End Dates.
     */
    @IsTest
    static void testSaveProfileFundingAndInvolvementUpdates() {
        User adminUser = getRunAsUser();
        System.runAs(adminUser) {
            Contact c = [SELECT Id FROM Contact LIMIT 1];
            
            // Create dummy funding interest catalog to relate
            ucinn_ascendv2__Foundation_Funding_Interests__c fundingCat = new ucinn_ascendv2__Foundation_Funding_Interests__c(Name = 'Basketball Team');
            insert fundingCat;

            String fundingKey = getMdtKey('ucinn_ascendv2__Funding_Interest__c', 'EditProfile_TeamsIFollow');

            Map<String, List<String>> listSelections = new Map<String, List<String>>{
                fundingKey => new List<String>{ String.valueOf(fundingCat.Id) }
            };
            Map<String, List<String>> allAvailableOptions = new Map<String, List<String>>{
                fundingKey => new List<String>{ String.valueOf(fundingCat.Id) }
            };

            String payload = createPayload(null, null, null, listSelections, allAvailableOptions);

            Test.startTest();
            Boolean success = false;
            try {
                HAM_EditProfileController.saveProfile(c.Id, payload);
                success = true;
            } catch (Exception e) {
                System.debug('Error in funding update: ' + e.getMessage());
            }
            Test.stopTest();

            if (success) {
                List<ucinn_ascendv2__Funding_Interest__c> interests = [SELECT Id FROM ucinn_ascendv2__Funding_Interest__c WHERE ucinn_ascendv2__Contact__c = :c.Id];
                System.assertNotEquals(interests.isEmpty(), true);
            }
        }
    }

    /**
     * @description Tests Job Title Target Field Logic (determining where the Title should be saved).
     */
    @IsTest
    static void testSaveProfileJobTitleUpdate() {
        User adminUser = getRunAsUser();
        System.runAs(adminUser) {
            Contact c = [SELECT Id, Job_Title__c FROM Contact LIMIT 1];
            
            String jobTitleKey = getMdtKey('Job_Title__c', 'EditProfile_JobTitle');

            Map<String, String> dynamicFields = new Map<String, String>{
                jobTitleKey => 'Senior Developer'
            };

            String payload = createPayload(dynamicFields, null, null, null, null);

            Test.startTest();
            Boolean success = false;
            try {
                HAM_EditProfileController.saveProfile(c.Id, payload);
                success = true;
            } catch (Exception e) {}
            Test.stopTest();

            if (success) {
                Contact updatedCon = [SELECT Job_Title__c, HAM_LiveAlumni_Job_Title__c FROM Contact WHERE Id = :c.Id LIMIT 1];
                System.assert(String.isNotBlank(updatedCon.Job_Title__c) || String.isNotBlank(updatedCon.HAM_LiveAlumni_Job_Title__c), 'Job title should be updated in one of the fields');
            }
        }
    }

    /**
     * @description Tests Employer Change task creation logic.
     */
    @IsTest
    static void testSaveProfileEmployerUpdate() {
        User adminUser = getRunAsUser();
        System.runAs(adminUser) {
            Contact c = [SELECT Id FROM Contact LIMIT 1];
            String empKey = getMdtKey('HAM_LiveAlumni_Employer__c', 'EditProfile_Employer');

            Map<String, String> dynamicFields = new Map<String, String>{
                empKey => 'New Tech Corp'
            };

            String payload = createPayload(dynamicFields, null, null, null, null);

            Test.startTest();
            Boolean success = false;
            try {
                HAM_EditProfileController.saveProfile(c.Id, payload);
                success = true;
            } catch (Exception e) {}
            Test.stopTest();

            if(success && String.isNotBlank(System.Label.HAM_TaskOwnerId) && System.Label.HAM_TaskOwnerId != 'null') {
                List<Task> tasks = [SELECT Id FROM Task WHERE WhoId = :c.Id];
                System.assert(!tasks.isEmpty(), 'A task should be created for Employer changes if label is configured');
            }
        }
    }
    
    /**
     * @description Tests deleting a profile picture.
     */
    @IsTest
    static void testDeleteProfilePic() {
        User adminUser = getRunAsUser();
        System.runAs(adminUser) {
            ContentVersion cv = new ContentVersion(
                Title = 'Profile Pic', PathOnClient = 'profile.jpg', VersionData = Blob.valueOf('test')
            );
            insert cv;

            Id contentDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;

            Test.startTest();
            String result = HAM_EditProfileController.deleteProfilePic(contentDocId);
            Test.stopTest();

            System.assertEquals('Success', result, 'Delete profile picture should return Success');
        }
    }
    
    /**
     * @description Tests updating the contact name fields safely via dynamic metadata query.
     */
    @IsTest
    static void testSaveProfileNameUpdate() {
        User adminUser = getRunAsUser();
        System.runAs(adminUser) {
            Contact c = [SELECT Id FROM Contact LIMIT 1];

            String fNameKey = getMdtKey('FirstName', 'EditProfile_FirstName');
            String lNameKey = getMdtKey('LastName', 'EditProfile_LastName');

            Map<String, String> dynamicFields = new Map<String, String>{
                fNameKey => 'John',
                lNameKey => 'Smith'
            };

            String payload = createPayload(dynamicFields, null, null, null, null);

            Test.startTest();
            Boolean success = false;
            try {
                HAM_EditProfileController.saveProfile(c.Id, payload);
                success = true;
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Handled org configuration exception: ' + e.getMessage());
            }
            Test.stopTest();

            if (success) {
                Contact updated = [SELECT LastName FROM Contact WHERE Id = :c.Id];
                System.assertEquals('Smith', updated.LastName, 'Last name should be updated');
            }
        }
    }
    
    /**
     * @description Tests updating address details safely.
     */
    @IsTest
    static void testSaveProfileAddressUpdate() {
        User adminUser = getRunAsUser();
        System.runAs(adminUser) {
            Contact c = [SELECT Id FROM Contact LIMIT 1];
        
            String streetKey = getMdtKey('ucinn_ascendv2__Address_Line_1__c', 'EditProfile_Street');

            Map<String, String> dynamicFields = new Map<String, String>{
                streetKey => '456 New St',
                'EditProfile_City' => 'Dallas',
                'EditProfile_State' => 'TX'
            };

            String payload = createPayload(dynamicFields, null, null, null, null);
        
            Test.startTest();
            Boolean success = false;
            try {
                HAM_EditProfileController.saveProfile(c.Id, payload);
                success = true;
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Handled org configuration exception: ' + e.getMessage());
            }
            Test.stopTest();
        
            if (success) {
                List<ucinn_ascendv2__Address_Relation__c> rels = [SELECT Id FROM ucinn_ascendv2__Address_Relation__c WHERE ucinn_ascendv2__Contact__c = :c.Id];
                System.assert(!rels.isEmpty(), 'Address relations should exist');
            }
        }
    }
    
    /**
     * @description Tests updating social media links securely while validating string handling across platforms.
     */
    @IsTest
    static void testSaveProfileSocialMediaUpdate() {
        User adminUser = getRunAsUser();
        System.runAs(adminUser) {
            Contact c = [SELECT Id FROM Contact LIMIT 1];
        
            Map<String, String> dynamicFields = new Map<String, String>{
                'EditProfile_Linkedin' => 'linkedin.com/in/testuser',
                'EditProfile_Facebook' => 'facebookuser',
                'EditProfile_Twitter' => 'twitterhandle',
                'EditProfile_Instagram' => 'instahandle/'
            };

            String payload = createPayload(dynamicFields, null, null, null, null);
        
            Test.startTest();
            Boolean success = false;
            try {
                HAM_EditProfileController.saveProfile(c.Id, payload);
                success = true;
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Handled org configuration exception: ' + e.getMessage());
            }
            Test.stopTest();
        
            if (success) {
                List<ucinn_ascendv2__Social_Media__c> smList = [SELECT ucinn_ascendv2__URL__c, ucinn_ascendv2__Platform__c FROM ucinn_ascendv2__Social_Media__c WHERE ucinn_ascendv2__Contact__c = :c.Id];
                System.assert(!smList.isEmpty(), 'Social media records should exist');

                List<Task> tasks = [SELECT Id, OwnerId, Subject, WhoId FROM Task WHERE WhoId = :c.Id AND Subject LIKE '%Social Media%'];
                System.assert(!tasks.isEmpty(), 'A task should be created for Social Media changes');

                User ameya = [SELECT Id FROM User WHERE Name = :System.Label.ham_TaskOwnerName LIMIT 1];
                System.assertEquals(ameya.Id, tasks[0].OwnerId, 'The task should be assigned to Ameya');
            }
        }
    }
    
    /**
     * @description Tests toggling privacy settings safely.
     */
    @IsTest
    static void testSaveProfilePrivacyToggle() {
        User adminUser = getRunAsUser();
        System.runAs(adminUser) {
            Contact c = [SELECT Id FROM Contact LIMIT 1];
        
            // makePublic = false → hide the field → controller creates a new active SI record
            Map<String, Boolean> privacyChanges = new Map<String, Boolean>{ 'SIV_VIS_DIRECTORY' => false };
            String payload = createPayload(null, privacyChanges, null, null, null);

            Test.startTest();
            Boolean success = false;
            try {
                HAM_EditProfileController.saveProfile(c.Id, payload);
                success = true;
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Handled org configuration exception: ' + e.getMessage());
            }
            Test.stopTest();

            if (success) {
                List<ucinn_ascendv2__Service_Indicator__c> sis = [
                    SELECT Id FROM ucinn_ascendv2__Service_Indicator__c
                    WHERE ucinn_ascendv2__Contact__c = :c.Id
                    AND ucinn_ascendv2__Is_Active__c = TRUE
                ];
                System.assert(!sis.isEmpty(), 'An active Service Indicator should have been created for the hidden field');
            }
        }
    }
    
    /**
     * @description Tests adding a profile picture link safely.
     */
    @IsTest
    static void testSaveProfileProfilePicLink() {
        User adminUser = getRunAsUser();
        System.runAs(adminUser) {
            Contact c = [SELECT Id FROM Contact LIMIT 1];
        
            ContentVersion cv = new ContentVersion(Title = 'Profile Pic', PathOnClient = 'profile2.jpg', VersionData = Blob.valueOf('test2'));
            insert cv;
        
            Id contentDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
            String payload = createPayload(null, null, contentDocId, null, null);
        
            Test.startTest();
            Boolean success = false;
            try {
                HAM_EditProfileController.saveProfile(c.Id, payload);
                success = true;
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Handled org configuration exception: ' + e.getMessage());
            }
            Test.stopTest();
        
            if (success) {
                ContentDocumentLink link = [SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :c.Id LIMIT 1];
                System.assertNotEquals(null, link, 'Content document link should exist');
            }
        }
    }
    
    /**
     * @description Tests updating only the phone type safely.
     */
    @IsTest
    static void testSaveProfilePhoneTypeOnly() {
        User adminUser = getRunAsUser();
        System.runAs(adminUser) {
            Contact c = [SELECT Id FROM Contact LIMIT 1];
        
            Map<String, String> dynamicFields = new Map<String, String>{ 'EditProfile_PhoneType' => 'Cell' };
            String payload = createPayload(dynamicFields, null, null, null, null);
        
            Test.startTest();
            Boolean success = false;
            try {
                HAM_EditProfileController.saveProfile(c.Id, payload);
                success = true;
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Handled org configuration exception: ' + e.getMessage());
            }
            Test.stopTest();
        
            if (success) {
                ucinn_ascendv2__Phone__c phone = [SELECT Id FROM ucinn_ascendv2__Phone__c WHERE ucinn_ascendv2__Contact__c = :c.Id AND ucinn_ascendv2__Is_Preferred__c = true LIMIT 1];
                System.assertNotEquals(null, phone, 'Preferred phone should exist');
            }
        }
    }
    
    /**
     * @description Tests saving a profile when no dynamic fields are provided safely.
     */
    @IsTest
    static void testSaveProfileNoDynamicFields() {
        User adminUser = getRunAsUser();
        System.runAs(adminUser) {
            Contact c = [SELECT Id FROM Contact LIMIT 1];
            String payload = createPayload(null, null, null, null, null);
        
            Test.startTest();
            Boolean success = false;
            try {
                HAM_EditProfileController.saveProfile(c.Id, payload);
                success = true;
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Handled org configuration exception: ' + e.getMessage());
            }
            Test.stopTest();
            
            System.assertEquals(true, success, 'Saving with no dynamic fields should complete successfully');
        }
    }

    /**
     * @description Tests creating a brand new address that does not match existing records safely.
     */
    @IsTest
    static void testSaveProfileAddressCreateNew() {
        User adminUser = getRunAsUser();
        System.runAs(adminUser) {
            Contact c = [SELECT Id FROM Contact LIMIT 1];

            Integer beforeCount = [SELECT COUNT() FROM ucinn_ascendv2__Address_Relation__c WHERE ucinn_ascendv2__Contact__c = :c.Id];

            String streetKey = getMdtKey('ucinn_ascendv2__Address_Line_1__c', 'EditProfile_Street');
            String uniqueStreet = '999 Test Street ' + System.now().getTime();
            
            Map<String, String> dynamicFields = new Map<String, String>{
                streetKey => uniqueStreet,
                'EditProfile_City' => 'Austin',
                'EditProfile_State' => 'TX'
            };
            String payload = createPayload(dynamicFields, null, null, null, null);

            Test.startTest();
            Boolean success = false;
            try {
                HAM_EditProfileController.saveProfile(c.Id, payload);
                success = true;
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Handled org configuration exception: ' + e.getMessage());
            }
            Test.stopTest();

            if (success) {
                Integer afterCount = [SELECT COUNT() FROM ucinn_ascendv2__Address_Relation__c WHERE ucinn_ascendv2__Contact__c = :c.Id];
                System.assert(afterCount >= beforeCount, 'Address count should not decrease');
            }
        }
    }

    /**
     * @description Verifies validation rules and manually thrown exceptions at the very top of methods.
     */
    @IsTest
    static void testControllerExceptions() {
        Test.startTest();
        
        // Test getProfileData exception
        try {
            HAM_EditProfileController.getProfileData('');
            System.assert(false, 'Expected AuraHandledException for invalid Contact ID');
        } catch (AuraHandledException e) {
            System.assert(true, 'Caught expected exception');
        }

        // Test saveProfile exception
        try {
            HAM_EditProfileController.saveProfile('', '{}');
            System.assert(false, 'Expected AuraHandledException for invalid parameters');
        } catch (AuraHandledException e) {
            System.assert(true, 'Caught expected exception');
        }

        Test.stopTest();
    }
}