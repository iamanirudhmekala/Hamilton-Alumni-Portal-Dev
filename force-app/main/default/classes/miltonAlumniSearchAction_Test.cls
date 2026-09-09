/**
 * @description Test class for miltonAlumniSearchAction. Covers the blank-input safety net,
 * each optional search filter (name, degree, class year, constituent type, region), the per-contact
 * de-duplication/degree-concatenation of multiple ucinn_ascendv2__Degree_Information__c records,
 * and the 'Do Not Display Email' Service Indicator suppression logic (latest child record wins).
 */
@IsTest
private class miltonAlumniSearchAction_Test {

    private static final String EMAIL_SVID = 'SIV_VIS_EMAIL';
    private static final String CONNECTION_SVID = 'SIV_VIS_CONNECTION';
    private static final String ALUMNI_PRIVACY_SVID = 'SIV_VIS_ALUMNI_PRIVACY';

    @TestSetup
    static void setup() {
        // ucinn_ascendv2__Contact_Type__c uses 'Employee' rather than an Alumni value here because
        // the real Milton_Constituent_Type__mdt 'Alumni' record maps to a typo'd picklist value
        // ('Hamilton Alumini' vs the actual 'Hamilton Alumni') that can never match any real contact -
        // see testSearchAlumni_ByDegreeYearAndConstituentType for the working 'Current_Employee' case.
        List<Contact> contacts = new List<Contact>{
            new Contact(FirstName = 'Milton', LastName = 'HiddenEmailAlum', Email = 'hidden@miltontest.com',
                        HAM_Reunion_Year__c = '1990', HAM_Is_Active__c = true, ucinn_ascendv2__Contact_Type__c = 'Employee'),
            new Contact(FirstName = 'Milton', LastName = 'VisibleEmailAlum', Email = 'visible@miltontest.com',
                        HAM_Reunion_Year__c = '1991', HAM_Is_Active__c = true, ucinn_ascendv2__Contact_Type__c = 'Employee'),
            new Contact(FirstName = 'Milton', LastName = 'PlainAlum', Email = 'plain@miltontest.com',
                        HAM_Reunion_Year__c = '1992', HAM_Is_Active__c = true, ucinn_ascendv2__Contact_Type__c = 'Employee'),
            new Contact(FirstName = 'Milton', LastName = 'Viewer', Email = 'viewer@miltontest.com', HAM_Is_Active__c = true)
        };
        insert contacts;

        // Two Degree_Information records for the same contact - proves the search collapses
        // them into a single result row instead of two duplicate cards.
        insert new List<ucinn_ascendv2__Degree_Information__c>{
            new ucinn_ascendv2__Degree_Information__c(ucinn_ascendv2__Contact__c = contacts[0].Id),
            new ucinn_ascendv2__Degree_Information__c(ucinn_ascendv2__Contact__c = contacts[0].Id),
            new ucinn_ascendv2__Degree_Information__c(ucinn_ascendv2__Contact__c = contacts[1].Id),
            new ucinn_ascendv2__Degree_Information__c(ucinn_ascendv2__Contact__c = contacts[2].Id)
        };

        // PlainAlum has no Service Indicator record at all - email must simply show.
        // The email-visibility Service Indicator records themselves are created inside
        // testSearchAlumni_ByName_DedupesDegreesAndAppliesEmailVisibility (not here), because
        // that scenario needs Test.setCreatedDate to deterministically control which record is
        // "latest" - two inserts made back-to-back can otherwise land in the same millisecond.
    }

    private static Contact getContact(String lastName) {
        return [SELECT Id, Email FROM Contact WHERE LastName = :lastName LIMIT 1];
    }

