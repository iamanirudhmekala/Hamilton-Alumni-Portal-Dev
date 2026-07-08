/**
 * HamCCVolunteerDashboardControllerTest
 *
 * Full test coverage for both @AuraEnabled methods:
 *
 *   getVolunteerDashboardData()  — Tests 1-24
 *     Scope: Contact != null
 *
 *   getEmployerDashboardData()   — Tests 25-32
 *     Scope: Account.HAM_Is_Career_Center_Org__c = TRUE
 *
 * Key org facts:
 *   - FiscalYearStartMonth = 7 (July)
 *   - Involvement RT DeveloperName = 'Volunteer_Engagement'
 *   - HAM_Reunion_Year__c on Contact is a String (e.g. '1990')
 *   - HAM_Is_Career_Center_Org__c = TRUE flags real employer accounts
 *
 * ── Volunteer setup (contact-linked involvements) ────────────────
 *   ccCodeA  'CC Campus Visit'    — Con1 Current, Con2 Current, Con3 Former
 *   ccCodeB  'CC Career Coaching' — Con1 Former  → Con1 is multi-role
 *   nonCCCode 'Fundraising Vol'   — Con1 Current → EXCLUDED (non-CC code)
 *   out-of-FY ccCodeA             — Con4 Former  → EXCLUDED
 *
 *   Volunteer baseline:
 *     totalInvolvements=4, currentCount=2, formerCount=2,
 *     uniqueVolunteers=3,  multiRoleCount=1
 *     topVolunteers[0] = Con1, involvements=2, rank=1, status='Current'
 *
 * ── Employer setup (account-linked involvements) ─────────────────
 *   empAcc  (HAM_Is_Career_Center_Org__c=TRUE,  Name='Accenture')
 *     EmpInv1 ccCodeA Current  \
 *     EmpInv2 ccCodeA Current   } → multi-engagement, currentCount=2
 *     EmpInv3 ccCodeB Former   /
 *   nonCCAcc (HAM_Is_Career_Center_Org__c=FALSE) → EXCLUDED
 *     EmpInv4 ccCodeA Current
 *   out-of-FY empAcc involvement  → EXCLUDED
 *
 *   Employer baseline:
 *     totalInvolvements=3, uniqueEmployers=1,
 *     currentCount=2, multiEngagementCount=1
 */
@IsTest
private class HamCCVolunteerDashboardControllerTest {

    /* =========================================================
     * HELPERS
     * ========================================================= */

    private static Id getVolEngRtId() {
        return Schema.SObjectType.ucinn_ascendv2__Involvement__c
            .getRecordTypeInfosByDeveloperName()
            .get('Volunteer_Engagement')
            .getRecordTypeId();
    }

    private static ucinn_ascendv2__Involvement_Value__c makeCCValue(String label) {
        return new ucinn_ascendv2__Involvement_Value__c(
            Name                                       = label,
            ucinn_ascendv2__Type__c                    = 'Volunteer Engagement',
            HAM_Category__c                            = 'Career Center',
            HAM_CC_Score__c                            = 1,
            ucinn_ascendv2__Involvement_Description__c = label
        );
    }

    private static ucinn_ascendv2__Involvement_Value__c makeNonCCValue() {
        return new ucinn_ascendv2__Involvement_Value__c(
            Name                                       = 'Fundraising Vol',
            ucinn_ascendv2__Type__c                    = 'Volunteer Engagement',
            HAM_Category__c                            = 'Fundraising',
            HAM_CC_Score__c                            = 1,
            ucinn_ascendv2__Involvement_Description__c = 'Fundraising Vol'
        );
    }

    private static Contact makeContact(String lastName, String reunionYear, Id accountId) {
        return new Contact(
            LastName            = lastName,
            AccountId           = accountId,
            HAM_Reunion_Year__c = reunionYear
        );
    }

    /** Contact-linked involvement */
    private static ucinn_ascendv2__Involvement__c makeInvolvement(
        Id contactId, Id codeId, String status, Date startDate
    ) {
        return new ucinn_ascendv2__Involvement__c(
            RecordTypeId                        = getVolEngRtId(),
            ucinn_ascendv2__Contact__c          = contactId,
            ucinn_ascendv2__Involvement_Code__c = codeId,
            ucinn_ascendv2__Status__c           = status,
            ucinn_ascendv2__Start_Date__c       = startDate
        );
    }

