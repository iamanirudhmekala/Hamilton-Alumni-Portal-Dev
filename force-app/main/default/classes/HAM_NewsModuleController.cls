/**
* @File Name : HAM_NewsModuleController.cls
* @Description :
* @Author : Cube84 - Asheesh
* @Last Modified By :
* @Last Modified On : December 26, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | December 26, 2025 | Asheesh | Initial Version
**/

public without sharing class HAM_NewsModuleController {
    
    // Wrapper for child metadata fields
    public class DisplayFieldMetadata {
        @AuraEnabled public String fieldApiName;
        @AuraEnabled public String fieldPurpose;
        @AuraEnabled public String fieldLabel;
        @AuraEnabled public String fieldType;
        @AuraEnabled public Integer displayOrder;
        
        // Constructor for clean instantiation 
        public DisplayFieldMetadata(String api, String purpose, String label, String type, Integer order) {
            this.fieldApiName = api;
            this.fieldPurpose = purpose;
            this.fieldLabel = label;
            this.fieldType = type;
            this.displayOrder = order;
        }
    }
    
    // Consolidated structure to return metadata configuration details
    public class ComponentConfigData {
        @AuraEnabled public String sourceObjectApiName;
        @AuraEnabled public String whereClause;
        @AuraEnabled public Integer maxRecords;
        @AuraEnabled public String sortField;
        @AuraEnabled public String componentType;
        @AuraEnabled public Boolean isActive;
        
        @AuraEnabled public List<DisplayFieldMetadata> displayFields;
        @AuraEnabled public Map<String, String> purposeToApiMap; 
        @AuraEnabled public List<SObject> records;  // Added to get apex data
        
    }
    
    
    // --- Private Central Metadata Fetcher ---
    
        /**
    * @description Fetches all metadata configuration and related display fields for a given component key.
    *              Dynamically builds and executes SOQL query based on metadata configuration.
    *              Supports pagination via recordsToSkip and date filtering.
    * @param componentKey The unique key (CMP_Key__c) identifying the component configuration
    * @param recordsToSkip Number of records to skip for pagination (offset)
    * @param fromDate Start date filter in string format (converts to DateTime)
    * @param toDate End date filter in string format (converts to DateTime)
    * @return ComponentConfigData object containing configuration, display fields, and queried records
    */
    private static ComponentConfigData getConfigData(String componentKey, Integer recordsToSkip, String fromDate, String toDate, String category, Integer pageSize) {
        
        //String lastRecordName;
         Decimal lastDisplayValue;  
        DateTime fromDateFilter = fromDate != null ? Datetime.valueOf(fromDate) : null;
        DateTime toDateFilter = toDate != null ? Datetime.valueOf(toDate) : null;
        
        // Fetch parent configuration metadata
        List<HAM_Home_Page_Component_Config__mdt> config = [
            SELECT Id, CMP_Type__c, Is_Active__c, Source_Object__c, Max_Records__c, 
            Sort_Field__c, WHERE_Clause__c 
            FROM HAM_Home_Page_Component_Config__mdt 
            WHERE Is_Active__c = TRUE AND CMP_Key__c = :componentKey
            LIMIT 1
        ];
        
        // Return null if configuration doesn't exist or is inactive
        if (config.isEmpty() || !config[0].Is_Active__c) return null;
        
        // Fetch child display field metadata
        List<Ham_Home_Page_Child__mdt> fieldsMDT = [
            SELECT Field_Purpose__c, Field_API_Name__c, Display_Order__c, Field_Label__c, 
            Field_Type__c
            FROM Ham_Home_Page_Child__mdt 
            WHERE Ham_Home_Page_Component_Config__c = :config[0].Id 
            ORDER BY Display_Order__c ASC
        ];
        
        // Return null if no display fields are configured
        if (fieldsMDT.isEmpty()) return null;
        
        // Initialize configuration data object
        ComponentConfigData data = new ComponentConfigData();
        data.sourceObjectApiName = config[0].Source_Object__c;
        data.whereClause = config[0].WHERE_Clause__c;
        data.maxRecords = config[0].Max_Records__c != null ? config[0].Max_Records__c.intValue() : 0;
        data.sortField = config[0].Sort_Field__c;
        data.componentType = config[0].CMP_Type__c;
        data.isActive = config[0].Is_Active__c;
        data.displayFields = new List<DisplayFieldMetadata>();
        data.purposeToApiMap = new Map<String, String>();
        
        // Collect field API names for dynamic SOQL
        List<String> fieldApiNames = new List<String>();
        
        // Map child metadata to output structure
        for (Ham_Home_Page_Child__mdt mdt : fieldsMDT) {
            
            // Add display field metadata with all properties
            data.displayFields.add(new DisplayFieldMetadata(
                mdt.Field_API_Name__c, 
                mdt.Field_Purpose__c, 
                mdt.Field_Label__c, 
                mdt.Field_Type__c, 
                mdt.Display_Order__c != null ? mdt.Display_Order__c.intValue() : 0 
            ));
            
            // Build purpose-to-API-name map for LWC reference
            if (String.isNotBlank(mdt.Field_Purpose__c)) {
                data.purposeToApiMap.put(mdt.Field_Purpose__c, mdt.Field_API_Name__c);
            }
            
            // Collect field API names for SELECT clause
            if (String.isNotBlank(mdt.Field_API_Name__c)) {
                fieldApiNames.add(mdt.Field_API_Name__c);
            }
        }
        
        // --- Dynamic SOQL Execution ---
        
        // Always include Id field for LWC iteration keys
        fieldApiNames.add('Id'); 
        
        // Remove duplicates and join for SELECT clause
        String fieldsToSelect = String.join(new Set<String>(fieldApiNames), ',');
        
        // Build base SOQL query
        String soql = 'SELECT ' + fieldsToSelect + 
            ' FROM ' + config[0].Source_Object__c + 
            ' WHERE ' + config[0].WHERE_Clause__c;
        
        // Apply date filters if provided
        if(fromDate != null){
            soql += ' AND CreatedDate >= :fromDateFilter';
        }
        
        if(toDate != null){
            soql += ' AND CreatedDate <= :toDateFilter';
        }

        //  CATEGORY FILTER LOGIC
        if (String.isNotBlank(category) && category != 'all') {
            soql += ' AND HAM_News_Category__c = :category';
        }
        
        // Handle pagination using keyset-based approach with compound key for uniqueness
        // This ensures no records are skipped even when HAM_Display_Order__c has duplicate values
        if(recordsToSkip != 0 && (lastDisplayValue == null)){
            // Query to find the cursor position (last record of the previous page)
            String query = 'SELECT Id, HAM_Display_Order__c, CreatedDate FROM HAM_Listing__c WHERE ' + config[0].WHERE_Clause__c;
            
            // Apply same date filters to cursor query
            if(fromDate != null){
                query += ' AND CreatedDate >= :fromDateFilter';
            }
            
            if(toDate != null){
                query += ' AND CreatedDate <= :toDateFilter';
            }

            // Apply category filter to cursor query
            if (String.isNotBlank(category) && category != 'all') {
                query += ' AND HAM_News_Category__c = :category';
            }
            
            // Order by custom sort field + CreatedDate + Id for deterministic, unique ordering
            query += ' ORDER BY '+config[0].Sort_Field__c+' ASC NULLS LAST, CreatedDate DESC, Id ASC LIMIT :recordsToSkip';
            List<HAM_Listing__c> lstNews = Database.query(query);
            
            // Only apply cursor condition if we successfully retrieved the expected number of records
            if (!lstNews.isEmpty() && lstNews.size() == recordsToSkip) {
                // Get cursor values from the last record of the previous page
                HAM_Listing__c lastRecord = lstNews[recordsToSkip - 1];
                Decimal lastOrder = lastRecord.HAM_Display_Order__c;
                DateTime lastCreated = lastRecord.CreatedDate;
                Id lastId = lastRecord.Id;
                
                // Build compound cursor condition with explicit NULL handling
                // Sort order is: HAM_Display_Order__c ASC NULLS LAST, CreatedDate DESC, Id ASC
                
                if (lastOrder != null) {
                    // Case 1: Last record had a non-NULL HAM_Display_Order__c
                    // We want records where:
                    //   1. DisplayOrder > lastOrder (next display order group)
                    //   OR 2. DisplayOrder = lastOrder AND CreatedDate < lastCreated (same order, earlier date)
                    //   OR 3. DisplayOrder = lastOrder AND CreatedDate = lastCreated AND Id > lastId (same order & date)
                    //   OR 4. DisplayOrder IS NULL (all NULLs come after non-NULL values due to NULLS LAST)
                    soql += ' AND (HAM_Display_Order__c > :lastOrder ' +
                           'OR (HAM_Display_Order__c = :lastOrder AND CreatedDate < :lastCreated) ' +
                           'OR (HAM_Display_Order__c = :lastOrder AND CreatedDate = :lastCreated AND Id > :lastId) ' +
                           'OR HAM_Display_Order__c = NULL)';
                } else {
                    // Case 2: Last record had NULL HAM_Display_Order__c
                    // We're in the NULL section, filter by CreatedDate and Id only
                    soql += ' AND HAM_Display_Order__c = NULL ' +
                           'AND (CreatedDate < :lastCreated ' +
                           'OR (CreatedDate = :lastCreated AND Id > :lastId))';
                }
            }
        }
        
        // Apply sorting if configured - include Id for deterministic, unique ordering
        if (String.isNotBlank(config[0].Sort_Field__c)) {
            soql += ' ORDER BY ' + config[0].Sort_Field__c + ' ASC NULLS LAST, CreatedDate DESC, Id ASC'; 
        }
        
        // Apply record limit — pageSize param overrides metadata when provided
        Integer limitVal = (pageSize != null && pageSize > 0) ? pageSize : (config[0].Max_Records__c != null ? config[0].Max_Records__c.intValue() : 5);
        soql += ' LIMIT ' + limitVal;
        
        System.debug('Dynamic SOQL Query: ' + soql);
        
        // Execute dynamic query and handle errors
        try {
            data.records = Database.query(soql);
        } catch (Exception e) {
            System.debug('Dynamic SOQL Error for key ' + componentKey + ': ' + e.getMessage() + ' Query: ' + soql);
            data.records = new List<SObject>(); 
        }
        
        return data;
    }
    
    /**
    * @description LWC entry point for fetching news module configuration and records.
    *              Cacheable method that returns component configuration data including metadata and records.
    * @param componentKey Unique identifier for the component configuration (e.g., 'NewsModuleLWC')
    * @param recordsToSkip Number of records to skip for pagination
    * @param fromDate Optional start date filter (format: 'YYYY-MM-DD HH:mm:ss')
    * @param toDate Optional end date filter (format: 'YYYY-MM-DD HH:mm:ss')
    * @return ComponentConfigData containing configuration, display fields, and news records
    */
    @AuraEnabled(cacheable=true)
    public static ComponentConfigData getNewsConfig(String componentKey, Integer recordsToSkip, String fromDate, String toDate, String category, Integer pageSize) {
        return getConfigData(componentKey, recordsToSkip, fromDate, toDate, category, pageSize);
    }
    
    /**
    * @description Fetches the total count of active news records within the specified date range.
    *              Used for pagination calculation in the LWC component.
    * @param fromDate Optional start date filter (format: 'YYYY-MM-DD HH:mm:ss')
    * @param toDate Optional end date filter (format: 'YYYY-MM-DD HH:mm:ss')
    * @return Integer - Total count of news records matching the criteria, returns 0 on error
    */
    @AuraEnabled(cacheable=true)
    public static Integer getNewsRecordCount(String componentKey, String fromDate, String toDate, String category) {

        // Look up WHERE clause and source object from metadata
        List<HAM_Home_Page_Component_Config__mdt> config = [
            SELECT WHERE_Clause__c, Source_Object__c
            FROM HAM_Home_Page_Component_Config__mdt
            WHERE Is_Active__c = TRUE AND CMP_Key__c = :componentKey
            LIMIT 1
        ];
        if (config.isEmpty()) return 0;

        DateTime fromDateFilter = fromDate != null ? Datetime.valueOf(fromDate) : null;
        DateTime toDateFilter   = toDate   != null ? Datetime.valueOf(toDate)   : null;

        String queryString = 'SELECT COUNT() FROM ' + config[0].Source_Object__c
                           + ' WHERE ' + config[0].WHERE_Clause__c;

        if (fromDateFilter != null) queryString += ' AND CreatedDate >= :fromDateFilter';
        if (toDateFilter   != null) queryString += ' AND CreatedDate <= :toDateFilter';
        if (String.isNotBlank(category) && category != 'all') {
            queryString += ' AND HAM_News_Category__c = :category';
        }

        try {
            return Database.countQuery(queryString);
        } catch (QueryException e) {
            System.debug('Count Query Error: ' + e.getMessage());
            return 0;
        }
    }


    /**
    * @description Fetches the (HAM_Topics__c) HAM Topics picklist fields values to filter old news  .
    * @return  List<Map<String, String>> - 
    */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getPicklistValues(String objectName, String fieldName) {
        
        List<Map<String, String>> options = new List<Map<String, String>>();
        
        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);
        Schema.DescribeSObjectResult objDescribe = objType.getDescribe();
        
        Schema.SObjectField field = objDescribe.fields.getMap().get(fieldName);
        Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
        
        for (Schema.PicklistEntry entry : fieldDescribe.getPicklistValues()) {
            if (entry.isActive()) {
                options.add(new Map<String, String>{
                    'label' => entry.getLabel(),
                    'value' => entry.getValue()
                });
            }
        }
        
        return options;
    }
}