    /**
     * Creates the two Service Indicator child records that make the given contact's latest
     * record (for the given parent Service Indicator Value Portal ID) land with the given End
     * Date, using Test.setCreatedDate to make the "latest by CreatedDate" ordering deterministic
     * instead of relying on real insert timing (which can tie at millisecond granularity). Reused
     * for all three visibility checks (email, connection, alumni privacy) since they share the
     * exact same "latest child record wins" logic in miltonAlumniSearchAction.
     */
    private static void setupServiceIndicatorHistory(Id contactId, String portalId, String siValueName, Date latestEndDate) {
        ucinn_ascendv2__Service_Indicator_Value__c siValue;
        List<ucinn_ascendv2__Service_Indicator_Value__c> existing = [
            SELECT Id FROM ucinn_ascendv2__Service_Indicator_Value__c WHERE HAM_Portal_ID__c = :portalId LIMIT 1
        ];
        if (existing.isEmpty()) {
            siValue = new ucinn_ascendv2__Service_Indicator_Value__c(Name = siValueName, HAM_Portal_ID__c = portalId);
            insert siValue;
        } else {
            siValue = existing[0];
        }

        Id contactSiRtId = Schema.SObjectType.ucinn_ascendv2__Service_Indicator__c
            .getRecordTypeInfosByName().get(HAM_ConstantsUtil.CONTACT_SERVICE_INDICATOR_RECORD_TYPE).getRecordTypeId();

        // Older record: the opposite End Date state of what we want to end up with.
        ucinn_ascendv2__Service_Indicator__c olderRecord = new ucinn_ascendv2__Service_Indicator__c(
            ucinn_ascendv2__Contact__c = contactId,
            ucinn_ascendv2__Service_Indicator_Value__c = siValue.Id,
            RecordTypeId = contactSiRtId,
            ucinn_ascendv2__Start_Date__c = System.today().addDays(-30),
            ucinn_ascendv2__End_Date__c = latestEndDate == null ? System.today().addDays(-20) : null,
            ucinn_ascendv2__Is_Active__c = true
        );
        insert olderRecord;
        Test.setCreatedDate(olderRecord.Id, Datetime.now().addDays(-2));

        // Newer record: this is the one the production "latest wins" logic must pick.
        ucinn_ascendv2__Service_Indicator__c newerRecord = new ucinn_ascendv2__Service_Indicator__c(
            ucinn_ascendv2__Contact__c = contactId,
            ucinn_ascendv2__Service_Indicator_Value__c = siValue.Id,
            RecordTypeId = contactSiRtId,
            ucinn_ascendv2__Start_Date__c = System.today(),
            ucinn_ascendv2__End_Date__c = latestEndDate,
            ucinn_ascendv2__Is_Active__c = true
        );
        insert newerRecord;
        Test.setCreatedDate(newerRecord.Id, Datetime.now().addDays(-1));
    }

    @IsTest
    static void testSearchAlumni_NoCriteria_ReturnsEarlySafetyNet() {
        miltonAlumniSearchAction.AlumniSearchRequest req = new miltonAlumniSearchAction.AlumniSearchRequest();
        req.contactId = getContact('Viewer').Id;

        Test.startTest();
        List<miltonAlumniSearchAction.AlumniSearchOutput> outputs = miltonAlumniSearchAction.searchAlumni(
            new List<miltonAlumniSearchAction.AlumniSearchRequest>{ req }
        );
        Test.stopTest();

        Assert.areEqual(1, outputs.size(), 'One output expected per request');
        Assert.isFalse(outputs[0].result.isSuccess, 'Blank criteria must fail safely');
        Assert.areEqual(0, outputs[0].result.totalCount, 'No records should be returned');
    }

