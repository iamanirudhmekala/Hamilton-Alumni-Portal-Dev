/**
 * @description Apex controller for Contact Report component
 */
public with sharing class HamCCContactReportController {
    
    /**
     * @description Retrieves contact reports for a given contact or account
     * @param recordId - Contact or Account ID
     * @param isAlumni - Flag to determine if record is Contact (true) or Account (false)
     * @return List of ucinn_ascendv2__Contact_Report__c records
     */
    @AuraEnabled(cacheable=true)
    public static List<ucinn_ascendv2__Contact_Report__c> getContactReports(Id recordId, Boolean isAlumni) {
        List<ucinn_ascendv2__Contact_Report__c> reports = new List<ucinn_ascendv2__Contact_Report__c>();
        
        if (recordId != null) {
String query;
            if (isAlumni) {
                query = 'SELECT Id, Name, ucinn_ascendv2__Date__c, LastModifiedById, OwnerId, ' +
                       'ucinn_ascendv2__Description__c, ucinn_ascendv2__Contact_Report_Body__c, ' +
                       'HAM_PRM_at_Time_of_Meeting__c, LastModifiedBy.Name, HAM_Publish_to_Listserv__c, HAM_Is_Career_Center_Specific_CR__c ' +
                       'FROM ucinn_ascendv2__Contact_Report__c ' +
                       'WHERE ucinn_ascendv2__Contact__c = :recordId ' +
                       'ORDER BY CreatedDate DESC';
            } else {
                query = 'SELECT Id, Name, ucinn_ascendv2__Date__c, LastModifiedById, OwnerId, ' +
                       'ucinn_ascendv2__Description__c, ucinn_ascendv2__Contact_Report_Body__c, ' +
                       'HAM_PRM_at_Time_of_Meeting__c, LastModifiedBy.Name, HAM_Publish_to_Listserv__c, HAM_Is_Career_Center_Specific_CR__c ' +
                       'FROM ucinn_ascendv2__Contact_Report__c ' +
                       'WHERE ucinn_ascendv2__Account__c = :recordId ' +
                       'ORDER BY CreatedDate DESC';
            }
            system.debug('query----->'+query);
            reports = Database.query(query);
            system.debug('reports----->'+reports);
        }
        
        return reports;
    }
    
    /**
     * @description Creates or updates a contact report
     * @param report - Contact Report record to save
     * @return The saved record
     */
    @AuraEnabled
    public static ucinn_ascendv2__Contact_Report__c saveContactReport(ucinn_ascendv2__Contact_Report__c report) {
        if (report != null) {
            try {
                upsert report;
                return report;
            } catch (Exception e) {
                System.debug('Error saving contact report: ' + e.getMessage());
                throw new AuraHandledException('Failed to save contact report: ' + e.getMessage());
            }
        }
        return null;
    }
}