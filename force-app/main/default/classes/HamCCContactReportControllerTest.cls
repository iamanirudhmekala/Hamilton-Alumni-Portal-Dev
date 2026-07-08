/**
 * @description Unit tests for HamCCContactReportController
 */
@isTest
private class HamCCContactReportControllerTest {
    
    @isTest
    static void testGetContactReportsWithContact() {
        // Setup
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            Email = 'test.contact@example.com'
        );
        insert testContact;
        
        ucinn_ascendv2__Contact_Report__c testReport = new ucinn_ascendv2__Contact_Report__c(
            Name = 'Test Report',
            ucinn_ascendv2__Contact__c = testContact.Id,
            ucinn_ascendv2__Date__c = Date.today()
        );
        insert testReport;
        
        // Test
        List<ucinn_ascendv2__Contact_Report__c> results = HamCCContactReportController.getContactReports(testContact.Id, true);
        
        // Verify
        System.assertNotEquals(0, results.size(), 'Should return at least one contact report');
        System.assertEquals(testReport.Id, results[0].Id, 'Should return the correct report');
    }
    
    @isTest
    static void testGetContactReportsWithAccount() {
        // Setup
        Account testAccount = new Account(
            Name = 'Test Account'
        );
        insert testAccount;
        
        ucinn_ascendv2__Contact_Report__c testReport = new ucinn_ascendv2__Contact_Report__c(
            Name = 'Test Report',
            ucinn_ascendv2__Account__c = testAccount.Id,
            ucinn_ascendv2__Date__c = Date.today()
        );
        insert testReport;
        
        // Test
        List<ucinn_ascendv2__Contact_Report__c> results = HamCCContactReportController.getContactReports(testAccount.Id, false);
        
        // Verify
        System.assertNotEquals(0, results.size(), 'Should return at least one contact report');
        System.assertEquals(testReport.Id, results[0].Id, 'Should return the correct report');
    }
    
    @isTest
    static void testSaveContactReport() {
        // Setup
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            Email = 'test.contact@example.com'
        );
        insert testContact;
        
        ucinn_ascendv2__Contact_Report__c reportToSave = new ucinn_ascendv2__Contact_Report__c(
            Name = 'New Report',
            ucinn_ascendv2__Contact__c = testContact.Id,
            ucinn_ascendv2__Date__c = Date.today()
        );
        
        // Test
        ucinn_ascendv2__Contact_Report__c savedReport = HamCCContactReportController.saveContactReport(reportToSave);
        
        // Verify
        System.assertNotEquals(null, savedReport, 'Should return the saved report');
        System.assertNotEquals(null, savedReport.Id, 'Should have an ID after saving');
        System.assertEquals('New Report', savedReport.Name, 'Should save the correct name');
    }
}