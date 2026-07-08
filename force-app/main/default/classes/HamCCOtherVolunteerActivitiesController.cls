/**
 * @description Apex controller for Other Volunteer Activities component
 */
public with sharing class HamCCOtherVolunteerActivitiesController {
    
    /* =====================================================
     * Wrapper Classes
     * ===================================================== */
    public class VolunteerActivitiesData {
        @AuraEnabled public List<ucinn_ascendv2__Involvement__c> volunteerActivities { get; set; }
        @AuraEnabled public Integer currentInvolvementsCount { get; set; }
        @AuraEnabled public Integer formerInvolvementsCount { get; set; }
    }

    /* =====================================================
     * GET VOLUNTEER ACTIVITIES
     * ===================================================== */
    @AuraEnabled(cacheable=true)
    public static VolunteerActivitiesData getVolunteerActivities(Id recordId, Boolean isAlumni) {
        VolunteerActivitiesData res = new VolunteerActivitiesData();
        res.volunteerActivities = new List<ucinn_ascendv2__Involvement__c>();
        res.currentInvolvementsCount = 0;
        res.formerInvolvementsCount = 0;
        
        if (recordId != null) {
            List<ucinn_ascendv2__Involvement__c> activities = new List<ucinn_ascendv2__Involvement__c>();
            
            List<Id> valueIds = new List<Id>();
            for (ucinn_ascendv2__Involvement_Value__c v :
                [SELECT Id
                 FROM ucinn_ascendv2__Involvement_Value__c
                 WHERE ucinn_ascendv2__Type__c = 'Volunteer Engagement'
                 AND HAM_Category__c != 'Career Center']
            ) {
                valueIds.add(v.Id);
            }

            if (valueIds.isEmpty()) return res;

            List<ucinn_ascendv2__Involvement__c> invs;

            if (isAlumni) {
                invs = [
                    SELECT Id, Name, ucinn_ascendv2__Contact__c,
                                ucinn_ascendv2__Status__c,
                                Owner.Name, HAM_CC_Score__c,
                                ucinn_ascendv2__Involvement_Code_Description_Formula__c,
                                ucinn_ascendv2__Start_Date__c,
                                ucinn_ascendv2__End_Date__c, HAM_Handshake_Link__c, 
                                ucinn_ascendv2__Involvement_Code__r.Name,
                                OwnerId, ucinn_ascendv2__Involvement_Code__c, HAM_Category__c  
                    FROM ucinn_ascendv2__Involvement__c
                    WHERE ucinn_ascendv2__Contact__c = :recordId
                    AND ucinn_ascendv2__Involvement_Code__c IN :valueIds
                    ORDER BY ucinn_ascendv2__Status__c ASC
                ];
            } else {
                invs = [
                    SELECT Id, Name, ucinn_ascendv2__Account__c,
                                ucinn_ascendv2__Status__c,
                                Owner.Name, HAM_CC_Score__c,
                                ucinn_ascendv2__Involvement_Code_Description_Formula__c,
                                ucinn_ascendv2__Start_Date__c,
                                ucinn_ascendv2__End_Date__c, HAM_Handshake_Link__c,
                                ucinn_ascendv2__Involvement_Code__r.Name,
                                OwnerId, ucinn_ascendv2__Involvement_Code__c , HAM_Category__c
                    FROM ucinn_ascendv2__Involvement__c
                    WHERE ucinn_ascendv2__Account__c = :recordId
                    AND ucinn_ascendv2__Involvement_Code__c IN :valueIds
                    ORDER BY ucinn_ascendv2__Status__c ASC
                ];
            }

            if (invs.isEmpty()) return res;
            res.volunteerActivities = invs;
            system.debug('Result: Other---- ' + res.volunteerActivities);
            
            // Count current and former involvements
            for (ucinn_ascendv2__Involvement__c activity : invs) {
                if (activity.ucinn_ascendv2__Status__c == 'Current') {
                    res.currentInvolvementsCount++;
                } else if (activity.ucinn_ascendv2__Status__c == 'Former') {
                    res.formerInvolvementsCount++;
                }
            }
        }
        
        return res;
    }
    
    
}