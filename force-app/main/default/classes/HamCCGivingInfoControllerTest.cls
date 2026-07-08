@IsTest
private class HamCCGivingInfoControllerTest {

    /* ============================
     * Test Data Setup
     * ============================ */
    @TestSetup
    static void setupData() {

        // ----------------------------
        // Account (Non-Alumni)
        // ----------------------------
        Account acct = new Account(
            Name = 'Test Household',
            ucinn_ascendv2__Lifetime_Fundraising__c = 25000,
            ucinn_ascendv2__Amount_of_Largest_Gift__c = 10000
        );
        insert acct;

        // ----------------------------
        // Contact (Alumni)
        // ----------------------------
        Contact con = new Contact(
            LastName = 'Test Contact',
            AccountId = acct.Id,
            HAM_Largest_Gift_Amount__c = 15000,
            HAM_Current_Year_Hamilton_Fund_Collected__c = 3000,
            HAM_Total_Years_of_Giving__c = 5,
            HAM_1812__c = true,
            HAM_Ten_to_Fifth__c = true,
            HAM_Chapel_Bell__c = true
        );
        insert con;

        // ----------------------------
        // Record Type: Last 5 year Giving
        // ----------------------------
        Id givingRTId = Schema.SObjectType.HAM_Pledge_Balance__c
            .getRecordTypeInfosByName()
            .get('Last 5 year Giving')
            .getRecordTypeId();

        // ----------------------------
        // Pledge Balance (Alumni)
        // ----------------------------
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

    /* ============================
     * getGivingInfo – Alumni
     * ============================ */
    @IsTest
    static void testGetGivingInfo_Alumni() {
        Contact c = [SELECT Id FROM Contact LIMIT 1];

        Test.startTest();
        List<HAM_Pledge_Balance__c> results =
            HamCCGivingInfoController.getGivingInfo(c.Id, true);
        Test.stopTest();

        System.assertNotEquals(null, results);
        System.assertEquals(1, results.size(), 'One pledge record expected');

        HAM_Pledge_Balance__c pb = results[0];
        System.assertEquals('Annual Fund', pb.HAM_Designation__c);
        System.assertEquals(5000, pb.HAM_Paid__c);
        System.assertNotEquals(null, pb.CreatedDate);
    }

    /* ============================
     * getGivingInfo – Null Guard
     * ============================ */
    @IsTest
    static void testGetGivingInfo_NullId() {
        Test.startTest();
        List<HAM_Pledge_Balance__c> results =
            HamCCGivingInfoController.getGivingInfo(null, true);
        Test.stopTest();

        System.assertEquals(0, results.size());
    }

    /* ============================
     * getContactAccountData – Alumni
     * ============================ */
    @IsTest
    static void testGetContactAccountData_Alumni() {
        Contact c = [
            SELECT Id,
                   HAM_Lifetime_Paid__c,
                   HAM_Largest_Gift_Amount__c,
                   HAM_Current_Year_Hamilton_Fund_Collected__c,
                   HAM_Total_Years_of_Giving__c
            FROM Contact LIMIT 1
        ];

        Test.startTest();
        Map<String, Object> data =
            HamCCGivingInfoController.getContactAccountData(c.Id, true);
        Test.stopTest();

        System.assertEquals(
            (Decimal)(c.HAM_Lifetime_Paid__c == null ? 0 : c.HAM_Lifetime_Paid__c),
            data.get('lifetimeGiving')
        );

        System.assertEquals(
            (Decimal)(c.HAM_Largest_Gift_Amount__c == null ? 0 : c.HAM_Largest_Gift_Amount__c),
            data.get('largestGift')
        );

        System.assertEquals(
            (Decimal)c.HAM_Current_Year_Hamilton_Fund_Collected__c,
            data.get('thisYear')
        );

        System.assertEquals(
            (Integer)c.HAM_Total_Years_of_Giving__c,
            data.get('yearsOfGiving')
        );
    }

    /* ============================
     * getContactAccountData – Account
     * ============================ */
    @IsTest
    static void testGetContactAccountData_Account() {
        Account acct = [
            SELECT Id,
                   ucinn_ascendv2__Lifetime_Fundraising__c,
                   ucinn_ascendv2__Amount_of_Largest_Gift__c
            FROM Account LIMIT 1
        ];

        Test.startTest();
        Map<String, Object> data =
            HamCCGivingInfoController.getContactAccountData(acct.Id, false);
        Test.stopTest();

        System.assertEquals(
            (Decimal)acct.ucinn_ascendv2__Lifetime_Fundraising__c,
            data.get('lifetimeGiving')
        );

        System.assertEquals(
            (Decimal)acct.ucinn_ascendv2__Amount_of_Largest_Gift__c,
            data.get('largestGift')
        );

        System.assertEquals(0, data.get('thisYear'));
        System.assertEquals(0, data.get('yearsOfGiving'));
    }

    /* ============================
     * getContactAccountData – Null Guard
     * ============================ */
    @IsTest
    static void testGetContactAccountData_NullId() {
        Test.startTest();
        Map<String, Object> data =
            HamCCGivingInfoController.getContactAccountData(null, true);
        Test.stopTest();

        System.assertEquals(0, data.size());
    }

    /* ============================
     * getContactFullData – Positive
     * ============================ */
    @IsTest
    static void testGetContactFullData() {
        Contact c = [SELECT Id FROM Contact LIMIT 1];

        Test.startTest();
        Contact result =
            HamCCGivingInfoController.getContactFullData(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(c.Id, result.Id);
        System.assertEquals(true, result.HAM_1812__c);
    }

    /* ============================
     * getContactFullData – Null Guard
     * ============================ */
    @IsTest
    static void testGetContactFullData_Null() {
        Test.startTest();
        Contact c = HamCCGivingInfoController.getContactFullData(null);
        Test.stopTest();

        System.assertEquals(null, c);
    }
}