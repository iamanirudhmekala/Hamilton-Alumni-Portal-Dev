public class HAMReceiptBulkPDFController {
    
    private List<Receipt__c> selectedRecords;
    
    public HAMReceiptBulkPDFController(ApexPages.StandardSetController controller) {
        selectedRecords = (List<Receipt__c>) controller.getSelected();
    }
    
    public List<String> getRecordIds() {
        List<String> ids = new List<String>();
        for (Receipt__c r : selectedRecords) {
            ids.add(r.Id);
        }
        return ids;
    }
}