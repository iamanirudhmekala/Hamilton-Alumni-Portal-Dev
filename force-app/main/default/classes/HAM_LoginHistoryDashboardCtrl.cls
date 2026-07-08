/**
 * HAM_LoginHistoryDashboardCtrl
 * ------------------------------------------------------------------
 * Supplies metrics for the "Login History" tab of the Hamilton Quad
 * Ops Dashboard. LoginHistory is a system audit object with no
 * sharing model of its own and can carry a very large row count
 * (100k+ rows/month org-wide), so every method here is designed to
 * stay inside governor limits:
 *   - KPI tiles and charts use COUNT()/COUNT_DISTINCT()/GROUP BY
 *     aggregates, which are cheap regardless of how many raw rows
 *     they summarize.
 *   - The one place we need row-level detail (the error table) is
 *     bounded to a short lookback window (default 14 days) and a
 *     hard LIMIT, then paginated in Apex memory.
 *
 * SHARING MODEL: declared `without sharing` on purpose — LoginHistory
 * has no owner/sharing model to bypass, but this keeps the class
 * consistent with the rest of the dashboard's controllers and makes
 * the intent explicit. Because this tab *does* surface user names and
 * emails (that is the point — AIS/IT need to know who is stuck), keep
 * this dashboard restricted to the HAM_Quad_Ops_Dashboard permission
 * set (internal staff), not the public Experience Cloud site.
 *
 * A NOTE ON THE "Status" FIELD: some orgs report that LoginHistory
 * rejects an inequality filter (Status != 'Success') when combined
 * with other WHERE clauses. If you hit that here, replace the WHERE
 * clause in queryRawErrorRows() with an explicit IN list of the
 * non-success Status values your org actually produces (see the
 * commented ALTERNATE query below the method) — building that list
 * from getStatusBreakdown()'s output is the easiest way to keep it
 * current.
 */
