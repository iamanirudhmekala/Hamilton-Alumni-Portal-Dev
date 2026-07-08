/**
 * @description Test class for Ham_PreferenceController.
 * Updated to cover Inverted Suppression Logic, Dynamic Parent Lookups, and ID-based tracking.
 */
@SuppressWarnings('PMD.NoTrailingWhitespace, PMD.IfElseStmtsMustUseBraces, PMD.IfStmtsMustUseBraces,PMD.ExcessivePublicCount, PMD.OperationWithLimitsInLoop, PMD.DebugsShouldUseLoggingLevel, PMD.ApexDoc, PMD.FieldNamingConventions, PMD.ExcessiveClassLength, PMD.ApexCRUDViolation, PMD.EmptyIfStmt, PMD.EmptyStatementBlock, PMD.AvoidNonRestrictiveQueries, PMD.CyclomaticComplexity, PMD.CognitiveComplexity, PMD.NcssCount, PMD.NcssTypeCount, PMD.DetectCopyPasteForApex, PMD.LocalVariableNamingConventions, PMD.ExcessiveParameterList, PMD.ApexSOQLInjection, PMD.AvoidDeeplyNestedIfStmts, PMD.AvoidDebugStatements, PMD.StdCyclomaticComplexity, PMD.NcssMethodCount, PMD.ApexUnitTestClassShouldHaveRunAs, PMD.MethodNamingConventions')
@isTest
private class Ham_PreferenceController_Test {

    /**
     * @description Test Setup method to create foundational data.
     */
    @testSetup
    static void setupData() {
        // 1. Create Account
        Account acc = new Account(Name = 'Test Household');
        insert acc;

        // 2. Create Contact
        Contact con = new Contact(
            FirstName = 'Test1',
            LastName = 'User1',
            AccountId = acc.Id,
            Email = 'test1user1@example.com'
        );
        insert con;

        // 3. Create Service Indicator Values (Configuration Records)
        // Parent Record (e.g., Mail)
        ucinn_ascendv2__Service_Indicator_Value__c parentSiv = new ucinn_ascendv2__Service_Indicator_Value__c(
            Name = 'No Contact Mass Mail',
            HAM_Portal_Visible_Name__c = 'Mail',
            HAM_Category__c = 'Communication Preferences',
            ucinn_ascendv2__Service_Indicator_Description__c = 'Opt out of all mail',
            HAM_Is_Visible_On_Portal__c = true
        );
        insert parentSiv;

        // Child Record (e.g., Hamilton Magazine) linked to Parent
        ucinn_ascendv2__Service_Indicator_Value__c childSiv = new ucinn_ascendv2__Service_Indicator_Value__c(
            Name = 'No Hamilton Magazine',
            HAM_Portal_Visible_Name__c = 'Hamilton Magazine',
            HAM_Category__c = 'Marketing Preferences',
            ucinn_ascendv2__Service_Indicator_Description__c = 'Opt out of magazine',
            HAM_Is_Visible_On_Portal__c = true,
            HAM_Parent_Service_Indicator_Value__c = parentSiv.Id
        );
        insert childSiv;
    }

    /**
     * @description Tests the getPreferences method.
     * Verifies it correctly maps parent IDs and active IDs.
     */
    @isTest
    static void testGetPreferences() {
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        ucinn_ascendv2__Service_Indicator_Value__c siv = [SELECT Id FROM ucinn_ascendv2__Service_Indicator_Value__c WHERE Name = 'No Contact Mass Mail' LIMIT 1];
        ucinn_ascendv2__Service_Indicator_Value__c childSiv = [SELECT Id FROM ucinn_ascendv2__Service_Indicator_Value__c WHERE Name = 'No Hamilton Magazine' LIMIT 1];

        // Create an existing Active Suppression Record
        ucinn_ascendv2__Service_Indicator__c activeInd = new ucinn_ascendv2__Service_Indicator__c(
            ucinn_ascendv2__Contact__c = con.Id,
            ucinn_ascendv2__Service_Indicator_Value__c = siv.Id,
            ucinn_ascendv2__Start_Date__c = System.today(),
            ucinn_ascendv2__Is_Active__c = true
        );
        insert activeInd;

        Test.startTest();
        Ham_PreferenceController.PreferenceDataDTO result = Ham_PreferenceController.getPreferences(con.Id);
        Test.stopTest();

        // Assertions
        System.assertNotEquals(null, result, 'Result DTO should not be null');
        System.assertEquals(2, result.items.size(), 'Should return 2 config items created in setup');
        
        // Verify Parent Mapping Coverage (Now checking IDs instead of UI Keys)
        Boolean foundParentKey = false;
        for(Ham_PreferenceController.SIVWrapper wrapper : result.items) {
            if(wrapper.id == childSiv.Id && wrapper.parentId == siv.Id) {
                foundParentKey = true;
            }
        }
        System.assert(foundParentKey, 'The child record should correctly identify the parent record ID');

        // Verify Active State (Now tracking IDs)
        System.assertEquals(1, result.activeIndicatorIds.size(), 'Should have 1 active indicator');
        System.assertEquals(siv.Id, result.activeIndicatorIds[0], 'Active indicator should be identified by its Record ID');
    }

