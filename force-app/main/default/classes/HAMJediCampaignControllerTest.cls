@IsTest
public class HAMJediCampaignControllerTest {

    /**
     * Test getCampaignDetails with a contact that has multiple campaign memberships
     */
    @IsTest
    static void testGetCampaignDetails_WithMultipleCampaigns() {
        // Arrange: Create test data
        Account acc = HAMJediTestDataFactory.makeAccount('Test Campaign Account');
        Contact con = HAMJediTestDataFactory.makeContact('TestContact', acc.Id);

        // Create parent campaign
        Campaign parentCampaign = new Campaign(
            Name = 'Parent Campaign',
            IsActive = true,
            StartDate = Date.today().addDays(-60),
            EndDate = Date.today().addDays(-30),
            HAM_Fiscal_Year__c = '2024'
        );
        insert parentCampaign;

        // Create child campaigns
        List<Campaign> campaigns = new List<Campaign>{
            new Campaign(
                Name = 'Campaign A',
                IsActive = true,
                StartDate = Date.today().addDays(-30),
                EndDate = Date.today().addDays(30),
                ParentId = parentCampaign.Id,
                HAM_Fiscal_Year__c = '2024'
            ),
            new Campaign(
                Name = 'Campaign B',
                IsActive = false,
                StartDate = Date.today().addDays(-10),
                EndDate = Date.today().addDays(10),
                HAM_Fiscal_Year__c = '2024'
            ),
            new Campaign(
                Name = 'Campaign C',
                IsActive = true,
                StartDate = Date.today().addDays(-5),
                EndDate = Date.today().addDays(5),
                HAM_Fiscal_Year__c = '2025'
            )
        };
        insert campaigns;

        // Create campaign members
        List<CampaignMember> members = new List<CampaignMember>();
        for (Campaign c : campaigns) {
            members.add(new CampaignMember(
                CampaignId = c.Id,
                ContactId = con.Id,
                Status = 'Sent'
            ));
        }
        insert members;

        // Act: Call the controller method
        Test.startTest();
        List<Campaign> results = HAMJediCampaignController.getCampaignDetails(con.Id);
        Test.stopTest();

        // Assert: Verify results
        System.assertEquals(3, results.size(), 'Should return 3 campaigns');

        // Verify campaigns are sorted by StartDate DESC
        System.assertEquals('Campaign C', results[0].Name, 'First campaign should be Campaign C (most recent start date)');
        System.assertEquals('Campaign B', results[1].Name, 'Second campaign should be Campaign B');
        System.assertEquals('Campaign A', results[2].Name, 'Third campaign should be Campaign A (oldest start date)');

        // Verify parent name is populated
        System.assertEquals('Parent Campaign', results[2].Parent.Name, 'Parent campaign name should be populated');

        // Verify all required fields are returned
        for (Campaign c : results) {
            System.assertNotEquals(null, c.Id, 'Campaign Id should be populated');
            System.assertNotEquals(null, c.Name, 'Campaign Name should be populated');
            System.assertNotEquals(null, c.IsActive, 'IsActive should be populated');
            System.assertNotEquals(null, c.HAM_Fiscal_Year__c, 'Fiscal Year should be populated');
        }
    }

    /**
     * Test getCampaignDetails with a contact that has no campaign memberships
     */
    @IsTest
    static void testGetCampaignDetails_NoCampaigns() {
        // Arrange: Create contact with no campaigns
        Account acc = HAMJediTestDataFactory.makeAccount('Test Account No Campaigns');
        Contact con = HAMJediTestDataFactory.makeContact('TestContactNoCampaigns', acc.Id);

        // Act: Call the controller method
        Test.startTest();
        List<Campaign> results = HAMJediCampaignController.getCampaignDetails(con.Id);
        Test.stopTest();

        // Assert: Should return empty list
        System.assertNotEquals(null, results, 'Result should not be null');
        System.assertEquals(0, results.size(), 'Should return empty list when no campaigns exist');
    }

    /**
     * Test getCampaignDetails with null contact ID
     */
    @IsTest
    static void testGetCampaignDetails_NullContactId() {
        // Act: Call with null contact ID
        Test.startTest();
        List<Campaign> results = HAMJediCampaignController.getCampaignDetails(null);
        Test.stopTest();

        // Assert: Should return empty list
        System.assertNotEquals(null, results, 'Result should not be null');
        System.assertEquals(0, results.size(), 'Should return empty list for null contact ID');
    }

