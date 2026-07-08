/**
 * @description Apex controller for Giving by Designations component
 */
public with sharing class HamCCGivingByDesignationsController {
    
    /**
     * @description Retrieves giving by designations for a given contact or account
     * @param recordId - Contact or Account ID
     * @param isAlumni - Flag to determine if record is Contact (true) or Account (false)
     * @return List of HAM_Pledge_Balance__c records
     */
    @AuraEnabled(cacheable=true)
    public static List<HAM_Pledge_Balance__c> getGivingByDesignations(Id recordId, Boolean isAlumni) {
        List<HAM_Pledge_Balance__c> givingDesignations = new List<HAM_Pledge_Balance__c>();
        String pdRecordTypeID = Schema.SObjectType.HAM_Pledge_Balance__c.getRecordTypeInfosByName().get('Giving By Purpose').getRecordTypeId();
       
        if (recordId != null && isAlumni) {
            // Only process for alumni (when isAlumni is true)
            givingDesignations = [SELECT Id, Name,
                        HAM_Designation__c,
                        HAM_Fiscal_Year__c,
                        HAM_Paid__c,
                        HAM_Pledge_Balance__c,
                        HAM_Pledged__c,
                        CreatedDate 
                       FROM HAM_Pledge_Balance__c
                       WHERE Constituent__c =:recordId AND HAM_Status__c = 'active' AND RecordtypeID =:pdRecordTypeID
                       ORDER BY CreatedDate DESC];
        } else {
            // Return empty list for non-alumni or null recordId
            givingDesignations = new List<HAM_Pledge_Balance__c>();
        }
        
        return givingDesignations;
    }
    
    
}