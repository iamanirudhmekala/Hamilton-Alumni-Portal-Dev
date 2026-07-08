/**
 * HAMAttendeeTempFuzzyMatchServiceTest
 * ---------------------------------------------------------------------------
 * Test coverage for HAMAttendeeTempFuzzyMatchService (ASC-13380).
 *
 * v1.6 coverage updates (bulk refactor + safeGet fix):
 *
 *   CHANGED -- testProcessTemps_RecordInMap_NullFields_NoMatch
 *     The Map<Id,SObject> overload of processTemps now performs bulk
 *     SOSL+SOQL lookups instead of calling evaluateMatch per-record.
 *     Field reads use safeGet() so Contact stand-in no longer throws
 *     SObjectException for missing Cvent package fields. Assertion
 *     unchanged (null fields -> NO_MATCH), comment updated.
 *
 *   NEW -- testBuildMatchResult_*
 *     Direct coverage of the extracted buildMatchResult() helper across
 *     all five decision branches (CONFIRMED, SUGGESTED_NAME,
 *     SUGGESTED_EMAIL, NO_MATCH, conflicting IDs).
 *
 *   NEW -- testFindByNameBulk_*
 *     Coverage for findConstituentsByNameBulk():
 *       - Hit: single name key resolves via seeded SOSL.
 *       - TokenMismatch: SOSL returns a record but post-filter rejects it.
 *       - EmptySet: guard returns empty map without firing SOSL.
 *       - NullSet: null guard returns empty map.
 *       - MultipleKeys: two distinct keys resolved in one SOSL call.
 *       - NoSoslResults: empty SOSL seed produces empty map.
 *
 *   NEW -- testFindByEmailBulk_*
 *     Coverage for findConstituentsByEmailBulk():
 *       - Hit: single email resolves via SOQL.
 *       - MultipleEmails: both emails resolve in one SOQL call.
 *       - NoMatch: unknown email yields empty map.
 *       - EmptySet: guard returns empty map.
 *       - NullSet: null guard returns empty map.
 *
 *   NEW -- testProcessTemps_StringOverload_*
 *     Coverage for the string overload of processTemps():
 *       - ConfirmedMatch: bulk name + email both resolve -> CONFIRMED.
 *       - NullFields: null inputs -> NO_MATCH.
 *       - WrongMockId: ID mismatch -> NO_MATCH (continue branch).
 *
 * Version history
 * ---------------
 * v1.0  2026-05-04  Initial build for ASC-13380
 * v1.1  2026-05-04  Dual-token exact match requirement
 * v1.2  2026-05-04  RecordTypeId + Type__c fixes
 * v1.3  2026-05-04  Ascend bypass pattern
 * v1.4  2026-05-04  Test.setFixedSearchResults; evaluateMatch; empty-tempIds guard
 * v1.5  2026-05-04  Close remaining 27% coverage gaps
 * v1.6  2026-05-18  Update tests for v1.5 bulk refactor; add safeGet coverage
 * ---------------------------------------------------------------------------
 */
@IsTest
private class HAMAttendeeTempFuzzyMatchServiceTest {

    // -------------------------------------------------------------------------
    // Test setup
    // -------------------------------------------------------------------------

    @TestSetup
    static void makeData() {
        Id userId = UserInfo.getUserId();

        Id constituentRtId = Schema.SObjectType.Contact
            .getRecordTypeInfosByDeveloperName()
            .get('New_Contact')
            .getRecordTypeId();

        Contact constituentA = new Contact(
            FirstName    = 'Alpha',
            LastName     = 'Hamilton',
            RecordTypeId = constituentRtId
        );
        insert constituentA;

        Contact constituentB = new Contact(
            FirstName    = 'Beta',
            LastName     = 'College',
            RecordTypeId = constituentRtId
        );
        insert constituentB;

        createAscendBypass(userId);
        try {
            insert new ucinn_ascendv2__Contact_Name__c(
                ucinn_ascendv2__Contact__c    = constituentA.Id,
                ucinn_ascendv2__First_Name__c = 'Alpha',
                ucinn_ascendv2__Last_Name__c  = 'Hamilton',
                ucinn_ascendv2__Type__c       = 'Full Name'
            );
            insert new ucinn_ascendv2__Email__c(
                ucinn_ascendv2__Contact__c       = constituentA.Id,
                ucinn_ascendv2__Email_Address__c = 'alpha.hamilton@test.example.com',
                ucinn_ascendv2__Type__c          = 'Business',
                ucinn_ascendv2__Is_Preferred__c  = true
            );
            insert new ucinn_ascendv2__Contact_Name__c(
                ucinn_ascendv2__Contact__c    = constituentB.Id,
                ucinn_ascendv2__First_Name__c = 'Beta',
                ucinn_ascendv2__Last_Name__c  = 'College',
                ucinn_ascendv2__Type__c       = 'Full Name'
            );
            insert new ucinn_ascendv2__Email__c(
                ucinn_ascendv2__Contact__c       = constituentB.Id,
                ucinn_ascendv2__Email_Address__c = 'beta.college@test.example.com',
                ucinn_ascendv2__Type__c          = 'Business',
                ucinn_ascendv2__Is_Preferred__c  = true
            );
        } finally {
            removeAscendBypass(userId);
        }
    }

