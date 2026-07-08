public with sharing class HAMUpdateContactCurrentChapter implements Database.Batchable<SObject> {
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(
            'SELECT Id, HAM_Current_Chapters__c FROM Contact WHERE ucinn_ascendv2__Preferred_Address_Formula__c != NULL'
        );
    }

    public void execute(Database.BatchableContext bc, List<Contact> scope) {

        for (Contact con : scope) {
            if (String.isBlank(con.HAM_Current_Chapters__c)) {
                continue;
            }

            List<String> cleanedValues = new List<String>();

            for (String chapter : con.HAM_Current_Chapters__c.split(',')) {
                cleanedValues.add(chapter.split('-')[0].trim());
            }

            con.HAM_Current_Chapters__c = String.join(cleanedValues, ', ');
        }

        update scope;
    }

    public void finish(Database.BatchableContext bc) {
        // Optional: logging or notification
    }
}