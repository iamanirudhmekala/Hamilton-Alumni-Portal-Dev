trigger HamConnectionTrigger on HAM_Connection__c(after insert, after update, after delete) {
    
    if (Trigger.isAfter) {
        // Handle New Records
        if (Trigger.isInsert) {
            HAM_ConnectionTriggerHandler.onAfterInsert(Trigger.new);
        }
        
        // Handle Updates (Pass oldMap to detect status changes)
        else if (Trigger.isUpdate) {
            HAM_ConnectionTriggerHandler.onAfterUpdate(Trigger.new, Trigger.oldMap);
        }
        
        // Handle Deletions
        else if (Trigger.isDelete) {
            HAM_ConnectionTriggerHandler.onAfterDelete(Trigger.old);
        }
    }
}