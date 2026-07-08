public with sharing class HAMJediContactReportController {
    @AuraEnabled(cacheable=true)
    public static List<ucinn_ascendv2__Contact_Report__c> getContactReportDetail(String contactId) {

        // Step 1: Query Contact Report Relations to get all CR IDs
        // This includes Contact Reports that are related through CRR but may not have direct contact relationship
        Set<Id> contactReportIdsFromCRR = new Set<Id>();

        List<ucinn_ascendv2__Contact_Report_Relation__c> crrRecords = [
            SELECT Id,
                   ucinn_ascendv2__Contact_Role__c,
                   ucinn_ascendv2__Contact__c,
                   ucinn_ascendv2__Contact_Report__c
            FROM ucinn_ascendv2__Contact_Report_Relation__c
            WHERE ucinn_ascendv2__Contact__c = :contactId
        ];

        // Collect Contact Report IDs from CRR
        for(ucinn_ascendv2__Contact_Report_Relation__c crr : crrRecords) {
            if(crr.ucinn_ascendv2__Contact_Report__c != null) {
                contactReportIdsFromCRR.add(crr.ucinn_ascendv2__Contact_Report__c);
            }
        }

        // Step 2: Query Contact Reports using OR condition to get both:
        // - Contact Reports where contact has direct relationship (ucinn_ascendv2__Contact__c = contactId)
        // - Contact Reports that came through Contact Report Relations (Id IN contactReportIdsFromCRR)
        // This automatically deduplicates since SOQL returns unique records
        List<ucinn_ascendv2__Contact_Report__c> contactReports = [
            SELECT Id,
                   Name,
                   ucinn_ascendv2__Contact_Method__c,
                   ucinn_ascendv2__Substantive_Contact__c,
                   ucinn_ascendv2__Description__c,
                   ucinn_ascendv2__Contact_Report_Body__c,
                   ucinn_ascendv2__Date__c,
                   HAM_PRM_at_Time_of_Meeting__c,
                   HAM_Publish_to_Listserv__c,
                   LastModifiedBy.Name
            FROM ucinn_ascendv2__Contact_Report__c
            WHERE ucinn_ascendv2__Contact__c = :contactId
               OR Id IN :contactReportIdsFromCRR
            ORDER BY LastModifiedDate DESC
        ];

        return contactReports;
    }
}