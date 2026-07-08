/**
 * @description Controller class for the `ham_editProfileCmp` LWC component. 
 * It provides methods to retrieve, update, and manage a user's personal information, 
 * including contact details, employment, address, and profile picture.
 * The class uses wrapper classes to handle complex data structures for communication with the client-side component.
 *
 * @author Sachin
 * @Last Modified On : Mar 12, 2026 
 * @Modification Log :
 *==============================================================================
 * Ver | Date | Author | Modification
 *==============================================================================
 * 1.0 | August 28, 2025 |  Sachin | Initial Version
 * 1.1 | Sept 04, 2025 | Sachin |  Done as part of Optimization
 * 1.2 | Oct 07,2025 | Immanuel | Implemented the duplicate phone number detection
 * 1.3 | Oct 10,2025 | Sachin | Removed county field from UI and Backend
 * 1.4 | Jan 22,2026 | Anirudh | Restructured to use metadata and dynamic queries for fields
 * 1.5 | Jan 27,2026 | Anirudh | Added logic to Directory Privacy Settings
 * 1.6 | Jan 30,2026 | Sachin | Added Privacy Logic, Picklist Fallbacks.
 * 1.7 | Feb 02,2026 | Anirudh | Enhanced error handling for phone and email updates,to handle Employer change tasks
 * 1.8 | Mar 12,2026 | Sachin | Dynamic Master Privacy Labels from SIV, UI Visual Overrides, Strict Dirty Checking.
 * 1.9 | Apr 20,2026 | Anirudh | Student portal changes and Edit profile picture bug fix
 */