    @IsTest
    static void testSearchAlumni_ByName_DedupesDegreesAndAppliesEmailVisibility() {
        Contact viewer = getContact('Viewer');
        Contact hiddenAlum = getContact('HiddenEmailAlum');
        Contact visibleAlum = getContact('VisibleEmailAlum');
        Contact plainAlum = getContact('PlainAlum');

        // HiddenEmailAlum's latest indicator has no End Date -> email must be hidden.
        setupServiceIndicatorHistory(hiddenAlum.Id, EMAIL_SVID, 'Do Not Display Email', null);
        // VisibleEmailAlum's latest indicator has an End Date (turned back on) -> email must show.
        setupServiceIndicatorHistory(visibleAlum.Id, EMAIL_SVID, 'Do Not Display Email', System.today());

        miltonAlumniSearchAction.AlumniSearchRequest req = new miltonAlumniSearchAction.AlumniSearchRequest();
        req.alumniName = 'Milton';
        req.contactId = viewer.Id;

        Test.startTest();
        List<miltonAlumniSearchAction.AlumniSearchOutput> outputs = miltonAlumniSearchAction.searchAlumni(
            new List<miltonAlumniSearchAction.AlumniSearchRequest>{ req }
        );
        Test.stopTest();

        miltonAlumniSearchResponse resp = outputs[0].result;
        Assert.isTrue(resp.isSuccess, 'Search by name should succeed');

        Map<Id, miltonAlumniResult> byContact = new Map<Id, miltonAlumniResult>();
        Integer hiddenAlumRowCount = 0;
        for (miltonAlumniResult ar : resp.alumniRecords) {
            byContact.put(ar.contactId, ar);
            if (ar.contactId == hiddenAlum.Id) {
                hiddenAlumRowCount++;
            }
        }

        Assert.areEqual(1, hiddenAlumRowCount, 'Two Degree_Information records for one contact must collapse into a single result row');

        Assert.isTrue(byContact.containsKey(hiddenAlum.Id), 'Hidden-email alum must still appear in results');
        Assert.isNull(byContact.get(hiddenAlum.Id).email, 'Latest indicator has no End Date - email must be hidden');
        Assert.isFalse(byContact.get(hiddenAlum.Id).isDeceased, 'A living contact must not be flagged as deceased');

        Assert.isTrue(byContact.containsKey(visibleAlum.Id), 'Visible-email alum must appear in results');
        Assert.areEqual(visibleAlum.Email, byContact.get(visibleAlum.Id).email, 'Latest indicator has an End Date - email must show');

        Assert.isTrue(byContact.containsKey(plainAlum.Id), 'Plain alum must appear in results');
        Assert.areEqual(plainAlum.Email, byContact.get(plainAlum.Id).email, 'No indicator at all - email must show');
    }

    @IsTest
    static void testSearchAlumni_ByDegreeYearAndConstituentType() {
        Contact viewer = getContact('Viewer');

        miltonAlumniSearchAction.AlumniSearchRequest byDegree = new miltonAlumniSearchAction.AlumniSearchRequest();
        byDegree.majorDegree = 'Economics';
        byDegree.contactId = viewer.Id;

        miltonAlumniSearchAction.AlumniSearchRequest byYear = new miltonAlumniSearchAction.AlumniSearchRequest();
        byYear.classOfYear = '1990';
        byYear.contactId = viewer.Id;

        // 'Current_Employee' resolves (via Milton_Constituent_Type__mdt) to the single picklist
        // value 'Employee', which the seeded contacts above carry.
        miltonAlumniSearchAction.AlumniSearchRequest byType = new miltonAlumniSearchAction.AlumniSearchRequest();
        byType.constituentType = 'Current_Employee';
        byType.contactId = viewer.Id;

        Test.startTest();
        List<miltonAlumniSearchAction.AlumniSearchOutput> outputs = miltonAlumniSearchAction.searchAlumni(
            new List<miltonAlumniSearchAction.AlumniSearchRequest>{ byDegree, byYear, byType }
        );
        Test.stopTest();

        Assert.areEqual(3, outputs.size(), 'One output per request');
        for (miltonAlumniSearchAction.AlumniSearchOutput output : outputs) {
            Assert.isTrue(output.result.isSuccess, 'Each filtered search should succeed');
        }

        // The constituent type filter resolves the Milton_Constituent_Type__mdt record's
        // comma-separated Constituent_Type__c value(s) and checks membership on
        // ucinn_ascendv2__Contact_Type__c (a multi-select picklist) via INCLUDES, so this proves
        // the whole mapping + membership match actually works, not just that the query ran.
        Assert.isTrue(outputs[2].result.totalCount > 0, 'Current_Employee should resolve to \'Employee\' and match the seeded contacts');
    }

