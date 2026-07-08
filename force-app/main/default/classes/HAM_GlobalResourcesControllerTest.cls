/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : HAM_GlobalResourcesControllerTest
 * Description     : Test class for HAM_GlobalResourcesController
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */
@SuppressWarnings('PMD.NoTrailingWhitespace, PMD.ExcessiveClassLength, PME.ExcessivePublicCount, PMD.ApexCRUDViolation, PMD.EmptyIfStmt, PMD.EmptyStatementBlock, PMD.AvoidNonRestrictiveQueries, PMD.CyclomaticComplexity, PMD.CognitiveComplexity, PMD.NcssCount, PMD.NcssTypeCount, PMD.DetectCopyPasteForApex, PMD.LocalVariableNamingConventions, PMD.ExcessiveParameterList, PMD.ApexSOQLInjection, PMD.AvoidDeeplyNestedIfStmts, PMD.AvoidDebugStatements, PMD.StdCyclomaticComplexity, PMD.NcssMethodCount')
@IsTest
private class HAM_GlobalResourcesControllerTest {

    @TestSetup
    static void setupTestData() {
        List<HAM_Listing__c> testListings = new List<HAM_Listing__c>();

        // 1. Valid Record (Category = Resources, Is_Active = true)
        testListings.add(new HAM_Listing__c(
            HAM_Title__c = 'Test Resource 1',
            HAM_Category__c = 'Resources',
            HAM_Is_Active__c = true,
            HAM_Actual_link__c = 'https://test.com/1',
            HAM_Image_URL__c = 'https://test.com/img1.jpg'
        ));

        // 2. Valid Record (Category = Resources, Is_Active = true)
        testListings.add(new HAM_Listing__c(
            HAM_Title__c = 'Test Resource 2',
            HAM_Category__c = 'Resources',
            HAM_Is_Active__c = true,
            HAM_Actual_link__c = 'https://test.com/2',
            HAM_Image_URL__c = 'https://test.com/img2.jpg'
        ));

        // 3. Negative Record - Wrong Category
        testListings.add(new HAM_Listing__c(
            HAM_Title__c = 'Test News Listing',
            HAM_Category__c = 'News',
            HAM_Is_Active__c = true,
            HAM_Actual_link__c = 'https://test.com/news'
        ));

        // 4. Negative Record - Inactive Resource
        testListings.add(new HAM_Listing__c(
            HAM_Title__c = 'Test Inactive Resource',
            HAM_Category__c = 'Resources',
            HAM_Is_Active__c = false,
            HAM_Actual_link__c = 'https://test.com/inactive'
        ));

        insert testListings;
    }

    @IsTest
    static void testGetResources_Success() {
        // ACT
        Test.startTest();
        List<HAM_GlobalResourcesController.ResourceWrapper> results = HAM_GlobalResourcesController.getResources();
        Test.stopTest();

        // ASSERT
        // Should only return the 2 records that are active and have category 'Resources'
        System.assertEquals(2, results.size(), 'Expected exactly 2 active resources to be returned.');

        // Verify the wrapper field mappings
        Boolean foundResource1 = false;
        for(HAM_GlobalResourcesController.ResourceWrapper wrapper : results) {
            System.assertNotEquals(null, wrapper.id, 'Wrapper ID should not be null');
            
            if(wrapper.title == 'Test Resource 1') {
                foundResource1 = true;
                System.assertEquals('https://test.com/1', wrapper.linkUrl, 'Link URL mapping failed');
                System.assertEquals('https://test.com/img1.jpg', wrapper.imageUrl, 'Image URL mapping failed');
            }
        }
        
        System.assert(foundResource1, 'Expected "Test Resource 1" to be included in the results.');
    }
}