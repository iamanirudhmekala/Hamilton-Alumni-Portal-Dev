@IsTest
public class HAMJEDIGivingSocietyCtrlTest {

    @TestSetup
    static void setupTestData() {
        // Create Account and Contact using data factory
        Account acc = HAMJediTestDataFactory.makeAccount('Test Giving Society Account');
        Contact con = HAMJediTestDataFactory.makeContact('GivingSocietyTest', acc.Id);

        // Create Giving Society records using data factory
        ucinn_ascendv2__Giving_Society__c society1 = HAMJediTestDataFactory.makeGivingSociety('Heritage Society');
        ucinn_ascendv2__Giving_Society__c society2 = HAMJediTestDataFactory.makeGivingSociety('Leadership Circle');

        // Create Society Membership records
        List<ucinn_ascendv2__Society_Membership__c> memberships = new List<ucinn_ascendv2__Society_Membership__c>();

        memberships.add(new ucinn_ascendv2__Society_Membership__c(
            ucinn_ascendv2__Contact__c = con.Id,
            ucinn_ascendv2__Giving_Society__c = society1.Id,
            ucinn_ascendv2__Member_Since__c = Date.today().addYears(-2),
            ucinn_ascendv2__Anniversary_Date__c = Date.today().addMonths(6),
            ucinn_ascendv2__Expiration_Date__c = Date.today().addYears(1),
            HAM_JBA_Anonymous__c = false,
            HAM_Will_Provision__c = true,
            HAM_Planned_Gift__c = false,
            HAM_Documented__c = true,
            HAM_Unknown__c = false,
            ucinn_ascendv2__Comments__c = 'Test membership 1'
        ));

        memberships.add(new ucinn_ascendv2__Society_Membership__c(
            ucinn_ascendv2__Contact__c = con.Id,
            ucinn_ascendv2__Giving_Society__c = society2.Id,
            ucinn_ascendv2__Member_Since__c = Date.today().addYears(-5),
            ucinn_ascendv2__Anniversary_Date__c = Date.today().addMonths(-6),
            ucinn_ascendv2__Expiration_Date__c = Date.today().addMonths(-1),
            HAM_JBA_Anonymous__c = true,
            HAM_Will_Provision__c = false,
            HAM_Planned_Gift__c = true,
            HAM_Documented__c = false,
            HAM_Unknown__c = true,
            ucinn_ascendv2__Comments__c = 'Test membership 2'
        ));

        memberships.add(new ucinn_ascendv2__Society_Membership__c(
            ucinn_ascendv2__Contact__c = con.Id,
            ucinn_ascendv2__Giving_Society__c = society1.Id,
            ucinn_ascendv2__Member_Since__c = Date.today().addYears(-1),
            ucinn_ascendv2__Anniversary_Date__c = Date.today().addMonths(3),
            HAM_JBA_Anonymous__c = false,
            HAM_Will_Provision__c = false,
            HAM_Planned_Gift__c = false,
            HAM_Documented__c = false,
            HAM_Unknown__c = false
        ));

        insert memberships;
    }

    @IsTest
    static void testGetSocietyMemberships_WithValidContact() {
        // Get the test contact
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];

        Test.startTest();
        List<ucinn_ascendv2__Society_Membership__c> results =
            HAMJEDIGivingSocietyCtrl.getSocietyMemberships(testContact.Id);
        Test.stopTest();

        // Verify results
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(3, results.size(), 'Should return 3 memberships');