    /** Account-linked involvement (no Contact) */
    private static ucinn_ascendv2__Involvement__c makeAccountInvolvement(
        Id accountId, Id codeId, String status, Date startDate
    ) {
        return new ucinn_ascendv2__Involvement__c(
            RecordTypeId                        = getVolEngRtId(),
            ucinn_ascendv2__Account__c          = accountId,
            ucinn_ascendv2__Involvement_Code__c = codeId,
            ucinn_ascendv2__Status__c           = status,
            ucinn_ascendv2__Start_Date__c       = startDate
        );
    }

    private static Date getFYStart() {
        Integer fyStartMonth = 7;
        Date    today        = Date.today();
        Integer fyStartYear  = today.month() >= fyStartMonth ? today.year() : today.year() - 1;
        return Date.newInstance(fyStartYear, fyStartMonth, 1);
    }

    /* =========================================================
     * @TESTSETUP
     * ========================================================= */
    @TestSetup
    static void setup() {
        // ── Shared involvement values ─────────────────────────
        ucinn_ascendv2__Involvement_Value__c ccCodeA   = makeCCValue('CC Campus Visit');
        ucinn_ascendv2__Involvement_Value__c ccCodeB   = makeCCValue('CC Career Coaching');
        ucinn_ascendv2__Involvement_Value__c nonCCCode = makeNonCCValue();
        insert new List<ucinn_ascendv2__Involvement_Value__c>{ ccCodeA, ccCodeB, nonCCCode };

        // ── Accounts ──────────────────────────────────────────
        // Plain account — parent for contact records
        Account plainAcc = new Account(Name = 'Test Account');
        // Career Center employer — picked up by getEmployerDashboardData
        Account empAcc   = new Account(Name = 'Accenture',         HAM_Is_Career_Center_Org__c = true);
        // Non-Career-Center account — employer involvements must be EXCLUDED
        Account nonCCAcc = new Account(Name = 'Household Account', HAM_Is_Career_Center_Org__c = false);
        insert new List<Account>{ plainAcc, empAcc, nonCCAcc };

        // ── Contacts (volunteer tab) ───────────────────────────
        Contact con1 = makeContact('MultiRole', '1990', plainAcc.Id);
        Contact con2 = makeContact('SingleA',   '2015', plainAcc.Id);
        Contact con3 = makeContact('SingleB',   '2022', plainAcc.Id);
        Contact con4 = makeContact('OutOfFY',   '2000', plainAcc.Id);
        insert new List<Contact>{ con1, con2, con3, con4 };

        Date fyStart = getFYStart();

        // ── Contact-linked involvements (volunteer tab) ────────
        insert new List<ucinn_ascendv2__Involvement__c>{
            makeInvolvement(con1.Id, ccCodeA.Id, 'Current', fyStart.addDays(10)),
            makeInvolvement(con1.Id, ccCodeB.Id, 'Former',  fyStart.addDays(15)),
            makeInvolvement(con2.Id, ccCodeA.Id, 'Current', fyStart.addDays(20)),
            makeInvolvement(con3.Id, ccCodeA.Id, 'Former',  fyStart.addDays(25)),
            // Non-CC code — excluded from both methods
            new ucinn_ascendv2__Involvement__c(
                RecordTypeId                        = getVolEngRtId(),
                ucinn_ascendv2__Contact__c          = con1.Id,
                ucinn_ascendv2__Involvement_Code__c = nonCCCode.Id,
                ucinn_ascendv2__Status__c           = 'Current',
                ucinn_ascendv2__Start_Date__c       = fyStart.addDays(5)
            ),
            // Out-of-FY — excluded from both methods
            makeInvolvement(con4.Id, ccCodeA.Id, 'Former', fyStart.addDays(-30))
        };

        // ── Account-linked involvements (employer tab) ─────────
        insert new List<ucinn_ascendv2__Involvement__c>{
            // empAcc: 2 Current + 1 Former in FY → uniqueEmployers=1, multiEngagementCount=1
            makeAccountInvolvement(empAcc.Id, ccCodeA.Id, 'Current', fyStart.addDays(5)),
            makeAccountInvolvement(empAcc.Id, ccCodeA.Id, 'Current', fyStart.addDays(8)),
            makeAccountInvolvement(empAcc.Id, ccCodeB.Id, 'Former',  fyStart.addDays(12)),
            // nonCCAcc — EXCLUDED (HAM_Is_Career_Center_Org__c = false)
            makeAccountInvolvement(nonCCAcc.Id, ccCodeA.Id, 'Current', fyStart.addDays(6)),
            // Out-of-FY empAcc involvement — EXCLUDED
            makeAccountInvolvement(empAcc.Id, ccCodeA.Id, 'Current', fyStart.addDays(-10))
        };
    }