    @IsTest
    static void testSearchAlumni_ByRegionFiltersOnActiveCurrentChapter() {
        Contact viewer = getContact('Viewer');
        Contact inRegionAlum = getContact('HiddenEmailAlum');
        Contact outOfRegionAlum = getContact('PlainAlum');

        HAM_Chapter_Lookup__c chapter = new HAM_Chapter_Lookup__c(
            Name = 'Milton Test Region',
            HAM_Chapter_Code__c = 'MTR',
            HAM_Chapter_Type__c = 'Domestic'
        );
        insert chapter;

        // Only HiddenEmailAlum has an ACTIVE current-chapter record for this region -
        // PlainAlum's record is inactive and must not match.
        insert new List<HAM_Current_Chapter__c>{
            new HAM_Current_Chapter__c(Constituent__c = inRegionAlum.Id, Chapter__c = chapter.Id, Is_Active__c = true),
            new HAM_Current_Chapter__c(Constituent__c = outOfRegionAlum.Id, Chapter__c = chapter.Id, Is_Active__c = false)
        };

        miltonAlumniSearchAction.AlumniSearchRequest req = new miltonAlumniSearchAction.AlumniSearchRequest();
        req.region = 'Milton Test Region';
        req.contactId = viewer.Id;

        Test.startTest();
        List<miltonAlumniSearchAction.AlumniSearchOutput> outputs = miltonAlumniSearchAction.searchAlumni(
            new List<miltonAlumniSearchAction.AlumniSearchRequest>{ req }
        );
        Test.stopTest();

        miltonAlumniSearchResponse resp = outputs[0].result;
        Assert.isTrue(resp.isSuccess, 'Search by region should succeed');

        Set<Id> resultContactIds = new Set<Id>();
        for (miltonAlumniResult ar : resp.alumniRecords) {
            resultContactIds.add(ar.contactId);
        }

        Assert.isTrue(resultContactIds.contains(inRegionAlum.Id), 'Alum with an active current-chapter match must appear');
        Assert.isFalse(resultContactIds.contains(outOfRegionAlum.Id), 'Alum whose current-chapter record is inactive must not match the region filter');
    }

    @IsTest
    static void testSearchAlumni_UnknownConstituentTypeReturnsNoResults() {
        miltonAlumniSearchAction.AlumniSearchRequest req = new miltonAlumniSearchAction.AlumniSearchRequest();
        req.constituentType = 'Not_A_Real_Constituent_Type';
        req.contactId = getContact('Viewer').Id;

        Test.startTest();
        List<miltonAlumniSearchAction.AlumniSearchOutput> outputs = miltonAlumniSearchAction.searchAlumni(
            new List<miltonAlumniSearchAction.AlumniSearchRequest>{ req }
        );
        Test.stopTest();

        miltonAlumniSearchResponse resp = outputs[0].result;
        Assert.isTrue(resp.isSuccess, 'A well-formed but unmatched constituent type is not an error');
        Assert.areEqual(0, resp.totalCount, 'No Milton_Constituent_Type__mdt match must fail safe to zero results, not skip the filter');
    }

    @IsTest
    static void testSearchAlumni_ConnectedFirstThenLastNameAlphabetical() {
        Contact viewer = getContact('Viewer');
        Contact hiddenAlum = getContact('HiddenEmailAlum'); // unconnected
        Contact plainAlum = getContact('PlainAlum');        // unconnected
        Contact visibleAlum = getContact('VisibleEmailAlum'); // will be connected

        // Alphabetically 'VisibleEmailAlum' would sort last (H < P < V), but being connected
        // to the viewer must still put it first, ahead of both unconnected contacts.
        insert new HAM_Connection__c(
            HAM_Portal_User__c = viewer.Id,
            HAM_Linked_Constituent__c = visibleAlum.Id,
            HAM_Connection_Status__c = HAM_ConstantsUtil.CONNECTED
        );

        miltonAlumniSearchAction.AlumniSearchRequest req = new miltonAlumniSearchAction.AlumniSearchRequest();
        req.alumniName = 'Milton';
        req.contactId = viewer.Id;

        Test.startTest();
        List<miltonAlumniSearchAction.AlumniSearchOutput> outputs = miltonAlumniSearchAction.searchAlumni(
            new List<miltonAlumniSearchAction.AlumniSearchRequest>{ req }
        );
        Test.stopTest();

        List<miltonAlumniResult> results = outputs[0].result.alumniRecords;
        Assert.areEqual(3, results.size(), 'HiddenEmailAlum, PlainAlum and VisibleEmailAlum should all appear');

        Assert.areEqual(visibleAlum.Id, results[0].contactId, 'The connected alum must be listed first despite sorting last alphabetically');
        Assert.isTrue(results[0].isConnected, 'First result must be the connected alum');

        Assert.areEqual(hiddenAlum.Id, results[1].contactId, 'Among unconnected alumni, HiddenEmailAlum (H) sorts before PlainAlum (P)');
        Assert.areEqual(plainAlum.Id, results[2].contactId, 'PlainAlum is last, alphabetically after HiddenEmailAlum');
    }

