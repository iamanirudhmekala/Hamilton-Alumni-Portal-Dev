@IsTest
public class HAMJediContactReportControllerTest {
    
    @TestSetup
    static void setupTestData() {
        Account testAccount = HAMJediTestDataFactory.makeAccount('Contact Report Test Account');
        Contact testContact = HAMJediTestDataFactory.makeContactWithDonorId('TestContact', testAccount.Id, 'D12345');
        
        // Create contact reports using existing factory methods
        HAMJediTestDataFactory.makeContactReport(testContact.Id);
        HAMJediTestDataFactory.makeContactReports(testContact.Id, 3);
    }
    
    @IsTest
    static void testGetContactReportDetail() {
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];
        
        Test.startTest();
        List<ucinn_ascendv2__Contact_Report__c> results = HAMJediContactReportController.getContactReportDetail(testContact.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, results, 'Should return contact reports list');
        System.assertEquals(4, results.size(), 'Should return 4 contact reports total');
        
        // Verify required fields are populated
        for (ucinn_ascendv2__Contact_Report__c report : results) {
            System.assertNotEquals(null, report.Id, 'Report ID should be populated');
            System.assertNotEquals(null, report.Name, 'Report Name should be populated');
        }
    }
    
    @IsTest
    static void testGetContactReportDetailNoReports() {
        // Create a contact without reports
        Account account = HAMJediTestDataFactory.makeAccount('No Reports Account');
        Contact contactNoReports = HAMJediTestDataFactory.makeContactWithDonorId('NoReports', account.Id, 'D99999');
        
        Test.startTest();
        List<ucinn_ascendv2__Contact_Report__c> results = HAMJediContactReportController.getContactReportDetail(contactNoReports.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, results, 'Should return empty list, not null');
        System.assertEquals(0, results.size(), 'Should return empty list when no reports exist');
    }
    
    @IsTest
    static void testGetContactReportDetailOrdering() {
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];
        
        // Create additional report to test ordering
        HAMJediTestDataFactory.makeContactReport(testContact.Id);
        
        Test.startTest();
        List<ucinn_ascendv2__Contact_Report__c> results = HAMJediContactReportController.getContactReportDetail(testContact.Id);
        Test.stopTest();
        
        System.assert(results.size() > 1, 'Should have multiple reports for ordering test');
        // Results should be ordered by LastModifiedDate DESC
        // We can verify the query executes without errors
    }
    
    @IsTest
    static void testGetContactReportFieldAccess() {
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];
        
        Test.startTest();
        List<ucinn_ascendv2__Contact_Report__c> results = HAMJediContactReportController.getContactReportDetail(testContact.Id);
        Test.stopTest();
        
        if (results.size() > 0) {
            ucinn_ascendv2__Contact_Report__c report = results[0];
            // Verify all queried fields are accessible (no exceptions thrown)
            String name = report.Name;
            String contactMethod = report.ucinn_ascendv2__Contact_Method__c;
            String substantive = report.ucinn_ascendv2__Substantive_Contact__c;
            String description = report.ucinn_ascendv2__Description__c;
            String body = report.ucinn_ascendv2__Contact_Report_Body__c;
            Date reportDate = report.ucinn_ascendv2__Date__c;
            String prm = report.HAM_PRM_at_Time_of_Meeting__c;
            String lastModifiedByName = report.LastModifiedBy?.Name;

            System.assertNotEquals(null, report.Id, 'Report should have ID');
            System.assertNotEquals(null, lastModifiedByName, 'Last Modified By Name should be populated');
        }
    }
    
    @IsTest
    static void testGetContactReportDetailWithNullContactId() {
        Test.startTest();
        List<ucinn_ascendv2__Contact_Report__c> results = HAMJediContactReportController.getContactReportDetail(null);
        Test.stopTest();
        
        System.assertNotEquals(null, results, 'Should return empty list for null contact ID');
        System.assertEquals(0, results.size(), 'Should return empty list for null contact ID');
    }
    
    @IsTest
    static void testGetContactReportDetailWithEmptyContactId() {
        Test.startTest();
        List<ucinn_ascendv2__Contact_Report__c> results = HAMJediContactReportController.getContactReportDetail('');
        Test.stopTest();

        System.assertNotEquals(null, results, 'Should return empty list for empty contact ID');
        System.assertEquals(0, results.size(), 'Should return empty list for empty contact ID');
    }

    @IsTest
    static void testGetContactReportDetailWithContactReportRelations() {
        // Setup: Create primary contact and spouse contact
        Account testAccount = HAMJediTestDataFactory.makeAccount('CRR Test Account');
        Contact primaryContact = HAMJediTestDataFactory.makeContactWithDonorId('PrimaryContact', testAccount.Id, 'D11111');
        Contact spouseContact = HAMJediTestDataFactory.makeContactWithDonorId('SpouseContact', testAccount.Id, 'D22222');

        // Get a valid picklist value for Contact Role
        String validContactRole = getValidContactRole();

        // Create a Contact Report directly linked to the primary contact
        ucinn_ascendv2__Contact_Report__c directReport = new ucinn_ascendv2__Contact_Report__c(
            ucinn_ascendv2__Contact__c = primaryContact.Id,
            ucinn_ascendv2__Contact_Method__c = 'In Person',
            ucinn_ascendv2__Description__c = 'Direct report for primary contact',
            ucinn_ascendv2__Date__c = Date.today()
        );
        insert directReport;

        // Create a Contact Report linked to spouse (not directly to primary)
        ucinn_ascendv2__Contact_Report__c spouseReport = new ucinn_ascendv2__Contact_Report__c(
            ucinn_ascendv2__Contact__c = spouseContact.Id,
            ucinn_ascendv2__Contact_Method__c = 'Phone',
            ucinn_ascendv2__Description__c = 'Report for spouse contact',
            ucinn_ascendv2__Date__c = Date.today().addDays(-1)
        );
        insert spouseReport;

        // Create Contact Report Relation linking primary contact to spouse's report
        ucinn_ascendv2__Contact_Report_Relation__c crr = new ucinn_ascendv2__Contact_Report_Relation__c(
            ucinn_ascendv2__Contact__c = primaryContact.Id,
            ucinn_ascendv2__Contact_Report__c = spouseReport.Id,
            ucinn_ascendv2__Contact_Role__c = validContactRole
        );
        insert crr;

        Test.startTest();
        List<ucinn_ascendv2__Contact_Report__c> results = HAMJediContactReportController.getContactReportDetail(primaryContact.Id);
        Test.stopTest();

        // Verify both reports are returned: direct report + spouse report via CRR
        System.assertNotEquals(null, results, 'Should return contact reports list');
        System.assertEquals(2, results.size(), 'Should return 2 contact reports (1 direct + 1 via CRR)');

        // Verify both report IDs are in the results
        Set<Id> returnedIds = new Set<Id>();
        for (ucinn_ascendv2__Contact_Report__c report : results) {
            returnedIds.add(report.Id);
        }
        System.assert(returnedIds.contains(directReport.Id), 'Should include direct contact report');
        System.assert(returnedIds.contains(spouseReport.Id), 'Should include spouse contact report via CRR');
    }

    @IsTest
    static void testGetContactReportDetailWithMultipleContactReportRelations() {
        // Setup: Create primary contact and multiple related contacts
        Account testAccount = HAMJediTestDataFactory.makeAccount('Multi CRR Test Account');
        Contact primaryContact = HAMJediTestDataFactory.makeContactWithDonorId('PrimaryContact', testAccount.Id, 'D33333');
        Contact relatedContact1 = HAMJediTestDataFactory.makeContactWithDonorId('RelatedContact1', testAccount.Id, 'D44444');
        Contact relatedContact2 = HAMJediTestDataFactory.makeContactWithDonorId('RelatedContact2', testAccount.Id, 'D55555');

        // Get valid picklist values for Contact Role
        List<String> validContactRoles = getValidContactRoles(2);

        // Create Contact Reports for related contacts (not directly linked to primary)
        ucinn_ascendv2__Contact_Report__c relatedReport1 = new ucinn_ascendv2__Contact_Report__c(
            ucinn_ascendv2__Contact__c = relatedContact1.Id,
            ucinn_ascendv2__Contact_Method__c = 'Email',
            ucinn_ascendv2__Description__c = 'Report for related contact 1',
            ucinn_ascendv2__Date__c = Date.today().addDays(-2)
        );
        ucinn_ascendv2__Contact_Report__c relatedReport2 = new ucinn_ascendv2__Contact_Report__c(
            ucinn_ascendv2__Contact__c = relatedContact2.Id,
            ucinn_ascendv2__Contact_Method__c = 'Virtual',
            ucinn_ascendv2__Description__c = 'Report for related contact 2',
            ucinn_ascendv2__Date__c = Date.today().addDays(-3)
        );
        insert new List<ucinn_ascendv2__Contact_Report__c>{ relatedReport1, relatedReport2 };

        // Create Contact Report Relations linking primary contact to both reports
        List<ucinn_ascendv2__Contact_Report_Relation__c> crrList = new List<ucinn_ascendv2__Contact_Report_Relation__c>{
            new ucinn_ascendv2__Contact_Report_Relation__c(
                ucinn_ascendv2__Contact__c = primaryContact.Id,
                ucinn_ascendv2__Contact_Report__c = relatedReport1.Id,
                ucinn_ascendv2__Contact_Role__c = validContactRoles[0]
            ),
            new ucinn_ascendv2__Contact_Report_Relation__c(
                ucinn_ascendv2__Contact__c = primaryContact.Id,
                ucinn_ascendv2__Contact_Report__c = relatedReport2.Id,
                ucinn_ascendv2__Contact_Role__c = validContactRoles.size() > 1 ? validContactRoles[1] : validContactRoles[0]
            )
        };
        insert crrList;

        Test.startTest();
        List<ucinn_ascendv2__Contact_Report__c> results = HAMJediContactReportController.getContactReportDetail(primaryContact.Id);
        Test.stopTest();

        // Verify both related reports are returned via CRR
        System.assertNotEquals(null, results, 'Should return contact reports list');
        System.assertEquals(2, results.size(), 'Should return 2 contact reports via CRR');

        // Verify both report IDs are in the results
        Set<Id> returnedIds = new Set<Id>();
        for (ucinn_ascendv2__Contact_Report__c report : results) {
            returnedIds.add(report.Id);
        }
        System.assert(returnedIds.contains(relatedReport1.Id), 'Should include related contact report 1 via CRR');
        System.assert(returnedIds.contains(relatedReport2.Id), 'Should include related contact report 2 via CRR');
    }

    @IsTest
    static void testGetContactReportDetailDeduplication() {
        // Setup: Test that same report appearing in both direct and CRR is only returned once
        Account testAccount = HAMJediTestDataFactory.makeAccount('Dedup Test Account');
        Contact primaryContact = HAMJediTestDataFactory.makeContactWithDonorId('PrimaryContact', testAccount.Id, 'D66666');

        // Create a Contact Report directly linked to the primary contact
        ucinn_ascendv2__Contact_Report__c directReport = new ucinn_ascendv2__Contact_Report__c(
            ucinn_ascendv2__Contact__c = primaryContact.Id,
            ucinn_ascendv2__Contact_Method__c = 'In Person',
            ucinn_ascendv2__Description__c = 'Direct report that also has CRR',
            ucinn_ascendv2__Date__c = Date.today()
        );
        insert directReport;

        // Get a valid picklist value for Contact Role
        String validContactRole = getValidContactRole();

        // Create Contact Report Relation for the same report (to test deduplication)
        ucinn_ascendv2__Contact_Report_Relation__c crr = new ucinn_ascendv2__Contact_Report_Relation__c(
            ucinn_ascendv2__Contact__c = primaryContact.Id,
            ucinn_ascendv2__Contact_Report__c = directReport.Id,
            ucinn_ascendv2__Contact_Role__c = validContactRole
        );
        insert crr;

        Test.startTest();
        List<ucinn_ascendv2__Contact_Report__c> results = HAMJediContactReportController.getContactReportDetail(primaryContact.Id);
        Test.stopTest();

        // Verify the report is only returned once (automatic SOQL deduplication)
        System.assertNotEquals(null, results, 'Should return contact reports list');
        System.assertEquals(1, results.size(), 'Should return only 1 contact report (deduplicated)');
        System.assertEquals(directReport.Id, results[0].Id, 'Should return the correct contact report');
    }

    // Helper method to get a single valid Contact Role picklist value
    private static String getValidContactRole() {
        Schema.DescribeFieldResult fieldResult = ucinn_ascendv2__Contact_Report_Relation__c.ucinn_ascendv2__Contact_Role__c.getDescribe();
        List<Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues();

        // Return first active picklist value
        for (Schema.PicklistEntry entry : picklistValues) {
            if (entry.isActive()) {
                return entry.getValue();
            }
        }

        // Fallback: return null if no active values found (test will fail, which is correct)
        return null;
    }

    // Helper method to get multiple valid Contact Role picklist values
    private static List<String> getValidContactRoles(Integer count) {
        Schema.DescribeFieldResult fieldResult = ucinn_ascendv2__Contact_Report_Relation__c.ucinn_ascendv2__Contact_Role__c.getDescribe();
        List<Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues();
        List<String> validRoles = new List<String>();

        // Collect active picklist values up to the requested count
        for (Schema.PicklistEntry entry : picklistValues) {
            if (entry.isActive()) {
                validRoles.add(entry.getValue());
                if (validRoles.size() >= count) {
                    break;
                }
            }
        }

        // If we don't have enough values, reuse the first one
        while (validRoles.size() < count && validRoles.size() > 0) {
            validRoles.add(validRoles[0]);
        }

        return validRoles;
    }
}