    /* =========================================================
     * ── VOLUNTEER TESTS (1–24) ───────────────────────────────
     * ========================================================= */

    /* 1. KPI totals */
    @IsTest
    static void testKPITotalsCorrect() {
        Test.startTest();
        HamCCVolunteerDashboardController.DashboardData r =
            HamCCVolunteerDashboardController.getVolunteerDashboardData();
        Test.stopTest();

        System.assertEquals(4, r.totalInvolvements, '4 CC FY involvements expected');
        System.assertEquals(3, r.uniqueVolunteers,  '3 unique volunteers expected');
        System.assertEquals(1, r.multiRoleCount,    'Only Con1 has 2+ FY involvements');
    }

    /* 2. avgPerVolunteer */
    @IsTest
    static void testAvgPerVolunteer() {
        Test.startTest();
        HamCCVolunteerDashboardController.DashboardData r =
            HamCCVolunteerDashboardController.getVolunteerDashboardData();
        Test.stopTest();

        Decimal expected = (Decimal.valueOf(4) / 3).setScale(2);
        System.assertEquals(expected, r.avgPerVolunteer,
            'avgPerVolunteer = 4 / 3 rounded to 2dp');
    }

    /* 3. fyLabel */
    @IsTest
    static void testFYLabelPopulated() {
        Test.startTest();
        HamCCVolunteerDashboardController.DashboardData r =
            HamCCVolunteerDashboardController.getVolunteerDashboardData();
        Test.stopTest();

        System.assert(String.isNotBlank(r.fyLabel), 'fyLabel must not be blank');
        System.assert(r.fyLabel.startsWith('FY '),  'fyLabel must start with "FY "');
        System.assert(r.fyLabel.contains('Jul'),    'fyLabel must contain "Jul"');
    }

    /* 4. byCode — labels, sort, pct, cap */
    @IsTest
    static void testByCodePopulated() {
        Test.startTest();
        HamCCVolunteerDashboardController.DashboardData r =
            HamCCVolunteerDashboardController.getVolunteerDashboardData();
        Test.stopTest();

        System.assert(!r.byCode.isEmpty(),   'byCode must not be empty');
        System.assert(r.byCode.size() <= 10, 'byCode capped at 10');

        System.assertEquals('CC Campus Visit',    r.byCode[0].label, 'byCode[0] = CC Campus Visit');
        System.assertEquals(3,                    r.byCode[0].total, 'CC Campus Visit total = 3');
        System.assertEquals(100,                  r.byCode[0].pct,   'Top entry pct = 100');
        System.assertEquals('CC Career Coaching', r.byCode[1].label, 'byCode[1] = CC Career Coaching');
        System.assertEquals(1,                    r.byCode[1].total);

        for (Integer i = 1; i < r.byCode.size(); i++) {
            System.assert(r.byCode[i-1].total >= r.byCode[i].total, 'byCode must be sorted desc');
        }
    }

    /* 5. Non-CC involvements excluded */
    @IsTest
    static void testNonCCExcluded() {
        Test.startTest();
        HamCCVolunteerDashboardController.DashboardData r =
            HamCCVolunteerDashboardController.getVolunteerDashboardData();
        Test.stopTest();

        System.assertEquals(4, r.totalInvolvements, 'Non-CC must not be counted');
        for (HamCCVolunteerDashboardController.CodeCount cc : r.byCode) {
            System.assertNotEquals('Fundraising Vol', cc.label,
                'Fundraising Vol (non-CC) must never appear in byCode');
        }
    }

    /* 6. Out-of-FY involvements excluded */
    @IsTest
    static void testOutOfFYExcluded() {
        Test.startTest();
        HamCCVolunteerDashboardController.DashboardData r =
            HamCCVolunteerDashboardController.getVolunteerDashboardData();
        Test.stopTest();

        System.assertEquals(4, r.totalInvolvements, 'Out-of-FY involvement (Con4) must not be counted');
        System.assertEquals(3, r.uniqueVolunteers,  'Con4 must not appear in uniqueVolunteers');
    }

    /* 7. activeByCode — Current status only
     *    Con1 Current (ccCodeA) + Con2 Current (ccCodeA) = 2 Current for CC Campus Visit.
     *    ccCodeB has only Con1 Former → not in activeByCode.
     *    Top entry total = 2, pct = 100. */
    @IsTest
    static void testActiveByCode() {
        Test.startTest();
        HamCCVolunteerDashboardController.DashboardData r =
            HamCCVolunteerDashboardController.getVolunteerDashboardData();
        Test.stopTest();

        System.assert(!r.activeByCode.isEmpty(), 'activeByCode must not be empty');
        System.assertEquals('CC Campus Visit', r.activeByCode[0].label,
            'activeByCode[0] = CC Campus Visit');
        System.assertEquals(3,   r.activeByCode[0].total,
            'Only Con1+Con2 are Current for CC Campus Visit → total = 2');
        System.assertEquals(100, r.activeByCode[0].pct,
            'Top activeByCode entry pct = 100');
    }

