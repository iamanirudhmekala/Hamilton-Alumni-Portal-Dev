/**
 * @description Test class for MiltonEventSearchAction. Covers the invalid-eventType safety
 * net, the default eventType (Upcoming_Events), the Upcoming/Past x My/Other Events split
 * (registered-attendee based), the event name filter, and the Region filter - including its
 * Cvent-only scope (Blackthorn is skipped entirely once a region is supplied) and the
 * "Anytown also matches a blank region" rule mirrored from HAM_EventsController.
 */
@IsTest
private class MiltonEventSearchAction_Test {

    @TestSetup
    static void setup() {
        Contact viewer = new Contact(FirstName = 'Milton', LastName = 'EventSearchViewer', Email = 'eventviewer@miltontest.com');
        insert viewer;

        Date today = Date.today();
        Date upcomingDate = today.addDays(10);
        Date pastDate = today.addDays(-10);

        List<CventEvents__Event__c> cventEvents = new List<CventEvents__Event__c>{
            makeCventEvent('Milton Reunion Weekend', 'MILTONEVT001', 'milton-evt-001', upcomingDate, 'Boston'),
            makeCventEvent('Milton Reunion NYC Mixer', 'MILTONEVT002', 'milton-evt-002', upcomingDate, 'NYC'),
            makeCventEvent('Milton Past Homecoming', 'MILTONEVT003', 'milton-evt-003', pastDate, 'Boston'),
            makeCventEvent('Milton Generic Region Event', 'MILTONEVT004', 'milton-evt-004', upcomingDate, null),
            makeCventEvent('Milton Cancelled Event', 'MILTONEVT005', 'milton-evt-005', upcomingDate, 'Boston')
        };
        cventEvents[4].CventEvents__pkg_Status__c = 'Cancelled';
        insert cventEvents;

        insert new CventEvents__Attendee__c(
            CventEvents__Event__c = cventEvents[1].Id,
            CventEvents__Contact__c = viewer.Id,
            CventEvents__Status__c = 'Accepted'
        );

        List<conference360__Event__c> btEvents = new List<conference360__Event__c>{
            makeBlackthornEvent('Milton Blackthorn Upcoming Mixer', upcomingDate),
            makeBlackthornEvent('Milton Blackthorn Past Social', pastDate),
            makeBlackthornEvent('Milton Blackthorn My Upcoming Event', upcomingDate)
        };
        insert btEvents;

        insert new conference360__Attendee__c(
            conference360__Event__c = btEvents[2].Id,
            conference360__Contact__c = viewer.Id
        );
    }

    private static CventEvents__Event__c makeCventEvent(String title, String code, String stub, Date startDate, String region) {
        return new CventEvents__Event__c(
            CventEvents__pkg_Title__c = title,
            CventEvents__pkg_Category__c = 'Reunion',
            CventEvents__pkg_Code__c = code,
            CventEvents__pkg_EventStatus__c = 'Upcoming',
            CventEvents__pkg_EventStub__c = stub,
            CventEvents__pkg_Status__c = 'Active',
            ADVPublicPrivate__c = 'Public',
            ADVPrimaryRegion__c = region,
            CventEvents__pkg_StartDate__c = startDate,
            CventEvents__pkg_Description__c = 'Description for ' + title,
            HAMImageURL__c = 'https://example.com/' + stub + '.png',
            CventEvents__pkg_Location__c = 'Test Venue for ' + title,
            CventEvents__pkg_City__c = 'Test City'
        );
    }

    private static conference360__Event__c makeBlackthornEvent(String name, Date startDate) {
        return new conference360__Event__c(
            Name = name,
            HAM_Private_Event__c = false,
            conference360__Event_Start_Date__c = startDate,
            conference360__Short_Description__c = 'Description for ' + name,
            conference360__Image_URL__c = 'https://example.com/bt.png',
            conference360__Alternative_Image_Text__c = 'Milton Blackthorn event image',
            conference360__Venue_Name__c = 'Test BT Venue',
            conference360__Venue_City__c = 'Test City'
        );
    }

    private static Id getViewerId() {
        return [SELECT Id FROM Contact WHERE LastName = 'EventSearchViewer' LIMIT 1].Id;
    }

