trigger HAM_TriviaTrigger on HAM_Trivia__c (after insert) {
    
    if (Trigger.isAfter && Trigger.isInsert) {
        HAM_TriviaTriggerHandler.afterInsert(Trigger.new,Trigger.old);
    }
}