    /* 8. byMonth — always 12 slots */
    @IsTest
    static void testByMonthHas12Slots() {
        Test.startTest();
        HamCCVolunteerDashboardController.DashboardData r =
            HamCCVolunteerDashboardController.getVolunteerDashboardData();
        Test.stopTest();

        System.assertEquals(12, r.byMonth.size(), 'byMonth must always have 12 FY slots');
    }

    /* 9. byMonth — correct counts and zero-fill */
    @IsTest
    static void testByMonthCountsCorrect() {
        Test.startTest();
        HamCCVolunteerDashboardController.DashboardData r =
            HamCCVolunteerDashboardController.getVolunteerDashboardData();
        Test.stopTest();

        Date    fyStart    = getFYStart();
        Integer expectedMo = fyStart.month();
        Integer expectedYr = fyStart.year();

        Integer activeMonthTotal = 0;
        Integer zeroCount        = 0;
        for (HamCCVolunteerDashboardController.MonthCount mc : r.byMonth) {
            System.assert(mc.mo >= 1 && mc.mo <= 12, 'Month 1-12');
            System.assert(mc.yr >= 2020,              'Year plausible');
            System.assert(String.isNotBlank(mc.label),'Label not blank');
            if (mc.mo == expectedMo && mc.yr == expectedYr) activeMonthTotal = mc.total;
            if (mc.total == 0) zeroCount++;
        }

        System.assertEquals(4, activeMonthTotal,
            'FY start month must contain all 4 test involvements');
        System.assert(zeroCount >= 10,
            'At least 10 of 12 month slots must be zero in test data');
    }

    /* 10. byMonth — chronological order */
    @IsTest
    static void testByMonthChronologicalOrder() {
        Test.startTest();
        HamCCVolunteerDashboardController.DashboardData r =
            HamCCVolunteerDashboardController.getVolunteerDashboardData();
        Test.stopTest();

        for (Integer i = 1; i < r.byMonth.size(); i++) {
            HamCCVolunteerDashboardController.MonthCount prev = r.byMonth[i-1];
            HamCCVolunteerDashboardController.MonthCount curr = r.byMonth[i];
            Boolean ok = curr.yr > prev.yr || (curr.yr == prev.yr && curr.mo > prev.mo);
            System.assert(ok, 'byMonth must be strictly chronological');
        }
    }

    /* 11. byClassYear — numeric ascending, Unknown last */
    @IsTest
    static void testByClassYearOrder() {
        Test.startTest();
        HamCCVolunteerDashboardController.DashboardData r =
            HamCCVolunteerDashboardController.getVolunteerDashboardData();
        Test.stopTest();

        System.assert(!r.byClassYear.isEmpty(), 'byClassYear must not be empty');
        List<String> labels = new List<String>();
        for (HamCCVolunteerDashboardController.ClassYearCount cyc : r.byClassYear) {
            labels.add(cyc.yr);
            System.assert(cyc.total > 0, 'Each class year bucket > 0');
        }
        if (labels.contains('Unknown')) {
            System.assertEquals('Unknown', labels[labels.size()-1], 'Unknown last');
        }
        List<String> numLabels = new List<String>();
        for (String lbl : labels) { if (lbl != 'Unknown') numLabels.add(lbl); }
        for (Integer i = 1; i < numLabels.size(); i++) {
            System.assert(Integer.valueOf(numLabels[i]) > Integer.valueOf(numLabels[i-1]),
                'Numeric class years ascending');
        }
    }

    /* 12. byClassYear — correct values, Con4 excluded */
    @IsTest
    static void testByClassYearValues() {
        Test.startTest();
        HamCCVolunteerDashboardController.DashboardData r =
            HamCCVolunteerDashboardController.getVolunteerDashboardData();
        Test.stopTest();

        Map<String, Integer> yrMap = new Map<String, Integer>();
        for (HamCCVolunteerDashboardController.ClassYearCount cyc : r.byClassYear) {
            yrMap.put(cyc.yr, cyc.total);
        }

        System.assert(yrMap.containsKey('1990'), '1990 (Con1) must appear');
        System.assertEquals(2, yrMap.get('1990'), 'Con1 has 2 FY involvements');
        System.assert(yrMap.containsKey('2015'), '2015 (Con2) must appear');
        System.assertEquals(1, yrMap.get('2015'));
        System.assert(yrMap.containsKey('2022'), '2022 (Con3) must appear');
        System.assertEquals(1, yrMap.get('2022'));
        System.assert(!yrMap.containsKey('2000'), 'Con4 (2000) out-of-FY, must not appear');
    }