    @IsTest
    static void testSearchEvents_InvalidEventType_ReturnsFailure() {
        MiltonEventSearchAction.EventSearchRequest req = new MiltonEventSearchAction.EventSearchRequest();
        req.contactId = getViewerId();
        req.eventType = 'Not_A_Real_Value';

        Test.startTest();
        List<MiltonEventSearchAction.EventSearchOutput> outputs = MiltonEventSearchAction.searchEvents(
            new List<MiltonEventSearchAction.EventSearchRequest>{ req }
        );
        Test.stopTest();

        Assert.isFalse(outputs[0].result.isSuccess, 'An unrecognized eventType must fail safely');
        Assert.areEqual(0, outputs[0].result.totalCount, 'No records should be returned for an invalid eventType');
    }

    @IsTest
    static void testSearchEvents_DefaultEventType_ReturnsAllUpcomingEventsRegardlessOfRegistration() {
        MiltonEventSearchAction.EventSearchRequest req = new MiltonEventSearchAction.EventSearchRequest();
        req.contactId = getViewerId();
        // eventType left blank - must default to Upcoming_Events, which does NOT filter by
        // contactId at all (only the My Events variants do) - registered and unregistered
        // upcoming events must both come back.

        Test.startTest();
        List<MiltonEventSearchAction.EventSearchOutput> outputs = MiltonEventSearchAction.searchEvents(
            new List<MiltonEventSearchAction.EventSearchRequest>{ req }
        );
        Test.stopTest();

        miltonEventSearchResponse resp = outputs[0].result;
        Assert.isTrue(resp.isSuccess, 'A well-formed request must succeed');

        Set<String> resultNames = new Set<String>();
        for (miltonEventResult evt : resp.events) {
            resultNames.add(evt.eventName);
        }

        Assert.isTrue(resultNames.contains('Milton Reunion Weekend'), 'Upcoming, unregistered Cvent event must appear');
        Assert.isTrue(resultNames.contains('Milton Blackthorn Upcoming Mixer'), 'Upcoming, unregistered Blackthorn event must appear');
        Assert.isTrue(resultNames.contains('Milton Reunion NYC Mixer'), 'An event the viewer is registered for must still appear - Upcoming_Events does not filter by contactId');
        Assert.isTrue(resultNames.contains('Milton Blackthorn My Upcoming Event'), 'A registered Blackthorn event must still appear - Upcoming_Events does not filter by contactId');
        Assert.isFalse(resultNames.contains('Milton Past Homecoming'), 'A past event must not appear in an Upcoming search');
        Assert.isFalse(resultNames.contains('Milton Cancelled Event'), 'A cancelled event must never appear');
    }

    @IsTest
    static void testSearchEvents_UpcomingMyEvents_ReturnsOnlyRegisteredEvents() {
        MiltonEventSearchAction.EventSearchRequest req = new MiltonEventSearchAction.EventSearchRequest();
        req.contactId = getViewerId();
        req.eventType = 'Upcoming_My_Events';

        Test.startTest();
        List<MiltonEventSearchAction.EventSearchOutput> outputs = MiltonEventSearchAction.searchEvents(
            new List<MiltonEventSearchAction.EventSearchRequest>{ req }
        );
        Test.stopTest();

        miltonEventSearchResponse resp = outputs[0].result;
        Set<String> resultNames = new Set<String>();
        for (miltonEventResult evt : resp.events) {
            resultNames.add(evt.eventName);
        }

        Assert.isTrue(resultNames.contains('Milton Reunion NYC Mixer'), 'The registered Cvent event must appear in My Events');
        Assert.isTrue(resultNames.contains('Milton Blackthorn My Upcoming Event'), 'The registered Blackthorn event must appear in My Events');
        Assert.isFalse(resultNames.contains('Milton Reunion Weekend'), 'An event the viewer is not registered for must not appear in My Events');
    }

