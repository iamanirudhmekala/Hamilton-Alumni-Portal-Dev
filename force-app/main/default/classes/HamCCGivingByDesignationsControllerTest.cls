@IsTest
private class HamCCGivingByDesignationsControllerTest {

    @TestSetup
    static void setupData() {
        // Account
        Account acct = new Account(
            Name = 'Test Household'
        );
        insert acct;

        // Contact (Alumni)
        Contact con = new Contact(
            LastName = 'Test Contact',
            AccountId = acct.Id
        );
        insert con;

        // Record Type for Giving By Purpose (controller uses this RT)
        Id givingRTId = Schema.SObjectType.HAM_Pledge_Balance__c
            .getRecordTypeInfosByName()
            .get('Giving By Purpose')
            .getRecordTypeId();

        // Active pledge balance for alumni contact
        HAM_Pledge_Balance__c pb = new HAM_Pledge_Balance__c(
            Name = 'Test Pledge',
            RecordTypeId = givingRTId,
            Constituent__c = con.Id,
            HAM_Status__c = 'active',
            HAM_Designation__c = 'Annual Fund',
            HAM_Fiscal_Year__c = '2025',
            HAM_Paid__c = 5000,
            HAM_Pledged__c = 8000,
            HAM_Pledge_Balance__c = 3000
        );
        insert pb;
    }

    @IsTest
    static void testGetGivingByDesignations_AlumniTrue_ReturnsRows() {
        Contact c = [SELECT Id FROM Contact LIMIT 1];

        Test.startTest();
        List<HAM_Pledge_Balance__c> results =
            HamCCGivingByDesignationsController.getGivingByDesignations(c.Id, true);
        Test.stopTest();

        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(1, results.size(), 'Expected one pledge balance row for alumni');

        HAM_Pledge_Balance__c row = results[0];
        System.assertEquals('Annual Fund', row.HAM_Designation__c, 'Designation should match test data');
        System.assertEquals(5000, row.HAM_Paid__c, 'Paid should match test data');
        System.assertEquals(3000, row.HAM_Pledge_Balance__c, 'Balance should match test data');
    }

    @IsTest
    static void testGetGivingByDesignations_AlumniFalse_EmptyList() {
        Contact c = [SELECT Id FROM Contact LIMIT 1];

        Test.startTest();
        List<HAM_Pledge_Balance__c> results =
            HamCCGivingByDesignationsController.getGivingByDesignations(c.Id, false);
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Non-alumni should return empty list per controller rules');
    }

    @IsTest
    static void testGetGivingByDesignations_NullId_EmptyList() {
        Test.startTest();
        List<HAM_Pledge_Balance__c> results =
            HamCCGivingByDesignationsController.getGivingByDesignations(null, true);
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Null Id should return empty list');
    }
}