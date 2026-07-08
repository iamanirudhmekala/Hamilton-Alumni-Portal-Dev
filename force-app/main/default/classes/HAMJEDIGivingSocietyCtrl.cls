public with sharing class HAMJEDIGivingSocietyCtrl {

    @AuraEnabled(cacheable=true)
    public static List<ucinn_ascendv2__Society_Membership__c> getSocietyMemberships(String contactId) {
        return [
            SELECT Id,
                Name,
                ucinn_ascendv2__Contact__c,
                ucinn_ascendv2__Giving_Society__c,
                ucinn_ascendv2__Giving_Society__r.Name,
                ucinn_ascendv2__Membership_Level__c,
                ucinn_ascendv2__Membership_Status__c,
                ucinn_ascendv2__Anniversary_Date__c,
                ucinn_ascendv2__Member_Since__c,
                ucinn_ascendv2__Expiration_Date__c,
                Current_Fiscal_Year_Member__c,
                HAM_JBA_Anonymous__c,
                HAM_Will_Provision__c,
                HAM_Planned_Gift__c,
                HAM_Documented__c,
                HAM_Unknown__c,
                ucinn_ascendv2__Comments__c
            FROM ucinn_ascendv2__Society_Membership__c
            WHERE ucinn_ascendv2__Contact__c = :contactId
            ORDER BY ucinn_ascendv2__Membership_Status__c ASC,
                     ucinn_ascendv2__Member_Since__c DESC
        ];
    }
}