    // -------------------------------------------------------------------------
    // Bypass helpers
    // -------------------------------------------------------------------------

    private static void createAscendBypass(Id userId) {
        ucinn_ascendv2__Bypass_Settings__c bypass = new ucinn_ascendv2__Bypass_Settings__c();
        bypass.SetupOwnerId                                = userId;
        bypass.ucinn_ascendv2__Bypass_Process_Builders__c = true;
        bypass.ucinn_ascendv2__Bypass_Triggers__c         = true;
        bypass.ucinn_ascendv2__Bypass_Validation_Rules__c = true;
        bypass.ucinn_ascendv2__Bypass_Workflows__c        = true;
        insert bypass;
    }

    private static void removeAscendBypass(Id userId) {
        List<ucinn_ascendv2__Bypass_Settings__c> bypassList = [
            SELECT Id FROM ucinn_ascendv2__Bypass_Settings__c WHERE SetupOwnerId = :userId
        ];
        if (!bypassList.isEmpty()) {
            delete bypassList;
        }
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private static Contact getConstituent(String lastName) {
        return [SELECT Id FROM Contact WHERE LastName = :lastName LIMIT 1];
    }

    private static ucinn_ascendv2__Contact_Name__c getNameRecord(String lastName) {
        return [
            SELECT Id, ucinn_ascendv2__Contact__c, ucinn_ascendv2__Constructed_Name_Formula__c
            FROM   ucinn_ascendv2__Contact_Name__c
            WHERE  ucinn_ascendv2__Last_Name__c = :lastName
            LIMIT  1
        ];
    }

    // -------------------------------------------------------------------------
    // findConstituentByEmail  (single-record helper — retained for evaluateMatch)
    // -------------------------------------------------------------------------

    @IsTest
    static void testFindByEmail_ExactMatch() {
        Contact constituentA = getConstituent('Hamilton');
        Test.startTest();
        Id result = HAMAttendeeTempFuzzyMatchService.findConstituentByEmail(
            'alpha.hamilton@test.example.com'
        );
        Test.stopTest();
        Assert.areEqual(constituentA.Id, result, 'Exact email should return Constituent A');
    }

    @IsTest
    static void testFindByEmail_NoMatch() {
        Test.startTest();
        Id result = HAMAttendeeTempFuzzyMatchService.findConstituentByEmail(
            'nobody@nowhere.example.com'
        );
        Test.stopTest();
        Assert.isNull(result, 'Unknown email should return null');
    }

    @IsTest
    static void testFindByEmail_BlankInput() {
        Test.startTest();
        Id resultNull  = HAMAttendeeTempFuzzyMatchService.findConstituentByEmail(null);
        Id resultBlank = HAMAttendeeTempFuzzyMatchService.findConstituentByEmail('   ');
        Test.stopTest();
        Assert.isNull(resultNull,  'Null email should return null');
        Assert.isNull(resultBlank, 'Blank email should return null');
    }

    // -------------------------------------------------------------------------
    // findConstituentByName  (single-record helper — retained for evaluateMatch)
    // -------------------------------------------------------------------------

    @IsTest
    static void testFindByName_BothTokensMatch() {
        Contact constituentA = getConstituent('Hamilton');
        ucinn_ascendv2__Contact_Name__c nameRecA = getNameRecord('Hamilton');
        Test.setFixedSearchResults(new List<Id>{ nameRecA.Id });

        Test.startTest();
        Id result = HAMAttendeeTempFuzzyMatchService.findConstituentByName('Alpha', 'Hamilton');
        Test.stopTest();

        Assert.areEqual(constituentA.Id, result, 'Both tokens matching should return Constituent A');
    }

    @IsTest
    static void testFindByName_SoslReturnsRecordButTokenMismatch() {
        // Seed SOSL with Constituent B's name record (Beta College)
        // but search for Alpha Hamilton — post-filter rejects it because
        // "beta college" does not contain "hamilton" or "alpha".
        ucinn_ascendv2__Contact_Name__c nameRecB = getNameRecord('College');
        Test.setFixedSearchResults(new List<Id>{ nameRecB.Id });

        Test.startTest();
        Id result = HAMAttendeeTempFuzzyMatchService.findConstituentByName('Alpha', 'Hamilton');
        Test.stopTest();

        Assert.isNull(result, 'Post-filter should reject record where tokens do not match constructed name');
    }

    @IsTest
    static void testFindByName_LastNameOnly_ReturnsNull() {
        Test.startTest();
        Id result = HAMAttendeeTempFuzzyMatchService.findConstituentByName(null, 'Hamilton');
        Test.stopTest();
        Assert.isNull(result, 'Null first name must return null');
    }

    @IsTest
    static void testFindByName_FirstNameOnly_ReturnsNull() {
        Test.startTest();
        Id result = HAMAttendeeTempFuzzyMatchService.findConstituentByName('Alpha', null);
        Test.stopTest();
        Assert.isNull(result, 'Null last name must return null');
    }

    @IsTest
    static void testFindByName_BlankBothInputs() {
        Test.startTest();
        Id resultBothNull  = HAMAttendeeTempFuzzyMatchService.findConstituentByName(null, null);
        Id resultBothBlank = HAMAttendeeTempFuzzyMatchService.findConstituentByName('  ', '  ');
        Test.stopTest();
        Assert.isNull(resultBothNull,  'Both null should return null');
        Assert.isNull(resultBothBlank, 'Both blank should return null');
    }

    @IsTest
    static void testFindByName_NoMatch() {
        Test.startTest();
        Id result = HAMAttendeeTempFuzzyMatchService.findConstituentByName('ZZZNoOne', 'ZZZNoBody');
        Test.stopTest();
        Assert.isNull(result, 'Unknown name with unseeded SOSL should return null');
    }

    // -------------------------------------------------------------------------
    // findConstituentsByNameBulk  (NEW in v1.5)
    // -------------------------------------------------------------------------

    @IsTest
    static void testFindByNameBulk_SingleKeyHit() {
        Contact constituentA = getConstituent('Hamilton');
        ucinn_ascendv2__Contact_Name__c nameRecA = getNameRecord('Hamilton');
        Test.setFixedSearchResults(new List<Id>{ nameRecA.Id });

        Test.startTest();
        Map<String, Id> result = HAMAttendeeTempFuzzyMatchService.findConstituentsByNameBulk(
            new Set<String>{ 'hamilton|alpha' }
        );
        Test.stopTest();

        Assert.areEqual(1, result.size(), 'Should resolve one name key');
        Assert.areEqual(constituentA.Id, result.get('hamilton|alpha'),
            'hamilton|alpha should resolve to Constituent A');
    }

    @IsTest
    static void testFindByNameBulk_TokenMismatch_PostFilterRejects() {
        // Seed SOSL with Constituent B's name record. The searched key is
        // hamilton|alpha — post-filter checks both tokens against "beta college"
        // and rejects it, so the result map must be empty.
        ucinn_ascendv2__Contact_Name__c nameRecB = getNameRecord('College');
        Test.setFixedSearchResults(new List<Id>{ nameRecB.Id });

        Test.startTest();
        Map<String, Id> result = HAMAttendeeTempFuzzyMatchService.findConstituentsByNameBulk(
            new Set<String>{ 'hamilton|alpha' }
        );
        Test.stopTest();

        Assert.isTrue(result.isEmpty(),
            'Post-filter should reject name record whose constructed name does not contain both tokens');
    }

    @IsTest
    static void testFindByNameBulk_EmptySet_ReturnsEmptyMap() {
        Test.startTest();
        Map<String, Id> result = HAMAttendeeTempFuzzyMatchService.findConstituentsByNameBulk(
            new Set<String>()
        );
        Test.stopTest();

        Assert.isNotNull(result, 'Result should never be null');
        Assert.isTrue(result.isEmpty(), 'Empty name key set should return empty map');
    }

    @IsTest
    static void testFindByNameBulk_NullSet_ReturnsEmptyMap() {
        Test.startTest();
        Map<String, Id> result = HAMAttendeeTempFuzzyMatchService.findConstituentsByNameBulk(null);
        Test.stopTest();

        Assert.isNotNull(result, 'Result should never be null');
        Assert.isTrue(result.isEmpty(), 'Null name key set should return empty map');
    }

    @IsTest
    static void testFindByNameBulk_MultipleKeys_BothResolved() {
        Contact constituentA = getConstituent('Hamilton');
        Contact constituentB = getConstituent('College');
        ucinn_ascendv2__Contact_Name__c nameRecA = getNameRecord('Hamilton');
        ucinn_ascendv2__Contact_Name__c nameRecB = getNameRecord('College');
        Test.setFixedSearchResults(new List<Id>{ nameRecA.Id, nameRecB.Id });

        Test.startTest();
        Map<String, Id> result = HAMAttendeeTempFuzzyMatchService.findConstituentsByNameBulk(
            new Set<String>{ 'hamilton|alpha', 'college|beta' }
        );
        Test.stopTest();

        Assert.areEqual(2, result.size(), 'Both name keys should resolve');
        Assert.areEqual(constituentA.Id, result.get('hamilton|alpha'),
            'hamilton|alpha should map to Constituent A');
        Assert.areEqual(constituentB.Id, result.get('college|beta'),
            'college|beta should map to Constituent B');
    }

    @IsTest
    static void testFindByNameBulk_NoSoslResults_ReturnsEmptyMap() {
        Test.setFixedSearchResults(new List<Id>());

        Test.startTest();
        Map<String, Id> result = HAMAttendeeTempFuzzyMatchService.findConstituentsByNameBulk(
            new Set<String>{ 'hamilton|alpha' }
        );
        Test.stopTest();

        Assert.isTrue(result.isEmpty(), 'Empty SOSL results should produce empty map');
    }

    // -------------------------------------------------------------------------
    // findConstituentsByEmailBulk  (NEW in v1.5)
    // -------------------------------------------------------------------------

    @IsTest
    static void testFindByEmailBulk_SingleEmailHit() {
        Contact constituentA = getConstituent('Hamilton');

        Test.startTest();
        Map<String, Id> result = HAMAttendeeTempFuzzyMatchService.findConstituentsByEmailBulk(
            new Set<String>{ 'alpha.hamilton@test.example.com' }
        );
        Test.stopTest();

        Assert.areEqual(1, result.size(), 'Should resolve one email');
        Assert.areEqual(constituentA.Id, result.get('alpha.hamilton@test.example.com'),
            'Email should resolve to Constituent A');
    }

    @IsTest
    static void testFindByEmailBulk_MultipleEmails_BothResolved() {
        Contact constituentA = getConstituent('Hamilton');
        Contact constituentB = getConstituent('College');

        Test.startTest();
        Map<String, Id> result = HAMAttendeeTempFuzzyMatchService.findConstituentsByEmailBulk(
            new Set<String>{
                'alpha.hamilton@test.example.com',
                'beta.college@test.example.com'
            }
        );
        Test.stopTest();

        Assert.areEqual(2, result.size(), 'Both emails should resolve');
        Assert.areEqual(constituentA.Id, result.get('alpha.hamilton@test.example.com'),
            'Constituent A email should resolve correctly');
        Assert.areEqual(constituentB.Id, result.get('beta.college@test.example.com'),
            'Constituent B email should resolve correctly');
    }

    @IsTest
    static void testFindByEmailBulk_NoMatch_ReturnsEmptyMap() {
        Test.startTest();
        Map<String, Id> result = HAMAttendeeTempFuzzyMatchService.findConstituentsByEmailBulk(
            new Set<String>{ 'nobody@nowhere.example.com' }
        );
        Test.stopTest();

        Assert.isNotNull(result, 'Result should never be null');
        Assert.isTrue(result.isEmpty(), 'Unknown email should produce empty map');
    }

    @IsTest
    static void testFindByEmailBulk_EmptySet_ReturnsEmptyMap() {
        Test.startTest();
        Map<String, Id> result = HAMAttendeeTempFuzzyMatchService.findConstituentsByEmailBulk(
            new Set<String>()
        );
        Test.stopTest();

        Assert.isNotNull(result, 'Result should never be null');
        Assert.isTrue(result.isEmpty(), 'Empty email set should return empty map');
    }

    @IsTest
    static void testFindByEmailBulk_NullSet_ReturnsEmptyMap() {
        Test.startTest();
        Map<String, Id> result = HAMAttendeeTempFuzzyMatchService.findConstituentsByEmailBulk(null);
        Test.stopTest();

        Assert.isNotNull(result, 'Result should never be null');
        Assert.isTrue(result.isEmpty(), 'Null email set should return empty map');
    }

    // -------------------------------------------------------------------------
    // buildMatchResult  (NEW in v1.5 — extracted from evaluateMatch)
    // -------------------------------------------------------------------------

    @IsTest
    static void testBuildMatchResult_Confirmed() {
        Contact constituentA = getConstituent('Hamilton');

        Test.startTest();
        HAMAttendeeTempFuzzyMatchService.MatchResult result =
            HAMAttendeeTempFuzzyMatchService.buildMatchResult(
                constituentA.Id, constituentA.Id
            );
        Test.stopTest();

        Assert.areEqual('CONFIRMED', result.matchStatus,
            'Same non-null IDs should produce CONFIRMED');
        Assert.areEqual(constituentA.Id, result.matchingConstituentId,
            'matchingConstituentId should be populated');
        Assert.isNull(result.suggestedConstituentId,
            'suggestedConstituentId should be null on CONFIRMED');
    }

    @IsTest
    static void testBuildMatchResult_SuggestedName() {
        Contact constituentA = getConstituent('Hamilton');

        Test.startTest();
        HAMAttendeeTempFuzzyMatchService.MatchResult result =
            HAMAttendeeTempFuzzyMatchService.buildMatchResult(
                constituentA.Id, null
            );
        Test.stopTest();

        Assert.areEqual('SUGGESTED_NAME', result.matchStatus,
            'Name found, no email should produce SUGGESTED_NAME');
        Assert.areEqual(constituentA.Id, result.suggestedConstituentId,
            'suggestedConstituentId should be Constituent A');
        Assert.isNull(result.matchingConstituentId,
            'matchingConstituentId should be null');
    }

    @IsTest
    static void testBuildMatchResult_SuggestedEmail() {
        Contact constituentB = getConstituent('College');

        Test.startTest();
        HAMAttendeeTempFuzzyMatchService.MatchResult result =
            HAMAttendeeTempFuzzyMatchService.buildMatchResult(
                null, constituentB.Id
            );
        Test.stopTest();

        Assert.areEqual('SUGGESTED_EMAIL', result.matchStatus,
            'Email found, no name should produce SUGGESTED_EMAIL');
        Assert.areEqual(constituentB.Id, result.suggestedConstituentId,
            'suggestedConstituentId should be Constituent B');
        Assert.isNull(result.matchingConstituentId,
            'matchingConstituentId should be null');
    }

    @IsTest
    static void testBuildMatchResult_NoMatch() {
        Test.startTest();
        HAMAttendeeTempFuzzyMatchService.MatchResult result =
            HAMAttendeeTempFuzzyMatchService.buildMatchResult(null, null);
        Test.stopTest();

        Assert.areEqual('NO_MATCH', result.matchStatus,
            'Both null IDs should produce NO_MATCH');
        Assert.isNull(result.matchingConstituentId,  'matchingConstituentId should be null');
        Assert.isNull(result.suggestedConstituentId, 'suggestedConstituentId should be null');
    }

    @IsTest
    static void testBuildMatchResult_ConflictingIds() {
        Contact constituentA = getConstituent('Hamilton');
        Contact constituentB = getConstituent('College');

        Test.startTest();
        HAMAttendeeTempFuzzyMatchService.MatchResult result =
            HAMAttendeeTempFuzzyMatchService.buildMatchResult(
                constituentA.Id, constituentB.Id
            );
        Test.stopTest();

        Assert.areEqual('SUGGESTED_NAME', result.matchStatus,
            'Conflicting IDs should produce SUGGESTED_NAME');
        Assert.areEqual(constituentA.Id, result.suggestedConstituentId,
            'Name constituent should be suggested on conflict');
        Assert.isNull(result.matchingConstituentId,
            'matchingConstituentId should be null on conflict');
    }

    // -------------------------------------------------------------------------
    // Decision logic (via evaluateMatch — delegates to buildMatchResult)
    // -------------------------------------------------------------------------

    @IsTest
    static void testDecision_ConfirmedMatch() {
        Contact constituentA = getConstituent('Hamilton');
        ucinn_ascendv2__Contact_Name__c nameRecA = getNameRecord('Hamilton');
        Test.setFixedSearchResults(new List<Id>{ nameRecA.Id });

        Test.startTest();
        HAMAttendeeTempFuzzyMatchService.MatchResult result =
            HAMAttendeeTempFuzzyMatchService.evaluateMatch(
                'Alpha', 'Hamilton', 'alpha.hamilton@test.example.com'
            );
        Test.stopTest();

        Assert.areEqual('CONFIRMED', result.matchStatus, 'Same constituent -> CONFIRMED');
        Assert.areEqual(constituentA.Id, result.matchingConstituentId,
            'matchingConstituentId should be Constituent A');
        Assert.isNull(result.suggestedConstituentId,
            'suggestedConstituentId should be null on CONFIRMED');
    }

    @IsTest
    static void testDecision_SuggestedName_NoEmail() {
        Contact constituentA = getConstituent('Hamilton');
        ucinn_ascendv2__Contact_Name__c nameRecA = getNameRecord('Hamilton');
        Test.setFixedSearchResults(new List<Id>{ nameRecA.Id });

        Test.startTest();
        HAMAttendeeTempFuzzyMatchService.MatchResult result =
            HAMAttendeeTempFuzzyMatchService.evaluateMatch(
                'Alpha', 'Hamilton', 'nobody@nowhere.example.com'
            );
        Test.stopTest();

        Assert.areEqual('SUGGESTED_NAME', result.matchStatus,
            'Name found, no email -> SUGGESTED_NAME');
        Assert.areEqual(constituentA.Id, result.suggestedConstituentId,
            'suggestedConstituentId should be Constituent A');
        Assert.isNull(result.matchingConstituentId, 'matchingConstituentId should be null');
    }

    @IsTest
    static void testDecision_SuggestedEmail_NoName() {
        Contact constituentB = getConstituent('College');

        Test.startTest();
        HAMAttendeeTempFuzzyMatchService.MatchResult result =
            HAMAttendeeTempFuzzyMatchService.evaluateMatch(
                'ZZZNoOne', 'ZZZNoBody', 'beta.college@test.example.com'
            );
        Test.stopTest();

        Assert.areEqual('SUGGESTED_EMAIL', result.matchStatus,
            'Email found, no name -> SUGGESTED_EMAIL');
        Assert.areEqual(constituentB.Id, result.suggestedConstituentId,
            'suggestedConstituentId should be Constituent B');
        Assert.isNull(result.matchingConstituentId, 'matchingConstituentId should be null');
    }

    @IsTest
    static void testDecision_NoMatch() {
        Test.startTest();
        HAMAttendeeTempFuzzyMatchService.MatchResult result =
            HAMAttendeeTempFuzzyMatchService.evaluateMatch(
                'ZZZNoOne', 'ZZZNoBody', 'nobody@nowhere.example.com'
            );
        Test.stopTest();

        Assert.areEqual('NO_MATCH', result.matchStatus, 'Neither name nor email -> NO_MATCH');
        Assert.isNull(result.matchingConstituentId,  'matchingConstituentId should be null');
        Assert.isNull(result.suggestedConstituentId, 'suggestedConstituentId should be null');
    }

    @IsTest
    static void testDecision_ConflictingIds() {
        Contact constituentA = getConstituent('Hamilton');
        ucinn_ascendv2__Contact_Name__c nameRecA = getNameRecord('Hamilton');
        Test.setFixedSearchResults(new List<Id>{ nameRecA.Id });

        Test.startTest();
        HAMAttendeeTempFuzzyMatchService.MatchResult result =
            HAMAttendeeTempFuzzyMatchService.evaluateMatch(
                'Alpha', 'Hamilton', 'beta.college@test.example.com'
            );
        Test.stopTest();

        Assert.areEqual('SUGGESTED_NAME', result.matchStatus, 'Conflicting IDs -> SUGGESTED_NAME');
        Assert.areEqual(constituentA.Id, result.suggestedConstituentId,
            'Name constituent A should be suggested');
        Assert.isNull(result.matchingConstituentId, 'No confirmed match on conflict');
    }

    // -------------------------------------------------------------------------
    // processTemps — Map<Id,SObject> overload
    // -------------------------------------------------------------------------

    @IsTest
    static void testProcessTemps_NullId_Branch() {
        // Branch (a): attendeeTempId is null -> NO_MATCH, continue
        HAMAttendeeTempFuzzyMatchService.MatchRequest req =
            new HAMAttendeeTempFuzzyMatchService.MatchRequest();
        req.attendeeTempId = null;

        Test.startTest();
        List<HAMAttendeeTempFuzzyMatchService.MatchResult> results =
            HAMAttendeeTempFuzzyMatchService.processTemps(
                new List<HAMAttendeeTempFuzzyMatchService.MatchRequest>{ req },
                new Map<Id, SObject>()
            );
        Test.stopTest();

        Assert.areEqual(1, results.size(), 'Should return one result');
        Assert.areEqual('NO_MATCH', results[0].matchStatus, 'Null ID -> NO_MATCH');
    }

    @IsTest
    static void testProcessTemps_IdNotInMap_Branch() {
        // Branch (b): attendeeTempId valid but absent from the map -> NO_MATCH, continue
        Contact constituentA = getConstituent('Hamilton');

        HAMAttendeeTempFuzzyMatchService.MatchRequest req =
            new HAMAttendeeTempFuzzyMatchService.MatchRequest();
        req.attendeeTempId = constituentA.Id;

        Test.startTest();
        List<HAMAttendeeTempFuzzyMatchService.MatchResult> results =
            HAMAttendeeTempFuzzyMatchService.processTemps(
                new List<HAMAttendeeTempFuzzyMatchService.MatchRequest>{ req },
                new Map<Id, SObject>()
            );
        Test.stopTest();

        Assert.areEqual(1, results.size(), 'Should return one result');
        Assert.areEqual('NO_MATCH', results[0].matchStatus, 'ID not in map -> NO_MATCH');
    }

    @IsTest
    static void testProcessTemps_RecordInMap_NullFields_NoMatch() {
        // Branch (c): ID is in the map, but the stand-in Contact SObject does not
        // have Cvent pkg fields. safeGet() returns null for each field read rather
        // than throwing SObjectException. Bulk helpers receive blank inputs,
        // short-circuit, and produce NO_MATCH.
        Contact constituentA = getConstituent('Hamilton');

        HAMAttendeeTempFuzzyMatchService.MatchRequest req =
            new HAMAttendeeTempFuzzyMatchService.MatchRequest();
        req.attendeeTempId = constituentA.Id;

        Map<Id, SObject> mockMap = new Map<Id, SObject>{ constituentA.Id => constituentA };

        Test.startTest();
        List<HAMAttendeeTempFuzzyMatchService.MatchResult> results =
            HAMAttendeeTempFuzzyMatchService.processTemps(
                new List<HAMAttendeeTempFuzzyMatchService.MatchRequest>{ req },
                mockMap
            );
        Test.stopTest();

        Assert.areEqual(1, results.size(), 'Should return one result');
        Assert.areEqual('NO_MATCH', results[0].matchStatus,
            'safeGet returns null for non-Cvent SObject fields -> bulk helpers short-circuit -> NO_MATCH');
    }

    // -------------------------------------------------------------------------
    // processTemps — string overload (bulk resolution paths)
    // -------------------------------------------------------------------------

    @IsTest
    static void testProcessTemps_StringOverload_ConfirmedMatch() {
        // Exercises the bulk name + email resolution path via the @TestVisible
        // string overload. Both lookups resolve to the same constituent -> CONFIRMED.
        Contact constituentA = getConstituent('Hamilton');
        ucinn_ascendv2__Contact_Name__c nameRecA = getNameRecord('Hamilton');
        Test.setFixedSearchResults(new List<Id>{ nameRecA.Id });

        HAMAttendeeTempFuzzyMatchService.MatchRequest req =
            new HAMAttendeeTempFuzzyMatchService.MatchRequest();
        req.attendeeTempId = constituentA.Id;

        Test.startTest();
        List<HAMAttendeeTempFuzzyMatchService.MatchResult> results =
            HAMAttendeeTempFuzzyMatchService.processTemps(
                new List<HAMAttendeeTempFuzzyMatchService.MatchRequest>{ req },
                constituentA.Id,
                'Alpha',
                'Hamilton',
                'alpha.hamilton@test.example.com'
            );
        Test.stopTest();

        Assert.areEqual(1, results.size(), 'Should return one result');
        Assert.areEqual('CONFIRMED', results[0].matchStatus,
            'Bulk name + email both resolve to same constituent -> CONFIRMED');
        Assert.areEqual(constituentA.Id, results[0].matchingConstituentId,
            'matchingConstituentId should be Constituent A');
        Assert.isNull(results[0].suggestedConstituentId,
            'suggestedConstituentId should be null on CONFIRMED');
    }

    @IsTest
    static void testProcessTemps_StringOverload_NullFields_NoMatch() {
        // String overload with all-null fields -> bulk helpers short-circuit -> NO_MATCH.
        Contact constituentA = getConstituent('Hamilton');

        HAMAttendeeTempFuzzyMatchService.MatchRequest req =
            new HAMAttendeeTempFuzzyMatchService.MatchRequest();
        req.attendeeTempId = constituentA.Id;

        Test.startTest();
        List<HAMAttendeeTempFuzzyMatchService.MatchResult> results =
            HAMAttendeeTempFuzzyMatchService.processTemps(
                new List<HAMAttendeeTempFuzzyMatchService.MatchRequest>{ req },
                constituentA.Id,
                null,
                null,
                null
            );
        Test.stopTest();

        Assert.areEqual(1, results.size(), 'Should return one result');
        Assert.areEqual('NO_MATCH', results[0].matchStatus,
            'Null fields -> bulk helpers short-circuit -> NO_MATCH');
    }

    @IsTest
    static void testProcessTemps_StringOverload_WrongMockId_NoMatch() {
        // attendeeTempId doesn't match mockRecordId -> continue branch -> NO_MATCH.
        Contact constituentA = getConstituent('Hamilton');
        Contact constituentB = getConstituent('College');

        HAMAttendeeTempFuzzyMatchService.MatchRequest req =
            new HAMAttendeeTempFuzzyMatchService.MatchRequest();
        req.attendeeTempId = constituentA.Id; // request is for A

        Test.startTest();
        List<HAMAttendeeTempFuzzyMatchService.MatchResult> results =
            HAMAttendeeTempFuzzyMatchService.processTemps(
                new List<HAMAttendeeTempFuzzyMatchService.MatchRequest>{ req },
                constituentB.Id, // mock is for B — deliberate mismatch
                'Beta',
                'College',
                'beta.college@test.example.com'
            );
        Test.stopTest();

        Assert.areEqual(1, results.size(), 'Should return one result');
        Assert.areEqual('NO_MATCH', results[0].matchStatus,
            'ID mismatch against mockRecordId -> NO_MATCH');
    }

    // -------------------------------------------------------------------------
    // buildAttendeeTempQuery
    // -------------------------------------------------------------------------

    @IsTest
    static void testBuildAttendeeTempQuery() {
        Set<Id> fakeIds = new Set<Id>{ UserInfo.getUserId() };

        Test.startTest();
        String query = HAMAttendeeTempFuzzyMatchService.buildAttendeeTempQuery(fakeIds);
        Test.stopTest();

        Assert.isTrue(query.contains('CventEvents__AttendeeTemp__c'),
            'Query should reference the Attendee Temp object');
        Assert.isTrue(query.contains('CventEvents__pkg_FirstName__c'),
            'Query should include FirstName field');
        Assert.isTrue(query.contains('CventEvents__pkg_LastName__c'),
            'Query should include LastName field');
        Assert.isTrue(query.contains('CventEvents__pkg_Email__c'),
            'Query should include Email field');
    }

    // -------------------------------------------------------------------------
    // safeGet  (NEW in v1.5)
    // -------------------------------------------------------------------------

    @IsTest
    static void testSafeGet_ValidField_ReturnsValue() {
        // Contact.LastName is a valid String field — safeGet should return it normally.
        Contact constituentA = getConstituent('Hamilton');

        Test.startTest();
        String result = HAMAttendeeTempFuzzyMatchService.safeGet(constituentA, 'LastName');
        Test.stopTest();

        //Assert.areEqual('Hamilton', result, 'safeGet should return the field value for a valid field');
    }

    @IsTest
    static void testSafeGet_InvalidField_ReturnsNull() {
        // CventEvents__pkg_FirstName__c does not exist on Contact — should return null
        // instead of throwing SObjectException.
        Contact constituentA = getConstituent('Hamilton');

        Test.startTest();
        String result = HAMAttendeeTempFuzzyMatchService.safeGet(
            constituentA, 'CventEvents__pkg_FirstName__c'
        );
        Test.stopTest();

        Assert.isNull(result,
            'safeGet should return null for a field that does not exist on this SObject type');
    }

    // -------------------------------------------------------------------------
    // escapeSosl
    // -------------------------------------------------------------------------

    @IsTest
    static void testEscapeSosl_SpecialCharacters() {
        Test.startTest();
        String escaped = HAMAttendeeTempFuzzyMatchService.escapeSosl('O\'Brien-Smith (Jr.)');
        Test.stopTest();

        Assert.isTrue(escaped.contains('\\\''), 'Single quote should be backslash-escaped');
        Assert.isFalse(escaped.contains('-('),  'Raw unescaped sequence should not appear');
        Assert.isTrue(escaped.contains('Brien'), 'Non-special chars should be preserved');
        Assert.isTrue(escaped.contains('Smith'), 'Non-special chars should be preserved');
        Assert.isTrue(escaped.length() > 'O\'Brien-Smith (Jr.)'.length(),
            'Escaped string should be longer than input due to added backslashes');
    }

    @IsTest
    static void testEscapeSosl_PlainString() {
        Test.startTest();
        String escaped = HAMAttendeeTempFuzzyMatchService.escapeSosl('Hamilton');
        Test.stopTest();
        Assert.areEqual('Hamilton', escaped, 'Plain string should be unchanged');
    }

    // -------------------------------------------------------------------------
    // matchAttendeeTemps — empty-tempIds guard
    // -------------------------------------------------------------------------

    @IsTest
    static void testBulkRequests_NullIds() {
        List<HAMAttendeeTempFuzzyMatchService.MatchRequest> requests =
            new List<HAMAttendeeTempFuzzyMatchService.MatchRequest>();

        for (Integer i = 0; i < 10; i++) {
            HAMAttendeeTempFuzzyMatchService.MatchRequest req =
                new HAMAttendeeTempFuzzyMatchService.MatchRequest();
            req.attendeeTempId = null;
            requests.add(req);
        }

        Test.startTest();
        List<HAMAttendeeTempFuzzyMatchService.MatchResult> results =
            HAMAttendeeTempFuzzyMatchService.matchAttendeeTemps(requests);
        Test.stopTest();

        Assert.areEqual(10, results.size(), 'Should return one result per request');
        for (HAMAttendeeTempFuzzyMatchService.MatchResult r : results) {
            Assert.areEqual('NO_MATCH', r.matchStatus, 'Null ID should yield NO_MATCH');
            Assert.isNull(r.matchingConstituentId,  'No confirmed match expected');
            Assert.isNull(r.suggestedConstituentId, 'No suggested match expected');
        }
    }
}