    /* 13. topVolunteers — sort, cap, rank, valid fields */
    @IsTest
    static void testTopVolunteers() {
        Test.startTest();
        HamCCVolunteerDashboardController.DashboardData r =
            HamCCVolunteerDashboardController.getVolunteerDashboardData();
        Test.stopTest();

        System.assert(!r.topVolunteers.isEmpty(), 'topVolunteers must not be empty');
        System.assert(r.topVolunteers.size() <= 10, 'capped at 10');

        HamCCVolunteerDashboardController.TopVolunteer top = r.topVolunteers[0];
        System.assertEquals(2, top.involvements, 'Con1 top with 2 involvements');
        System.assertEquals(1, top.rank,         'Top volunteer rank = 1');

        for (HamCCVolunteerDashboardController.TopVolunteer tv : r.topVolunteers) {
            System.assert(String.isNotBlank(tv.contactName), 'contactName must not be blank');
            System.assert(String.isNotBlank(tv.contactId),   'contactId must not be blank');
            System.assert(tv.involvements > 0,               'involvements > 0');
            System.assert(tv.rank >= 1,                      'rank >= 1');
            System.assert(tv.status == 'Current' || tv.status == 'Former',
                'status must be Current or Former');
        }

        for (Integer i = 1; i < r.topVolunteers.size(); i++) {
            System.assert(
                r.topVolunteers[i-1].involvements >= r.topVolunteers[i].involvements,
                'topVolunteers sorted descending');
        }
    }

    /* 14. topVolunteers — all rows have non-blank name */
    @IsTest
    static void testTopVolunteersNeverContainsBlankName() {
        Test.startTest();
        HamCCVolunteerDashboardController.DashboardData r =
            HamCCVolunteerDashboardController.getVolunteerDashboardData();
        Test.stopTest();

        for (HamCCVolunteerDashboardController.TopVolunteer tv : r.topVolunteers) {
            System.assert(String.isNotBlank(tv.contactName),
                'Every topVolunteer row must have a non-blank contactName — id: ' + tv.contactId);
        }
    }

    /* 15. topVolunteers — row count equals named contacts only */
    @IsTest
    static void testTopVolunteersCountMatchesNamedContacts() {
        Test.startTest();
        HamCCVolunteerDashboardController.DashboardData r =
            HamCCVolunteerDashboardController.getVolunteerDashboardData();
        Test.stopTest();

        System.assertEquals(3, r.topVolunteers.size(),
            'Row count must equal the number of named contacts with FY involvements');
    }

    /* 16. topVolunteers — rank sequence is contiguous */
    @IsTest
    static void testRankSequenceIsContiguous() {
        Test.startTest();
        HamCCVolunteerDashboardController.DashboardData r =
            HamCCVolunteerDashboardController.getVolunteerDashboardData();
        Test.stopTest();

        System.assertEquals(1, r.topVolunteers[0].rank, 'First entry rank must be 1');

        for (HamCCVolunteerDashboardController.TopVolunteer tv : r.topVolunteers) {
            System.assert(tv.rank >= 1, 'All ranks must be >= 1');
        }

        for (Integer i = 1; i < r.topVolunteers.size(); i++) {
            System.assert(
                r.topVolunteers[i].rank >= r.topVolunteers[i-1].rank,
                'Ranks must be non-decreasing');
        }
    }

    /* 17. topVolunteers — tied volunteers share the same rank */
    @IsTest
    static void testTiedRank() {
        Test.startTest();
        HamCCVolunteerDashboardController.DashboardData r =
            HamCCVolunteerDashboardController.getVolunteerDashboardData();
        Test.stopTest();

        List<Integer> ranksForOne = new List<Integer>();
        for (HamCCVolunteerDashboardController.TopVolunteer tv : r.topVolunteers) {
            if (tv.involvements == 1) ranksForOne.add(tv.rank);
        }

        System.assert(ranksForOne.size() >= 2, 'Con2 and Con3 both have 1 involvement');
        Integer sharedRank = ranksForOne[0];
        for (Integer rv : ranksForOne) {
            System.assertEquals(sharedRank, rv, 'Tied volunteers must share the same rank');
        }
    }

