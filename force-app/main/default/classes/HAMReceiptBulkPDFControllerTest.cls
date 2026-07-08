@isTest
private class HAMReceiptBulkPDFControllerTest {
    
    @isTest
    static void testGetRecordIds() {
        List<Receipt__c> testReceipts = new List<Receipt__c>();
        for (Integer i = 0; i < 3; i++) {
            testReceipts.add(new Receipt__c());
        }
        insert testReceipts;
        
        Test.startTest();
        ApexPages.StandardSetController ssc = new ApexPages.StandardSetController(testReceipts);
        ssc.setSelected(testReceipts);
        
        HAMReceiptBulkPDFController ext = new HAMReceiptBulkPDFController(ssc);
        List<String> ids = ext.getRecordIds();
        Test.stopTest();
        
        System.assertEquals(3, ids.size(), 'Should return 3 record IDs');
        for (Receipt__c r : testReceipts) {
            System.assert(ids.contains(r.Id), 'Should contain ID: ' + r.Id);
        }
    }
}