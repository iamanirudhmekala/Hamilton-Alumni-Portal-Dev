/**
 * @author Kindsight
 * @date 3/25/2026
 * @description Batch Job to generate GL Records
 * @script Database.executeBatch(new ham_BATCH_GLFeeder());
 */
public class ham_BATCH_GLFeeder implements Database.Batchable<SObject> {
    List<String> paymentFields = new List<String>{'Id', 'Name', 
        'HAM_Contact_Name_and_Donor_ID__c', 
        'HAM_Clearing_Account__c', 
        'ucinn_ascendv2__Adjusted_Gift__c',
        'ucinn_ascendv2__Account__c', 
        'ucinn_ascendv2__Account__r.Name', 
        'ucinn_ascendv2__Contact__c', 
        'ucinn_ascendv2__Contact__r.FirstName', 
        'ucinn_ascendv2__Contact__r.LastName', 
        'ucinn_ascendv2__Donor_ID_Formula__c', 
        'ucinn_ascendv2__Designation__c', 
        'ucinn_ascendv2__Designation__r.ucinn_ascendv2__G_L_Account__c', 
        'ucinn_ascendv2__Designation__r.HAM_Workday_Revenue_Category__c', 
        'ucinn_ascendv2__Designation__r.HAM_Workday_Program__c', 
        'ucinn_ascendv2__Designation__r.HAM_Workday_Fund__c', 
        'ucinn_ascendv2__Designation__r.HAM_Workday_Cost_Center__c', 
        'ucinn_ascendv2__Opportunity__c', 
        'ucinn_ascendv2__Opportunity__r.Name', 
        'ucinn_ascendv2__Payment_Amount__c', 
        'ucinn_ascendv2__Session__c', 
        'ucinn_ascendv2__Session__r.Id', 
        'ucinn_ascendv2__Session__r.ucinn_ascendv2__Session_Date__c' 
    };

    public Database.QueryLocator start(Database.BatchableContext bc) {
        String query = 'SELECT Id, ' +
                            '(SELECT ' + String.join(this.paymentFields, ', ') + 
                            ' FROM ucinn_ascendv2__Payments_Session__r ' +
                            ' WHERE ucinn_ascendv2__Send_to_G_L__c = true ' +
                            ' AND ucinn_ascendv2__Sent_to_G_L_Date__c = null) ' +
                        'FROM ucinn_ascendv2__Session__c ' +
                        'WHERE ucinn_ascendv2__Is_Ready_for_G_L__c = true ' +
                        'AND ucinn_ascendv2__Is_Sent_to_G_L__c = false ' +
                        'AND HAM_Is_Sent_to_GL_Feeder__c = false';

        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<ucinn_ascendv2__Session__c> sessions) {
        List<GL_Feeder__c> feedersToInsert = new List<GL_Feeder__c>();
        List<ucinn_ascendv2__Session__c> sessionsToUpdate = new List<ucinn_ascendv2__Session__c>();
        Set<Id> adjustedGiftIds = new Set<Id>();

        for (ucinn_ascendv2__Session__c session : sessions) {
            if (session.ucinn_ascendv2__Payments_Session__r == null || session.ucinn_ascendv2__Payments_Session__r.isEmpty()) {
                continue;
            }

            for (ucinn_ascendv2__Payment__c payment : session.ucinn_ascendv2__Payments_Session__r) {
                GL_Feeder__c feeder = generateFeeder(payment, false);

                feedersToInsert.add(feeder);
                
                if(payment.ucinn_ascendv2__Adjusted_Gift__c != null){
                    adjustedGiftIds.add(payment.ucinn_ascendv2__Adjusted_Gift__c);
                }
            }

            sessionsToUpdate.add(new ucinn_ascendv2__Session__c(
                Id = session.Id,
                HAM_Is_Sent_to_GL_Feeder__c = true
            ));
        }
        
        if(!adjustedGiftIds.isEmpty()){
            String query = 'SELECT ' + String.join(this.paymentFields, ', ') + 
                            ' FROM ucinn_ascendv2__Payment__c ' +               
                            ' WHERE ucinn_ascendv2__Opportunity__c IN: adjustedGiftIds';
            List<ucinn_ascendv2__Payment__c> adjustedPayments = Database.query(query);
            
            for(ucinn_ascendv2__Payment__c payment: adjustedPayments){                
                GL_Feeder__c feeder = generateFeeder(payment, true);

                feedersToInsert.add(feeder);
            }
        }

        if (!feedersToInsert.isEmpty()) {
            insert feedersToInsert;
        }

        if (!sessionsToUpdate.isEmpty()) {
            update sessionsToUpdate;
        }
    }
    
    public GL_Feeder__c generateFeeder(ucinn_ascendv2__Payment__c payment, Boolean adjusted){
        GL_Feeder__c feeder = new GL_Feeder__c();

        feeder.Payment__c = payment.Id;
        feeder.External_Reference_ID__c = payment.Name;
        feeder.Constituent__c = payment.ucinn_ascendv2__Contact__c;
        feeder.Organization__c = payment.ucinn_ascendv2__Account__c;
        
        feeder.Amount__c = adjusted ? -1 * payment.ucinn_ascendv2__Payment_Amount__c : payment.ucinn_ascendv2__Payment_Amount__c;
        feeder.Legacy_GL_Account__c = payment.HAM_Clearing_Account__c?.replace('-', '');
        
        String donorName = '';
        
        if(payment.ucinn_ascendv2__Contact__c != null){
            donorName = payment.ucinn_ascendv2__Contact__r.FirstName + ' ' + payment.ucinn_ascendv2__Contact__r.LastName; 
        }
        else{
            donorName = payment.ucinn_ascendv2__Account__r != null ? payment.ucinn_ascendv2__Account__r.Name : '';
        }
        
        feeder.Donor_Name__c = donorName;
        feeder.memo__c = payment.HAM_Contact_Name_and_Donor_ID__c + ' | ' + payment.Name;
        feeder.Donor_Name_Custom_Field__c = payment.ucinn_ascendv2__Donor_ID_Formula__c;
        feeder.Donor_Reference_ID__c = payment.ucinn_ascendv2__Donor_ID_Formula__c;
        
        feeder.Journal_ID__c = payment.ucinn_ascendv2__Session__c;
        feeder.Session__c = payment.ucinn_ascendv2__Session__c;
        feeder.Journal_Date__c = payment.ucinn_ascendv2__Session__r.ucinn_ascendv2__Session_Date__c;
        
        feeder.Designation__c = payment.ucinn_ascendv2__Designation__c;	
        feeder.Revenue_Category__c = payment.ucinn_ascendv2__Designation__r.HAM_Workday_Revenue_Category__c;
        feeder.Ledger_Account__c = payment.ucinn_ascendv2__Designation__r.ucinn_ascendv2__G_L_Account__c;
        feeder.Program__c = payment.ucinn_ascendv2__Designation__r.HAM_Workday_Program__c;
        feeder.Fund__c = payment.ucinn_ascendv2__Designation__r.HAM_Workday_Fund__c;
        
        if(!String.isBlank(feeder.Ledger_Account__c) && feeder.Ledger_Account__c.length() >= 9){
            feeder.Gift_ID__c = feeder.Ledger_Account__c.substring(3, 9);   
        }
        
        feeder.Pledge_Gift__c = payment.ucinn_ascendv2__Opportunity__c;
        
        return feeder;
    }

    public void finish(Database.BatchableContext bc) {
    }
}