@isTest
private class EventTimezoneControllerTest {

    /**
     * @description Sets up test data once for all test methods in this class.
     * Creates one Contact-linked Event and one Event without a Contact.
     */
    @testSetup
    static void setupTestData() {
        Contact c = new Contact(
            FirstName = 'Test',
            LastName = 'Contact' + String.valueOf(DateTime.now().getTime())
        );
        insert c;

        Event e = new Event(
            Subject = 'Test Meeting',
            StartDateTime = DateTime.newInstance(2024, 3, 15, 17, 0, 0),
            EndDateTime = DateTime.newInstance(2024, 3, 15, 18, 0, 0),
            DurationInMinutes = 60,
            ActivityDateTime = DateTime.newInstance(2024, 3, 15, 17, 0, 0),
            WhoId = c.Id
        );
        insert e;

        Event eNoContact = new Event(
            Subject = 'No Contact Meeting',
            StartDateTime = DateTime.newInstance(2024, 3, 15, 17, 0, 0),
            EndDateTime = DateTime.newInstance(2024, 3, 15, 18, 0, 0),
            DurationInMinutes = 60,
            ActivityDateTime = DateTime.newInstance(2024, 3, 15, 17, 0, 0)
        );
        insert eNoContact;
    }

    /**
     * @description Tests that getStartTimeET, getEndTimeET, and getWhoNameWithSuffix
     * all return non-null values when the Event has a linked Contact via WhoId.
     */
    @isTest
    static void testTimezoneConversionWithContact() {
        Contact c = [SELECT Id FROM Contact LIMIT 1];
        Event e = [SELECT Id FROM Event WHERE WhoId = :c.Id LIMIT 1];

        System.runAs(new User(Id = UserInfo.getUserId())) {
            EventTimezoneController ctrl = new EventTimezoneController();
            ctrl.eventId = e.Id;

            System.assertNotEquals(null, ctrl.getStartTimeET(), 'Start time should not be null');
            System.assertNotEquals(null, ctrl.getEndTimeET(), 'End time should not be null');
            System.assertNotEquals(null, ctrl.getWhoNameWithSuffix(), 'Who name should not be null');
        }
    }

    /**
     * @description Tests that getWhoNameWithSuffix returns an empty string
     * when the Event has no WhoId (no linked Contact or Lead).
     */
    @isTest
    static void testWhoNameWithSuffixNoContact() {
        Event e = [SELECT Id FROM Event WHERE WhoId = null LIMIT 1];

        System.runAs(new User(Id = UserInfo.getUserId())) {
            EventTimezoneController ctrl = new EventTimezoneController();
            ctrl.eventId = e.Id;

            System.assertEquals('', ctrl.getWhoNameWithSuffix(), 'Should return empty string with no WhoId');
        }
    }
}