    /**
     * @description Tests savePreferences when user Opts OUT (Toggle = False).
     * SUPPRESSION LOGIC: Should INSERT a new Service Indicator record.
     */
    @isTest
    static void testSavePreferences_OptOut_InsertsRecord() {
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        ucinn_ascendv2__Service_Indicator_Value__c childSiv = [SELECT Id FROM ucinn_ascendv2__Service_Indicator_Value__c WHERE Name = 'No Hamilton Magazine' LIMIT 1];
        
        // Prepare map: User toggles 'Hamilton Magazine' to False (Opt-Out) passing the ID
        Map<String, Boolean> changes = new Map<String, Boolean>();
        changes.put(childSiv.Id, false);

        Test.startTest();
        Ham_PreferenceController.savePreferences(changes, con.Id);
        Test.stopTest();

        // Verify Record Creation
        List<ucinn_ascendv2__Service_Indicator__c> indicators = [
            SELECT Id, ucinn_ascendv2__Is_Active__c, ucinn_ascendv2__Service_Indicator_Value__c 
            FROM ucinn_ascendv2__Service_Indicator__c 
            WHERE ucinn_ascendv2__Contact__c = :con.Id
        ];

        System.assertEquals(1, indicators.size(), 'One suppression record should be created');
        System.assertEquals(childSiv.Id, indicators[0].ucinn_ascendv2__Service_Indicator_Value__c, 'Should be linked to correct backend ID');
        System.assertEquals(true, indicators[0].ucinn_ascendv2__Is_Active__c, 'Record should be active');
    }

    /**
     * @description Tests savePreferences when user Opts IN (Toggle = True).
     * SUPPRESSION LOGIC: Should UPDATE the existing record with an End Date.
     */
    @isTest
    static void testSavePreferences_OptIn_EndDatesRecord() {
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        ucinn_ascendv2__Service_Indicator_Value__c siv = [SELECT Id FROM ucinn_ascendv2__Service_Indicator_Value__c WHERE Name = 'No Contact Mass Mail' LIMIT 1];

        // 1. Setup: Create an existing Active suppression record
        ucinn_ascendv2__Service_Indicator__c activeInd = new ucinn_ascendv2__Service_Indicator__c(
            ucinn_ascendv2__Contact__c = con.Id,
            ucinn_ascendv2__Service_Indicator_Value__c = siv.Id,
            ucinn_ascendv2__Start_Date__c = System.today().addDays(-5),
            ucinn_ascendv2__Is_Active__c = true
        );
        insert activeInd;

        // 2. Prepare changes: User toggles 'Mail' to True (Opt-In) via ID
        Map<String, Boolean> changes = new Map<String, Boolean>();
        changes.put(siv.Id, true);

        Test.startTest();
        Ham_PreferenceController.savePreferences(changes, con.Id);
        Test.stopTest();

        // 3. Verify Update (End Date should be populated)
        ucinn_ascendv2__Service_Indicator__c updatedInd = [
            SELECT Id, ucinn_ascendv2__End_Date__c 
            FROM ucinn_ascendv2__Service_Indicator__c 
            WHERE Id = :activeInd.Id
        ];

        System.assertEquals(System.today(), updatedInd.ucinn_ascendv2__End_Date__c, 'End Date should be set to today to remove suppression');
    }

    /**
     * @description Tests error handling scenarios (Null inputs, Exception handling).
     */
    @isTest
    static void testErrorHandling() {
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        ucinn_ascendv2__Service_Indicator_Value__c siv = [SELECT Id FROM ucinn_ascendv2__Service_Indicator_Value__c LIMIT 1];

        Test.startTest();

        // 1. Test Null Map (Should return gracefully without exception)
        try {
            Ham_PreferenceController.savePreferences(null, con.Id);
            System.assert(true, 'Null map handled gracefully');
        } catch (Exception e) {
            System.assert(false, 'Should not throw exception on null map');
        }

        // 2. Test Null Contact ID (Should throw AuraHandledException)
        try {
            Map<String, Boolean> changes = new Map<String, Boolean>{siv.Id => false};
            Ham_PreferenceController.savePreferences(changes, null);
            System.assert(false, 'Should have thrown exception for null contact');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Script-thrown exception'), 'Exception message mismatch');
        }
        
        Test.stopTest();
    }
}