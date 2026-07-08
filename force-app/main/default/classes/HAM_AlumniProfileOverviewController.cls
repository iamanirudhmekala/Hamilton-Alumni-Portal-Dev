/**
* @File Name : HAM_AlumniProfileOverviewController.cls
* @Description : This class is used to fetch contact's profile overview details on alumni directory page of the portal.
* @Author : Cube84 - Sacin
* @Last Modified By : Nilesh
* @Last Modified On : January 28, 2026
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | August 28, 2025 |  Sachin | Initial Version
* 1.1 | Sep 03, 2025 |  Aswhin S | Optimization
* 1.2 | Sep 30, 2025 |  Sachin | removing residence halls value if primary constituent type is 'Student'.
* 1.3 | Jan 29, 2026 |  Nilesh | Restructure method and wrapper for new profile overview compatible .

**/
@SuppressWarnings('PMD.NoTrailingWhitespace, PMD.IfStmtsMustUseBraces, PMD.IfElseStmtsMustUseBraces, PMD.ExcessiveClassLength, PMD.DebugsShouldUseLoggingLevel,   PMD.ExcessivePublicCount, PMD.ApexCRUDViolation, PMD.EmptyIfStmt, PMD.EmptyStatementBlock, PMD.AvoidNonRestrictiveQueries, PMD.CyclomaticComplexity, PMD.CognitiveComplexity, PMD.NcssCount, PMD.NcssTypeCount, PMD.DetectCopyPasteForApex, PMD.LocalVariableNamingConventions, PMD.ExcessiveParameterList, PMD.ApexSOQLInjection, PMD.AvoidDeeplyNestedIfStmts, PMD.AvoidDebugStatements, PMD.StdCyclomaticComplexity, PMD.NcssMethodCount, PMD.ApexDoc')
public without sharing class HAM_AlumniProfileOverviewController {
    /**
     * @description A wrapper class to structure the output data as required by the front end
     */
    public class AlumniProfileOverviewCard {
        @AuraEnabled public Id contactId;
        @AuraEnabled public String contactName;
        @AuraEnabled public Boolean isKirklandAlumnae;
        @AuraEnabled public Boolean isDeseasedAlumnae;
        @AuraEnabled public Boolean showClassOf;
        @AuraEnabled public String classYear;
        @AuraEnabled public String profilePictureUrl;
        @AuraEnabled public String contactlinkedInUrl;
        @AuraEnabled public String facebookUrl;
        @AuraEnabled public String instagramUrl;
        @AuraEnabled public String twitterUrl;
        @AuraEnabled public Boolean isConnection;
        @AuraEnabled public Boolean protalLogedUserPrivacy;   // logged-in portal user's connection privacy


        @AuraEnabled public List<FieldWrapper> fields;
        @AuraEnabled public List<FieldWrapper> personalInfofields;
        @AuraEnabled public List<FieldWrapper> campusLifefields;
        @AuraEnabled public List<FieldWrapper> addressDetailsfields;
        @AuraEnabled public List<FieldWrapper> degreesfields;

       
    }

    /**
     * @description Wrapper to hold a field's value and its order
     */
    public class FieldWrapper implements Comparable {
        @AuraEnabled public String label;
        @AuraEnabled public Decimal order;
        @AuraEnabled public Object value;
		
        /**
         * @description CompareTo method for sorting by order
         * @param obj The object to compare to
         * @return Integer indicating sort order
         */
        public Integer compareTo(Object obj) {
            FieldWrapper other = (FieldWrapper)obj;
            if (this.order == other.order) {
                return 0;
            }
            return (this.order > other.order) ? 1 : -1; // Ascending
        }
    }

    /**
     * @description A method to retrieve an alumni contact's profile overview details dynamically.
     * It fetches fields from a custom metadata type to build the query and a structured output.
     * @param contactId The ID of the Contact record to retrieve.
     * @return A list of AlumniProfileOverviewCard wrapper objects.
     */
    @SuppressWarnings('PME.DebugsShouldUseLoggingLevel')
    @AuraEnabled(cacheable=true)
    public static List<AlumniProfileOverviewCard> getAlumniOverview(String contactId, string portalId) {

        List<Contact> constituentList = [SELECT Id, ucinn_ascendv2__Primary_Contact_Type__c FROM Contact WHERE Id = :contactId WITH SYSTEM_MODE LIMIT 1];
        if(constituentList.isEmpty()) {
            return new List<AlumniProfileOverviewCard>();
        }
        Contact constituent = constituentList[0];
        String involvementRecordType = (constituent.ucinn_ascendv2__Primary_Contact_Type__c == 'Student')
                                        ? 'Student_Involvement'
                                        : 'Alumni_Involvement';
          
        Id ServiceIndicatorRecordTypeId = Schema.SObjectType.ucinn_ascendv2__Service_Indicator__c.getRecordTypeInfosByName().get('Contact Service Indicator').getRecordTypeId();

        // Logged-in portal user's connection privacy — used by the LWC to hide Send Request
        Boolean loggedUserConnectionPrivacy = false;
        if (String.isNotBlank(portalId)) {
            List<ucinn_ascendv2__Service_Indicator__c> loggedUserPrivacySI = [
                SELECT Id
                FROM ucinn_ascendv2__Service_Indicator__c
                WHERE RecordTypeId = :ServiceIndicatorRecordTypeId
                  AND ucinn_ascendv2__Is_Active__c = true
                  AND ucinn_ascendv2__Contact__c = :portalId
                  AND ucinn_ascendv2__Service_Indicator_Value__r.HAM_Portal_ID__c = :HAM_ConstantsUtil.CONNECTION_PRIVCACY_SVID
                WITH SYSTEM_MODE
                LIMIT 1
            ];
            loggedUserConnectionPrivacy = !loggedUserPrivacySI.isEmpty();
        }

        // A set to store API names of standard and non-custom fields.
        Set<String> fieldApiNames = new Set<String>();

        // Retrieve metadata fields.
        List<HAM_Meta_Data__mdt> ConnectionMetaList = [SELECT HAM_Level_2__c,HAM_Field_API__c, HAM_Display_Label__c, HAM_Order__c,HAM_Field_Type__c FROM HAM_Meta_Data__mdt WHERE HAM_Level_1__c = 'Alumni Profile Overview' WITH SYSTEM_MODE ORDER BY HAM_Order__c];
 
        for(HAM_Meta_Data__mdt meta : ConnectionMetaList) {
            if(meta.HAM_Field_API__c != null && meta.HAM_Field_Type__c != 'Replaceable'){    
                fieldApiNames.add(meta.HAM_Field_API__c);
            }
        }
        fieldApiNames.add('HAM_Profile_Picture_URL__c');
        fieldApiNames.add('HAM_LiveAlumni_Employer__c');

        // Define the WHERE clause for the main Contact query.
        String whereClause = ' Where Id = :contactId';

        // Join all non-custom field API names into a single string for the SELECT clause.
        String queryFields = String.join(new List<String>(fieldApiNames), ', ');

        // Subqueries
        String degreeSubquery = '(SELECT Id,ucinn_ascendv2__Major_Formula__c, ucinn_ascendv2__Major_Degree_Formula__c, ucinn_ascendv2__Second_Major_Formula__c,Third_Concentration_Formula__c,ucinn_ascendv2__Minor_Degree_Formula__c,Second_Minor__c,Third_Minor__c, RecordType.DeveloperName FROM ucinn_ascendv2__Degree_Information_Contact__r)';
        //String involvmentSubquery = '(SELECT Id, HAM_Category__c, ucinn_ascendv2__Involvement_Code_Description_Formula__c FROM ucinn_ascendv2__Involvements_Contact__r )';
        String involvmentSubquery = '(SELECT Id, HAM_Category__c, ucinn_ascendv2__Involvement_Code_Description_Formula__c  FROM ucinn_ascendv2__Involvements_Contact__r WHERE RecordType.DeveloperName = \'' + involvementRecordType + '\')';
        String socialMediaSubquery = '(SELECT Id, ucinn_ascendv2__URL__c, ucinn_ascendv2__Platform__c FROM ucinn_ascendv2__Social_Media__r )';
        String emailSubquery = '(SELECT ucinn_ascendv2__Email_Address__c FROM ucinn_ascendv2__Emails_Contact__r WHERE ucinn_ascendv2__Is_Preferred__c = true ORDER BY LastModifiedDate DESC LIMIT 1 )';
        String addressSubquery = '(Select Id,ucinn_ascendv2__Address__c,ucinn_ascendv2__Address__r.ucinn_ascendv2__Address_Line_1__c,ucinn_ascendv2__Address__r.ucinn_ascendv2__City__c,ucinn_ascendv2__Address__r.ucinn_ascendv2__State__c, ucinn_ascendv2__Address__r.ucinn_ascendv2__Country__c, ucinn_ascendv2__Address__r.ucinn_ascendv2__Postal_Code__c  from ucinn_ascendv2__Address_Relations_Contact__r Where ucinn_ascendv2__Is_Preferred__c = true)';

        String queryString = 'SELECT Id, HAM_Name_w_Suffix__c, Email, ucinn_ascendv2__Primary_Contact_Type__c, ' + queryFields + ', ' + degreeSubquery + ', ' + involvmentSubquery + ', ' + socialMediaSubquery + ', '+ emailSubquery + ', ' + addressSubquery + ' FROM Contact ' + whereClause;
         
        List<Contact> alumniContacts = new List<Contact>();
        try {
            alumniContacts = Database.query(queryString);
        } catch (System.QueryException e) {
            System.debug(LoggingLevel.ERROR, 'Query Error: ' + e.getMessage());
            return new List<AlumniProfileOverviewCard>();
        }

        // --- PRIVACY LOGIC START (UPDATED) ---
        
        // 1. Get Service Indicator Configurations (Metadata)
        Map<String, String> ServiceIndicatorMap = new Map<String, String>();
        for (Ham_Service_Indicators__mdt ind : [SELECT Indicator_For_Field__c, Indicator_Value__c FROM Ham_Service_Indicators__mdt WHERE Is_Active__c = true AND Module__c = 'Profile Overview' WITH SYSTEM_MODE]) {
            ServiceIndicatorMap.put(ind.Indicator_For_Field__c, ind.Indicator_Value__c);
        }
        
        // 2. Get Active Indicators for Contact (Database)
        // Fetches HAM_Portal_ID__c (e.g. SIV_VIS_PHONE) to match Metadata
        Map<Id, Set<String>> constituentServiceIndicatorsMap = new Map<Id, Set<String>>();

        if(!alumniContacts.isEmpty()){
            for (ucinn_ascendv2__Service_Indicator__c si : [
                SELECT ucinn_ascendv2__Contact__c, ucinn_ascendv2__Service_Indicator_Value__r.HAM_Portal_ID__c 
                FROM ucinn_ascendv2__Service_Indicator__c
                WHERE RecordTypeId =: ServiceIndicatorRecordTypeId 
                AND ucinn_ascendv2__Contact__c IN: alumniContacts 
                AND ucinn_ascendv2__Is_Active__c = true
                AND ucinn_ascendv2__Service_Indicator_Value__r.HAM_Portal_ID__c != null
                WITH SYSTEM_MODE
            ]) {
                if(!constituentServiceIndicatorsMap.containsKey(si.ucinn_ascendv2__Contact__c)){
                    constituentServiceIndicatorsMap.put(si.ucinn_ascendv2__Contact__c, new Set<String>());
                }
                constituentServiceIndicatorsMap.get(si.ucinn_ascendv2__Contact__c).add(si.ucinn_ascendv2__Service_Indicator_Value__r.HAM_Portal_ID__c);
            }
        }
        // --- PRIVACY LOGIC END ---
         
        // Data Preparation Maps
        Map<Id, List<String>> underGradudegreeMap = new Map<Id, List<String>>();
        Map<Id, List<String>> underGradMinordegreeMap = new Map<Id, List<String>>();
        Map<Id, List<String>> postGradudegreeMap = new Map<Id, List<String>>();
        Map<Id, List<String>> emailMap = new Map<Id, List<String>>();
        Map<Id, List<String>> residenceHallMap = new Map<Id, List<String>>();
        Map<Id, List<String>> athleticsMap = new Map<Id, List<String>>();
        Map<Id, List<String>> studentOrgMap = new Map<Id, List<String>>();
        Map<Id, Map<String, String>> socialMediaMapByContact = new Map<Id, Map<String, String>>();
        Map<Id, Map<String,String>> addressMapByContact = new Map<Id, Map<String,String>>();
        Map<Id, List<String>> currentChaptersMap = new Map<Id, List<String>>();

        if (!alumniContacts.isEmpty()) {
            for (Contact con : alumniContacts) {

                // Degree information
                if(con.ucinn_ascendv2__Degree_Information_Contact__r != null){
                    for (ucinn_ascendv2__Degree_Information__c degree : con.ucinn_ascendv2__Degree_Information_Contact__r) {
                    if(degree.RecordType.DeveloperName == HAM_ConstantsUtil.SCHOOL_DEGREE_INFORMATION){

                        if(degree.ucinn_ascendv2__Major_Degree_Formula__c != null){
                            if(!underGradudegreeMap.containsKey(con.Id)) underGradudegreeMap.put(con.Id,new List<String>());
                            underGradudegreeMap.get(con.Id).add(degree.ucinn_ascendv2__Major_Degree_Formula__c);
                        }
                        if(degree.ucinn_ascendv2__Second_Major_Formula__c != null){
                            if(!underGradudegreeMap.containsKey(con.Id)) underGradudegreeMap.put(con.Id,new List<String>());
                            underGradudegreeMap.get(con.Id).add(degree.ucinn_ascendv2__Second_Major_Formula__c);
                        }
                        if(degree.Third_Concentration_Formula__c != null){
                           if(!underGradudegreeMap.containsKey(con.Id)) underGradudegreeMap.put(con.Id,new List<String>());
                            underGradudegreeMap.get(con.Id).add(degree.Third_Concentration_Formula__c);
                        }
                        
                        // Handle 'Undergraduate_Minor' by collecting Minor Degree values from 'School_Degree_Information' records.
                        if(degree.ucinn_ascendv2__Minor_Degree_Formula__c != null){
                            if(!underGradMinordegreeMap.containsKey(con.Id)) underGradMinordegreeMap.put(con.Id,new List<String>());
                            underGradMinordegreeMap.get(con.Id).add(degree.ucinn_ascendv2__Minor_Degree_Formula__c);
                        }
                        if(degree.Second_Minor__c != null){
                            if(!underGradMinordegreeMap.containsKey(con.Id)) underGradMinordegreeMap.put(con.Id,new List<String>());
                            underGradMinordegreeMap.get(con.Id).add(degree.Second_Minor__c);
                        }
                        if(degree.Third_Minor__c != null){
                            if(!underGradMinordegreeMap.containsKey(con.Id)) underGradMinordegreeMap.put(con.Id,new List<String>());
                            underGradMinordegreeMap.get(con.Id).add(degree.Third_Minor__c);
                        }
                    }

                    // Handle 'Post_Graduate_Degree' by collecting Major Degree values from 'Non_School_Degree_Information' records.
                    if(degree.RecordType.DeveloperName == HAM_ConstantsUtil.NON_SCHOOL_DEGREE_INFORMATION && degree.ucinn_ascendv2__Major_Degree_Formula__c != null){
                         if(!postGradudegreeMap.containsKey(con.Id)) postGradudegreeMap.put(con.Id,new List<String>());
                          postGradudegreeMap.get(con.Id).add(degree.ucinn_ascendv2__Major_Degree_Formula__c);
                    }

                    }
                }
                
                // Involment residence hall
                if (con.ucinn_ascendv2__Involvements_Contact__r != null) {
                    for (ucinn_ascendv2__Involvement__c invol : con.ucinn_ascendv2__Involvements_Contact__r) {
                        if (invol.ucinn_ascendv2__Involvement_Code_Description_Formula__c == null) continue;

                        if(invol.HAM_Category__c == HAM_ConstantsUtil.STUDENT_HOUSING1){
                            if(!residenceHallMap.containsKey(con.Id)) residenceHallMap.put(con.Id,new List<String>());
                            residenceHallMap.get(con.Id).add(invol.ucinn_ascendv2__Involvement_Code_Description_Formula__c);
                        }
                        if(invol.HAM_Category__c == HAM_ConstantsUtil.STUDENT_NCAA_ATHLETICS){
                            if(!athleticsMap.containsKey(con.Id)) athleticsMap.put(con.Id,new List<String>());
                            athleticsMap.get(con.Id).add(invol.ucinn_ascendv2__Involvement_Code_Description_Formula__c);
                        }
                        if(invol.HAM_Category__c == HAM_ConstantsUtil.STUDENT_PRIVATE_SOCIETIES || invol.HAM_Category__c == HAM_ConstantsUtil.STUDENT_CLUBS){
                            if(!studentOrgMap.containsKey(con.Id)) studentOrgMap.put(con.Id,new List<String>());
                            studentOrgMap.get(con.Id).add(invol.ucinn_ascendv2__Involvement_Code_Description_Formula__c);
                        }
                    }
                }

                // Handle Social Media
                if (con.ucinn_ascendv2__Social_Media__r != null) {
                    for(ucinn_ascendv2__Social_Media__c sm : con.ucinn_ascendv2__Social_Media__r ){
                        if (sm.ucinn_ascendv2__URL__c == null) continue;
                        if (!socialMediaMapByContact.containsKey(con.Id)) socialMediaMapByContact.put(con.Id, new Map<String, String>());
                        socialMediaMapByContact.get(con.Id).put(sm.ucinn_ascendv2__Platform__c, sm.ucinn_ascendv2__URL__c);
                    }
                }
                
                // Handle address
                if (con.ucinn_ascendv2__Address_Relations_Contact__r != null) {
                    for(ucinn_ascendv2__Address_Relation__c ad : con.ucinn_ascendv2__Address_Relations_Contact__r ){
                        if (!addressMapByContact.containsKey(con.Id)) addressMapByContact.put(con.Id, new Map<String,String>());
                        Map<String,String> addr = addressMapByContact.get(con.Id);
                        addr.put('Street', ad.ucinn_ascendv2__Address__r.ucinn_ascendv2__Address_Line_1__c);
                        addr.put('City', ad.ucinn_ascendv2__Address__r.ucinn_ascendv2__City__c);
                        addr.put('State', ad.ucinn_ascendv2__Address__r.ucinn_ascendv2__State__c);
                        addr.put('Country', ad.ucinn_ascendv2__Address__r.ucinn_ascendv2__Country__c);
                        addr.put('Zip Code', ad.ucinn_ascendv2__Address__r.ucinn_ascendv2__Postal_Code__c);
                    }
                }

                // Handle email
                if(con.ucinn_ascendv2__Emails_Contact__r != null){
                    for( ucinn_ascendv2__Email__c em : con.ucinn_ascendv2__Emails_Contact__r){
                        if (!emailMap.containsKey(con.Id)) emailMap.put(con.Id,new List<String>());
                        emailMap.get(con.Id).add(em.ucinn_ascendv2__Email_Address__c);
                    }
                }
            }
        }

        // Handle Current Chapters from junction records (live query, excludes 'Unassigned Chapter', sorted A→Z)
        if (!alumniContacts.isEmpty()) {
            for (HAM_Current_Chapter__c junc : [
                SELECT Constituent__c, Chapter__r.Name
                FROM HAM_Current_Chapter__c
                WHERE Constituent__c IN :alumniContacts
                AND Is_Active__c = true
                AND Chapter__r.Name != 'Unassigned Chapter'
                ORDER BY Chapter__r.Name ASC
            ]) {
                if (!currentChaptersMap.containsKey(junc.Constituent__c)) {
                    currentChaptersMap.put(junc.Constituent__c, new List<String>());
                }
                currentChaptersMap.get(junc.Constituent__c).add(junc.Chapter__r.Name);
            }
        }

        //system.debug('socialMediaMapByContact -'+socialMediaMapByContact);
         
        List<AlumniProfileOverviewCard> alumniProfileOverview = new List<AlumniProfileOverviewCard>();
        
        for (Contact con : alumniContacts) {
            
            // --- MASTER PRIVACY CHECK ---
            if (constituentServiceIndicatorsMap.containsKey(con.Id)) {
                if (constituentServiceIndicatorsMap.get(con.Id).contains('SIV_VIS_ALUMNI_PRIVACY')) {
                    continue; // Skip this contact entirely
                }
            }

            AlumniProfileOverviewCard card = new AlumniProfileOverviewCard();
            card.contactId = con.Id;
            card.protalLogedUserPrivacy = loggedUserConnectionPrivacy;   // NEW
            card.personalInfofields = new List<FieldWrapper>();
            card.campusLifefields = new List<FieldWrapper>();
            card.addressDetailsfields = new List<FieldWrapper>();
            card.degreesfields = new List<FieldWrapper>();
            

            //system.debug('ServiceIndicatorMap -'+ServiceIndicatorMap);
          
            // Determine Skipped Fields for this contact
            Set<String> DirectoryskippedFields = new Set<String>();
            if (constituentServiceIndicatorsMap.containsKey(con.Id)) {
                 for (String fieldApi : ServiceIndicatorMap.keySet()) {
                    String sivCode = ServiceIndicatorMap.get(fieldApi);
                    if (constituentServiceIndicatorsMap.get(con.Id).contains(sivCode)) {
                        DirectoryskippedFields.add(fieldApi);
                    }
                }
            }

            //system.debug('DirectoryskippedFields -'+DirectoryskippedFields);
           
            // Iterate Metadata
            for (HAM_Meta_Data__mdt meta : ConnectionMetaList) {
                
                // Boolean DirFieldisSkipped = DirectoryskippedFields.contains(meta.HAM_Field_API__c);
                Boolean DirFieldisSkipped = DirectoryskippedFields.contains(meta.HAM_Field_API__c) || 
                            (meta.HAM_Level_2__c == 'Address Details' && DirectoryskippedFields.contains('ADDR_ADDRESS'));
                
                // Specific Check: Profile Picture Privacy
                if(meta.HAM_Display_Label__c == HAM_ConstantsUtil.PROFILE_PICTURE) {
                    if(!DirFieldisSkipped) {
                        card.profilePictureUrl = getFieldValue(con, 'HAM_Profile_Picture_URL__c');
                    } else {
                        card.profilePictureUrl = null;
                    }
                    continue;
                }
          
           
                if(meta.HAM_Display_Label__c == 'No Connections' && meta.HAM_Field_API__c == 'NO_CONNECTIONS'){
                      
                     if(DirFieldisSkipped) {
                        card.isConnection = false;
                    } else {
                        card.isConnection = true;
                    }
                    continue;
                    
                }
            

                String valueInDirectory = '';
                if (!DirFieldisSkipped) {
                    valueInDirectory = resolveFieldValue(con, meta.HAM_Level_2__c, meta.HAM_Field_API__c, meta.HAM_Display_Label__c, underGradudegreeMap,underGradMinordegreeMap,postGradudegreeMap, residenceHallMap, athleticsMap, studentOrgMap,socialMediaMapByContact,addressMapByContact,currentChaptersMap);
                }
                
                // Personal Information
                if (meta.HAM_Level_2__c == HAM_ConstantsUtil.PERSONAL_INFO) {
                   // if(!DirFieldisSkipped) {
                        FieldWrapper field = new FieldWrapper();
                        field.label = meta.HAM_Display_Label__c;
                        field.order = meta.HAM_Order__c;
                        field.value = String.isBlank(valueInDirectory) ? '-' : valueInDirectory;
                        card.personalInfofields.add(field);
                   // }
                    continue;
                }

                 // Degree Information
                if (meta.HAM_Level_2__c == 'Degrees') {
                   
                    FieldWrapper field = new FieldWrapper();
                    field.label = meta.HAM_Display_Label__c;
                    field.order = meta.HAM_Order__c;
                    field.value = String.isBlank(valueInDirectory) ? '-' : valueInDirectory;
                    card.degreesfields.add(field); 
                }

                // Address Details
                if (meta.HAM_Level_2__c == HAM_ConstantsUtil.ADDRESS_DETAILS) {
                   // if(!DirFieldisSkipped) {
                        FieldWrapper field = new FieldWrapper();
                        field.label = meta.HAM_Display_Label__c;
                        field.order = meta.HAM_Order__c;
                        field.value = String.isBlank(valueInDirectory) ? '-' : valueInDirectory;
                        card.addressDetailsfields.add(field);
                  //  }
                    continue;
                }

                // Campus Life
                if (meta.HAM_Level_2__c == HAM_ConstantsUtil.CAMPUS_LIFE) {
                   // if(!DirFieldisSkipped) {
                        FieldWrapper field = new FieldWrapper();
                        field.label = meta.HAM_Display_Label__c;
                        field.order = meta.HAM_Order__c;
                        field.value = String.isBlank(valueInDirectory) ? '-' : valueInDirectory;
                        card.campusLifefields.add(field);
                    //}
                    continue;
                }
                
                // Header Information
                if (meta.HAM_Level_2__c == HAM_ConstantsUtil.HEADER) {
                    if(meta.HAM_Display_Label__c == HAM_ConstantsUtil.NAME){
                        card.contactName = String.isBlank(valueInDirectory) ? '-' : valueInDirectory;
                    }
                    if(meta.HAM_Display_Label__c == HAM_ConstantsUtil.KIRKLAND_ALUMNAE){
                        card.isKirklandAlumnae = con.ucinn_ascendv2__Contact_Type__c != null && con.ucinn_ascendv2__Contact_Type__c.contains(HAM_ConstantsUtil.KIRKLAND_ALUMNAE);
                    }
                    if(meta.HAM_Display_Label__c == HAM_ConstantsUtil.DECEASED_ALUMNAE){
                        card.isDeseasedAlumnae = Boolean.valueOf(valueInDirectory);
                    }
                    if(meta.HAM_Display_Label__c == HAM_ConstantsUtil.CLASS1){
                        card.classYear = String.isBlank(valueInDirectory) ? '-' : valueInDirectory;
                    }
                    if(meta.HAM_Display_Label__c == HAM_ConstantsUtil.SHOW_CLASS_OF){
                        card.showClassOf = con.ucinn_ascendv2__Contact_Type__c != null && 
                                           con.ucinn_ascendv2__Contact_Type__c.contains(HAM_ConstantsUtil.KIRKLAND_ALUMNAE) ||
                                           con.ucinn_ascendv2__Contact_Type__c.contains(HAM_ConstantsUtil.HAMILTON_ALUMNI) ;
                    }
                    continue;
                }

                // Social Media
                if (meta.HAM_Level_2__c == HAM_ConstantsUtil.SOCIAL_MEDIA) {
                    //if(!DirFieldisSkipped) {
                        if(meta.HAM_Display_Label__c == HAM_ConstantsUtil.FACEBOOK) card.facebookUrl = String.isBlank(valueInDirectory) ? null : valueInDirectory;
                        if(meta.HAM_Display_Label__c == HAM_ConstantsUtil.INSTAGRAM) card.instagramUrl = String.isBlank(valueInDirectory) ? null : valueInDirectory;
                        if(meta.HAM_Display_Label__c == HAM_ConstantsUtil.TWITTER) card.twitterUrl = String.isBlank(valueInDirectory) ? null : valueInDirectory;
                    	if(meta.HAM_Display_Label__c == HAM_ConstantsUtil.LINKEDIN) card.contactlinkedInUrl = String.isBlank(valueInDirectory) ? null : valueInDirectory;
                    //}
                    continue;
                }

                if(meta.HAM_Display_Label__c == HAM_ConstantsUtil.LINKEDIN_URL) card.contactlinkedInUrl = String.isBlank(valueInDirectory) ? null : valueInDirectory;

            }

            card.personalInfofields.sort();
            card.campusLifefields.sort();
            card.addressDetailsfields.sort();
            card.degreesfields.sort();
            alumniProfileOverview.add(card);
        }
         system.debug('alumniProfileOverview -'+alumniProfileOverview);
        return alumniProfileOverview;
    }

     /*
    * @description: Resolves and returns a display-ready value for a field on the Alumni Profile Overview
    *               based on metadata configuration and pre-processed relationship data.
    * @param:  record - The Contact record, hamLevel2 - HAM Level 2 value from metadata, fieldApi - fields api name, displayLabel - Display label for field, degreeMap - Degree map to resolev field

    * @return:  A String representing the resolved field value for display in the Alumni Profile Overview UI. Returns null if no value is available
    *           or applicable for the given record and field configuration.
    */
      @SuppressWarnings('PMD.DebugsShouldUseLoggingLevel')
      private static String resolveFieldValue(SObject record, String hamLevel2, String fieldApi,String displayLabel, Map<Id, List<String>> degreeMap, Map<Id, List<String>> minordegreeMap, Map<Id, List<String>> postdegreeMap, Map<Id, List<String>> residenceHallMap, Map<Id, List<String>> athleticsMap, Map<Id, List<String>> studentOrgMap,  Map<Id, Map<String,String>> socialMediaMapByContact, Map<Id, Map<String,String>> addressMapByContact, Map<Id, List<String>> currentChaptersMap) {
        
       
        // handling for Degrees
        if (hamLevel2 == 'Degrees') {
            
            if (record instanceof Contact) {
                Contact con = (Contact) record;
                
                if (fieldApi == HAM_ConstantsUtil.UNDERGRADUATE_DEGREE) {
                    if (degreeMap.containsKey(con.Id)) {
                        return String.join(degreeMap.get(con.Id), ', ');
                    }
                }
                else if (fieldApi == HAM_ConstantsUtil.UNDERGRADUATE_MINOR) {
                    if (minordegreeMap.containsKey(con.Id)) {
                        return String.join(minordegreeMap.get(con.Id), ', ');
                    }
                }
                else if (fieldApi == HAM_ConstantsUtil.POST_GRADUATE_DEGREE) {
                    if (postdegreeMap.containsKey(con.Id)) {
                            return String.join(postdegreeMap.get(con.Id), ', ');
                    } 
                }

                 return null;
               
            }
        }

        // handling for Residence Halls
        if (displayLabel == HAM_ConstantsUtil.RESIDENCE_HALLS) {
            
            if (record instanceof Contact) {
                Contact con = (Contact) record;
                
                if (residenceHallMap.containsKey(con.Id)) {
                    return String.join(residenceHallMap.get(con.Id), ', ');
                }
                
                return null;
            }
        }

        // handling for Undergraduate Athletics
        if (displayLabel == HAM_ConstantsUtil.UNDERGRAD_ATHLETICS) {
            
            if (record instanceof Contact) {
                Contact con = (Contact) record;
                
                if (athleticsMap.containsKey(con.Id)) {
                    return String.join(athleticsMap.get(con.Id), ', ');
                }
                
                return null;
            }
        }

        // handling for Student Organizations Category
        if (displayLabel == HAM_ConstantsUtil.STUDENT_ORGANIZATIONS) {
            
            if (record instanceof Contact) {
                Contact con = (Contact) record;
                
                if (studentOrgMap.containsKey(con.Id)) {
                    return String.join(studentOrgMap.get(con.Id), ', ');
                }
                
                return null;
            }
        }
        
        system.debug('hamLevel2 -'+hamLevel2);
        // Handling for Social Media Records
        if (hamLevel2 == HAM_ConstantsUtil.SOCIAL_MEDIA) {
             if (record instanceof Contact) {
                Contact con = (Contact) record;
             
                if(socialMediaMapByContact.containsKey(con.Id)) {
                    return socialMediaMapByContact.get(con.Id).get(displayLabel);
                }
                return null;
             }
           }
       
        // Handle address details
        if(hamLevel2 == HAM_ConstantsUtil.ADDRESS_DETAILS){
             if (record instanceof Contact) {
                Contact con = (Contact) record;

                if(addressMapByContact.containsKey(con.Id)) {
                    return addressMapByContact.get(con.Id).get(displayLabel);
                }
                return null;
             }
        }

        // handling for Current Chapters from junction records
        if (displayLabel == HAM_ConstantsUtil.CURRENT_CHAPTER) {
            if (record instanceof Contact) {
                Contact con = (Contact) record;
                if (currentChaptersMap.containsKey(con.Id)) {
                    return String.join(currentChaptersMap.get(con.Id), ', ');
                }
                return null;
            }
        }

        if (fieldApi == 'Constituent_Employer__r.Name') {
            String constituentName = getFieldValue(record, fieldApi);
            return String.isNotBlank(constituentName) ? constituentName : getFieldValue(record, 'HAM_LiveAlumni_Employer__c');
        }
        return getFieldValue(record, fieldApi);
    }
    
     /*
    * @description: A method to get field value dynamically.
    *               It received field with values in the form of contact record and get its value from record.
    * @param:       record - The Contact record,  fieldPath - fields api name
    * @return:       A String of field value. This string will contain a field value for the a requested contact record.
    */
    @SuppressWarnings('PMD.DebugsShouldUseLoggingLevel')
    private static String getFieldValue(SObject record, String fieldPath) {
        try {
            List<String> parts = fieldPath.split('\\.');
            SObject current = record;
            
            for (Integer i = 0; i < parts.size() - 1; i++) {
                current = current != null ? current.getSObject(parts[i]) : null;
            }
            
            Object val = current != null ? current.get(parts[parts.size() - 1]) : null;
            return val != null ? String.valueOf(val) : '';
        } catch (Exception e) {
            return null;
        }
    }
    
    Public Class ConnectionData{
        @AuraEnabled public Boolean isDisable;
        @AuraEnabled public Boolean isSendRequest;
        @AuraEnabled public String label;
        @AuraEnabled public String cssClass;
        @AuraEnabled public Boolean protalLogedUserPrivacy;   // logged-in user's connection privacy
    }
    
    @AuraEnabled(cacheable=true)
    public static ConnectionData getConnectionStatus(String portalId, String constituentId){ 
        ConnectionData conData = new ConnectionData();

         

        List<HAM_Connection__c> connections = [SELECT HAM_Connection_Status__c, HAM_Portal_User__c, HAM_Linked_Constituent__c,HAM_Is_Blocked__c
                                                FROM HAM_Connection__C
                                                WHERE HAM_Linked_Constituent__c = :constituentId 
                                                AND HAM_Portal_User__c = :portalId
                                                LIMIT 1 ];
        if(connections != null && !connections.isEmpty()){
            if(connections[0].HAM_Connection_Status__c == 'Request Sent'){
                conData.isDisable = false;
                conData.isSendRequest = false;
                conData.label = 'Cancel Request';
                conData.cssClass = 'btn inactive';
                return conData;
            }else if(connections[0].HAM_Connection_Status__c == 'Connected'){
                conData.isDisable = false;
                conData.isSendRequest = false;
                conData.label = 'Remove Connection';
                conData.cssClass = 'btn inactive';
                return conData;
            }else if( String.isBlank(connections[0].HAM_Connection_Status__c) && connections[0].HAM_Is_Blocked__c){
                conData.isDisable = false;
                conData.isSendRequest = false;
                conData.label = 'Unblock';
                conData.cssClass = 'btn active';
                return conData;
            }
        }
        List<HAM_Connection__c> secondaryConnections = [SELECT HAM_Rejected_Date__c, HAM_Connection_Status__c, HAM_Portal_User__c, HAM_Linked_Constituent__c
                                                            FROM HAM_Connection__C
                                                            WHERE HAM_Linked_Constituent__c = :portalId
                                                            AND HAM_Portal_User__c = :constituentId
                                                            LIMIT 1 ];
        if(secondaryConnections != null && !secondaryConnections.isEmpty()){
            if((secondaryConnections[0].HAM_Connection_Status__c == 'Disconnect' || secondaryConnections[0].HAM_Connection_Status__c == 'Rejected') && secondaryConnections[0].HAM_Rejected_Date__c != null){
                Integer daysDiff = system.today().daysBetween(secondaryConnections[0].HAM_Rejected_Date__c);
                if(daysDiff <= 30){
                    conData.isDisable = true;
                    conData.isSendRequest = true;
                    conData.label = 'Send Request';
                    conData.cssClass = 'btn disable';
                    return conData;
                }
            }
            else if(secondaryConnections[0].HAM_Connection_Status__c == 'Request Sent'){
                conData.isDisable = false;
                conData.isSendRequest = false;
                conData.label = 'Accept';
                conData.cssClass = 'btn active';
                return conData;
            }
        }
            
        conData.isDisable = true;
        conData.isSendRequest = true;
        conData.label = 'Send Request';
        conData.cssClass = 'btn active';
        return conData;
    }


    
}