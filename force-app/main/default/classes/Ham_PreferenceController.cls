/**
 * @description Controller for the Hamilton Preference Center LWC.
 * Handles fetching UI configuration from Service Indicator Values 
 * and managing Constituent preferences via Service Indicator suppression records.
 * Runs in 'without sharing' mode to allow Community Users to create/update records.
 */
@SuppressWarnings('PMD.NoTrailingWhitespace, PMD.IfElseStmtsMustUseBraces, PMD.IfStmtsMustUseBraces,PMD.ExcessivePublicCount, PMD.OperationWithLimitsInLoop, PMD.DebugsShouldUseLoggingLevel, PMD.ApexDoc, PMD.FieldNamingConventions, PMD.ExcessiveClassLength, PMD.ApexCRUDViolation, PMD.EmptyIfStmt, PMD.EmptyStatementBlock, PMD.AvoidNonRestrictiveQueries, PMD.CyclomaticComplexity, PMD.CognitiveComplexity, PMD.NcssCount, PMD.NcssTypeCount, PMD.DetectCopyPasteForApex, PMD.LocalVariableNamingConventions, PMD.ExcessiveParameterList, PMD.ApexSOQLInjection, PMD.AvoidDeeplyNestedIfStmts, PMD.AvoidDebugStatements, PMD.StdCyclomaticComplexity, PMD.NcssMethodCount')
public without sharing class Ham_PreferenceController {
    
    public class PreferenceDataDTO {
        @AuraEnabled public List<SIVWrapper> items;
        @AuraEnabled public List<String> activeIndicatorIds; // Changed from Names to IDs
    }

    public class SIVWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String name;      
        @AuraEnabled public String category;  
        @AuraEnabled public String description; 
        @AuraEnabled public String parentId; // Changed from UI Key to ID
    }

    @AuraEnabled(cacheable=true)
    public static PreferenceDataDTO getPreferences(String contactId) {
        PreferenceDataDTO result = new PreferenceDataDTO();
        
        // Fetch Configuration: Notice we only need the Parent ID field now!
        List<ucinn_ascendv2__Service_Indicator_Value__c> sivList = [
            SELECT Id, Name, HAM_Category__c, ucinn_ascendv2__Service_Indicator_Description__c, HAM_Portal_Visible_Name__c,
                   HAM_Parent_Service_Indicator_Value__c
            FROM ucinn_ascendv2__Service_Indicator_Value__c 
            WHERE HAM_Category__c IN ('Communication Preferences','Marketing Preferences','Privacy Controls','Email Preferences') 
            AND HAM_Is_Visible_On_Portal__c = TRUE
            ORDER BY HAM_Category__c ASC, Name ASC
        ];

        result.items = new List<SIVWrapper>();
        for (ucinn_ascendv2__Service_Indicator_Value__c siv : sivList) {
            SIVWrapper item = new SIVWrapper();
            item.id = siv.Id;
            item.name = String.isNotBlank(siv.HAM_Portal_Visible_Name__c) ? siv.HAM_Portal_Visible_Name__c : siv.Name;
            item.category = siv.HAM_Category__c;
            item.description = siv.ucinn_ascendv2__Service_Indicator_Description__c; 
            item.parentId = siv.HAM_Parent_Service_Indicator_Value__c; // Directly assign the ID
            
            result.items.add(item);
        }

        // Fetch State: Active Indicators mapped by ID
        Set<String> activeSet = new Set<String>();
        if (contactId != null) {
            List<ucinn_ascendv2__Service_Indicator__c> activeIndicators = [
                SELECT ucinn_ascendv2__Service_Indicator_Value__c
                FROM ucinn_ascendv2__Service_Indicator__c 
                WHERE ucinn_ascendv2__Contact__c = :contactId 
                AND ucinn_ascendv2__Is_Active__c = TRUE 
            ];

            for (ucinn_ascendv2__Service_Indicator__c indicator : activeIndicators) {
                if (indicator.ucinn_ascendv2__Service_Indicator_Value__c != null) {
                    activeSet.add(indicator.ucinn_ascendv2__Service_Indicator_Value__c);
                }
            }
        } 
        result.activeIndicatorIds = new List<String>(activeSet);

        return result;
    }

    @AuraEnabled
    public static void savePreferences(Map<String, Boolean> changedToggles, String contactId) {
        if (changedToggles == null || changedToggles.isEmpty()) return;
        if (contactId == null) throw new AuraHandledException('No Contact found for current user.');

        Id contactIndicatorRtId = Schema.SObjectType.ucinn_ascendv2__Service_Indicator__c
            .getRecordTypeInfosByDeveloperName()
            .get('Contact_Service_Indicator')
            .getRecordTypeId();

        List<ucinn_ascendv2__Service_Indicator__c> toInsert = new List<ucinn_ascendv2__Service_Indicator__c>();
        List<ucinn_ascendv2__Service_Indicator__c> toUpdate = new List<ucinn_ascendv2__Service_Indicator__c>();

        // Query existing records directly using the IDs passed from the UI
        List<ucinn_ascendv2__Service_Indicator__c> currentActiveRecords = [
            SELECT Id, ucinn_ascendv2__Service_Indicator_Value__c
            FROM ucinn_ascendv2__Service_Indicator__c 
            WHERE ucinn_ascendv2__Contact__c = :contactId
            AND ucinn_ascendv2__Is_Active__c = TRUE
            AND ucinn_ascendv2__Service_Indicator_Value__c IN :changedToggles.keySet()
        ];
        
        Map<String, ucinn_ascendv2__Service_Indicator__c> activeMap = new Map<String, ucinn_ascendv2__Service_Indicator__c>();
        for (ucinn_ascendv2__Service_Indicator__c ind : currentActiveRecords) {
            activeMap.put(ind.ucinn_ascendv2__Service_Indicator_Value__c, ind);
        }

        // Process Changes based on Suppression Logic
        for (String sivId : changedToggles.keySet()) {
            Boolean isOptedIn = changedToggles.get(sivId); 

            if (isOptedIn) {
                if (activeMap.containsKey(sivId)) {
                    ucinn_ascendv2__Service_Indicator__c existing = activeMap.get(sivId);
                    existing.ucinn_ascendv2__End_Date__c = System.today();
                    toUpdate.add(existing);
                }
            } 
            else {
                if (!activeMap.containsKey(sivId)) {
                    ucinn_ascendv2__Service_Indicator__c newInd = new ucinn_ascendv2__Service_Indicator__c();
                    newInd.RecordTypeId = contactIndicatorRtId; 
                    newInd.ucinn_ascendv2__Contact__c = contactId;
                    newInd.ucinn_ascendv2__Service_Indicator_Value__c = sivId; // Assign ID directly
                    newInd.ucinn_ascendv2__Start_Date__c = System.today();
                    newInd.ucinn_ascendv2__End_Date__c = null; 
                    newInd.ucinn_ascendv2__Is_Active__c = true;
                    
                    toInsert.add(newInd);
                }
            }
        }

        try {
            if (!toUpdate.isEmpty()) update toUpdate; 
            if (!toInsert.isEmpty()) insert toInsert; 
            
            List<Id> serviceIndicatorIds = new List<Id>();
            for (ucinn_ascendv2__Service_Indicator__c updatedRec : toUpdate) { serviceIndicatorIds.add(updatedRec.Id); }
            for (ucinn_ascendv2__Service_Indicator__c insertedRec : toInsert) { serviceIndicatorIds.add(insertedRec.Id); }
            
            if (!serviceIndicatorIds.isEmpty() && !Test.isRunningTest()) {
                HamMktgCampaignService.processServiceIndicators(serviceIndicatorIds, contactId);
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error saving preferences: ' + e.getMessage());
        }
    }
}