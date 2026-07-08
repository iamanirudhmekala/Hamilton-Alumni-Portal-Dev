public class SandboxContactEmailInvalidationBatch implements Database.Batchable<Sobject>, Database.Stateful{
    private String query;
    private Integer recordsProcessed = 0;
    @TestVisible private Boolean isSandbox;

    public Database.QueryLocator start(Database.BatchableContext bc){
        query = 'SELECT Id, Email FROM Contact WHERE Email != \'\' AND (NOT Email LIKE \'%.invalid\')';
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<Contact> scope){
        if(isSandbox == null){
            isSandbox = [SELECT Id, IsSandbox FROM Organization].IsSandbox;
        }

        if(isSandbox){
            for(Contact c : scope){
                c.Email += '.invalid';
            }
            
            update scope;
        }else{
            System.debug('SandboxContactEmailInvalidationBatch cannot be ran in Production environments.');
        }
    }

    public void finish(Database.BatchableContext bc){
        System.debug('Records Processed: ' + String.valueOf(recordsProcessed));
    }
}