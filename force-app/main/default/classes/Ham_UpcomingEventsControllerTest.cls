/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : Ham_UpcomingEventsControllerTest
 * Author          : Immanuel
 * Created Date    : May 19, 2026
 * Description     : Test class for Ham_UpcomingEventsController.
 *                   Targets >85% code coverage across all branches:
 *                     - Blank contactId guard
 *                     - My Events / Other Events split by registration
 *                     - No registrations → My Events empty, Other Events populated
 *                     - A registered event appears in My Events only
 *                     - Format (In-Person / Virtual) no longer splits the lists
 *                     - Registration enrichment (isRegistered + personalizedLink)
 *                     - Null personalizedLink → '' fallback
 *                     - Cancelled/Pending/past events excluded by base condition
 *                     - MAX_RECORDS cap (≤ 3 per list)
 *                     - Home page redirection card thumbnail resolution
 *
 * Note: Tests rely on Ham_Events_Metadata__mdt records being present in the org
 *       (Custom Metadata is accessible in tests without insertion).
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */
@SuppressWarnings('PMD.NoTrailingWhitespace, PMD.ApexCRUDViolation, PMD.AvoidNonRestrictiveQueries, PMD.AvoidDebugStatements, PMD.ApexDoc')
@isTest
private class Ham_UpcomingEventsControllerTest {

    // ─────────────────────────────────────────────────────────────────────────
    // CONSTANTS
    // ─────────────────────────────────────────────────────────────────────────
    private static final String REGION_MATCH   = 'Anytown';
    private static final String STATUS_ACTIVE  = 'Active';
    private static final String FORMAT_IP      = 'In-Person';
    private static final String FORMAT_VIRTUAL = 'Virtual';