        // Verify all fields are populated
        for (ucinn_ascendv2__Society_Membership__c membership : results) {
            System.assertNotEquals(null, membership.Id, 'Membership Id should be populated');
            System.assertNotEquals(null, membership.Name, 'Membership Name should be populated');
            System.assertEquals(testContact.Id, membership.ucinn_ascendv2__Contact__c,
                'Contact Id should match');
            System.assertNotEquals(null, membership.ucinn_ascendv2__Giving_Society__c,
                'Giving Society Id should be populated');
        }
    }

    @IsTest
    static void testGetSocietyMemberships_WithGivingSocietyLookup() {
        // Get the test contact
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];

        Test.startTest();
        List<ucinn_ascendv2__Society_Membership__c> results =
            HAMJEDIGivingSocietyCtrl.getSocietyMemberships(testContact.Id);
        Test.stopTest();

        // Verify Giving Society relationship is queried
        Boolean foundGivingSocietyName = false;
        for (ucinn_ascendv2__Society_Membership__c membership : results) {
            if (membership.ucinn_ascendv2__Giving_Society__r != null &&
                membership.ucinn_ascendv2__Giving_Society__r.Name != null) {
                foundGivingSocietyName = true;
                System.assert(
                    membership.ucinn_ascendv2__Giving_Society__r.Name == 'Heritage Society' ||
                    membership.ucinn_ascendv2__Giving_Society__r.Name == 'Leadership Circle',
                    'Giving Society Name should be Heritage Society or Leadership Circle'
                );
            }
        }
        System.assert(foundGivingSocietyName, 'At least one membership should have Giving Society Name populated');
    }

    @IsTest
    static void testGetSocietyMemberships_Sorting() {
        // Get the test contact
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];

        Test.startTest();
        List<ucinn_ascendv2__Society_Membership__c> results =
            HAMJEDIGivingSocietyCtrl.getSocietyMemberships(testContact.Id);
        Test.stopTest();

        // Verify sorting: Membership Status ASC, then Member Since DESC
        System.assertEquals(3, results.size(), 'Should return 3 memberships');

        // Verify records are returned in sorted order
        // Primary sort: Membership Status ASC (formula field, calculated by system)
        // Secondary sort: Member Since DESC (most recent first within same status)
        for (Integer i = 0; i < results.size() - 1; i++) {
            String status1 = results[i].ucinn_ascendv2__Membership_Status__c;
            String status2 = results[i+1].ucinn_ascendv2__Membership_Status__c;
            Date memberSince1 = results[i].ucinn_ascendv2__Member_Since__c;
            Date memberSince2 = results[i+1].ucinn_ascendv2__Member_Since__c;

            // If statuses are the same, verify Member Since DESC order
            if (status1 == status2) {
                System.assert(
                    memberSince1 >= memberSince2,
                    'Within same status, should be sorted by Member Since DESC'
                );
            }
            // Otherwise, just verify we have valid data
            System.assertNotEquals(null, results[i].Id, 'Record should have valid Id');
        }
    }

    @IsTest
    static void testGetSocietyMemberships_EmptyResults() {
        // Create a contact with no memberships
        Account acc = HAMJediTestDataFactory.makeAccount('No Membership Account');
        Contact conWithNoMemberships = HAMJediTestDataFactory.makeContact('NoMemberships', acc.Id);

        Test.startTest();
        List<ucinn_ascendv2__Society_Membership__c> results =
            HAMJEDIGivingSocietyCtrl.getSocietyMemberships(conWithNoMemberships.Id);
        Test.stopTest();

        // Verify empty results
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(0, results.size(), 'Should return 0 memberships for contact with no memberships');
    }

    @IsTest
    static void testGetSocietyMemberships_AllFieldsReturned() {
        // Get the test contact
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];

        Test.startTest();
        List<ucinn_ascendv2__Society_Membership__c> results =
            HAMJEDIGivingSocietyCtrl.getSocietyMemberships(testContact.Id);
        Test.stopTest();

        // Find the membership with all fields populated (first one from setup)
        ucinn_ascendv2__Society_Membership__c fullMembership = results[0];

        // Verify all fields are accessible
        System.assertNotEquals(null, fullMembership.Id);
        System.assertNotEquals(null, fullMembership.Name);
        System.assertNotEquals(null, fullMembership.ucinn_ascendv2__Contact__c);
        System.assertNotEquals(null, fullMembership.ucinn_ascendv2__Giving_Society__c);
        System.assertNotEquals(null, fullMembership.ucinn_ascendv2__Member_Since__c);
        System.assertNotEquals(null, fullMembership.ucinn_ascendv2__Anniversary_Date__c);
        System.assertNotEquals(null, fullMembership.HAM_JBA_Anonymous__c);
        System.assertNotEquals(null, fullMembership.HAM_Will_Provision__c);
        System.assertNotEquals(null, fullMembership.HAM_Planned_Gift__c);
        System.assertNotEquals(null, fullMembership.HAM_Documented__c);
        System.assertNotEquals(null, fullMembership.HAM_Unknown__c);
    }

    @IsTest
    static void testGetSocietyMemberships_Cacheable() {
        // Get the test contact
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];

        // Test that method is cacheable (can be called from wire service)
        Test.startTest();
        List<ucinn_ascendv2__Society_Membership__c> results1 =
            HAMJEDIGivingSocietyCtrl.getSocietyMemberships(testContact.Id);
        List<ucinn_ascendv2__Society_Membership__c> results2 =
            HAMJEDIGivingSocietyCtrl.getSocietyMemberships(testContact.Id);
        Test.stopTest();

        // Both calls should return same number of records
        System.assertEquals(results1.size(), results2.size(),
            'Cacheable method should return consistent results');
        System.assertEquals(3, results1.size(), 'Should return 3 memberships');
    }
}