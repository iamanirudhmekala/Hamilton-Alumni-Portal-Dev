public with sharing class HAMJediEventController {
    @AuraEnabled(cacheable=true)
    public static List<CventEvents__Attendee__c> getEventsDetail(String contactId) {
        List<CventEvents__Attendee__c> attendance = new List<CventEvents__Attendee__c>();
        attendance = [SELECT Id, Name,
                             CventEvents__Event__r.CventEvents__pkg_Title__c,
                             CventEvents__Event__r.CventEvents__pkg_EndDate__c,
                             CventEvents__Status__c
                       FROM CventEvents__Attendee__c
                       WHERE CventEvents__Contact__c = :contactId];
        return attendance;
    }

    @AuraEnabled(cacheable=true)
    public static List<et4ae5__IndividualEmailResult__c> getEmailDetail(String contactId) {
        List<et4ae5__IndividualEmailResult__c> emails = new List<et4ae5__IndividualEmailResult__c>();
        emails = [SELECT Name,et4ae5__FromName__c,et4ae5__FromAddress__c,et4ae5__SubjectLine__c,et4ae5__Contact__c,et4ae5__HardBounce__c,et4ae5__SoftBounce__c,et4ae5__DateBounced__c,et4ae5__Opened__c,et4ae5__DateOpened__c,et4ae5__NumberOfTotalClicks__c,et4ae5__NumberOfUniqueClicks__c FROM et4ae5__IndividualEmailResult__c WHERE et4ae5__Contact__c =:contactId];
        return emails;
    }
    
}