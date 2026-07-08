@IsTest
private class HAM_ReceiptPDFQueueable_Test {

    @IsTest
    static void testFullExecutionPath() {

        Receipt__c r = new Receipt__c(
            Receipt_Date__c = Date.today(),
            HAM_Receipt_Type__c = 'Hard Credit',
            HAM_Is_Processed__c = false
        );
        insert r;

        Map<String,
            HAM_ReceiptPDFQueueable.ReceiptPageWrapper> testMap =
            new Map<String,
                HAM_ReceiptPDFQueueable.ReceiptPageWrapper>();

        HAM_ReceiptPDFQueueable.ReceiptPageWrapper wrapper =
            new HAM_ReceiptPDFQueueable.ReceiptPageWrapper(
                'TestBrandedPage',
                'TestUnbrandedPage'
            );

        testMap.put('Hard Credit', wrapper);

        HAM_ReceiptPDFQueueable.testMappingOverride =
            testMap;

        Test.startTest();

        System.enqueueJob(
            new HAM_ReceiptPDFQueueable(
                new List<Id>{ r.Id }
            )
        );

        Test.stopTest();

        Receipt__c updated = [
            SELECT HAM_Is_Processed__c
            FROM Receipt__c
            WHERE Id = :r.Id
        ];

        System.assertEquals(
            true,
            updated.HAM_Is_Processed__c
        );

        List<ContentVersion> versions = [
            SELECT Id
            FROM ContentVersion
        ];

        System.assertEquals(2, versions.size());

        List<ContentDocumentLink> links = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :r.Id
        ];

        System.assertEquals(2, links.size());
    }
}