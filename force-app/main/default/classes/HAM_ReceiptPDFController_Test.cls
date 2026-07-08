@IsTest
private class HAM_ReceiptPDFController_Test {

    @IsTest
    static void testControllerFullData() {

        Receipt__c r = new Receipt__c(
           
            Receipt_Date__c = Date.today(),
            HAM_Letter_Salutation__c = 'Dear Donor',
            HAM_Letter_Addressee__c = 'John Doe',
            HAM_Designation_Text__c = 
                '• $50 to Fund A\n• $75 to Fund B',
            HAM_Stock_Text__c =
                '100 Shares of XYZ\n200 Shares of ABC',
            HAM_Tribute_Text__c =
                'In honor of Jane\nIn memory of Bob',
            HAM_is_stock_receipt__c = true,
            HAM_is_tribute_receipt__c = true,
            HAM_Country__c = 'Canada'
        );
        insert r;

        // Set page parameter
        Test.setCurrentPage(
            new PageReference('/apex/TestPage')
        );
        ApexPages.currentPage().getParameters()
            .put('id', r.Id);

        Test.startTest();
        HAM_ReceiptPDFController controller =
            new HAM_ReceiptPDFController();
        Test.stopTest();

        System.assertNotEquals(
            null,
            controller.receipt
        );

        System.assertEquals(
            2,
            controller.givingSummary.size(),
            'Should split designation lines'
        );

        System.assertEquals(
            2,
            controller.stockGifts.size(),
            'Should split stock lines'
        );

        System.assertEquals(
            2,
            controller.tributeGifts.size(),
            'Should split tribute lines'
        );

        System.assertEquals(
            true,
            controller.isStockReceipt
        );

        System.assertEquals(
            true,
            controller.isTributeReceipt
        );

        System.assertEquals(
            true,
            controller.showCountry,
            'Country should show when not US'
        );
    }

    @IsTest
    static void testControllerUnitedStatesCountry() {

        Receipt__c r = new Receipt__c(
            
            Receipt_Date__c = Date.today(),
            HAM_Country__c = 'United States',
            HAM_is_stock_receipt__c = false,
            HAM_is_tribute_receipt__c = false
        );
        insert r;

        Test.setCurrentPage(
            new PageReference('/apex/TestPage')
        );
        ApexPages.currentPage().getParameters()
            .put('id', r.Id);

        HAM_ReceiptPDFController controller =
            new HAM_ReceiptPDFController();

        System.assertEquals(
            false,
            controller.showCountry,
            'Country should not show for US'
        );

        System.assertEquals(
            false,
            controller.isStockReceipt
        );

        System.assertEquals(
            false,
            controller.isTributeReceipt
        );
    }

    @IsTest
    static void testControllerNoIdParameter() {

        Test.setCurrentPage(
            new PageReference('/apex/TestPage')
        );

        HAM_ReceiptPDFController controller =
            new HAM_ReceiptPDFController();

        System.assertEquals(
            null,
            controller.receipt
        );
    }
}