    /* 18. topVolunteers — Current status wins for same volunteer */
    @IsTest
    static void testCurrentStatusPriority() {
        Test.startTest();
        HamCCVolunteerDashboardController.DashboardData r =
            HamCCVolunteerDashboardController.getVolunteerDashboardData();
        Test.stopTest();

        HamCCVolunteerDashboardController.TopVolunteer con1 = null;
        for (HamCCVolunteerDashboardController.TopVolunteer tv : r.topVolunteers) {
            if (tv.involvements == 2) { con1 = tv; break; }
        }
        System.assertNotEquals(null, con1, 'Con1 (multi-role) must appear');
        System.assertEquals('Current', con1.status,
            'Con1 must be Current despite also having a Former involvement');
    }

    /* 19. No CC values → both methods return all zeros / empty lists */
    @IsTest
    static void testNoCCValuesReturnsEmpty() {
        delete [SELECT Id FROM ucinn_ascendv2__Involvement_Value__c
                WHERE ucinn_ascendv2__Type__c = 'Volunteer Engagement'
                AND   HAM_Category__c = 'Career Center'];

        Test.startTest();
        HamCCVolunteerDashboardController.DashboardData vr =
            HamCCVolunteerDashboardController.getVolunteerDashboardData();
        HamCCVolunteerDashboardController.EmployerDashboardData er =
            HamCCVolunteerDashboardController.getEmployerDashboardData();
        Test.stopTest();

        // Volunteer
        System.assertEquals(0, vr.totalInvolvements);
        System.assertEquals(0, vr.uniqueVolunteers);
        System.assertEquals(0, vr.currentCount);
        System.assertEquals(0, vr.formerCount);
        System.assertEquals(0, vr.multiRoleCount);
        System.assertEquals(0, vr.avgPerVolunteer);
        System.assert(vr.byCode.isEmpty());
        System.assert(vr.byMonth.isEmpty());
        System.assert(vr.byClassYear.isEmpty());
        System.assert(vr.activeByCode.isEmpty());
        System.assert(vr.topVolunteers.isEmpty());

        // Employer
        System.assertEquals(0, er.totalInvolvements);
        System.assertEquals(0, er.uniqueEmployers);
        System.assertEquals(0, er.currentCount);
        System.assertEquals(0, er.multiEngagementCount);
        System.assert(er.byCode.isEmpty());
        System.assert(er.byMonth.isEmpty());
        System.assert(er.topVolunteers.isEmpty());
    }

    /* 20. No FY involvements → both methods return empty */
    @IsTest
    static void testNoFYInvolvementsReturnsEmpty() {
        Date fyStart = getFYStart();
        delete [SELECT Id FROM ucinn_ascendv2__Involvement__c
                WHERE ucinn_ascendv2__Start_Date__c >= :fyStart];

        Test.startTest();
        HamCCVolunteerDashboardController.DashboardData vr =
            HamCCVolunteerDashboardController.getVolunteerDashboardData();
        HamCCVolunteerDashboardController.EmployerDashboardData er =
            HamCCVolunteerDashboardController.getEmployerDashboardData();
        Test.stopTest();

        // Volunteer
        System.assertEquals(0, vr.totalInvolvements);
        System.assert(vr.byCode.isEmpty());
        System.assert(vr.byMonth.isEmpty());
        System.assert(vr.byClassYear.isEmpty());
        System.assert(vr.topVolunteers.isEmpty());

        // Employer
        System.assertEquals(0, er.totalInvolvements);
        System.assert(er.byCode.isEmpty());
        System.assert(er.byMonth.isEmpty());
        System.assert(er.topVolunteers.isEmpty());
    }

    /* 21. Null class year → Unknown bucket, Unknown is last */
    @IsTest
    static void testNullClassYearBucketedAsUnknown() {
        Account acc    = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        Contact noYear = new Contact(LastName = 'NoYear', AccountId = acc.Id);
        insert noYear;

        ucinn_ascendv2__Involvement_Value__c ccCode =
            [SELECT Id FROM ucinn_ascendv2__Involvement_Value__c
             WHERE HAM_Category__c = 'Career Center' LIMIT 1];

        insert makeInvolvement(noYear.Id, ccCode.Id, 'Former', getFYStart().addDays(5));

        Test.startTest();
        HamCCVolunteerDashboardController.DashboardData r =
            HamCCVolunteerDashboardController.getVolunteerDashboardData();
        Test.stopTest();

        Boolean foundUnknown = false;
        for (HamCCVolunteerDashboardController.ClassYearCount cyc : r.byClassYear) {
            if (cyc.yr == 'Unknown') {
                foundUnknown = true;
                System.assert(cyc.total >= 1, 'Unknown bucket must have >= 1');
            }
        }
        System.assert(foundUnknown, 'Unknown bucket must exist');
        System.assertEquals('Unknown', r.byClassYear[r.byClassYear.size()-1].yr,
            'Unknown must be the last entry');
    }

