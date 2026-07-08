/**
 * This class contains unit tests for validating the behavior of Apex classes
 * and triggers.
 *
 * Unit tests are class methods that verify whether a particular piece
 * of code is working properly. Unit test methods take no arguments,
 * commit no data to the database, and are flagged with the testMethod
 * keyword in the method definition.
 *
 * All test methods in an org are executed whenever Apex code is deployed
 * to a production org to confirm correctness, ensure code
 * coverage, and prevent regressions. All Apex classes are
 * required to have at least 75% code coverage in order to be deployed
 * to a production org. In addition, all triggers must have some code coverage.
 * 
 * The @isTest class annotation indicates this class only contains test
 * methods. Classes defined with the @isTest annotation do not count against
 * the org size limit for all Apex scripts.
 *
 * See the Apex Language Reference for more information about Testing and Code Coverage.
 */
@isTest
private class HamMyProspectControllerTest {

    
    @TestSetup
    static void setupTestData() {
        Account testAccount = HAMJediTestDataFactory.makeAccount('Search Test Account');
        
        Contact c1 = HAMJediTestDataFactory.makeSearchContact('Johnson', testAccount.Id, 'D12345', '2020');
        c1.ucinn_ascendv2__PRM__c = UserInfo.getUserId();
        update c1;
        testAccount.ucinn_ascendv2__Primary_Contact__c = c1.Id; 
        update testAccount;
        Contact c2 = HAMJediTestDataFactory.makeSearchContact('Smith', testAccount.Id, 'D67890', '2015');
    }

    // Basic search tests
    @IsTest
    static void testMyPrimaryConstitiuent() {
        Test.startTest();
            user testUser = [SELECT Id, Name FROM User WHERE Id = :UserInfo.getUserId()];
            System.runAs(testUser) {
                List<Contact> results = HamMyProspectController.searchMyProspects();
            }
        Test.stopTest();
       
    }
}