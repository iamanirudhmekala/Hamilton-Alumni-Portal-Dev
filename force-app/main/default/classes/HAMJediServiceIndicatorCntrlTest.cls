@isTest
private class HAMJediServiceIndicatorCntrlTest {

    @testSetup
    static void setup() {
        // Create common test data
        Account acc = HAMJediTestDataFactory.makeAccount();
        Contact con = HAMJediTestDataFactory.makeContact(acc.Id);

        // Create multiple service indicators for the contact
        ucinn_ascendv2__Service_Indicator__c si1 = HAMJediTestDataFactory.makeServiceIndicator(con.Id);
        si1.ucinn_ascendv2__Start_Date__c = Date.today().addDays(-10);
        si1.ucinn_ascendv2__Is_Active__c = true;

        ucinn_ascendv2__Service_Indicator__c si2 = HAMJediTestDataFactory.makeServiceIndicator(con.Id);
        si2.ucinn_ascendv2__Start_Date__c = Date.today().addDays(-20);
        si2.ucinn_ascendv2__Is_Active__c = false;
        
        update new List<ucinn_ascendv2__Service_Indicator__c>{si1, si2};
    }

    @isTest
    static void testGetIndicatorsWithValidContact() {
        // Arrange
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];

        // Act
        Test.startTest();
        List<ucinn_ascendv2__Service_Indicator__c> result = HAMJediServiceIndicatorController.getServiceIndicators(testContact.Id);
        Test.stopTest();

        // Assert
        System.assertNotEquals(null, result, 'Result should not be null.');
        System.assertEquals(2, result.size(), 'Should return two service indicators for the contact.');
        System.assertEquals(testContact.Id, result[0].ucinn_ascendv2__Contact__c, 'First record should belong to the correct contact.');
        System.assertEquals(testContact.Id, result[1].ucinn_ascendv2__Contact__c, 'Second record should belong to the correct contact.');
        
        // Assert sorting: Active first, then by Start Date Desc
        System.assertEquals(true, result[0].ucinn_ascendv2__Is_Active__c, 'First record should be the active one.');
        System.assertEquals(false, result[1].ucinn_ascendv2__Is_Active__c, 'Second record should be the inactive one.');
    }

    @isTest
    static void testGetIndicatorsWithBlankContact() {
        // Act
        Test.startTest();
        List<ucinn_ascendv2__Service_Indicator__c> result = HAMJediServiceIndicatorController.getServiceIndicators('');
        Test.stopTest();

        // Assert
        System.assertNotEquals(null, result, 'Result should not be null for a blank Id.');
        System.assertEquals(0, result.size(), 'Should return an empty list for a blank Id.');
    }
    
    @isTest
    static void testGetIndicatorsWithNullContact() {
        // Act
        Test.startTest();
        List<ucinn_ascendv2__Service_Indicator__c> result = HAMJediServiceIndicatorController.getServiceIndicators(null);
        Test.stopTest();

        // Assert
        System.assertNotEquals(null, result, 'Result should not be null for a null Id.');
        System.assertEquals(0, result.size(), 'Should return an empty list for a null Id.');
    }

    @isTest
    static void testGetIndicatorsWithNoIndicators() {
        // Arrange: Create a contact with no service indicators
        Account newAcc = HAMJediTestDataFactory.makeAccount('AccountWithoutIndicators');
        Contact newCon = HAMJediTestDataFactory.makeContact('ContactWithoutIndicators', newAcc.Id);
        
        // Act
        Test.startTest();
        List<ucinn_ascendv2__Service_Indicator__c> result = HAMJediServiceIndicatorController.getServiceIndicators(newCon.Id);
        Test.stopTest();
        
        // Assert
        System.assertNotEquals(null, result, 'Result should not be null.');
        System.assertEquals(0, result.size(), 'Should return an empty list when contact has no indicators.');
    }
}