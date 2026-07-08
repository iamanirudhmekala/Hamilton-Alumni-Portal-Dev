// To run manually after a bulk data load:
// Database.executeBatch(new HAM_ServiceIndicatorFlagBatch(), 200);
public with sharing class HAM_ServiceIndicatorFlagBatch implements Database.Batchable<SObject>, Database.Stateful {

    private static final Set<String> SI_NAMES = new Set<String>{
        'Do Not Send Athletic Updates',
        'Do Not Send College Updates',
        'Do Not Send Event Invitations',
        'Do Not Send Hamilton Headlines',
        'Do Not Send Virtual Events Digest',
        'Do Not Sent Impact Report',
        'No Hamilton Calendar'
    };

    private static final Map<String, String> SI_TO_FIELD = new Map<String, String>{
        'Do Not Send Athletic Updates'      => 'HAM_Send_Athletic_Updates__c',
        'Do Not Send College Updates'       => 'HAM_Send_College_Updates__c',
        'Do Not Send Event Invitations'     => 'HAM_Send_Event_Invitations__c',
        'Do Not Send Hamilton Headlines'    => 'HAM_Send_Hamilton_Headlines__c',
        'Do Not Send Virtual Events Digest' => 'HAM_Send_Virtual_Events_Digest__c',
        'Do Not Sent Impact Report'         => 'HAM_Send_Impact_Report__c',
        'No Hamilton Calendar'              => 'HAM_Hamilton_Calendar__c'
    };

    public Database.QueryLocator start(Database.BatchableContext bc) {
        // SOQL does not allow semi-join subqueries combined with OR, so collect SI contact IDs first
        Set<Id> siContactIds = new Set<Id>();
        for (ucinn_ascendv2__Service_Indicator__c si : [
            SELECT ucinn_ascendv2__Contact__c
            FROM ucinn_ascendv2__Service_Indicator__c
            WHERE ucinn_ascendv2__Service_Indicator_Value__r.Name IN :SI_NAMES
        ]) {
            siContactIds.add(si.ucinn_ascendv2__Contact__c);
        }

        return Database.getQueryLocator([
            SELECT Id,
                   HAM_Send_Athletic_Updates__c,
                   HAM_Send_College_Updates__c,
                   HAM_Send_Event_Invitations__c,
                   HAM_Send_Hamilton_Headlines__c,
                   HAM_Send_Virtual_Events_Digest__c,
                   HAM_Send_Impact_Report__c,
                   HAM_Hamilton_Calendar__c
            FROM Contact
            WHERE Id IN :siContactIds
            OR HAM_Send_Athletic_Updates__c = null
            OR HAM_Send_College_Updates__c = null
            OR HAM_Send_Event_Invitations__c = null
            OR HAM_Send_Hamilton_Headlines__c = null
            OR HAM_Send_Virtual_Events_Digest__c = null
            OR HAM_Send_Impact_Report__c = null
            OR HAM_Hamilton_Calendar__c = null
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Contact> scope) {
        Set<Id> contactIds = new Set<Id>();
        for (Contact c : scope) {
            contactIds.add(c.Id);
        }

        // ContactId → (SI Value Name → isActive)
        Map<Id, Map<String, Boolean>> siByContact = new Map<Id, Map<String, Boolean>>();
        for (ucinn_ascendv2__Service_Indicator__c si : [
            SELECT ucinn_ascendv2__Contact__c,
                   ucinn_ascendv2__Service_Indicator_Value__r.Name,
                   ucinn_ascendv2__Is_Active__c
            FROM ucinn_ascendv2__Service_Indicator__c
            WHERE ucinn_ascendv2__Contact__c IN :contactIds
              AND ucinn_ascendv2__Service_Indicator_Value__r.Name IN :SI_NAMES
        ]) {
            Id cId = si.ucinn_ascendv2__Contact__c;
            String siName = si.ucinn_ascendv2__Service_Indicator_Value__r.Name;
            if (!siByContact.containsKey(cId)) {
                siByContact.put(cId, new Map<String, Boolean>());
            }
            // If any SI for this name is active, the flag should be false
            Boolean currentActive = siByContact.get(cId).containsKey(siName)
                ? siByContact.get(cId).get(siName)
                : false;
            siByContact.get(cId).put(siName, currentActive || si.ucinn_ascendv2__Is_Active__c);
        }

        List<Contact> toUpdate = new List<Contact>();
        for (Contact c : scope) {
            // Default all 7 flags to true
            for (String fieldName : SI_TO_FIELD.values()) {
                c.put(fieldName, true);
            }
            // Apply active SIs
            if (siByContact.containsKey(c.Id)) {
                for (String siName : siByContact.get(c.Id).keySet()) {
                    if (siByContact.get(c.Id).get(siName)) {
                        String fieldName = SI_TO_FIELD.get(siName);
                        if (fieldName != null) {
                            c.put(fieldName, false);
                        }
                    }
                }
            }
            toUpdate.add(c);
        }

        update toUpdate;
    }

    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.INFO, 'HAM_ServiceIndicatorFlagBatch complete. Job ID: ' + bc.getJobId());
    }
}