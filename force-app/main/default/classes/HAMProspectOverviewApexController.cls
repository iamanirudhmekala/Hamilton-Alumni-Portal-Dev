/**
 * @description Controller for the HAM Prospect Overview LWC component.
 * Provides prospect contact details, giving history, education, and relationship data.
 */
// 05/06/2026 NVV: ASC-13451 - Added ucinn_ascendv2__Is_Deceased__c to searchProspectDetails query for red name treatment on Convert page
// 05/06/2026 NVV: ASC-13502 - Added HAM_Special_Handling_Notes__c to searchProspectGivingDetails query
public with sharing class HAMProspectOverviewApexController {
    /**
     * @description Retrieves prospect contact details including personal info, chapters, and preferences
     * @param contactId The ID of the Contact record
     * @return Contact record with prospect detail fields
     */
    @AuraEnabled(cacheable=true)
    public static Contact searchProspectDetails(String contactId) {
        Contact objProspect = [SELECT ID, Name,HAM_Name_w_Suffix__c,ucinn_ascendv2__Donor_ID__c, ucinn_ascendv2__Contact_Type__c, HAM_Preferred_Chapter_Lookup__c,HAM_Preferred_Chapter_Lookup__r.name, HAM_Profile_Picture_URL__c,HAM_Current_Chapters__c,HAM_Alternate_Chapter__c,HAM_Alternate_Chapter__r.name, HAM_Phone_and_Type__c,HAM_PreferredEmail__c,HAM_LiveAlumni_Employer__c,HAM_LiveAlumni_Job_Title__c,ucinn_ascendv2__Preferred_Address_Formula__c,ucinn_ascendv2__PRM__c,ucinn_ascendv2__PRM__r.Name, ucinn_ascendv2__Preferred_Spouse__c,ucinn_ascendv2__Preferred_Spouse__r.name,Birthdate,ucinn_ascendv2__Wealth_Rating__c,ucinn_ascendv2__External_System_ID__c,HAM_Household_Prospect_Stage__c,ucinn_ascendv2__Is_Deceased__c FROM Contact WHERE Id =:contactId WITH SECURITY_ENFORCED];
        return objProspect;
    }

    /**
     * @description Retrieves prospect giving details including lifetime amounts, largest gifts, and fund designations
     * @param contactId The ID of the Contact record
     * @return ContactWrapper containing giving data and stewardship designations
     */
    @AuraEnabled(cacheable=true)
    public static ContactWrapper searchProspectGivingDetails(String contactId) {
        Contact objProspect = [SELECT ID, Name, AccountId, HAM_Consecutive_Years_of_Giving__c, HAM_Total_Years_of_Giving__c, HAM_Lifetime_Committed__c, HAM_Lifetime_Paid__c,HAM_Current_Yr_Hamilton_Fund_Fundraising__c, HAM_Current_Year_Hamilton_Fund_Collected__c,
        HAM_1812__c, HAM_Founders_Circle__c,HAM_Ten_to_Fifth__c,HAM_Chapel_Bell__c,HAM_Couper_Guild__c,HAM_JBA__c,HAM_JBA_Anonymous__c, HAM_Lifetime_Committed_w_BQI__c, HAM_Lifetime_Bequest_Intention__c,
        HAM_Largest_gift_Amount__c,HAM_Largest_gift_Date__c,HAM_Largest_gift_purpose__c,HAM_Largest_Pledge_Amount__c,HAM_Largest_Pledge_Date__c,HAM_Largest_Pledge_Purpose__c,
        HAM_Largest_AF_gift_Amount__c,HAM_Largest_AF_gift_Date__c,HAM_Largest_AF_gift_Purpose__c,HAM_Largest_AF_Pledge_Amount__c,HAM_Largest_AF_Pledge_Date__c,HAM_Largest_AF_Pledge_Purpose__c,HAM_Last_Gift_Amount__c,HAM_Last_Gift_Date__c, HAM_Current_FY_Paid__c, ucinn_ascendv2__Wealth_Rating__c, HAM_Special_Handling_Notes__c
        FROM Contact WHERE Id =:contactId WITH SECURITY_ENFORCED];
        String designationRecordTypeID = Schema.SObjectType.ucinn_ascendv2__Designation__c.getRecordTypeInfosByName().get('Fund').getRecordTypeId();

        List<ucinn_ascendv2__Designation_Stewardship__c> designations = [SELECT HAM_Fund_Name__c, ID FROM ucinn_ascendv2__Designation_Stewardship__c WHERE ucinn_ascendv2__Contact_Stewardee__c =:contactId AND ucinn_ascendv2__Status__c = 'Current' AND  HAM_Reporting_Type__c != 'None' AND  ucinn_ascendv2__Designation__r.HAM_Fund_Status__c != 'Inactive' AND ucinn_ascendv2__Designation__r.RecordTypeId =: designationRecordTypeID WITH SECURITY_ENFORCED];
        ContactWrapper objWrapper = new ContactWrapper();
        objWrapper.objRecord = objProspect;
        objWrapper.designations = designations; 
       return objWrapper;
    }

    /**
     * @description Retrieves deceased and do-not-contact indicator flags for a prospect
     * @param contactId The ID of the Contact record
     * @return ContactWrapper with isDeceased and isDoNotContact flags
     */
    @AuraEnabled(cacheable=true)
    public static ContactWrapper searchIndicatorDetails(String contactId) {
        ContactWrapper objWrapper = new ContactWrapper();
        objWrapper.isDeceased = false;
        objWrapper.isDoNotContact = false;
        Contact objProspect = [SELECT ID, ucinn_ascendv2__Is_Deceased__c FROM Contact WHERE Id =:contactId WITH SECURITY_ENFORCED];
        objWrapper.isDeceased = objProspect.ucinn_ascendv2__Is_Deceased__c;
        Integer serviceIndicatorCount = [SELECT Count() FROM ucinn_ascendv2__Service_Indicator__c WHERE ucinn_ascendv2__Contact__c =:contactId AND ucinn_ascendv2__Service_Indicator_Description_Formula__c = 'No Contact with Hamilton' AND ucinn_ascendv2__Is_Active__c = TRUE WITH SECURITY_ENFORCED];
        if(serviceIndicatorCount > 0){
            objWrapper.isDoNotContact = true;
        }
        return objWrapper;
    }

    /**
     * @description Retrieves prospect education data including Hamilton degree, concentrations, minors, involvements, and other degrees
     * @param contactId The ID of the Contact record
     * @return DegreeWrapper containing degree, involvement, and award data
     */
    @AuraEnabled(cacheable=true)
    public static DegreeWrapper searchProspectEducation(String contactId) {
        DegreeWrapper objWrapper = new DegreeWrapper();

        objWrapper.hamiltonDegree = getDegreeRecord(contactId);

        // Concatenate concentrations (majors)
        List<String> concentrationList = new List<String>();
        if(objWrapper.hamiltonDegree != null) {
            if(String.isNotBlank(objWrapper.hamiltonDegree.ucinn_ascendv2__Major_Formula__c)) {
                concentrationList.add(objWrapper.hamiltonDegree.ucinn_ascendv2__Major_Formula__c);
            }
            if(String.isNotBlank(objWrapper.hamiltonDegree.ucinn_ascendv2__Second_Major_Formula__c)) {
                concentrationList.add(objWrapper.hamiltonDegree.ucinn_ascendv2__Second_Major_Formula__c);
            }
            if(String.isNotBlank(objWrapper.hamiltonDegree.Third_Concentration_Formula__c)) {
                concentrationList.add(objWrapper.hamiltonDegree.Third_Concentration_Formula__c);
            }
        }
        objWrapper.concentrations = String.join(concentrationList, '; ');

        // Concatenate minors 
        List<String> minorList = new List<String>();
        if(objWrapper.hamiltonDegree != null) {
            if(String.isNotBlank(objWrapper.hamiltonDegree.ucinn_ascendv2__Minor_Formula__c)) {
                minorList.add(objWrapper.hamiltonDegree.ucinn_ascendv2__Minor_Formula__c);
            }
            if(String.isNotBlank(objWrapper.hamiltonDegree.Second_Minor__c)) {
                minorList.add(objWrapper.hamiltonDegree.Second_Minor__c);
            }
            if(String.isNotBlank(objWrapper.hamiltonDegree.Third_Minor__c)) {
                minorList.add(objWrapper.hamiltonDegree.Third_Minor__c);
            }
        }
        objWrapper.minors = String.join(minorList, '; ');

        objWrapper = getProspectInvolments(contactId, objWrapper);

        // Fetch Other Degree Information records
        String otherDegreeType = 'Other Degree Information';
        Schema.RecordTypeInfo otherRT = Schema.SObjectType.ucinn_ascendv2__Degree_Information__c.getRecordTypeInfosByName().get(otherDegreeType);
        if (otherRT != null) {
            Id otherRTId = otherRT.getRecordTypeId();
            objWrapper.otherDegrees = [
                SELECT Id, Name,
                       ucinn_ascendv2__Degree_Institution__c,
                       ucinn_ascendv2__Degree_Institution__r.Name,
                       ucinn_ascendv2__Conferred_Degree_Year__c,
                       ucinn_ascendv2__Degree_Code__c,
                       ucinn_ascendv2__Degree_Code__r.ucinn_ascendv2__Description__c,
                       HAM_First_Major__c, HAM_First_Minor__c
                FROM ucinn_ascendv2__Degree_Information__c
                WHERE ucinn_ascendv2__Contact__c = :contactId
                AND RecordTypeId = :otherRTId
                WITH SECURITY_ENFORCED
                ORDER BY ucinn_ascendv2__Conferred_Degree_Year__c DESC
            ];
        }

        return objWrapper;
    }

    /**
     * @description Retrieves the Hamilton/Kirkland degree record for a contact
     * @param contactId The ID of the Contact record
     * @return The most recent Hamilton/Kirkland Degree Information record
     */
    public static ucinn_ascendv2__Degree_Information__c getDegreeRecord(String contactId){
        String hamiltonDegreeType= 'Hamilton/Kirkland Degree Information';
        Map<String, Schema.RecordTypeInfo> recordTypeInfo = Schema.SObjectType.ucinn_ascendv2__Degree_Information__c.getRecordTypeInfosByName();
        Schema.RecordTypeInfo rt = recordTypeInfo.get(hamiltonDegreeType);
        if (rt == null) {
            return null;
        }
        Id recordTypeId = rt.getRecordTypeId();
        List<ucinn_ascendv2__Degree_Information__c> degrees = [SELECT ID, Name,ucinn_ascendv2__Major_Formula__c,ucinn_ascendv2__Second_Major_Formula__c,Third_Concentration_Formula__c,ucinn_ascendv2__Minor_Formula__c,Second_Minor__c,Third_Minor__c,ucinn_ascendv2__Conferred_Degree_Year__c,HAM_Reunion_Milestone_Year__c FROM ucinn_ascendv2__Degree_Information__c WHERE ucinn_ascendv2__Contact__c =:contactId AND RecordTypeID =: recordTypeId WITH SECURITY_ENFORCED ORDER BY CreatedDate DESC LIMIT 1];
        return degrees.isEmpty() ? null : degrees[0];
    }
    /**
     * @description Retrieves prospect involvements (athletics, clubs, societies) and awards
     * @param contactId The ID of the Contact record
     * @param objWrapper The DegreeWrapper to populate with involvement data
     * @return DegreeWrapper with athletics, clubs, societies, and awards populated
     */
    public static  DegreeWrapper getProspectInvolments(String contactId, DegreeWrapper objWrapper){
        List<ucinn_ascendv2__Involvement__c> involments = new list<ucinn_ascendv2__Involvement__c>();
        involments = [SELECT ucinn_ascendv2__Involvement_Code_Description_Formula__c, HAM_Category__c,ucinn_ascendv2__Award_Honor_Rec_d_Date__c,ucinn_ascendv2__Involvement_Code__c, ucinn_ascendv2__Involvement_Code__r.Name FROM ucinn_ascendv2__Involvement__c WHERE ucinn_ascendv2__Contact__c =:contactId WITH SECURITY_ENFORCED];
        String athletics = '';
        String club = '';
        String societies = '';
        List<ucinn_ascendv2__Designation_Beneficiary__c> awards =  new list<ucinn_ascendv2__Designation_Beneficiary__c>();
        awards = [SELECT ID, Name,ucinn_ascendv2__Type__c,ucinn_ascendv2__Designation__c,ucinn_ascendv2__Designation__r.ucinn_ascendv2__Designation_Name__c, ucinn_ascendv2__Designation__r.ucinn_ascendv2__Fund_Name__c,ucinn_ascendv2__Fiscal_Year__c FROM ucinn_ascendv2__Designation_Beneficiary__c WHERE ucinn_ascendv2__Contact__c =:contactId WITH SECURITY_ENFORCED];
        for(ucinn_ascendv2__Involvement__c involvement:involments){
            if(involvement.HAM_Category__c == 'Student NCAA Athletics'){
                athletics += involvement.ucinn_ascendv2__Involvement_Code_Description_Formula__c + ', ';
            }else if(involvement.HAM_Category__c == 'Student Clubs'){
                club += involvement.ucinn_ascendv2__Involvement_Code_Description_Formula__c + ', ';
            }else if(involvement.HAM_Category__c == 'Student Private Societies'){
                societies += involvement.ucinn_ascendv2__Involvement_Code_Description_Formula__c + ', ';
            }
        }

        objWrapper.athletics = athletics.removeEnd(', ');
        objWrapper.clubs = club.removeEnd(', ');
        objWrapper.societies = societies.removeEnd(', ');
        objWrapper.awards = awards;
        return objWrapper;
    }

    /**
     * @description Wrapper for contact data, designations, and indicator flags
     */
    public class ContactWrapper{
        /** @description The Contact record with giving or indicator fields */
        @AuraEnabled
        public Contact objRecord;
        /** @description List of active fund stewardship designations */
        @AuraEnabled
        public List<ucinn_ascendv2__Designation_Stewardship__c> designations;
        /** @description Whether the contact is deceased */
        @AuraEnabled
        public Boolean isDeceased;
        /** @description Whether the contact has a Do Not Contact service indicator */
        @AuraEnabled
        public Boolean isDoNotContact;
    }

    /**
     * @description Wrapper for degree, involvement, and award data
     */
    public class DegreeWrapper{
        /** @description The Hamilton/Kirkland degree record */
        @AuraEnabled
        public ucinn_ascendv2__Degree_Information__c hamiltonDegree;
        /** @description Comma-separated list of student NCAA athletics */
        @AuraEnabled
        public String athletics;
        /** @description Comma-separated list of student clubs */
        @AuraEnabled
        public String clubs;
        /** @description Comma-separated list of student private societies */
        @AuraEnabled
        public String societies;
        /** @description List of designation beneficiary award records */
        @AuraEnabled
        public List<ucinn_ascendv2__Designation_Beneficiary__c> awards;
        /** @description Semicolon-separated list of concentrations (majors) */
        @AuraEnabled
        public String concentrations;
        /** @description Semicolon-separated list of minors */
        @AuraEnabled
        public String minors;
        /** @description List of non-Hamilton degree records */
        @AuraEnabled
        public List<ucinn_ascendv2__Degree_Information__c> otherDegrees;
    }

    /**
     * @description Retrieves children contacts from the Relationship object
     *
     * @param contactId The ID of the parent contact
     * @return List of ChildContact wrappers containing child display names and IDs
     *
     * Query Logic:
     * - Queries ucinn_ascendv2__Relationship__c where ucinn_ascendv2__Contact__c = contactId (parent)
     * - Filters by ucinn_ascendv2__Related_Contact_Role__c = 'Child'
     * - Orders by CreatedDate ASC (oldest relationship first)
     * - Returns HAM_Name_w_Suffix__c for display (falls back to Name if blank)
     */
    @AuraEnabled(cacheable=true)
    public static List<ChildContact> getChildrenFromRelationships(String contactId) {
        List<ChildContact> childContacts = new List<ChildContact>();

        if (String.isBlank(contactId)) {
            return childContacts;
        }

        // Query relationships where current contact is parent and role is Child
        List<ucinn_ascendv2__Relationship__c> relationships = [
            SELECT Id,
                   ucinn_ascendv2__Related_Contact__c,
                   ucinn_ascendv2__Related_Contact__r.Name,
                   ucinn_ascendv2__Related_Contact__r.HAM_Name_w_Suffix__c,
                   CreatedDate
            FROM ucinn_ascendv2__Relationship__c
            WHERE ucinn_ascendv2__Contact__c = :contactId
            AND ucinn_ascendv2__Related_Contact_Role__c = 'Child'
            WITH SECURITY_ENFORCED
            ORDER BY CreatedDate ASC
        ];

        // Build response with child name and Contact ID
        for (ucinn_ascendv2__Relationship__c rel : relationships) {
            if (rel.ucinn_ascendv2__Related_Contact__c != null) {
                String displayName = String.isBlank(rel.ucinn_ascendv2__Related_Contact__r.HAM_Name_w_Suffix__c)
                    ? rel.ucinn_ascendv2__Related_Contact__r.Name
                    : rel.ucinn_ascendv2__Related_Contact__r.HAM_Name_w_Suffix__c;

                childContacts.add(new ChildContact(
                    displayName,
                    rel.ucinn_ascendv2__Related_Contact__c
                ));
            }
        }

        return childContacts;
    }

    /**
     * @description Retrieves parent contacts from the Relationship object
     *
     * @param contactId The ID of the child contact
     * @return List of ChildContact wrappers containing parent display names and IDs
     *
     * Query Logic:
     * - Queries ucinn_ascendv2__Relationship__c where ucinn_ascendv2__Contact__c = contactId (child)
     * - Filters by ucinn_ascendv2__Related_Contact_Role__c = 'Parent'
     * - Orders by CreatedDate ASC (oldest relationship first)
     * - Returns HAM_Name_w_Suffix__c for display (falls back to Name if blank)
     */
    @AuraEnabled(cacheable=true)
    public static List<ChildContact> getParentsFromRelationships(String contactId) {
        List<ChildContact> parentContacts = new List<ChildContact>();

        if (String.isBlank(contactId)) {
            return parentContacts;
        }

        // Query relationships where current contact is child and role is Parent
        List<ucinn_ascendv2__Relationship__c> relationships = [
            SELECT Id,
                   ucinn_ascendv2__Related_Contact__c,
                   ucinn_ascendv2__Related_Contact__r.Name,
                   ucinn_ascendv2__Related_Contact__r.HAM_Name_w_Suffix__c,
                   CreatedDate
            FROM ucinn_ascendv2__Relationship__c
            WHERE ucinn_ascendv2__Contact__c = :contactId
            AND ucinn_ascendv2__Related_Contact_Role__c = 'Parent'
            WITH SECURITY_ENFORCED
            ORDER BY CreatedDate ASC
        ];

        // Build response with parent name and Contact ID
        for (ucinn_ascendv2__Relationship__c rel : relationships) {
            if (rel.ucinn_ascendv2__Related_Contact__c != null) {
                String displayName = String.isBlank(rel.ucinn_ascendv2__Related_Contact__r.HAM_Name_w_Suffix__c)
                    ? rel.ucinn_ascendv2__Related_Contact__r.Name
                    : rel.ucinn_ascendv2__Related_Contact__r.HAM_Name_w_Suffix__c;

                parentContacts.add(new ChildContact(
                    displayName,
                    rel.ucinn_ascendv2__Related_Contact__c
                ));
            }
        }

        return parentContacts;
    }

    /**
     * @description Wrapper class to store contact display information for children/parents.
     * Used by getChildrenFromRelationships() and getParentsFromRelationships()
     */
    public class ChildContact {
        /** @description The display name of the child/parent contact */
        @AuraEnabled public String displayName;
        /** @description The Salesforce ID of the child/parent contact */
        @AuraEnabled public String contactId;

        /**
         * @description Constructs a ChildContact wrapper
         * @param displayName The contact display name
         * @param contactId The contact record ID
         */
        public ChildContact(String displayName, String contactId) {
            this.displayName = displayName;
            this.contactId = contactId;
        }
    }

    /**
     * @description Updates JEDI usage tracking fields on the current User record.
     * Tracks daily usage by updating count and last used date.
     *
     * Logic:
     * - If HAM_JEDI_Last_Used_Date__c is blank: Set to today, set count to 1
     * - If HAM_JEDI_Last_Used_Date__c is not today: Update to today, increment count
     * - If HAM_JEDI_Last_Used_Date__c is today: Do nothing (already tracked)
     *
     * Runs silently in background with no user feedback.
     */
    @AuraEnabled
    public static void updateJEDIUsageTracker() {
        try {
            Id currentUserId = UserInfo.getUserId();
            Date today = Date.today();

            // Query current user's tracking fields
            // Note: WITH SECURITY_ENFORCED is intentionally omitted here because this method
            // only reads/writes the currently authenticated user's own tracking fields.
            // FLS enforcement would silently block the update in profiles that lack field access.
            User currentUser = [
                SELECT Id, HAM_JEDI_Usage_Count__c, HAM_JEDI_Last_Used_Date__c
                FROM User
                WHERE Id = :currentUserId
                LIMIT 1
            ];

            // Check if update is needed
            Boolean needsUpdate = false;

            if (currentUser.HAM_JEDI_Last_Used_Date__c == null) {
                // First time using JEDI - initialize
                currentUser.HAM_JEDI_Last_Used_Date__c = today;
                currentUser.HAM_JEDI_Usage_Count__c = (currentUser.HAM_JEDI_Usage_Count__c == null ? 0 : currentUser.HAM_JEDI_Usage_Count__c) + 1;
                needsUpdate = true;
            } else if (currentUser.HAM_JEDI_Last_Used_Date__c != today) {
                // Different day - increment counter and update date
                currentUser.HAM_JEDI_Last_Used_Date__c = today;
                currentUser.HAM_JEDI_Usage_Count__c = (currentUser.HAM_JEDI_Usage_Count__c == null ? 0 : currentUser.HAM_JEDI_Usage_Count__c) + 1;
                needsUpdate = true;
            }
            // else: already tracked today, do nothing

            if (needsUpdate) {
                update currentUser;
            }

        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'JEDI Usage Tracker Error: ' + e.getMessage());
        }
    }
}