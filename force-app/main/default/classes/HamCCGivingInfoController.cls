/**
 * @description Apex controller for Giving Information component
 */
public with sharing class HamCCGivingInfoController {
    
    /**
     * @description Retrieves giving information by purpose for a given contact or account
     * @param recordId - Contact or Account ID
     * @param isAlumni - Flag to determine if record is Contact (true) or Account (false)
     * @return List of HAM_Pledge_Balance__c records
     */
    @AuraEnabled(cacheable=true)
    public static List<HAM_Pledge_Balance__c> getGivingInfo(Id recordId, Boolean isAlumni) {
        List<HAM_Pledge_Balance__c> givingInfo = new List<HAM_Pledge_Balance__c>();
        String pdRecordTypeID = Schema.SObjectType.HAM_Pledge_Balance__c.getRecordTypeInfosByName().get('Last 5 year Giving').getRecordTypeId();
       
        if (recordId != null) {
            String query;
            if (isAlumni) {
                 givingInfo = [SELECT Id, Name,
                        HAM_Designation__c,
                        HAM_Fiscal_Year__c,
                        HAM_Paid__c,
                        HAM_Pledge_Balance__c,
                        HAM_Pledged__c, 
                        createdDate  
                       FROM HAM_Pledge_Balance__c
                       WHERE Constituent__c =:recordId AND HAM_Status__c = 'active' AND RecordtypeID =:pdRecordTypeID];
            } else {
                 givingInfo = [SELECT Id, Name,
                        HAM_Designation__c,
                        HAM_Fiscal_Year__c,
                        HAM_Paid__c,
                        HAM_Pledge_Balance__c,
                        HAM_Pledged__c, 
                        createdDate  
                       FROM HAM_Pledge_Balance__c
                       WHERE Constituent__c =:recordId AND HAM_Status__c = 'active' AND RecordtypeID =:pdRecordTypeID];
            }
            
        }
        
        return givingInfo;
    }
    
    /**
     * @description Retrieves contact or account data for giving summary
     * @param recordId - Contact or Account ID
     * @param isAlumni - Flag to determine if record is Contact (true) or Account (false)
     * @return Map with lifetimeGiving, largestGift, thisYear, and yearsOfGiving values
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getContactAccountData(Id recordId, Boolean isAlumni) {
        Map<String, Object> result = new Map<String, Object>();
        
        if (recordId != null) {
            if (isAlumni) {
                // For alumni (Contact record)
                Contact contact = [SELECT Id, HAM_Lifetime_Paid__c, HAM_Largest_Gift_Amount__c,HAM_Current_Year_Hamilton_Fund_Collected__c, HAM_Total_Years_of_Giving__c FROM Contact WHERE Id = :recordId LIMIT 1];
                result.put('lifetimeGiving', contact.HAM_Lifetime_Paid__c != null ? contact.HAM_Lifetime_Paid__c : 0);
                result.put('largestGift', contact.HAM_Largest_Gift_Amount__c != null ? contact.HAM_Largest_Gift_Amount__c : 0);
                // Set other fields to 0 for alumni (they are hidden)
                result.put('thisYear', contact.HAM_Current_Year_Hamilton_Fund_Collected__c != null ? contact.HAM_Current_Year_Hamilton_Fund_Collected__c : 0);
                result.put('yearsOfGiving', contact.HAM_Total_Years_of_Giving__c != null ? contact.HAM_Total_Years_of_Giving__c : 0);
                
            } else {
                // For non-alumni (Account record)
                Account account = [SELECT Id, ucinn_ascendv2__Lifetime_Fundraising__c, ucinn_ascendv2__Amount_of_Largest_Gift__c FROM Account WHERE Id = :recordId LIMIT 1];
                result.put('lifetimeGiving', account.ucinn_ascendv2__Lifetime_Fundraising__c != null ? account.ucinn_ascendv2__Lifetime_Fundraising__c : 0);
                result.put('largestGift', account.ucinn_ascendv2__Amount_of_Largest_Gift__c != null ? account.ucinn_ascendv2__Amount_of_Largest_Gift__c : 0);
                
                result.put('thisYear', 0);
                result.put('yearsOfGiving', 0);
            }
        }
        
        return result;
    }
    
    /**
     * @description Retrieves full contact data for badge logic and other purposes
     * @param contactId - Contact ID to query
     * @return Complete Contact record with all fields needed for badge logic
     */
    @AuraEnabled(cacheable=true)
    public static Contact getContactFullData(Id contactId) {
        if (contactId != null) {
            Contact contact = [SELECT ID, Name, AccountId, HAM_Consecutive_Years_of_Giving__c, HAM_Total_Years_of_Giving__c, HAM_Lifetime_Committed__c, HAM_Lifetime_Paid__c,HAM_Current_Yr_Hamilton_Fund_Fundraising__c, HAM_Current_Year_Hamilton_Fund_Collected__c,
            HAM_1812__c, HAM_Founders_Circle__c,HAM_Ten_to_Fifth__c,HAM_Chapel_Bell__c,HAM_Couper_Guild__c,HAM_JBA__c,HAM_JBA_Anonymous__c, HAM_Lifetime_Committed_w_BQI__c, HAM_Lifetime_Bequest_Intention__c,
            HAM_Largest_gift_Amount__c,HAM_Largest_gift_Date__c,HAM_Largest_gift_purpose__c,HAM_Largest_Pledge_Amount__c,HAM_Largest_Pledge_Date__c,HAM_Largest_Pledge_Purpose__c,
            HAM_Largest_AF_gift_Amount__c,HAM_Largest_AF_gift_Date__c,HAM_Largest_AF_gift_Purpose__c,HAM_Largest_AF_Pledge_Amount__c,HAM_Largest_AF_Pledge_Date__c,HAM_Largest_AF_Pledge_Purpose__c,HAM_Last_Gift_Amount__c,HAM_Last_Gift_Date__c, HAM_Current_FY_Paid__c, ucinn_ascendv2__Wealth_Rating__c
            FROM Contact WHERE Id =:contactId];
            return contact;
        }
        return null;
    }
    
    
}