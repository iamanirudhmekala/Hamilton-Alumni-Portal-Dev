@isTest
private class hamCCAlumniProfileControllerTest {

    @testSetup
    static void setupData() {
        
        // ===============================================================
        // CHANGE START: Insert Reciprocal Relationship Custom Settings
        // This is required for Ascend package relationship triggers
        // ===============================================================
        List<ucinn_ascendv2__Reciprocal_Relationships__c> settings = new List<ucinn_ascendv2__Reciprocal_Relationships__c>();
        
        // Mapping 'Child' -> 'Parent'
        settings.add(new ucinn_ascendv2__Reciprocal_Relationships__c(
            Name = 'Child',
            ucinn_ascendv2__Reciprocal__c = 'Parent'
        ));
        
        // Mapping 'Parent' -> 'Child'
        settings.add(new ucinn_ascendv2__Reciprocal_Relationships__c(
            Name = 'Parent',
            ucinn_ascendv2__Reciprocal__c = 'Child'
        ));
        
        insert settings;
        // ===============================================================
        // CHANGE END
        // ===============================================================

        // 1. Create User for PRM
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1]; 
        User u = new User(Alias = 'standt', Email='standarduser@testorg.com', 
            EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US', 
            LocaleSidKey='en_US', ProfileId = p.Id, 
            TimeZoneSidKey='America/Los_Angeles', UserName='ham_test_user@testorg.com');
        insert u;

        // 2. Create Account (Employee Path)
        Account acc = new Account(
            Name = 'Test Employer',
            Type = 'Employer',
            AccountNumber = '12345',
            ucinn_ascendv2__PRM__c = u.Id
        );
        insert acc;

        // 3. Create Contact (Alumni Path)
        Contact con = new Contact(
            LastName = 'Test Alumni',
            ucinn_ascendv2__PRM__c = u.Id,
            AccountId = acc.Id
        );
        insert con;

        // 4. Create Related Contact for Relationship
        Contact relatedCon = new Contact(LastName = 'Related Contact');
        insert relatedCon;

        // 5. Create Relationship (Contact to Contact)
        // Note: The triggers will use the Custom Settings created above
        ucinn_ascendv2__Relationship__c rel = new ucinn_ascendv2__Relationship__c(
            ucinn_ascendv2__Contact__c = con.Id,
            ucinn_ascendv2__Related_Contact__c = relatedCon.Id,
            ucinn_ascendv2__Related_Contact_Role__c = 'Child'
        );
        insert rel;

        // Note: We don't necessarily need to insert the reciprocal (rel2) manually 
        // if the managed package trigger handles it. However, adding it manually 
        // to be safe if triggers are disabled in test context is fine, 
        // but often triggers duplicate errors if inserted manually while trigger runs.
        // We will stick to inserting one side to let logic flow naturally.

        // 6. Create Affiliation (Contact to Account)
        ucinn_ascendv2__Affiliation__c aff = new ucinn_ascendv2__Affiliation__c(
            ucinn_ascendv2__Account__c = acc.Id,
            ucinn_ascendv2__Contact__c = con.Id,
            ucinn_ascendv2__Status__c = 'Current',
            HAM_Contact_Type__c = 'Career Center Contact',
            ucinn_ascendv2__Job_Title__c = 'Manager',
            ucinn_ascendv2__Organization_Role__c = 'Philanthropic Vehicle',
            ucinn_ascendv2__Constituent_Role__c = 'Donor Advisor'
        );
        insert aff;

        // 7. Create Open Tasks
        Task t1 = new Task(
            Subject = 'Call Alumni',
            Status = 'Open',
            Priority = 'Normal',
            WhoId = con.Id,
            ActivityDate = Date.today()
        );
        
        Task t2 = new Task(
            Subject = 'Check Account',
            Status = 'Open',
            Priority = 'High',
            WhatId = acc.Id,
            ActivityDate = Date.today().addDays(1)
        );
        insert new List<Task>{t1, t2};
    }

    /**
     * @description Tests the getAlumniData method (Contact context).
     */
    @isTest
    static void testGetAlumniData() {
        Contact con = [SELECT Id FROM Contact WHERE LastName = 'Test Alumni' LIMIT 1];

        Test.startTest();
        hamCCAlumniProfileController.ProfileData result = hamCCAlumniProfileController.getAlumniData(con.Id);
        Test.stopTest();

        // 1. Assert Contact Data
        System.assertNotEquals(null, result.objConstituentData, 'Contact data should be returned');
        System.assertEquals(con.Id, result.objConstituentData.Id);

        // 2. Assert PRM Data
        System.assertNotEquals(null, result.prmData, 'PRM data should be populated');
        System.assertEquals('PRM', result.prmData.relationship);

        // 3. Assert Relationships
        // We check that the relationship inserted exists
        System.assertNotEquals(null, result.orgRelations, 'Relationships should not be null');
        System.assertEquals(1, result.orgRelations.size(), 'Should find 1 relationship');

        // 4. Assert Tasks (WhoId)
        System.assertNotEquals(null, result.openTasks, 'Tasks should not be null');
        System.assertEquals(1, result.openTasks.size(), 'Should find 1 open task for contact');
        System.assertEquals('Call Alumni', result.openTasks[0].Subject);
        
        // 5. Assert Badges
        System.assertNotEquals(null, result.badges, 'Badges list should not be null');
    }

    /**
     * @description Tests the getEmployeeData method (Account context).
     */
    @isTest
    static void testGetEmployeeData() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Employer' LIMIT 1];

        Test.startTest();
        hamCCAlumniProfileController.ProfileData result = hamCCAlumniProfileController.getEmployeeData(acc.Id);
        Test.stopTest();

        // 1. Assert Account Data
        System.assertNotEquals(null, result.objOrgData, 'Account data should be returned');
        System.assertEquals(acc.Id, result.objOrgData.Id);

        // 2. Assert Affiliations (Mapped to orgRelations)
        System.assertNotEquals(null, result.orgRelations, 'Affiliations should not be null');
        System.assertEquals(1, result.orgRelations.size(), 'Should find 1 affiliation');
        System.assertEquals('Manager', result.orgRelations[0].relationship);

        // 3. Assert Tasks (WhatId)
        System.assertNotEquals(null, result.openTasks, 'Tasks should not be null');
        System.assertEquals(1, result.openTasks.size(), 'Should find 1 open task for account');
        System.assertEquals('Check Account', result.openTasks[0].Subject);
    }
}