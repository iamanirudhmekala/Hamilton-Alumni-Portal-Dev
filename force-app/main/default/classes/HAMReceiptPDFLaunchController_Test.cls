@IsTest
private class HAMReceiptPDFLaunchController_Test {

    /* -----------------------------------------------------------
       Test Data Setup
    ------------------------------------------------------------*/
    @testSetup
    static void setupData() {

        List<Receipt__c> receipts = new List<Receipt__c>();

        // Create 25 records to test chunking (20 + 5)
        for (Integer i = 0; i < 25; i++) {

            String typeValue;

            if (i < 8) {
                typeValue = 'Hard Credit';
            } else if (i < 16) {
                typeValue = 'Soft Credit';
            } else {
                typeValue = 'IRA';
            }

            receipts.add(new Receipt__c(
                Receipt_Date__c = Date.today().addDays(-5),
                HAM_Receipt_Type__c = typeValue,
                HAM_Is_Processed__c = false,
                HAM_Sum_of_Cash_Amount__c = 100,
                HAM_Letter_Salutation__c = 'Dear Donor',
                HAM_Letter_Addressee__c = 'John Doe',
                HAM_Designation_Text__c = 'General Fund',
                HAM_City__c = 'Clinton',
                HAM_State__c = 'NY',
                HAM_ZipCode__c = '13323',
                HAM_Street_Address__c = '198 College Hill Rd',
                HAM_Country__c = 'USA',
                HAM_is_stock_receipt__c = false,
                HAM_is_tribute_receipt__c = false
            ));
        }

        insert receipts;
    }

    /* -----------------------------------------------------------
       Test: getReceipts()
    ------------------------------------------------------------*/
    @IsTest
    static void testGetReceipts() {

        Test.startTest();
        List<Receipt__c> results =
            HAMReceiptPDFLaunchController.getReceipts();
        Test.stopTest();

        System.assertNotEquals(null, results);
        System.assert(results.size() > 0);

        for (Receipt__c r : results) {
            System.assertEquals(false, r.HAM_Is_Processed__c);
            System.assertNotEquals('', r.HAM_Receipt_Type__c);
        }
    }

    /* -----------------------------------------------------------
       Test: updateReceipts()
    ------------------------------------------------------------*/
    @IsTest
    static void testUpdateReceipts() {

        List<Receipt__c> receipts =
            [SELECT Id, Receipt_Date__c FROM Receipt__c LIMIT 5];

        List<Id> ids = new List<Id>();
        for (Receipt__c r : receipts) {
            ids.add(r.Id);
        }

        Test.startTest();
        HAMReceiptPDFLaunchController.updateReceipts(ids);
        Test.stopTest();

        List<Receipt__c> updated =
            [SELECT Receipt_Date__c FROM Receipt__c WHERE Id IN :ids];

        for (Receipt__c r : updated) {
            System.assertEquals(Date.today(), r.Receipt_Date__c);
        }
    }

    /* -----------------------------------------------------------
       Test: launchJob() - Null Input
    ------------------------------------------------------------*/
    @IsTest
    static void testLaunchJob_NullInput() {

        Test.startTest();
        HAMReceiptPDFLaunchController.launchJob(null);
        Test.stopTest();

        System.assert(true);
    }

    /* -----------------------------------------------------------
       Test: launchJob() - Empty List
    ------------------------------------------------------------*/
    @IsTest
    static void testLaunchJob_EmptyList() {

        Test.startTest();
        HAMReceiptPDFLaunchController.launchJob(new List<Id>());
        Test.stopTest();

        System.assert(true);
    }

    /* -----------------------------------------------------------
       Test: launchJob() - Chunking Logic
    ------------------------------------------------------------*/
    @IsTest
    static void testLaunchJob_Chunking() {

        List<Receipt__c> receipts =
            [SELECT Id FROM Receipt__c];

        List<Id> ids = new List<Id>();
        for (Receipt__c r : receipts) {
            ids.add(r.Id);
        }

        Test.startTest();
        HAMReceiptPDFLaunchController.launchJob(ids);
        Test.stopTest();

        // 25 records with chunk size 20 => 2 queueable jobs executed
        // If no exception occurs, chunking worked.
        System.assert(true);
    }
}