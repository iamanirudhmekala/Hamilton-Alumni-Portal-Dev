public class SandboxEmailInvalidationBatch implements Database.Batchable<Sobject>, Database.Stateful{
    private String query;
    private Integer recordsProcessed = 0;
    @TestVisible private Boolean isSandbox;

    public Database.QueryLocator start(Database.BatchableContext bc){
        query = 'SELECT Id, ucinn_ascendv2__Email_Address__c, ucinn_ascendv2__Is_Preferred__c, ucinn_ascendv2__Status__c FROM ucinn_ascendv2__Email__c WHERE ucinn_ascendv2__Is_Preferred__c = true';
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<ucinn_ascendv2__Email__c> scope){
        if(isSandbox == null){
            isSandbox = [SELECT Id, IsSandbox FROM Organization].IsSandbox;
        }

        if(isSandbox){
            for(ucinn_ascendv2__Email__c e : scope){
                e.ucinn_ascendv2__Email_Address__c += '.invalid';
            }
            
            update scope;
            recordsProcessed += scope.size();
        }else{
            System.debug('SandboxEmailInvalidationBatch cannot be ran in Production environments.');
        }
    }

    public void finish(Database.BatchableContext bc){
        System.debug('Records Processed: ' + String.valueOf(recordsProcessed));
        if(isSandbox){
            SandboxContactEmailInvalidationBatch contactEmailCleanUp = new SandboxContactEmailInvalidationBatch();
            Id batchJobId = Database.executeBatch(contactEmailCleanUp, 200);
        }
    }
}