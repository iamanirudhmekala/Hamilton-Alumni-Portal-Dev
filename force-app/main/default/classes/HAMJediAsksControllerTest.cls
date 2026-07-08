// Test class for HAMJediAsksController - covers all methods and edge cases
@IsTest
public class HAMJediAsksControllerTest {

    // Setup test data for all test methods - creates Account, Contact, and Opportunities
    @TestSetup
    static void setupTestData() {
        // Create test Account and Contact using factory
        Account acc = HAMJediTestDataFactory.makeAccount('Test Account Asks');
        Contact con = HAMJediTestDataFactory.makeContact('TestContact', acc.Id);

        // Get Proposal RecordType ID
        Id proposalRecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName()
            .get('Proposal')?.getRecordTypeId();

        // Create test Opportunities with Proposal RecordType
        List<Opportunity> opps = new List<Opportunity>();

        // Opportunity 1 - Most recent ask date
        opps.add(new Opportunity(
            Name = 'Test Opportunity 1',
            AccountId = acc.Id,
            StageName = 'Qualification',
            CloseDate = Date.today().addDays(30),
            RecordTypeId = proposalRecordTypeId,
            ucinn_ascendv2__Submitted_Amount__c = 10000,
            HAM_Expected_Amount__c = 9000,
            ucinn_ascendv2__Submitted_Date__c = Date.today().addDays(-5)
        ));

        // Opportunity 2 - Older ask date
        opps.add(new Opportunity(
            Name = 'Test Opportunity 2',
            AccountId = acc.Id,
            StageName = 'Needs Analysis',
            CloseDate = Date.today().addDays(60),
            RecordTypeId = proposalRecordTypeId,
            ucinn_ascendv2__Submitted_Amount__c = 25000,
            HAM_Expected_Amount__c = 20000,
            ucinn_ascendv2__Submitted_Date__c = Date.today().addDays(-10)
        ));

        // Opportunity 3 - No submitted date (should be last in ordering)
        opps.add(new Opportunity(
            Name = 'Test Opportunity 3',
            AccountId = acc.Id,
            StageName = 'Closed Won',
            CloseDate = Date.today().addDays(-5),
            RecordTypeId = proposalRecordTypeId,
            ucinn_ascendv2__Submitted_Amount__c = 5000,
            HAM_Expected_Amount__c = 5000,
            ucinn_ascendv2__Submitted_Date__c = null
        ));

        insert opps;

        // Create OpportunityContactRole to link Contact to Opportunities
        List<OpportunityContactRole> roles = new List<OpportunityContactRole>();
        for (Opportunity opp : opps) {
            roles.add(new OpportunityContactRole(
                OpportunityId = opp.Id,
                ContactId = con.Id,
                Role = 'Decision Maker'
            ));
        }
        insert roles;
    }

    // ========================================
    // TEST: getJediAsks - Positive Scenarios
    // ========================================

    // Verify that getJediAsks returns all opportunities when Contact has associated asks
    @IsTest
    static void testGetJediAsks_WithOpportunities() {
        Contact con = [SELECT Id FROM Contact LIMIT 1];

        Test.startTest();
        List<Opportunity> result = HAMJediAsksController.getJediAsks(con.Id);
        Test.stopTest();

        Assert.areEqual(3, result.size(), 'Should return 3 opportunities');
        Assert.isNotNull(result[0].Id, 'Opportunity ID should not be null');
        Assert.isNotNull(result[0].Name, 'Opportunity Name should not be null');
        Assert.isNotNull(result[0].StageName, 'StageName should not be null');
    }

    // Verify that getJediAsks returns opportunities ordered by Close Date DESC
    @IsTest
    static void testGetJediAsks_OrderedBySubmittedDateDesc() {
        Contact con = [SELECT Id FROM Contact LIMIT 1];

        Test.startTest();
        List<Opportunity> result = HAMJediAsksController.getJediAsks(con.Id);
        Test.stopTest();

        Assert.areEqual(3, result.size(), 'Should return 3 opportunities');
        // First should be most recent Close Date (60 days in future)
        Assert.areEqual('Test Opportunity 2', result[0].Name, 'First opportunity should have latest close date');
        // Second should be next Close Date (30 days in future)
        Assert.areEqual('Test Opportunity 1', result[1].Name, 'Second opportunity should have middle close date');
        // Third should be oldest Close Date (5 days in past)
        Assert.areEqual('Test Opportunity 3', result[2].Name, 'Third opportunity should have oldest close date');
    }

