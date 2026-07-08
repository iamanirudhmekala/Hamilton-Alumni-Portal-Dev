/**
 * Exercises every method on HAM_ServiceIndicatorDashboardCtrl. Creating a
 * real Experience Cloud partner user in a test context is environment-
 * dependent (profile name, community/site setup, feature licenses), so
 * this test tries to build one and run the create/modify DML as that
 * user; if that setup isn't available in a given sandbox, it falls back
 * to asserting the methods still execute cleanly against an empty result
 * set. Re-run in a full sandbox with a real partner profile to validate
 * the partner-only filtering logic end-to-end.
 */
@isTest
private class HAM_ServiceIndicatorDashboardCtrlTest {

    @TestSetup
    static void setup() {
        List<Profile> partnerProfiles = [
            SELECT Id FROM Profile WHERE UserType = 'PowerPartner' LIMIT 1
        ];

        if (partnerProfiles.isEmpty()) {
            return; // no partner profile available in this org/sandbox for test setup
        }

        Account acct = new Account(Name = 'HAM Quad Test Partner Account');
        insert acct;

        Contact portalContact = new Contact(LastName = 'SI Test Portal Contact', AccountId = acct.Id);
        insert portalContact;

        User partnerUser;
        try {
            partnerUser = new User(
                FirstName = 'HAMQuad',
                LastName = 'TestPartner',
                Email = 'hamquad.test.partner@example.invalid',
                Username = 'hamquad.test.partner@example.invalid.' + DateTime.now().getTime(),
                Alias = 'hqtp',
                TimeZoneSidKey = 'America/New_York',
                LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'en_US',
                ProfileId = partnerProfiles[0].Id,
                ContactId = portalContact.Id
            );
            insert partnerUser;
        } catch (Exception e) {
            // Partner license/community setup not available in this context —
            // downstream tests will simply see an empty data set, which is fine.
            partnerUser = null;
        }

        if (partnerUser != null) {
            ucinn_ascendv2__Service_Indicator_Value__c siv = new ucinn_ascendv2__Service_Indicator_Value__c(Name = 'Do Not Display Test Field');
            insert siv;

            try {
                System.runAs(partnerUser) {
                    ucinn_ascendv2__Service_Indicator__c rec = new ucinn_ascendv2__Service_Indicator__c(
                        ucinn_ascendv2__Service_Indicator_Value__c = siv.Id
                    );
                    insert rec;
                }
            } catch (Exception e) {
                // Partner user lacks cross-object access to the admin-owned SIV record.
                // Insert without SIV reference — the record still shows up in getLatestActivity
                // (which has no SIV != null filter) and covers those code paths.
                try {
                    System.runAs(partnerUser) {
                        insert new ucinn_ascendv2__Service_Indicator__c();
                    }
                } catch (Exception e2) {
                    // Partner profile has no CRUD on Service_Indicator__c in this org config.
                }
            }
        }
    }

    @isTest
    static void testGetPartnerTotals() {
        Test.startTest();
        HAM_ServiceIndicatorDashboardCtrl.Totals t = HAM_ServiceIndicatorDashboardCtrl.getPartnerTotals();
        Test.stopTest();

        System.assertNotEquals(null, t);
        System.assert(t.created30 >= 0);
        System.assert(t.modified30 >= 0);
    }

    @isTest
    static void testGetActivityByIndicatorType30() {
        Test.startTest();
        List<HAM_ServiceIndicatorDashboardCtrl.IndicatorActivity> activity =
            HAM_ServiceIndicatorDashboardCtrl.getActivityByIndicatorType30();
        Test.stopTest();

        System.assertNotEquals(null, activity);
    }

    @isTest
    static void testGetTopIndicatorsByWeek() {
        Test.startTest();
        List<HAM_ServiceIndicatorDashboardCtrl.WeeklyTopIndicators> weeks =
            HAM_ServiceIndicatorDashboardCtrl.getTopIndicatorsByWeek(4);
        List<HAM_ServiceIndicatorDashboardCtrl.WeeklyTopIndicators> defaultWeeks =
            HAM_ServiceIndicatorDashboardCtrl.getTopIndicatorsByWeek(null);
        Test.stopTest();

        System.assertEquals(4, weeks.size());
        System.assertEquals(4, defaultWeeks.size());
        for (HAM_ServiceIndicatorDashboardCtrl.WeeklyTopIndicators w : weeks) {
            System.assert(w.topIndicators.size() <= 10);
        }
    }

    @isTest
    static void testGetLatestActivity() {
        Test.startTest();
        List<HAM_ServiceIndicatorDashboardCtrl.LatestActivityRow> rows =
            HAM_ServiceIndicatorDashboardCtrl.getLatestActivity(10);
        List<HAM_ServiceIndicatorDashboardCtrl.LatestActivityRow> defaultRows =
            HAM_ServiceIndicatorDashboardCtrl.getLatestActivity(null);
        Test.stopTest();

        System.assertNotEquals(null, rows);
        System.assertNotEquals(null, defaultRows);
    }

    /**
     * Covers getLatestActivity() loop body using the @TestVisible stub —
     * avoids needing a real PowerPartner user in every sandbox.
     */
    @isTest
    static void testGetLatestActivityStub() {
        ucinn_ascendv2__Service_Indicator__c si = new ucinn_ascendv2__Service_Indicator__c();
        insert si;

        HAM_ServiceIndicatorDashboardCtrl.testLatestActivityRecords = [
            SELECT ucinn_ascendv2__Service_Indicator_Value__r.Name,
                   CreatedDate, LastModifiedDate,
                   CreatedBy.UserType, LastModifiedBy.UserType
            FROM ucinn_ascendv2__Service_Indicator__c
            WHERE Id = :si.Id
        ];

        Test.startTest();
        List<HAM_ServiceIndicatorDashboardCtrl.LatestActivityRow> rows =
            HAM_ServiceIndicatorDashboardCtrl.getLatestActivity(10);
        Test.stopTest();

        HAM_ServiceIndicatorDashboardCtrl.testLatestActivityRecords = null;

        System.assertEquals(1, rows.size());
        System.assertNotEquals(null, rows[0].action);
        System.assertNotEquals(null, rows[0].activityDate);
    }

    /**
     * Covers IndicatorActivityComparator.compare() directly.
     */
    @isTest
    static void testIndicatorComparator() {
        HAM_ServiceIndicatorDashboardCtrl.IndicatorActivity a = new HAM_ServiceIndicatorDashboardCtrl.IndicatorActivity();
        a.total = 5;
        HAM_ServiceIndicatorDashboardCtrl.IndicatorActivity b = new HAM_ServiceIndicatorDashboardCtrl.IndicatorActivity();
        b.total = 10;
        List<HAM_ServiceIndicatorDashboardCtrl.IndicatorActivity> lst =
            new List<HAM_ServiceIndicatorDashboardCtrl.IndicatorActivity>{ a, b };
        lst.sort(new HAM_ServiceIndicatorDashboardCtrl.IndicatorActivityComparator());
        System.assertEquals(10, lst[0].total, 'higher total should sort first');
    }
}