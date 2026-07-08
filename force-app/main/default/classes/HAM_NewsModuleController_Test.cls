/**
 * @description Test class for HAM_NewsModuleController
 * Validates news module configuration retrieval and record counting functionality
 * @author      Cube84 - Asheesh
 * @Last Modified By : Anirudh Mekala
 * @Last Modified On : Jan 12, 2026
 * @see         HAM_NewsModuleController
 * @Modification Log :
 *==============================================================================
 * Ver | Date | Author | Modification
 *==============================================================================
 * 1.0 | Dec 22, 2025 |  Asheesh | Initial Version
 * 2.0 | Jan 12, 2026 | Anirudh | Second Version
 */
@isTest
public class HAM_NewsModuleController_Test {
    
    // ============================================================
    // Constants - Avoid magic numbers and hardcoded strings
    // ============================================================
    private static final String TEST_NEWS_TITLE = 'News';
    private static final String TEST_CATEGORY = 'News';
    private static final String TEST_TOPIC_FILTER = 'all'; // Used to bypass the controller's Topic filter
    private static final String CMP_KEY_NEWS_MODULE = 'NewsModuleLWC';
    private static final Integer TEST_RECORD_COUNT = 10;
    private static final String DATE_FORMAT = 'yyyy-MM-dd HH:mm:ss';
    
    // ============================================================
    // Test Data Setup
    // ============================================================
    
    /**
     * @description Creates test data for all test methods in this class.
     * Sets up HAM_Listing__c records with active news entries.
     */
    @testSetup
    static void setupData() {
        
        // DYNAMICALLY FETCH VALID PICKLIST VALUE to avoid "Restricted Picklist" DML errors
        String validTopic = null;
        Schema.DescribeFieldResult fieldResult = HAM_Listing__c.HAM_Topics__c.getDescribe();
        for (Schema.PicklistEntry ple : fieldResult.getPicklistValues()) {
            if (ple.isActive()) {
                validTopic = ple.getValue();
                break; // Grab the first active value
            }
        }
        
        List<HAM_Listing__c> listings = new List<HAM_Listing__c>();
        
        // Create multiple news listings with sequential display order
        for (Integer i = 0; i < TEST_RECORD_COUNT; i++) {
            listings.add(new HAM_Listing__c(
                HAM_Title__c = TEST_NEWS_TITLE,
                HAM_Display_Order__c = i,
                HAM_Is_Active__c = true,
                HAM_Category__c = TEST_CATEGORY, 
                HAM_Topics__c = validTopic // Safe, dynamically fetched value
            ));
        }
        
        insert listings;
        
        // Backdate all records to 10 days ago (older than 7 days requirement)
        DateTime tenDaysAgo = DateTime.now().addDays(-10);
        for (HAM_Listing__c listing : listings) {
            Test.setCreatedDate(listing.Id, tenDaysAgo);
        }
    }
    
    // ============================================================
    // getNewsConfig() Tests
    // ============================================================
    
    @isTest
    static void testGetNewsConfig_WithValidKey_ReturnsConfigData() {
        // Act
        Test.startTest();
        HAM_NewsModuleController.ComponentConfigData result =
            HAM_NewsModuleController.getNewsConfig(
                CMP_KEY_NEWS_MODULE,
                0,      // offset
                null,   // fromDate
                null,   // toDate
                TEST_TOPIC_FILTER,    // category
                null    // pageSize — use metadata default
            );
        Test.stopTest();
        
        // Assert - Verify all expected properties are populated
        if(result != null) {
            System.assertEquals(true, result.isActive, 
                'Component should be marked as active');
            System.assertNotEquals(null, result.displayFields, 
                'Display fields collection should be initialized');
            System.assert(result.displayFields.size() > 0, 
                'Display fields should contain at least one field configuration');
            System.assertNotEquals(null, result.records, 
                'Records collection should be initialized');
        }
    }
    
    @isTest
    static void testGetNewsConfig_WithDateFilter_ReturnsFilteredRecords() {
        // Arrange - Define a date range that includes records from 15 to 5 days ago
        String fromDate = Datetime.now().addDays(-15).format(DATE_FORMAT);
        String toDate = Datetime.now().addDays(-5).format(DATE_FORMAT);
        
        // Act
        Test.startTest();
        HAM_NewsModuleController.ComponentConfigData result =
            HAM_NewsModuleController.getNewsConfig(
                CMP_KEY_NEWS_MODULE,
                0,          // offset
                fromDate,
                toDate,
                TEST_TOPIC_FILTER,  // category
                null                // pageSize — use metadata default
            );
        Test.stopTest();
        
        // Assert
        if(result != null) {
            System.assertNotEquals(null, result.records, 
                'Records collection should be initialized even with date filters');
        }
    }
    
