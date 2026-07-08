@IsTest
private class ItineraryMapFinderTest {

    @IsTest
    static void test_ItineraryMapFinder_Constructor() {
        // Act
        ItineraryMapFinder finder = new ItineraryMapFinder();

        // Assert
        System.assertNotEquals(
            null,
            finder,
            'ItineraryMapFinder should be instantiated successfully'
        );
    }
}