    @IsTest
    static void testSearchAlumni_ConnectionPrivacyHidesConnectionActionOnly() {
        Contact viewer = getContact('Viewer');
        Contact privateContact = getContact('PlainAlum');
        Contact openContact = getContact('HiddenEmailAlum');

        // PlainAlum's latest SIV_VIS_CONNECTION indicator has no End Date - the connection
        // action must be hidden, but the alum must still appear in the results.
        setupServiceIndicatorHistory(privateContact.Id, CONNECTION_SVID, 'Do Not Display Connection', null);

        miltonAlumniSearchAction.AlumniSearchRequest req = new miltonAlumniSearchAction.AlumniSearchRequest();
        req.alumniName = 'Milton';
        req.contactId = viewer.Id;

        Test.startTest();
        List<miltonAlumniSearchAction.AlumniSearchOutput> outputs = miltonAlumniSearchAction.searchAlumni(
            new List<miltonAlumniSearchAction.AlumniSearchRequest>{ req }
        );
        Test.stopTest();

        Map<Id, miltonAlumniResult> byContact = new Map<Id, miltonAlumniResult>();
        for (miltonAlumniResult ar : outputs[0].result.alumniRecords) {
            byContact.put(ar.contactId, ar);
        }

        Assert.isTrue(byContact.containsKey(privateContact.Id), 'The alum must still appear in results');
        Assert.isTrue(byContact.get(privateContact.Id).connectionPrivacyEnabled, 'Active SIV_VIS_CONNECTION indicator must hide the connection action');

        Assert.isTrue(byContact.containsKey(openContact.Id), 'An unrelated alum must still appear');
        Assert.isFalse(byContact.get(openContact.Id).connectionPrivacyEnabled, 'No indicator - connection action must remain available');
    }

    @IsTest
    static void testSearchAlumni_AlumniPrivacyExcludesContactFromResults() {
        Contact viewer = getContact('Viewer');
        Contact privateAlum = getContact('PlainAlum');
        Contact visibleAlum = getContact('HiddenEmailAlum');

        // PlainAlum's latest SIV_VIS_ALUMNI_PRIVACY indicator has no End Date - unlike email or
        // connection privacy, this must exclude the alum from the results entirely.
        setupServiceIndicatorHistory(privateAlum.Id, ALUMNI_PRIVACY_SVID, 'Alumni Privacy', null);

        miltonAlumniSearchAction.AlumniSearchRequest req = new miltonAlumniSearchAction.AlumniSearchRequest();
        req.alumniName = 'Milton';
        req.contactId = viewer.Id;

        Test.startTest();
        List<miltonAlumniSearchAction.AlumniSearchOutput> outputs = miltonAlumniSearchAction.searchAlumni(
            new List<miltonAlumniSearchAction.AlumniSearchRequest>{ req }
        );
        Test.stopTest();

        miltonAlumniSearchResponse resp = outputs[0].result;
        Set<Id> resultContactIds = new Set<Id>();
        for (miltonAlumniResult ar : resp.alumniRecords) {
            resultContactIds.add(ar.contactId);
        }

        Assert.isFalse(resultContactIds.contains(privateAlum.Id), 'Active SIV_VIS_ALUMNI_PRIVACY indicator must exclude the alum entirely');
        Assert.isTrue(resultContactIds.contains(visibleAlum.Id), 'An unrelated alum must still appear');
        Assert.areEqual(resultContactIds.size(), resp.totalCount, 'totalCount must reflect the filtered list');
    }

    @IsTest
    static void testSearchAlumni_ViewerIsSelf() {
        Contact hiddenAlum = getContact('HiddenEmailAlum');

        miltonAlumniSearchAction.AlumniSearchRequest req = new miltonAlumniSearchAction.AlumniSearchRequest();
        req.alumniName = 'HiddenEmailAlum';
        req.contactId = hiddenAlum.Id;

        Test.startTest();
        List<miltonAlumniSearchAction.AlumniSearchOutput> outputs = miltonAlumniSearchAction.searchAlumni(
            new List<miltonAlumniSearchAction.AlumniSearchRequest>{ req }
        );
        Test.stopTest();

        miltonAlumniResult ar = outputs[0].result.alumniRecords[0];
        Assert.isTrue(ar.isSelf, 'Viewer searching their own record should be flagged as self');
    }
}