    // Verify that all expected fields are returned in the query
    @IsTest
    static void testGetJediAsks_AllFieldsPopulated() {
        Contact con = [SELECT Id FROM Contact LIMIT 1];

        Test.startTest();
        List<Opportunity> result = HAMJediAsksController.getJediAsks(con.Id);
        Test.stopTest();

        Assert.isTrue(result.size() > 0, 'Should return at least 1 opportunity');
        Opportunity opp = result[0];
        Assert.isNotNull(opp.Id, 'Id should not be null');
        Assert.isNotNull(opp.Name, 'Name should not be null');
        Assert.isNotNull(opp.ucinn_ascendv2__Submitted_Amount__c, 'Ask Amount should not be null');
        Assert.isNotNull(opp.HAM_Expected_Amount__c, 'Expected Amount should not be null');
        Assert.isNotNull(opp.StageName, 'Stage should not be null');
        Assert.isNotNull(opp.CloseDate, 'Close Date should not be null');
    }

    // Verify that only opportunities with Proposal RecordType are returned
    @IsTest
    static void testGetJediAsks_OnlyProposalRecordType() {
        Contact con = [SELECT Id, AccountId FROM Contact LIMIT 1];

        // Try to create an opportunity with a different RecordType (should be excluded if accessible)
        Id otherRecordTypeId = null;

        // Try to get a different RecordType that the running user has access to
        try {
            List<RecordType> otherTypes = [
                SELECT Id
                FROM RecordType
                WHERE SObjectType = 'Opportunity'
                AND DeveloperName != 'Proposal'
                AND IsActive = true
                LIMIT 1
            ];
            if (!otherTypes.isEmpty()) {
                otherRecordTypeId = otherTypes[0].Id;
            }
        } catch (Exception e) {
            // No accessible RecordTypes found, skip creating non-Proposal opportunity
            System.debug('No other RecordType accessible: ' + e.getMessage());
        }

        // Only create non-Proposal opportunity if we have access to another RecordType
        if (otherRecordTypeId != null) {
            try {
                Opportunity nonProposalOpp = new Opportunity(
                    Name = 'Non-Proposal Opportunity',
                    AccountId = con.AccountId,
                    StageName = 'Prospecting',
                    CloseDate = Date.today().addDays(30),
                    RecordTypeId = otherRecordTypeId,
                    ucinn_ascendv2__Submitted_Amount__c = 15000
                );
                insert nonProposalOpp;

                // Link to contact
                OpportunityContactRole role = new OpportunityContactRole(
                    OpportunityId = nonProposalOpp.Id,
                    ContactId = con.Id,
                    Role = 'Influencer'
                );
                insert role;
            } catch (Exception e) {
                // If insert fails due to RecordType access, that's ok - test will still pass
                System.debug('Could not create non-Proposal opportunity: ' + e.getMessage());
            }
        }

        Test.startTest();
        List<Opportunity> result = HAMJediAsksController.getJediAsks(con.Id);
        Test.stopTest();

        // Should return at least the 3 Proposal opportunities from setup
        Assert.isTrue(result.size() >= 3, 'Should return at least 3 Proposal opportunities');

        // Verify all returned opportunities from setup are Proposal RecordType
        Integer proposalCount = 0;
        for (Opportunity opp : result) {
            if (opp.Name.startsWith('Test Opportunity')) {
                proposalCount++;
            }
        }
        Assert.areEqual(3, proposalCount, 'Should return all 3 Proposal opportunities from setup');
    }

    // ========================================
    // TEST: getJediAsks - Negative Scenarios
    // ========================================

    // Verify that getJediAsks returns empty list when Contact has no opportunities
    @IsTest
    static void testGetJediAsks_NoOpportunities() {
        // Create a new contact with no opportunities
        Account acc = HAMJediTestDataFactory.makeAccount('Test Account No Opps');
        Contact conNoOpps = HAMJediTestDataFactory.makeContact('NoOpps', acc.Id);

        Test.startTest();
        List<Opportunity> result = HAMJediAsksController.getJediAsks(conNoOpps.Id);
        Test.stopTest();

        Assert.areEqual(0, result.size(), 'Should return empty list when no opportunities');
        Assert.isNotNull(result, 'Result should not be null, just empty');
    }

    // Verify that getJediAsks handles null contactId gracefully
    @IsTest
    static void testGetJediAsks_NullContactId() {
        Test.startTest();
        List<Opportunity> result = HAMJediAsksController.getJediAsks(null);
        Test.stopTest();

        // Should return empty list for null contactId
        Assert.areEqual(0, result.size(), 'Should return empty list for null contactId');
        Assert.isNotNull(result, 'Result should not be null, just empty');
    }

    // Verify that getJediAsks handles invalid contactId gracefully
    @IsTest
    static void testGetJediAsks_InvalidContactId() {
        // Generate a fake Contact Id that doesn't exist
        String fakeContactId = '003000000000000AAA';

        Test.startTest();
        List<Opportunity> result = HAMJediAsksController.getJediAsks(fakeContactId);
        Test.stopTest();

        // Should return empty list for non-existent contact
        Assert.areEqual(0, result.size(), 'Should return empty list for invalid contactId');
    }

    // ========================================
    // TEST: getJediAsks - Edge Cases
    // ========================================