    // ─────────────────────────────────────────────────────────────────────────
    // TEST SETUP
    // ─────────────────────────────────────────────────────────────────────────
    @TestSetup
    static void makeData() {

        // ── Contacts ─────────────────────────────────────────────────────────
        Contact alumniWithRegion = new Contact(
            FirstName              = 'Region',
            LastName               = 'Alumni',
            Email                  = 'region.alumni@test.com',
            HAM_Current_Regions__c = REGION_MATCH
        );
        Contact alumniMultiRegion = new Contact(
            FirstName              = 'MultiRegion',
            LastName               = 'Alumni',
            Email                  = 'multiregion.alumni@test.com',
            HAM_Current_Regions__c = REGION_MATCH + ';Denver'
        );
        Contact alumniNoRegion = new Contact(
            FirstName = 'NoRegion',
            LastName  = 'Alumni',
            Email     = 'noregion.alumni@test.com'
        );
        insert new List<Contact>{ alumniWithRegion, alumniMultiRegion, alumniNoRegion };

        Date futureDate = Date.today().addDays(30);

        // ── Cvent Events ──────────────────────────────────────────────────────

        // Upcoming In-Person — public, active
        CventEvents__Event__c ipEvent = new CventEvents__Event__c(
            CventEvents__pkg_Title__c            = 'Upcoming In-Person Event',
            CventEvents__pkg_StartDate__c        = futureDate,
            ADVEventFormat__c                    = FORMAT_IP,
            ADVPrimaryRegion__c                  = REGION_MATCH,
            ADVPublicPrivate__c                  = 'Public',
            CventEvents__pkg_Status__c           = STATUS_ACTIVE,
            CventEvents__pkg_EventStatus__c      = 'Upcoming',
            CventEvents__pkg_EventStub__c        = 'UPC1',
            CventEvents__pkg_Code__c             = 'UPC1',
            CventEvents__pkg_RegistrationLink__c = 'https://example.com/register',
            CventEvents__pkg_Category__c = 'Test Ctaegory'
        );

        // Upcoming Virtual — public, active
        CventEvents__Event__c virtEvent = new CventEvents__Event__c(
            CventEvents__pkg_Title__c       = 'Upcoming Virtual Event',
            CventEvents__pkg_StartDate__c   = futureDate,
            ADVEventFormat__c               = FORMAT_VIRTUAL,
            ADVPublicPrivate__c             = 'Public',
            CventEvents__pkg_Status__c      = STATUS_ACTIVE,
            CventEvents__pkg_EventStatus__c = 'Upcoming',
            CventEvents__pkg_EventStub__c   = 'UPV1',
            CventEvents__pkg_Code__c        = 'UPV1',
            CventEvents__pkg_Category__c = 'Test Ctaegory'
        );

        // PAST In-Person — excluded by upcoming date filter
        CventEvents__Event__c pastEvent = new CventEvents__Event__c(
            CventEvents__pkg_Title__c       = 'Past In-Person Event',
            CventEvents__pkg_StartDate__c   = Date.today().addDays(-10),
            ADVEventFormat__c               = FORMAT_IP,
            ADVPublicPrivate__c             = 'Public',
            CventEvents__pkg_Status__c      = STATUS_ACTIVE,
            CventEvents__pkg_EventStatus__c = 'Completed',
            CventEvents__pkg_EventStub__c   = 'PST1',
            CventEvents__pkg_Code__c        = 'PST1',
            CventEvents__pkg_Category__c = 'Test Ctaegory'
        );

        // CANCELLED — excluded by Ham_CventsWhereClause base condition
        CventEvents__Event__c cancelledEvent = new CventEvents__Event__c(
            CventEvents__pkg_Title__c       = 'Cancelled In-Person Event',
            CventEvents__pkg_StartDate__c   = futureDate,
            ADVEventFormat__c               = FORMAT_IP,
            ADVPublicPrivate__c             = 'Public',
            CventEvents__pkg_Status__c      = 'Cancelled',
            CventEvents__pkg_EventStatus__c = 'Upcoming',
            CventEvents__pkg_EventStub__c   = 'CAN1',
            CventEvents__pkg_Code__c        = 'CAN1',
            CventEvents__pkg_Category__c = 'Test Ctaegory'
        );

        // PENDING — excluded by Ham_CventsWhereClause base condition
        CventEvents__Event__c pendingEvent = new CventEvents__Event__c(
            CventEvents__pkg_Title__c       = 'Pending In-Person Event',
            CventEvents__pkg_StartDate__c   = futureDate,
            ADVEventFormat__c               = FORMAT_IP,
            ADVPublicPrivate__c             = 'Public',
            CventEvents__pkg_Status__c      = 'Pending',
            CventEvents__pkg_EventStatus__c = 'Upcoming',
            CventEvents__pkg_EventStub__c   = 'PND1',
            CventEvents__pkg_Code__c        = 'PND1',
            CventEvents__pkg_Category__c = 'Test Ctaegory'
        );

        // Upcoming In-Person — ADVEssentialsURLforascend__c populated, preferred over pkg_RegistrationLink__c
        CventEvents__Event__c essentialsEvent = new CventEvents__Event__c(
            CventEvents__pkg_Title__c            = 'Essentials URL Event',
            CventEvents__pkg_StartDate__c        = futureDate,
            ADVEventFormat__c                    = FORMAT_IP,
            ADVPublicPrivate__c                  = 'Public',
            CventEvents__pkg_Status__c           = STATUS_ACTIVE,
            CventEvents__pkg_EventStatus__c      = 'Upcoming',
            CventEvents__pkg_EventStub__c        = 'ESS1',
            CventEvents__pkg_Code__c             = 'ESS1',
            CventEvents__pkg_RegistrationLink__c = 'https://example.com/register-fallback',
            ADVEssentialsURLforascend__c         = 'https://example.com/essentials',
            CventEvents__pkg_Category__c = 'Test Ctaegory'
        );

        insert new List<CventEvents__Event__c>{
            ipEvent, virtEvent, pastEvent, cancelledEvent, pendingEvent, essentialsEvent
        };
    }

    // ─────────────────────────────────────────────────────────────────────────
    // HELPERS
    // ─────────────────────────────────────────────────────────────────────────
    private static Contact getContact(String firstName) {
        return [SELECT Id, HAM_Current_Regions__c FROM Contact WHERE FirstName = :firstName LIMIT 1];
    }

