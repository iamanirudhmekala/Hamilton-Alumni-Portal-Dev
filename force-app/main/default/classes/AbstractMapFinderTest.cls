@IsTest
private class AbstractMapFinderTest {

    // Concrete implementation for testing only
    private class TestMapFinder extends AbstractMapFinder {
        // No additional implementation needed
    }

    @IsTest
    static void test_AbstractMapFinder_Constructor() {
        // Act
        AbstractMapFinder finder = new TestMapFinder();

        // Assert
        System.assertNotEquals(null, finder, 'AbstractMapFinder subclass should be instantiated');
    }
}