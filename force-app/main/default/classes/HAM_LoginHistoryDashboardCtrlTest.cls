/**
 * LoginHistory is a read-only system object — test context has no rows
 * for it and Apex tests cannot insert into it. These tests exercise
 * every method purely for governor-limit/query-shape correctness
 * (no exceptions, sane empty-state results), not business-data
 * assertions. Validate the actual filtering logic in a sandbox once
 * this is deployed, using getLoginIssues() against real data.
 */
@isTest
private class HAM_LoginHistoryDashboardCtrlTest {

    @isTest
    static void testGetKpis() {
        Test.startTest();
        HAM_LoginHistoryDashboardCtrl.Kpis k = HAM_LoginHistoryDashboardCtrl.getKpis();
        Test.stopTest();

        System.assertNotEquals(null, k);
        System.assert(k.total30 >= 0, 'total30 should be non-negative');
        System.assert(k.success30 >= 0, 'success30 should be non-negative');
    }

    @isTest
    static void testGetDailyUniqueLogins() {
        Test.startTest();
        List<HAM_LoginHistoryDashboardCtrl.DailyPoint> points = HAM_LoginHistoryDashboardCtrl.getDailyUniqueLogins(31);
        List<HAM_LoginHistoryDashboardCtrl.DailyPoint> defaultPoints = HAM_LoginHistoryDashboardCtrl.getDailyUniqueLogins(null);
        Test.stopTest();

        System.assertEquals(31, points.size());
        System.assertEquals(31, defaultPoints.size());
        for (HAM_LoginHistoryDashboardCtrl.DailyPoint p : points) {
            System.assert(p.distinctUsers >= 0, 'distinctUsers should be non-negative');
        }
    }

    @isTest
    static void testGetWeeklyLogins() {
        Test.startTest();
        List<HAM_LoginHistoryDashboardCtrl.WeeklyPoint> weeks = HAM_LoginHistoryDashboardCtrl.getWeeklyLogins(4);
        Test.stopTest();

        System.assertEquals(4, weeks.size());
        System.assertEquals(true, weeks[3].isPartialWeek);
    }

    @isTest
    static void testGetStatusBreakdown() {
        Test.startTest();
        List<HAM_LoginHistoryDashboardCtrl.NameValue> breakdown = HAM_LoginHistoryDashboardCtrl.getStatusBreakdown();
        Test.stopTest();

        System.assertNotEquals(null, breakdown);
    }

    @isTest
    static void testGetLoginIssues() {
        Test.startTest();
        HAM_LoginHistoryDashboardCtrl.LoginIssuePage page = HAM_LoginHistoryDashboardCtrl.getLoginIssues(1, 10, 14);
        HAM_LoginHistoryDashboardCtrl.LoginIssuePage defaultPage = HAM_LoginHistoryDashboardCtrl.getLoginIssues(null, null, null);
        Test.stopTest();

        System.assert(page.totalRecords >= 0, 'totalRecords should be non-negative');
        System.assert(page.totalPages >= 1, 'totalPages should be at least 1');
        System.assert(defaultPage.totalRecords >= 0, 'defaultPage totalRecords should be non-negative');
    }
}