@isTest
private class HAM_ConnectionsDashboardCtrlTest {

    @TestSetup
    static void setup() {
        Contact portalUser = new Contact(LastName = 'Portal Test User');
        Contact linked = new Contact(LastName = 'Linked Test Contact');
        insert new List<Contact>{ portalUser, linked };

        List<HAM_Connection__c> conns = new List<HAM_Connection__c>();
        conns.add(new HAM_Connection__c(
            HAM_Portal_User__c = portalUser.Id,
            HAM_Linked_Constituent__c = linked.Id,
            HAM_Data_Source__c = 'Portal User',
            HAM_Connection_Status__c = 'Connected'
        ));
        conns.add(new HAM_Connection__c(
            HAM_Portal_User__c = portalUser.Id,
            HAM_Linked_Constituent__c = linked.Id,
            HAM_Data_Source__c = 'Portal User',
            HAM_Is_bookmarked__c = true
        ));
        conns.add(new HAM_Connection__c(
            HAM_Portal_User__c = portalUser.Id,
            HAM_Linked_Constituent__c = linked.Id,
            HAM_Data_Source__c = 'Admin',
            HAM_Is_bookmarked__c = true
        ));
        insert conns;
    }

    @isTest
    static void testGetKpis() {
        Test.startTest();
        HAM_ConnectionsDashboardCtrl.Kpis k = HAM_ConnectionsDashboardCtrl.getKpis();
        Test.stopTest();

        System.assertNotEquals(null, k);
        System.assert(k.newConnections >= 0);
        System.assert(k.newBookmarks >= 0);
    }

    @isTest
    static void testGetStatusBreakdown() {
        Test.startTest();
        List<HAM_ConnectionsDashboardCtrl.NameValue> breakdown = HAM_ConnectionsDashboardCtrl.getStatusBreakdown();
        Test.stopTest();

        System.assertNotEquals(null, breakdown);
    }

    @isTest
    static void testGetDailyTrend() {
        Test.startTest();
        List<HAM_ConnectionsDashboardCtrl.DailyPoint> points = HAM_ConnectionsDashboardCtrl.getDailyTrend(14);
        List<HAM_ConnectionsDashboardCtrl.DailyPoint> defaultPoints = HAM_ConnectionsDashboardCtrl.getDailyTrend(null);
        Test.stopTest();

        System.assertEquals(14, points.size());
        System.assertEquals(14, defaultPoints.size());
    }

    @isTest
    static void testGetAllTimeTotals() {
        Test.startTest();
        HAM_ConnectionsDashboardCtrl.AllTimeTotals t = HAM_ConnectionsDashboardCtrl.getAllTimeTotals();
        Test.stopTest();

        System.assertNotEquals(null, t);
        System.assert(t.total >= 2); // the two Portal User records from setup
    }
}