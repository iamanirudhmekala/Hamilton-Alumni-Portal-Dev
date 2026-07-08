public with sharing class HAM_ReceiptPDFController {
    public Receipt__c receipt { get; set; }
    public Boolean isStockReceipt { get; set; }
    public Boolean isTributeReceipt { get; set; }
    public List<String> givingSummary { get; set; }
    public List<String> stockGifts { get; set; }
    public List<String> tributeGifts { get; set; }
    public Boolean showCountry { get; set; }

    public HAM_ReceiptPDFController() {
        Id receiptId = ApexPages.currentPage().getParameters().get('id');

        if(receiptId != null){

            receipt = [
                SELECT Id,
                       Name,
                       Receipt_Date__c,
                       HAM_Sum_of_Cash_Amount__c,
                       HAM_Letter_Salutation__c,
                       HAM_Letter_Addressee__c,
                       HAM_Designation_Text__c,
                       HAM_City__c,
                       HAM_State__c,
                       HAM_ZipCode__c,
                       HAM_Street_Address__c,
                       HAM_Country__c,
                       HAM_Stock_Text__c,
                       HAM_is_stock_receipt__c,
                       HAM_Tribute_Text__c,
                       HAM_is_tribute_receipt__c
                FROM Receipt__c
                WHERE Id = :receiptId
                LIMIT 1
            ];

            givingSummary = new List<String>();
            stockGifts = new List<String>();
            tributeGifts = new List<String>();
            if(receipt != null ){

            
                if(String.isNotBlank(receipt.HAM_Designation_Text__c)) {

                    // Handles both Windows (\r\n) and Unix (\n) line endings
                    List<String> rawLines = receipt.HAM_Designation_Text__c
                        .split('\\r?\\n');
                    
                    for(String line : rawLines){
                        if(String.isNotBlank(line)){
                            givingSummary.add(line.trim());
                        }
                    }
                }
               
                if(String.isNotBlank(receipt.HAM_Stock_Text__c)) {

                    // Handles both Windows (\r\n) and Unix (\n) line endings
                    List<String> rawLines1 = receipt.HAM_Stock_Text__c
                        .split('\\r?\\n');
                    
                    for(String line : rawLines1){
                        if(String.isNotBlank(line)){
                            stockGifts.add(line.trim());
                        }
                    }
                }
                if(String.isNotBlank(receipt.HAM_Tribute_Text__c)) {

                    // Handles both Windows (\r\n) and Unix (\n) line endings
                    List<String> rawLines2 = receipt.HAM_Tribute_Text__c
                        .split('\\r?\\n');
                    
                    for(String line : rawLines2){
                        if(String.isNotBlank(line)){
                            tributeGifts.add(line.trim());
                        }
                    }
                }
            }
            showCountry = receipt.HAM_Country__c != 'United States' && receipt.HAM_Country__c != '' && receipt.HAM_Country__c != null;
            isStockReceipt = receipt.HAM_is_stock_receipt__c;
            isTributeReceipt = receipt.HAM_is_tribute_receipt__c;
        }
    }
}