@SuppressWarnings('PMD.NoTrailingWhitespace,PMD.IfStmtsMustUseBraces, PMD.StdCyclomaticComplexity, PMD.ExcessivePublicCount, PMD.EmptyCatchBlock, PMD.IfElseStmtsMustUseBraces, PMD.ApexCRUDViolation,PMD.ApexDoc, PMD.EmptyIfStmt, PMD.EmptyStatementBlock, PMD.AvoidNonRestrictiveQueries,PMD.DebugsShouldUseLoggingLevel, PMD.CyclomaticComplexity, PMD.CognitiveComplexity, PMD.NcssCount, PMD.NcssTypeCount, PMD.DetectCopyPasteForApex, PMD.LocalVariableNamingConventions, PMD.ExcessiveParameterList, PMD.ApexSOQLInjection, PMD.AvoidDeeplyNestedIfStmts, PMD.AvoidDebugStatements, PMD.StdCyclometicComplexity, PMD.NcssMethodCount,PMD.IfSmtsMustUseBraces, PMD.IfElseSmtsMustUseBraces,PMD.ForLoopsMustUseBraces,PMD.OneDeclarationPerLine,PMD.OperationWithLimitsInLoop')
public without sharing class HAM_EditProfileController {

    // --- WRAPPERS ---

    public class ProfileSavePayload {
        @AuraEnabled public Map<String, String> dynamicFields;
        @AuraEnabled public Map<String, Boolean> privacyChanges;
        @AuraEnabled public String contentDocId;
        @AuraEnabled public Map<String, List<String>> listSelections;
        @AuraEnabled public Map<String, List<String>> allAvailableOptions;
    }

    public class ListDataResult {
        public Map<String, String> displayValues = new Map<String, String>();
        public Map<String, List<Map<String, Object>>> optionsMap = new Map<String, List<Map<String, Object>>>();
    }

    public class ProfileInitWrapper {
        @AuraEnabled public Contact contactRecord;
        @AuraEnabled public List<EditProfileSection> sections;
        @AuraEnabled public List<VisibilityGroup> visibilityGroups;
        @AuraEnabled public List<String> activePrivacyIds; 
        @AuraEnabled public Boolean isEmployee;
        @AuraEnabled public Boolean isKirklandAlumnae;
        @AuraEnabled public Boolean isStudent;
        @AuraEnabled public Boolean showClassOf;
        @AuraEnabled public String currentChapters;
        @AuraEnabled public Map<String, List<Map<String, String>>> picklistMap; 
        @AuraEnabled public Map<String, List<Map<String, Object>>> listOptionsMap;
        @AuraEnabled public String masterPrivacyLabel;
        @AuraEnabled public String masterPrivacyDescription;
        @AuraEnabled public Boolean isMasterSivVisible;
        // Dynamic mapping of Parent Portal ID -> List of Child Portal IDs		
	    @AuraEnabled public Map<String, List<String>> parentToChildMap;
        @AuraEnabled public Map<String, List<String>> hiddenParentToChildMap;
        @AuraEnabled public Map<String, List<String>> visibleParentHiddenChildMap;
        @AuraEnabled public List<String> visiblePortalIds;
    }

    public class EditProfileSection implements Comparable {
        @AuraEnabled public String name;
        @AuraEnabled public Integer order;
        @AuraEnabled public List<EditProfileField> fields;
        public Integer compareTo(Object compareTo) {
            EditProfileSection other = (EditProfileSection) compareTo;
            return (this.order == null ? 0 : this.order) - (other.order == null ? 0 : other.order);
        }
    }

    public class EditProfileField implements Comparable {
        @AuraEnabled public String label;
        @AuraEnabled public String apiName;
        @AuraEnabled public String relatedObject; 
        @AuraEnabled public String displayType;
        @AuraEnabled public String portalId; 
        @AuraEnabled public String value; 
        @AuraEnabled public Integer order;
        @AuraEnabled public String metadataDevName;
        @AuraEnabled public Boolean isReadOnly; 
        public Integer compareTo(Object compareTo) {
            EditProfileField other = (EditProfileField) compareTo;
            return (this.order == null ? 0 : this.order) - (other.order == null ? 0 : other.order);
        }
    }

    public class VisibilityGroup {
        @AuraEnabled public String label;
        @AuraEnabled public String name;
        @AuraEnabled public List<VisibilityToggle> toggles;
    }

    public class VisibilityToggle {
        @AuraEnabled public String label;
        @AuraEnabled public String description;
        @AuraEnabled public String portalId;
        @AuraEnabled public String sivRecId;		
	    @AuraEnabled public String parentId;
    }

    // --- READ METHOD ---
    
    @AuraEnabled(cacheable=true)
    public static ProfileInitWrapper getProfileData(String contactId) {
        if(String.isBlank(contactId)) { throw new AuraHandledException('Invalid Contact ID provided.'); }
        try {
            ProfileInitWrapper response = new ProfileInitWrapper();
            response.picklistMap = new Map<String, List<Map<String, String>>>();
            response.listOptionsMap = new Map<String, List<Map<String, Object>>>();
            
            List<HAM_Object_Fetcher__mdt> metadata = [
                SELECT DeveloperName, HAM_Level_2__c, HAM_Display_Label__c, HAM_Display_Field__c, 
                       HAM_Display_Type__c, HAM_Service_Indicator_ID__c, HAM_Order__c, Ham_Section_Order__c, 
                       HAM_Related_Object__c, HAM_Additional_Filter__c
                FROM HAM_Object_Fetcher__mdt 
                WHERE HAM_Level_1__c = 'Edit Profile'
                ORDER BY Ham_Section_Order__c ASC, HAM_Order__c ASC
            ];

            String alumniPrivacyId = System.Label.HAM_AlumniPrivacyPortalId;

            // Added check so the Master ID is captured even if it somehow doesn't match 'Directory Visibility'
            List<ucinn_ascendv2__Service_Indicator_Value__c> dbSivs = [
                SELECT Id, Name, ucinn_ascendv2__Service_Indicator_Description__c,HAM_Is_Visible_On_Portal__c, HAM_Portal_ID__c, HAM_Portal_Visible_Name__c,
                HAM_Parent_Service_Indicator_Value__c, HAM_Parent_Service_Indicator_Value__r.HAM_Portal_ID__c
                FROM ucinn_ascendv2__Service_Indicator_Value__c
                WHERE HAM_Portal_ID__c != null 
                AND (HAM_Category__c = 'Directory Visibility' OR HAM_Portal_ID__c = :alumniPrivacyId)
                AND HAM_Is_Visible_On_Portal__c = TRUE
            ];
            
            Map<String, ucinn_ascendv2__Service_Indicator_Value__c> sivMap = new Map<String, ucinn_ascendv2__Service_Indicator_Value__c>();
            response.parentToChildMap = new Map<String, List<String>>();
            response.hiddenParentToChildMap = new Map<String, List<String>>();
            response.visibleParentHiddenChildMap = new Map<String, List<String>>();
            for(ucinn_ascendv2__Service_Indicator_Value__c siv : dbSivs) { sivMap.put(siv.HAM_Portal_ID__c, siv); }            		
	            for(ucinn_ascendv2__Service_Indicator_Value__c siv : dbSivs) { 		
	                sivMap.put(siv.HAM_Portal_ID__c, siv); 		
	                		
	                // Build the dynamic Parent-to-Child map using the database relationship		
	                String parentPortalId = siv.HAM_Parent_Service_Indicator_Value__r != null ? siv.HAM_Parent_Service_Indicator_Value__r.HAM_Portal_ID__c : null;		
	                if (String.isNotBlank(parentPortalId) && sivMap.containsKey(parentPortalId)) {		
	                    if (!response.parentToChildMap.containsKey(parentPortalId)) {		
	                        response.parentToChildMap.put(parentPortalId, new List<String>());		
	                    }		
	                    response.parentToChildMap.get(parentPortalId).add(siv.HAM_Portal_ID__c);
	                } else if (String.isNotBlank(parentPortalId)) {
	                    if (!response.hiddenParentToChildMap.containsKey(parentPortalId)) {
	                        response.hiddenParentToChildMap.put(parentPortalId, new List<String>());
	                    }
	                    response.hiddenParentToChildMap.get(parentPortalId).add(siv.HAM_Portal_ID__c);
	                }
	            }

            // Extract dynamic Master Privacy metadata
            if(sivMap.containsKey(alumniPrivacyId)) {
                response.masterPrivacyLabel = sivMap.get(alumniPrivacyId).HAM_Portal_Visible_Name__c;
                response.masterPrivacyDescription = sivMap.get(alumniPrivacyId).ucinn_ascendv2__Service_Indicator_Description__c;
            }
            response.isMasterSivVisible = sivMap.containsKey(alumniPrivacyId);
            response.visiblePortalIds = new List<String>(sivMap.keySet());

            // Non-visible child SIVs whose parent IS portal-visible (e.g. city with visibility=false under address parent)
            List<ucinn_ascendv2__Service_Indicator_Value__c> hiddenChildSivs = [
                SELECT HAM_Portal_ID__c, HAM_Parent_Service_Indicator_Value__r.HAM_Portal_ID__c
                FROM ucinn_ascendv2__Service_Indicator_Value__c
                WHERE HAM_Is_Visible_On_Portal__c = FALSE
                AND HAM_Portal_ID__c != null
                AND HAM_Category__c = 'Directory Visibility'
                AND HAM_Parent_Service_Indicator_Value__c != null
            ];
            for (ucinn_ascendv2__Service_Indicator_Value__c siv : hiddenChildSivs) {
                String hParentPortalId = siv.HAM_Parent_Service_Indicator_Value__r != null
                    ? siv.HAM_Parent_Service_Indicator_Value__r.HAM_Portal_ID__c
                    : null;
                if (String.isNotBlank(hParentPortalId) && sivMap.containsKey(hParentPortalId)) {
                    if (!response.visibleParentHiddenChildMap.containsKey(hParentPortalId)) {
                        response.visibleParentHiddenChildMap.put(hParentPortalId, new List<String>());
                    }
                    response.visibleParentHiddenChildMap.get(hParentPortalId).add(siv.HAM_Portal_ID__c);
                }
            }

            Map<String, EditProfileSection> sectionMap = new Map<String, EditProfileSection>();
            Map<String, HAM_Object_Fetcher__mdt> metadataMap = new Map<String, HAM_Object_Fetcher__mdt>();
            
            Set<String> contactFields = new Set<String>{'Id', 'FirstName', 'LastName', 'Name', 'HAM_Reunion_Year__c', 'HAM_Profile_Picture_URL__c', 'ucinn_ascendv2__Primary_Contact_Type__c','ucinn_ascendv2__Contact_Type__c', 'Constituent_Employer__r.Name', 'Job_Title__c', 'HAM_LiveAlumni_Job_Title__c'};
            Set<String> socialPlatforms = new Set<String>();
            List<HAM_Object_Fetcher__mdt> listFieldsToFetch = new List<HAM_Object_Fetcher__mdt>();

            for(HAM_Object_Fetcher__mdt mdt : metadata) {
                if(mdt.HAM_Display_Type__c != 'Replaceable'){
                    metadataMap.put(mdt.DeveloperName, mdt);
                    if(!sectionMap.containsKey(mdt.HAM_Level_2__c)) {
                        EditProfileSection sec = new EditProfileSection();
                        sec.name = mdt.HAM_Level_2__c;
                        sec.order = Integer.valueOf(mdt.Ham_Section_Order__c);
                        sec.fields = new List<EditProfileField>();
                        sectionMap.put(mdt.HAM_Level_2__c, sec);
                    }

                    EditProfileField field = new EditProfileField();
                    field.label = mdt.HAM_Display_Label__c;
                    field.apiName = mdt.HAM_Display_Field__c;
                    field.displayType = mdt.HAM_Display_Type__c;
                    field.portalId = mdt.HAM_Service_Indicator_ID__c;
                    field.order = Integer.valueOf(mdt.HAM_Order__c);
                    field.metadataDevName = mdt.DeveloperName;
                    field.relatedObject = mdt.HAM_Related_Object__c;

                    if(mdt.HAM_Display_Type__c == 'Contact Field' || mdt.HAM_Display_Type__c == 'Lookup') {
                        if(String.isNotBlank(mdt.HAM_Display_Field__c)) contactFields.add(String.escapeSingleQuotes(mdt.HAM_Display_Field__c));
                    } 
                    else if (mdt.HAM_Display_Type__c == 'Picklist') {
                        List<Map<String, String>> opts = getPicklistOptions(mdt.HAM_Related_Object__c, mdt.HAM_Display_Field__c);
                        if(mdt.HAM_Related_Object__c == 'ucinn_ascendv2__Address_Relation__c') {
                            Set<String> allowed = new Set<String>{'Residence', 'Business'};
                            List<Map<String, String>> filtered = new List<Map<String, String>>();
                            for(Map<String, String> opt : opts) { if(allowed.contains(opt.get('value'))) filtered.add(opt); }
                            opts = filtered;
                        }
                        response.picklistMap.put(mdt.DeveloperName, opts);
                    }
                    else if (mdt.HAM_Display_Type__c == 'Related Single' && mdt.HAM_Related_Object__c == 'ucinn_ascendv2__Social_Media__c') {
                        if(mdt.HAM_Additional_Filter__c != null && mdt.HAM_Additional_Filter__c.contains('\'')) {
                            socialPlatforms.add(mdt.HAM_Additional_Filter__c.substringBetween('\'', '\''));
                        }
                    }
                    else if (mdt.HAM_Display_Type__c == 'List') {
                        listFieldsToFetch.add(mdt);
                    }
                    sectionMap.get(mdt.HAM_Level_2__c).fields.add(field);
                }
            }

            response.sections = sectionMap.values();
            response.sections.sort();
            
            for (EditProfileSection sec : response.sections) {
                if (sec.fields != null) {
                    sec.fields.sort(); 
                }
            }

            String query = 'SELECT ' + String.join(new List<String>(contactFields), ', ') + 
                           ', (SELECT ucinn_ascendv2__Type__c, ucinn_ascendv2__Address__r.ucinn_ascendv2__Address_Line_1__c, ucinn_ascendv2__Address__r.ucinn_ascendv2__City__c, ucinn_ascendv2__Address__r.ucinn_ascendv2__State__c, ucinn_ascendv2__Address__r.ucinn_ascendv2__Country__c, ucinn_ascendv2__Address__r.ucinn_ascendv2__Postal_Code__c FROM ucinn_ascendv2__Address_Relations_Contact__r WHERE ucinn_ascendv2__Is_Preferred__c = true LIMIT 1)' +
                           ', (SELECT ucinn_ascendv2__Phone_Number__c, ucinn_ascendv2__Type__c FROM ucinn_ascendv2__Phones_Contact__r WHERE ucinn_ascendv2__Is_Preferred__c = true ORDER BY LastModifiedDate DESC LIMIT 1)' +
                           ', (SELECT ucinn_ascendv2__Email_Address__c,ucinn_ascendv2__Type__c FROM ucinn_ascendv2__Emails_Contact__r WHERE ucinn_ascendv2__Is_Preferred__c = true ORDER BY LastModifiedDate DESC LIMIT 1)' +
                           ' FROM Contact WHERE Id = :contactId LIMIT 1';
            
            Contact con = Database.query(query);
            response.contactRecord = con;

            String pType = (String)con.get('ucinn_ascendv2__Primary_Contact_Type__c');
            response.isEmployee = (pType != null && pType.containsIgnoreCase('Employee'));
            response.isStudent = (pType != null && pType.containsIgnoreCase('Student'));

            String cType = (String)con.get('ucinn_ascendv2__Contact_Type__c');
            response.isKirklandAlumnae = (cType != null && cType.containsIgnoreCase('Kirkland Alumnae'));
            response.showClassOf = (cType != null && (cType.containsIgnoreCase('Hamilton Alumni') || cType.containsIgnoreCase('Hamilton Alumini') || cType.containsIgnoreCase('Kirkland Alumnae')));

            // Build per-role hidden/editable sets; filter list fields before fetching
            Set<String> hiddenDevNames = response.isStudent == true
                ? new Set<String>{'EditProfile_Employer', 'EditProfile_JobTitle', 'EditProfile_Industry', 'EditProfile_UndergraduateAthletics', 'EditProfile_ResidenceHalls'}
                : new Set<String>{'EditProfile_TeamsIFollow'};
            Set<String> studentEditableDevNames = new Set<String>{
                'EditProfile_Linkedin', 'EditProfile_Facebook', 'EditProfile_Twitter',
                'EditProfile_Instagram', 'EditProfile_TeamsIFollow'
            };
            List<HAM_Object_Fetcher__mdt> filteredListFields = new List<HAM_Object_Fetcher__mdt>();
            for (HAM_Object_Fetcher__mdt mdt : listFieldsToFetch) {
                if (!hiddenDevNames.contains(mdt.DeveloperName)) {
                    filteredListFields.add(mdt);
                }
            }

            Map<String, String> smMap = getSocialMediaMap(con.Id, socialPlatforms);
            ListDataResult listResult = fetchListFieldData(con.Id, filteredListFields);
            response.listOptionsMap = listResult.optionsMap;
            
            for(EditProfileSection sec : response.sections) {
                for(EditProfileField field : sec.fields) {
                    if(field.displayType == 'Contact Field') {
                        try {
                            String rawVal = String.valueOf(con.get(field.apiName));
                            if(rawVal == 'null') rawVal = '';
                            if(field.apiName == 'HAM_LiveAlumni_Employer__c') {
                                SObject empRel = con.getSObject('Constituent_Employer__r');
                                String constituentName = (empRel != null) ? (String)empRel.get('Name') : null;
                                field.value = String.isNotBlank(constituentName) ? constituentName : rawVal;
                            } else if(field.apiName == 'Job_Title__c') {
                                String liveAlumniJobTitle = String.valueOf(con.get('HAM_LiveAlumni_Job_Title__c'));
                                if(liveAlumniJobTitle == 'null') liveAlumniJobTitle = '';
                                field.value = String.isNotBlank(rawVal) ? rawVal : liveAlumniJobTitle;
                            } else {
                                field.value = rawVal;
                            }
                        } catch(Exception e) { field.value = ''; }
                    }
                    else if (field.displayType == 'Lookup') {
                        if (field.apiName != null && field.apiName.contains('.')) {
                            List<String> parts = field.apiName.split('\\.');
                            String objName = parts[0];
                            String fieldName = parts[1];
                            SObject relObj = con.getSObject(objName);
                            if(relObj != null) { field.value = (String)relObj.get(fieldName); }
                        }
                    }
                    else if (field.displayType == 'Address' && !con.ucinn_ascendv2__Address_Relations_Contact__r.isEmpty()) {
                        ucinn_ascendv2__Address_Relation__c ar = con.ucinn_ascendv2__Address_Relations_Contact__r[0];
                        if(field.apiName == 'ucinn_ascendv2__Address_Line_1__c') field.value = ar.ucinn_ascendv2__Address__r.ucinn_ascendv2__Address_Line_1__c;
                        else if(field.apiName == 'ucinn_ascendv2__City__c') field.value = ar.ucinn_ascendv2__Address__r.ucinn_ascendv2__City__c;
                        else if(field.apiName == 'ucinn_ascendv2__State__c') field.value = ar.ucinn_ascendv2__Address__r.ucinn_ascendv2__State__c;
                        else if(field.apiName == 'ucinn_ascendv2__Country__c') field.value = ar.ucinn_ascendv2__Address__r.ucinn_ascendv2__Country__c;
                        else if(field.apiName == 'ucinn_ascendv2__Postal_Code__c') field.value = ar.ucinn_ascendv2__Address__r.ucinn_ascendv2__Postal_Code__c;
                    }
                    else if (field.relatedObject == 'ucinn_ascendv2__Address_Relation__c' && !con.ucinn_ascendv2__Address_Relations_Contact__r.isEmpty()) {
                        field.value = con.ucinn_ascendv2__Address_Relations_Contact__r[0].ucinn_ascendv2__Type__c;
                    }
                    else if (field.relatedObject == 'ucinn_ascendv2__Phone__c' && !con.ucinn_ascendv2__Phones_Contact__r.isEmpty()) {
                        field.value = con.ucinn_ascendv2__Phones_Contact__r[0].ucinn_ascendv2__Type__c;
                    }
                    else if (field.relatedObject == 'ucinn_ascendv2__Email__c' && !con.ucinn_ascendv2__Emails_Contact__r.isEmpty()) {
                        field.value = con.ucinn_ascendv2__Emails_Contact__r[0].ucinn_ascendv2__Type__c;
                    }
                    else if (field.displayType == 'Related Single' && field.relatedObject == 'ucinn_ascendv2__Social_Media__c') {
                        HAM_Object_Fetcher__mdt mdtConfig = metadataMap.get(field.metadataDevName);
                        if(mdtConfig != null && mdtConfig.HAM_Additional_Filter__c != null) {
                            String platform = mdtConfig.HAM_Additional_Filter__c.substringBetween('\'', '\'');
                            if(smMap.containsKey(platform)) field.value = smMap.get(platform);
                        }
                    }
                    else if (field.displayType == 'List' && listResult.displayValues.containsKey(field.metadataDevName)) {
                        field.value = listResult.displayValues.get(field.metadataDevName);
                    }
                }
            }

            // Remove hidden fields from sections; mark non-editable fields read-only for students
            List<EditProfileSection> filteredSections = new List<EditProfileSection>();
            for (EditProfileSection sec : response.sections) {
                List<EditProfileField> filteredFields = new List<EditProfileField>();
                for (EditProfileField field : sec.fields) {
                    if (!hiddenDevNames.contains(field.metadataDevName)) {
                        if (response.isStudent == true && !studentEditableDevNames.contains(field.metadataDevName)) {
                            field.isReadOnly = true;
                        }
                        filteredFields.add(field);
                    }
                }
                if (!filteredFields.isEmpty()) {
                    sec.fields = filteredFields;
                    filteredSections.add(sec);
                }
            }
            response.sections = filteredSections;

            // Strip hidden field portal IDs from the privacy panel
            List<HAM_Object_Fetcher__mdt> visibilityMetadata = new List<HAM_Object_Fetcher__mdt>();
            for (HAM_Object_Fetcher__mdt mdt : metadata) {
                if (!hiddenDevNames.contains(mdt.DeveloperName)) {
                    visibilityMetadata.add(mdt);
                }
            }
            response.visibilityGroups = buildVisibilityGroups(visibilityMetadata, sivMap);
            
            Set<String> activeIdsSet = new Set<String>();
            for(ucinn_ascendv2__Service_Indicator__c si : [SELECT ucinn_ascendv2__Service_Indicator_Value__r.HAM_Portal_ID__c FROM ucinn_ascendv2__Service_Indicator__c WHERE ucinn_ascendv2__Contact__c = :contactId AND ucinn_ascendv2__Is_Active__c = TRUE AND ucinn_ascendv2__Service_Indicator_Value__r.HAM_Portal_ID__c != null]) {
                activeIdsSet.add(si.ucinn_ascendv2__Service_Indicator_Value__r.HAM_Portal_ID__c);
            }
            response.activePrivacyIds = new List<String>(activeIdsSet);

            return response;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'HAM_EditProfileController.getProfileData Error: ' + e.getMessage() + ' | Stack: ' + e.getStackTraceString());
            throw new AuraHandledException('Load Error: ' + e.getMessage());
        }
    }

    // --- SAVE METHOD ---

    @AuraEnabled
    public static String saveProfile(String contactId, String payloadJSON) {
        if(String.isBlank(contactId) || String.isBlank(payloadJSON)) {
            throw new AuraHandledException('Invalid parameters provided.');
        }
        Savepoint sp = Database.setSavepoint();
        Id userId = UserInfo.getUserId();
        try {
            ProfileSavePayload payload = (ProfileSavePayload) JSON.deserialize(payloadJSON, ProfileSavePayload.class);
            
            Map<String, String> dynamicFields = payload.dynamicFields != null ? payload.dynamicFields : new Map<String, String>();
            Map<String, Boolean> privacyChanges = payload.privacyChanges != null ? payload.privacyChanges : new Map<String, Boolean>();
            Map<String, List<String>> listSelections = payload.listSelections != null ? payload.listSelections : new Map<String, List<String>>();
            Map<String, List<String>> allAvailableOptions = payload.allAvailableOptions != null ? payload.allAvailableOptions : new Map<String, List<String>>();
            String contentDocId = payload.contentDocId;

            List<HAM_Object_Fetcher__mdt> metadata = [SELECT DeveloperName, HAM_Display_Field__c, HAM_Display_Type__c, HAM_Related_Object__c, HAM_Additional_Filter__c FROM HAM_Object_Fetcher__mdt WHERE HAM_Level_1__c = 'Edit Profile'];
            Map<String, HAM_Object_Fetcher__mdt> metaMap = new Map<String, HAM_Object_Fetcher__mdt>();
            
            Set<String> fieldsToQuery = new Set<String>{'Id', 'Job_Title__c', 'HAM_LiveAlumni_Job_Title__c', 'HAM_Profile_Picture_URL__c', 'ucinn_ascendv2__Primary_Contact_Type__c', 'Constituent_Employer__r.Name'};
            for(HAM_Object_Fetcher__mdt m : metadata) {
                metaMap.put(m.DeveloperName, m);
                if(m.HAM_Display_Type__c == 'Contact Field' && String.isNotBlank(m.HAM_Display_Field__c)) {
                    fieldsToQuery.add(m.HAM_Display_Field__c);
                }
            }

            Contact existingCon = Database.query('SELECT ' + String.join(new List<String>(fieldsToQuery), ', ') + ' FROM Contact WHERE Id = :contactId LIMIT 1');
            Contact contactToUpdate = new Contact(Id = contactId);
            Boolean isContactUpdated = false;
            
            Map<String, Object> addressUpdates = new Map<String, Object>();
            Map<String, String> socialMediaUpdates = new Map<String, String>();
            List<Task> tasksToInsert = new List<Task>();
            
            String phoneVal = null, phoneTypeVal = null, emailVal = null, emailTypeVal = null; 
            Boolean hasPhoneUpdate = false, hasPhoneTypeUpdate = false, hasEmailUpdate = false, hasEmailTypeUpdate = false, hasAddressFieldUpdate = false;

            for(String key : dynamicFields.keySet()) {
                if(!metaMap.containsKey(key)) continue;
                HAM_Object_Fetcher__mdt config = metaMap.get(key);
                String value = dynamicFields.get(key);
                String newValStr = value == null ? '' : value; 
                String apiName = config.HAM_Display_Field__c;

                if(apiName == 'HAM_Formatted_Phone__c') { phoneVal = value; hasPhoneUpdate = true; continue; }
                if(config.HAM_Related_Object__c == 'ucinn_ascendv2__Phone__c') { phoneTypeVal = value; hasPhoneTypeUpdate = true; continue; }
                
                if(apiName == 'HAM_PreferredEmail__c') { emailVal = value; hasEmailUpdate = true; continue; }
                if(config.HAM_Related_Object__c == 'ucinn_ascendv2__Email__c') { emailTypeVal = value; hasEmailTypeUpdate = true; continue; }

                if(config.HAM_Display_Type__c == 'Contact Field') {
                    if(apiName == 'HAM_LiveAlumni_Employer__c') {
                         SObject empRel = existingCon.getSObject('Constituent_Employer__r');
                         String constituentName = (empRel != null) ? (String)empRel.get('Name') : null;
                         String dbRawVal = String.valueOf(existingCon.get(apiName));
                         String oldUIVal = String.isNotBlank(constituentName) ? constituentName : (dbRawVal == null ? '' : dbRawVal);
                         
                         if(oldUIVal != newValStr) {
                             handleEmployerUpdate(value, contactId, tasksToInsert);
                             contactToUpdate.put(apiName, value);
                             isContactUpdated = true;
                         }
                    } else if (apiName == 'Job_Title__c') {
                        String targetField = String.isNotBlank(existingCon.Job_Title__c) ? 'Job_Title__c' : 'HAM_LiveAlumni_Job_Title__c';
                        String oldVal = String.valueOf(existingCon.get(targetField)); if(oldVal == null) oldVal = '';
                        if(oldVal != newValStr) {
                            contactToUpdate.put(targetField, value);
                            isContactUpdated = true;
                        }
                    } else if (apiName == 'FirstName' || apiName == 'LastName') {
                        String oldVal = String.valueOf(existingCon.get(apiName)); if(oldVal == null) oldVal = '';
                        if (oldVal != newValStr && String.isNotBlank(newValStr)) {
                            contactToUpdate.put(apiName, newValStr);
                            isContactUpdated = true;
                        }
                    } else {
                        Object oldValObj = existingCon.get(apiName);
                        String oldValStr = oldValObj == null ? '' : String.valueOf(oldValObj).trim();
                        if(oldValStr.endsWith('.0') && !newValStr.endsWith('.0')) { oldValStr = oldValStr.substringBeforeLast('.0'); }

                        if(oldValStr != newValStr) {
                            if(String.isBlank(newValStr)) {
                                contactToUpdate.put(apiName, null);
                            } else {
                                contactToUpdate.put(apiName, value);
                            }
                            isContactUpdated = true;
                        }
                    }
                }
                else if(config.HAM_Display_Type__c == 'Address' || config.HAM_Related_Object__c == 'ucinn_ascendv2__Address_Relation__c') {
                    addressUpdates.put(apiName, value);
                    if(config.HAM_Display_Type__c == 'Address') hasAddressFieldUpdate = true;
                }
                else if(config.HAM_Display_Type__c == 'Related Single' && config.HAM_Related_Object__c == 'ucinn_ascendv2__Social_Media__c') {
                    String platform = config.HAM_Additional_Filter__c.substringBetween('\'', '\'');
                    socialMediaUpdates.put(platform, value);
                }
            }

            if(String.isNotBlank(contentDocId)){
                String docPublicLink = generatePublicLinkForDoc(contentDocId);
                if(String.isNotBlank(docPublicLink) && docPublicLink != existingCon.HAM_Profile_Picture_URL__c){
                    contactToUpdate.HAM_Profile_Picture_URL__c = docPublicLink;
                    isContactUpdated = true;
                }
            }

            if(hasPhoneUpdate) handlePhone(contactId, phoneVal, phoneTypeVal);
            else if (hasPhoneTypeUpdate && String.isNotBlank(phoneTypeVal)) handlePhoneTypeOnly(contactId, phoneTypeVal);
            
            if(hasEmailUpdate) handleEmail(contactId, emailVal);
            if(hasEmailTypeUpdate && String.isNotBlank(emailTypeVal)) handleEmailTypeOnly(contactId, emailTypeVal);

            if(!listSelections.isEmpty() || !allAvailableOptions.isEmpty()) {
                if(handleListUpdates(contactId, listSelections, allAvailableOptions, metaMap, contactToUpdate, existingCon)) {
                    isContactUpdated = true; 
                }
            }

            if(isContactUpdated) {
                update contactToUpdate;
            }
            
            createAscendBypassMethod(userId);
            
            if(!addressUpdates.isEmpty()) handleAddressUpdate(contactId, addressUpdates, tasksToInsert);
            if(!socialMediaUpdates.isEmpty()) handleSocialMediaUpdate(contactId, socialMediaUpdates, tasksToInsert);
            if(!privacyChanges.isEmpty()) handlePrivacyChanges(contactId, privacyChanges);
            if(String.isNotBlank(contentDocId)) handleProfilePicLink(contactId, contentDocId, tasksToInsert);
            if(!tasksToInsert.isEmpty()) insert tasksToInsert;

            return 'Success';
        } catch (Exception e) {
            Database.rollback(sp);
            System.debug(LoggingLevel.ERROR, 'HAM_EditProfileController.saveProfile Error: ' + e.getMessage() + ' | Stack: ' + e.getStackTraceString());
            String msg = e.getMessage();
            if(msg.contains('ucinn_ascendv2__Phone_Number__c') || (msg.contains('DUPLICATE_VALUE') && msg.contains('Phone'))) { return 'Error: PHONE_ERROR'; }
            if(msg.contains('ucinn_ascendv2__Email_Address__c') || msg.contains('INVALID_EMAIL_ADDRESS')) { return 'Error: EMAIL_ERROR'; }
            if(msg.contains('DUPLICATE_VALUE')) return 'Error: This value already exists.';
            if(msg.contains('FIELD_CUSTOM_VALIDATION_EXCEPTION')) { return 'Error: Please check your input. ' + msg.substringAfter('FIELD_CUSTOM_VALIDATION_EXCEPTION,').substringBefore(':'); }
            throw new AuraHandledException('Error saving profile: ' + msg);
        } finally {
            removeAscendBypassMethod(userId);
        }
    }

    @AuraEnabled
    public static String deleteProfilePic(String contentDocId) {
        try {
            if(String.isNotBlank(contentDocId)) delete [SELECT Id FROM ContentDocument WHERE Id = :contentDocId LIMIT 1];
            return 'Success';
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'HAM_EditProfileController.deleteProfilePic Error: ' + e.getMessage() + ' | Stack: ' + e.getStackTraceString());
            throw new AuraHandledException(e.getMessage());
        }
    }

    // --- PRIVATE HELPERS ---

    private static List<VisibilityGroup> buildVisibilityGroups(List<HAM_Object_Fetcher__mdt> metadata, Map<String, ucinn_ascendv2__Service_Indicator_Value__c> sivMap) {
        Map<String, VisibilityGroup> groups = new Map<String, VisibilityGroup>();
        Set<String> processedPortalIds = new Set<String>(); 

        for(HAM_Object_Fetcher__mdt mdt : metadata) {
            String portalId = mdt.HAM_Service_Indicator_ID__c;
            if(String.isNotBlank(portalId) && portalId != System.Label.HAM_AlumniPrivacyPortalId && sivMap.containsKey(portalId)) {
                if(processedPortalIds.contains(portalId)) continue;
                processedPortalIds.add(portalId);

                ucinn_ascendv2__Service_Indicator_Value__c sivRecord = sivMap.get(portalId);

                if(!groups.containsKey(mdt.HAM_Level_2__c)) {
                    VisibilityGroup g = new VisibilityGroup();
                    g.label = mdt.HAM_Level_2__c;
                    g.name = mdt.HAM_Level_2__c.deleteWhitespace();
                    g.toggles = new List<VisibilityToggle>();
                    groups.put(mdt.HAM_Level_2__c, g);
                }
                
                VisibilityToggle t = new VisibilityToggle();
                t.label = sivRecord.HAM_Portal_Visible_Name__c; 
                t.description = sivRecord.ucinn_ascendv2__Service_Indicator_Description__c;
                t.portalId = portalId;
                t.sivRecId = sivRecord.Id;
                t.parentId = sivRecord.HAM_Parent_Service_Indicator_Value__c;
                groups.get(mdt.HAM_Level_2__c).toggles.add(t);
            }
        }
        return groups.values();
    }

    private static ListDataResult fetchListFieldData(String contactId, List<HAM_Object_Fetcher__mdt> configs) {
        ListDataResult result = new ListDataResult();
        Set<Id> activeInvIds = new Set<Id>();
        for(ucinn_ascendv2__Involvement__c inv : [SELECT ucinn_ascendv2__Involvement_Code__c FROM ucinn_ascendv2__Involvement__c WHERE ucinn_ascendv2__Contact__c = :contactId AND (ucinn_ascendv2__End_Date__c = null OR ucinn_ascendv2__End_Date__c > TODAY)]) {
            activeInvIds.add(inv.ucinn_ascendv2__Involvement_Code__c);
        }

        for(HAM_Object_Fetcher__mdt config : configs) {
            try {
                String obj = config.HAM_Related_Object__c;
                String filter = config.HAM_Additional_Filter__c;
                List<Map<String, Object>> opts = new List<Map<String, Object>>();
                List<String> selectedLabels = new List<String>();

                if(obj == 'ucinn_ascendv2__Involvement__c') {
                    String q = 'SELECT Id, Name, ucinn_ascendv2__Involvement_Description__c FROM ucinn_ascendv2__Involvement_Value__c';
                    if(String.isNotBlank(filter)) { q += ' WHERE ' + filter; }
                    q += ' ORDER BY Name';
                    for(SObject v : Database.query(q)) {
                        String label = (String)v.get('ucinn_ascendv2__Involvement_Description__c');
                        if(String.isBlank(label)) label = (String)v.get('Name');
                        Boolean isChecked = activeInvIds.contains(v.Id);
                        opts.add(new Map<String, Object>{'value' => String.valueOf(v.Id), 'label' => label, 'checked' => isChecked});
                        if(isChecked) selectedLabels.add(label);
                    }
                } else if (obj == 'ucinn_ascendv2__Funding_Interest__c') {
                    // Pre-query which catalog IDs this contact already follows
                    Set<Id> activeInterestIds = new Set<Id>();
                    for (ucinn_ascendv2__Funding_Interest__c fi : [
                        SELECT ucinn_ascendv2__Foundation_Funding_Interest__c
                        FROM ucinn_ascendv2__Funding_Interest__c
                        WHERE ucinn_ascendv2__Contact__c = :contactId
                    ]) {
                        activeInterestIds.add(fi.ucinn_ascendv2__Foundation_Funding_Interest__c);
                    }
                    // Query catalog with the metadata filter (HAM_Category__c = 'Athletics')
                    String q = 'SELECT Id, Name FROM ucinn_ascendv2__Foundation_Funding_Interests__c';
                    if (String.isNotBlank(filter)) { q += ' WHERE ' + filter; }
                    q += ' ORDER BY Name';
                    for (SObject v : Database.query(q)) {
                        String label = (String)v.get('Name');
                        Boolean isChecked = activeInterestIds.contains(v.Id);
                        opts.add(new Map<String, Object>{'value' => String.valueOf(v.Id), 'label' => label, 'checked' => isChecked});
                        if (isChecked) selectedLabels.add(label);
                    }
                } else if(obj == 'HAM_Chapter_Lookup__c') {
                    Set<Id> activeChapterIds = new Set<Id>();
                    for(HAM_Current_Chapter__c junc : [
                        SELECT Chapter__c FROM HAM_Current_Chapter__c
                        WHERE Constituent__c = :contactId AND Is_Active__c = true
                    ]) {
                        activeChapterIds.add(junc.Chapter__c);
                    }
                    String q = 'SELECT Id, Name FROM HAM_Chapter_Lookup__c';
                    if(String.isNotBlank(filter)) { q += ' WHERE ' + filter; }
                    q += ' ORDER BY Name';
                    for(SObject v : Database.query(q)) {
                        String label = (String)v.get('Name');
                        Boolean isChecked = activeChapterIds.contains(v.Id);
                        opts.add(new Map<String, Object>{'value' => String.valueOf(v.Id), 'label' => label, 'checked' => isChecked});
                        if(isChecked) selectedLabels.add(label);
                    }
                }
                result.optionsMap.put(config.DeveloperName, opts);
                result.displayValues.put(config.DeveloperName, String.join(selectedLabels, ', '));
            } catch(Exception e) { System.debug('List Field error: ' + e.getMessage()); }
        }
        return result;
    }

    private static Boolean handleListUpdates(String contactId, Map<String, List<String>> listSelections, Map<String, List<String>> allAvailableOptions, Map<String, HAM_Object_Fetcher__mdt> metaMap, Contact contactToUpdate, Contact existingCon) {
        Boolean contactChanged = false;
        String pType = existingCon.ucinn_ascendv2__Primary_Contact_Type__c;
        Id invRTId = Schema.SObjectType.ucinn_ascendv2__Involvement__c.getRecordTypeInfosByDeveloperName().get(
            pType != null && pType.containsIgnoreCase('Student') ? 'Student_Involvement' : 'Alumni_Involvement'
        ).getRecordTypeId();

        Set<Id> allPossibleInvIds = new Set<Id>();
        Set<Id> selectedInvValueIds = new Set<Id>();
        Set<Id> selectedChapterIds = new Set<Id>();
        Set<Id> allPossibleChapterIds = new Set<Id>();
        Set<Id> allPossibleFundingIds = new Set<Id>();
        Set<Id> selectedFundingIds = new Set<Id>();
        
        for(String key : metaMap.keySet()) {
            HAM_Object_Fetcher__mdt mdt = metaMap.get(key);
            if(mdt == null) continue;
            
            if(mdt.HAM_Related_Object__c == 'ucinn_ascendv2__Involvement__c') {
                if(listSelections.containsKey(key)) { for(String val : listSelections.get(key)) selectedInvValueIds.add((Id)val); }
                if(allAvailableOptions.containsKey(key)) { for(String val : allAvailableOptions.get(key)) allPossibleInvIds.add((Id)val); }
            } else if (mdt.HAM_Related_Object__c == 'ucinn_ascendv2__Funding_Interest__c') {
                if (listSelections.containsKey(key)) { for (String val : listSelections.get(key)) selectedFundingIds.add((Id)val); }
                if (allAvailableOptions.containsKey(key)) { for (String val : allAvailableOptions.get(key)) allPossibleFundingIds.add((Id)val); }
            } else if(mdt.HAM_Related_Object__c == 'HAM_Chapter_Lookup__c') {
                if(listSelections.containsKey(key)) { for(String val : listSelections.get(key)) selectedChapterIds.add((Id)val); }
                if(allAvailableOptions.containsKey(key)) { for(String val : allAvailableOptions.get(key)) allPossibleChapterIds.add((Id)val); }
            }
        }

        if(!allPossibleInvIds.isEmpty()) {
            List<ucinn_ascendv2__Involvement__c> existingInvs = [
                SELECT Id, ucinn_ascendv2__Involvement_Code__c 
                FROM ucinn_ascendv2__Involvement__c 
                WHERE ucinn_ascendv2__Contact__c = :contactId 
                AND (ucinn_ascendv2__End_Date__c = null OR ucinn_ascendv2__End_Date__c > TODAY)
                AND ucinn_ascendv2__Involvement_Code__c IN :allPossibleInvIds
            ];
            
            List<ucinn_ascendv2__Involvement__c> toInsert = new List<ucinn_ascendv2__Involvement__c>();
            List<ucinn_ascendv2__Involvement__c> toUpdate = new List<ucinn_ascendv2__Involvement__c>();
            Set<Id> existingInvValueIds = new Set<Id>();
            
            for(ucinn_ascendv2__Involvement__c inv : existingInvs) {
                existingInvValueIds.add(inv.ucinn_ascendv2__Involvement_Code__c);
                if(!selectedInvValueIds.contains(inv.ucinn_ascendv2__Involvement_Code__c)) {
                    inv.ucinn_ascendv2__End_Date__c = Date.today();
                    toUpdate.add(inv);
                }
            }
            
            for(Id valId : selectedInvValueIds) {
                if(!existingInvValueIds.contains(valId)) {
                    toInsert.add(new ucinn_ascendv2__Involvement__c(
                        ucinn_ascendv2__Contact__c = contactId,
                        ucinn_ascendv2__Involvement_Code__c = valId,
                        RecordTypeId = invRTId,
                        ucinn_ascendv2__Start_Date__c = Date.today()
                    ));
                }
            }
            if(!toInsert.isEmpty()) insert toInsert;
            if(!toUpdate.isEmpty()) update toUpdate;
        }

        // Funding Interest (Teams I Follow) — delete removed, insert added
        if (!allPossibleFundingIds.isEmpty()) {
            List<ucinn_ascendv2__Funding_Interest__c> existingFIs = [
                SELECT Id, ucinn_ascendv2__Foundation_Funding_Interest__c
                FROM ucinn_ascendv2__Funding_Interest__c
                WHERE ucinn_ascendv2__Contact__c = :contactId
                AND ucinn_ascendv2__Foundation_Funding_Interest__c IN :allPossibleFundingIds
            ];
            Set<Id> existingCatalogIds = new Set<Id>();
            List<ucinn_ascendv2__Funding_Interest__c> fiToDelete = new List<ucinn_ascendv2__Funding_Interest__c>();
            for (ucinn_ascendv2__Funding_Interest__c fi : existingFIs) {
                existingCatalogIds.add(fi.ucinn_ascendv2__Foundation_Funding_Interest__c);
                if (!selectedFundingIds.contains(fi.ucinn_ascendv2__Foundation_Funding_Interest__c)) {
                    fiToDelete.add(fi);
                }
            }
            List<ucinn_ascendv2__Funding_Interest__c> fiToInsert = new List<ucinn_ascendv2__Funding_Interest__c>();
            for (Id catalogId : selectedFundingIds) {
                if (!existingCatalogIds.contains(catalogId)) {
                    fiToInsert.add(new ucinn_ascendv2__Funding_Interest__c(
                        ucinn_ascendv2__Contact__c = contactId,
                        ucinn_ascendv2__Foundation_Funding_Interest__c = catalogId
                    ));
                }
            }
            if (!fiToDelete.isEmpty()) delete fiToDelete;
            if (!fiToInsert.isEmpty()) insert fiToInsert;
        }

        if(!allPossibleChapterIds.isEmpty()) {
            List<HAM_Current_Chapter__c> existingJuncs = [
                SELECT Id, Chapter__c, Is_Active__c, Source__c
                FROM HAM_Current_Chapter__c
                WHERE Constituent__c = :contactId
                AND Chapter__c IN :allPossibleChapterIds
            ];
            Map<Id, HAM_Current_Chapter__c> chapterToJuncMap = new Map<Id, HAM_Current_Chapter__c>();
            for(HAM_Current_Chapter__c junc : existingJuncs) { chapterToJuncMap.put(junc.Chapter__c, junc); }

            List<HAM_Current_Chapter__c> toInsert = new List<HAM_Current_Chapter__c>();
            List<HAM_Current_Chapter__c> toUpdate = new List<HAM_Current_Chapter__c>();

            for(Id chapterId : allPossibleChapterIds) {
                Boolean isSelected = selectedChapterIds.contains(chapterId);
                if(chapterToJuncMap.containsKey(chapterId)) {
                    HAM_Current_Chapter__c junc = chapterToJuncMap.get(chapterId);
                    Boolean needsUpdate = false;
                    if(isSelected && !junc.Is_Active__c) { junc.Is_Active__c = true; needsUpdate = true; }
                    else if(!isSelected && junc.Is_Active__c) { junc.Is_Active__c = false; needsUpdate = true; }
                    if(needsUpdate) {
                        if(junc.Source__c != 'Portal Update') { junc.Source__c = 'Portal Update'; }
                        toUpdate.add(junc);
                    }
                } else if(isSelected) {
                    toInsert.add(new HAM_Current_Chapter__c(
                        Constituent__c = contactId,
                        Chapter__c = chapterId,
                        Is_Active__c = true,
                        Source__c = 'Portal Update'
                    ));
                }
            }
            if(!toInsert.isEmpty()) insert toInsert;
            if(!toUpdate.isEmpty()) update toUpdate;
        }

        return contactChanged;
    }
    
    private static void handlePrivacyChanges(String contactId, Map<String, Boolean> changes) {
        Map<String, Id> portalToValueId = new Map<String, Id>();
        for(ucinn_ascendv2__Service_Indicator_Value__c val : [SELECT Id, HAM_Portal_ID__c FROM ucinn_ascendv2__Service_Indicator_Value__c WHERE HAM_Portal_ID__c IN :changes.keySet()]) { portalToValueId.put(val.HAM_Portal_ID__c, val.Id); }
        List<ucinn_ascendv2__Service_Indicator__c> existing = [SELECT Id, ucinn_ascendv2__Service_Indicator_Value__r.HAM_Portal_ID__c FROM ucinn_ascendv2__Service_Indicator__c WHERE ucinn_ascendv2__Contact__c = :contactId AND ucinn_ascendv2__Is_Active__c = TRUE];
        Map<String, ucinn_ascendv2__Service_Indicator__c> activeMap = new Map<String, ucinn_ascendv2__Service_Indicator__c>();
        for(ucinn_ascendv2__Service_Indicator__c si : existing) {activeMap.put(si.ucinn_ascendv2__Service_Indicator_Value__r.HAM_Portal_ID__c, si);}
        
        List<ucinn_ascendv2__Service_Indicator__c> upsertList = new List<ucinn_ascendv2__Service_Indicator__c>();
        for(String portalId : changes.keySet()) {
            Boolean makePublic = changes.get(portalId); 
            if(makePublic) {
                if(activeMap.containsKey(portalId)) { 
                    ucinn_ascendv2__Service_Indicator__c rec = activeMap.get(portalId); rec.ucinn_ascendv2__End_Date__c = Date.today(); upsertList.add(rec); 
                }
            } else { 
                if(!activeMap.containsKey(portalId) && portalToValueId.containsKey(portalId)) {
                    upsertList.add(new ucinn_ascendv2__Service_Indicator__c(ucinn_ascendv2__Contact__c = contactId, ucinn_ascendv2__Service_Indicator_Value__c = portalToValueId.get(portalId), ucinn_ascendv2__Start_Date__c = Date.today(), ucinn_ascendv2__Is_Active__c = true));
                } 
            }
        }
        if(!upsertList.isEmpty()) {upsert upsertList;}
    }

    private static void handlePhone(String contactId, String phoneValue, String typeValue) {
        if(String.isBlank(phoneValue)) return;
        String cleanPhone = phoneValue.replaceAll('[^0-9]', '');
        List<ucinn_ascendv2__Phone__c> allPhones = [SELECT Id, ucinn_ascendv2__Phone_Number__c, ucinn_ascendv2__Is_Preferred__c, ucinn_ascendv2__Type__c FROM ucinn_ascendv2__Phone__c WHERE ucinn_ascendv2__Contact__c = :contactId];
        ucinn_ascendv2__Phone__c existingMatch = null;

        for(ucinn_ascendv2__Phone__c p : allPhones) {
            if(p.ucinn_ascendv2__Phone_Number__c != null) {
                String dbClean = p.ucinn_ascendv2__Phone_Number__c.replaceAll('[^0-9]', '');
                if(dbClean == cleanPhone) { existingMatch = p; break; }
            }
        }

        if(existingMatch != null) {
            Boolean needsUpdate = false;
            if(!existingMatch.ucinn_ascendv2__Is_Preferred__c) { existingMatch.ucinn_ascendv2__Is_Preferred__c = true; needsUpdate = true; }
            if(String.isNotBlank(typeValue) && existingMatch.ucinn_ascendv2__Type__c != typeValue) { existingMatch.ucinn_ascendv2__Type__c = typeValue; needsUpdate = true; }
            if(needsUpdate) update existingMatch;
        } else {
            String newType = String.isNotBlank(typeValue) ? typeValue : 'Cell';
            insert new ucinn_ascendv2__Phone__c(ucinn_ascendv2__Contact__c = contactId, ucinn_ascendv2__Phone_Number__c = phoneValue, ucinn_ascendv2__Is_Preferred__c = true, ucinn_ascendv2__Status__c = 'Current', ucinn_ascendv2__Type__c = newType);
        }
    }

    private static void handlePhoneTypeOnly(String contactId, String newType) {
        List<ucinn_ascendv2__Phone__c> pref = [SELECT Id, ucinn_ascendv2__Type__c FROM ucinn_ascendv2__Phone__c WHERE ucinn_ascendv2__Contact__c = :contactId AND ucinn_ascendv2__Is_Preferred__c = true LIMIT 1];
        if(!pref.isEmpty() && pref[0].ucinn_ascendv2__Type__c != newType) { pref[0].ucinn_ascendv2__Type__c = newType; update pref[0]; }
    }

    private static void handleEmailTypeOnly(String contactId, String newType) {
        List<ucinn_ascendv2__Email__c> pref = [SELECT Id, ucinn_ascendv2__Type__c FROM ucinn_ascendv2__Email__c WHERE ucinn_ascendv2__Contact__c = :contactId AND ucinn_ascendv2__Is_Preferred__c = true LIMIT 1];
        if(!pref.isEmpty() && pref[0].ucinn_ascendv2__Type__c != newType) { pref[0].ucinn_ascendv2__Type__c = newType; update pref[0]; }
    }

    private static void handleEmail(String contactId, String value) {
        List<ucinn_ascendv2__Email__c> existing = [SELECT Id, ucinn_ascendv2__Is_Preferred__c FROM ucinn_ascendv2__Email__c WHERE ucinn_ascendv2__Contact__c = :contactId AND ucinn_ascendv2__Email_Address__c = :value LIMIT 1];
        if(!existing.isEmpty()) { 
            if(!existing[0].ucinn_ascendv2__Is_Preferred__c) { existing[0].ucinn_ascendv2__Is_Preferred__c = true; update existing[0]; }
        }
        else { insert new ucinn_ascendv2__Email__c(ucinn_ascendv2__Contact__c = contactId, ucinn_ascendv2__Email_Address__c = value, ucinn_ascendv2__Is_Preferred__c = true, ucinn_ascendv2__Status__c = 'Current', ucinn_ascendv2__Type__c = 'Personal'); }
    }

    private static void handleEmployerUpdate(String employerName, String contactId, List<Task> tasks) {
        if (String.isNotBlank(System.Label.HAM_TaskOwnerId) && System.Label.HAM_TaskOwnerId != 'null') {
            String contactName = '';
            List<Contact> conList = [SELECT Name FROM Contact WHERE Id = :contactId LIMIT 1];
            if (!conList.isEmpty()) { contactName = conList[0].Name; }
            tasks.add(new Task(
                Subject = (System.Label.HAM_EmployerChangeSubject + ' - ' + contactName).left(255),
                OwnerId = System.Label.HAM_TaskOwnerId,
                WhoId = contactId,
                Description = (System.Label.HAM_EmployerChangeDesc + ' ' + employerName + '\n\nConstituent: ' + contactName).left(32000),
                ActivityDate = Date.today().addDays(Integer.valueOf(System.label.HAM_TaskDueDuration))
            ));
        }
    }

    private static void handleAddressUpdate(String contactId, Map<String, Object> updates, List<Task> tasks) {
        List<ucinn_ascendv2__Address_Relation__c> allRels = [SELECT Id, ucinn_ascendv2__Is_Preferred__c, ucinn_ascendv2__Type__c, ucinn_ascendv2__Address__r.ucinn_ascendv2__Address_Line_1__c, ucinn_ascendv2__Address__r.ucinn_ascendv2__City__c, ucinn_ascendv2__Address__r.ucinn_ascendv2__State__c, ucinn_ascendv2__Address__r.ucinn_ascendv2__Country__c, ucinn_ascendv2__Address__r.ucinn_ascendv2__Postal_Code__c FROM ucinn_ascendv2__Address_Relation__c WHERE ucinn_ascendv2__Contact__c = :contactId];
        ucinn_ascendv2__Address_Relation__c currentPref = null;
        for(ucinn_ascendv2__Address_Relation__c rel : allRels) { if(rel.ucinn_ascendv2__Is_Preferred__c) { currentPref = rel; break; } }

        String newLine1 = (String)updates.get('ucinn_ascendv2__Address_Line_1__c'); String newCity = (String)updates.get('ucinn_ascendv2__City__c');
        String newState = (String)updates.get('ucinn_ascendv2__State__c'); String newCountry = (String)updates.get('ucinn_ascendv2__Country__c');
        String newPostal = (String)updates.get('ucinn_ascendv2__Postal_Code__c'); String newType = (String)updates.get('ucinn_ascendv2__Type__c');

        if(currentPref != null && currentPref.ucinn_ascendv2__Address__r != null) {
            if(newLine1 == null) newLine1 = currentPref.ucinn_ascendv2__Address__r.ucinn_ascendv2__Address_Line_1__c; if(newCity == null) newCity = currentPref.ucinn_ascendv2__Address__r.ucinn_ascendv2__City__c;
            if(newState == null) newState = currentPref.ucinn_ascendv2__Address__r.ucinn_ascendv2__State__c; if(newCountry == null) newCountry = currentPref.ucinn_ascendv2__Address__r.ucinn_ascendv2__Country__c;
            if(newPostal == null) newPostal = currentPref.ucinn_ascendv2__Address__r.ucinn_ascendv2__Postal_Code__c;
            
            if(normalizeStr(newLine1) == normalizeStr(currentPref.ucinn_ascendv2__Address__r.ucinn_ascendv2__Address_Line_1__c) && normalizeStr(newCity) == normalizeStr(currentPref.ucinn_ascendv2__Address__r.ucinn_ascendv2__City__c) && normalizeStr(newState) == normalizeStr(currentPref.ucinn_ascendv2__Address__r.ucinn_ascendv2__State__c) && normalizeStr(newCountry) == normalizeStr(currentPref.ucinn_ascendv2__Address__r.ucinn_ascendv2__Country__c) && normalizeStr(newPostal) == normalizeStr(currentPref.ucinn_ascendv2__Address__r.ucinn_ascendv2__Postal_Code__c)) {
                if(String.isNotBlank(newType) && newType != currentPref.ucinn_ascendv2__Type__c) { currentPref.ucinn_ascendv2__Type__c = newType; update currentPref; }
                return;
            }
        }

        List<ucinn_ascendv2__Address_Relation__c> toUpdate = new List<ucinn_ascendv2__Address_Relation__c>(); Boolean matchFound = false;
        for(ucinn_ascendv2__Address_Relation__c rel : allRels) {
            if(rel.ucinn_ascendv2__Address__r != null && normalizeStr(newLine1) == normalizeStr(rel.ucinn_ascendv2__Address__r.ucinn_ascendv2__Address_Line_1__c) && normalizeStr(newCity) == normalizeStr(rel.ucinn_ascendv2__Address__r.ucinn_ascendv2__City__c) && normalizeStr(newState) == normalizeStr(rel.ucinn_ascendv2__Address__r.ucinn_ascendv2__State__c) && normalizeStr(newCountry) == normalizeStr(rel.ucinn_ascendv2__Address__r.ucinn_ascendv2__Country__c) && normalizeStr(newPostal) == normalizeStr(rel.ucinn_ascendv2__Address__r.ucinn_ascendv2__Postal_Code__c)) {
                if(!rel.ucinn_ascendv2__Is_Preferred__c) {
                    rel.ucinn_ascendv2__Is_Preferred__c = true; toUpdate.add(rel);
                    if(currentPref != null && currentPref.Id != rel.Id) { currentPref.ucinn_ascendv2__Is_Preferred__c = false; toUpdate.add(currentPref); }
                }
                matchFound = true; break; 
            }
        }

        if(matchFound) { if(!toUpdate.isEmpty()){ update toUpdate;} return; }
        if(String.isBlank(newLine1) && currentPref == null){ return;}

        ucinn_ascendv2__Address__c newAddr = new ucinn_ascendv2__Address__c(ucinn_ascendv2__Address_Line_1__c = newLine1, ucinn_ascendv2__City__c = newCity, ucinn_ascendv2__State__c = newState, ucinn_ascendv2__Country__c = newCountry, ucinn_ascendv2__Postal_Code__c = newPostal); insert newAddr;
        insert new ucinn_ascendv2__Address_Relation__c(ucinn_ascendv2__Contact__c = contactId, ucinn_ascendv2__Address__c = newAddr.Id, ucinn_ascendv2__Status__c = 'Current', ucinn_ascendv2__Is_Preferred__c = true, ucinn_ascendv2__Type__c = newType);

        if(currentPref != null) { currentPref.ucinn_ascendv2__Is_Preferred__c = false; update currentPref; }
        if(String.isNotBlank(System.Label.HAM_TaskOwnerId) && System.Label.HAM_TaskOwnerId != 'null') {
            String contactName = '';
            List<Contact> conList = [SELECT Name FROM Contact WHERE Id = :contactId LIMIT 1];
            if (!conList.isEmpty()) { contactName = conList[0].Name; }
            tasks.add(new Task(
                Subject = (System.Label.HAM_AddressChangeSubject + ' - ' + contactName).left(255),
                OwnerId = System.Label.HAM_TaskOwnerId,
                WhoId = contactId,
                Description = (System.Label.HAM_AddressChangeDesc + '\n\nConstituent: ' + contactName).left(32000),
                ActivityDate = Date.today().addDays(Integer.valueOf(System.Label.HAM_TaskDueDuration))
            ));
        }
    }

    private static void handleSocialMediaUpdate(String contactId, Map<String, String> updates, List<Task> tasks) {
        List<ucinn_ascendv2__Social_Media__c> existing = [SELECT Id, ucinn_ascendv2__Platform__c, ucinn_ascendv2__URL__c, ucinn_ascendv2__Social_Handle__c FROM ucinn_ascendv2__Social_Media__c WHERE ucinn_ascendv2__Contact__c = :contactId AND ucinn_ascendv2__Platform__c IN :updates.keySet() ORDER BY LastModifiedDate DESC];
        Map<String, ucinn_ascendv2__Social_Media__c> existingMap = new Map<String, ucinn_ascendv2__Social_Media__c>();
        for(ucinn_ascendv2__Social_Media__c sm : existing) { if(!existingMap.containsKey(sm.ucinn_ascendv2__Platform__c)) {existingMap.put(sm.ucinn_ascendv2__Platform__c, sm);} }
        
        List<ucinn_ascendv2__Social_Media__c> toUpsert = new List<ucinn_ascendv2__Social_Media__c>();
        String linkedInUrl = null;
        for(String platform : updates.keySet()) {
            String userHandle = updates.get(platform); String url='';
            if(platform == 'Facebook'){url = userHandle.endsWith('/') ? 'https://www.facebook.com/'+userHandle : 'https://www.facebook.com/'+userHandle+'/';}
            if(platform == 'Instagram'){url = userHandle.endsWith('/') ? 'https://www.instagram.com/'+userHandle : 'https://www.instagram.com/'+userHandle+'/';}
            if(platform == 'Twitter'){url = userHandle.endsWith('/') ? 'https://x.com/'+userHandle : 'https://x.com/'+userHandle+'/';}
            if(platform == 'LinkedIn'){url = userHandle.endsWith('/') ? 'https://www.linkedin.com/in/'+userHandle : 'https://www.linkedin.com/in/'+userHandle+'/'; linkedInUrl = url;}
            if(String.isBlank(userHandle)) {continue; }

            if(existingMap.containsKey(platform)) {
                ucinn_ascendv2__Social_Media__c rec = existingMap.get(platform);
                if(rec.ucinn_ascendv2__URL__c != url || rec.ucinn_ascendv2__Social_Handle__c != userHandle) {
                    rec.ucinn_ascendv2__URL__c = url; rec.ucinn_ascendv2__Social_Handle__c = userHandle; toUpsert.add(rec);
                }
            }
            else { toUpsert.add(new ucinn_ascendv2__Social_Media__c(ucinn_ascendv2__Contact__c = contactId, ucinn_ascendv2__Platform__c = platform, ucinn_ascendv2__URL__c = url, ucinn_ascendv2__Social_Handle__c = userHandle )); }
        }
        if(!toUpsert.isEmpty()) { 
            upsert toUpsert; 
            createSocialMediaUpdateTask(contactId, tasks);
        }
        if(String.isNotBlank(linkedInUrl)) { update new Contact(Id = contactId, HAM_LiveAlumni_LinkedIn_URL__c = linkedInUrl); }
    }

    private static void createSocialMediaUpdateTask(String contactId, List<Task> tasks) {
        Id ameyaId = null;
        List<User> ameyaUsers = [SELECT Id FROM User WHERE Name = :System.Label.ham_TaskOwnerName LIMIT 1];
        if (!ameyaUsers.isEmpty()) {
            ameyaId = ameyaUsers[0].Id;
        } else {
            if (String.isNotBlank(System.Label.HAM_TaskOwnerId) && System.Label.HAM_TaskOwnerId != 'null') {
                ameyaId = (Id)System.Label.HAM_TaskOwnerId;
            }
        }
        
        if (ameyaId != null) {
            String contactName = '';
            List<Contact> conList = [SELECT Name FROM Contact WHERE Id = :contactId LIMIT 1];
            if (!conList.isEmpty()) { contactName = conList[0].Name; }
            tasks.add(new Task(
                Subject = (System.Label.HAM_SocialMediaChangeSubject + ' - ' + contactName).left(255),
                OwnerId = ameyaId,
                WhoId = contactId,
                Description = (System.Label.HAM_SocialMediaChangeDesc + '\n\nConstituent: ' + contactName).left(32000),
                ActivityDate = Date.today().addDays(Integer.valueOf(System.Label.HAM_TaskDueDuration))
            ));
        }
    }

    private static void handleProfilePicLink(String contactId, String contentDocId, List<Task> tasks) {
        try{ ContentDocumentLink cdl = new ContentDocumentLink(); cdl.ContentDocumentId = contentDocId; cdl.LinkedEntityId = contactId; cdl.ShareType = 'V'; cdl.Visibility = 'AllUsers'; insert cdl; } catch (Exception e) {}
        if (String.isNotBlank(System.Label.HAM_TaskOwnerId) && System.Label.HAM_TaskOwnerId != 'null'){
            String contactName = ''; String fileName = '';
            List<Contact> conList = [SELECT Name FROM Contact WHERE Id = :contactId LIMIT 1]; if (!conList.isEmpty()) {contactName = conList[0].Name;}
            List<ContentDocument> cdList = [SELECT Title FROM ContentDocument WHERE Id = :contentDocId LIMIT 1]; if (!cdList.isEmpty()) {fileName = cdList[0].Title;}
            tasks.add(new Task(Subject = (System.Label.HAM_ProfilePicChangeSubject + ' - ' + contactName).left(255), OwnerId = System.Label.HAM_TaskOwnerId, WhoId = contactId, Description = (System.Label.HAM_ProfilePicChangeDesc + '\n\nUploaded File Name: ' + fileName).left(32000), ActivityDate = Date.today().addDays(Integer.valueOf(System.Label.HAM_TaskDueDuration))));
        }
    }

   private static String generatePublicLinkForDoc(String contentDocId) {
        if (String.isBlank(contentDocId)) return '';
        try {
            ContentVersion cv = [SELECT Id, Title FROM ContentVersion WHERE ContentDocumentId = :contentDocId AND IsLatest = true LIMIT 1];
            ContentDistribution dist = new ContentDistribution(Name = cv.Title != null ? cv.Title : 'Public Link', ContentVersionId = cv.Id, PreferencesAllowViewInBrowser = true, PreferencesAllowOriginalDownload = true, PreferencesLinkLatestVersion = true, PreferencesNotifyOnVisit = false);
            insert dist;
            return [SELECT ContentDownloadUrl FROM ContentDistribution WHERE ID = :dist.Id LIMIT 1].ContentDownloadUrl;
        } catch (Exception ex) { return ''; }
    }

    @SuppressWarnings('PMD.IfStmtsMustUseBraces, PMD.IfElseStmtsMustUseBraces')
    private static Map<String, String> getSocialMediaMap(String contactId, Set<String> platforms) {
        Map<String, String> smMap = new Map<String, String>();
        if(platforms.isEmpty()) return smMap;
        for(ucinn_ascendv2__Social_Media__c sm : [SELECT ucinn_ascendv2__Platform__c, ucinn_ascendv2__Social_Handle__c FROM ucinn_ascendv2__Social_Media__c WHERE ucinn_ascendv2__Contact__c = :contactId AND ucinn_ascendv2__Platform__c IN :platforms ORDER BY LastModifiedDate DESC]) { if(!smMap.containsKey(sm.ucinn_ascendv2__Platform__c)){smMap.put(sm.ucinn_ascendv2__Platform__c, sm.ucinn_ascendv2__Social_Handle__c);} }
        return smMap;
    }

    @SuppressWarnings('PMD.IfStmtsMustUseBraces, PMD.IfElseStmtsMustUseBraces')
    private static List<Map<String, String>> getPicklistOptions(String objName, String fieldName) {
        List<Map<String, String>> options = new List<Map<String, String>>();
        try {
            Schema.DescribeSobjectResult[] results = Schema.describeSObjects(new String[]{objName});
            if(results.size() > 0) {
                Schema.DescribeFieldResult fieldResult = results[0].fields.getMap().get(fieldName).getDescribe();
                for(Schema.PicklistEntry pe : fieldResult.getPicklistValues()) { 
                    if(pe.isActive()) {
                        options.add(new Map<String, String>{'label' => pe.getLabel(), 'value' => pe.getValue()}); 
                    }
                }
            }
        } catch(Exception e) { 
            System.debug(LoggingLevel.ERROR, 'Picklist fetch error: ' + e.getMessage()); 
        }
        return options;
    }

    private static void createAscendBypassMethod(Id userId) { ucinn_ascendv2__Bypass_Settings__c ascBypass = new ucinn_ascendv2__Bypass_Settings__c(); ascBypass.SetupOwnerId = userId; ascBypass.ucinn_ascendv2__Bypass_Process_Builders__c = true; ascBypass.ucinn_ascendv2__Bypass_Triggers__c = true; ascBypass.ucinn_ascendv2__Bypass_Validation_Rules__c = true; ascBypass.ucinn_ascendv2__Bypass_Workflows__c = true; insert ascBypass; }
    private static void removeAscendBypassMethod(Id userId) { List<ucinn_ascendv2__Bypass_Settings__c> ascBypassList = [Select Id from ucinn_ascendv2__Bypass_Settings__c Where SetupOwnerId = :userId]; if(!ascBypassList.isEmpty()){ delete ascBypassList; }}
    private static String normalizeStr(String s) { return s == null ? '' : s; }
}