public without sharing class HAM_LoginHistoryDashboardCtrl {

    private static final String STATUS_SUCCESS = 'Success';

    /* ---------------------------------------------------------- */
    /*  Wrapper types                                              */
    /* ---------------------------------------------------------- */

    public class Kpis {
        @AuraEnabled public Integer total30;
        @AuraEnabled public Integer success30;
        @AuraEnabled public Integer distinctUsersThisMonth;
        @AuraEnabled public Integer distinctUsersLastMonth;
    }

    public class NameValue {
        @AuraEnabled public String name;
        @AuraEnabled public Integer value;
        public NameValue(String name, Integer value) {
            this.name = name;
            this.value = value;
        }
    }

    public class DailyPoint {
        @AuraEnabled public String label;
        @AuraEnabled public Date day;
        @AuraEnabled public Integer distinctUsers;
    }

    public class WeeklyPoint {
        @AuraEnabled public String label;
        @AuraEnabled public Integer count;
        @AuraEnabled public Boolean isPartialWeek;
    }

    public class LoginIssueRow {
        @AuraEnabled public String userName;
        @AuraEnabled public String email;
        @AuraEnabled public String profileName;
        @AuraEnabled public Boolean isActive;
        @AuraEnabled public String status;
        @AuraEnabled public Datetime loginTime;
        @AuraEnabled public String loginDate;   // formatted, e.g. 2026-07-01
        @AuraEnabled public String loginTimeOfDay; // formatted, e.g. 09:42 AM
    }

    public class LoginIssuePage {
        @AuraEnabled public List<LoginIssueRow> records;
        @AuraEnabled public Integer totalRecords;
        @AuraEnabled public Integer totalPages;
        @AuraEnabled public Integer pageNumber;
        @AuraEnabled public Integer pageSize;
    }

    /* ---------------------------------------------------------- */
    /*  KPI tiles                                                  */
    /* ---------------------------------------------------------- */

    @AuraEnabled(cacheable=true)
    public static Kpis getKpis() {
        Kpis k = new Kpis();

        k.total30 = [SELECT COUNT() FROM LoginHistory WHERE LoginTime = LAST_N_DAYS:30];
        Integer successCount = 0;
        List<AggregateResult> statusAgg = [
            SELECT Status s, COUNT(Id) cnt
            FROM LoginHistory
            WHERE LoginTime = LAST_N_DAYS:30
            GROUP BY Status
        ];
        for (AggregateResult ar : statusAgg) {
            if (STATUS_SUCCESS.equals((String) ar.get('s'))) {
                successCount = (Integer) ar.get('cnt');
            }
        }
        k.success30 = successCount;

        AggregateResult thisMonth = [
            SELECT COUNT_DISTINCT(UserId) cnt FROM LoginHistory WHERE LoginTime = THIS_MONTH
        ];
        k.distinctUsersThisMonth = (Integer) thisMonth.get('cnt');

        AggregateResult lastMonth = [
            SELECT COUNT_DISTINCT(UserId) cnt FROM LoginHistory WHERE LoginTime = LAST_MONTH
        ];
        k.distinctUsersLastMonth = (Integer) lastMonth.get('cnt');

        return k;
    }

    /* ---------------------------------------------------------- */
    /*  Daily unique logins — last N days (default 31)             */
    /* ---------------------------------------------------------- */

    @AuraEnabled(cacheable=true)
    public static List<DailyPoint> getDailyUniqueLogins(Integer numDays) {
        Integer days = (numDays == null || numDays <= 0) ? 31 : numDays;

        Map<Date, Integer> byDay = new Map<Date, Integer>();
        for (AggregateResult ar : [
            SELECT DAY_ONLY(LoginTime) d, COUNT_DISTINCT(UserId) cnt
            FROM LoginHistory
            WHERE LoginTime = LAST_N_DAYS:31
            GROUP BY DAY_ONLY(LoginTime)
        ]) {
            byDay.put((Date) ar.get('d'), (Integer) ar.get('cnt'));
        }

        List<DailyPoint> points = new List<DailyPoint>();
        Date today = Date.today();
        for (Integer i = days - 1; i >= 0; i--) {
            Date d = today.addDays(-i);
            DailyPoint p = new DailyPoint();
            p.day = d;
            p.label = String.valueOf(d.month()) + '/' + String.valueOf(d.day());
            p.distinctUsers = byDay.containsKey(d) ? byDay.get(d) : 0;
            points.add(p);
        }
        return points;
    }

    /* ---------------------------------------------------------- */
    /*  Weekly rolling totals — default last 4 rolling 7-day weeks */
    /* ---------------------------------------------------------- */

    @AuraEnabled(cacheable=true)
    public static List<WeeklyPoint> getWeeklyLogins(Integer numWeeks) {
        Integer weeks = (numWeeks == null || numWeeks <= 0) ? 4 : numWeeks;
        List<WeeklyPoint> points = new List<WeeklyPoint>();
        Datetime now = Datetime.now();

        // weeks[0] = most recent (partial) week, working backwards
        for (Integer i = weeks - 1; i >= 0; i--) {
            Datetime windowEnd = now.addDays(-7 * i);
            Datetime windowStart = windowEnd.addDays(-7);

            Integer cnt = [
                SELECT COUNT()
                FROM LoginHistory
                WHERE LoginTime >= :windowStart AND LoginTime < :windowEnd
            ];

            WeeklyPoint wp = new WeeklyPoint();
            Date startDate = windowStart.dateGmt();
            wp.label = 'Wk of ' + String.valueOf(startDate.month()) + '/' + String.valueOf(startDate.day());
            wp.count = cnt;
            wp.isPartialWeek = (i == 0);
            points.add(wp);
        }
        return points;
    }

    /* ---------------------------------------------------------- */
    /*  Status breakdown — last 30 days                            */
    /* ---------------------------------------------------------- */

    @AuraEnabled(cacheable=true)
    public static List<NameValue> getStatusBreakdown() {
        List<NameValue> results = new List<NameValue>();
        for (AggregateResult ar : [
            SELECT Status st, COUNT(Id) cnt
            FROM LoginHistory
            WHERE LoginTime = LAST_N_DAYS:30
            GROUP BY Status
            ORDER BY COUNT(Id) DESC
        ]) {
            results.add(new NameValue((String) ar.get('st'), (Integer) ar.get('cnt')));
        }
        return results;
    }

    /* ---------------------------------------------------------- */
    /*  Error table — latest → oldest, paginated, "no success YET  */
    /*  that day" filter, date + time columns                      */
    /* ---------------------------------------------------------- */

    @AuraEnabled(cacheable=true)
    public static LoginIssuePage getLoginIssues(Integer pageNumber, Integer pageSize, Integer lookbackDays) {
        Integer page = (pageNumber == null || pageNumber < 1) ? 1 : pageNumber;
        Integer size = (pageSize == null || pageSize < 1) ? 10 : pageSize;
        Integer lookback = (lookbackDays == null || lookbackDays < 1) ? 14 : lookbackDays;

        // 1) Build the set of "UserId_yyyy-MM-dd" keys that already have at
        //    least one Success that day, so we can exclude later error rows
        //    for users who did eventually get in that day.
        Set<String> successDayKeys = new Set<String>();
        for (AggregateResult ar : buildSuccessDayAggregate(lookback)) {
            Id uid = (Id) ar.get('uid');
            Date d = (Date) ar.get('d');
            successDayKeys.add(String.valueOf(uid) + '_' + d.format());
        }

        // 2) Pull raw rows (no User relationship — LoginHistory doesn't support it).
        //    Collect UserIds then do a separate User query to join in memory.
        List<LoginHistory> rawRows = queryRawErrorRows(lookback);
        Set<Id> userIds = new Set<Id>();
        for (LoginHistory lh : rawRows) {
            if (lh.UserId != null) userIds.add(lh.UserId);
        }
        Map<Id, User> userMap = new Map<Id, User>([
            SELECT Id, Name, Email, Profile.Name, IsActive
            FROM User
            WHERE Id IN :userIds
        ]);

        List<LoginIssueRow> filtered = new List<LoginIssueRow>();
        for (LoginHistory lh : rawRows) {
            Date loginDay = lh.LoginTime.dateGmt();
            String key = String.valueOf(lh.UserId) + '_' + loginDay.format();
            if (STATUS_SUCCESS.equals(lh.Status)) {
                continue;
            }
            if (successDayKeys.contains(key)) {
                continue;
            }

            User u = userMap.get(lh.UserId);
            LoginIssueRow row = new LoginIssueRow();
            row.userName = u != null ? u.Name : '(unknown user)';
            row.email = u != null ? u.Email : '';
            row.profileName = (u != null && u.Profile != null) ? u.Profile.Name : '';
            row.isActive = u != null ? u.IsActive : null;
            row.status = lh.Status;
            row.loginTime = lh.LoginTime;
            row.loginDate = lh.LoginTime.format('yyyy-MM-dd');
            row.loginTimeOfDay = lh.LoginTime.format('hh:mm a');
            filtered.add(row);
        }

        // Already ordered latest → oldest by the query below; paginate in memory.
        Integer total = filtered.size();
        Integer totalPages = (Integer) Math.ceil((Decimal) total / size);
        if (totalPages < 1) totalPages = 1;
        if (page > totalPages) page = totalPages;

        Integer startIdx = (page - 1) * size;
        Integer endIdx = Math.min(startIdx + size, total);

        List<LoginIssueRow> pageRows = new List<LoginIssueRow>();
        if (startIdx < total) {
            for (Integer i = startIdx; i < endIdx; i++) {
                pageRows.add(filtered[i]);
            }
        }

        LoginIssuePage result = new LoginIssuePage();
        result.records = pageRows;
        result.totalRecords = total;
        result.totalPages = totalPages;
        result.pageNumber = page;
        result.pageSize = size;
        return result;
    }

    private static List<AggregateResult> buildSuccessDayAggregate(Integer lookback) {
        Datetime windowStart = Datetime.now().addDays(-lookback);
        List<AggregateResult> allDayAgg = [
            SELECT Status s, UserId uid, DAY_ONLY(LoginTime) d
            FROM LoginHistory
            WHERE LoginTime >= :windowStart
            GROUP BY Status, UserId, DAY_ONLY(LoginTime)
        ];
        List<AggregateResult> successOnly = new List<AggregateResult>();
        for (AggregateResult ar : allDayAgg) {
            if (STATUS_SUCCESS.equals((String) ar.get('s'))) {
                successOnly.add(ar);
            }
        }
        return successOnly;
    }

    private static List<LoginHistory> queryRawErrorRows(Integer lookback) {
        Datetime windowStart = Datetime.now().addDays(-lookback);
        return [
            SELECT Id, UserId, Status, LoginTime
            FROM LoginHistory
            WHERE LoginTime >= :windowStart
            ORDER BY LoginTime DESC
            LIMIT 2000
        ];

        /* ALTERNATE — use this instead if your org rejects the inequality
           filter above ("didn't understand relationship/inequality" type
           errors), swapping in the exact non-Success values from
           getStatusBreakdown():

        return [
            SELECT Id, UserId, User.Name, User.Email, User.Profile.Name, User.IsActive, Status, LoginTime
            FROM LoginHistory
            WHERE Status IN ('Passwordless login required','Multi-factor required',
                             'Invalid Password','User is inactive',
                             'Failed: InResponseTo invalid','Failed: Invalid portal ID',
                             'Failed: Not approved','Failed: Computer activation required')
              AND LoginTime >= :windowStart
            ORDER BY LoginTime DESC
            LIMIT 2000
        ];
        */
    }
}