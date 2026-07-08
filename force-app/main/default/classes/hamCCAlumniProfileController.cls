/**
 * @description Controller for the Alumni/Employee Profile LWC. 
 * Aggregates Contact/Account details, relationships, tasks, and engagement badges.
 * @security    Enforces 'with sharing' to respect record-level access.
 */
public with sharing class hamCCAlumniProfileController {

    // Constants
    private static final String STATUS_OPEN = 'Open';
    private static final String STATUS_NStarted = 'Not Started';
    private static final String BADGE_PROSPECT = 'Prospect';
    private static final String BADGE_ENGAGED = 'Engaged';
    private static final String BADGE_VOLUNTEER_CC = 'Career Center Volunteer';
    private static final String BADGE_VOLUNTEER_IMPACT = 'Impact Volunteer';
    
    // Query Filters
    private static final String AFFILIATION_TYPE_CAREER = 'Career Center Contact';
    private static final String STATUS_CURRENT = 'Current';

    // ==========================================
    // Wrapper Classes
    // ==========================================
    public class ProfileData {
        @AuraEnabled public Contact objConstituentData { get; set; }
        @AuraEnabled public Account objOrgData { get; set; }
        @AuraEnabled public ConstituentRelationWrapper prmData { get; set; }
        @AuraEnabled public List<ConstituentRelationWrapper> orgRelations { get; set; }
        @AuraEnabled public List<Task> openTasks { get; set; }
        @AuraEnabled public List<String> badges { get; set; }
        @AuraEnabled public String major {get; set;}
        @auraenabled public Boolean isVolunteer {get; set;}

        public ProfileData() {
            this.orgRelations = new List<ConstituentRelationWrapper>();
            this.openTasks = new List<Task>();
            this.badges = new List<String>();
            this.prmData = new ConstituentRelationWrapper();
            this.major = '';
            this.isVolunteer = false;
        }
    }

    public class ConstituentRelationWrapper {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String relationship { get; set; }
        @AuraEnabled public String name { get; set; }
    }

    // ==========================================
    // Public Methods
    // ==========================================

    @AuraEnabled(cacheable=true)
    public static ProfileData getAlumniData(String recordId) {
        ProfileData result = new ProfileData();
        result.objConstituentData = new Contact();

        try {
            // 1. Get Contact Data
            result.objConstituentData = [
                SELECT Id, HAM_Name_w_Suffix__c, Phone, Email, 
                       ucinn_ascendv2__Preferred_Address_Formula__c,
                       Constituent_Employer__c, Job_Title__c, 
                       HAM_LiveAlumni_Job_Title__c, HAM_LiveAlumni_Employer__c, 
                       ucinn_ascendv2__PRM__c, ucinn_ascendv2__PRM__r.Name,
                       HAM_Profile_Picture_URL__c, HAM_Reunion_Year__c, Is_Volunteer__c
                FROM Contact 
                WHERE Id = :recordId
                LIMIT 1
            ];

            // 2. Map PRM Data
            if (String.isNotBlank(result.objConstituentData.ucinn_ascendv2__PRM__c)) {
                result.prmData.id = result.objConstituentData.ucinn_ascendv2__PRM__c;
                result.prmData.name = result.objConstituentData.ucinn_ascendv2__PRM__r.Name;
                result.prmData.relationship = 'PRM';
            }

            // 3. Get Relationships (Specific to Contact)
            for (ucinn_ascendv2__Relationship__c rel : [
                SELECT Id, ucinn_ascendv2__Contact_Role_Formula__c,
                       ucinn_ascendv2__Related_Contact__c, 
                       ucinn_ascendv2__Related_Contact__r.HAM_Name_w_Suffix__c,ucinn_ascendv2__Related_Contact_Role__c 
                FROM ucinn_ascendv2__Relationship__c 
                WHERE ucinn_ascendv2__Contact__c = :recordId
            ]) {
                ConstituentRelationWrapper wrapper = new ConstituentRelationWrapper();
                wrapper.id = rel.ucinn_ascendv2__Related_Contact__c;
                wrapper.name = rel.ucinn_ascendv2__Related_Contact__r.HAM_Name_w_Suffix__c;
                wrapper.relationship = rel.ucinn_ascendv2__Related_Contact_Role__c;
                result.orgRelations.add(wrapper);
            }

            // 4. Common Logic (Tasks & Badges)
            // Retrieve Open Tasks linked to the Contact (WhoId)
            result.openTasks = getOpenTasks(recordId, true);
            
            // DEPENDENCY: Calls external controller for score
            Integer involvementScore = hamCCVolunteerEngagementController.getEngagementData(recordId, true).currentYearScore;
            result.badges = calculateBadges(involvementScore);

            //5. Get Constituents Major
            result.major = HAMProspectOverviewApexController.searchProspectEducation(recordId).concentrations;
            result.isVolunteer =  result.objConstituentData.Is_Volunteer__c;

        } catch (Exception e) {
            handleException(e);
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static ProfileData getEmployeeData(String recordId) {
        ProfileData result = new ProfileData();
        result.objOrgData = new Account();

        try {
            // 1. Get Account Data
            result.objOrgData = [
                SELECT Id, Name, Type, AccountNumber, Industry, 
                       ucinn_ascendv2__Preferred_Address_Formula__c, PhotoUrl 
                FROM Account 
                WHERE Id = :recordId
                LIMIT 1
            ];

            // 2. Get Affiliations (Specific to Account)
            for (ucinn_ascendv2__Affiliation__c aff : [
                SELECT Id, ucinn_ascendv2__Job_Title__c,
                       ucinn_ascendv2__Contact__c, 
                       ucinn_ascendv2__Contact__r.HAM_Name_w_Suffix__c, HAM_Contact_Type__c, ucinn_ascendv2__Constituent_Role__c  
                FROM ucinn_ascendv2__Affiliation__c 
                WHERE ucinn_ascendv2__Account__c = :recordId  
                AND ucinn_ascendv2__Status__c = :STATUS_CURRENT
                AND HAM_Contact_Type__c = :AFFILIATION_TYPE_CAREER
            ]) {
                ConstituentRelationWrapper wrapper = new ConstituentRelationWrapper();
                wrapper.id = aff.ucinn_ascendv2__Contact__c;
                wrapper.name = aff.ucinn_ascendv2__Contact__r.HAM_Name_w_Suffix__c;
                if(!String.isBlank(aff.ucinn_ascendv2__Job_Title__c)){
                    wrapper.relationship = aff.ucinn_ascendv2__Job_Title__c;
                }else{
                     wrapper.relationship = aff.ucinn_ascendv2__Constituent_Role__c;
                }
                //wrapper.relationship = aff.ucinn_ascendv2__Job_Title__c;
                result.orgRelations.add(wrapper);
            }

            // 3. Common Logic (Tasks & Badges)
            // Retrieve Open Tasks linked to the Account (WhatId)
            result.openTasks = getOpenTasks(recordId, false);
            System.debug('Task count----'+result.openTasks.size());
            System.debug('Task ----'+result.openTasks);

            // DEPENDENCY: Calls external controller for score
            Integer involvementScore = hamCCVolunteerEngagementController.getEngagementData(recordId, false).currentYearScore;
            System.debug('Score-----'+involvementScore);
            result.badges = calculateBadges(involvementScore);
            System.debug('Badge-----'+result.badges);

        } catch (Exception e) {
            handleException(e);
        }
        return result;
    }

    // ==========================================
    // Private Helper Methods
    // ==========================================

    /**
     * @description Retrieves Open Tasks for a given record. 
     * Refactored from Dynamic SOQL to Static SOQL for security and performance.
     * @param recordId      The ID of the parent record.
     * @param isWhoRelation If true, filters by WhoId (People); otherwise WhatId (Objects).
     */
    private static List<Task> getOpenTasks(String recordId, Boolean isWhoRelation) {
        if (isWhoRelation) {
            return [
                SELECT Id, Subject, Priority, HAM_Task_Link__c, ActivityDate 
                FROM Task 
                WHERE (Status = :STATUS_OPEN OR Status = : STATUS_NStarted)
                AND WhoId = :recordId
                ORDER BY ActivityDate ASC NULLS LAST, Priority ASC NULLS LAST
            ];
        } else {
            return [
                SELECT Id, Subject, Priority, HAM_Task_Link__c, ActivityDate 
                FROM Task 
                WHERE (Status = :STATUS_OPEN OR Status = : STATUS_NStarted)
                AND WhatId = :recordId
                ORDER BY ActivityDate ASC NULLS LAST, Priority ASC NULLS LAST
            ];
        }
    }

    /**
     * @description Calculates badges based on integer score.
     */
    private static List<String> calculateBadges(Integer score) {
        List<String> badges = new List<String>();
        if (score == 0) {
            badges.add(BADGE_PROSPECT);
        } else if (score == 1) {
            badges.add(BADGE_ENGAGED);
        } else if (score == 2) {
            badges.add(BADGE_VOLUNTEER_CC);
        } else if (score >= 3) {
            badges.add(BADGE_VOLUNTEER_IMPACT);
        }
        return badges;
    }

    /**
     * @description Standard exception handler.
     */
    private static void handleException(Exception e) {
        // In production, you might log this to a custom object/platform event
        throw new AuraHandledException('Error retrieving profile data: ' + e.getMessage());
    }
}