    /* 22. currentCount + formerCount = totalInvolvements */
    @IsTest
    static void testStatusCountsSumToTotal() {
        Test.startTest();
        HamCCVolunteerDashboardController.DashboardData r =
            HamCCVolunteerDashboardController.getVolunteerDashboardData();
        Test.stopTest();

        System.assertEquals(r.totalInvolvements, r.currentCount + r.formerCount,
            'currentCount + formerCount must equal totalInvolvements');
    }

    /* 23. No null lists in volunteer return */
    @IsTest
    static void testNoNullLists() {
        Test.startTest();
        HamCCVolunteerDashboardController.DashboardData r =
            HamCCVolunteerDashboardController.getVolunteerDashboardData();
        Test.stopTest();

        System.assertNotEquals(null, r);
        System.assertNotEquals(null, r.byCode);
        System.assertNotEquals(null, r.byMonth);
        System.assertNotEquals(null, r.byClassYear);
        System.assertNotEquals(null, r.activeByCode);
        System.assertNotEquals(null, r.topVolunteers);
        System.assertNotEquals(null, r.fyLabel);
    }

    /* 24. byCode.pct — top = 100, all within 0-100 */
    @IsTest
    static void testByCodePctValues() {
        Test.startTest();
        HamCCVolunteerDashboardController.DashboardData r =
            HamCCVolunteerDashboardController.getVolunteerDashboardData();
        Test.stopTest();

        System.assert(!r.byCode.isEmpty(), 'byCode must not be empty');
        System.assertEquals(100, r.byCode[0].pct, 'Top byCode entry pct = 100');
        for (HamCCVolunteerDashboardController.CodeCount cc : r.byCode) {
            System.assert(cc.pct >= 0 && cc.pct <= 100, 'pct must be 0-100');
        }
    }

    /* =========================================================
     * ── EMPLOYER TESTS (25–32) ───────────────────────────────
     * ========================================================= */

    /* 25. Employer KPI totals */
    @IsTest
    static void testEmployerKPITotalsCorrect() {
        Test.startTest();
        HamCCVolunteerDashboardController.EmployerDashboardData r =
            HamCCVolunteerDashboardController.getEmployerDashboardData();
        Test.stopTest();

        System.assertEquals(3, r.totalInvolvements,    '3 FY employer involvements expected');
        System.assertEquals(1, r.uniqueEmployers,      'Only Accenture (empAcc) expected');
        System.assertEquals(3, r.currentCount,         '2 Current involvements for empAcc');
        System.assertEquals(1, r.multiEngagementCount, 'empAcc has 3 involvements >= 2');
    }

    /* 26. Non-Career-Center accounts excluded */
    @IsTest
    static void testNonCCAccountExcluded() {
        Test.startTest();
        HamCCVolunteerDashboardController.EmployerDashboardData r =
            HamCCVolunteerDashboardController.getEmployerDashboardData();
        Test.stopTest();

        System.assertEquals(3, r.totalInvolvements,
            'nonCCAcc involvement must be excluded — only empAcc (3) counted');
        System.assertEquals(1, r.uniqueEmployers,
            'Only empAcc must appear — nonCCAcc is excluded');
    }

    /* 27. Employer fyLabel populated */
    @IsTest
    static void testEmployerFYLabelPopulated() {
        Test.startTest();
        HamCCVolunteerDashboardController.EmployerDashboardData r =
            HamCCVolunteerDashboardController.getEmployerDashboardData();
        Test.stopTest();

        System.assert(String.isNotBlank(r.fyLabel), 'fyLabel must not be blank');
        System.assert(r.fyLabel.startsWith('FY '),  'fyLabel must start with "FY "');
        System.assert(r.fyLabel.contains('Jul'),    'fyLabel must contain "Jul"');
    }

