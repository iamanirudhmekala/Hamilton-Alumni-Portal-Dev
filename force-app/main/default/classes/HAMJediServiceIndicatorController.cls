public with sharing class HAMJediServiceIndicatorController {

    @AuraEnabled(cacheable=true)
    public static List<ucinn_ascendv2__Service_Indicator__c> getServiceIndicators(String contactId) {
        List<ucinn_ascendv2__Service_Indicator__c> serviceIndicators = new List<ucinn_ascendv2__Service_Indicator__c>();

        if (String.isBlank(contactId)) {
            return serviceIndicators;
        }

        // Query Service Indicators for the given Contact
        serviceIndicators = [
            SELECT Id,
                   Name,
                   ucinn_ascendv2__Contact__c,
                   ucinn_ascendv2__Service_Indicator_Value__c,
                   ucinn_ascendv2__Service_Indicator_Value__r.Name,
                   ucinn_ascendv2__Service_Indicator_Value__r.HAM_Is_Visible_On_Portal__c,
                   ucinn_ascendv2__Service_Indicator_Description_Formula__c,
                   ucinn_ascendv2__Code_Formula__c,
                   ucinn_ascendv2__Start_Date__c,
                   ucinn_ascendv2__End_Date__c,
                   ucinn_ascendv2__Is_Active__c,
                   ucinn_ascendv2__Comments__c
            FROM ucinn_ascendv2__Service_Indicator__c
            WHERE ucinn_ascendv2__Contact__c = :contactId
            ORDER BY ucinn_ascendv2__Is_Active__c DESC, ucinn_ascendv2__Start_Date__c DESC NULLS LAST
        ];

        return serviceIndicators;
    }
}