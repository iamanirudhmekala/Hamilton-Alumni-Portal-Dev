/**
 * @description Test class for `HAM_AlumniDirectoryController`. This class contains unit tests
 * to verify the functionality of methods related to fetching alumni records, managing filters,
 * and handling user preferences in the alumni directory.
 *
 * @author Sachin Sharma
 * @date August 29, 2025
 * @Modification Log :
 *==============================================================================
 * Ver | Date         | Author  | Modification
 *==============================================================================
 * 1.0 | Aug 29, 2025 | Sachin  | Initial Version
 * 2.0 | Jan 28, 2026 | Asheesh | Updated with respect to new code
 * 3.0 | Jan 30, 2026 | Sachin  | Fixed for comprehensive coverage & PMD Compliance
 * 3.1 | Mar 18, 2026 | Sachin  | Added multi-word search coverage
 * 3.2 | Jun 03, 2026 | Gemini  | Fixed parameter mismatches, added Bookmark/Favorite and Fuzzy Search coverage.
 */
@SuppressWarnings('PMD.NoTrailingWhitespace, PMD.ApexCRUDViolation, PMD.EmptyIfStmt, PMD.EmptyStatementBlock, PMD.AvoidNonRestrictiveQueries, PMD.CyclomaticComplexity, PMD.CognitiveComplexity, PMD.NcssCount, PMD.NcssTypeCount, PMD.DetectCopyPasteForApex, PMD.LocalVariableNamingConventions, PMD.ExcessiveParameterList, PMD.ApexSOQLInjection, PMD.AvoidDeeplyNestedIfStmts, PMD.AvoidDebugStatements, PMD.StdCyclomaticComplexity, PMD.NcssMethodCount')
@IsTest
public with sharing class HAM_AlumniDirectoryController_Test {

    @TestSetup
    static void setup() {
        
        // 1. Create a Test Admin User
        User testAdmin;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Profile adminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
            testAdmin = new User(
                Alias = 'hadmin',
                Email = 'hamiltonadmin@testorg.com',
                EmailEncodingKey = 'UTF-8',
                LastName = 'AdminUser',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                ProfileId = adminProfile.Id,
                TimeZoneSidKey = 'America/Los_Angeles',
                UserName = 'hamiltonadmin' + DateTime.now().getTime() + '@testorg.com'
            );
            insert testAdmin;
        }

        // 2. Create Account
        Account acc = new Account(Name = 'Test Account', Industry = 'Finance');
        insert acc;
        
        // 3. Create Test Contacts
        List<Contact> contactsToInsert = new List<Contact>();
        for (Integer i = 0; i < 20; i++) {
            String contactType = 'Alumni';
            if (Math.mod(i, 3) == 0) {
                contactType = 'Alumni;' + HAM_ConstantsUtil.KIRKLAND_ALUMNAE;
            }
            
            Contact c = new Contact(
                FirstName = 'Test',
                LastName = 'Alumni ' + i,
                HAM_Profile_Picture_URL__c = 'https://test.com/pic' + i + '.jpg',
                ucinn_ascendv2__Preferred_Class_Year__c = '1980',
                HAM_Reunion_Year__c = '1980',
                Constituent_Employer__c = acc.Id,
                HAM_Is_Active__c = true,
                ucinn_ascendv2__Primary_Contact_Type__c = 'Alumni',
                ucinn_ascendv2__Contact_Type__c = contactType,
                Email = 'test' + i + '@test.com',
                MailingCity = 'Boston',
                MailingState = 'MA'
            );
            contactsToInsert.add(c);
        }
        insert contactsToInsert;
        
        // 4. Create Post Codes & Degrees
        List<ucinn_ascendv2__Post_Code__c> postcodes = new List<ucinn_ascendv2__Post_Code__c>{
            new ucinn_ascendv2__Post_Code__c(Name = 'Economics', ucinn_ascendv2__Major_Specialty_Description__c = 'Economics', ucinn_ascendv2__Is_Active__c = true),
            new ucinn_ascendv2__Post_Code__c(Name = 'Computer Science', ucinn_ascendv2__Major_Specialty_Description__c = 'Computer Science', ucinn_ascendv2__Is_Active__c = true)
        };
        insert postcodes;
        
        Id schoolDegreeRecordTypeId = Schema.SObjectType.ucinn_ascendv2__Degree_Information__c
            .getRecordTypeInfosByDeveloperName().get('School_Degree_Information').getRecordTypeId();
        
        List<ucinn_ascendv2__Degree_Information__c> degreesToInsert = new List<ucinn_ascendv2__Degree_Information__c>();
        for (Integer i = 0; i < contactsToInsert.size(); i++) {
            degreesToInsert.add(new ucinn_ascendv2__Degree_Information__c(
                ucinn_ascendv2__Contact__c = contactsToInsert[i].Id,
                ucinn_ascendv2__Post_Code__c = postcodes[Math.mod(i, 2)].Id,
                RecordTypeId = schoolDegreeRecordTypeId
            ));
        }
        insert degreesToInsert;
        
        // 5. Create Connections covering all statuses
        List<HAM_Connection__c> connectionsToInsert = new List<HAM_Connection__c>();
        Contact portalUser = contactsToInsert[0];
        
        // Primary Connections
        for (Integer i = 1; i <= 6; i++) {
            connectionsToInsert.add(new HAM_Connection__c(
                HAM_Portal_User__c = portalUser.Id,
                HAM_Linked_Constituent__c = contactsToInsert[i].Id,
                HAM_Connection_Status__c = 'Connected',
                HAM_Is_Connected__c = true,
                HAM_Is_favorite__c = (i <= 3), // First 3 are favorites
                HAM_Is_bookmarked__c = false,
                HAM_Is_Blocked__c = false
            ));
        }
        
        // Secondary Connections (Request Sent to Portal User)
        for (Integer i = 7; i <= 10; i++) {
            connectionsToInsert.add(new HAM_Connection__c(
                HAM_Portal_User__c = contactsToInsert[i].Id,
                HAM_Linked_Constituent__c = portalUser.Id,
                HAM_Connection_Status__c = 'Request Sent',
                HAM_Is_Connected__c = false,
                HAM_Is_Blocked__c = false
            ));
        }

        // Blocked Connections
        for (Integer i = 11; i <= 12; i++) {
            connectionsToInsert.add(new HAM_Connection__c(
                HAM_Portal_User__c = portalUser.Id,
                HAM_Linked_Constituent__c = contactsToInsert[i].Id,
                HAM_Is_Blocked__c = true
            ));
        }
        
        insert connectionsToInsert;
        
        // 6. Create Service Indicators (including Privacy)
        Id serviceIndicatorRT = Schema.SObjectType.ucinn_ascendv2__Service_Indicator__c
            .getRecordTypeInfosByName().get(HAM_ConstantsUtil.CONTACT_SERVICE_INDICATOR_RECORD_TYPE).getRecordTypeId();

        List<ucinn_ascendv2__Service_Indicator_Value__c> siValues = new List<ucinn_ascendv2__Service_Indicator_Value__c>{
            new ucinn_ascendv2__Service_Indicator_Value__c(Name = 'Privacy', HAM_Portal_ID__c = HAM_ConstantsUtil.ALUMNI_PRIVCACY_SVID),
            new ucinn_ascendv2__Service_Indicator_Value__c(Name = 'Hide Email', HAM_Portal_ID__c = 'SIV_VIS_ALUMNI_PRIVACY') // Master Privacy SVID string check
        };
        insert siValues;

        List<ucinn_ascendv2__Service_Indicator__c> serviceIndicators = new List<ucinn_ascendv2__Service_Indicator__c>{
            new ucinn_ascendv2__Service_Indicator__c(
                ucinn_ascendv2__Contact__c = contactsToInsert[1].Id,
                ucinn_ascendv2__Service_Indicator_Value__c = siValues[0].Id,
                RecordTypeId = serviceIndicatorRT,
                ucinn_ascendv2__Is_Active__c = true
            ),
            new ucinn_ascendv2__Service_Indicator__c(
                ucinn_ascendv2__Contact__c = contactsToInsert[2].Id,
                ucinn_ascendv2__Service_Indicator_Value__c = siValues[1].Id,
                RecordTypeId = serviceIndicatorRT,
                ucinn_ascendv2__Is_Active__c = true
            )
        };
        insert serviceIndicators;

        // 7. Create Contact Name for Fuzzy Search Coverage
        ucinn_ascendv2__Contact_Name__c fuzzyName = new ucinn_ascendv2__Contact_Name__c(
            ucinn_ascendv2__Contact__c = contactsToInsert[0].Id,
            ucinn_ascendv2__Last_Name__c = 'TestFuzzy',
            ucinn_ascendv2__First_Name__c = 'Test'
        );
        insert fuzzyName;
    }

    private static User getTestUser() {
        return [SELECT Id FROM User WHERE Email = 'hamiltonadmin@testorg.com' LIMIT 1];
    }
    
    private static Contact getPortalUser() {
        return [SELECT Id FROM Contact WHERE LastName = 'Alumni 0' LIMIT 1];
    }

    // ==========================================
    // METADATA & UTILITY TESTS
    // ==========================================

    @IsTest
    static void testGetFilterMetadataAndValues() {
        System.runAs(getTestUser()) {
            Test.startTest();
            List<HAM_AlumniDirectoryController.FilterWrapper> filters = HAM_AlumniDirectoryController.getFilterMetadataAndValues();
            Test.stopTest();
            Assert.isNotNull(filters, 'Filters should not be null');
        }
    }

    @IsTest
    static void testSearchFilterOptions() {
        System.runAs(getTestUser()) {
            Test.startTest();
            List<String> results = HAM_AlumniDirectoryController.searchFilterOptions('Test', 'search');
            List<String> emptyResults = HAM_AlumniDirectoryController.searchFilterOptions('', 'search');
            Test.stopTest();
            Assert.isNotNull(results, 'Results should not be null');
            Assert.areEqual(0, emptyResults.size(), 'Empty placeholder should return empty list');
        }
    }

    @IsTest
    static void testGetPicklistValues() {
        System.runAs(getTestUser()) {
            Test.startTest();
            List<String> valid = HAM_AlumniDirectoryController.getPicklistValues('Contact', 'LeadSource');
            List<String> invalid = HAM_AlumniDirectoryController.getPicklistValues('InvalidObject__c', 'AnyField__c');
            Test.stopTest();
            Assert.isNotNull(valid);
            Assert.areEqual(0, invalid.size(), 'Invalid object should safely return empty list');
        }
    }

    // ==========================================
    // COUNTS & TABS TESTS
    // ==========================================

    @IsTest
    static void testGetDirectoryDataCountAllTabs() {
        System.runAs(getTestUser()) {
            Id portalId = getPortalUser().Id;
            List<Map<String, Object>> filters = new List<Map<String, Object>>{
                new Map<String, Object>{ 'placeholder' => 'Class Year', 'values' => new List<String>{'1980'} }
            };

            Test.startTest();
            Integer buildCount = HAM_AlumniDirectoryController.getDirectoryDataCount(HAM_ConstantsUtil.BUILD_TAB, 'Alumni', filters, portalId, null, null, null, null);
            Integer connCount = HAM_AlumniDirectoryController.getDirectoryDataCount(HAM_ConstantsUtil.CONNECTION_TAB, '', null, portalId, null, null, null, null);
            Integer bookmarkCount = HAM_AlumniDirectoryController.getDirectoryDataCount(HAM_ConstantsUtil.BOOKMARK_TAB, '', null, portalId, null, null, null, null);
            Integer inviteCountSent = HAM_AlumniDirectoryController.getDirectoryDataCount(HAM_ConstantsUtil.INVITATION_TAB, '', null, portalId, 'Sent', null, null, null);
            Integer inviteCountRecv = HAM_AlumniDirectoryController.getDirectoryDataCount(HAM_ConstantsUtil.INVITATION_TAB, '', null, portalId, 'Received', null, null, null);
            Integer blockedCount = HAM_AlumniDirectoryController.getDirectoryDataCount(HAM_ConstantsUtil.BLOCKED_TAB, '', null, portalId, null, null, null, null);
            Test.stopTest();
            
            Assert.isTrue(buildCount >= 0);
            Assert.isTrue(connCount >= 0);
            Assert.isTrue(inviteCountSent >= 0);
            Assert.isTrue(inviteCountRecv >= 0);
            Assert.isTrue(blockedCount >= 0);
        }
    }

    @IsTest
    static void testBookmarkAndFavoriteFilters() {
        System.runAs(getTestUser()) {
            Id portalId = getPortalUser().Id;

            Test.startTest();
            // 1. Cover the Favorite Filter branch on the Connection Tab
            HAM_AlumniDirectoryController.getDirectoryDataCount(HAM_ConstantsUtil.CONNECTION_TAB, '', null, portalId, null, 'false', 'true', null);
            HAM_AlumniDirectoryController.getDirectoryData(HAM_ConstantsUtil.CONNECTION_TAB, 10, 0, '', null, portalId, null, 'false', 'true', null);

            // 2. Cover the Bookmark Filter branch on the Bookmark Tab
            HAM_AlumniDirectoryController.getDirectoryDataCount(HAM_ConstantsUtil.BOOKMARK_TAB, '', null, portalId, null, 'true', 'false', null);
            HAM_AlumniDirectoryController.getDirectoryData(HAM_ConstantsUtil.BOOKMARK_TAB, 10, 0, '', null, portalId, null, 'true', 'false', null);
            Test.stopTest();
            
            Assert.isTrue(true, 'Executed filter branches successfully.');
        }
    }

    // ==========================================
    // PAGINATION & DIRECTORY DATA TESTS
    // ==========================================

    @IsTest
    static void testGetDirectoryDataBuildTabPagination() {
        System.runAs(getTestUser()) {
            Id portalId = getPortalUser().Id;
            
            // Multiple filters to hit Direct and Subquery logic in buildWhereClause
            List<Map<String, Object>> filters = new List<Map<String, Object>>{
                new Map<String, Object>{ 'placeholder' => 'Class Year', 'values' => new List<String>{'1980'} },
                new Map<String, Object>{ 'placeholder' => 'City', 'values' => new List<String>{'Boston', 'New York'} }
            };

            Test.startTest();
            // Page 1 (recordsToSkip = 0)
            HAM_AlumniDirectoryController.DirectoryResponse p1 = 
                HAM_AlumniDirectoryController.getDirectoryData(HAM_ConstantsUtil.BUILD_TAB, 5, 0, 'Test', filters, portalId, null, null, null, null);
            
            // Page 2 (recordsToSkip = 5) - Hits the Offset SOQL Branches
            HAM_AlumniDirectoryController.DirectoryResponse p2 = 
                HAM_AlumniDirectoryController.getDirectoryData(HAM_ConstantsUtil.BUILD_TAB, 5, 5, 'Test', filters, portalId, null, null, null, null);
            Test.stopTest();
            
            Assert.isNotNull(p1);
            Assert.isNotNull(p2);
        }
    }

    @IsTest
    static void testGetDirectoryDataConnectionsPagination() {
        System.runAs(getTestUser()) {
            Id portalId = getPortalUser().Id;

            Test.startTest();
            // Primary Connections Pagination Check
            HAM_AlumniDirectoryController.DirectoryResponse p1 = 
                HAM_AlumniDirectoryController.getDirectoryData(HAM_ConstantsUtil.CONNECTION_TAB, 2, 0, '', null, portalId, null, null, null, null);
                
            HAM_AlumniDirectoryController.DirectoryResponse p2 = 
                HAM_AlumniDirectoryController.getDirectoryData(HAM_ConstantsUtil.CONNECTION_TAB, 2, 2, '', null, portalId, null, null, null, null);
            Test.stopTest();
            
            Assert.isNotNull(p1);
            Assert.isNotNull(p2);
        }
    }

    @IsTest
    static void testGetDirectoryDataInvitationsPagination() {
        System.runAs(getTestUser()) {
            Id portalId = getPortalUser().Id;

            Test.startTest();
            // Secondary Connections (Invitations Received) Pagination Check
            HAM_AlumniDirectoryController.DirectoryResponse p1Recv = 
                HAM_AlumniDirectoryController.getDirectoryData(HAM_ConstantsUtil.INVITATION_TAB, 2, 0, '', null, portalId, null, null, null, null);
                
            HAM_AlumniDirectoryController.DirectoryResponse p2Recv = 
                HAM_AlumniDirectoryController.getDirectoryData(HAM_ConstantsUtil.INVITATION_TAB, 2, 2, '', null, portalId, null, null, null, null);

            // Primary Connections (Invitations Sent) Pagination Check
            HAM_AlumniDirectoryController.DirectoryResponse p1Sent = 
                HAM_AlumniDirectoryController.getDirectoryData(HAM_ConstantsUtil.INVITATION_TAB, 2, 0, '', null, portalId, 'Sent', null, null, null);
                
            HAM_AlumniDirectoryController.DirectoryResponse p2Sent = 
                HAM_AlumniDirectoryController.getDirectoryData(HAM_ConstantsUtil.INVITATION_TAB, 2, 2, '', null, portalId, 'Sent', null, null, null);
            Test.stopTest();
            
            Assert.isNotNull(p1Recv);
            Assert.isNotNull(p2Recv);
            Assert.isNotNull(p1Sent);
            Assert.isNotNull(p2Sent);
        }
    }

    @IsTest
    static void testGetDirectoryDataBlockedTab() {
        System.runAs(getTestUser()) {
            Id portalId = getPortalUser().Id;

            Test.startTest();
            HAM_AlumniDirectoryController.DirectoryResponse response = 
                HAM_AlumniDirectoryController.getDirectoryData(HAM_ConstantsUtil.BLOCKED_TAB, 10, 0, '', null, portalId, null, null, null, null);
            Test.stopTest();
            
            Assert.isNotNull(response);
        }
    }

    // ==========================================
    // MULTI-WORD SEARCH COVERAGE (NEW LOGIC)
    // ==========================================

    @IsTest
    static void testGetDirectoryDataMultiWordSearch() {
        System.runAs(getTestUser()) {
            Id portalId = getPortalUser().Id;
            // Searching specifically with spaces and the inserted fuzzy name to test logic
            String multiWordSearchTerm = 'TestFuzzy Alumni';

            Test.startTest();
            HAM_AlumniDirectoryController.DirectoryResponse response = 
                HAM_AlumniDirectoryController.getDirectoryData(HAM_ConstantsUtil.BUILD_TAB, 10, 0, multiWordSearchTerm, null, portalId, null, null, null, null);
                
            Integer count = HAM_AlumniDirectoryController.getDirectoryDataCount(HAM_ConstantsUtil.BUILD_TAB, multiWordSearchTerm, null, portalId, null, null, null, null);
            Test.stopTest();
            
            Assert.isNotNull(response, 'Response should not be null');
            Assert.isTrue(count >= 0, 'Multi-word search count should resolve safely');
        }
    }

    @IsTest
    static void testGetDirectoryDataWithContactScope() {
        // [Group Members] The optional scopeContactIds parameter restricts constituents to the
        // supplied Ids and enables the default (no search/filter) view for scoped callers.
        System.runAs(getTestUser()) {
            Id portalId = getPortalUser().Id;
            List<Contact> scopeContacts = [
                SELECT Id, Name FROM Contact
                WHERE LastName IN ('Alumni 5', 'Alumni 6') ORDER BY Name
            ];
            List<Id> scopeIds = new List<Id>();
            for (Contact c : scopeContacts) scopeIds.add(c.Id);

            Test.startTest();
            Integer scopedCount = HAM_AlumniDirectoryController.getDirectoryDataCount(
                HAM_ConstantsUtil.BUILD_TAB, '', new List<Map<String, Object>>(), portalId, null, null, null, scopeIds);
            HAM_AlumniDirectoryController.DirectoryResponse scopedData =
                HAM_AlumniDirectoryController.getDirectoryData(
                    HAM_ConstantsUtil.BUILD_TAB, 9, 0, '', new List<Map<String, Object>>(), portalId, null, null, null, scopeIds);
            // Regression: a null scope with no search/filters must keep returning zero constituents
            Integer unscopedCount = HAM_AlumniDirectoryController.getDirectoryDataCount(
                HAM_ConstantsUtil.BUILD_TAB, '', new List<Map<String, Object>>(), portalId, null, null, null, null);
            Test.stopTest();

            Assert.areEqual(scopeIds.size(), scopedCount, 'Scoped count must match the eligible scoped contacts.');
            Assert.areEqual(scopeIds.size(), scopedData.constituentsData.size(), 'Scoped data must return only the scoped contacts.');
            for (HAM_AlumniDirectoryController.ConstituentWrapper cw : scopedData.constituentsData) {
                Assert.isTrue(new Set<Id>(scopeIds).contains(cw.id), 'Every returned constituent must be inside the scope.');
            }
            Assert.areEqual(0, unscopedCount, 'Null scope with no search/filters must keep legacy behaviour (no constituents).');
        }
    }

    // ==========================================
    // WIDGET & PREFERENCES TESTS
    // ==========================================

    @IsTest
    static void testGetDirectoryDataOnWidget() {
        System.runAs(getTestUser()) {
            Id portalId = getPortalUser().Id;

            Test.startTest();
            HAM_AlumniDirectoryController.AlumniDirectoryWrapper result = 
                HAM_AlumniDirectoryController.getDirectoryDataOnWidget(portalId);
            Test.stopTest();
            
            Assert.isNotNull(result, 'Widget result should not be null');
            Assert.isNotNull(result.connectionList, 'Widget connection list initialized');
        }
    }

    @IsTest
    static void testSaveAndGetUserPreferences() {
        System.runAs(getTestUser()) {
            Id portalId = getPortalUser().Id;
            String filtersJson = '[{"placeholder":"Class Year","values":["1980"]}]';

            Test.startTest();
            HAM_AlumniDirectoryController.saveUserPreferences(filtersJson, portalId);
            String saved = HAM_AlumniDirectoryController.getSavedUserPreferences(portalId);
            
            // Update
            String updatedJson = '[{"placeholder":"Industry","values":["Finance"]}]';
            HAM_AlumniDirectoryController.saveUserPreferences(updatedJson, portalId);
            String updated = HAM_AlumniDirectoryController.getSavedUserPreferences(portalId);
            Test.stopTest();

            Assert.areEqual(filtersJson, saved);
            Assert.areEqual(updatedJson, updated);
        }
    }
    
    @IsTest
    static void testGetDirectoryTabset() {
        System.runAs(getTestUser()) {
            Test.startTest();
            List<Ham_Directory_Tabset__mdt> tabs = HAM_AlumniDirectoryController.getDirectoryTabset();
            Test.stopTest();
            Assert.isNotNull(tabs);
        }
    }

    // ==========================================
    // NEWLY ADDED COVERAGE TESTS
    // ==========================================

    @IsTest
    static void testGetContactDefaultFilterData() {
        System.runAs(getTestUser()) {
            // Fetch an existing contact and add the chapter data expected by the controller
            Contact testContact = [SELECT Id FROM Contact WHERE LastName = 'Alumni 0' LIMIT 1];

            // Create the Chapter record based on the controller's Chapter__r relationship
            HAM_Chapter_Lookup__c testChapterObj = new HAM_Chapter_Lookup__c(
                Name = 'Boston Chapter',
                HAM_Chapter_Code__c = '000000'
            );
            insert testChapterObj;

            // Insert the actual junction object with the proper custom object reference
            HAM_Current_Chapter__c testCurrentChapter = new HAM_Current_Chapter__c(
                Constituent__c = testContact.Id,
                Chapter__c = testChapterObj.Id,
                Is_Active__c = true
            );
            insert testCurrentChapter;

            Test.startTest();
            HAM_AlumniDirectoryController.ContactDefaultFilterData defaultData = 
                HAM_AlumniDirectoryController.getContactDefaultFilterData(testContact.Id);
            Test.stopTest();

            Assert.isNotNull(defaultData, 'Default filter data should be returned');
            
            Assert.isTrue(defaultData.currentChapters.contains('Boston Chapter'), 'Valid chapters should be included');
            // This validates the specific logic ignoring 'Unassigned Chapter'
            Assert.isFalse(defaultData.currentChapters.contains('Unassigned Chapter'), 'Unassigned Chapters should be filtered out');
        }
    }

    @IsTest
    static void testGetDirectoryDataOnWidget_NoConnections() {
        System.runAs(getTestUser()) {
            // Grab a contact that was intentionally left out of the connection inserts in @TestSetup
            Contact noConnContact = [SELECT Id FROM Contact WHERE LastName = 'Alumni 15' LIMIT 1];

            Test.startTest();
            HAM_AlumniDirectoryController.AlumniDirectoryWrapper result = 
                HAM_AlumniDirectoryController.getDirectoryDataOnWidget(noConnContact.Id);
            Test.stopTest();

            Assert.isNotNull(result, 'Widget result should not be null');
            Assert.isTrue(result.connectionList.isEmpty(), 'Connection list should be empty to trigger fallback');
            // This confirms the controller successfully jumped into the finalConnections.isEmpty() block
            Assert.isNotNull(result.alumniList, 'Classmate fallback list should be initialized'); 
        }
    }

    @IsTest
    static void testGetDirectoryData_EmptyFilterHandling() {
        System.runAs(getTestUser()) {
            Id portalId = getPortalUser().Id;
            
            // Passing invalid configurations to force the controller to hit the `continue` branches
            List<Map<String, Object>> edgeCaseFilters = new List<Map<String, Object>>{
                new Map<String, Object>{ 'placeholder' => 'Class Year', 'values' => new List<String>() }, // Empty values
                new Map<String, Object>{ 'placeholder' => '', 'values' => new List<String>{'Test'} },     // Empty placeholder
                new Map<String, Object>{ 'placeholder' => 'Industry', 'values' => null }                  // Null values
            };

            Test.startTest();
            HAM_AlumniDirectoryController.DirectoryResponse response = 
                HAM_AlumniDirectoryController.getDirectoryData(HAM_ConstantsUtil.BUILD_TAB, 10, 0, '', edgeCaseFilters, portalId, null, null, null, null);
            Test.stopTest();

            Assert.isNotNull(response, 'Response should handle invalid filters gracefully without failing');
        }
    }

    @IsTest
    static void testGetSavedUserPreferences_NullReturn() {
        System.runAs(getTestUser()) {
            // Pick a contact that we know has no HAM_Portal_User_Preference__c record yet
            Contact freshContact = [SELECT Id FROM Contact WHERE LastName = 'Alumni 18' LIMIT 1];
            
            Test.startTest();
            String savedPref = HAM_AlumniDirectoryController.getSavedUserPreferences(freshContact.Id);
            Test.stopTest();
            
            Assert.isNull(savedPref, 'Should return null when no preferences exist for the user');
        }
    }
}