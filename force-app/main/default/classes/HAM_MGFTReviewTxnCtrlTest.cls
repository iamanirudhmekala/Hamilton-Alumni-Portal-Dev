@IsTest
private class HAM_MGFTReviewTxnCtrlTest {

    @TestSetup
    static void setup() {
        // NOTE: This assumes the MGFT record type + related lookups (Contact,
        // Campaign, Designation) already exist in the org / are creatable in
        // a test context. Adjust field values below to match your sandbox's
        // required fields / validation rules if this fails to insert.

        Id mgftRtId = [
            SELECT Id FROM RecordType
            WHERE SobjectType = 'ucinn_ascendv2__Review_Transaction_v2__c'
              AND DeveloperName = 'MGFT'
            LIMIT 1
        ].Id;

        Contact c = new Contact(
            FirstName = 'Test',
            LastName = 'Donor',
            Suffix = 'Jr.'
        );
        insert c;

        Campaign camp = new Campaign(Name = 'Test Appeal');
        insert camp;

        ucinn_ascendv2__Designation__c d1 = new ucinn_ascendv2__Designation__c(
            Name = 'HAMFUND',
            ucinn_ascendv2__Designation_Name__c = 'Hamilton Fund'
        );
        insert d1;

        ucinn_ascendv2__Review_Transaction_v2__c txn = new ucinn_ascendv2__Review_Transaction_v2__c(
            RecordTypeId = mgftRtId,
            HAM_Data_Source__c = 'Portal - MakeAGift',
            ucinn_ascendv2__Transaction_Date__c = Date.today(),
            ucinn_ascendv2__Total_Transaction_Amount__c = 100,
            ucinn_ascendv2__Is_Anonymous__c = false,
            ucinn_ascendv2__Email_1__c = 'test@example.com',
            ucinn_ascendv2__Contact__c = c.Id,
            ucinn_ascendv2__Campaign__c = camp.Id,
            ucinn_ascendv2__Designation_1__c = d1.Id,
            // Required by an org validation rule ("Please specify an
            // external system ID for review transaction"). Any unique
            // string satisfies it in a test context.
            ucinn_ascendv2__External_System_ID__c = 'MGFT-' + String.valueOf(Crypto.getRandomInteger())
        );
        insert txn;
    }

    @IsTest
    static void testGetTransactionsNoFilters() {
        Test.startTest();
        List<HAM_MGFTReviewTxnCtrl.TransactionRow> rows =
            HAM_MGFTReviewTxnCtrl.getTransactions(new HAM_MGFTReviewTxnCtrl.FilterRequest());
        Test.stopTest();

        System.assertEquals(1, rows.size(), 'Expected exactly one seeded MGFT / Portal-MakeAGift row');
        System.assertEquals(100, rows[0].totalAmount);
        System.assertEquals('Hamilton Fund', rows[0].designations);
    }

    @IsTest
    static void testGetTransactionsWithFilters() {
        HAM_MGFTReviewTxnCtrl.FilterRequest filters = new HAM_MGFTReviewTxnCtrl.FilterRequest();
        filters.startDate = Date.today().addDays(-1);
        filters.endDate = Date.today().addDays(1);
        filters.donorName = 'Donor';

        Test.startTest();
        List<HAM_MGFTReviewTxnCtrl.TransactionRow> rows = HAM_MGFTReviewTxnCtrl.getTransactions(filters);
        Test.stopTest();

        System.assertEquals(1, rows.size());
    }

    @IsTest
    static void testGetTransactionsWithFiscalYearFilter() {
        HAM_MGFTReviewTxnCtrl.FilterRequest filters = new HAM_MGFTReviewTxnCtrl.FilterRequest();
        Integer currentFy = Date.today().month() >= 7 ? Date.today().year() + 1 : Date.today().year();
        filters.fiscalYear1 = 'FY' + currentFy;

        Test.startTest();
        List<HAM_MGFTReviewTxnCtrl.TransactionRow> rows = HAM_MGFTReviewTxnCtrl.getTransactions(filters);
        Test.stopTest();

        System.assertEquals(1, rows.size());
    }

    @IsTest
    static void testGetAppealCodeOptions() {
        Test.startTest();
        List<HAM_MGFTReviewTxnCtrl.SelectOption> options = HAM_MGFTReviewTxnCtrl.getAppealCodeOptions();
        Test.stopTest();

        System.assertEquals(1, options.size());
    }

    @IsTest
    static void testGetFiscalYearOptions() {
        Test.startTest();
        List<HAM_MGFTReviewTxnCtrl.SelectOption> options = HAM_MGFTReviewTxnCtrl.getFiscalYearOptions();
        Test.stopTest();

        System.assertEquals(8, options.size());
    }

    @IsTest
    static void testGetTodayTotalAmount() {
        Test.startTest();
        Decimal total = HAM_MGFTReviewTxnCtrl.getTodayTotalAmount();
        Test.stopTest();

        System.assertEquals(100, total, 'Expected today\'s total to match the single seeded transaction dated today');
    }
}