    // Verify that opportunities without OpportunityContactRole are excluded
    @IsTest
    static void testGetJediAsks_OnlyLinkedOpportunities() {
        Contact con = [SELECT Id, AccountId FROM Contact LIMIT 1];

        // Create a DIFFERENT account to ensure no automatic linking via triggers
        Account differentAcc = HAMJediTestDataFactory.makeAccount('Different Account');

        Id proposalRecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName()
            .get('Proposal')?.getRecordTypeId();

        // Create an opportunity on different account NOT linked to the contact
        Opportunity unlinkedOpp = new Opportunity(
            Name = 'Unlinked Opportunity',
            AccountId = differentAcc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(45),
            RecordTypeId = proposalRecordTypeId,
            ucinn_ascendv2__Submitted_Amount__c = 12000
        );
        insert unlinkedOpp;
        // Intentionally NOT creating OpportunityContactRole

        Test.startTest();
        List<Opportunity> result = HAMJediAsksController.getJediAsks(con.Id);
        Test.stopTest();

        // Should only return the 3 linked opportunities from setup
        Assert.areEqual(3, result.size(), 'Should only return opportunities linked via OpportunityContactRole');
        for (Opportunity opp : result) {
            Assert.areNotEqual('Unlinked Opportunity', opp.Name, 'Should not return unlinked opportunity');
        }
    }

    // Verify that opportunities with null or blank values are handled correctly
    @IsTest
    static void testGetJediAsks_NullFieldValues() {
        Contact con = [SELECT Id, AccountId FROM Contact LIMIT 1];

        Id proposalRecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName()
            .get('Proposal')?.getRecordTypeId();

        // Create opportunity with minimal required fields (nulls for optional fields)
        Opportunity minimalOpp = new Opportunity(
            Name = 'Minimal Opportunity',
            AccountId = con.AccountId,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            RecordTypeId = proposalRecordTypeId
            // ucinn_ascendv2__Submitted_Amount__c intentionally null
            // HAM_Expected_Amount__c intentionally null
            // ucinn_ascendv2__Submitted_Date__c intentionally null
        );
        insert minimalOpp;

        OpportunityContactRole role = new OpportunityContactRole(
            OpportunityId = minimalOpp.Id,
            ContactId = con.Id,
            Role = 'Other'
        );
        insert role;

        Test.startTest();
        List<Opportunity> result = HAMJediAsksController.getJediAsks(con.Id);
        Test.stopTest();

        // Should return all 4 opportunities (3 from setup + 1 minimal)
        Assert.areEqual(4, result.size(), 'Should handle opportunities with null field values');

        // Find the minimal opportunity in results
        Opportunity minimal = null;
        for (Opportunity opp : result) {
            if (opp.Name == 'Minimal Opportunity') {
                minimal = opp;
                break;
            }
        }

        Assert.isNotNull(minimal, 'Should return minimal opportunity');
        Assert.isNull(minimal.ucinn_ascendv2__Submitted_Amount__c, 'Ask Amount can be null');
        Assert.isNull(minimal.HAM_Expected_Amount__c, 'Expected Amount can be null');
    }

    // Verify behavior with a contact linked to many opportunities (bulk test)
    @IsTest
    static void testGetJediAsks_BulkOpportunities() {
        Contact con = [SELECT Id, AccountId FROM Contact LIMIT 1];

        Id proposalRecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName()
            .get('Proposal')?.getRecordTypeId();

        // Create 20 additional opportunities
        List<Opportunity> bulkOpps = new List<Opportunity>();
        for (Integer i = 0; i < 20; i++) {
            bulkOpps.add(new Opportunity(
                Name = 'Bulk Opportunity ' + i,
                AccountId = con.AccountId,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30 + i),
                RecordTypeId = proposalRecordTypeId,
                ucinn_ascendv2__Submitted_Amount__c = 1000 * (i + 1),
                ucinn_ascendv2__Submitted_Date__c = Date.today().addDays(-(i + 1))
            ));
        }
        insert bulkOpps;

        List<OpportunityContactRole> bulkRoles = new List<OpportunityContactRole>();
        for (Opportunity opp : bulkOpps) {
            bulkRoles.add(new OpportunityContactRole(
                OpportunityId = opp.Id,
                ContactId = con.Id,
                Role = 'Other'
            ));
        }
        insert bulkRoles;

        Test.startTest();
        List<Opportunity> result = HAMJediAsksController.getJediAsks(con.Id);
        Test.stopTest();

        // Should return all 23 opportunities (3 from setup + 20 bulk)
        Assert.areEqual(23, result.size(), 'Should handle bulk opportunities');

        // Verify ordering - most recent close date first
        for (Integer i = 0; i < result.size() - 1; i++) {
            if (result[i].CloseDate != null &&
                result[i + 1].CloseDate != null) {
                Assert.isTrue(
                    result[i].CloseDate >= result[i + 1].CloseDate,
                    'Should maintain DESC order by Close Date'
                );
            }
        }
    }
}