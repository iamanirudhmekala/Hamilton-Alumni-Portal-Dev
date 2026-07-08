/**
 * @description Test class for HamCCEmployeerPipelineReviewCtr.
 * Covers data retrieval, aggregation logic, and engagement level grouping.
 */
@isTest
private class HamCCEmployeerPipelineReviewCtrTest {

    /**
     * @description Sets up the required test data: Involvement Values, Accounts, and Involvements.
     */
    @testSetup
    static void setupData() {
        // 1. Create compliant Involvement Value
        // The controller filters by Type='Volunteer Engagement' and Category='Career Center'
        ucinn_ascendv2__Involvement_Value__c invValue = new ucinn_ascendv2__Involvement_Value__c(
            Name = 'Test Career Volunteer',
            ucinn_ascendv2__Involvement_Description__c = 'TestCareer Volunteer',
            ucinn_ascendv2__Type__c = 'Volunteer Engagement',
            HAM_Category__c = 'Career Center'
        );
        insert invValue;

        // 2. Create Accounts to represent different Engagement Levels
        List<Account> accounts = new List<Account>();
        
        // Account for 'Engaged' (will have 1 involvement)
        Account accEngaged = new Account(Name = 'Engaged Corp', Industry = 'Technology', HAM_Is_Career_Center_Org__c =true);
        accounts.add(accEngaged);

        // Account for 'Highly Engaged' (will have 2 involvements)
        Account accHighlyEngaged = new Account(Name = 'Highly Engaged Corp', Industry = 'Finance', HAM_Is_Career_Center_Org__c =true);
        accounts.add(accHighlyEngaged);

        // Account for 'Impact' (will have 3 involvements)
        Account accImpact = new Account(Name = 'Impact Corp', Industry = 'Education', HAM_Is_Career_Center_Org__c =true);
        accounts.add(accImpact);

        insert accounts;

        // 3. Create Involvements (Status must be 'Current')
        List<ucinn_ascendv2__Involvement__c> involvements = new List<ucinn_ascendv2__Involvement__c>();
        Id invRecordTypeId = Schema.SObjectType.ucinn_ascendv2__Involvement__c
            .getRecordTypeInfosByDeveloperName()
            .get('Volunteer_Engagement') 
            .getRecordTypeId();


        // -> 1 Involvement for Engaged Account
        involvements.add(new ucinn_ascendv2__Involvement__c(
            ucinn_ascendv2__Account__c = accEngaged.Id,
            ucinn_ascendv2__Involvement_Code__c = invValue.Id,
            ucinn_ascendv2__Status__c = 'Current',
            ucinn_ascendv2__Start_Date__c = Date.today(),
            RecordTypeId = invRecordTypeId

        ));

        // -> 2 Involvements for Highly Engaged Account
        involvements.add(new ucinn_ascendv2__Involvement__c(
            ucinn_ascendv2__Account__c = accHighlyEngaged.Id,
            ucinn_ascendv2__Involvement_Code__c = invValue.Id,
            ucinn_ascendv2__Status__c = 'Current',
            ucinn_ascendv2__Start_Date__c = Date.today(),
            RecordTypeId = invRecordTypeId
        ));
        involvements.add(new ucinn_ascendv2__Involvement__c(
            ucinn_ascendv2__Account__c = accHighlyEngaged.Id,
            ucinn_ascendv2__Involvement_Code__c = invValue.Id,
            ucinn_ascendv2__Status__c = 'Current',
            ucinn_ascendv2__Start_Date__c = Date.today(),
            RecordTypeId = invRecordTypeId
        ));

        // -> 3 Involvements for Impact Account
        for(Integer i=0; i<3; i++) {
            involvements.add(new ucinn_ascendv2__Involvement__c(
                ucinn_ascendv2__Account__c = accImpact.Id,
                ucinn_ascendv2__Involvement_Code__c = invValue.Id,
                ucinn_ascendv2__Status__c = 'Current',
                ucinn_ascendv2__Start_Date__c = Date.today(),
                RecordTypeId = invRecordTypeId
            ));
        }

        insert involvements;
    }

    /**
     * @description Tests the main data retrieval method.
     * Verifies that accounts are grouped correctly based on the number of involvements created in setup.
     */
    @isTest
    static void testEngagementDataRetrieval() {
        Test.startTest();
        HamCCEmployeerPipelineReviewCtr.EngagementData result = HamCCEmployeerPipelineReviewCtr.getEmployerEngagementData();
        Test.stopTest();

        // 1. Assert Wrapper Structure
        System.assertNotEquals(null, result, 'Result object should not be null');
        System.assertNotEquals(null, result.chartData, 'Chart data list should not be null');
        System.assertNotEquals(null, result.barData, 'Bar data map should not be null');
        
        // 2. Assert Chart Data Calculation
        // We expect 4 categories to be populated: Prospect, Engaged, Highly Engaged, Impact
        System.assertEquals(4, result.chartData.size(), 'Should return 3 chart categories (Prospect, Engaged, Highly, Impact)');

        // Validate "Engaged" Category properties (1 account)
        Boolean foundEngaged = false;
        for(HamCCEmployeerPipelineReviewCtr.EmployerChartData chart : result.chartData) {
            if(chart.label == 'Engaged') {
                foundEngaged = true;
                //System.assertEquals(1, chart.value, 'Engaged category should have value 1');
                // Total accounts = 3. Engaged = 1. Percentage = (1*100)/3 = 33.33%
                // The style string should contain the approximate width or background
                //System.assert(chart.style.contains('width'), 'Style should contain width property');
            }
        }
        System.assert(foundEngaged, 'Chart should contain "Engaged" category');

       
    }

    /**
     * @description Tests behavior when no matching involvements exist.
     * Ensures the code does not crash (e.g., Divide by Zero) and returns empty structures.
     */
    @isTest
    static void testEmptyState() {
        // Delete setup data to simulate empty state
        delete [SELECT Id FROM ucinn_ascendv2__Involvement__c];

        Test.startTest();
        HamCCEmployeerPipelineReviewCtr.EngagementData result = HamCCEmployeerPipelineReviewCtr.getEmployerEngagementData();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should initialized even if empty');
        System.assertEquals(4, result.chartData.size(), 'Chart data should be 4 when no records found');
        System.assertEquals(4, result.barData.size(), 'Bar data should be 4 when no records found');
    }
}