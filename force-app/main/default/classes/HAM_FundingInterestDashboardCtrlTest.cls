@isTest
private class HAM_FundingInterestDashboardCtrlTest {

    @TestSetup
    static void setup() {
        List<ucinn_ascendv2__Funding_Interest__c> interests = new List<ucinn_ascendv2__Funding_Interest__c>();
        interests.add(new ucinn_ascendv2__Funding_Interest__c(
            HAM_Category__c = 'Events Volunteer',
            ucinn_ascendv2__Data_Source__c = 'Self Reported'
        ));
        interests.add(new ucinn_ascendv2__Funding_Interest__c(
            HAM_Category__c = 'Career Center'
        ));
        interests.add(new ucinn_ascendv2__Funding_Interest__c());
        insert interests;
    }

    @isTest
    static void testGetKpis() {
        Test.startTest();
        HAM_FundingInterestDashboardCtrl.Kpis k = HAM_FundingInterestDashboardCtrl.getKpis();
        Test.stopTest();

        System.assertNotEquals(null, k);
        System.assert(k.new30 >= 3);
        System.assert(k.allTimeTotal >= 3);
    }

    @isTest
    static void testGetNewByCategory30() {
        Test.startTest();
        List<HAM_FundingInterestDashboardCtrl.NameValue> byCategory = HAM_FundingInterestDashboardCtrl.getNewByCategory30();
        Test.stopTest();

        System.assertNotEquals(null, byCategory);
        System.assert(byCategory.size() >= 2);
    }

    @isTest
    static void testGetAllTimeByCategory() {
        Test.startTest();
        List<HAM_FundingInterestDashboardCtrl.NameValue> allTime = HAM_FundingInterestDashboardCtrl.getAllTimeByCategory();
        Integer noCategory = HAM_FundingInterestDashboardCtrl.getAllTimeNoCategoryCount();
        Test.stopTest();

        System.assertNotEquals(null, allTime);
        System.assert(noCategory >= 1);
    }
}