    @IsTest
    static void testSearchEvents_PastEvents_ReturnsPastEventsAcrossBothSources() {
        MiltonEventSearchAction.EventSearchRequest req = new MiltonEventSearchAction.EventSearchRequest();
        req.contactId = getViewerId();
        req.eventType = 'Past_Events';

        Test.startTest();
        List<MiltonEventSearchAction.EventSearchOutput> outputs = MiltonEventSearchAction.searchEvents(
            new List<MiltonEventSearchAction.EventSearchRequest>{ req }
        );
        Test.stopTest();

        miltonEventSearchResponse resp = outputs[0].result;
        Set<String> resultNames = new Set<String>();
        for (miltonEventResult evt : resp.events) {
            resultNames.add(evt.eventName);
        }

        Assert.isTrue(resultNames.contains('Milton Past Homecoming'), 'Past Cvent event must appear in a Past Events search');
        Assert.isTrue(resultNames.contains('Milton Blackthorn Past Social'), 'Past Blackthorn event must appear in a Past Events search');
        Assert.isFalse(resultNames.contains('Milton Reunion Weekend'), 'An upcoming event must not appear in a Past Events search');
    }

    @IsTest
    static void testSearchEvents_EventNameFilter_MatchesPartialTitleOnly() {
        MiltonEventSearchAction.EventSearchRequest req = new MiltonEventSearchAction.EventSearchRequest();
        req.contactId = getViewerId();
        req.eventName = 'Reunion Weekend';

        Test.startTest();
        List<MiltonEventSearchAction.EventSearchOutput> outputs = MiltonEventSearchAction.searchEvents(
            new List<MiltonEventSearchAction.EventSearchRequest>{ req }
        );
        Test.stopTest();

        miltonEventSearchResponse resp = outputs[0].result;
        Assert.areEqual(1, resp.totalCount, 'Only the one matching event should be returned');
        Assert.areEqual('Milton Reunion Weekend', resp.events[0].eventName, 'The matched event must be the one whose title contains the search text');
        Assert.isNotNull(resp.events[0].location, 'Location should be populated from the venue field');
        Assert.isNotNull(resp.events[0].startDate, 'startDate should be formatted from the event start date');
    }

    @IsTest
    static void testSearchEvents_RegionFilter_IsCventOnlyAndAppliesAnytownNullRule() {
        MiltonEventSearchAction.EventSearchRequest req = new MiltonEventSearchAction.EventSearchRequest();
        req.contactId = getViewerId();
        req.eventRegion = 'Anytown';

        Test.startTest();
        List<MiltonEventSearchAction.EventSearchOutput> outputs = MiltonEventSearchAction.searchEvents(
            new List<MiltonEventSearchAction.EventSearchRequest>{ req }
        );
        Test.stopTest();

        miltonEventSearchResponse resp = outputs[0].result;
        Set<String> resultNames = new Set<String>();
        for (miltonEventResult evt : resp.events) {
            resultNames.add(evt.eventName);
        }

        Assert.isTrue(resultNames.contains('Milton Generic Region Event'), 'A blank-region Cvent event must be included when filtering by Anytown');
        Assert.isFalse(resultNames.contains('Milton Reunion Weekend'), 'A Boston-region event must not match an Anytown-only filter');
        Assert.isFalse(resultNames.contains('Milton Blackthorn Upcoming Mixer'), 'Blackthorn events must be skipped entirely once a region filter is supplied');
    }

    @IsTest
    static void testSearchEvents_RegionFilter_MatchesSpecificRegionOnly() {
        MiltonEventSearchAction.EventSearchRequest req = new MiltonEventSearchAction.EventSearchRequest();
        req.contactId = getViewerId();
        req.eventRegion = 'Boston';

        Test.startTest();
        List<MiltonEventSearchAction.EventSearchOutput> outputs = MiltonEventSearchAction.searchEvents(
            new List<MiltonEventSearchAction.EventSearchRequest>{ req }
        );
        Test.stopTest();

        miltonEventSearchResponse resp = outputs[0].result;
        Set<String> resultNames = new Set<String>();
        for (miltonEventResult evt : resp.events) {
            resultNames.add(evt.eventName);
        }

        Assert.isTrue(resultNames.contains('Milton Reunion Weekend'), 'The Boston-region event must be returned');
        Assert.isFalse(resultNames.contains('Milton Reunion NYC Mixer'), 'An NYC-region event must not match a Boston-only filter');
        Assert.isFalse(resultNames.contains('Milton Generic Region Event'), 'A blank-region event must not match a specific region filter (Anytown rule only applies to Anytown)');
    }
}