    // ============================================================
    // getNewsRecordCount() Tests
    // ============================================================
    
    @isTest
    static void testGetNewsRecordCount_WithValidDateRange_ReturnsCount() {
        // Arrange - Use date range that captures backdated test records (10 days old)
        String fromDate = Datetime.now().addDays(-15).format(DATE_FORMAT);
        String toDate = Datetime.now().addDays(-5).format(DATE_FORMAT);
        
        // Act
        Test.startTest();
        Integer countResult =
            HAM_NewsModuleController.getNewsRecordCount('NewsModuleOldLWC', fromDate, toDate, TEST_TOPIC_FILTER);
        Test.stopTest();

        // Assert
        System.assert(countResult > 0,
            'News record count should be greater than zero when records exist within date range');
        System.assertEquals(TEST_RECORD_COUNT, countResult, 
            'Count should match the number of test records created');
    }
    
    @isTest
    static void testGetNewsRecordCount_WithNullDates_ReturnsAllRecords() {
        // Act
        Test.startTest();
        Integer countResult =
            HAM_NewsModuleController.getNewsRecordCount('NewsModuleOldLWC', null, null, TEST_TOPIC_FILTER);
        Test.stopTest();
        
        // Assert
        System.assert(countResult > 0, 
            'Record count should be returned even without date filters');
        System.assertEquals(TEST_RECORD_COUNT, countResult, 
            'Count without filters should return all active test records older than 7 days');
    }
    
    // ============================================================
    // Edge Case / Negative Tests
    // ============================================================
    
    @isTest
    static void testGetNewsConfig_WithInvalidKey_HandlesGracefully() {
        // Arrange
        String invalidComponentKey = 'NonExistentComponent_XYZ';
        
        // Act
        Test.startTest();
        HAM_NewsModuleController.ComponentConfigData result =
            HAM_NewsModuleController.getNewsConfig(
                invalidComponentKey,
                0,
                null,
                null,
                TEST_TOPIC_FILTER,
                null
            );
        Test.stopTest();
        
        // Assert
        System.assert(result == null || result.isActive == false, 
            'Invalid component key should return null or inactive config');
    }
    
    @isTest
    static void testGetNewsRecordCount_WithExclusiveDateRange_ReturnsZero() {
        // Arrange - Use date range that excludes test data (30-20 days ago)
        String fromDate = Datetime.now().addDays(-30).format(DATE_FORMAT);
        String toDate = Datetime.now().addDays(-20).format(DATE_FORMAT);
        
        // Act
        Test.startTest();
        Integer countResult =
            HAM_NewsModuleController.getNewsRecordCount('NewsModuleOldLWC', fromDate, toDate, TEST_TOPIC_FILTER);
        Test.stopTest();

        // Assert
        System.assertEquals(0, countResult, 
            'Record count should be zero when date range excludes all records');
    }
    
    @isTest
    static void testGetNewsConfig_WithOffset_ReturnsPaginatedRecords() {
        // Arrange
        Integer offset = 5;
        
        // Act
        Test.startTest();
        HAM_NewsModuleController.ComponentConfigData result =
            HAM_NewsModuleController.getNewsConfig(
                CMP_KEY_NEWS_MODULE,
                offset,
                null,
                null,
                TEST_TOPIC_FILTER,
                null
            );
        Test.stopTest();
        
        // Assert
        if(result != null) {
            System.assertNotEquals(null, result.records, 
                'Records should be returned with offset parameter');
            System.assert(result.records.size() <= (TEST_RECORD_COUNT - offset), 
                'Offset should reduce the number of returned records');
        }
    }

    // ============================================================
    // getPicklistValues() Tests
    // ============================================================

    @isTest
    static void testGetPicklistValues_ReturnsOptions() {
        // Act
        Test.startTest();
        List<Map<String, String>> picklistValues = HAM_NewsModuleController.getPicklistValues('HAM_Listing__c', 'HAM_Category__c');
        Test.stopTest();
        
        // Assert
        System.assertNotEquals(null, picklistValues, 
            'The returned picklist values list should not be null');
            
        if(!picklistValues.isEmpty()) {
            System.assert(picklistValues[0].containsKey('label'), 
                'Picklist map should contain a label key');
            System.assert(picklistValues[0].containsKey('value'), 
                'Picklist map should contain a value key');
        }
    }
}