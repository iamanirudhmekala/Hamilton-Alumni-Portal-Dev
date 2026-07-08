public with sharing class HAMReceiptPDFLaunchController {
    @AuraEnabled(cacheable=true)
    public static void launchJob(List<Id> recordIds) {

       if (recordIds == null || recordIds.isEmpty()) {
            return;
        }

        Integer chunkSize = 20;
        Integer totalSize = recordIds.size();

        for (Integer i = 0; i < totalSize; i += chunkSize) {

            List<Id> chunk = new List<Id>();

            Integer lastElement = Math.min(i + chunkSize, totalSize);

            for (Integer j = i; j < lastElement; j++) {
                chunk.add(recordIds[j]);
            }

            System.enqueueJob(
                new HAM_ReceiptPDFQueueable(chunk)
            );
        }
    }
    @AuraEnabled(cacheable=true)
    public static List<Receipt__c> getReceipts() {
       
            return [
                SELECT Id,
                    Name,
                    Receipt_Date__c,
                    HAM_Receipt_Type__c,
                    HAM_Constituent__c,
                    HAM_Constituent__r.HAM_Name_w_Suffix__c,
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
                    HAM_is_tribute_receipt__c,
                    HAM_Is_Processed__c
                FROM Receipt__c
                WHERE HAM_Receipt_Type__c != '' 
                AND HAM_Is_Processed__c = FALSE
                ORDER BY Receipt_Date__c DESC
            ];
       
    }

    @AuraEnabled(cacheable=true)
    public static void updateReceipts(List<Id> recordIds) {
        List<Receipt__c> selectedReceipts = [  SELECT Id,
                                                      Name,
                                                      Receipt_Date__c
                                                FROM Receipt__c
                                                WHERE ID IN: recordIds];
        for(Receipt__c receipt :selectedReceipts){
            receipt.Receipt_Date__c = date.today();
        }
        system.debug('selectedReceipts------'+selectedReceipts);
        List<Database.SaveResult> results = Database.update(selectedReceipts, false);
        System.debug('results-------->'+results);

    }
}