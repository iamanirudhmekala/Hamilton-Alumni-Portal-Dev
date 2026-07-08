public class HAM_TriviaTriggerHandler {

    public static void afterInsert(List<HAM_Trivia__c> newRecords,List<HAM_Trivia__c> oldRecords) {
        set<Id> newIds = new set<Id>();
        for (HAM_Trivia__c trivia : newRecords) {
             newIds.add(trivia.Id);
        }
        
        List<HAM_Trivia__c> triviaList = [SELECT Id,Show_On_Portal__c,CreatedDate FROM HAM_Trivia__c WHERE Id NOT IN :newIds AND CreatedDate < TODAY AND Show_On_Portal__c = True ];
        //System.debug('triviaList : ' + triviaList);
        
        for(HAM_Trivia__c vartrivia : triviaList){
            vartrivia.Show_On_Portal__c = false;
        }
        
        update triviaList;
    }
}