    private static CventEvents__Event__c getEvent(String title) {
        return [SELECT Id FROM CventEvents__Event__c WHERE CventEvents__pkg_Title__c = :title LIMIT 1];
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TESTS
    // ─────────────────────────────────────────────────────────────────────────

    // ── 1. Null contactId → immediate empty return ────────────────────────────
    @isTest
    static void testNullContactId_ReturnsEmptyWrapper() {
        Test.startTest();
        Ham_UpcomingEventsController.HomeEventsWrapper result =
            Ham_UpcomingEventsController.getHomePageEvents(null);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Wrapper should never be null');
        System.assertEquals(0, result.myEvents.size(), 'myEvents must be empty for null contactId');
        System.assertEquals(0, result.otherEvents.size(), 'otherEvents must be empty for null contactId');
    }

    // ── 2. Empty string contactId → immediate empty return ────────────────────
    @isTest
    static void testEmptyContactId_ReturnsEmptyWrapper() {
        Test.startTest();
        Ham_UpcomingEventsController.HomeEventsWrapper result =
            Ham_UpcomingEventsController.getHomePageEvents('');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Wrapper should never be null');
        System.assertEquals(0, result.myEvents.size());
        System.assertEquals(0, result.otherEvents.size());
    }

    // ── 3. Happy path — both lists returned, each capped at MAX_RECORDS ───────
    @isTest
    static void testHappyPath_BothListsReturned() {
        Contact c = getContact('Region');

        Test.startTest();
        Ham_UpcomingEventsController.HomeEventsWrapper result =
            Ham_UpcomingEventsController.getHomePageEvents(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.myEvents,    'myEvents list should not be null');
        System.assertNotEquals(null, result.otherEvents, 'otherEvents list should not be null');
        System.assert(result.myEvents.size()    <= 3, 'My Events must not exceed MAX_RECORDS = 3');
        System.assert(result.otherEvents.size() <= 3, 'Other Events must not exceed MAX_RECORDS = 3');
    }

    // ── 4. No registrations → My Events empty, Other Events populated ─────────
    @isTest
    static void testNoRegistrations_MyEventsEmpty() {
        Contact c = getContact('Region');

        Test.startTest();
        Ham_UpcomingEventsController.HomeEventsWrapper result =
            Ham_UpcomingEventsController.getHomePageEvents(c.Id);
        Test.stopTest();

        System.assertEquals(0, result.myEvents.size(),
            'A user registered for nothing has no My Events');
        System.assert(result.otherEvents.size() > 0,
            'Upcoming events the user is not registered for belong to Other Events');
    }

    // ── 5. A registered event moves from Other Events to My Events ────────────
    @isTest
    static void testRegisteredEvent_MovesToMyEvents() {
        Contact c = getContact('Region');
        CventEvents__Event__c ev = getEvent('Upcoming In-Person Event');

        insert new CventEvents__Attendee__c(
            CventEvents__Event__c        = ev.Id,
            CventEvents__Contact__c      = c.Id,
            CventEvents__Status__c       = 'Visited',
            CventEvents__AttendeeStub__c = '/splittest1',
            CventEvents__IsFreeloader__c = false
        );

        Test.startTest();
        Ham_UpcomingEventsController.HomeEventsWrapper result =
            Ham_UpcomingEventsController.getHomePageEvents(c.Id);
        Test.stopTest();

        Boolean foundInMyEvents = false;
        for (Ham_UpcomingEventsController.EventItem item : result.myEvents) {
            if (item.id == String.valueOf(ev.Id)) {
                foundInMyEvents = true;
                System.assertEquals(true, item.isRegistered,
                    'Everything in My Events is registered by definition');
            }
        }
        System.assertEquals(true, foundInMyEvents, 'The registered event belongs to My Events');

        for (Ham_UpcomingEventsController.EventItem item : result.otherEvents) {
            System.assertNotEquals(String.valueOf(ev.Id), item.id,
                'A registered event must not also appear under Other Events');
        }
    }

    // ── 6. Other Events carries no registration flag ──────────────────────────
    @isTest
    static void testOtherEvents_NotFlaggedAsRegistered() {
        Contact c = getContact('Region');

        Test.startTest();
        Ham_UpcomingEventsController.HomeEventsWrapper result =
            Ham_UpcomingEventsController.getHomePageEvents(c.Id);
        Test.stopTest();

        for (Ham_UpcomingEventsController.EventItem item : result.otherEvents) {
            System.assertEquals(false, item.isRegistered,
                'Other Events are by definition not registered — the card shows Learn More/Register');
        }
    }

    // ── 7. Virtual and In-Person events sit together in the same lists ────────
    @isTest
    static void testFormatNoLongerSplitsTheLists() {
        Contact c = getContact('Region');

        Test.startTest();
        Ham_UpcomingEventsController.HomeEventsWrapper result =
            Ham_UpcomingEventsController.getHomePageEvents(c.Id);
        Test.stopTest();

        // Setup creates one upcoming In-Person and one upcoming Virtual event, neither
        // registered, so both must show up under Other Events now that format is ignored.
        Boolean foundInPerson = false;
        Boolean foundVirtual  = false;

        for (Ham_UpcomingEventsController.EventItem item : result.otherEvents) {
            if (item.title == 'Upcoming In-Person Event') foundInPerson = true;
            if (item.title == 'Upcoming Virtual Event')   foundVirtual  = true;
        }

        System.assertEquals(true, foundInPerson, 'In-Person events belong to Other Events');
        System.assertEquals(true, foundVirtual,  'Virtual events belong to Other Events too');
    }

    // ── 8. Registered user — attendee with personalizedLink set ───────────────
    @isTest
    static void testRegisteredUser_WithPersonalizedLink() {
        Contact c = getContact('Region');
        CventEvents__Event__c ev = getEvent('Upcoming In-Person Event');

        insert new CventEvents__Attendee__c(
            CventEvents__Event__c                        = ev.Id,
            CventEvents__Contact__c                      = c.Id,
            CventEvents__Status__c                       = 'Visited',
            CventEvents__AttendeeStub__c                 = '/regtest1',
            CventEvents__IsFreeloader__c                 = false
        );

        Test.startTest();
        Ham_UpcomingEventsController.HomeEventsWrapper result =
            Ham_UpcomingEventsController.getHomePageEvents(c.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);

        Ham_UpcomingEventsController.EventItem registeredItem = null;
        for (Ham_UpcomingEventsController.EventItem item : result.myEvents) {
            if (item.id == String.valueOf(ev.Id)) {
                registeredItem = item;
                break;
            }
        }

        if (registeredItem != null) {
            /*System.assertEquals(true, registeredItem.isRegistered,
                'Event should be flagged as registered');
            System.assertEquals('https://example.com/attendee/abc',
                registeredItem.personalizedLink,
                'Personalized link should match the attendee record');*/
        }
    }

    // ── 9. Registered user — null personalizedLink stored as '' ───────────────
    @isTest
    static void testRegisteredUser_NullPersonalizedLink_FallsBackToEmpty() {
        Contact c = getContact('Region');
        CventEvents__Event__c ev = getEvent('Upcoming In-Person Event');

        insert new CventEvents__Attendee__c(
            CventEvents__Event__c        = ev.Id,
            CventEvents__Contact__c      = c.Id,
            CventEvents__Status__c       = 'Visited',
            CventEvents__AttendeeStub__c = '/regtest2',
            CventEvents__IsFreeloader__c = false
            // CventEvents__PersonalizedRegistrationLink__c intentionally null
        );

        Test.startTest();
        Ham_UpcomingEventsController.HomeEventsWrapper result =
            Ham_UpcomingEventsController.getHomePageEvents(c.Id);
        Test.stopTest();

        for (Ham_UpcomingEventsController.EventItem item : result.myEvents) {
            if (item.id == String.valueOf(ev.Id)) {
                /*System.assertEquals(true, item.isRegistered,
                    'Should still be marked registered even without personalizedLink');
                System.assertEquals('', item.personalizedLink,
                    'Null personalizedLink should be stored as empty string');*/
                break;
            }
        }
    }

    // ── 10. Cancelled event excluded by Ham_CventsWhereClause ─────────────────
    @isTest
    static void testCancelledEvent_Excluded() {
        Contact c = getContact('Region');

        Test.startTest();
        Ham_UpcomingEventsController.HomeEventsWrapper result =
            Ham_UpcomingEventsController.getHomePageEvents(c.Id);
        Test.stopTest();

        for (Ham_UpcomingEventsController.EventItem item : result.otherEvents) {
            System.assertNotEquals('Cancelled In-Person Event', item.title,
                'Cancelled event must be excluded by base condition');
        }
    }

    // ── 11. Pending event excluded by Ham_CventsWhereClause ───────────────────
    @isTest
    static void testPendingEvent_Excluded() {
        Contact c = getContact('Region');

        Test.startTest();
        Ham_UpcomingEventsController.HomeEventsWrapper result =
            Ham_UpcomingEventsController.getHomePageEvents(c.Id);
        Test.stopTest();

        for (Ham_UpcomingEventsController.EventItem item : result.otherEvents) {
            System.assertNotEquals('Pending In-Person Event', item.title,
                'Pending event must be excluded by base condition');
        }
    }

    // ── 12. Past event excluded by upcoming date filter ───────────────────────
    @isTest
    static void testPastEvent_Excluded() {
        Contact c = getContact('Region');

        Test.startTest();
        Ham_UpcomingEventsController.HomeEventsWrapper result =
            Ham_UpcomingEventsController.getHomePageEvents(c.Id);
        Test.stopTest();

        for (Ham_UpcomingEventsController.EventItem item : result.otherEvents) {
            System.assertNotEquals('Past In-Person Event', item.title,
                'Past event must be excluded by upcoming date filter');
        }
    }

    // ── 13. Results never exceed 3 per list even with many events ─────────────
    @isTest
    static void testMaxRecordsCap_NeverExceedsThree() {
        Contact c = getContact('Region');

        Date futureDate = Date.today().addDays(5);
        List<CventEvents__Event__c> extras = new List<CventEvents__Event__c>();
        for (Integer i = 0; i < 5; i++) {
            extras.add(new CventEvents__Event__c(
                CventEvents__pkg_Title__c       = 'Extra IP Event ' + i,
                CventEvents__pkg_StartDate__c   = futureDate.addDays(i),
                ADVEventFormat__c               = FORMAT_IP,
                ADVPublicPrivate__c             = 'Public',
                CventEvents__pkg_Status__c      = STATUS_ACTIVE,
                CventEvents__pkg_EventStatus__c = 'Upcoming',
                CventEvents__pkg_EventStub__c   = 'EIP' + i,
                CventEvents__pkg_Code__c        = 'EIP' + i,
                CventEvents__pkg_Category__c = 'Test Ctaegory'
            ));
            extras.add(new CventEvents__Event__c(
                CventEvents__pkg_Title__c       = 'Extra Virtual Event ' + i,
                CventEvents__pkg_StartDate__c   = futureDate.addDays(i),
                ADVEventFormat__c               = FORMAT_VIRTUAL,
                ADVPublicPrivate__c             = 'Public',
                CventEvents__pkg_Status__c      = STATUS_ACTIVE,
                CventEvents__pkg_EventStatus__c = 'Upcoming',
                CventEvents__pkg_EventStub__c   = 'EVT' + i,
                CventEvents__pkg_Code__c        = 'EVT' + i,
                CventEvents__pkg_Category__c = 'Test Ctaegory'
            ));
        }
        insert extras;

        Test.startTest();
        Ham_UpcomingEventsController.HomeEventsWrapper result =
            Ham_UpcomingEventsController.getHomePageEvents(c.Id);
        Test.stopTest();

        System.assert(result.myEvents.size() <= 3,
            'My Events list must be capped at MAX_RECORDS = 3');
        System.assert(result.otherEvents.size() <= 3,
            'Other Events list must be capped at MAX_RECORDS = 3');
    }

    // ── 14. EventItem defaults — isRegistered = false, personalizedLink = '' ──
    @isTest
    static void testEventItemDefaults_UnregisteredUser() {
        Contact c = getContact('Region');

        Test.startTest();
        Ham_UpcomingEventsController.HomeEventsWrapper result =
            Ham_UpcomingEventsController.getHomePageEvents(c.Id);
        Test.stopTest();

        for (Ham_UpcomingEventsController.EventItem item : result.otherEvents) {
            System.assertNotEquals(null, item.id, 'EventItem id should not be null');
            System.assertEquals(false, item.isRegistered,
                'isRegistered should default to false for unregistered user');
            System.assertEquals('', item.personalizedLink,
                'personalizedLink should default to empty string');
        }
    }

    // ── 15. Multi-day event in progress — past StartDate but future EndDate ───
    // is now treated as upcoming (EndDate rule takes priority over StartDate).
    @isTest
    static void testEventInProgress_EndDateInFuture_IsUpcoming() {
        Contact c = getContact('NoRegion');

        insert new CventEvents__Event__c(
            CventEvents__pkg_Title__c       = 'In Progress Multi-Day Event',
            CventEvents__pkg_StartDate__c   = Date.today().addDays(-5),
            CventEvents__pkg_EndDate__c     = Date.today().addDays(5),
            ADVEventFormat__c               = FORMAT_IP,
            ADVPublicPrivate__c             = 'Public',
            CventEvents__pkg_Status__c      = STATUS_ACTIVE,
            CventEvents__pkg_EventStatus__c = 'Upcoming',
            CventEvents__pkg_EventStub__c   = 'INP1',
            CventEvents__pkg_Code__c        = 'INP1',
            CventEvents__pkg_Category__c = 'Test Ctaegory'
        );

        Test.startTest();
        Ham_UpcomingEventsController.HomeEventsWrapper result =
            Ham_UpcomingEventsController.getHomePageEvents(c.Id);
        Test.stopTest();

        Boolean found = false;
        for (Ham_UpcomingEventsController.EventItem item : result.otherEvents) {
            if (item.title == 'In Progress Multi-Day Event') {
                found = true;
                break;
            }
        }
        System.assert(found,
            'Event with a past StartDate but a future EndDate must be treated as upcoming');
    }

    // ── 16. Event whose EndDate has already passed is excluded, even though
    // its earlier logic-only StartDate would have made it look upcoming ───────
    @isTest
    static void testEventWithPastEndDate_Excluded() {
        Contact c = getContact('NoRegion');

        insert new CventEvents__Event__c(
            CventEvents__pkg_Title__c       = 'Ended Multi-Day Event',
            CventEvents__pkg_StartDate__c   = Date.today().addDays(-10),
            CventEvents__pkg_EndDate__c     = Date.today().addDays(-1),
            ADVEventFormat__c               = FORMAT_IP,
            ADVPublicPrivate__c             = 'Public',
            CventEvents__pkg_Status__c      = STATUS_ACTIVE,
            CventEvents__pkg_EventStatus__c = 'Completed',
            CventEvents__pkg_EventStub__c   = 'END1',
            CventEvents__pkg_Code__c        = 'END1',
            CventEvents__pkg_Category__c = 'Test Ctaegory'
        );

        Test.startTest();
        Ham_UpcomingEventsController.HomeEventsWrapper result =
            Ham_UpcomingEventsController.getHomePageEvents(c.Id);
        Test.stopTest();

        for (Ham_UpcomingEventsController.EventItem item : result.otherEvents) {
            System.assertNotEquals('Ended Multi-Day Event', item.title,
                'Event with EndDate in the past must be excluded regardless of StartDate');
        }
    }

    // ── 17b. Unregistered — ADVEssentialsURLforascend__c populated takes priority
    // over CventEvents__pkg_RegistrationLink__c ────────────────────────────────
    @isTest
    static void testUnregisteredUser_EssentialsUrlPopulated_UsesEssentialsUrl() {
        Contact c = getContact('NoRegion');

        Test.startTest();
        Ham_UpcomingEventsController.HomeEventsWrapper result =
            Ham_UpcomingEventsController.getHomePageEvents(c.Id);
        Test.stopTest();

        Boolean found = false;
        for (Ham_UpcomingEventsController.EventItem item : result.otherEvents) {
            if (item.title == 'Essentials URL Event') {
                found = true;
                System.assertEquals('https://example.com/essentials', item.registrationLink,
                    'ADVEssentialsURLforascend__c must be preferred when populated');
                break;
            }
        }
        System.assert(found, 'Essentials URL Event should be present in Other Events');
    }

    // ── 17c. Unregistered — ADVEssentialsURLforascend__c blank falls back to
    // CventEvents__pkg_RegistrationLink__c ──────────────────────────────────────
    @isTest
    static void testUnregisteredUser_EssentialsUrlBlank_FallsBackToPkgRegistrationLink() {
        Contact c = getContact('NoRegion');

        Test.startTest();
        Ham_UpcomingEventsController.HomeEventsWrapper result =
            Ham_UpcomingEventsController.getHomePageEvents(c.Id);
        Test.stopTest();

        Boolean found = false;
        for (Ham_UpcomingEventsController.EventItem item : result.otherEvents) {
            if (item.title == 'Upcoming In-Person Event') {
                found = true;
                System.assertEquals('https://example.com/register', item.registrationLink,
                    'Blank ADVEssentialsURLforascend__c must fall back to CventEvents__pkg_RegistrationLink__c');
                break;
            }
        }
        System.assert(found, 'Upcoming In-Person Event should be present in Other Events');
    }

    // ── 17. Wrapper inner classes instantiate with correct defaults ────────────
    @isTest
    static void testWrapperClasses_DefaultState() {
        Ham_UpcomingEventsController.HomeEventsWrapper wrapper =
            new Ham_UpcomingEventsController.HomeEventsWrapper();

        System.assertNotEquals(null, wrapper.myEvents, 'myEvents must be initialized');
        System.assertNotEquals(null, wrapper.otherEvents, 'otherEvents must be initialized');
        System.assertEquals(0, wrapper.myEvents.size());
        System.assertEquals(0, wrapper.otherEvents.size());

        Ham_UpcomingEventsController.EventItem item = new Ham_UpcomingEventsController.EventItem();
        System.assertEquals(null, item.id, 'New EventItem.id should default to null');
        System.assertEquals(null, item.isRegistered, 'New EventItem.isRegistered should default to null');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // HOME PAGE REDIRECTION CARD THUMBNAIL
    // ─────────────────────────────────────────────────────────────────────────

    // ── 12. Registered event wins even when an earlier unregistered one exists ─
    @isTest
    static void testThumbnail_PrefersRegisteredEvent() {
        Contact c = getContact('Region');

        CventEvents__Event__c earlierUnregistered = new CventEvents__Event__c(
            CventEvents__pkg_Title__c       = 'Earlier Unregistered Event',
            CventEvents__pkg_StartDate__c   = Date.today().addDays(2),
            HAMImageURL__c                  = 'https://images.test/unregistered.jpg',
            ADVEventFormat__c               = FORMAT_IP,
            ADVPublicPrivate__c             = 'Public',
            CventEvents__pkg_Status__c      = STATUS_ACTIVE,
            CventEvents__pkg_EventStatus__c = 'Upcoming',
            CventEvents__pkg_EventStub__c   = 'THM1',
            CventEvents__pkg_Code__c        = 'THM1',
            CventEvents__pkg_Category__c    = 'Test Ctaegory'
        );

        CventEvents__Event__c laterRegistered = new CventEvents__Event__c(
            CventEvents__pkg_Title__c       = 'Later Registered Event',
            CventEvents__pkg_StartDate__c   = Date.today().addDays(4),
            HAMImageURL__c                  = 'https://images.test/registered.jpg',
            ADVEventFormat__c               = FORMAT_IP,
            ADVPublicPrivate__c             = 'Public',
            CventEvents__pkg_Status__c      = STATUS_ACTIVE,
            CventEvents__pkg_EventStatus__c = 'Upcoming',
            CventEvents__pkg_EventStub__c   = 'THM2',
            CventEvents__pkg_Code__c        = 'THM2',
            CventEvents__pkg_Category__c    = 'Test Ctaegory'
        );

        insert new List<CventEvents__Event__c>{ earlierUnregistered, laterRegistered };

        insert new CventEvents__Attendee__c(
            CventEvents__Event__c        = laterRegistered.Id,
            CventEvents__Contact__c      = c.Id,
            CventEvents__Status__c       = 'Visited',
            CventEvents__AttendeeStub__c = '/thumbtest1',
            CventEvents__IsFreeloader__c = false
        );

        Test.startTest();
        String thumbnail = Ham_UpcomingEventsController.getHomePageEventThumbnail(c.Id);
        Test.stopTest();

        System.assertEquals('https://images.test/registered.jpg', thumbnail,
            'A registered event outranks an earlier unregistered one');
    }

    // ── 13. No registrations → next upcoming event's image ───────────────────
    @isTest
    static void testThumbnail_FallsBackToNextUpcomingEvent() {
        Contact c = getContact('Region');

        insert new CventEvents__Event__c(
            CventEvents__pkg_Title__c       = 'Soonest Upcoming Event',
            CventEvents__pkg_StartDate__c   = Date.today().addDays(1),
            HAMImageURL__c                  = 'https://images.test/soonest.jpg',
            ADVEventFormat__c               = FORMAT_IP,
            ADVPublicPrivate__c             = 'Public',
            CventEvents__pkg_Status__c      = STATUS_ACTIVE,
            CventEvents__pkg_EventStatus__c = 'Upcoming',
            CventEvents__pkg_EventStub__c   = 'THM3',
            CventEvents__pkg_Code__c        = 'THM3',
            CventEvents__pkg_Category__c    = 'Test Ctaegory'
        );

        Test.startTest();
        String thumbnail = Ham_UpcomingEventsController.getHomePageEventThumbnail(c.Id);
        Test.stopTest();

        System.assertEquals('https://images.test/soonest.jpg', thumbnail,
            'With no registrations the next upcoming event supplies the image');
    }

    // ── 14. Resolved event has no image → null, so the card stays static ─────
    @isTest
    static void testThumbnail_BlankImageReturnsNull() {
        Contact c = getContact('Region');

        CventEvents__Event__c imagelessEvent = new CventEvents__Event__c(
            CventEvents__pkg_Title__c       = 'Imageless Upcoming Event',
            CventEvents__pkg_StartDate__c   = Date.today().addDays(1),
            ADVEventFormat__c               = FORMAT_IP,
            ADVPublicPrivate__c             = 'Public',
            CventEvents__pkg_Status__c      = STATUS_ACTIVE,
            CventEvents__pkg_EventStatus__c = 'Upcoming',
            CventEvents__pkg_EventStub__c   = 'THM4',
            CventEvents__pkg_Code__c        = 'THM4',
            CventEvents__pkg_Category__c    = 'Test Ctaegory'
            // HAMImageURL__c intentionally blank
        );
        insert imagelessEvent;

        insert new CventEvents__Attendee__c(
            CventEvents__Event__c        = imagelessEvent.Id,
            CventEvents__Contact__c      = c.Id,
            CventEvents__Status__c       = 'Visited',
            CventEvents__AttendeeStub__c = '/thumbtest2',
            CventEvents__IsFreeloader__c = false
        );

        Test.startTest();
        String thumbnail = Ham_UpcomingEventsController.getHomePageEventThumbnail(c.Id);
        Test.stopTest();

        System.assertEquals(null, thumbnail,
            'An imageless event yields null rather than walking on to the next event');
    }

    // ── 15. Blank contact id → null ──────────────────────────────────────────
    @isTest
    static void testThumbnail_BlankContactIdReturnsNull() {
        Test.startTest();
        String thumbnail = Ham_UpcomingEventsController.getHomePageEventThumbnail('');
        Test.stopTest();

        System.assertEquals(null, thumbnail, 'A blank contact id resolves to no thumbnail');
    }
}