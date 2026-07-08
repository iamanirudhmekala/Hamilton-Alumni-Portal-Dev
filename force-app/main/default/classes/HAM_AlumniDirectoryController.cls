/**
* @File Name : HAM_AlumniDirectoryController.cls
* @description : This class is used to fetch all contact details on alumni directory page, based on user search.
* @Author : Cube84 - Sachin
* @Last Modified By : Sachin
* @Last Modified On : August 28, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | August 28, 2025 |  Sachin | Initial Version
* 1.1 | Sept 04, 2025 |  Sachin |  Done as part of Optimization
* 1.2 | Sept 29, 2025 |  Sachin |  updated buildWhereClause to incorporate middle name in search key using ucinn_ascendv2__Expanded_Name_Formula__c
* 1.3 | Oct 03, 2025 |  Sachin |  updated buildWhereClause to add default filter: exclude records with primary constituent type ('Student' AND 'Friend') And only include records with HAM_Is_Active__c = true.
**/

@SuppressWarnings('PMD.NoTrailingWhitespace, PMD.ExcessiveClassLength, PME.ExcessivePublicCount, PMD.ApexCRUDViolation, PMD.EmptyIfStmt, PMD.EmptyStatementBlock, PMD.AvoidNonRestrictiveQueries, PMD.CyclomaticComplexity, PMD.CognitiveComplexity, PMD.NcssCount, PMD.NcssTypeCount, PMD.DetectCopyPasteForApex, PMD.LocalVariableNamingConventions, PMD.ExcessiveParameterList, PMD.ApexSOQLInjection, PMD.AvoidDeeplyNestedIfStmts, PMD.AvoidDebugStatements, PMD.StdCyclomaticComplexity, PMD.NcssMethodCount')
public without sharing class HAM_AlumniDirectoryController {
    
    /**
     * @description Global Id of the logged-in Portal User Contact
     */
    Public static String portalUserId;

    // Cache to avoid re-querying ucinn_ascendv2__Contact_Name__c on every buildWhereClause call
    // without these variables, The 'Names' object query runs 3 times in buildWhereClause.
    private static String  cachedFuzzySearchKey     = null;
    private static Set<Id> cachedFuzzyContactIds    = null;
    
    /**
     * @description Wrapper class to pass filter metadata and options to the LWC
     */
    public class FilterWrapper {
        @AuraEnabled public String fieldApiName;
        @AuraEnabled public String placeholder;
        @AuraEnabled public String type;
        @AuraEnabled public Decimal order;
        @AuraEnabled public List<String> values;
    }
    /**
     * @description Fetches HAM_Filters__mdt field configuration.
     * Based on metadata configuration, fetches actual filter values whether it is a picklist value or custom values assigned in metadata.
     * @return List<FilterWrapper> - A list of filter configurations and their available options.
     **/
    @AuraEnabled(cacheable=true)
    public static List<FilterWrapper> getFilterMetadataAndValues() {
        List<HAM_Filters__mdt> filtersMetadata = [SELECT Id, HAM_Reference_Type__c, HAM_Reference_Object_API__c,
                                                 HAM_Reference_Field_API__c, HAM_Reference_Values__c,
                                                 HAM_Order__c, HAM_Placeholder__c
                                                 FROM HAM_Filters__mdt WITH SECURITY_ENFORCED ORDER BY HAM_Order__c];
        
        List<FilterWrapper> filterWrappers = new List<FilterWrapper>();
        
        for (HAM_Filters__mdt filterMdt : filtersMetadata) {
            FilterWrapper fw = new FilterWrapper();
            fw.fieldApiName = filterMdt.HAM_Reference_Field_API__c;
            fw.placeholder = filterMdt.HAM_Placeholder__c;
            fw.type = filterMdt.HAM_Reference_Type__c;
            fw.order = filterMdt.HAM_Order__c;
            fw.values = new List<String>();
            
            // 1. Check Helper First (Hybrid Approach)
            List<String> dynamicValues = HAM_AlumniFilterHelper.getDynamicValues(filterMdt.HAM_Placeholder__c);
            
            if (dynamicValues != null) {
                fw.values = dynamicValues; // Use dynamic DB values
            }
            // 2. Fallback to Metadata/Picklist
            else if (filterMdt.HAM_Reference_Type__c == 'Picklist') {
                fw.values = getPicklistValues(filterMdt.HAM_Reference_Object_API__c, filterMdt.HAM_Reference_Field_API__c);
            }
            // 3. Fallback to Metadata Values (Legacy)
            else if (String.isNotBlank(filterMdt.HAM_Reference_Values__c)) {
                fw.values.addAll(filterMdt.HAM_Reference_Values__c.split('[,;\\n]+'));
                for(Integer i = 0; i < fw.values.size(); i++) {
                    fw.values[i] = fw.values[i].trim();
                }
            }
            
            filterWrappers.add(fw);
        }
        return filterWrappers;
    }
	
    /**
     * @description Searches for dynamic filter options based on user input.
     * @param placeholder The name of the filter category.
     * @param searchTerm The user's typed search query.
     * @return List<String> matching filter options.
     */
    @AuraEnabled(cacheable=true)
    public static List<String> searchFilterOptions(String placeholder, String searchTerm) {
        try {
            if (String.isBlank(placeholder) || String.isBlank(searchTerm)) {
                return new List<String>();
            }
            // Delegate to Helper to keep Controller clean
            return HAM_AlumniFilterHelper.searchDynamicValues(placeholder, searchTerm);
        } catch (Exception e) {
            System.debug(LoggingLevel.error, 'Filter Search Error: ' + e.getMessage());
            return new List<String>();
        }
    }
    
    /**
     * @description Retrieves the picklist values for a given SObject and field API name.
     * @param sObjName The API name of the SObject (e.g., 'Contact').
     * @param fieldName The API name of the picklist field (e.g., 'Industry').
     * @return List<String> of picklist values. Returns an empty list if the SObject or field is invalid.
     */
    @TestVisible
    private static List<String> getPicklistValues(String sObjName, String fieldName) {
         List<String> values = new List<String>();
         try {
             Schema.SObjectType s = Schema.getGlobalDescribe().get(sObjName);
             Schema.DescribeSObjectResult r = s.getDescribe();
             Map<String,Schema.SObjectField> fields = r.fields.getMap();
             if(fields.containsKey(fieldName)) {
                 for(Schema.PicklistEntry p : fields.get(fieldName).getDescribe().getPicklistValues()) {
                     if(p.isActive()) {
                        values.add(p.getValue());
                     }
                 }
             }
         } catch(Exception e) { System.debug(LoggingLevel.error, 'Picklist Error: ' + e.getMessage()); }
         return values;
    }
    
        /**
     * @description Fetches the total constituent record number based on user search input.
     * @param tab The currently active tab in the directory UI.
     * @param searchKey String input in search bar from the user.
     * @param selectedFilters Selected filters on the UI (e.g., placeholder: Class Year, Value: 1979).
     * @param portalConstituentId The Contact Id of the logged-in user.
     * @return Integer - Number of records found in database.
     */
    @AuraEnabled(cacheable=true)
    public static Integer getDirectoryDataCount(String tab, String searchKey, List<Map<String, Object>> selectedFilters, Id portalConstituentId, String invitationSubTab, String bookmarkConnectionsFilter, String favoriteConnectionsFilter) {
        //CPD-OFF
        Boolean hasTab = !String.isBlank(tab); //hasTab == tab exists, !hasTab == tab does not exists
        Boolean hasSearch = !String.isBlank(searchKey);
        Boolean hasFilters = selectedFilters != null && !selectedFilters.isEmpty();
        Boolean isBuildTab = tab == HAM_ConstantsUtil.BUILD_TAB;
        Boolean isBlockedTab = tab == HAM_ConstantsUtil.BLOCKED_TAB;
        Id ServiceIndicatorRecordTypeId = Schema.SObjectType.ucinn_ascendv2__Service_Indicator__c.getRecordTypeInfosByName().get(HAM_ConstantsUtil.CONTACT_SERVICE_INDICATOR_RECORD_TYPE).getRecordTypeId();

        // WHERE clauses
        String baseConstituentWhere = System.Label.ham_AlumniDefaultFilter;
        String basePortalWhere = System.Label.ham_AlumniDefaultFilterPortal;
        String baseLinkedWhere = System.Label.ham_AlumniDefaultFilterLinked;

        //NO STUDENT CLAUSES
        String noStudentClause = System.label.Ham_No_Students;
        String noStudentOnLinkedUser = System.label.Ham_Linked_No_Student;
        String noStudentOnPortalUser = System.label.Ham_Portal_No_Student;

        String constituentWhere;
        String portalUserWhere;
        String linkedUserWhere;

        if (hasSearch || hasFilters) {
            constituentWhere = buildWhereClause(baseConstituentWhere, null, null, searchKey, selectedFilters);
            portalUserWhere = buildWhereClause(null, basePortalWhere, null, searchKey, selectedFilters);
            linkedUserWhere = buildWhereClause(null, null, baseLinkedWhere, searchKey, selectedFilters);
        } else {
            constituentWhere = baseConstituentWhere;
            portalUserWhere = basePortalWhere;
            linkedUserWhere = baseLinkedWhere;
        }

        //If filters are present, we store their placeholders. Later we check for record hiding based on this.
        Set<String> filterPlaceholders = new Set<String>();

        if(selectedFilters != null && !selectedFilters.isEmpty()){
            for (Map<String, Object> filter : selectedFilters) {
                if (filter.containsKey('placeholder') && filter.get('placeholder') != null) {
                    filterPlaceholders.add(String.valueOf(filter.get('placeholder')));
                }
            }
        }
        //CPD-ON
        //Getting the blocked profile IDs and All connection Ids
        //CPD-OFF
        set<Id> blockedProfileIds = new Set<Id>();
        set<Id> Allconnections = new Set<Id>();

        for(Contact con : [SELECT Id,
                        (SELECT HAM_Linked_Constituent__c,HAM_Is_Blocked__c FROM HAM_Connections__r),
                        (SELECT HAM_Portal_User__c,HAM_Is_Blocked__c FROM HAM_Connections1__r)
                        FROM Contact WHERE ID =: portalConstituentId]){

            if(!con.HAM_Connections__r.isEmpty()){
                for(HAM_Connection__C connection : con.HAM_Connections__r){
                    if(connection.HAM_Is_Blocked__c == true){
                        blockedProfileIds.add(connection.HAM_Linked_Constituent__c);
                    }else{
                        Allconnections.add(connection.HAM_Linked_Constituent__c);
                    }
                }
            }
            if(!con.HAM_Connections1__r.isEmpty()){
                for(HAM_Connection__C connection : con.HAM_Connections1__r){
                    if(connection.HAM_Is_Blocked__c == true){
                        blockedProfileIds.add(connection.HAM_Portal_User__c);
                    }else{
                        Allconnections.add(connection.HAM_Portal_User__c);
                    }
                }
            }
        }

         //Check for ALUMNI_PRIVACY (Hidden on directory)
        Set<Id> AlumniPrivacyIds = new Set<Id>();
        for (ucinn_ascendv2__Service_Indicator__c si : [SELECT ucinn_ascendv2__Contact__c,ucinn_ascendv2__Service_Indicator_Value__r.HAM_Portal_ID__c
                                                        FROM ucinn_ascendv2__Service_Indicator__c
                                                        WHERE RecordTypeId =: ServiceIndicatorRecordTypeId AND ucinn_ascendv2__Is_Active__c = true
                                                        AND ucinn_ascendv2__Service_Indicator_Value__r.HAM_Portal_ID__c = :HAM_ConstantsUtil.ALUMNI_PRIVCACY_SVID
                                                        ]) {
            AlumniPrivacyIds.add(si.ucinn_ascendv2__Contact__c);
        }
        //CPD-ON

        //This set is to store the records that match the service indicator with filter placeholders. We do this to skip records on search
        Set<Id> IdsMatchingFiltersAndIndicators  = new Set<Id>();

        Map<Id,List<String>> constituentServiceIndicatorsMap = new Map<Id,List<String>>();
        //CPD-OFF 
        if(!Allconnections.isEmpty()){
            for (ucinn_ascendv2__Service_Indicator__c si : [SELECT ucinn_ascendv2__Contact__c,ucinn_ascendv2__Service_Indicator_Value__r.HAM_Portal_ID__c
                                                            FROM ucinn_ascendv2__Service_Indicator__c
                                                            WHERE RecordTypeId =: ServiceIndicatorRecordTypeId AND
                                                            ucinn_ascendv2__Contact__c IN: Allconnections AND ucinn_ascendv2__Is_Active__c = true
                                                        ]) {
                                                                
                if(!constituentServiceIndicatorsMap.containsKey(si.ucinn_ascendv2__Contact__c)){
                    constituentServiceIndicatorsMap.put(si.ucinn_ascendv2__Contact__c,new List<String>{si.ucinn_ascendv2__Service_Indicator_Value__r.HAM_Portal_ID__c});
                }else{
                    constituentServiceIndicatorsMap.get(si.ucinn_ascendv2__Contact__c).add(si.ucinn_ascendv2__Service_Indicator_Value__r.HAM_Portal_ID__c);
                }
            }
        }
        //CPD-ON

        Map<String,String> IndicatorValueAndPlaceholderMap = new Map<String,String>();
         for (Ham_Service_Indicators__mdt ind : [SELECT Indicator_For_Field__c, Indicator_Value__c,Filter_Placeholder__c,Module__c FROM Ham_Service_Indicators__mdt
                                                WHERE (Module__c = 'Directory' OR Module__c = 'Connection - Primary' OR Module__c = 'Connection - Secondary')
                                                AND Is_Active__c = true]) {
        
            IndicatorValueAndPlaceholderMap.put(ind.Indicator_Value__c,ind.Filter_Placeholder__c);

        }

        for(Id conId : constituentServiceIndicatorsMap.keySet()){
            for(String IndicatorValue : constituentServiceIndicatorsMap.get(conId)){
                if(filterPlaceholders.contains(IndicatorValueAndPlaceholderMap.get(IndicatorValue))){
                    IdsMatchingFiltersAndIndicators.add(conId);
                    break;
                }
            }
        }

        Integer constituentsCount = 0;
        Integer primaryConnectionsCount = 0;
        Integer secondaryConnectionsCount = 0;

        String flagsPerTabOnPrimary;
        String flagsPerTabOnSecondary;

        //flagsPerTabOnPrimary and flagsPerTabOnSecondary are the strings we concatenate with the connections soql. This is to get the data based on the tab.
        if (!String.isBlank(tab)) {
            if (tab == HAM_ConstantsUtil.CONNECTION_TAB) {
                flagsPerTabOnPrimary = favoriteConnectionsFilter == 'true'
                    ? 'AND HAM_Is_Connected__c = true AND HAM_Is_favorite__c = true '
                    : 'AND HAM_Is_Connected__c = true ';
                flagsPerTabOnSecondary = '';
            }
            else if (tab == HAM_ConstantsUtil.BOOKMARK_TAB) {
                flagsPerTabOnPrimary = bookmarkConnectionsFilter == 'true'
                    ? 'AND HAM_Is_bookmarked__c = true AND HAM_Is_Connected__c = true '
                    : 'AND HAM_Is_bookmarked__c = true ';
                flagsPerTabOnSecondary = '';
            }
            else if (tab == HAM_ConstantsUtil.INVITATION_TAB) {
                if (invitationSubTab == 'Sent') {
                    flagsPerTabOnPrimary = 'AND HAM_Connection_Status__c = \'Request Sent\' ';
                    flagsPerTabOnSecondary = '';
                } else {
                    flagsPerTabOnPrimary = '';
                    flagsPerTabOnSecondary = 'AND HAM_Connection_Status__c = \'Request Sent\' AND';
                }
            }else{
                flagsPerTabOnPrimary = '';
                flagsPerTabOnSecondary = '';
            }
        }

        if ((!hasTab || isBuildTab) && (String.isNotBlank(searchKey) || !selectedFilters.isEmpty())) {

            //Constituents
            String constituentQuery =
            'SELECT Count() FROM Contact WHERE'+
            ' ID NOT IN :blockedProfileIds'+
            ' AND ID NOT IN :IdsMatchingFiltersAndIndicators'+
            ' AND Id NOT IN :AlumniPrivacyIds AND '+constituentWhere;

            //NO STUDENT CLAUSE. ONLY FOR 'SEARCH DIRECTORY TAB'
            if(isBuildTab){
                constituentQuery += ' AND '+noStudentClause;
            }

            //System.debug('>>> constituent count Query: ' + constituentQuery);

            try{
                constituentsCount = Database.countQuery(constituentQuery);
            }catch(exception ex){
                System.debug(LoggingLevel.error, 'Constituents Count Query Error: ' + ex.getMessage());
                return constituentsCount;
            }
        }

        //Primary Connections
        String primaryConnectionsQuery =
        'SELECT COUNT() FROM HAM_Connection__c WHERE '+linkedUserWhere+' '+flagsPerTabOnPrimary+
        ' AND HAM_Linked_Constituent__c NOT IN :IdsMatchingFiltersAndIndicators' +
        ' AND HAM_Linked_Constituent__c NOT IN :AlumniPrivacyIds';

        //NO STUDENT CLAUSE. ONLY FOR 'SEARCH DIRECTORY TAB'
        if(isBuildTab){
            primaryConnectionsQuery += ' AND '+noStudentOnLinkedUser;
        }

        if(isBlockedTab){
            primaryConnectionsQuery += ' AND HAM_Is_Blocked__c = TRUE AND HAM_Linked_Constituent__c IN :blockedProfileIds';
        } else {
            primaryConnectionsQuery += ' AND HAM_Is_Blocked__c = FALSE AND HAM_Linked_Constituent__c NOT IN :blockedProfileIds';
        }

        //System.debug('>>> primaryConnections count Query: ' + primaryConnectionsQuery);

         try{
            primaryConnectionsCount = Database.countQuery(primaryConnectionsQuery);
        }catch(exception ex){
            System.debug(LoggingLevel.error, 'Primary connections Count Query Error: ' + ex.getMessage());
            return primaryConnectionsCount;
        }
        //Secondary Connections
        String secondaryConnectionsQuery =
        'SELECT COUNT() FROM HAM_Connection__c WHERE '+portalUserWhere+' '+flagsPerTabOnSecondary+
        ' AND HAM_Portal_User__c NOT IN :IdsMatchingFiltersAndIndicators' +
        ' AND HAM_Portal_User__c NOT IN :AlumniPrivacyIds';

        //NO STUDENT CLAUSE. ONLY FOR 'SEARCH DIRECTORY TAB'
        if(isBuildTab){
            secondaryConnectionsQuery += ' AND '+noStudentOnPortalUser;
        }

        if(isBlockedTab){
            secondaryConnectionsQuery += ' AND HAM_Is_Blocked__c = TRUE AND HAM_Portal_User__c IN :blockedProfileIds';
        }else{
            secondaryConnectionsQuery += ' AND HAM_Is_Blocked__c = FALSE AND HAM_Portal_User__c NOT IN :blockedProfileIds';
        }

        //System.debug('>>> secondaryConnections count Query: ' + secondaryConnectionsQuery);

         try{
            if(isBlockedTab == false){
                secondaryConnectionsCount = Database.countQuery(secondaryConnectionsQuery);
            }
        }catch(exception ex){
            System.debug(LoggingLevel.error, 'Primary connections Count Query Error: ' + ex.getMessage());
            return secondaryConnectionsCount;
        }

        if(tab == HAM_ConstantsUtil.BUILD_TAB){
            return constituentsCount;
        }else if(tab == HAM_ConstantsUtil.INVITATION_TAB){
            return invitationSubTab == 'Sent' ? primaryConnectionsCount : secondaryConnectionsCount;
        }
        else{
            return primaryConnectionsCount;
        }
           
    }
    
	/**
     * @description Wrapper class containing the entire structure returned for Directory Data.
     */
    public class DirectoryResponse {
        @AuraEnabled public List<ConstituentWrapper> constituentsData;
        @AuraEnabled public ConnectionsData connectionsData;
        @AuraEnabled public List<ConnectionWrapper> sentRequests;
        @AuraEnabled public Boolean protalLogedUserPrivacy;
    }
	
    /**
     * @description Wrapper class for separating primary and secondary connections.
     */
    public class ConnectionsData {
        @AuraEnabled public List<ConnectionWrapper> primaryConnections;
        @AuraEnabled public List<ConnectionWrapper> secondaryConnections;
    }
	
    /**
     * @description Wrapper class for individual Constituent contact records.
     */
    public class ConstituentWrapper {
        @AuraEnabled public Id id;
        @AuraEnabled public Map<String, Object> header = new Map<String, Object>();
        @AuraEnabled public Map<String, Object> flags  = new Map<String, Object>();
        @AuraEnabled public List<FieldItems> fields = new List<FieldItems>();
    }
	
    /**
     * @description Wrapper class for connection-specific records.
     */
    public class ConnectionWrapper {
        @AuraEnabled public Id linkedUserId;
        @AuraEnabled public Id portalUserId;
        @AuraEnabled public Date rejectedDate;
        @AuraEnabled public String status;
        @AuraEnabled public String connectionMessage;
        @AuraEnabled public Map<String, Object> header = new Map<String, Object>();
        @AuraEnabled public Map<String, Object> flags  = new Map<String, Object>();
        @AuraEnabled public List<FieldItems> fields = new List<FieldItems>();
    }
	
    /**
     * @description Generic wrapper for displaying key-value field data in the UI.
     */
    public class FieldItems {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
    }

    /**
     * @description Wrapper for returning a portal user's default filter data (class year, current chapters, and major).
     */
    public class ContactDefaultFilterData {
        @AuraEnabled public String classYear;
        @AuraEnabled public List<String> currentChapters;
        @AuraEnabled public List<String> majorValues;
    }

	/**
     * @description Fetches all constituent records and connections based on user search input and active tab.
     * @param tab Currently active UI tab.
     * @param pageSize Number of records to be displayed at a time.
     * @param recordsToSkip Offset to skip records (e.g., On page-1 skip 0, page-2 skip 9).
     * @param searchKey String input in search bar from the user.
     * @param selectedFilters List of maps containing selected filters from the UI.
     * @param portalConstituentId Contact Id of the logged in portal user.
     * @return DirectoryResponse - Wrapper containing categorized constituent and connection data.
     */
    @AuraEnabled(cacheable=true)
    public static DirectoryResponse getDirectoryData(String tab,Integer pageSize,Integer recordsToSkip,String searchKey,
                                                    List<Map<String, Object>> selectedFilters,Id portalConstituentId, String invitationSubTab,
                                                    String bookmarkConnectionsFilter, String favoriteConnectionsFilter) {
                                                        
        portalUserId = portalConstituentId;
                                                                                              
        DirectoryResponse response = new DirectoryResponse();
        response.constituentsData = new List<ConstituentWrapper>();
        response.connectionsData = new ConnectionsData();
        response.connectionsData.primaryConnections = new List<ConnectionWrapper>();
        response.sentRequests = new List<ConnectionWrapper>();
        response.connectionsData.secondaryConnections = new List<ConnectionWrapper>();
    
        Boolean hasTab = !String.isBlank(tab); //hasTab == tab exists, !hasTab == tab does not exists
        Boolean hasSearch = !String.isBlank(searchKey);
        Boolean hasFilters = selectedFilters != null && !selectedFilters.isEmpty();
        Boolean isBuildTab = tab == HAM_ConstantsUtil.BUILD_TAB;
        Boolean isBlockedTab = tab == HAM_ConstantsUtil.BLOCKED_TAB;
        Id ServiceIndicatorRecordTypeId = Schema.SObjectType.ucinn_ascendv2__Service_Indicator__c.getRecordTypeInfosByName().get(HAM_ConstantsUtil.CONTACT_SERVICE_INDICATOR_RECORD_TYPE).getRecordTypeId();
    
        // WHERE clauses
        String baseConstituentWhere = System.Label.ham_AlumniDefaultFilter;
        String basePortalWhere = System.Label.ham_AlumniDefaultFilterPortal;
        String baseLinkedWhere = System.Label.ham_AlumniDefaultFilterLinked;

        //NO STUDENT CLAUSES
        String noStudentClause = System.label.Ham_No_Students;
        String noStudentOnLinkedUser = System.label.Ham_Linked_No_Student;
        String noStudentOnPortalUser = System.label.Ham_Portal_No_Student;
    
        String constituentWhere;
        String portalUserWhere;
        String linkedUserWhere;
    
        if (hasSearch || hasFilters) {
            constituentWhere = buildWhereClause(baseConstituentWhere, null, null, searchKey, selectedFilters);
            portalUserWhere = buildWhereClause(null, basePortalWhere, null, searchKey, selectedFilters);
            linkedUserWhere = buildWhereClause(null, null, baseLinkedWhere, searchKey, selectedFilters);
        } else {
            constituentWhere = baseConstituentWhere;
            portalUserWhere = basePortalWhere;
            linkedUserWhere = baseLinkedWhere;
        }
    
        //If filters are present, we store their placeholders. Later we use this to skip records based on indicators
        Set<String> filterPlaceholders = new Set<String>();
    
        if(selectedFilters != null && !selectedFilters.isEmpty()){
        for (Map<String, Object> filter : selectedFilters) {
            if (filter.containsKey('placeholder') && filter.get('placeholder') != null) {
                filterPlaceholders.add(String.valueOf(filter.get('placeholder')));
            }
        }}
    
        //Get fields from metadata to prepare dynamic soql for both  constituents and connections data
        List<String> selectedFieldsForConstituents = new List<String>{'Id'};
        List<String> selectedFieldsForPrimaryConnections = new List<String>{'Id'};
        List<String> selectedFieldsForSecondaryConnections = new List<String>{'Id'};
    
        //Getting Metdata fields
        List<HAM_Meta_Data__mdt> directoryMeta = [SELECT HAM_Field_API__c, HAM_Display_Label__c, HAM_Level_2__c, HAM_Field_Type__c
                                                    FROM HAM_Meta_Data__mdt WHERE HAM_Level_1__c = 'Directory' ORDER BY HAM_Order__c];
        //storing field APIs to later build query
        for (HAM_Meta_Data__mdt meta : directoryMeta) {
            if(meta.HAM_Field_API__c != null){
                selectedFieldsForConstituents.add(meta.HAM_Field_API__c);
            }
        }
    
        //Getting Metdata fields
        List<HAM_Meta_Data__mdt> primaryConnectionMeta = new List<HAM_Meta_Data__mdt>();
        List<HAM_Meta_Data__mdt> secondaryConnectionMeta = new List<HAM_Meta_Data__mdt>();
        
        //storing field APIs to later build query
        for (HAM_Meta_Data__mdt meta : [SELECT HAM_Field_API__c, HAM_Display_Label__c, HAM_Level_2__c, HAM_Field_Type__c
                                                    FROM HAM_Meta_Data__mdt WHERE HAM_Level_1__c = 'Connection' ORDER BY HAM_Order__c]) {
            if(meta.HAM_Field_API__c != null && meta.HAM_Field_API__c.contains(HAM_ConstantsUtil.LINKED_USER)){
                selectedFieldsForPrimaryConnections.add(meta.HAM_Field_API__c);
                primaryConnectionMeta.add(meta);
            }else if(meta.HAM_Field_API__c != null && meta.HAM_Field_API__c.contains(HAM_ConstantsUtil.PORTAL_USER)){
                selectedFieldsForSecondaryConnections.add(meta.HAM_Field_API__c);
                secondaryConnectionMeta.add(meta);
            }else{
                if(!meta.HAM_Display_Label__c.contains(HAM_ConstantsUtil.DEGREE)){
                    selectedFieldsForPrimaryConnections.add(meta.HAM_Field_API__c);
                    selectedFieldsForSecondaryConnections.add(meta.HAM_Field_API__c);
                }
                primaryConnectionMeta.add(meta);
                secondaryConnectionMeta.add(meta);
            }
            
        }
    
        //Getting the blocked profile IDs and All connection Ids
        set<Id> blockedProfileIds = new Set<Id>();
        set<Id> Allconnections = new Set<Id>();
    
        for(Contact con : [SELECT Id,
                          (SELECT HAM_Linked_Constituent__c,HAM_Is_Blocked__c FROM HAM_Connections__r),
                          (SELECT HAM_Portal_User__c,HAM_Is_Blocked__c FROM HAM_Connections1__r)
                          FROM Contact WHERE ID =: portalConstituentId]){
    
            if(!con.HAM_Connections__r.isEmpty()){
                for(HAM_Connection__C connection : con.HAM_Connections__r){
                    if(connection.HAM_Is_Blocked__c == true){
                        blockedProfileIds.add(connection.HAM_Linked_Constituent__c);
                    }else{
                        Allconnections.add(connection.HAM_Linked_Constituent__c);
                    }
                }
            }
            if(!con.HAM_Connections1__r.isEmpty()){
                for(HAM_Connection__C connection : con.HAM_Connections1__r){
                    if(connection.HAM_Is_Blocked__c == true){
                        blockedProfileIds.add(connection.HAM_Portal_User__c);
                    }else{
                        Allconnections.add(connection.HAM_Portal_User__c);
                    }
                }
            }
        }
    
        //Service indicators setup
    
        //Check for ALUMNI_PRIVACY (Hidden on directory) and CONNECTION_PRIVACY (Disable send request button)
        Set<Id> AlumniPrivacyIds = new Set<Id>();
        Set<Id> ConnectionPrivacyIds = new Set<Id>();

         for (ucinn_ascendv2__Service_Indicator__c si : [SELECT ucinn_ascendv2__Contact__c,ucinn_ascendv2__Service_Indicator_Value__r.HAM_Portal_ID__c
                                                         FROM ucinn_ascendv2__Service_Indicator__c
                                                         WHERE RecordTypeId =: ServiceIndicatorRecordTypeId AND ucinn_ascendv2__Is_Active__c = true
                                                         AND 
                                                         (ucinn_ascendv2__Service_Indicator_Value__r.HAM_Portal_ID__c = :HAM_ConstantsUtil.ALUMNI_PRIVCACY_SVID
                                                         OR 
                                                         ucinn_ascendv2__Service_Indicator_Value__r.HAM_Portal_ID__c = :HAM_ConstantsUtil.CONNECTION_PRIVCACY_SVID)
                                                        ]) {
            if(si.ucinn_ascendv2__Service_Indicator_Value__r.HAM_Portal_ID__c == HAM_ConstantsUtil.ALUMNI_PRIVCACY_SVID){
                AlumniPrivacyIds.add(si.ucinn_ascendv2__Contact__c);
            }
            if(si.ucinn_ascendv2__Service_Indicator_Value__r.HAM_Portal_ID__c == HAM_ConstantsUtil.CONNECTION_PRIVCACY_SVID){
                ConnectionPrivacyIds.add(si.ucinn_ascendv2__Contact__c);
            }
            
        }

        // Set logged-in portal user's connection-privacy flag (works across all tabs/scenarios)
        response.protalLogedUserPrivacy = ConnectionPrivacyIds.contains(portalConstituentId);
    
        //These maps are for service indicators for a specific field to be hidden. These are segregated into 3 based on 3 different API names of fields we need
        //ServiceIndicatorMap - this is for constituents
        //primaryConnectionServiceIndicatorMap - this is for primary connections
        //secondaryConnectionServiceIndicatorMap - this is for secondary connections
        Map<String, String> ServiceIndicatorMap = new Map<String, String>();
        Map<String, String> primaryConnectionServiceIndicatorMap = new Map<String, String>();
        Map<String, String> secondaryConnectionServiceIndicatorMap = new Map<String, String>();
    
        //This map is used to check and exclude the contact records based on the appled filters
        Map<string,string> IndicatorValueAndPlaceholderMap = new Map<String,String>();
    
        //This set is to store the records that match the service indicator with filter placeholders. We do this to skip records on search
        Set<Id> IdsMatchingFiltersAndIndicators  = new Set<Id>();
                
        for (Ham_Service_Indicators__mdt ind : [SELECT Indicator_For_Field__c, Indicator_Value__c,Filter_Placeholder__c,Module__c FROM Ham_Service_Indicators__mdt
                                                WHERE (Module__c = 'Directory' OR Module__c = 'Connection - Primary' OR Module__c = 'Connection - Secondary')
                                                AND Is_Active__c = true]) {
            
            IndicatorValueAndPlaceholderMap.put(ind.Indicator_Value__c,ind.Filter_Placeholder__c);
    
            if(ind.Module__c == HAM_ConstantsUtil.SI_DIRECTORY){
                ServiceIndicatorMap.put(ind.Indicator_For_Field__c,ind.Indicator_Value__c);
            }else if(ind.Module__c == HAM_ConstantsUtil.SI_PRIMARY_CON){
                primaryConnectionServiceIndicatorMap.put(ind.Indicator_For_Field__c,ind.Indicator_Value__c);
            }else if(ind.Module__c == HAM_ConstantsUtil.SI_SECONDARY_CON){
                secondaryConnectionServiceIndicatorMap.put(ind.Indicator_For_Field__c,ind.Indicator_Value__c);
            }
        }
    
        Map<Id,List<String>> constituentServiceIndicatorsMap = new Map<Id,List<String>>();
                
        if(!Allconnections.isEmpty()){
            for (ucinn_ascendv2__Service_Indicator__c si : [SELECT ucinn_ascendv2__Contact__c,ucinn_ascendv2__Service_Indicator_Value__r.HAM_Portal_ID__c
                                                            FROM ucinn_ascendv2__Service_Indicator__c
                                                            WHERE RecordTypeId =: ServiceIndicatorRecordTypeId AND
                                                            ucinn_ascendv2__Contact__c IN: Allconnections AND ucinn_ascendv2__Is_Active__c = true
                                                           ]) {
                                                                
                if(!constituentServiceIndicatorsMap.containsKey(si.ucinn_ascendv2__Contact__c)){
                    constituentServiceIndicatorsMap.put(si.ucinn_ascendv2__Contact__c,new List<String>{si.ucinn_ascendv2__Service_Indicator_Value__r.HAM_Portal_ID__c});
                }else{
                    constituentServiceIndicatorsMap.get(si.ucinn_ascendv2__Contact__c).add(si.ucinn_ascendv2__Service_Indicator_Value__r.HAM_Portal_ID__c);
                }
            }
        }
    
        for(Id conId : constituentServiceIndicatorsMap.keySet()){
            for(String IndicatorValue : constituentServiceIndicatorsMap.get(conId)){
                if(filterPlaceholders.contains(IndicatorValueAndPlaceholderMap.get(IndicatorValue))){
                    IdsMatchingFiltersAndIndicators.add(conId);
                    break;
                }
            }
        }
    
        //Get degrees for all sorted records
        Map<Id, Set<String>> degreeMap = new Map<Id, Set<String>>();
    
        if (!Allconnections.isEmpty()) {
    
            for (ucinn_ascendv2__Degree_Information__c deg : [SELECT ucinn_ascendv2__Contact__c,ucinn_ascendv2__Major_Formula__c,ucinn_ascendv2__Second_Major_Formula__c,
                                                              Third_Concentration_Formula__c FROM ucinn_ascendv2__Degree_Information__c
                                                              WHERE ucinn_ascendv2__Contact__c IN :Allconnections]) {
                //CPD-OFF
                Set<String> degreeList = degreeMap.get(deg.ucinn_ascendv2__Contact__c);
    
                if (degreeList == null) {
                    degreeList = new Set<String>();
                    degreeMap.put(deg.ucinn_ascendv2__Contact__c, degreeList);
                }
    
                if (!String.isBlank(deg.ucinn_ascendv2__Major_Formula__c)){
                    degreeList.add(deg.ucinn_ascendv2__Major_Formula__c);
                }
    
                if (!String.isBlank(deg.ucinn_ascendv2__Second_Major_Formula__c)){
                    degreeList.add(deg.ucinn_ascendv2__Second_Major_Formula__c);
                }
    
                if (!String.isBlank(deg.Third_Concentration_Formula__c)){
                    degreeList.add(deg.Third_Concentration_Formula__c);
                }
    
            }
            //CPD-ON
        }
        
        //Constituents
        //hasTab == tab exists, !hasTab == tab does not exists
    
        List<Contact> Constituents = new List<Contact>();
        Set<Id> constituentIds = new Set<Id>();
    
        if ((!hasTab || isBuildTab) && (String.isNotBlank(searchKey) || (selectedFilters != null && !selectedFilters.isEmpty()))) {
    
            String constituentQuery =
                'SELECT ' + String.join(selectedFieldsForConstituents, ', ') +
                ' FROM Contact WHERE '+constituentWhere+
                ' AND ID NOT IN :blockedProfileIds' +
                ' AND ID NOT IN :IdsMatchingFiltersAndIndicators' +
                ' AND ID NOT IN :AlumniPrivacyIds';
            
            //NO STUDENT CLAUSE. ONLY FOR 'SEARCH DIRECTORY' TAB
            if(isBuildTab){
                constituentQuery += ' AND '+noStudentClause;
            }
    
            //recordsToSkip == 0, which is page 1
            if(recordsToSkip != null && recordsToSkip == 0){
    
                constituentQuery += ' ORDER BY Name ASC LIMIT : pageSize';
    
            }else if(recordsToSkip != null && recordsToSkip > 0) {
    
                String lastRecordName;
    
                String consQuery =
                'SELECT ' + String.join(selectedFieldsForConstituents, ', ') +
                ' FROM Contact WHERE ' + constituentWhere+
                ' AND ID != :portalConstituentId' +
                ' AND ID NOT IN :blockedProfileIds' +
                ' AND ID NOT IN :AlumniPrivacyIds';

                //NO STUDENT CLAUSE. ONLY FOR 'SEARCH DIRECTORY' TAB
                if(isBuildTab){
                    consQuery += ' AND '+noStudentClause;
                }

                consQuery += ' ORDER BY Name ASC LIMIT '+ recordsToSkip;

                //System.debug('>>> consQuery: ' + consQuery);
    
                List<Contact> lstContact = Database.query(consQuery);
                lastRecordName = (lstContact != null && !lstContact.isEmpty()) ? lstContact[lstContact.size() - 1].Name : null;
                constituentQuery = (lastRecordName != null) ? (constituentQuery  + ' AND Name > : lastRecordName  ORDER BY Name ASC LIMIT : pageSize') : constituentQuery;
    
            }

          //System.debug('>>> constituentQuery: ' + constituentQuery);
    
            try{
                Constituents = Database.query(constituentQuery);
                if(!Constituents.isEmpty()){
                    for(Contact con : Constituents){
                        constituentIds.add(con.Id);
                    }
                }
            }catch(exception ex){
                System.debug(LoggingLevel.error, 'Constituents Query Error: ' + ex.getMessage());
                return new DirectoryResponse();
            }
        
            if(!Constituents.isEmpty()){
                if (!constituentIds.isEmpty()) {
                     for (ucinn_ascendv2__Degree_Information__c deg : [SELECT ucinn_ascendv2__Contact__c,ucinn_ascendv2__Major_Formula__c,ucinn_ascendv2__Second_Major_Formula__c,
                                                              Third_Concentration_Formula__c FROM ucinn_ascendv2__Degree_Information__c
                                                              WHERE ucinn_ascendv2__Contact__c IN :constituentIds]) {
    
                        Set<String> degreeList = degreeMap.get(deg.ucinn_ascendv2__Contact__c);
    
                        if (degreeList == null) {
                            degreeList = new Set<String>();
                            degreeMap.put(deg.ucinn_ascendv2__Contact__c, degreeList);
                        }
    
                        if (!String.isBlank(deg.ucinn_ascendv2__Major_Formula__c)){
                            degreeList.add(deg.ucinn_ascendv2__Major_Formula__c);
                        }
    
                        if (!String.isBlank(deg.ucinn_ascendv2__Second_Major_Formula__c)){
                            degreeList.add(deg.ucinn_ascendv2__Second_Major_Formula__c);
                        }
    
                        if (!String.isBlank(deg.Third_Concentration_Formula__c)){
                            degreeList.add(deg.Third_Concentration_Formula__c);
                        }
    
                    }
                }
    
                for (Contact con : Constituents) {
    
                    ConstituentWrapper cw = new ConstituentWrapper();
                    cw.id = con.Id;

                    //Connection privacy check (disable/hide 'Send Connection' button)
                    Boolean ConnectionPrivacyEnabled = ConnectionPrivacyIds.contains(con.Id) ? true : false;
                    cw.header.put('connectionPrivacyEnabled', ConnectionPrivacyEnabled);
                    
                    //skip fields based on service indicators
                    Set<String> ConstituentskippedFields = new Set<String>();
                    if (constituentServiceIndicatorsMap.containsKey(con.Id)) {
                        for (String fieldApi : ServiceIndicatorMap.keySet()) {
                            if (constituentServiceIndicatorsMap.get(con.Id).contains(ServiceIndicatorMap.get(fieldApi))) {
                                ConstituentskippedFields.add(fieldApi);
                            }
                        }
                    }
    
                    for (HAM_Meta_Data__mdt meta : directoryMeta) {
    
                        // check for skipped field
                        Boolean conFieldisSkipped = ConstituentskippedFields.contains(meta.HAM_Field_API__c);
                        
                        String valueInDirectory = '';
                        if (!conFieldisSkipped) {
                            valueInDirectory = resolveFieldValue(con, meta.HAM_Field_API__c, meta.HAM_Display_Label__c, degreeMap);
                        }
                        
                        // Header Fields = Name , profile Photo , Kirkland Alumnae
                        if (meta.HAM_Level_2__c == 'Header') {
                            if(meta.HAM_Display_Label__c == HAM_ConstantsUtil.KIRKLAND_ALUMNAE){
                                Boolean isKirklandAlumnae = con.ucinn_ascendv2__Contact_Type__c != null &&
                                                            con.ucinn_ascendv2__Contact_Type__c.contains(HAM_ConstantsUtil.KIRKLAND_ALUMNAE);
                                cw.header.put('isKirklandAlumnae', isKirklandAlumnae);
                            }else if(meta.HAM_Display_Label__c == HAM_ConstantsUtil.DECEASED_ALUMNAE){
                                cw.header.put('isDeseasedAlumnae', Boolean.valueOf(valueInDirectory));
                            }else{
                                cw.header.put(meta.HAM_Display_Label__c, valueInDirectory);
                                continue;
                            }
                        }
                        
                        // FIELDS => Rest of the fields Degree, Graduation Year, Industry
                        if (meta.HAM_Level_2__c == 'Fields' && meta.HAM_Field_Type__c == 'Replaceable') {
                            
                            FieldItems item = new FieldItems();
                            item.label = meta.HAM_Display_Label__c;
                            //item.value = value != null ? value : '-';
                            if (String.isBlank(valueInDirectory)) {
                                item.value = '-';
                            } else {
                                item.value = valueInDirectory;
                            }
                            cw.fields.add(item);
                        }
                    }
    
                    response.constituentsData.add(cw);
                }
            }
        }
       
        //CONNECTIONS
         String primaryConnectionsQuery;
         String secondaryConnectionsQuery;
         List<HAM_Connection__c> primaryConnections;
         List<HAM_Connection__c> secondaryConnections;
         String flagsPerTabOnPrimary;
         String flagsPerTabOnSecondary;
    
         //flagsPerTabOnPrimary and flagsPerTabOnSecondary are the strings we concatenate with the connections soql. This is to get the data based on the tab.
         if (!String.isBlank(tab)) {
            if (tab == HAM_ConstantsUtil.CONNECTION_TAB) {
                flagsPerTabOnPrimary = favoriteConnectionsFilter == 'true'
                    ? 'AND HAM_Is_Connected__c = true AND HAM_Is_favorite__c = true '
                    : 'AND HAM_Is_Connected__c = true ';
                flagsPerTabOnSecondary = '';
            }
            else if (tab == HAM_ConstantsUtil.BOOKMARK_TAB) {
                flagsPerTabOnPrimary = bookmarkConnectionsFilter == 'true'
                    ? 'AND HAM_Is_bookmarked__c = true AND HAM_Is_Connected__c = true '
                    : 'AND HAM_Is_bookmarked__c = true ';
                flagsPerTabOnSecondary = '';
            }
            else if (tab == HAM_ConstantsUtil.INVITATION_TAB) {
                flagsPerTabOnPrimary = '';
                flagsPerTabOnSecondary = 'AND HAM_Connection_Status__c = \'Request Sent\' ';
            }
            else{
                flagsPerTabOnPrimary = '';
                flagsPerTabOnSecondary = '';
            }
        }
    
        //On 'Build Your Alumni tab', the constituent records are shown first and later/in the next pages the connections are shown.
        //Max records on a page is 9 (list/grid).Hence defaulting values. we chnage this later on per logic.
    
        integer primaryConnectionsToFetch;
        integer secondaryConnectionsToFetch;
    
        if(tab == HAM_ConstantsUtil.CONNECTION_TAB || tab == HAM_ConstantsUtil.BOOKMARK_TAB || Constituents.isEmpty()){
            primaryConnectionsToFetch = 9;
        }else if(tab == HAM_ConstantsUtil.INVITATION_TAB){
            secondaryConnectionsToFetch = 9;
        }
    
        if(!Constituents.isEmpty()){
            // Max records on a page is 9 (list/grid).
            // So first place is taken by constituents, next comes the primary connections. Later, we give space to secondary connections.
            // Hence to know the space remaining for primary connections, we are substracting with Constituents.size()
    
            integer no_OfConstituents = Constituents.size();
            
            if (no_OfConstituents < 9) {
                primaryConnectionsToFetch = 9 - no_OfConstituents;
            }else{
                primaryConnectionsToFetch = 0;
            }
        }
    
        //Handling primary and secondary connections individually. That we way we control the no.of records fetched and have appropriate pagination logic
    
        //Primary = HAM_Connections__r (logged in user is poratl user)
        //we get the primary records based on 2 parameters
        // 1) primaryConnectionsKeyset, this contains the last primary connection record name from our previous page. we use this as keyset to get next set of records
        // 2) primaryConnectionsToFetch, this is the parameter that tells us how many records can we fit in after the constituents have taken the place
    
        //HAM_Portal_User__c = :portalConstituentId is already included in the query
        //
        
        if (tab == HAM_ConstantsUtil.INVITATION_TAB) {

            if (invitationSubTab == 'Sent') {

                // ============================================================
                // INVITATION TAB — SENT: connections where I am the initiator
                // I am HAM_Portal_User__c (sender); recipient is HAM_Linked_Constituent__c
                // Use primaryConnectionMeta to display recipient's (HAM_Linked_Constituent__r) data
                // ============================================================

                String sentQuery =
                    'SELECT ' + String.join(selectedFieldsForPrimaryConnections, ', ') +
                    ', HAM_Linked_Constituent__c, HAM_Rejected_Date__c, HAM_Connection_Message__c, HAM_Connection_Status__c,' +
                    'HAM_Portal_User__c, CreatedDate ' +
                    'FROM HAM_Connection__c ' +
                    'WHERE ' + linkedUserWhere +
                    ' AND HAM_Connection_Status__c = \'Request Sent\'' +
                    ' AND HAM_Linked_Constituent__c NOT IN :IdsMatchingFiltersAndIndicators' +
                    ' AND HAM_Linked_Constituent__c NOT IN :AlumniPrivacyIds' +
                    ' AND HAM_Is_Blocked__c = FALSE' +
                    ' AND HAM_Linked_Constituent__c NOT IN :blockedProfileIds';

                Datetime lastSentCreatedDate;

                if (recordsToSkip != null && recordsToSkip == 0) {
                    sentQuery += ' ORDER BY CreatedDate DESC LIMIT :pageSize';
                } else if (recordsToSkip != null && recordsToSkip > 0) {
                    String sentSkipQuery = sentQuery + ' ORDER BY CreatedDate DESC LIMIT ' + recordsToSkip;
                    List<HAM_Connection__c> lstSent = Database.query(sentSkipQuery);
                    if (lstSent != null && !lstSent.isEmpty()) {
                        lastSentCreatedDate = lstSent[lstSent.size() - 1].CreatedDate;
                    }
                    if (lastSentCreatedDate != null) {
                        sentQuery += ' AND CreatedDate < :lastSentCreatedDate ORDER BY CreatedDate DESC LIMIT :pageSize';
                    } else {
                        sentQuery += ' ORDER BY CreatedDate DESC LIMIT :pageSize';
                    }
                }

                List<HAM_Connection__c> sentConnections = new List<HAM_Connection__c>();
                try {
                    sentConnections = Database.query(sentQuery);
                } catch (Exception ex) {
                    System.debug(LoggingLevel.error, 'Sent invitations Query Error: ' + ex.getMessage());
                    return new DirectoryResponse();
                }

                for (HAM_Connection__c sentConn : sentConnections) {
                    ConnectionWrapper scnw = new ConnectionWrapper();
                    scnw.linkedUserId = sentConn.HAM_Linked_Constituent__c;
                    scnw.portalUserId = sentConn.HAM_Portal_User__c;
                    scnw.status = sentConn.HAM_Connection_Status__c;
                    scnw.rejectedDate = sentConn.HAM_Rejected_Date__c;
                    scnw.connectionMessage = HAM_NotificationService.stripHTML(sentConn.HAM_Connection_Message__c);

                    Set<String> skippedFields = new Set<String>();
                    if (constituentServiceIndicatorsMap.containsKey(sentConn.HAM_Linked_Constituent__c)) {
                        for (String fieldApi : primaryConnectionServiceIndicatorMap.keySet()) {
                            if (constituentServiceIndicatorsMap.get(sentConn.HAM_Linked_Constituent__c).contains(primaryConnectionServiceIndicatorMap.get(fieldApi))) {
                                skippedFields.add(fieldApi);
                            }
                        }
                    }

                    for (HAM_Meta_Data__mdt meta : primaryConnectionMeta) {
                        Boolean isSkipped = skippedFields.contains(meta.HAM_Field_API__c);
                        String fieldValue = '';
                        if (!isSkipped) {
                            fieldValue = resolveFieldValue(sentConn, meta.HAM_Field_API__c, meta.HAM_Display_Label__c, degreeMap);
                        }
                        if (meta.HAM_Level_2__c == 'Header') {
                            if (meta.HAM_Display_Label__c == HAM_ConstantsUtil.KIRKLAND_ALUMNAE) {
                                Boolean isKirkland = sentConn.HAM_Linked_Constituent__r.ucinn_ascendv2__Contact_Type__c != null &&
                                                     sentConn.HAM_Linked_Constituent__r.ucinn_ascendv2__Contact_Type__c.contains(HAM_ConstantsUtil.KIRKLAND_ALUMNAE);
                                scnw.header.put('isKirklandAlumnae', isKirkland);
                            } else if (meta.HAM_Display_Label__c == HAM_ConstantsUtil.DECEASED_ALUMNAE) {
                                scnw.header.put('isDeseasedAlumnae', Boolean.valueOf(fieldValue));
                            } else {
                                scnw.header.put(meta.HAM_Display_Label__c, fieldValue);
                                continue;
                            }
                        }
                        if (meta.HAM_Level_2__c == 'Flags') {
                            scnw.flags.put(meta.HAM_Display_Label__c, fieldValue == 'true');
                            continue;
                        }
                        if (meta.HAM_Level_2__c == 'Fields' && meta.HAM_Field_Type__c == 'Replaceable') {
                            FieldItems item = new FieldItems();
                            item.label = meta.HAM_Display_Label__c;
                            item.value = String.isBlank(fieldValue) ? '-' : fieldValue;
                            scnw.fields.add(item);
                        }
                    }
                    response.sentRequests.add(scnw);
                }

            } else {

            // ============================================================
            // INVITATION TAB — RECEIVED: Fetch Secondary FIRST, then Primary from it
            // ============================================================

            secondaryConnectionsQuery =
                'SELECT ' + String.join(selectedFieldsForSecondaryConnections, ', ') +
                ', HAM_Linked_Constituent__c, HAM_Rejected_Date__c, HAM_Connection_Message__c, HAM_Connection_Status__c,' +
                'HAM_Portal_User__c, CreatedDate ' +
                'FROM HAM_Connection__c ';

            secondaryConnectionsQuery += ' WHERE ' +
                portalUserWhere + ' ' + flagsPerTabOnSecondary +
                ' AND HAM_Portal_User__c NOT IN :IdsMatchingFiltersAndIndicators' +
                ' AND HAM_Portal_User__c NOT IN :AlumniPrivacyIds';

            Datetime lastSecondaryCreatedDate;

            if (recordsToSkip != null && recordsToSkip == 0) {

                secondaryConnectionsQuery += ' ORDER BY CreatedDate DESC LIMIT :pageSize';

            } else if (recordsToSkip != null && recordsToSkip > 0) {

                // Skip query: get the last record's CreatedDate
                String secondarySkipQuery = secondaryConnectionsQuery +
                    ' ORDER BY CreatedDate DESC LIMIT ' + recordsToSkip;

                List<HAM_Connection__c> lstSecondaryCon = Database.query(secondarySkipQuery);

                if (lstSecondaryCon != null && !lstSecondaryCon.isEmpty()) {
                    lastSecondaryCreatedDate = lstSecondaryCon[lstSecondaryCon.size() - 1].CreatedDate;
                }

                if (lastSecondaryCreatedDate != null) {
                    secondaryConnectionsQuery += ' AND CreatedDate < :lastSecondaryCreatedDate ORDER BY CreatedDate DESC LIMIT :pageSize';
                } else {
                    secondaryConnectionsQuery += ' ORDER BY CreatedDate DESC LIMIT :pageSize';
                }
            }

            // --- Execute Secondary Query ---
            Set<Id> secondaryConnectionConstituentIds = new Set<Id>();
            try {
                secondaryConnections = Database.Query(secondaryConnectionsQuery);
                for (HAM_Connection__c con : secondaryConnections) {
                    secondaryConnectionConstituentIds.add(con.HAM_Portal_User__c);
                }
            } catch (Exception ex) {
                System.debug(LoggingLevel.error, 'secondary connections Query Error: ' + ex.getMessage());
                return new DirectoryResponse();
            }

            // --- Fetch Primary FROM secondary results ---
            if (!secondaryConnectionConstituentIds.isEmpty()) {
                primaryConnectionsQuery =
                    'SELECT ' + String.join(selectedFieldsForPrimaryConnections, ', ') +
                    ',HAM_Linked_Constituent__c, HAM_Rejected_Date__c, HAM_Connection_Status__c,' +
                    'HAM_Portal_User__c ' +
                    'FROM HAM_Connection__c ';

                primaryConnectionsQuery += 'WHERE ' +
                    linkedUserWhere + ' ' + flagsPerTabOnPrimary +
                    ' AND HAM_Linked_Constituent__c NOT IN :IdsMatchingFiltersAndIndicators' +
                    ' AND HAM_Linked_Constituent__c NOT IN :AlumniPrivacyIds' +
                    ' AND HAM_Linked_Constituent__c IN :secondaryConnectionConstituentIds';

                primaryConnectionsQuery += ' ORDER BY CreatedDate DESC';

                try {
                    primaryConnections = Database.Query(primaryConnectionsQuery);
                } catch (Exception ex) {
                    System.debug(LoggingLevel.error, 'primary connections Query Error: ' + ex.getMessage());
                    return new DirectoryResponse();
                }
            }

            } // end RECEIVED branch

        } else {

            // ============================================================
            // ALL OTHER TABS: Primary first, then Secondary
            // ============================================================
        
            primaryConnectionsQuery =
                'SELECT ' + String.join(selectedFieldsForPrimaryConnections, ', ') +
                ',HAM_Linked_Constituent__c, HAM_Rejected_Date__c, HAM_Connection_Status__c,' +
                'HAM_Portal_User__c, CreatedDate ' +
                'FROM HAM_Connection__c ';
        
            primaryConnectionsQuery += 'WHERE ' +
                linkedUserWhere + ' ' + flagsPerTabOnPrimary +
                ' AND HAM_Linked_Constituent__c NOT IN :IdsMatchingFiltersAndIndicators' +
                ' AND HAM_Linked_Constituent__c NOT IN :AlumniPrivacyIds';
        
            if (isBlockedTab) {
                primaryConnectionsQuery += ' AND HAM_Is_Blocked__c = TRUE AND HAM_Linked_Constituent__c IN :blockedProfileIds';
            } else {
                primaryConnectionsQuery += ' AND HAM_Is_Blocked__c = FALSE AND HAM_Linked_Constituent__c NOT IN :blockedProfileIds';
            }
        
            if (isBuildTab) {
                primaryConnectionsQuery += ' AND HAM_Linked_Constituent__c IN :constituentIds';

                //NO STUDENT CLAUSE. 'APPLIES ONLY FOR 'SEARCH DIRECTORY' TAB.
                primaryConnectionsQuery += ' AND '+noStudentOnLinkedUser;
            }
        
            Datetime lastPrimaryCreatedDate;
        
            if (recordsToSkip != null && recordsToSkip == 0) {
        
                primaryConnectionsQuery += ' ORDER BY CreatedDate DESC LIMIT :pageSize';
        
            } else if (recordsToSkip != null && recordsToSkip > 0) {
        
                // Skip query: get the last record's CreatedDate
                String primarySkipQuery = primaryConnectionsQuery +
                    ' ORDER BY CreatedDate DESC LIMIT ' + recordsToSkip;

                //System.debug('>>> primarySkipQuery: ' + primarySkipQuery);
        
                List<HAM_Connection__c> lstPrimaryCon = Database.query(primarySkipQuery);
        
                if (lstPrimaryCon != null && !lstPrimaryCon.isEmpty()) {
                    lastPrimaryCreatedDate = lstPrimaryCon[lstPrimaryCon.size() - 1].CreatedDate;
                }
        
                if (lastPrimaryCreatedDate != null) {
                    primaryConnectionsQuery += ' AND CreatedDate < :lastPrimaryCreatedDate ORDER BY CreatedDate DESC LIMIT :pageSize';
                } else {
                    primaryConnectionsQuery += ' ORDER BY CreatedDate DESC LIMIT :pageSize';
                }
            }
            
            // --- Execute Primary Query ---
            Set<Id> primaryConnectionConstituentIds = new Set<Id>();

            //System.debug('>>> primaryConnectionsQuery: ' + primaryConnectionsQuery);

            try {
                primaryConnections = Database.Query(primaryConnectionsQuery);
                for (HAM_Connection__c con : primaryConnections) {
                    primaryConnectionConstituentIds.add(con.HAM_Linked_Constituent__c);
                }
            } catch (Exception ex) {
                System.debug(LoggingLevel.error, 'primary connections Query Error: ' + ex.getMessage());
                return new DirectoryResponse();
            }
        
            // --- Fetch Secondary from Primary results ---
            if (!primaryConnectionConstituentIds.isEmpty()) {
             
                secondaryConnectionsQuery =
                    'SELECT ' + String.join(selectedFieldsForSecondaryConnections, ', ') +
                    ', HAM_Linked_Constituent__c, HAM_Rejected_Date__c, HAM_Connection_Message__c, HAM_Connection_Status__c,' +
                    'HAM_Portal_User__c ' +
                    'FROM HAM_Connection__c ';
        
                secondaryConnectionsQuery += ' WHERE ' +
                    portalUserWhere + ' ' + flagsPerTabOnSecondary +
                    ' AND HAM_Portal_User__c NOT IN :IdsMatchingFiltersAndIndicators' +
                    ' AND HAM_Portal_User__c NOT IN :AlumniPrivacyIds' +
                    ' AND HAM_Portal_User__c IN :primaryConnectionConstituentIds';
        
                if (isBlockedTab) {
                    secondaryConnectionsQuery += ' AND HAM_Is_Blocked__c = TRUE AND HAM_Portal_User__c IN :blockedProfileIds';
                } else {
                    secondaryConnectionsQuery += ' AND HAM_Is_Blocked__c = FALSE AND HAM_Portal_User__c NOT IN :blockedProfileIds';
                }
        
                if (isBuildTab) {
                    secondaryConnectionsQuery += ' AND HAM_Portal_User__c IN :constituentIds';

                    //NO STUDENT CLAUSE. 'APPLIES ONLY FOR 'SEARCH DIRECTORY' TAB.
                    secondaryConnectionsQuery += ' AND '+noStudentOnPortalUser;
                }
        
                secondaryConnectionsQuery += ' ORDER BY CreatedDate DESC LIMIT :pageSize';
        
                try {
                    if (isBlockedTab == false) {
                        //System.debug('>>> secondaryConnectionsQuery: ' + secondaryConnectionsQuery);
                        secondaryConnections = Database.Query(secondaryConnectionsQuery);
                    }
                } catch (Exception ex) {
                    System.debug(LoggingLevel.error, 'Secondary connections Query Error: ' + ex.getMessage() + ' at ' + ex.getLineNumber());
                    return new DirectoryResponse();
                }
              
            }
        }
    
        //Build wrapper for primary connections
        if(primaryConnections != null && !primaryConnections.isEmpty()){
            for (HAM_Connection__c primaryConnection : primaryConnections) {
    
            ConnectionWrapper pcnw = new ConnectionWrapper();
            pcnw.linkedUserId = primaryConnection.HAM_Linked_Constituent__c;
            pcnw.portalUserId = primaryConnection.HAM_Portal_User__c;
            pcnw.status = primaryConnection.HAM_Connection_Status__c;
            pcnw.rejectedDate = primaryConnection.HAM_Rejected_Date__c;

            //Connection privacy check (disable/hide 'Send Connection' button)
            Boolean ConnectionPrivacyEnabled =  ConnectionPrivacyIds.Contains(primaryConnection.HAM_Linked_Constituent__c) ? true : false;
            pcnw.header.put('connectionPrivacyEnabled', ConnectionPrivacyEnabled);
    
            //skip fields based on service indicators
            Set<String> primaryskippedFields = new Set<String>();
            if (constituentServiceIndicatorsMap.containsKey(primaryConnection.HAM_Linked_Constituent__c)) {
                for (String fieldApi : primaryConnectionServiceIndicatorMap.keySet()) {
                    if (constituentServiceIndicatorsMap.get(primaryConnection.HAM_Linked_Constituent__c).contains(primaryConnectionServiceIndicatorMap.get(fieldApi))) {
                        primaryskippedFields.add(fieldApi);
                    }
                }
            }
    
            for (HAM_Meta_Data__mdt meta : primaryConnectionMeta) {
    
                // check for skipped field
                Boolean primaryFieldisSkipped = primaryskippedFields.contains(meta.HAM_Field_API__c);
                
                String valueInPrimary = '';
                if (!primaryFieldisSkipped) {
                    valueInPrimary = resolveFieldValue(primaryConnection, meta.HAM_Field_API__c, meta.HAM_Display_Label__c, degreeMap);
                }
                
                // Headers => Name , profile Photo , Kirkland Alumnae logo boolean
                if (meta.HAM_Level_2__c == 'Header') {
                    if(meta.HAM_Display_Label__c == HAM_ConstantsUtil.KIRKLAND_ALUMNAE){
                        Boolean isKirklandAlumnae = primaryConnection.HAM_Linked_Constituent__r.ucinn_ascendv2__Contact_Type__c != null &&
                                                    primaryConnection.HAM_Linked_Constituent__r.ucinn_ascendv2__Contact_Type__c.contains(HAM_ConstantsUtil.KIRKLAND_ALUMNAE);
                        pcnw.header.put('isKirklandAlumnae', isKirklandAlumnae);
                    }else if(meta.HAM_Display_Label__c == HAM_ConstantsUtil.DECEASED_ALUMNAE){
                        pcnw.header.put('isDeseasedAlumnae', Boolean.valueOf(valueInPrimary));
                    }else{
                        pcnw.header.put(meta.HAM_Display_Label__c, valueInPrimary);
                        continue;
                    }
                }
    
                // Flags => iConnected, isBookmarked, isFavorite, isBlocked
                if (meta.HAM_Level_2__c == 'Flags') {
                    pcnw.flags.put(meta.HAM_Display_Label__c, valueInPrimary == 'true');
                    continue;
                }
                
                // Fields => Rest of the fields Degree, Graduation Year, Industry
                if (meta.HAM_Level_2__c == 'Fields' && meta.HAM_Field_Type__c == 'Replaceable') {
                    
                    FieldItems item = new FieldItems();
                    item.label = meta.HAM_Display_Label__c;
                    //item.value = value != null ? value : '-';
                    if (String.isBlank(valueInPrimary)) {
                        item.value = '-';
                    } else {
                        item.value = valueInPrimary;
                    }
                    
                    pcnw.fields.add(item);
                }
            }
            response.connectionsData.primaryConnections.add(pcnw);
        }
        }
        
    
        //Build wrapper for secondary connections
    
        if(isBlockedTab){
            //ConnectionWrapper scnw = new ConnectionWrapper();
        }else{
    
            if(secondaryConnections != null && !secondaryConnections.isEmpty()){
                  for (HAM_Connection__c secondaryConnection : secondaryConnections) {
        
                    ConnectionWrapper scnw = new ConnectionWrapper();
                    scnw.linkedUserId = secondaryConnection.HAM_Linked_Constituent__c;
                    scnw.portalUserId = secondaryConnection.HAM_Portal_User__c;
                    scnw.status = secondaryConnection.HAM_Connection_Status__c;
                    scnw.rejectedDate = secondaryConnection.HAM_Rejected_Date__c;
                    scnw.connectionMessage = HAM_NotificationService.stripHTML(secondaryConnection.HAM_Connection_Message__c);

                    //Connection privacy check (disable/hide 'Send Connection' button)
                    Boolean ConnectionPrivacyEnabled =  ConnectionPrivacyIds.Contains(secondaryConnection.HAM_Portal_User__c) ? true : false;
                    scnw.header.put('connectionPrivacyEnabled', ConnectionPrivacyEnabled);
        
                    //skip fields based on service indicators
                    Set<String> secondaryskippedFields = new Set<String>();
                    if (constituentServiceIndicatorsMap.containsKey(secondaryConnection.HAM_Portal_User__c)) {
                        for (String fieldApi : secondaryConnectionServiceIndicatorMap.keySet()) {
                            if (constituentServiceIndicatorsMap.get(secondaryConnection.HAM_Portal_User__c).contains(secondaryConnectionServiceIndicatorMap.get(fieldApi))) {
                                secondaryskippedFields.add(fieldApi);
                            }
                        }
                    }
        
                    for (HAM_Meta_Data__mdt meta : secondaryConnectionMeta) {
        
                        // check for skipped field
                        Boolean secondaryFieldisSkipped = secondaryskippedFields.contains(meta.HAM_Field_API__c);
                        
                        String valueInSecondary = '';
                        if (!secondaryFieldisSkipped) {
                            valueInSecondary = resolveFieldValue(secondaryConnection, meta.HAM_Field_API__c, meta.HAM_Display_Label__c, degreeMap);
                        }
                        
                        // Header Fields = Name , profile Photo , Kirkland Alumnae log
                        if (meta.HAM_Level_2__c == 'Header') {
                            if(meta.HAM_Display_Label__c == HAM_ConstantsUtil.KIRKLAND_ALUMNAE){
                                Boolean isKirklandAlumnae = secondaryConnection.HAM_Portal_User__r.ucinn_ascendv2__Contact_Type__c != null &&
                                                            secondaryConnection.HAM_Portal_User__r.ucinn_ascendv2__Contact_Type__c.contains(HAM_ConstantsUtil.KIRKLAND_ALUMNAE);
                                scnw.header.put('isKirklandAlumnae', isKirklandAlumnae);
                            }else if(meta.HAM_Display_Label__c == HAM_ConstantsUtil.DECEASED_ALUMNAE){
                                scnw.header.put('isDeseasedAlumnae', Boolean.valueOf(valueInSecondary));
                            }else{
                                scnw.header.put(meta.HAM_Display_Label__c, valueInSecondary);
                                continue;
                            }
                        }
        
                        // Flags => iConnected, isBookmarked, isFavorite, isBlocked
                        if (meta.HAM_Level_2__c == 'Flags') {
                            scnw.flags.put(meta.HAM_Display_Label__c, valueInSecondary == 'true');
                            continue;
                        }
                        
                        // FIELDS => Rest of the fields Degree, Graduation Year, Industry
                        if (meta.HAM_Level_2__c == 'Fields' && meta.HAM_Field_Type__c == 'Replaceable') {
                            
                            FieldItems item = new FieldItems();
                            item.label = meta.HAM_Display_Label__c;
                            //item.value = value != null ? value : '-';
                            if (String.isBlank(valueInSecondary)) {
                                item.value = '-';
                            } else {
                                item.value = valueInSecondary;
                            }
                            
                            scnw.fields.add(item);
                        }
                    }
                    response.connectionsData.secondaryConnections.add(scnw);
                }
            }
            
        }
        return response;
    }

      /**
     * @description Builds the WHERE clause dynamically for the alumni directory based on search terms and filters.
     * @param constituentWhereClause Base WHERE string for Constituents.
     * @param portalWhereClause Base WHERE string for Portal Users.
     * @param linkedWhereClause Base WHERE string for Linked Constituents.
     * @param searchKey String input in the search bar from the user.
     * @param selectedFilters List of user-selected filters from UI.
     * @return String - A dynamically built WHERE clause string.
     */
    
     private static String buildWhereClause(String constituentWhereClause, String portalWhereClause, String linkedWhereClause,
                                     String searchKey, List<Map<String, Object>> selectedFilters) {
    
        List<String> conditions = new List<String>();

        String relationshipPrefix = '';
        String relationshipLookup = 'Id';

        if(portalWhereClause != null){
            relationshipPrefix = 'HAM_Portal_User__r.';
            relationshipLookup = 'HAM_Portal_User__c';
        }
        else if(linkedWhereClause != null){
            relationshipPrefix = 'HAM_Linked_Constituent__r.';
            relationshipLookup = 'HAM_Linked_Constituent__c';
        }

        String baseWhereClause;
        String nameField;

        if (constituentWhereClause != null) {
            baseWhereClause = constituentWhereClause;
            nameField = 'ucinn_ascendv2__Expanded_Name_Formula__c';

        } else if (portalWhereClause != null) {
            baseWhereClause = portalWhereClause;
            nameField = 'HAM_Portal_User__r.ucinn_ascendv2__Expanded_Name_Formula__c';

        } else if (linkedWhereClause != null) {
            baseWhereClause = linkedWhereClause;
            nameField = 'HAM_Linked_Constituent__r.ucinn_ascendv2__Expanded_Name_Formula__c';
        }

        // base condition
        if (String.isNotBlank(baseWhereClause)) {
            conditions.add(baseWhereClause);
        }

        // UPDATED: Multi-word Global Search logic — extended to include Contact Names child object
        // Primary match:  ucinn_ascendv2__Expanded_Name_Formula__c  (official name on Contact)
        // Fallback match: ucinn_ascendv2__Constructed_Name_Formula__c on ucinn_ascendv2__Contact_Name__c (nick names / former names stored as child records)
        // NOTE: A SOQL semi-join cannot be used here because Salesforce only allows semi-joins at
        // the top level of a WHERE clause, not nested inside OR groups. Instead we pre-query the
        // Names object once and inline the resulting IDs as literals.

        if (String.isNotBlank(searchKey) && String.isNotBlank(nameField)) {
            List<String> searchTerms = searchKey.trim().split('\\s+');
            List<String> nameSubConditions      = new List<String>();
            List<String> fuzzyNameSubConditions = new List<String>();

            //NOTE: We are using term.length() >= 2 condition after we faced a bug. At the least, we check the names records if we atleast have 2 chars
            // if the char is <2, then we only search with primary expanded name field on contact.
            //Anyhow, a nickname will atleast have 2 chars in most probable cases. This way, we cover appropriate records fetching.
            //Also as a safety, we are using LIMIT 49000 on names object.

            for (String term : searchTerms) {
                if (String.isNotBlank(term)) {
                    String safeTerm = String.escapeSingleQuotes(term);
                    // Primary name search runs for ALL term lengths
                    nameSubConditions.add(nameField + ' LIKE \'%' + safeTerm + '%\'');
                    // Fuzzy nickname search (on names object) only for terms >= 2 chars
                    if (term.length() >= 2) {
                        fuzzyNameSubConditions.add('ucinn_ascendv2__Constructed_Name_Formula__c LIKE \'%' + safeTerm + '%\'');
                    }
                }
            }

            if (!nameSubConditions.isEmpty()) {
                String nameCondition = '(' + String.join(nameSubConditions, ' AND ') + ')';

                // Only run fuzzy lookup if there are valid terms (>= 2 chars) to query on
                if (!fuzzyNameSubConditions.isEmpty()) {
                    if (cachedFuzzySearchKey == null || cachedFuzzySearchKey != searchKey) {
                        cachedFuzzySearchKey  = searchKey;
                        cachedFuzzyContactIds = new Set<Id>();
                        String contactNameQuery =
                            'SELECT ucinn_ascendv2__Contact__c FROM ucinn_ascendv2__Contact_Name__c WHERE '
                            + String.join(fuzzyNameSubConditions, ' AND ')
                            + ' LIMIT 49000';
                        for (ucinn_ascendv2__Contact_Name__c cn : Database.query(contactNameQuery)) {
                            if (cn.ucinn_ascendv2__Contact__c != null) {
                                cachedFuzzyContactIds.add(cn.ucinn_ascendv2__Contact__c);
                            }
                        }
                    }

                    if (!cachedFuzzyContactIds.isEmpty()) {
                        String idList = '\'' + String.join(new List<Id>(cachedFuzzyContactIds), '\',\'') + '\'';
                        String fuzzyCondition = relationshipLookup + ' IN (' + idList + ')';
                        conditions.add('(' + nameCondition + ' OR (' + fuzzyCondition + '))');
                    } else {
                        conditions.add(nameCondition);
                    }
                } else {
                    // All terms were single chars — use primary name search only, skip fuzzy
                    conditions.add(nameCondition);
                }
            }
        }

        // Metadata Map Fallback
        List<HAM_Filters__mdt> allFiltersMdt = [SELECT HAM_Direct_Filter__c, HAM_Direct_Filter_Field__c, HAM_Related_Filter_Object__c,
                                            HAM_Related_Reference_Filter_Field__c, HAM_Related_Reference_Filter__c, HAM_Placeholder__c
                                            FROM HAM_Filters__mdt ];

        Map<String, HAM_Filters__mdt> filterMetadataMap = new Map<String, HAM_Filters__mdt>();

        for (HAM_Filters__mdt mdt : allFiltersMdt){
            filterMetadataMap.put(mdt.HAM_Placeholder__c, mdt);
        }

        if (selectedFilters != null && !selectedFilters.isEmpty()) {
            for (Map<String, Object> filter : selectedFilters) {
                String ph = (String) filter.get('placeholder');
                List<Object> rawVals = (List<Object>) filter.get('values');
                
                if (String.isBlank(ph) || rawVals == null || rawVals.isEmpty()){
                    continue;
                }
                
                List<String> valList = new List<String>();
                for(Object o : rawVals){
                    valList.add( (String)o );
                }

                // Check Helper for complex SQL
                String complexCondition = HAM_AlumniFilterHelper.getSpecificWhereClause(ph, valList,relationshipLookup, relationshipPrefix);
                
                if (String.isNotBlank(complexCondition)) {
                    conditions.add(complexCondition);
                }
                // Fallback to standard metadata field mapping
                else if (filterMetadataMap.containsKey(ph)) {

                    HAM_Filters__mdt mdt = filterMetadataMap.get(ph);
                    List<String> safeVals = new List<String>();

                    for (String v : valList){
                        safeVals.add(String.escapeSingleQuotes(v));
                    }
                    String inClause = '(\'' + String.join(safeVals, '\',\'') + '\')';

                    if (mdt.HAM_Direct_Filter__c) {
                        String fieldName = String.isBlank(relationshipPrefix) ? mdt.HAM_Direct_Filter_Field__c : relationshipPrefix + mdt.HAM_Direct_Filter_Field__c;
                        conditions.add(fieldName + ' IN ' + inClause);
                    } else {
                        String subquery = 'Id IN (SELECT '+ mdt.HAM_Related_Reference_Filter_Field__c + ' FROM ' +
                            mdt.HAM_Related_Filter_Object__c + ' WHERE ' +
                            mdt.HAM_Related_Reference_Filter__c + ' IN ' + inClause + ')';
                        conditions.add(subquery);
                    }
                }
            }
        }
        //System.debug('Build where clause conditions: '+String.join(conditions, ' AND '));
        return conditions.isEmpty() ? '' : String.join(conditions, ' AND ');
    }
        
    /**
     * @description Saves selected filters as a JSON string for the logged-in user in the HAM_Portal_User_Preference__c object.
     * @param filtersJson JSON input of selected filters from the user UI.
     * @param currentContactId ContactId of the logged in portal user.
     */
    @AuraEnabled
    public static void saveUserPreferences(String filtersJson, String currentContactId ) {

        if (currentContactId != null) {
            List<HAM_Portal_User_Preference__c> existingPreferences = [
                SELECT Id, Alumni_Filter__c
                FROM HAM_Portal_User_Preference__c
                WHERE Portal_Contact__c = :currentContactId
                LIMIT 1
            ];
            
            if (!existingPreferences.isEmpty()) {
                HAM_Portal_User_Preference__c preferenceToUpdate = existingPreferences[0];
                preferenceToUpdate.Alumni_Filter__c = filtersJson;
                update preferenceToUpdate;
            } else {
                HAM_Portal_User_Preference__c newPreference = new HAM_Portal_User_Preference__c();
                newPreference.Alumni_Filter__c = filtersJson;
                newPreference.Portal_Contact__c = currentContactId;
                insert newPreference;
            }
        }
    }
    
    /**
     * @description Retrieves the saved JSON string of user filter preferences.
     * @param currentContactId The Contact Id for the logged-in user.
     * @return String JSON representation of stored user preferences.
     */
    @AuraEnabled(cacheable=true)
    public static String getSavedUserPreferences(String currentContactId) {
        
        if (currentContactId != null) {
            List<HAM_Portal_User_Preference__c> existingPreferences = [
                SELECT Alumni_Filter__c
                FROM HAM_Portal_User_Preference__c
                WHERE Portal_Contact__c = :currentContactId
                LIMIT 1
            ];
            
            if (!existingPreferences.isEmpty()) {
                return existingPreferences[0].Alumni_Filter__c;
            }
        }
        return null;
    }
    
    /**
     * @description Returns the logged-in user's class year and current chapters to be used as
     * default directory filters when no saved preferences exist.
     * HAM_Current_Chapters__c is a comma-separated Long Text Area; each trimmed value maps
     * to a Region filter option (matched against HAM_Preferred_Chapter_Lookup__r.Name).
     * @param contactId The Contact Id of the logged-in portal user.
     * @return ContactDefaultFilterData containing classYear and currentChapters list.
     */
    @AuraEnabled(cacheable=true)
    public static ContactDefaultFilterData getContactDefaultFilterData(String contactId) {
        ContactDefaultFilterData result = new ContactDefaultFilterData();
        result.currentChapters = new List<String>();
        result.majorValues = new List<String>();

        if (String.isBlank(contactId)) {
            return result;
        }

        List<Contact> contacts = [
            SELECT HAM_Reunion_Year__c
            FROM Contact
            WHERE Id = :contactId
            LIMIT 1
        ];

        if (contacts.isEmpty()) {
            return result;
        }

        Contact con = contacts[0];

        if (String.isNotBlank(con.HAM_Reunion_Year__c)) {
            result.classYear = con.HAM_Reunion_Year__c;
        }

        for (HAM_Current_Chapter__c ch : [
            SELECT Chapter__r.Name
            FROM HAM_Current_Chapter__c
            WHERE Constituent__c = :contactId
            AND Is_Active__c = true
            AND Chapter__r.Name != 'Unassigned Chapter'
        ]) {
            result.currentChapters.add(ch.Chapter__r.Name);
        }

        List<ucinn_ascendv2__Degree_Information__c> degrees = [
            SELECT ucinn_ascendv2__Major_Formula__c
            FROM ucinn_ascendv2__Degree_Information__c
            WHERE ucinn_ascendv2__Contact__c = :contactId
            AND RecordType.DeveloperName = 'School_Degree_Information'
            LIMIT 1
        ];

        if (!degrees.isEmpty() && String.isNotBlank(degrees[0].ucinn_ascendv2__Major_Formula__c)) {
            result.majorValues.add(degrees[0].ucinn_ascendv2__Major_Formula__c.trim());
        }

        return result;
    }

    /**
     * @description Fetches basic Contact details for the portal user to use in initial logic parsing.
     * @param constituentId The Contact ID for the current logged in user.
     * @return Contact record containing basic portal user info.
     */
    private static Contact getPortalConstituentDetails(Id constituentId) {
        return [
            SELECT Id, Name,HAM_Reunion_Year__c
            FROM Contact
            WHERE Id = :constituentId
            LIMIT 1
        ];
    }
    
    /**
     * @description Retrieves the portal Constituent's concentration (Degree) details.
     * @param constituentId The constituent Id.
     * @return Set<String> containing unique degree references.
     */
    private static Set<String> getPortalConstituentDegree(Id constituentId) {
        
        List<ucinn_ascendv2__Degree_Information__c> ConstituentDegrees;
        Set<String> Degrees = New Set<String>();
        if(constituentId != Null || constituentId != ''){
            ConstituentDegrees = [SELECT Id, ucinn_ascendv2__Major_Formula__c, ucinn_ascendv2__Contact__c FROM ucinn_ascendv2__Degree_Information__c WHERE ucinn_ascendv2__Contact__c =: constituentId];
        }
        
        if(!ConstituentDegrees.isEmpty()){
            for(ucinn_ascendv2__Degree_Information__c Degree : ConstituentDegrees){
                
                if(Degree.ucinn_ascendv2__Major_Formula__c != null){
                    Degrees.add(Degree.ucinn_ascendv2__Major_Formula__c.toLowerCase().trim());
                }
            }
        }
        
        return Degrees;
    }
      
    /**
     * @description Helper to dynamically resolve fields and nested attributes for UI mappings.
     * @param record Standard sObject to parse (Contact, HAM_Connection__c).
     * @param fieldApi Complete field path lookup.
     * @param displayLabel Custom logic branch target label.
     * @param degreeMap Map linking IDs to Degree definitions.
     * @return String dynamically parsed field string.
     */
    private static String resolveFieldValue(SObject record, String fieldApi,String displayLabel, Map<Id, Set<String>> degreeMap) {
        
        // handling for Degree
        if (displayLabel == 'Degree:') {
            if (record instanceof HAM_Connection__c) {
                HAM_Connection__c conn = (HAM_Connection__c) record;
                
                if(conn.HAM_Portal_User__c == portalUserId){
                    if (conn.HAM_Linked_Constituent__c != null && degreeMap.containsKey(conn.HAM_Linked_Constituent__c)) {
                        return String.join(degreeMap.get(conn.HAM_Linked_Constituent__c),', ');
                    }
                    return null;
                }else{
                    if (conn.HAM_Portal_User__c != null && degreeMap.containsKey(conn.HAM_Portal_User__c)) {
                        return String.join(degreeMap.get(conn.HAM_Portal_User__c),', ');
                    }
                    return null;
                }
            }
            
            if (record instanceof Contact) {
                Contact con = (Contact) record;
                
                if (degreeMap.containsKey(con.Id)) {
                    return String.join(degreeMap.get(con.Id), ', ');
                }
                
                return null;
            }
        }
        
        return getFieldValue(record, fieldApi);
    }
    
    /**
     * @description Utility method to grab deep cross-object field mapping values safely.
     * @param record Source sObject context.
     * @param fieldPath Full string lookup path (e.g., 'Account.Name').
     * @return String safe-cast field value output or null on failure.
     */
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
	
    /**
     * @description Obtains Directory Tab Configurations from metadata.
     * @return List<Ham_Directory_Tabset__mdt> Configuration parameters.
     */
    @AuraEnabled(cacheable=true)
    public static List <Ham_Directory_Tabset__mdt> getDirectoryTabset () {
        return [SELECT Id,Label,Is_Active__c,Tab_Order__c FROM Ham_Directory_Tabset__mdt WHERE Is_Active__c = true ORDER BY Tab_Order__c ];
    }
	
    /**
     * @description A wrapper class to structure output connection data for the front end directory widget.
     */
    public class AlumniData {
        @AuraEnabled public Id connectionId;
        @AuraEnabled public Id linkedConstituentId;
        @AuraEnabled public Map<String, Object> header = new Map<String, Object>();
        @AuraEnabled public Map<String, Object> flags  = new Map<String, Object>();
        @AuraEnabled public List<FieldItem> fields  = new List<FieldItem>();
    }
    
    /**
     * @description Individual UI mapping definition key-value store for nested iterations.
     */
    public class FieldItem {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
    }
    
    /**
     * @description General structure wrapper to merge constituent profiles with active user connections.
     */
    public class AlumniDirectoryWrapper {
        @AuraEnabled public List<AlumniData> connectionList;
        @AuraEnabled public List<AlumniData> alumniList;
        @AuraEnabled public String connectionCount;

    }
    
        /**
     * @description Main method to retrieve the alumni directory dashboard data based on priority/favorite logic metrics.
     * @param portalConstituentId Contact Id associated with the logged-in user.
     * @return AlumniDirectoryWrapper object containing parsed connection datasets and general alumni mapping logic.
     */
    @AuraEnabled(cacheable=true)
    public static AlumniDirectoryWrapper getDirectoryDataOnWidget(Id portalConstituentId) {
        
        Id ServiceIndicatorRecordTypeId = Schema.SObjectType.ucinn_ascendv2__Service_Indicator__c.getRecordTypeInfosByName().get(HAM_ConstantsUtil.CONTACT_SERVICE_INDICATOR_RECORD_TYPE).getRecordTypeId();
        
        // Get max size from Custom Label
        final Integer MAX_SIZE = Integer.valueOf(System.Label.Ham_Alumni_Directory_Max_Connections);

        // Number of cards actually shown in the widget
        final Integer DISPLAY_CAP = Integer.valueOf(System.Label.Ham_Alumni_Directory_Display_Count);
        
        portalUserId = portalConstituentId;
        
        Contact portalConstituent = getPortalConstituentDetails(portalConstituentId);
        Set<String> portalConstituentDegrees = getPortalConstituentDegree(portalConstituentId);
        String classYear = portalConstituent.HAM_Reunion_Year__c;
        AlumniDirectoryWrapper result = new AlumniDirectoryWrapper();
        result.connectionList = new List<AlumniData>();
        result.alumniList = new List<AlumniData>();
        
        try {
            
            //Get fields from metadata and prepare dynamic soql to get connections
            List<String> selectedFieldsForConnections = new List<String>{'Id'};
                List<HAM_Meta_Data__mdt> ConnectionMetaList = [SELECT HAM_Level_2__c,HAM_Field_API__c, HAM_Display_Label__c, HAM_Order__c,HAM_Field_Type__c FROM HAM_Meta_Data__mdt WHERE HAM_Level_1__c = 'Connection' AND (NOT HAM_Field_API__c LIKE 'HAM_Portal_User__r%') ORDER BY HAM_Order__c];
            
            //BUILD DYNAMIC QUERY FROM METADATA
            for (HAM_Meta_Data__mdt meta : ConnectionMetaList) {
                if(meta.HAM_Field_API__c != null){
                    selectedFieldsForConnections.add(meta.HAM_Field_API__c);
                }
            }
            
            String ConnectionQuery = 'SELECT HAM_Portal_User__c, ' + String.join(selectedFieldsForConnections, ', ')+ ' FROM HAM_Connection__c' +' WHERE HAM_Is_Blocked__c = false AND HAM_Linked_Constituent__r.ucinn_ascendv2__Is_Deceased__c = false AND HAM_Linked_Constituent__r.HAM_Is_Active__c = True' +
                ' AND HAM_Portal_User__c = \'' + String.escapeSingleQuotes(portalConstituentId) + '\'' +' ORDER BY LastModifiedDate DESC LIMIT 2000';
            
            List<HAM_Connection__c> connections = (List<HAM_Connection__c>) Database.query(ConnectionQuery);
            

            // sort final connection list based on priority
            // Optimized single-pass with configurable max size
            List<HAM_Connection__c> finalConnections = new List<HAM_Connection__c>();
            List<HAM_Connection__c> nonFavorites = new List<HAM_Connection__c>();
            List<HAM_Connection__c> bookmarked = new List<HAM_Connection__c>();
            
            for (HAM_Connection__c conn : connections) {
                if (conn.HAM_Is_Connected__c == true) {
                   
                    if (conn.HAM_Is_favorite__c) {
                        if (finalConnections.size() < MAX_SIZE) {
                            finalConnections.add(conn);
                        }
                    } else {
                        if (nonFavorites.size() < MAX_SIZE) {
                            nonFavorites.add(conn);
                        }
                    }
                } else if (conn.HAM_Is_bookmarked__c == true) {
                    if (bookmarked.size() < MAX_SIZE) {
                        bookmarked.add(conn);
                    }
                }
                
                // Early exit when max favorites reached
                if (finalConnections.size() >= MAX_SIZE) {
                    break;
                }
            }

            // 1) Count ALL connected records — no limit, no break
            Integer countConnection = 0;
            for (HAM_Connection__c conn : connections) {
                if (conn.HAM_Is_Connected__c == true) {
                    countConnection++;
                }
            }
            
            // Format count to always display as 2 digits (e.g., 01, 02)
            result.connectionCount =  String.valueOf(countConnection);

            // Fill remaining slots
            fillFromList(finalConnections, nonFavorites, MAX_SIZE);
            fillFromList(finalConnections, bookmarked, MAX_SIZE);
            
            //Get fields from metadata and prepare dynamic soql to get constituent data
            List<String> selectedFieldsForConstituents = new List<String>{'Id'};
            List<HAM_Meta_Data__mdt> DirectoryMetaList = [SELECT HAM_Level_2__c,HAM_Field_API__c, HAM_Display_Label__c, HAM_Order__c,HAM_Field_Type__c FROM HAM_Meta_Data__mdt WHERE HAM_Level_1__c = 'Directory' ORDER BY HAM_Order__c];
            
            //BUILD DYNAMIC QUERY FROM METADATA
            for (HAM_Meta_Data__mdt meta : DirectoryMetaList) {
                if(meta.HAM_Field_API__c != null){
                    selectedFieldsForConstituents.add(meta.HAM_Field_API__c);
                }
            }
            
            String DirectoryQuery = '';
            List<Contact> Constituents = new List<Contact>();

            if (String.isNotBlank(classYear)) {
            DirectoryQuery = 'SELECT ' + String.join(selectedFieldsForConstituents, ', ') + ', ' +
                '(SELECT ucinn_ascendv2__Major_Formula__c ' +
                ' FROM ucinn_ascendv2__Degree_Information_Contact__r) ' +
                'FROM Contact ' +
                'WHERE HAM_Reunion_Year__c = :classYear AND ucinn_ascendv2__Is_Deceased__c = false AND HAM_Is_Active__c = True' +
                ' AND Id != \'' + String.escapeSingleQuotes(portalConstituentId) + '\'' +
                'ORDER BY Name ASC LIMIT 1500';
            
             Constituents = (List<Contact>) Database.query(DirectoryQuery);
            }
            
            //List<Contact> Constituents = (List<Contact>) Database.query(DirectoryQuery);
            
            //Get linkedConstituentIds for final connections - used to get degrees
            Set<Id> linkedConstituentIds = new Set<Id>();
            for (HAM_Connection__c c : finalConnections) {
                if (c.HAM_Linked_Constituent__c != null) {
                    linkedConstituentIds.add(c.HAM_Linked_Constituent__c);
                }
            }
            
            //Get Service Indicatirs Connfigurations
            Map<String, String> ServiceIndicatorMap = new Map<String, String>();

            for (Ham_Service_Indicators__mdt ind : [SELECT Indicator_For_Field__c, Indicator_Value__c FROM Ham_Service_Indicators__mdt WHERE Is_Active__c = true AND
                                                    (Module__c = 'Directory Widget')]) {
                ServiceIndicatorMap.put(ind.Indicator_For_Field__c,ind.Indicator_Value__c);
            }
            
            Map<Id,List<String>> constituentServiceIndicatorsMap = new Map<Id,List<String>>();
            //for connections
            if(!linkedConstituentIds.isEmpty()){
                for (ucinn_ascendv2__Service_Indicator__c si : [SELECT ucinn_ascendv2__Contact__c,ucinn_ascendv2__Service_Indicator_Value__r.ucinn_ascendv2__Service_Indicator_Description__c,ucinn_ascendv2__Service_Indicator_Value__r.HAM_Portal_ID__c
                                                                FROM ucinn_ascendv2__Service_Indicator__c
                                                                WHERE RecordTypeId =: ServiceIndicatorRecordTypeId
                                                                AND ucinn_ascendv2__Contact__c IN: linkedConstituentIds AND ucinn_ascendv2__Is_Active__c = true AND ucinn_ascendv2__Service_Indicator_Value__r.HAM_Portal_ID__c != null]) {
                                                                    
                    if(!constituentServiceIndicatorsMap.containsKey(si.ucinn_ascendv2__Contact__c)){
                        constituentServiceIndicatorsMap.put(si.ucinn_ascendv2__Contact__c,new List<String>{si.ucinn_ascendv2__Service_Indicator_Value__r.HAM_Portal_ID__c});
                    }else{
                        constituentServiceIndicatorsMap.get(si.ucinn_ascendv2__Contact__c).add(si.ucinn_ascendv2__Service_Indicator_Value__r.HAM_Portal_ID__c);
                    }
                }
            }
            
            if(!Constituents.isEmpty()){
                for (ucinn_ascendv2__Service_Indicator__c si : [SELECT ucinn_ascendv2__Contact__c,ucinn_ascendv2__Service_Indicator_Value__r.ucinn_ascendv2__Service_Indicator_Description__c,ucinn_ascendv2__Service_Indicator_Value__r.HAM_Portal_ID__c
                                                                FROM ucinn_ascendv2__Service_Indicator__c
                                                                WHERE RecordTypeId =: ServiceIndicatorRecordTypeId AND ucinn_ascendv2__Contact__c IN: Constituents
                                                                AND ucinn_ascendv2__Is_Active__c = true AND ucinn_ascendv2__Service_Indicator_Value__r.HAM_Portal_ID__c != null]) {
                                                                    
                    if(!constituentServiceIndicatorsMap.containsKey(si.ucinn_ascendv2__Contact__c)){
                        constituentServiceIndicatorsMap.put(si.ucinn_ascendv2__Contact__c,new List<String>{si.ucinn_ascendv2__Service_Indicator_Value__r.HAM_Portal_ID__c});
                    }else{
                        constituentServiceIndicatorsMap.get(si.ucinn_ascendv2__Contact__c).add(si.ucinn_ascendv2__Service_Indicator_Value__r.HAM_Portal_ID__c);
                    }
                }
            }
            
            Map<Id, Set<String>> degreeMap = new Map<Id, Set<String>>();
            
            //for connections
            if (!linkedConstituentIds.isEmpty()) {
                for (ucinn_ascendv2__Degree_Information__c deg : [SELECT ucinn_ascendv2__Contact__c,ucinn_ascendv2__Major_Formula__c FROM ucinn_ascendv2__Degree_Information__c
                                                                  WHERE ucinn_ascendv2__Contact__c IN :linkedConstituentIds]) {
                                                                      
                    if (!degreeMap.containsKey(deg.ucinn_ascendv2__Contact__c)) {
                        degreeMap.put(deg.ucinn_ascendv2__Contact__c, new Set<String>());
                    }
                    if (deg.ucinn_ascendv2__Major_Formula__c != null) {
                         if(!degreeMap.get(deg.ucinn_ascendv2__Contact__c).contains(deg.ucinn_ascendv2__Major_Formula__c)){
                            degreeMap.get(deg.ucinn_ascendv2__Contact__c).add(deg.ucinn_ascendv2__Major_Formula__c);
                        }
                    }
                }
            }
            
            //For Constituents
            if (!Constituents.isEmpty()) {
                for (Contact con : Constituents) {
                    
                    if (con.ucinn_ascendv2__Degree_Information_Contact__r == null) {
                        continue;
                    }
                    
                    for (ucinn_ascendv2__Degree_Information__c deg : con.ucinn_ascendv2__Degree_Information_Contact__r) {
                        
                        if (deg.ucinn_ascendv2__Major_Formula__c == null) {
                            continue;
                        }
                        if(!degreeMap.containsKey(con.Id)){
                            degreeMap.put(con.Id,new Set<String>());
                        }
                        degreeMap.get(con.Id).add(deg.ucinn_ascendv2__Major_Formula__c);
                    }
                }
            }

           
            // Build wrapper for UI
            if(!finalConnections.isEmpty()){
                for (HAM_Connection__c conn : finalConnections) {

                     // --- MASTER PRIVACY CHECK ---
                    if (constituentServiceIndicatorsMap.containsKey(conn.HAM_Linked_Constituent__c)) {
                        if (constituentServiceIndicatorsMap.get(conn.HAM_Linked_Constituent__c).contains('SIV_VIS_ALUMNI_PRIVACY')) {
                            continue; // Skip this contact entirely
                        }
                    }

                    AlumniData alumni = new AlumniData();
                    alumni.connectionId = conn.Id;
                    alumni.linkedConstituentId = conn.HAM_Linked_Constituent__c;
                    
                    //  skip fields based on service indicators
                    
                    Set<String> skippedFields = new Set<String>();
                    if (constituentServiceIndicatorsMap.containsKey(conn.HAM_Linked_Constituent__c)) {
                        for (String fieldApi : ServiceIndicatorMap.keySet()) {
                            if (constituentServiceIndicatorsMap.get(conn.HAM_Linked_Constituent__c).contains(ServiceIndicatorMap.get(fieldApi))) {
                                skippedFields.add(fieldApi);
                            }
                        }
                    }
                    
                    // Build wrapper
                    
                    for (HAM_Meta_Data__mdt meta : ConnectionMetaList) {
                        
                        // check for skipped field
                        Boolean isSkipped = skippedFields.contains(meta.HAM_Field_API__c);
                        
                        String value = '';
                        if (!isSkipped) {
                            value = resolveFieldValue(conn, meta.HAM_Field_API__c, meta.HAM_Display_Label__c, degreeMap);
                        }
                        
                        //  Header Fields => Name, profile Photo,Kikland Alumnae logo
                        if (meta.HAM_Level_2__c == 'Header') {
                            if(meta.HAM_Display_Label__c == HAM_ConstantsUtil.KIRKLAND_ALUMNAE){
                                Boolean isKirklandAlumnae = conn.HAM_Linked_Constituent__r.ucinn_ascendv2__Contact_Type__c != null &&
                                                            conn.HAM_Linked_Constituent__r.ucinn_ascendv2__Contact_Type__c.contains(HAM_ConstantsUtil.KIRKLAND_ALUMNAE);
                                alumni.header.put('isKirklandAlumnae', isKirklandAlumnae);
                            }
                            else if(meta.HAM_Display_Label__c == HAM_ConstantsUtil.DECEASED_ALUMNAE){
                                alumni.header.put('isDeseasedAlumnae', Boolean.valueOf(value));
                            }else{
                                alumni.header.put(meta.HAM_Display_Label__c, value);
                                continue;
                            }
                        }
                        
                        // FLAGS => iConnected, isBookmarked, isFavorite, isBlocked
                        if (meta.HAM_Level_2__c == 'Flags') {
                            alumni.flags.put(meta.HAM_Display_Label__c, value == 'true');
                            continue;
                        }
                        
                        // FIELDS => Rest of the fields Degree, Graduation Year, Industry
                        if (meta.HAM_Level_2__c == 'Fields' && meta.HAM_Field_Type__c == 'Replaceable') {
                            
                            FieldItem item = new FieldItem();
                            item.label = meta.HAM_Display_Label__c;
                            //item.value = value != null ? value : '-';
                            if (String.isBlank(value)) {
                                item.value = '-';
                            } else {
                                item.value = value;
                            }
                            
                            alumni.fields.add(item);
                        }
                    }
                    result.connectionList.add(alumni);

                    if (result.connectionList.size() >= DISPLAY_CAP) {
                        break;
                    }
                }
            }
            // if coonections is not present then check for classmate list
            if(finalConnections.isEmpty()){
                
                // Handle null degrees
                Set<String> portalContactDegrees = portalConstituentDegrees == null ? new Set<String>() : portalConstituentDegrees;
                
                // Single pass: find matching classmates and build degree map simultaneously
                List<Contact> finalClassmates = new List<Contact>();
                Map<Id, List<String>> constituentDegreeMap = new Map<Id, List<String>>();
                
                for(Contact con : Constituents){
                    
                    // Stop if we have enough classmates
                    if (finalClassmates.size() >= MAX_SIZE) {
                        break;
                    }
                    
                    
                    
                    // Check for matching degree and collect all degrees in one pass
                    Boolean hasMatchingDegree = false;
                    List<String> allDegrees = new List<String>();
                    
                    for (ucinn_ascendv2__Degree_Information__c degInfo : con.ucinn_ascendv2__Degree_Information_Contact__r) {
                        String major = degInfo.ucinn_ascendv2__Major_Formula__c;
                        
                        if (String.isNotBlank(major)) {
                            allDegrees.add(major);
                            
                            // Check if this degree matches portal constituent's degrees
                            if (!hasMatchingDegree && portalContactDegrees.contains(major.toLowerCase().trim())) {
                                hasMatchingDegree = true;
                            }
                        }
                    }
                    
                    // Add classmate if they have a matching degree
                 
                        finalClassmates.add(con);
                        constituentDegreeMap.put(con.Id, allDegrees);
                  
                    
                }
                
                for(Contact con : finalClassmates){
                    
                    // --- MASTER PRIVACY CHECK ---
                    if (constituentServiceIndicatorsMap.containsKey(con.Id)) {
                        if (constituentServiceIndicatorsMap.get(con.Id).contains('SIV_VIS_ALUMNI_PRIVACY')) {
                            continue; // Skip this contact entirely
                        }
                    }

                    AlumniData alumniOnDirectory = new AlumniData();
                    alumniOnDirectory.connectionId = con.Id;
                    
                    //  skip fields based on service indicators
                    
                    Set<String> DirectoryskippedFields = new Set<String>();
                    if (constituentServiceIndicatorsMap.containsKey(con.Id)) {
                        for (String fieldApi : ServiceIndicatorMap.keySet()) {
                            if (constituentServiceIndicatorsMap.get(con.Id).contains(ServiceIndicatorMap.get(fieldApi))) {
                                DirectoryskippedFields.add(fieldApi);
                            }
                        }
                    }
                    
                    // Build wrapper
                    
                    for (HAM_Meta_Data__mdt meta : DirectoryMetaList) {
                        
                        // check for skipped field
                        Boolean DirFieldisSkipped = DirectoryskippedFields.contains(meta.HAM_Field_API__c);
                        
                        String valueInDirectory = '';
                        if (!DirFieldisSkipped) {
                            valueInDirectory = resolveFieldValue(con, meta.HAM_Field_API__c, meta.HAM_Display_Label__c, degreeMap);
                        }
                        
                        //  Header Fields => Name and profile Photo , Kirkland Alumnae
                        if (meta.HAM_Level_2__c == 'Header') {
                            if(meta.HAM_Display_Label__c == HAM_ConstantsUtil.KIRKLAND_ALUMNAE){
                                Boolean isKirklandAlumnae = con.ucinn_ascendv2__Contact_Type__c != null &&
                                                            con.ucinn_ascendv2__Contact_Type__c.contains(HAM_ConstantsUtil.KIRKLAND_ALUMNAE);
                                alumniOnDirectory.header.put('isKirklandAlumnae', isKirklandAlumnae);
                            }else if(meta.HAM_Display_Label__c == HAM_ConstantsUtil.DECEASED_ALUMNAE){
                                alumniOnDirectory.header.put('isDeseasedAlumnae', Boolean.valueOf(valueInDirectory));
                            }else{
                                alumniOnDirectory.header.put(meta.HAM_Display_Label__c, valueInDirectory);
                                continue;
                            }
                        }
                        
                        // FLAGS => iConnected, isBookmarked, isFavorite, isBlocked
                        if (meta.HAM_Level_2__c == 'Flags') {
                            alumniOnDirectory.flags.put(meta.HAM_Display_Label__c, valueInDirectory == 'true');
                            continue;
                        }
                        
                        // FIELDS => Rest of the fields Degree, Graduation Year, Industry
                        if (meta.HAM_Level_2__c == 'Fields' && meta.HAM_Field_Type__c == 'Replaceable') {
                            
                            FieldItem item = new FieldItem();
                            item.label = meta.HAM_Display_Label__c;
                            //item.value = value != null ? value : '-';
                            if (String.isBlank(valueInDirectory)) {
                                item.value = '-';
                            } else {
                                item.value = valueInDirectory;
                            }
                            
                            alumniOnDirectory.fields.add(item);
                        }
                    }
                    result.alumniList.add(alumniOnDirectory);

                    if (result.alumniList.size() >= DISPLAY_CAP) {
                        break;
                    }
                }
            }
            
            return result;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching alumni directory data: ' +e.getMessage() + ' at line ' + e.getLineNumber());
        }
        
    }
    
	/**
     * @description Helper method to fill up object list slots with non-favorites and bookmarked connections until maxSize is reached.
     * @param target The resulting collection.
     * @param source The source collection iterating.
     * @param maxSize Total max size enforcement.
     */
    private static void fillFromList(List<HAM_Connection__c> target, List<HAM_Connection__c> source, Integer maxSize) {
        Integer toAdd = Math.min(source.size(), maxSize - target.size());
        for (Integer i = 0; i < toAdd; i++) {
            target.add(source[i]);
        }
    }

     @AuraEnabled(cacheable=true)
    public static Boolean getPortalConstituentPrivacy(Id portalConstituentId) {

        if (portalConstituentId == null) {
            return false;
        }
            
        //Service indicators setup
    
        //Check for ALUMNI_PRIVACY (Hidden on directory) and CONNECTION_PRIVACY (Disable send request button)
        Set<Id> AlumniPrivacyIds = new Set<Id>();
        Set<Id> ConnectionPrivacyIds = new Set<Id>();
        Id ServiceIndicatorRecordTypeId = Schema.SObjectType.ucinn_ascendv2__Service_Indicator__c.getRecordTypeInfosByName().get(HAM_ConstantsUtil.CONTACT_SERVICE_INDICATOR_RECORD_TYPE).getRecordTypeId();


        List<ucinn_ascendv2__Service_Indicator__c> connectionPrivacy = [
        SELECT Id
        FROM ucinn_ascendv2__Service_Indicator__c
        WHERE RecordTypeId = :serviceIndicatorRecordTypeId
          AND ucinn_ascendv2__Is_Active__c = true
          AND ucinn_ascendv2__Contact__c = :portalConstituentId
          AND ucinn_ascendv2__Service_Indicator_Value__r.HAM_Portal_ID__c = :HAM_ConstantsUtil.CONNECTION_PRIVCACY_SVID
        LIMIT 1
    ];

    return !connectionPrivacy.isEmpty();
    }
    
}