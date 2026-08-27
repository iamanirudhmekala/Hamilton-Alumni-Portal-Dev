/**
* @File Name : HAM_MyImpactController.cls
* @Description : This class is used to fetch contact details and philanthropy details on my impact page.
* @Author : Cube84 - Sachin
* @Last Modified By : Nimish Vaidya
* @Last Modified On : Aug 05, 2026
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | July 9, 2025 |  Sachin | Initial Version
* 1.1 | Sept 04, 2025 |  Sachin |  Done as part of Optimization
* 1.2 | Oct 09,2025 | Immanuel | Added logic to accomodate 2nd,3rd degree concentartions
* 1.3 | Dec 03,2025 | Asheesh | Added logic to handle new homepage component.
* 1.4 | June 19, 2026 | Sachin Kumar Sharma | Added visibility feature toggle for Receipts table.
* 1.5 | Aug 05, 2026 | Nimish Vaidya | Added HAM_Table_Footnote__c and grant-form button fields to PhilanthropyDataTable for the HDAF table.
**/
@SuppressWarnings('PMD.NoTrailingWhitespace, PMD.IfElseStmtsMustUseBraces, PMD.IfStmtsMustUseBraces,PMD.ExcessivePublicCount, PMD.OperationWithLimitsInLoop, PMD.DebugsShouldUseLoggingLevel, PMD.ApexDoc, PMD.FieldNamingConventions, PMD.ExcessiveClassLength, PMD.ApexCRUDViolation, PMD.EmptyIfStmt, PMD.EmptyStatementBlock, PMD.AvoidNonRestrictiveQueries, PMD.CyclomaticComplexity, PMD.CognitiveComplexity, PMD.NcssCount, PMD.NcssTypeCount, PMD.DetectCopyPasteForApex, PMD.LocalVariableNamingConventions, PMD.ExcessiveParameterList, PMD.ApexSOQLInjection, PMD.AvoidDeeplyNestedIfStmts, PMD.AvoidDebugStatements, PMD.StdCyclomaticComplexity, PMD.NcssMethodCount')
public without sharing class HAM_MyImpactController {

    @TestVisible
    private static Boolean mockReceiptsTableStatus = null;

    /**
     * @description Fetches the feature toggle status for Receipts Table visibility.
     * @return Boolean - True if active/visible, False if inactive/hidden.
     */
    public static Boolean getReceiptsTableStatus() {
        if (Test.isRunningTest() && mockReceiptsTableStatus != null) {
            return mockReceiptsTableStatus;
        }
        try {
            // Querying with SYSTEM_MODE to ensure external portal/community users can read the toggle configuration
            // Added by Sachin Kumar Sharma on June 19, 2026
            Ham_GivingApp_Feature_Toggle__mdt toggle = [
                SELECT Is_Active__c 
                FROM Ham_GivingApp_Feature_Toggle__mdt 
                WHERE DeveloperName = 'Receipts_Table'
                WITH SYSTEM_MODE
                LIMIT 1
            ];
            return toggle.Is_Active__c;
        } catch (Exception e) {
            return true;
        }
    }

	// Main Wrapper Class to hold all data
    public class MyImpactDataWrapper {
        @AuraEnabled public ContactInfo contact;
		@AuraEnabled public List<DegreeInfo> degree;
		@AuraEnabled public OtherInfo otherInfo;
		@AuraEnabled public List<MyProfileBioData> bioData;
		@AuraEnabled public List<MyProfileMyConnect> myConnect;
        @AuraEnabled public CampusContact campusContact;
        @AuraEnabled public List<HCBadge> hcBadges; 
        @AuraEnabled public List<PhilanthropyField> philanthropyField;
        @AuraEnabled public String error; // To pass error messages if any
    }

    // Wrapper to hold other info
    public class OtherInfo {
        @AuraEnabled public Boolean isGift;
        @AuraEnabled public String facebook;
        @AuraEnabled public Decimal totalYearsOfGiving;
        @AuraEnabled public Boolean isVolunteer;
    }
	
	// Wrapper for Contact Information
    public class ContactInfo {
		@AuraEnabled public String userPic;
        @AuraEnabled public Id Id;
        @AuraEnabled public String name;
        @AuraEnabled public String linkedIn;
        @AuraEnabled public Boolean isKirklandAlumnae;
    }

	// Wrapper class for Degree Information
	public class DegreeInfo {
		@AuraEnabled public List<String> majors;
		@AuraEnabled public List<String> minors;
	}

    //Wrapper class for Campus Contact
    public class CampusContact {
        @AuraEnabled public String phone;
        @AuraEnabled public String email;
        @AuraEnabled public String name;
    }

	// Wrapper classes to represent the Constituent fields in My Profile section from metadata
    public class MyProfileBioData {
        @AuraEnabled public String displayLabel;
        @AuraEnabled public Decimal displayOrder;
        @AuraEnabled public String displayValue;
    }

	public class MyProfileMyConnect {
        @AuraEnabled public String displayLabel;
        @AuraEnabled public Decimal displayOrder;
        @AuraEnabled public String displayValue;
	}

    // New Wrapper for Dynamic HC Badges
    public class HCBadge {
        @AuraEnabled public String label;
        @AuraEnabled public String imageUrl;
        @AuraEnabled public Decimal order;
    }

    // New Wrapper for Fields within a Philanthropy Section
    public class PhilanthropyField {
        @AuraEnabled public String label; 
        @AuraEnabled public String value; 
        @AuraEnabled public String type; 
        @AuraEnabled public Decimal order; 
        @AuraEnabled public String sectionLabel;        
        @AuraEnabled public Decimal sectionOrder;
    }

    // HAM_Metadata wrapper
    public class MyImpactMetadata {
		@AuraEnabled public String fieldApiName;
        @AuraEnabled public String displayLabel;
        @AuraEnabled public Decimal displayOrder;
        @AuraEnabled public String level2;
        @AuraEnabled public String level1;
        @AuraEnabled public Decimal sectionOrder;
        @AuraEnabled public String type;
        @AuraEnabled public Id Id;
	}

    // Badge Metadata wrapper
    public class BadgeMetadata {
        @AuraEnabled public String imagePath;
        @AuraEnabled public String displayName;
        @AuraEnabled public Decimal displayOrder;
        @AuraEnabled public String mappingFieldApi;
    }

    // Parent Wrapper to store data for accordions in MyImpact page (My Services, My Affinities and Teams)
    public class MyServiceAffinities {
        @AuraEnabled public List<MyService> myServices; 
        @AuraEnabled public List<MyAffinity> myAffinities;  
    }

    // Wrapper for My Services
    public class MyService {
        @AuraEnabled public String displaylabel; 
        @AuraEnabled public String displayType;
        @AuraEnabled public Decimal order; 
        @AuraEnabled public String displayValueText; 
        @AuraEnabled public List<String> displayValueList;
    }

    // Wrapper for My Affinity
    public class MyAffinity {
        @AuraEnabled public String displaylabel; 
        @AuraEnabled public String displayType;
        @AuraEnabled public Decimal order; 
        @AuraEnabled public String displayValueText; 
        @AuraEnabled public List<String> displayValueList;
    }

    // Parent wrapper for philanthropy details
    public class PhilanthropyDetail {
        @AuraEnabled public List<PhilanthropyField> philanthropyField;
        @AuraEnabled public List<PhilanthropyDataTable> philanthropyDataTables;
        @AuraEnabled public Boolean showReceiptsTable;
        @AuraEnabled public String error;
    }

    public class PhilanthropyDataTable {
        @AuraEnabled public String tableName;
        @AuraEnabled public List<SObject> records;
        @AuraEnabled public List<String> columnLabels;
        @AuraEnabled public List<String> columnApiNames;
        @AuraEnabled public List<String> fieldTypes;
        @AuraEnabled public Decimal displayLimit;
        @AuraEnabled public Boolean displayLoadMore;
        @AuraEnabled public Decimal order;
        @AuraEnabled public String footnote;
        @AuraEnabled public String button1Label;
        @AuraEnabled public String button1Url;
        @AuraEnabled public String button2Label;
        @AuraEnabled public String button2Url;
    }

    // Wrapper to hold data of the interest values in affinities
    public class InterestWrapper {
        @AuraEnabled public String foundationInterestId;
        @AuraEnabled public String foundationInterestName;
        @AuraEnabled public Boolean isChecked;
        @AuraEnabled public String existingChildId; // ID of the Funding_Interest__c if it exists

        public InterestWrapper(ucinn_ascendv2__Foundation_Funding_Interests__c parent, ucinn_ascendv2__Funding_Interest__c child) {
            this.foundationInterestId = parent.Id;
            this.foundationInterestName = parent.Name;
            this.isChecked = (child != null);
            this.existingChildId = (child != null) ? child.Id : null;
        }
    }

      // Wrapper to hold data of the interest values in affinities
    public class InvolementWrapper {
        @AuraEnabled public String foundationInterestId;
        @AuraEnabled public String foundationInterestName;
        @AuraEnabled public Boolean isChecked;
        @AuraEnabled public String existingChildId; // ID of the Funding_Interest__c if it exists

        public InvolementWrapper(ucinn_ascendv2__Involvement_Value__c parent, ucinn_ascendv2__Involvement__c child) {
            this.foundationInterestId = parent.Id;
            this.foundationInterestName = parent.ucinn_ascendv2__Involvement_Description__c;
            this.isChecked = (child != null);
            this.existingChildId = (child != null) ? child.Id : null;
        }
    }

    /**
    * @description: Method to fetch philanthropy details field configuration from HAM_Object_Fetcher__mdt.
    * @param:       additionalWhereClause - dynamic where clause for the metadata to fetch only required records for this section.
    * @return:      List<HAM_Object_Fetcher__mdt> - A list of HAM_Object_Fetcher__mdt metadata records
    **/
    public static List<HAM_Object_Fetcher__mdt> getPhilanthrophyDetailMetadata(String additionalWhereClause) {
		List<HAM_Object_Fetcher__mdt> objectFetchers = new List<HAM_Object_Fetcher__mdt>();
        String query = 'SELECT Id, DeveloperName, HAM_Level_1__c, HAM_Level_2__c, HAM_Related_Object__c, HAM_Display_Type__c, HAM_Default_Display_Value__c, HAM_Display_Label__c,'+
                        'HAM_Display_Field__c, HAM_Reference_Field__c, HAM_Additional_Filter__c, HAM_Order__c, HAM_Table_Default_Sort_Order__c,HAM_Table_Field_APIs__c,'+
                        'HAM_Table_Field_Labels__c, HAM_Table_Limit__c, HAM_Table_Field_Types__c, HAM_Table_Load_More__c, '+
                        'HAM_Table_Footnote__c, HAM_Button_1_Label__c, HAM_Button_1_URL__c, HAM_Button_2_Label__c, HAM_Button_2_URL__c '+
                        'FROM HAM_Object_Fetcher__mdt';

        // Append the additional WHERE clause if provided
        if (String.isNotBlank(additionalWhereClause)) {
            query += ' WHERE ' + additionalWhereClause;
        }
        // add the ORDER BY clause
        query += ' ORDER By HAM_Level_1__c ASC, HAM_Level_2__c ASC, HAM_Order__c ASC';
        try{
            objectFetchers = (List<HAM_Object_Fetcher__mdt>)Database.query(query);
        }catch (QueryException qe) {
            System.debug('Query Error in getPhilanthrophyDetailMetadata: ' + qe.getMessage());
        }
        return objectFetchers;
    }

    /**
    * @description: Method to fetch My Impact(Profile section & My Philanthropy highlights section) field Configuration from Custom Metadata  
    * @param:       additionalWhereClause - dynamic where clause for the metadata to fetch only required records for this section.
    * @return:      List<MyImpactMetadata> - A list of MyImpactMetadata wrapper which objects.
    **/
    public static List<MyImpactMetadata> getMyImpactMetadata(String additionalWhereClause) {
        List<MyImpactMetadata> myImpactMetadaList = new List<MyImpactMetadata>();
        // base SOQL query
        String query = 'SELECT Id, HAM_Display_Label__c, HAM_Field_API__c, HAM_Field_Type__c, ' +
                       'HAM_Level_1__c, HAM_Level_2__c, HAM_Order__c, HAM_Section_Order__c ' +
                       'FROM HAM_Meta_Data__mdt';
        
        // Append the additional WHERE clause if provided
        if (String.isNotBlank(additionalWhereClause)) {
            query += ' WHERE ' + additionalWhereClause;
        }

        // Always add the ORDER BY clause
        query += 'WITH SECURITY_ENFORCED ORDER By HAM_Level_2__c, HAM_Order__c ASC';
        try{
            for (SObject sObjFieldConfig : Database.query(query)) {
                HAM_Meta_Data__mdt fieldConfig = (HAM_Meta_Data__mdt) sObjFieldConfig;

                // Only add if HAM_Field_API__c is not blank
                if (String.isNotBlank(fieldConfig.HAM_Field_API__c)) {
                    MyImpactMetadata metadata = new MyImpactMetadata();
                    metadata.fieldApiName = fieldConfig.HAM_Field_API__c != null ? fieldConfig.HAM_Field_API__c : ' ';
                    metadata.displayLabel = fieldConfig.HAM_Display_Label__c != null ? fieldConfig.HAM_Display_Label__c : '';
                    metadata.displayOrder = fieldConfig.HAM_Order__c != null ? fieldConfig.HAM_Order__c : 0;
                    metadata.sectionOrder = fieldConfig.HAM_Section_Order__c != null ? fieldConfig.HAM_Section_Order__c : 0;
                    metadata.level2 = fieldConfig.HAM_Level_2__c != null ? fieldConfig.HAM_Level_2__c : '';
                    metadata.level1 = fieldConfig.HAM_Level_1__c != null ? fieldConfig.HAM_Level_1__c : '';
                    metadata.type = (fieldConfig.HAM_Field_Type__c != null) ? fieldConfig.HAM_Field_Type__c : '';
                    metadata.Id = fieldConfig.Id;
                    myImpactMetadaList.add(metadata);
                }
            }
        } catch (QueryException qe) {
            System.debug('Query Error in getMyImpactMetadata: ' + qe.getMessage());
        }
        
        return myImpactMetadaList;
    }

    /**
    * @description: Method to fetch Badge field configuration from custom metadata
    * @return:      List<BadgeMetadata> - A list of BadgeMetadata wrapper which objects.
    **/
    public static List<BadgeMetadata> getBadgeMetadata() {
        List<BadgeMetadata> badgeMetadataList = new List<BadgeMetadata>();
		BadgeMetadata metadata;
        try{
            for (HAM_Badge__mdt fieldConfig : [SELECT HAM_Display_Name__c, HAM_Image_Path__c, HAM_Mapping_Field_API__c, HAM_Order__c FROM HAM_Badge__mdt WITH SECURITY_ENFORCED ORDER BY HAM_Order__c]) {            
                    metadata = new BadgeMetadata();
                    metadata.imagePath = fieldConfig.HAM_Image_Path__c != null ? fieldConfig.HAM_Image_Path__c : '';
                    metadata.displayName = fieldConfig.HAM_Display_Name__c != null ? fieldConfig.HAM_Display_Name__c : '';
                    metadata.displayOrder = fieldConfig.HAM_Order__c != null ? fieldConfig.HAM_Order__c : 0;
                    metadata.mappingFieldApi = fieldConfig.HAM_Mapping_Field_API__c != null ? fieldConfig.HAM_Mapping_Field_API__c : ''; 
                    badgeMetadataList.add(metadata);
            }
        }catch (QueryException qe) {
            System.debug('Query Error in getBadgeMetadata: ' + qe.getMessage());
        }
        
        return badgeMetadataList;
    }

    /**
    * @description : method to fetch records dynamically based on HAM_Object_Fetcher__mdt to populate philanthropycdetails in accordion.
    * @param : currentUserContactId - contactId of logged in portal user.
    * @return : PhilanthropyDetail - wrapper object.
    */
    @AuraEnabled(cacheable=true)
    public static PhilanthropyDetail getPhilanthropyDetails(String currentUserContactId) {
        
        PhilanthropyDetail philanthropyDetail = new PhilanthropyDetail();
        philanthropyDetail.philanthropyField = new List<PhilanthropyField>();
        philanthropyDetail.philanthropyDataTables = new List<PhilanthropyDataTable>();
        
        Boolean showReceipts = getReceiptsTableStatus();
        philanthropyDetail.showReceiptsTable = showReceipts;
        
        String whereClause = 'HAM_Level_1__c IN (\'My Philanthropy Detail\')';

        // Fetch Philanthropy detail fields which is preconfigured in HAM_Meta_data__mdt
        List<MyImpactMetadata> philanthropyDetailFieldsToQuery = getMyImpactMetadata(whereClause);

        // Fetch HAM_Object_Fetcher__mdt fields which is preconfigured
        List<HAM_Object_Fetcher__mdt> philanthropyDetailTablesToQuery = getPhilanthrophyDetailMetadata(whereClause);

        Set<String> fieldApiNames = new Set<String>();

        // Fetching details of philanthropy field for the accordion section
        for(MyImpactMetadata field : philanthropyDetailFieldsToQuery) {
            fieldApiNames.add(field.fieldApiName);            
        }

        // Fetching actual data from salesforce for philanthropy accordion based on the configurations in metadata
        String queryFields = String.join(new List<String>(fieldApiNames), ', ');

        String queryString = 'SELECT Id,'+ queryFields + ' FROM Contact WHERE Id = \'' + String.escapeSingleQuotes(currentUserContactId) + '\' LIMIT 1';
        
		Contact constituentSObject = null;
		try {
            List<Contact> results = (List<Contact>)Database.query(queryString);
            if (!results.isEmpty()) {
                constituentSObject = results[0];
            }
        } catch (System.QueryException e) {
             
             philanthropyDetail.error = 'Failed to retrieve constituent details. ' + e.getMessage();
             return philanthropyDetail;
        }
        if (constituentSObject != null) {
        for(MyImpactMetadata field: philanthropyDetailFieldsToQuery){
                if(field.level1 == HAM_ConstantsUtil.MY_PHILANTHROPY_DETAIL){
                    PhilanthropyField myPhilanthropy = new PhilanthropyField();
                    myPhilanthropy.label = field.displayLabel;
                    myPhilanthropy.order = field.displayOrder;
                    myPhilanthropy.sectionOrder = field.sectionOrder;
                    myPhilanthropy.value = (field.fieldApiName != null)? String.valueOf(constituentSObject.get(field.fieldApiName)) : ' '; 
                    myPhilanthropy.type = field.type;
                    myPhilanthropy.sectionLabel = field.level2;
                    philanthropyDetail.philanthropyField.add(myPhilanthropy);
                }
            }
        }
        // fetching philanthropy data table actual values 
        try {
            String recordLimit = System.Label.ham_PhilanthropyTableFetchLimit;
            for(HAM_Object_Fetcher__mdt field: philanthropyDetailTablesToQuery){
                if (!showReceipts && field.HAM_Level_2__c == 'Receipts') {
                    continue;
                }
                
                String query = 'SELECT ' + field.HAM_Table_Field_APIs__c + 
                            ' FROM ' + field.HAM_Related_Object__c + 
                            ' WHERE ' + field.HAM_Reference_Field__c + ' = \'' + String.escapeSingleQuotes(currentUserContactId) + '\'' ;

                if (String.isNotBlank(field.HAM_Additional_Filter__c)) {
                    query += ' AND ' + field.HAM_Additional_Filter__c;
                }

                query += ' ' + field.HAM_Table_Default_Sort_Order__c;            
                
                if(field.HAM_Table_Load_More__c) {
                    query += ' LIMIT ' + recordLimit;
                }
                else {
                    query += ' LIMIT ' + String.valueOf((Integer) field.HAM_Table_Limit__c);
                }
				 
                List<Sobject> tableData = Database.query(query);
                
                PhilanthropyDataTable dataTable = new PhilanthropyDataTable();
                dataTable.tableName = field.HAM_Display_Label__c; 
                dataTable.columnApiNames = field.HAM_Table_Field_APIs__c.split(','); // Store API names for columns
                dataTable.columnLabels = field.HAM_Table_Field_Labels__c.split(','); // Store Labels for columns
                dataTable.records = tableData;
                dataTable.fieldTypes = field.HAM_Table_Field_Types__c.split(',');
                dataTable.displayLimit = (Decimal) field.HAM_Table_Limit__c;
                dataTable.displayLoadMore = field.HAM_Table_Load_More__c;
                dataTable.order = (Decimal)field.HAM_Order__c;
                dataTable.footnote = field.HAM_Table_Footnote__c;
                dataTable.button1Label = field.HAM_Button_1_Label__c;
                dataTable.button1Url = field.HAM_Button_1_URL__c;
                dataTable.button2Label = field.HAM_Button_2_Label__c;
                dataTable.button2Url = field.HAM_Button_2_URL__c;
                philanthropyDetail.philanthropyDataTables.add(dataTable);
                                            
            }
        } catch (System.QueryException e) {
             System.debug('QueryException when fetching Contact: ' + e.getMessage());
             philanthropyDetail.error = 'Failed to retrieve constituent details. ' + e.getMessage();
             return philanthropyDetail;
        }
        
        return philanthropyDetail;
    }

    /**
    * @description : method to fetch records dynamically based on HAM_Object_Fetcher__mdt.
    * @param : currentUserContactId - contactId of logged in portal user.
    * @Returns : MyServiceAffinities - wrapper  object.
    **/
    @AuraEnabled(cacheable=true)
    public static MyServiceAffinities getMyServiceAffinitiesData(String currentUserContactId) {

        MyServiceAffinities myServiceAffinities = new MyServiceAffinities();
        myServiceAffinities.myAffinities = new List<MyAffinity>();
        myServiceAffinities.myServices = new List<MyService>();

        Contact con = [
            SELECT Id, ucinn_ascendv2__Primary_Contact_Type__c
            FROM Contact
            WHERE Id = :currentUserContactId
            LIMIT 1
        ];

        String involvementRecordType = (con.ucinn_ascendv2__Primary_Contact_Type__c == 'Student')
                                    ? 'Student_Involvement'
                                    : 'Alumni_Involvement';

        //  Fetch all HAM_Object_Fetcher__mdt records
        String whereClause = 'HAM_Level_1__c IN (\'My Service\',\'My Affinities\')' ;
        List<HAM_Object_Fetcher__mdt> objectFetchers = getPhilanthrophyDetailMetadata(whereClause);

        // Process each metadata record
        for (HAM_Object_Fetcher__mdt fetcher : objectFetchers) {
            if ((String.isBlank(fetcher.HAM_Level_2__c) || String.isBlank(fetcher.HAM_Related_Object__c)) && fetcher.HAM_Display_Type__c != HAM_ConstantsUtil.HARDCODED_STRING) {
                System.debug('Skipping metadata record ' + fetcher.DeveloperName + ' due to missing HAM_Level_2__c or HAM_Related_Object__c.');
                continue;
            }

            List<String> formattedRecords = new List<String>();
            if(fetcher.HAM_Display_Type__c != HAM_ConstantsUtil.HARDCODED_STRING) { 
                String objectApiName = fetcher.HAM_Related_Object__c;
                String displayField = fetcher.HAM_Display_Field__c != null ? fetcher.HAM_Display_Field__c : '';
                String referenceField = fetcher.HAM_Reference_Field__c;
                String filter = fetcher.HAM_Additional_Filter__c != null ? fetcher.HAM_Additional_Filter__c : '';

                // Construct the dynamic SOQL query
                Set<String> fieldsToSelect = new Set<String>{'Id'};
                if (String.isNotBlank(displayField)) {
                    fieldsToSelect.add(displayField);
                }

                String selectClause = String.join(new List<String>(fieldsToSelect), ',');
                String query = 'SELECT ' + selectClause + ' FROM ' + objectApiName;
                
                if (String.isNotBlank(referenceField)) {
                    query += ' WHERE ' + referenceField + ' = \'' + String.escapeSingleQuotes(currentUserContactId) + '\'';
                }
                if (String.isNotBlank(filter)) {
                    query += ' AND ' + filter;
                }
                /* Add RecordType filter ONLY if the metadata
                   is for 'My Affinities'. 'My Service' records will just use their own 
                   HAM_Additional_Filter__c defined in the metadata. */
                if(objectApiName == 'ucinn_ascendv2__Involvement__c' && fetcher.HAM_Level_1__c == HAM_ConstantsUtil.MY_AFFINITIES){ 
                    query += ' AND RecordType.DeveloperName = \'' + involvementRecordType + '\'';
                }
                //query += ' WITH SECURITY_ENFORCED';         
                system.debug('Final query -'+query); 
                try {
                    if (String.isNotBlank(displayField)) {
                        for (SObject record : Database.query(query)) { 
                            system.debug('record -'+record);   
                            Object fieldValue = record.get(displayField);
                            if (fieldValue != null) {
                                formattedRecords.add(String.valueOf(fieldValue));
                            }
                        }
                    }
                } catch (Exception e) {
                    System.debug('Error querying for ' + fetcher.DeveloperName + ': ' + e.getMessage());
                }
            }
            // Populate the appropriate wrapper class
            if (fetcher.HAM_Level_1__c == HAM_ConstantsUtil.MY_AFFINITIES) {
                MyAffinity myAffinity = new MyAffinity();
                myAffinity.displayLabel = fetcher.HAM_Display_Label__c;
                myAffinity.displayType = fetcher.HAM_Display_Type__c;
                myAffinity.order = fetcher.HAM_Order__c;
                
                if (fetcher.HAM_Display_Type__c == HAM_ConstantsUtil.LISTS && !formattedRecords.isEmpty()) {
                    myAffinity.displayValueList = formattedRecords;
                } else {
                    // Check if we should show the Default Display Value from metadata
                    // This applies if it's explicitly a HARDCODED_STRING OR if it's an empty LIST
                    if (fetcher.HAM_Display_Type__c == HAM_ConstantsUtil.HARDCODED_STRING || 
                       (fetcher.HAM_Display_Type__c == HAM_ConstantsUtil.LISTS && formattedRecords.isEmpty())) {
                        
                        myAffinity.displayValueText = (fetcher.HAM_Default_Display_Value__c != null) ? fetcher.HAM_Default_Display_Value__c : null;
                    } 
                    // Otherwise, join the records (standard text display)
                    else {
                        myAffinity.displayValueText = String.join(formattedRecords, '; ');
                    }
                }
                myServiceAffinities.myAffinities.add(myAffinity);

            }else if (fetcher.HAM_Level_1__c == HAM_ConstantsUtil.MY_SERVICE) {
                MyService myService = new MyService();
                myService.displayLabel = fetcher.HAM_Display_Label__c;
                myService.displayType = fetcher.HAM_Display_Type__c;
                myService.order = fetcher.HAM_Order__c;
                
                if (fetcher.HAM_Display_Type__c == HAM_ConstantsUtil.LISTS) {
                    myService.displayValueList = formattedRecords;
                } else {
                    myService.displayValueText = (fetcher.HAM_Display_Type__c == HAM_ConstantsUtil.HARDCODED_STRING) ? 
                                                    ((fetcher.HAM_Default_Display_Value__c != null) ? fetcher.HAM_Default_Display_Value__c : null)
                                                    : (String.join(formattedRecords, '; '));
                }
                myServiceAffinities.myServices.add(myService);
            }
        }

        return myServiceAffinities;
    }
    
    /**
    * @description : Method to get current user's Contact details and Philanthropy data
    * @param : currentUserContactId - contactId of logged in portal user.
    * @Returns : MyImpactDataWrapper - wrapper  object.
    **/
    @AuraEnabled(cacheable=true)
	public static MyImpactDataWrapper getContactAndPhilanthropyData(String currentUserContactId){
		MyImpactDataWrapper response = new MyImpactDataWrapper();
    
		// Dynamically building the SOQL query string for Constituent fields based on Custom Metadata and populating wrapper classes MyProfileBioData & MyProfileMyConnect
        String whereClause = 'HAM_Level_1__c IN (\'My Profile\',\'My Philanthropy Highlight\')';
        List<MyImpactMetadata> myImpactMetadataFieldsToQuery = getMyImpactMetadata(whereClause);
        List<BadgeMetadata> badgeMetdataFieldsToQuery = getBadgeMetadata();

        Set<String> fieldApiNames = new Set<String>();
        response.bioData = new list<MyProfileBioData>();
        response.myConnect = new list<MyProfileMyConnect>();
        response.philanthropyField = new list<philanthropyField>();
        
        for(MyImpactMetadata field : myImpactMetadataFieldsToQuery) {
            fieldApiNames.add(field.fieldApiName);            
        }

        for(BadgeMetadata field : badgeMetdataFieldsToQuery) {
            fieldApiNames.add(field.mappingFieldApi);            
        }

        String queryFields = String.join(new List<String>(fieldApiNames), ', ');


		// This subquery is used to fetch Degree Information.
        String degreeSubquery = '(SELECT Id,ucinn_ascendv2__Major_Degree_Formula__c,ucinn_ascendv2__Second_Major_Formula__c,Third_Concentration_Formula__c,ucinn_ascendv2__Minor_Degree_Formula__c,Second_Minor__c,Third_Minor__c FROM ucinn_ascendv2__Degree_Information_Contact__r where RecordType.DeveloperName = \'School_Degree_Information\')';
		
        // This subquery is used to fetch my campus contact email and phone
        String campusContact = 'HAM_Show_PRM_Details__c,HAM_PRM_Email__c,HAM_PRM_Phone__c,ucinn_ascendv2__PRM__r.Id,ucinn_ascendv2__PRM__r.FirstName';
        
        // This subquery is used to fetch my class contact
        String classContact = '(SELECT Id, ucinn_ascendv2__Assigned_Relationship_Mngr_Name_Formula__c FROM ucinn_ascendv2__Assignments_Contact__r WHERE ucinn_ascendv2__Assignment_Type__c = \'Class Manager\' AND ucinn_ascendv2__Assignment_End_Date__c = null AND RecordType.DeveloperName = \'Contact_Assignment\')';
        
        // This subquery is used to fetch social media detail of facebook
		String socialMediaSubquery = '(SELECT Id,ucinn_ascendv2__URL__c FROM ucinn_ascendv2__Social_Media__r where ucinn_ascendv2__Platform__c= \'Facebook\')';
		
        // Main query to fetch constituent
		String queryString = 'SELECT Id, HAM_Profile_Picture_URL__c, HAM_Name_w_Suffix__c,ucinn_ascendv2__Contact_Type__c, HAM_LiveAlumni_LinkedIn_URL__c,'+ queryFields + ', ' + campusContact +', '+ classContact + ', '+ degreeSubquery + ', ' + socialMediaSubquery + ' FROM Contact WHERE Id = \'' + String.escapeSingleQuotes(currentUserContactId) + '\' LIMIT 1';
        
		Contact constituentSObject = null;
		try {
            List<Contact> results = (List<Contact>)Database.query(queryString);
            
            if (!results.isEmpty()) {
                constituentSObject = results[0];
            }
        } catch (System.QueryException e) {
             System.debug('QueryException when fetching Contact: ' + e.getMessage());
             response.error = 'Failed to retrieve constituent details. ' + e.getMessage();
             return response;
        }

        if (constituentSObject != null) {
           
            try{
                response.contact = new ContactInfo();
                // populate ContactInfo wrapper from SObject
                response.contact.Id = constituentSObject.get('Id') != null ? (Id)constituentSObject.get('Id') : '';
                response.contact.userPic = constituentSObject.get('HAM_Profile_Picture_URL__c') != null ? (String)constituentSObject.get('HAM_Profile_Picture_URL__c') : '';
                response.contact.name = constituentSObject.get('HAM_Name_w_Suffix__c') != null ? (String)constituentSObject.get('HAM_Name_w_Suffix__c') : '';
                response.contact.linkedIn = constituentSObject.get('HAM_LiveAlumni_LinkedIn_URL__c') != null ? (String)constituentSObject.get('HAM_LiveAlumni_LinkedIn_URL__c') : '';
                String contactType = constituentSObject.get('ucinn_ascendv2__Contact_Type__c') != null ? (String)constituentSObject.get('ucinn_ascendv2__Contact_Type__c') : '';
                response.contact.isKirklandAlumnae =  contactType != null &&  !String.isBlank(contactType) && contactType.contains(HAM_ConstantsUtil.KIRKLAND_ALUMNAE)? true : false;

                // Populate related ucinn_ascendv2__Degree_Information__c
                response.degree = new List<DegreeInfo>();
                List<String> majors = new List<String>();
                List<String> minors = new List<String>();
                List<ucinn_ascendv2__Degree_Information__c> rawDegrees = (List<ucinn_ascendv2__Degree_Information__c>)constituentSObject.getSobjects('ucinn_ascendv2__Degree_Information_Contact__r');
    
                if (rawDegrees != null && !rawDegrees.isEmpty()) {
                    for (ucinn_ascendv2__Degree_Information__c degreeRecord : rawDegrees) {
                        
                        majors.add(fetchDegreeValue(degreeRecord,'ucinn_ascendv2__Major_Degree_Formula__c'));
                        majors.add(fetchDegreeValue(degreeRecord,'ucinn_ascendv2__Second_Major_Formula__c'));
                        majors.add(fetchDegreeValue(degreeRecord,'Third_Concentration_Formula__c'));
                        minors.add(fetchDegreeValue(degreeRecord,'ucinn_ascendv2__Minor_Degree_Formula__c'));
                        minors.add(fetchDegreeValue(degreeRecord,'Second_Minor__c'));
                        minors.add(fetchDegreeValue(degreeRecord,'Third_Minor__c'));
                    }
                    
                    DegreeInfo singleDegree = new DegreeInfo();
                    singleDegree.majors = majors;
                    singleDegree.minors = minors;
                    response.degree.add(singleDegree);
                }
                
                response.otherInfo = new OtherInfo();

                // Populate related social media Information
                List<ucinn_ascendv2__Social_Media__c> socialMedia = (List<ucinn_ascendv2__Social_Media__c>)constituentSObject.getSobjects('ucinn_ascendv2__Social_Media__r');
                if(socialMedia != null){
                    response.otherInfo.facebook = socialMedia[0].get('ucinn_ascendv2__URL__c') != null ? (String)socialMedia[0].get('ucinn_ascendv2__URL__c') : '';
                }
                
                response.otherInfo.isGift = (constituentSObject.get('HAM_Current_FY_Paid__c') != null && (Decimal)constituentSObject.get('HAM_Current_FY_Paid__c') > 0) ? false : true;
                
                // Populating class contact data
                List<ucinn_ascendv2__Assignment__c> assignments = (List<ucinn_ascendv2__Assignment__c>)constituentSObject.getSobjects('ucinn_ascendv2__Assignments_Contact__r');
                MyProfileMyConnect classContacts = new MyProfileMyConnect();
                classContacts.displayLabel = System.Label.ham_MyClassContact;
                classContacts.displayOrder = 1;
                if (assignments != null && !assignments.isEmpty()) {
                        
                    classContacts.displayValue = assignments[0].ucinn_ascendv2__Assigned_Relationship_Mngr_Name_Formula__c != null ? assignments[0].ucinn_ascendv2__Assigned_Relationship_Mngr_Name_Formula__c : '';  
                      
                }     
                response.myConnect.add(classContacts);          
    
                // Populate campus contact data
                Boolean showPRM = constituentSObject.get('HAM_Show_PRM_Details__c') == true;
                Boolean hasPRM  = constituentSObject.getSObject('ucinn_ascendv2__PRM__r') != null;
                response.campusContact = new CampusContact();
                if (showPRM && hasPRM) {
                    response.campusContact.name  = (String)(((SObject)constituentSObject.getSObject('ucinn_ascendv2__PRM__r')).get('FirstName'));
                    response.campusContact.phone = constituentSObject.get('HAM_PRM_Phone__c') != null ? (String)constituentSObject.get('HAM_PRM_Phone__c') : '';
                    response.campusContact.email = constituentSObject.get('HAM_PRM_Email__c') != null ? (String)constituentSObject.get('HAM_PRM_Email__c') : '';
                } else {
                    response.campusContact.name  = '';
                    response.campusContact.phone = '';
                    response.campusContact.email = '';
                }

                for(MyImpactMetadata field: myImpactMetadataFieldsToQuery){

                    //Populate Wrapper class MyProfileBioData
                    if(field.level2 == HAM_ConstantsUtil.BIO_DATA){
                        MyProfileBioData bioData = new MyProfileBioData();
                        bioData.displayLabel = field.displayLabel;
                        bioData.displayOrder = field.displayOrder;
                        bioData.displayValue = constituentSObject.get(field.fieldApiName) != null ? String.valueOf(constituentSObject.get(field.fieldApiName)) : '';
                                      
                        response.bioData.add(bioData);
                    }  
                    
                    //Populate Wrapper class MyProfileMyConnect
                    else if(field.level2 == HAM_ConstantsUtil.MY_CONNECT){
                        MyProfileMyConnect myConnect = new MyProfileMyConnect();
                        myConnect.displayLabel = field.displayLabel;
                        myConnect.displayOrder = field.displayOrder;
                        myConnect.displayValue = constituentSObject.get(field.fieldApiName) != null ? String.valueOf(constituentSObject.get(field.fieldApiName)) : '';  
                        response.myConnect.add(myConnect);
                    }

                    //Populate philanthropy wrapper fields
                    else if(field.level1 == HAM_ConstantsUtil.MY_PHILANTHROPY_HIGHLIGHT){
                        PhilanthropyField myPhilanthropy = new PhilanthropyField();
                        myPhilanthropy.label = field.displayLabel;
                        myPhilanthropy.order = field.displayOrder;
                        myPhilanthropy.sectionOrder = field.sectionOrder;
                        myPhilanthropy.value = ((field.fieldApiName != null) && constituentSObject.get(field.fieldApiName) != null)? String.valueOf(constituentSObject.get(field.fieldApiName)) : ' '; 
                        myPhilanthropy.type = field.type;
                        myPhilanthropy.sectionLabel = field.level2;
                        response.philanthropyField.add(myPhilanthropy);
                    }
                }

                // populate BadgeMetadata
                response.hcBadges = new List<HCBadge>();                

                for (BadgeMetadata badgeMdt : badgeMetdataFieldsToQuery) {
                    try {
                        // Check if the Contact has the corresponding boolean field set to true
                        Boolean hasBadge = constituentSObject.get(badgeMdt.mappingFieldApi) != null ? (Boolean)constituentSObject.get(badgeMdt.mappingFieldApi): false;
                        if (hasBadge == true) { 
                            HCBadge badge = new HCBadge();
                            badge.label = badgeMdt.displayName;
                            badge.imageUrl = badgeMdt.imagePath;
                            badge.order = badgeMdt.displayOrder;
                            response.hcBadges.add(badge);
                        }
                    } catch (Exception e) {
                        System.debug('Error checking badge field ' + badgeMdt.mappingFieldApi + ': ' + e.getMessage());
                    }
                }            

            }
            catch (Exception e){
                response.error = e.getMessage() + ' at line ' + e.getLineNumber();
                System.debug('Error processing constituentSObject data: ' + response.error);
            }                    
        }
        
        return response;
    }

    /**
     * @description Retrieves the list of available volunteer interests (specifically Athletics) 
     * and flags which ones are currently active for the portal users.
     * Used to populate the UI where users can select/deselect interests.
     * * @param currentUserContactId The Salesforce ID of the Contact currently logged in/viewing the page.
     * @return List<InterestWrapper> A list of wrapper objects containing the interest details 
     * and the specific user's existing record 
     */
    @AuraEnabled
    public static List<InterestWrapper> getInterests(String currentUserContactId) {
        List<InterestWrapper> wrapperList = new List<InterestWrapper>();

        // Fetch all available Foundation Funding Interests (The Master List)
        List<ucinn_ascendv2__Foundation_Funding_Interests__c> allInterests = 
            [SELECT Id, Name FROM ucinn_ascendv2__Foundation_Funding_Interests__c WHERE (HAM_Category__c = 'Athletics' OR HAM_Category__c = 'Private Society and Clubs') AND HAM_Is_Publicly_Visible__c = true ORDER BY Name ASC];

        // Fetch existing active Funding Interests for this Contact
        // Note: We filter out records that already have an End Date in the past 
        List<ucinn_ascendv2__Funding_Interest__c> existingLinks = 
            [SELECT Id, ucinn_ascendv2__Foundation_Funding_Interest__c 
             FROM ucinn_ascendv2__Funding_Interest__c 
             WHERE ucinn_ascendv2__Contact__c = :currentUserContactId 
             AND (ucinn_ascendv2__End_Date__c = NULL OR ucinn_ascendv2__End_Date__c > TODAY)];

        // Map existing links for easy lookup by Parent ID
        Map<Id, ucinn_ascendv2__Funding_Interest__c> activeMap = new Map<Id, ucinn_ascendv2__Funding_Interest__c>();
        for(ucinn_ascendv2__Funding_Interest__c link : existingLinks) {
            activeMap.put(link.ucinn_ascendv2__Foundation_Funding_Interest__c, link);
        }

        // Build the wrapper list
        for(ucinn_ascendv2__Foundation_Funding_Interests__c interest : allInterests) {
            ucinn_ascendv2__Funding_Interest__c childRec = activeMap.get(interest.Id);
            wrapperList.add(new InterestWrapper(interest, childRec));
        }

        return wrapperList;
    }

    /**
     * @description Processes the user's interest selections from the UI. 
     * It handles two scenarios:
     * 1. Creating new active records for newly selected interests.
     * 2. Expiring (setting End Date) for interests that were deselected.
     * @param dataStr A JSON-serialized string of the 'InterestWrapper' list containing UI selections.
     * @param currentUserContactId The ID of the Contact for whom these interests are being saved.
     */
    @AuraEnabled
    public static void saveInterests(String dataStr, Id currentUserContactId) {
        List<InterestWrapper> data = (List<InterestWrapper>) JSON.deserialize(dataStr, List<InterestWrapper>.class);
        
        List<ucinn_ascendv2__Funding_Interest__c> toInsert = new List<ucinn_ascendv2__Funding_Interest__c>();
        List<ucinn_ascendv2__Funding_Interest__c> toUpdate = new List<ucinn_ascendv2__Funding_Interest__c>();

        // Fetch the specific Record Type ID using the Developer Name
        Id targetRecordTypeId = Schema.SObjectType.ucinn_ascendv2__Funding_Interest__c
            .getRecordTypeInfosByDeveloperName()
            .get('Contact_Funding_Interest') // Matches the "Record Type Name" 
            .getRecordTypeId();

        for(InterestWrapper item : data) {
            // CASE 1: INSERT (User Checked the box, no record existed)
            if(item.isChecked && item.existingChildId == null) {
                ucinn_ascendv2__Funding_Interest__c newRec = new ucinn_ascendv2__Funding_Interest__c();
                
                // Set the Relationship lookups
                newRec.ucinn_ascendv2__Contact__c = currentUserContactId;
                newRec.ucinn_ascendv2__Foundation_Funding_Interest__c = item.foundationInterestId;
                
                // Set the Record Type explicitly
                newRec.RecordTypeId = targetRecordTypeId; 
                
                newRec.HAM_Category__c ='General Interest';
                newRec.ucinn_ascendv2__Start_Date__c = Date.today();

                toInsert.add(newRec);
            }
            
            // CASE 2: UPDATE (User Unchecked the box, record existed)
            else if(!item.isChecked && item.existingChildId != null) {
                ucinn_ascendv2__Funding_Interest__c updateRec = new ucinn_ascendv2__Funding_Interest__c();
                updateRec.Id = item.existingChildId;
                updateRec.ucinn_ascendv2__End_Date__c = Date.today();
                toUpdate.add(updateRec);
            }
        }

        if(!toInsert.isEmpty()) insert toInsert;
        if(!toUpdate.isEmpty()) update toUpdate;
    }


    /**
     * @description Retrieves the list of available volunteer Involment (specifically Student NCAA Athletics) 
     * and flags which ones are currently active for the portal users.
     * Used to populate the UI where users can select/deselect involvement.
     * * @param currentUserContactId The Salesforce ID of the Contact currently logged in/viewing the page.
     * @return List<InvolementWrapper> A list of wrapper objects containing the involvment details 
     * and the specific user's existing record 
     */
    @AuraEnabled
    public static List<InvolementWrapper> getInvolments(String currentUserContactId) {
        List<InvolementWrapper> wrapperList = new List<InvolementWrapper>();

        contact con = [SELECT Id, Name, ucinn_ascendv2__Primary_Contact_Type__c FROM Contact WHERE Id =: currentUserContactId LIMIT 1];
       
         // Get RecordType based on Contact Type
        String recordTypeName = con.ucinn_ascendv2__Primary_Contact_Type__c == 'Student' ? 'Student_Involvement' : 'Alumni_Involvement';

        // Fetch all available Foundation Funding Interests (The Master List)
        List<ucinn_ascendv2__Involvement_Value__c> allInvolments = 
            [SELECT Id, Name,ucinn_ascendv2__Involvement_Description__c FROM ucinn_ascendv2__Involvement_Value__c  WHERE HAM_Category__c = 'Student NCAA Athletics'  ORDER BY Name ASC];

        // Fetch existing active Funding Interests for this Contact
        // Note: We filter out records that already have an End Date in the past 
        
       List<ucinn_ascendv2__Involvement__c> existingLinks =
        [SELECT Id,
                ucinn_ascendv2__Involvement_Code_Description_Formula__c,
                ucinn_ascendv2__Contact__c,
                ucinn_ascendv2__Involvement_Code__c
         FROM ucinn_ascendv2__Involvement__c
         WHERE ucinn_ascendv2__Contact__c = :currentUserContactId
         AND HAM_Category__c = 'Student NCAA Athletics'
         AND RecordType.DeveloperName = :recordTypeName
         AND (ucinn_ascendv2__End_Date__c = null OR ucinn_ascendv2__End_Date__c > TODAY)];

        // Map existing links for easy lookup by Parent ID
        Map<Id, ucinn_ascendv2__Involvement__c> activeMap = new Map<Id, ucinn_ascendv2__Involvement__c>();
        for(ucinn_ascendv2__Involvement__c link : existingLinks) {
            activeMap.put(link.ucinn_ascendv2__Involvement_Code__c , link);
        }
        
        // Build the wrapper list
        for(ucinn_ascendv2__Involvement_Value__c invol : allInvolments) {
            ucinn_ascendv2__Involvement__c childRec = activeMap.get(invol.Id);
            wrapperList.add(new InvolementWrapper(invol, childRec));
        }
        
        return wrapperList;
    }

    /**
     * @description Retrieves the list of available volunteer Involment (specifically Student Clubs and Student Private Societies) 
     * and flags which ones are currently active for the portal users.
     * Used to populate the UI where users can select/deselect involvement.
     * * @param currentUserContactId The Salesforce ID of the Contact currently logged in/viewing the page.
     * @return List<InvolementWrapper> A list of wrapper objects containing the involvment details 
     * and the specific user's existing record 
     */

     @AuraEnabled
    public static List<InvolementWrapper> getInvolmentsUnderG(String currentUserContactId) {
        List<InvolementWrapper> wrapperList = new List<InvolementWrapper>();

        // Fetch Log In Portal user info
        contact con = [SELECT Id, Name, ucinn_ascendv2__Primary_Contact_Type__c FROM Contact WHERE Id =: currentUserContactId LIMIT 1];

        // Get RecordType based on Contact Type
        String recordTypeName = con.ucinn_ascendv2__Primary_Contact_Type__c == 'Student' ? 'Student_Involvement' : 'Alumni_Involvement';

        // Fetch all available Foundation Funding Interests (The Master List)
        List<ucinn_ascendv2__Involvement_Value__c> allInvolments = 
            [SELECT Id, Name,ucinn_ascendv2__Involvement_Description__c FROM ucinn_ascendv2__Involvement_Value__c  WHERE HAM_Category__c = 'Student Clubs' OR HAM_Category__c  = 'Student Private Societies'  ORDER BY Name ASC];

        // Fetch existing active Funding Interests for this Contact
        // Note: We filter out records that already have an End Date in the past 
        List<ucinn_ascendv2__Involvement__c > existingLinks = 
            [SELECT Id, ucinn_ascendv2__Involvement_Code_Description_Formula__c,ucinn_ascendv2__Contact__c,ucinn_ascendv2__Involvement_Code__c    
             FROM ucinn_ascendv2__Involvement__c  
             WHERE ucinn_ascendv2__Contact__c   = :currentUserContactId AND  (HAM_Category__c = 'Student Clubs' OR HAM_Category__c  = 'Student Private Societies') AND RecordType.DeveloperName=:recordTypeName
             AND (ucinn_ascendv2__End_Date__c = NULL OR ucinn_ascendv2__End_Date__c > TODAY)];

        // Map existing links for easy lookup by Parent ID
        Map<Id, ucinn_ascendv2__Involvement__c> activeMap = new Map<Id, ucinn_ascendv2__Involvement__c>();
        for(ucinn_ascendv2__Involvement__c link : existingLinks) {
            activeMap.put(link.ucinn_ascendv2__Involvement_Code__c , link);
        }

        // Build the wrapper list
        for(ucinn_ascendv2__Involvement_Value__c invol : allInvolments) {
            ucinn_ascendv2__Involvement__c childRec = activeMap.get(invol.Id);
            wrapperList.add(new InvolementWrapper(invol, childRec));
        }
       
        return wrapperList;
    }

    /**
     * @description Processes the user's involment selections from the UI. 
     * It handles two scenarios:
     * 1. Creating new active records for newly selected involment.
     * 2. Expiring (setting End Date) for involment that were deselected.
     * @param dataStr A JSON-serialized string of the 'InterestWrapper' list containing UI selections.
     * @param currentUserContactId The ID of the Contact for whom these involment are being saved.
     */
    @AuraEnabled
    public static void saveInvolments(String dataStr, Id currentUserContactId) {
        List<InvolementWrapper> data = (List<InvolementWrapper>) JSON.deserialize(dataStr, List<InvolementWrapper>.class);
           system.debug('data -'+ data);
        
        
        List<ucinn_ascendv2__Involvement__c> toInsert = new List<ucinn_ascendv2__Involvement__c>();
        List<ucinn_ascendv2__Involvement__c> toUpdate = new List<ucinn_ascendv2__Involvement__c>();

        // Fetch the specific Record Type ID using the Developer Name
        Id targetRecordTypeId = Schema.SObjectType.ucinn_ascendv2__Involvement__c
            .getRecordTypeInfosByDeveloperName()
            .get('Alumni_Involvement') // Matches the "Record Type Name" 
            .getRecordTypeId();

        Id studenttargetRecordTypeId = Schema.SObjectType.ucinn_ascendv2__Involvement__c
            .getRecordTypeInfosByDeveloperName()
            .get('Student_Involvement') // Matches the "Record Type Name" 
            .getRecordTypeId();

        contact con = [SELECT Id, Name, ucinn_ascendv2__Primary_Contact_Type__c FROM Contact WHERE Id =: currentUserContactId LIMIT 1];


        for(InvolementWrapper item : data) {
            // CASE 1: INSERT (User Checked the box, no record existed)
            if(item.isChecked && item.existingChildId == null) {
                ucinn_ascendv2__Involvement__c newRec = new ucinn_ascendv2__Involvement__c();
                
                // Set the Relationship lookups
                newRec.ucinn_ascendv2__Contact__c = currentUserContactId;
                newRec.ucinn_ascendv2__Involvement_Code__c = item.foundationInterestId;
                
                // Set the Record Type explicitly
                if(con.ucinn_ascendv2__Primary_Contact_Type__c == 'Student'){
                    newRec.RecordTypeId = studenttargetRecordTypeId; 
                }else{
                    newRec.RecordTypeId = targetRecordTypeId; 
                }
                
                //newRec.HAM_Category__c ='Student NCAA Athletics';
                newRec.ucinn_ascendv2__Start_Date__c = Date.today();

                toInsert.add(newRec);
            }
            
            // CASE 2: UPDATE (User Unchecked the box, record existed)
            else if(!item.isChecked && item.existingChildId != null) {
                ucinn_ascendv2__Involvement__c updateRec = new ucinn_ascendv2__Involvement__c();
                updateRec.Id = item.existingChildId;
                updateRec.ucinn_ascendv2__End_Date__c = Date.today();
                toUpdate.add(updateRec);
            }
        }

        system.debug('toInsert -'+toInsert);
        system.debug('toUpdate -'+toUpdate);
 

        if(!toInsert.isEmpty()) insert toInsert;
        if(!toUpdate.isEmpty()) update toUpdate;

        
    }

    private static String fetchDegreeValue(ucinn_ascendv2__Degree_Information__c degreeRec, String degreeField) {
        return degreeRec.get(degreeField) != null ? (String) degreeRec.get(degreeField) : '';
    }

    /**
     * @description Fetches the File and generates a secure Public Preview URL, bypassing Community sharing restrictions.
     */
    @AuraEnabled
    public static String getReceiptFileUrl(Id recordId) {
        String keyword = '%' + System.Label.ham_Receipt_File_Keyword + '%';
        Id versionId = null;
        
        // Default fallback name just in case
        String originalFileName = ' '; 
        
        // 1. Find the Latest Published Version of the file AND its exact Title
        for (ContentDocumentLink cdl : [
            SELECT ContentDocument.LatestPublishedVersionId, ContentDocument.Title
            FROM ContentDocumentLink 
            WHERE LinkedEntityId = :recordId 
            AND ContentDocument.Title LIKE :keyword 
            LIMIT 1
        ]) {
            versionId = cdl.ContentDocument.LatestPublishedVersionId;
            
            // Capture the exact file name from Salesforce!
            originalFileName = cdl.ContentDocument.Title; 
        }
        
        if (versionId == null) {
            return null; // File not found
        }
        
        // 2. Check if a Public Link (Content Distribution) already exists for this file
        List<ContentDistribution> existingLinks = [
            SELECT DistributionPublicUrl 
            FROM ContentDistribution 
            WHERE ContentVersionId = :versionId 
            LIMIT 1
        ];
        
        if (!existingLinks.isEmpty()) {
            return existingLinks[0].DistributionPublicUrl;
        }
        
        // 3. If no link exists, generate a new secure Public Link on the fly
        ContentDistribution newDist = new ContentDistribution();
        
        // Assign the exact file name here
        newDist.Name = originalFileName; 
        
        newDist.ContentVersionId = versionId;
        newDist.PreferencesAllowViewInBrowser = true; 
        newDist.PreferencesLinkLatestVersion = true;
        newDist.PreferencesAllowOriginalDownload = true;
        newDist.PreferencesPasswordRequired = false;
        
        insert newDist;
        
        // Re-query to get the generated Preview URL
        ContentDistribution insertedDist = [
            SELECT DistributionPublicUrl 
            FROM ContentDistribution 
            WHERE Id = :newDist.Id
        ];
        
        return insertedDist.DistributionPublicUrl;
    }

    /**
     * @description Re-queries the Receipts table data dynamically based on Date Filters, reusing the metadata.
     */
    @AuraEnabled
    public static PhilanthropyDataTable getFilteredReceiptsData(String currentUserContactId, Date startDate, Date endDate) {
        if (!getReceiptsTableStatus()) {
            return null;
        }
        
        // Properly handle the List assignment using existing helper method!
        String whereClause = 'HAM_Level_2__c = \'Receipts\'';
        List<HAM_Object_Fetcher__mdt> metadataList = getPhilanthrophyDetailMetadata(whereClause);
        
        if (metadataList == null || metadataList.isEmpty()) {
            return null;
        }
        
        // Explicitly grab the first record from the List
        HAM_Object_Fetcher__mdt field = metadataList[0];

        // Dynamically build the query
        String query = 'SELECT ' + field.HAM_Table_Field_APIs__c + ' FROM ' + field.HAM_Related_Object__c + 
                       ' WHERE ' + field.HAM_Reference_Field__c + ' = \'' + String.escapeSingleQuotes(currentUserContactId) + '\'';

        if (startDate != null) {
            query += ' AND Receipt_Date__c >= :startDate';
        }
        if (endDate != null) {
            query += ' AND Receipt_Date__c <= :endDate';
        }
        if (String.isNotBlank(field.HAM_Additional_Filter__c)) {
            query += ' AND ' + field.HAM_Additional_Filter__c;
        }

        query += ' ' + field.HAM_Table_Default_Sort_Order__c;
        
        // Build and return the standard wrapper
        PhilanthropyDataTable dataTable = new PhilanthropyDataTable();
        dataTable.tableName = field.HAM_Display_Label__c; 
        dataTable.columnApiNames = field.HAM_Table_Field_APIs__c.split(','); 
        dataTable.columnLabels = field.HAM_Table_Field_Labels__c.split(','); 
        dataTable.records = Database.query(query);
        dataTable.fieldTypes = field.HAM_Table_Field_Types__c.split(',');
        dataTable.displayLimit = (Decimal) field.HAM_Table_Limit__c;
        dataTable.displayLoadMore = field.HAM_Table_Load_More__c;
        dataTable.order = (Decimal)field.HAM_Order__c;
        
        return dataTable;
    }

    /**
    * @description Fetches the current value of the "Describe My Impact" long text field for a contact.
    * Used to pre-populate the edit modal on the My Impact page.
    * @param currentUserContactId - contactId of logged in portal user.
    * @return String - the current text value of HAM_Describe_My_Impact__c (empty string if none).
    */
    @AuraEnabled(cacheable=false)
    public static String getDescribeMyImpact(String currentUserContactId) {
        String describeMyImpact = '';
        try {
            Contact con = [
                SELECT Id, HAM_Describe_My_Impact__c
                FROM Contact
                WHERE Id = :currentUserContactId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            describeMyImpact = con.HAM_Describe_My_Impact__c != null ? con.HAM_Describe_My_Impact__c : '';
        } catch (Exception e) {
            System.debug('Error in getDescribeMyImpact: ' + e.getMessage());
        }
        return describeMyImpact;
    }

    /**
    * @description Saves the user-edited "Describe My Impact" text back to the Contact record.
    * @param currentUserContactId - contactId of logged in portal user.
    * @param describeMyImpact - the new text entered by the user in the modal.
    */
    @AuraEnabled
    public static void saveDescribeMyImpact(String currentUserContactId, String describeMyImpact) {
        try {
            Contact con = new Contact(
                Id = currentUserContactId,
                HAM_Describe_My_Impact__c = describeMyImpact
            );
            update con;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to save Describe My Impact: ' + e.getMessage());
        }
    }
}