@IsTest
private class HAMJediEventController_Test {

    @IsTest
    static void testGetEventsDetail_returnsAttendees() {
        // Arrange: full dataset (Account, Contact, 3 Attendees, 2 Email Results)
        Map<String, Object> ds = HAMJediTestDataFactory.createEventControllerTestDataset();
        Contact con = (Contact) ds.get('contact');
        List<SObject> rawAttendees = (List<SObject>) ds.get('attendees');
        List<CventEvents__Attendee__c> createdAttendees = new List<CventEvents__Attendee__c>();
        for (SObject s : rawAttendees) {
            createdAttendees.add((CventEvents__Attendee__c) s);
        }

        Test.startTest();
        // Act
        List<CventEvents__Attendee__c> got =
            HAMJediEventController.getEventsDetail(String.valueOf(con.Id));
        Test.stopTest();

        // Assert
        System.assertEquals(createdAttendees.size(), got.size(),
            'Should return all attendees for the contact');

        Set<Id> expected = new Set<Id>();
        for (CventEvents__Attendee__c a : createdAttendees) expected.add(a.Id);

        Set<Id> actual = new Set<Id>();
        for (CventEvents__Attendee__c a : got) actual.add(a.Id);

        System.assertEquals(expected, actual, 'Returned attendee Ids should match created ones');
    }

    @IsTest
    static void testGetEmailDetail_returnsEmails() {
        // Arrange
        Map<String, Object> ds = HAMJediTestDataFactory.createEventControllerTestDataset();
        Contact con = (Contact) ds.get('contact');
        List<SObject> rawEmails = (List<SObject>) ds.get('emails');
        List<et4ae5__IndividualEmailResult__c> createdEmails = new List<et4ae5__IndividualEmailResult__c>();
        for (SObject s : rawEmails) {
            createdEmails.add((et4ae5__IndividualEmailResult__c) s);
        }

        Test.startTest();
        // Act
        List<et4ae5__IndividualEmailResult__c> got =
            HAMJediEventController.getEmailDetail(String.valueOf(con.Id));
        Test.stopTest();

        // Assert
        System.assertEquals(createdEmails.size(), got.size(),
            'Should return all email results for the contact');

        Set<Id> expected = new Set<Id>();
        for (et4ae5__IndividualEmailResult__c e : createdEmails) expected.add(e.Id);

        Set<Id> actual = new Set<Id>();
        for (et4ae5__IndividualEmailResult__c e : got) actual.add(e.Id);

        System.assertEquals(expected, actual, 'Returned email result Ids should match created ones');
    }

    @IsTest
    static void testEmptyResults_forContactWithNoRecords() {
        // Arrange: fresh contact with no attendees/emails
        Account a = HAMJediTestDataFactory.makeAccount('No Activity Acct');
        Contact c = HAMJediTestDataFactory.makeContact('No Activity Contact', a.Id);

        Test.startTest();
        // Act
        List<CventEvents__Attendee__c> attendees =
            HAMJediEventController.getEventsDetail(String.valueOf(c.Id));
        List<et4ae5__IndividualEmailResult__c> emails =
            HAMJediEventController.getEmailDetail(String.valueOf(c.Id));
        Test.stopTest();

        // Assert
        System.assertEquals(0, attendees.size(), 'No attendees expected for new contact');
        System.assertEquals(0, emails.size(), 'No email results expected for new contact');
    }
}