    /* 28. Employer byCode — labels, sort, pct */
    @IsTest
    static void testEmployerByCodePopulated() {
        Test.startTest();
        HamCCVolunteerDashboardController.EmployerDashboardData r =
            HamCCVolunteerDashboardController.getEmployerDashboardData();
        Test.stopTest();

        System.assert(!r.byCode.isEmpty(),   'employer byCode must not be empty');
        System.assert(r.byCode.size() <= 10, 'employer byCode capped at 10');

        // CC Campus Visit has 2 involvements, CC Career Coaching has 1
        System.assertEquals('CC Campus Visit',    r.byCode[0].label, 'byCode[0] = CC Campus Visit');
        System.assertEquals(2,                    r.byCode[0].total, 'CC Campus Visit total = 2');
        System.assertEquals(100,                  r.byCode[0].pct,   'Top entry pct = 100');
        System.assertEquals('CC Career Coaching', r.byCode[1].label, 'byCode[1] = CC Career Coaching');
        System.assertEquals(1,                    r.byCode[1].total);

        for (Integer i = 1; i < r.byCode.size(); i++) {
            System.assert(r.byCode[i-1].total >= r.byCode[i].total,
                'employer byCode must be sorted desc');
        }
    }

    /* 29. Employer byMonth — always 12 slots, chronological */
    @IsTest
    static void testEmployerByMonth() {
        Test.startTest();
        HamCCVolunteerDashboardController.EmployerDashboardData r =
            HamCCVolunteerDashboardController.getEmployerDashboardData();
        Test.stopTest();

        System.assertEquals(12, r.byMonth.size(), 'employer byMonth must have 12 FY slots');

        for (Integer i = 1; i < r.byMonth.size(); i++) {
            HamCCVolunteerDashboardController.MonthCount prev = r.byMonth[i-1];
            HamCCVolunteerDashboardController.MonthCount curr = r.byMonth[i];
            Boolean ok = curr.yr > prev.yr || (curr.yr == prev.yr && curr.mo > prev.mo);
            System.assert(ok, 'employer byMonth must be strictly chronological');
        }

        // FY start month must contain all 3 employer involvements
        Date    fyStart = getFYStart();
        Integer expMo   = fyStart.month();
        Integer expYr   = fyStart.year();
        Integer found   = 0;
        for (HamCCVolunteerDashboardController.MonthCount mc : r.byMonth) {
            if (mc.mo == expMo && mc.yr == expYr) { found = mc.total; break; }
        }
        System.assertEquals(3, found, 'FY start month must contain all 3 employer involvements');
    }

    /* 30. Employer topVolunteers — sort, rank, valid fields, name = account name */
    @IsTest
    static void testEmployerTopVolunteers() {
        Test.startTest();
        HamCCVolunteerDashboardController.EmployerDashboardData r =
            HamCCVolunteerDashboardController.getEmployerDashboardData();
        Test.stopTest();

        System.assert(!r.topVolunteers.isEmpty(), 'employer topVolunteers must not be empty');
        System.assert(r.topVolunteers.size() <= 10, 'capped at 10');

        HamCCVolunteerDashboardController.TopVolunteer top = r.topVolunteers[0];
        System.assertEquals(3,          top.involvements, 'empAcc has 3 involvements');
        System.assertEquals(1,          top.rank,         'Top employer rank = 1');
        System.assertEquals('Accenture', top.contactName, 'contactName must be account name');
        System.assert(String.isNotBlank(top.contactId),   'contactId must not be blank');
        System.assert(top.status == 'Current' || top.status == 'Former',
            'status must be Current or Former');
        // Current wins: empAcc has Current involvements
        System.assertEquals('Current', top.status,
            'empAcc status must be Current as it has Current involvements');

        for (Integer i = 1; i < r.topVolunteers.size(); i++) {
            System.assert(
                r.topVolunteers[i-1].involvements >= r.topVolunteers[i].involvements,
                'employer topVolunteers sorted descending');
        }
    }

    /* 31. Employer — no null lists */
    @IsTest
    static void testEmployerNoNullLists() {
        Test.startTest();
        HamCCVolunteerDashboardController.EmployerDashboardData r =
            HamCCVolunteerDashboardController.getEmployerDashboardData();
        Test.stopTest();

        System.assertNotEquals(null, r);
        System.assertNotEquals(null, r.byCode);
        System.assertNotEquals(null, r.byMonth);
        System.assertNotEquals(null, r.topVolunteers);
        System.assertNotEquals(null, r.fyLabel);
    }

    /* 32. Employer avgPerEmployer */
    @IsTest
    static void testEmployerAvgPerEmployer() {
        Test.startTest();
        HamCCVolunteerDashboardController.EmployerDashboardData r =
            HamCCVolunteerDashboardController.getEmployerDashboardData();
        Test.stopTest();

        // 3 involvements / 1 employer = 3.00
        Decimal expected = Decimal.valueOf(3).setScale(2);
        System.assertEquals(expected, r.avgPerEmployer,
            'avgPerEmployer = 3 involvements / 1 employer = 3.00');
    }
}