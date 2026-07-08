@IsTest
private class AttendeeTest {

    @IsTest
    static void test_Attendee_PropertyGetSet() {
        // Arrange
        Attendee a = new Attendee();

        // Act
        a.fundraiser = 'a0B000000000123EAA';
        a.fundraiserName = 'LeedsSource Gala 2026';
        a.fundraiserRole = 'Host';

        // Assert
        System.assertEquals('a0B000000000123EAA', a.fundraiser, 'fundraiser should be stored/retrieved');
        System.assertEquals('LeedsSource Gala 2026', a.fundraiserName, 'fundraiserName should be stored/retrieved');
        System.assertEquals('Host', a.fundraiserRole, 'fundraiserRole should be stored/retrieved');
    }

    @IsTest
    static void test_Attendee_DefaultsAreNull() {
        Attendee a = new Attendee();

        System.assertEquals(null, a.fundraiser, 'fundraiser should default to null');
        System.assertEquals(null, a.fundraiserName, 'fundraiserName should default to null');
        System.assertEquals(null, a.fundraiserRole, 'fundraiserRole should default to null');
    }
}