//Database.executeBatch(new HAMPopulateProspectStageBatch(), 200);
public with sharing class HAMPopulateProspectStageBatch implements Database.Batchable<SObject>, Database.Stateful {

    private List<DmlException> errors = new List<DmlException>();

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, AccountId
            FROM Contact
            WHERE AccountId != null
            AND HAM_Household_Prospect_Stage__c = null
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Contact> scope) {
        Set<Id> accountIds = new Set<Id>();
        for (Contact c : scope) {
            accountIds.add(c.AccountId);
        }

        Map<Id, ucinn_ascendv2__Wealth_Rating__c> accountToWealthRating = new Map<Id, ucinn_ascendv2__Wealth_Rating__c>();
        for (ucinn_ascendv2__Wealth_Rating__c wr : [
            SELECT Id, ucinn_ascendv2__Account__c, HAM_Stage__c
            FROM ucinn_ascendv2__Wealth_Rating__c
            WHERE ucinn_ascendv2__Account__c IN :accountIds
            AND RecordType.Name = 'Prospect Stage'
            AND HAM_Stage__c != null
            AND HAM_Status__c = 'Current'
            ORDER BY CreatedDate DESC
        ]) {
            if (!accountToWealthRating.containsKey(wr.ucinn_ascendv2__Account__c)) {
                accountToWealthRating.put(wr.ucinn_ascendv2__Account__c, wr);
            }
        }

        List<Contact> toUpdate = new List<Contact>();
        for (Contact c : scope) {
            if (accountToWealthRating.containsKey(c.AccountId)) {
                c.HAM_Household_Prospect_Stage__c = accountToWealthRating.get(c.AccountId).HAM_Stage__c;
                toUpdate.add(c);
            }
        }

        if (!toUpdate.isEmpty()) {
            try {
                update toUpdate;
            } catch (DmlException ex) {
                errors.add(ex);
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        for (DmlException ex : errors) {
            System.debug('HAMPopulateProspectStageBatch error: ' + ex.getMessage());
        }
        System.debug('HAMPopulateProspectStageBatch finished. Total errors: ' + errors.size());
    }
}