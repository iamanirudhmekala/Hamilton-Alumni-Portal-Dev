/**
 * @description Controller to retrieve Prospect Contacts assigned to the current user.
 */
public with sharing class HamMyProspectController {
    
    /**
     * @description Returns contacts where the current user is the PRM manager.
     */
    @AuraEnabled(cacheable=true)
    public static List<Contact> searchMyProspects() {
        Id userId = UserInfo.getUserId(); 
        
        return [
            SELECT Id, Name, HAM_Name_w_Suffix__c, 
                   HAM_Preferred_Chapter_Lookup__c, HAM_Preferred_Chapter_Lookup__r.Name, 
                   HAM_Current_Chapters__c 
            FROM Contact 
            WHERE ucinn_ascendv2__PRM__c = :userId 
            AND HAM_Is_Primary_Constituent__c = TRUE 
            ORDER BY LastViewedDate DESC
            LIMIT 2000 // Performance Fix: Added safety limit
        ];
    }
}