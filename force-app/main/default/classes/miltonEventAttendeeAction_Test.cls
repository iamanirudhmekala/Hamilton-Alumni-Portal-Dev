/**
 * @description Test class for miltonEventAttendeeAction. Covers the blank-input safety net,
 * event lookup across both Cvent and Blackthorn, the per-contact de-duplication/degree-
 * concatenation of multiple ucinn_ascendv2__Degree_Information__c records, the no-match and
 * zero-attendee cases, the connections-only scope (with its own "no attendees from your
 * connections" message), the viewer-exclusion and blocked-contact exclusion, and the three
 * Service Indicator visibility rules (email, connection, alumni privacy) - identical semantics
 * to miltonAlumniSearchAction, reused here on event attendees instead of a name/degree/year search.
 */
@IsTest
private class miltonEventAttendeeAction_Test {

    private static final String EMAIL_SVID = 'SIV_VIS_EMAIL';
    private static final String CONNECTION_SVID = 'SIV_VIS_CONNECTION';
    private static final String ALUMNI_PRIVACY_SVID = 'SIV_VIS_ALUMNI_PRIVACY';

    @TestSetup
    static void setup() {
        List<Contact> contacts = new List<Contact>{
            new Contact(FirstName = 'Milton', LastName = 'CventAttendeeOne', Email = 'cvent1@miltontest.com',
                        HAM_Reunion_Year__c = '1990', HAM_Is_Active__c = true, ucinn_ascendv2__Contact_Type__c = 'Employee'),
            new Contact(FirstName = 'Milton', LastName = 'CventAttendeeTwo', Email = 'cvent2@miltontest.com',
                        HAM_Reunion_Year__c = '1991', HAM_Is_Active__c = true, ucinn_ascendv2__Contact_Type__c = 'Employee'),
            new Contact(FirstName = 'Milton', LastName = 'BlackthornAttendee', Email = 'bt1@miltontest.com',
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

        CventEvents__Event__c cventEvent = new CventEvents__Event__c(
            CventEvents__pkg_Title__c = 'Reunions \'26 Milton Test',
            CventEvents__pkg_Category__c = 'Reunion',
            CventEvents__pkg_Code__c = 'MILTONTEST001',
            CventEvents__pkg_EventStatus__c = 'Upcoming',
            CventEvents__pkg_EventStub__c = 'milton-test-event',
            CventEvents__pkg_Status__c = 'Active'
        );
        insert cventEvent;

        CventEvents__Event__c cventEventNoAttendees = new CventEvents__Event__c(
            CventEvents__pkg_Title__c = 'Milton Empty Test Event',
            CventEvents__pkg_Category__c = 'Reunion',
            CventEvents__pkg_Code__c = 'MILTONTEST002',
            CventEvents__pkg_EventStatus__c = 'Upcoming',
            CventEvents__pkg_EventStub__c = 'milton-empty-test-event',
            CventEvents__pkg_Status__c = 'Active'
        );
        insert cventEventNoAttendees;

        insert new List<CventEvents__Attendee__c>{
            new CventEvents__Attendee__c(
                CventEvents__Event__c = cventEvent.Id,
                CventEvents__Contact__c = contacts[0].Id,
                CventEvents__Status__c = 'Accepted'
            ),
            new CventEvents__Attendee__c(
                CventEvents__Event__c = cventEvent.Id,
                CventEvents__Contact__c = contacts[1].Id,
                CventEvents__Status__c = 'Accepted'
            )
        };

        conference360__Event__c btEvent = new conference360__Event__c(
            Name = 'Milton Blackthorn Test Event'
        );
        insert btEvent;

        insert new conference360__Attendee__c(
            conference360__Event__c = btEvent.Id,
            conference360__Contact__c = contacts[2].Id
        );

        // The action only shows attendees who are a Connection of the viewer (matching
        // HAM_EventsController.getEventAttendees' connectionsOnly=true scope), so all three
        // attendees above are set up as Connected to the viewer here. A fourth contact
        // (NonConnectionAttendee, added below) deliberately has no connection to the viewer,
        // to test the "no attendees from your connections" case.
        insert new List<HAM_Connection__c>{
            new HAM_Connection__c(
                HAM_Portal_User__c = contacts[3].Id,
                HAM_Linked_Constituent__c = contacts[0].Id,
                HAM_Connection_Status__c = HAM_ConstantsUtil.CONNECTED
            ),
            new HAM_Connection__c(
                HAM_Portal_User__c = contacts[3].Id,
                HAM_Linked_Constituent__c = contacts[1].Id,
                HAM_Connection_Status__c = HAM_ConstantsUtil.CONNECTED
            ),
            new HAM_Connection__c(
                HAM_Portal_User__c = contacts[3].Id,
                HAM_Linked_Constituent__c = contacts[2].Id,
                HAM_Connection_Status__c = HAM_ConstantsUtil.CONNECTED
            )
        };

        Contact nonConnectionAttendee = new Contact(
            FirstName = 'Milton', LastName = 'NonConnectionAttendee', Email = 'nonconn@miltontest.com',
            HAM_Reunion_Year__c = '1993', HAM_Is_Active__c = true, ucinn_ascendv2__Contact_Type__c = 'Employee'
        );
        insert nonConnectionAttendee;
        insert new ucinn_ascendv2__Degree_Information__c(ucinn_ascendv2__Contact__c = nonConnectionAttendee.Id);

        CventEvents__Event__c cventEventNoConnections = new CventEvents__Event__c(
            CventEvents__pkg_Title__c = 'Milton NoConnection Test Event',
            CventEvents__pkg_Category__c = 'Reunion',
            CventEvents__pkg_Code__c = 'MILTONTEST003',
            CventEvents__pkg_EventStatus__c = 'Upcoming',
            CventEvents__pkg_EventStub__c = 'milton-noconnection-test-event',
            CventEvents__pkg_Status__c = 'Active'
        );
        insert cventEventNoConnections;

        insert new CventEvents__Attendee__c(
            CventEvents__Event__c = cventEventNoConnections.Id,
            CventEvents__Contact__c = nonConnectionAttendee.Id,
            CventEvents__Status__c = 'Accepted'
        );
    }

    private static Contact getContact(String lastName) {
        return [SELECT Id, Email FROM Contact WHERE LastName = :lastName LIMIT 1];
    }

    /**
     * Same helper pattern as miltonAlumniSearchAction_Test.setupServiceIndicatorHistory:
     * creates two Service Indicator child records so the given contact's latest record
     * (by CreatedDate) lands with the given End Date - Test.setCreatedDate makes the
     * "latest wins" ordering deterministic instead of relying on real insert timing.
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
    static void testSearchEventAttendees_BlankEventName_ReturnsEarlySafetyNet() {
        miltonEventAttendeeAction.EventAttendeeRequest req = new miltonEventAttendeeAction.EventAttendeeRequest();
        req.contactId = getContact('Viewer').Id;

        Test.startTest();
        List<miltonEventAttendeeAction.EventAttendeeOutput> outputs = miltonEventAttendeeAction.searchEventAttendees(
            new List<miltonEventAttendeeAction.EventAttendeeRequest>{ req }
        );
        Test.stopTest();

        Assert.areEqual(1, outputs.size(), 'One output expected per request');
        Assert.isFalse(outputs[0].result.isSuccess, 'Blank event name must fail safely');
        Assert.areEqual(0, outputs[0].result.totalCount, 'No records should be returned');
    }

    @IsTest
    static void testSearchEventAttendees_CventEventMatch_DedupesDegreesAndAppliesEmailVisibility() {
        Contact viewer = getContact('Viewer');
        Contact hiddenAlum = getContact('CventAttendeeOne');
        Contact visibleAlum = getContact('CventAttendeeTwo');

        // hiddenAlum's latest indicator has no End Date -> email must be hidden.
        setupServiceIndicatorHistory(hiddenAlum.Id, EMAIL_SVID, 'Do Not Display Email', null);

        miltonEventAttendeeAction.EventAttendeeRequest req = new miltonEventAttendeeAction.EventAttendeeRequest();
        req.eventName = 'Reunions \'26';
        req.contactId = viewer.Id;

        Test.startTest();
        List<miltonEventAttendeeAction.EventAttendeeOutput> outputs = miltonEventAttendeeAction.searchEventAttendees(
            new List<miltonEventAttendeeAction.EventAttendeeRequest>{ req }
        );
        Test.stopTest();

        miltonAlumniSearchResponse resp = outputs[0].result;
        Assert.isTrue(resp.isSuccess, 'Search by event name should succeed');

        Map<Id, miltonAlumniResult> byContact = new Map<Id, miltonAlumniResult>();
        Integer hiddenAlumRowCount = 0;
        for (miltonAlumniResult ar : resp.alumniRecords) {
            byContact.put(ar.contactId, ar);
            if (ar.contactId == hiddenAlum.Id) {
                hiddenAlumRowCount++;
            }
        }

        Assert.areEqual(1, hiddenAlumRowCount, 'Two Degree_Information records for one contact must collapse into a single result row');
        Assert.isTrue(byContact.containsKey(hiddenAlum.Id), 'Hidden-email attendee must appear in results');
        Assert.isNull(byContact.get(hiddenAlum.Id).email, 'Latest indicator has no End Date - email must be hidden');

        Assert.isTrue(byContact.containsKey(visibleAlum.Id), 'Visible-email attendee must appear in results');
        Assert.areEqual(visibleAlum.Email, byContact.get(visibleAlum.Id).email, 'No indicator - email must show');
    }

    @IsTest
    static void testSearchEventAttendees_BlackthornEventMatch_ReturnsAttendee() {
        Contact viewer = getContact('Viewer');
        Contact btAlum = getContact('BlackthornAttendee');

        miltonEventAttendeeAction.EventAttendeeRequest req = new miltonEventAttendeeAction.EventAttendeeRequest();
        req.eventName = 'Blackthorn Test Event';
        req.contactId = viewer.Id;

        Test.startTest();
        List<miltonEventAttendeeAction.EventAttendeeOutput> outputs = miltonEventAttendeeAction.searchEventAttendees(
            new List<miltonEventAttendeeAction.EventAttendeeRequest>{ req }
        );
        Test.stopTest();

        miltonAlumniSearchResponse resp = outputs[0].result;
        Assert.isTrue(resp.isSuccess, 'Search by Blackthorn event name should succeed');
        Assert.areEqual(1, resp.totalCount, 'Only the Blackthorn attendee should be returned');
        Assert.areEqual(btAlum.Id, resp.alumniRecords[0].contactId, 'The Blackthorn attendee must be the one returned');
    }

    @IsTest
    static void testSearchEventAttendees_NoMatchingEvent_ReturnsZeroResults() {
        miltonEventAttendeeAction.EventAttendeeRequest req = new miltonEventAttendeeAction.EventAttendeeRequest();
        req.eventName = 'Not A Real Event Name At All';
        req.contactId = getContact('Viewer').Id;

        Test.startTest();
        List<miltonEventAttendeeAction.EventAttendeeOutput> outputs = miltonEventAttendeeAction.searchEventAttendees(
            new List<miltonEventAttendeeAction.EventAttendeeRequest>{ req }
        );
        Test.stopTest();

        miltonAlumniSearchResponse resp = outputs[0].result;
        Assert.isTrue(resp.isSuccess, 'A well-formed but unmatched event name is not an error');
        Assert.areEqual(0, resp.totalCount, 'No matching event must return zero results');
    }

    @IsTest
    static void testSearchEventAttendees_EventWithNoAttendees_ReturnsZeroResults() {
        miltonEventAttendeeAction.EventAttendeeRequest req = new miltonEventAttendeeAction.EventAttendeeRequest();
        req.eventName = 'Milton Empty Test Event';
        req.contactId = getContact('Viewer').Id;

        Test.startTest();
        List<miltonEventAttendeeAction.EventAttendeeOutput> outputs = miltonEventAttendeeAction.searchEventAttendees(
            new List<miltonEventAttendeeAction.EventAttendeeRequest>{ req }
        );
        Test.stopTest();

        miltonAlumniSearchResponse resp = outputs[0].result;
        Assert.isTrue(resp.isSuccess, 'An event with zero attendees is not an error');
        Assert.areEqual(0, resp.totalCount, 'Event exists but has no attendees - must return zero results');
    }

    @IsTest
    static void testSearchEventAttendees_ConnectionPrivacyHidesConnectionActionOnly() {
        Contact viewer = getContact('Viewer');
        Contact privateAlum = getContact('CventAttendeeOne');
        Contact openAlum = getContact('CventAttendeeTwo');

        setupServiceIndicatorHistory(privateAlum.Id, CONNECTION_SVID, 'Do Not Display Connection', null);

        miltonEventAttendeeAction.EventAttendeeRequest req = new miltonEventAttendeeAction.EventAttendeeRequest();
        req.eventName = 'Reunions \'26';
        req.contactId = viewer.Id;

        Test.startTest();
        List<miltonEventAttendeeAction.EventAttendeeOutput> outputs = miltonEventAttendeeAction.searchEventAttendees(
            new List<miltonEventAttendeeAction.EventAttendeeRequest>{ req }
        );
        Test.stopTest();

        Map<Id, miltonAlumniResult> byContact = new Map<Id, miltonAlumniResult>();
        for (miltonAlumniResult ar : outputs[0].result.alumniRecords) {
            byContact.put(ar.contactId, ar);
        }

        Assert.isTrue(byContact.containsKey(privateAlum.Id), 'The attendee must still appear in results');
        Assert.isTrue(byContact.get(privateAlum.Id).connectionPrivacyEnabled, 'Active SIV_VIS_CONNECTION indicator must hide the connection action');

        Assert.isTrue(byContact.containsKey(openAlum.Id), 'An unrelated attendee must still appear');
        Assert.isFalse(byContact.get(openAlum.Id).connectionPrivacyEnabled, 'No indicator - connection action must remain available');
    }

    @IsTest
    static void testSearchEventAttendees_AlumniPrivacyExcludesContactFromResults() {
        Contact viewer = getContact('Viewer');
        Contact privateAlum = getContact('CventAttendeeOne');
        Contact visibleAlum = getContact('CventAttendeeTwo');

        setupServiceIndicatorHistory(privateAlum.Id, ALUMNI_PRIVACY_SVID, 'Alumni Privacy', null);

        miltonEventAttendeeAction.EventAttendeeRequest req = new miltonEventAttendeeAction.EventAttendeeRequest();
        req.eventName = 'Reunions \'26';
        req.contactId = viewer.Id;

        Test.startTest();
        List<miltonEventAttendeeAction.EventAttendeeOutput> outputs = miltonEventAttendeeAction.searchEventAttendees(
            new List<miltonEventAttendeeAction.EventAttendeeRequest>{ req }
        );
        Test.stopTest();

        miltonAlumniSearchResponse resp = outputs[0].result;
        Set<Id> resultContactIds = new Set<Id>();
        for (miltonAlumniResult ar : resp.alumniRecords) {
            resultContactIds.add(ar.contactId);
        }

        Assert.isFalse(resultContactIds.contains(privateAlum.Id), 'Active SIV_VIS_ALUMNI_PRIVACY indicator must exclude the attendee entirely');
        Assert.isTrue(resultContactIds.contains(visibleAlum.Id), 'An unrelated attendee must still appear');
        Assert.areEqual(resultContactIds.size(), resp.totalCount, 'totalCount must reflect the filtered list');
    }

    @IsTest
    static void testSearchEventAttendees_ViewerExcludedFromOwnAttendeeList() {
        // The viewer is registered for the same Cvent event as an attendee themselves -
        // matches HAM_EventsController.getEventAttendees, which never shows the viewer
        // as their own attendee.
        Contact viewer = getContact('Viewer');
        CventEvents__Event__c cventEvent = [
            SELECT Id FROM CventEvents__Event__c WHERE CventEvents__pkg_Title__c = 'Reunions \'26 Milton Test' LIMIT 1
        ];
        insert new CventEvents__Attendee__c(
            CventEvents__Event__c = cventEvent.Id,
            CventEvents__Contact__c = viewer.Id,
            CventEvents__Status__c = 'Accepted'
        );

        miltonEventAttendeeAction.EventAttendeeRequest req = new miltonEventAttendeeAction.EventAttendeeRequest();
        req.eventName = 'Reunions \'26';
        req.contactId = viewer.Id;

        Test.startTest();
        List<miltonEventAttendeeAction.EventAttendeeOutput> outputs = miltonEventAttendeeAction.searchEventAttendees(
            new List<miltonEventAttendeeAction.EventAttendeeRequest>{ req }
        );
        Test.stopTest();

        Set<Id> resultContactIds = new Set<Id>();
        for (miltonAlumniResult ar : outputs[0].result.alumniRecords) {
            resultContactIds.add(ar.contactId);
        }

        Assert.isFalse(resultContactIds.contains(viewer.Id), 'The viewer must never appear as their own attendee');
    }

    @IsTest
    static void testSearchEventAttendees_BlockedContactExcludedFromResults() {
        Contact viewer = getContact('Viewer');
        Contact blockedAlum = getContact('CventAttendeeOne');
        Contact visibleAlum = getContact('CventAttendeeTwo');

        // blockedAlum is already Connected (via @TestSetup) - marking that same row as
        // blocked too proves the block exclusion fires even for an otherwise-valid connection.
        HAM_Connection__c existingConnection = [
            SELECT Id FROM HAM_Connection__c
            WHERE HAM_Portal_User__c = :viewer.Id AND HAM_Linked_Constituent__c = :blockedAlum.Id
            LIMIT 1
        ];
        existingConnection.HAM_Is_Blocked__c = true;
        update existingConnection;

        miltonEventAttendeeAction.EventAttendeeRequest req = new miltonEventAttendeeAction.EventAttendeeRequest();
        req.eventName = 'Reunions \'26';
        req.contactId = viewer.Id;

        Test.startTest();
        List<miltonEventAttendeeAction.EventAttendeeOutput> outputs = miltonEventAttendeeAction.searchEventAttendees(
            new List<miltonEventAttendeeAction.EventAttendeeRequest>{ req }
        );
        Test.stopTest();

        Set<Id> resultContactIds = new Set<Id>();
        for (miltonAlumniResult ar : outputs[0].result.alumniRecords) {
            resultContactIds.add(ar.contactId);
        }

        Assert.isFalse(resultContactIds.contains(blockedAlum.Id), 'A blocked contact must be excluded from the attendee list even though otherwise connected');
        Assert.isTrue(resultContactIds.contains(visibleAlum.Id), 'An unrelated attendee must still appear');
    }

    @IsTest
    static void testSearchEventAttendees_NoConnectionAttendees_ReturnsSpecificMessage() {
        miltonEventAttendeeAction.EventAttendeeRequest req = new miltonEventAttendeeAction.EventAttendeeRequest();
        req.eventName = 'Milton NoConnection Test Event';
        req.contactId = getContact('Viewer').Id;

        Test.startTest();
        List<miltonEventAttendeeAction.EventAttendeeOutput> outputs = miltonEventAttendeeAction.searchEventAttendees(
            new List<miltonEventAttendeeAction.EventAttendeeRequest>{ req }
        );
        Test.stopTest();

        miltonAlumniSearchResponse resp = outputs[0].result;
        Assert.isTrue(resp.isSuccess, 'An event whose attendees are not connections is not an error');
        Assert.areEqual(0, resp.totalCount, 'None of the attendees are connections - must return zero results');
        Assert.areEqual(
            'No attendees from your connections for "Milton NoConnection Test Event".',
            resp.statusMessage,
            'Must use the specific "no attendees from your connections" message, not the generic no-attendees one'
        );
    }
}