    /**
     * Test getCampaignDetails with campaigns that have null start dates
     */
    @IsTest
    static void testGetCampaignDetails_NullStartDates() {
        // Arrange: Create test data
        Account acc = HAMJediTestDataFactory.makeAccount('Test Null Dates Account');
        Contact con = HAMJediTestDataFactory.makeContact('TestContactNullDates', acc.Id);

        // Create campaigns with null start dates
        List<Campaign> campaigns = new List<Campaign>{
            new Campaign(
                Name = 'Campaign No Date',
                IsActive = true,
                HAM_Fiscal_Year__c = '2024'
                // StartDate intentionally null
            ),
            new Campaign(
                Name = 'Campaign With Date',
                IsActive = true,
                StartDate = Date.today(),
                EndDate = Date.today().addDays(30),
                HAM_Fiscal_Year__c = '2024'
            )
        };
        insert campaigns;

        // Create campaign members
        List<CampaignMember> members = new List<CampaignMember>();
        for (Campaign c : campaigns) {
            members.add(new CampaignMember(
                CampaignId = c.Id,
                ContactId = con.Id,
                Status = 'Sent'
            ));
        }
        insert members;

        // Act: Call the controller method
        Test.startTest();
        List<Campaign> results = HAMJediCampaignController.getCampaignDetails(con.Id);
        Test.stopTest();

        // Assert: Verify results and null handling
        System.assertEquals(2, results.size(), 'Should return both campaigns');
        // Campaigns with dates should come first, nulls last (NULLS LAST in query)
        System.assertEquals('Campaign With Date', results[0].Name, 'Campaign with date should be first');
        System.assertEquals('Campaign No Date', results[1].Name, 'Campaign without date should be last');
    }

    /**
     * Test getCampaignDetails with invalid contact ID
     */
    @IsTest
    static void testGetCampaignDetails_InvalidContactId() {
        // Arrange: Use a fake contact ID
        Id fakeContactId = '003000000000000AAA';

        // Act: Call with invalid contact ID
        Test.startTest();
        List<Campaign> results = HAMJediCampaignController.getCampaignDetails(fakeContactId);
        Test.stopTest();

        // Assert: Should return empty list (no campaign members found)
        System.assertNotEquals(null, results, 'Result should not be null');
        System.assertEquals(0, results.size(), 'Should return empty list for invalid contact ID');
    }

    /**
     * Test getCampaignDetails cacheability
     */
    @IsTest
    static void testGetCampaignDetails_Cacheable() {
        // Arrange: Create test data
        Account acc = HAMJediTestDataFactory.makeAccount('Test Cache Account');
        Contact con = HAMJediTestDataFactory.makeContact('TestContactCache', acc.Id);

        Campaign campaign = new Campaign(
            Name = 'Test Campaign Cache',
            IsActive = true,
            StartDate = Date.today(),
            HAM_Fiscal_Year__c = '2024'
        );
        insert campaign;

        CampaignMember member = new CampaignMember(
            CampaignId = campaign.Id,
            ContactId = con.Id,
            Status = 'Sent'
        );
        insert member;

        // Act: Call the method multiple times
        Test.startTest();
        List<Campaign> results1 = HAMJediCampaignController.getCampaignDetails(con.Id);
        List<Campaign> results2 = HAMJediCampaignController.getCampaignDetails(con.Id);
        Test.stopTest();

        // Assert: Both calls should return the same data
        System.assertEquals(results1.size(), results2.size(), 'Both calls should return same number of results');
        System.assertEquals(results1[0].Id, results2[0].Id, 'Both calls should return same campaign');
    }

    /**
     * Test with bulk campaign memberships (governor limits)
     */
    @IsTest
    static void testGetCampaignDetails_BulkCampaigns() {
        // Arrange: Create test data with many campaigns
        Account acc = HAMJediTestDataFactory.makeAccount('Test Bulk Account');
        Contact con = HAMJediTestDataFactory.makeContact('TestContactBulk', acc.Id);

        // Create 15 campaigns
        List<Campaign> campaigns = new List<Campaign>();
        for (Integer i = 0; i < 15; i++) {
            campaigns.add(new Campaign(
                Name = 'Bulk Campaign ' + i,
                IsActive = Math.mod(i, 2) == 0,
                StartDate = Date.today().addDays(-i),
                EndDate = Date.today().addDays(30 - i),
                HAM_Fiscal_Year__c = '2024'
            ));
        }
        insert campaigns;

        // Create campaign members
        List<CampaignMember> members = new List<CampaignMember>();
        for (Campaign c : campaigns) {
            members.add(new CampaignMember(
                CampaignId = c.Id,
                ContactId = con.Id,
                Status = 'Sent'
            ));
        }
        insert members;

        // Act: Call the controller method
        Test.startTest();
        List<Campaign> results = HAMJediCampaignController.getCampaignDetails(con.Id);
        Test.stopTest();

        // Assert: Verify all campaigns are returned and sorted correctly
        System.assertEquals(15, results.size(), 'Should return all 15 campaigns');

        // Verify sorting (most recent StartDate first)
        for (Integer i = 0; i < results.size() - 1; i++) {
            Date currentDate = results[i].StartDate;
            Date nextDate = results[i + 1].StartDate;
            System.assert(
                currentDate >= nextDate,
                'Campaigns should be sorted by StartDate DESC'
            );
        }
    }
}