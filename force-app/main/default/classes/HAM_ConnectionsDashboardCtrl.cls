/**
 * HAM_ConnectionsDashboardCtrl
 * ------------------------------------------------------------------
 * Supplies aggregate metrics for the "Connections" tab of the
 * Hamilton Quad Ops Dashboard (HAM_Connection__c).
 *
 * SHARING MODEL — READ THIS BEFORE CHANGING "without sharing":
 * This class is intentionally declared `without sharing`. Every method
 * returns COUNT()/GROUP BY aggregates only — never a queryable list of
 * HAM_Connection__c records or any field that identifies a constituent.
 * That means viewers of this dashboard see the *analysis* (how many
 * connections, bookmarks, etc.) regardless of whether their own
 * profile/permission set would let them open the underlying
 * HAM_Connection__c records. Apex also runs in system mode for
 * object/field-level security unless a class is explicitly checked
 * with WITH SECURITY_ENFORCED or Security.stripInaccessible — we are
 * relying on that default here as well, on purpose, since nothing
 * returned is record-identifying.
 * Access to this class itself is still gated by the
 * HAM_Quad_Ops_Dashboard permission set — do not make this class
 * `global` or expose it outside that permission set's Apex Class
 * Access list.
 */
public without sharing class HAM_ConnectionsDashboardCtrl {

    private static final String SRC_PORTAL_USER = 'Portal User';
    private static final String STATUS_CONNECTED = 'Connected';

    /* ---------------------------------------------------------- */
    /*  Wrapper types                                              */
    /* ---------------------------------------------------------- */

    public class Kpis {
        @AuraEnabled public Integer newConnections;
        @AuraEnabled public Integer newBookmarks;
        @AuraEnabled public Integer newFavorites;
        @AuraEnabled public Integer newBlocked;
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
        @AuraEnabled public String label;   // e.g. "6/17"
        @AuraEnabled public Date day;
        @AuraEnabled public Integer count;
    }

    public class AllTimeTotals {
        @AuraEnabled public Integer total;
        @AuraEnabled public Integer bookmarked;
        @AuraEnabled public Integer favorited;
        @AuraEnabled public Integer blocked;
        @AuraEnabled public Integer plain;
    }

    /* ---------------------------------------------------------- */
    /*  KPI tiles — last 30 days, Portal User source only          */
    /* ---------------------------------------------------------- */

    @AuraEnabled(cacheable=true)
    public static Kpis getKpis() {
        Kpis k = new Kpis();

        k.newConnections = [
            SELECT COUNT()
            FROM HAM_Connection__c
            WHERE HAM_Data_Source__c = :SRC_PORTAL_USER
              AND HAM_Connection_Status__c = :STATUS_CONNECTED
              AND CreatedDate = LAST_N_DAYS:30
        ];

        k.newBookmarks = [
            SELECT COUNT()
            FROM HAM_Connection__c
            WHERE HAM_Data_Source__c = :SRC_PORTAL_USER
              AND HAM_Is_bookmarked__c = true
              AND CreatedDate = LAST_N_DAYS:30
        ];

        k.newFavorites = [
            SELECT COUNT()
            FROM HAM_Connection__c
            WHERE HAM_Data_Source__c = :SRC_PORTAL_USER
              AND HAM_Is_favorite__c = true
              AND CreatedDate = LAST_N_DAYS:30
        ];

        k.newBlocked = [
            SELECT COUNT()
            FROM HAM_Connection__c
            WHERE HAM_Data_Source__c = :SRC_PORTAL_USER
              AND HAM_Is_Blocked__c = true
              AND CreatedDate = LAST_N_DAYS:30
        ];

        return k;
    }

    /* ---------------------------------------------------------- */
    /*  Status breakdown — last 30 days, Portal User source        */
    /* ---------------------------------------------------------- */

    @AuraEnabled(cacheable=true)
    public static List<NameValue> getStatusBreakdown() {
        List<NameValue> results = new List<NameValue>();

        for (AggregateResult ar : [
            SELECT HAM_Connection_Status__c st, COUNT(Id) cnt
            FROM HAM_Connection__c
            WHERE HAM_Data_Source__c = :SRC_PORTAL_USER
              AND HAM_Connection_Status__c != null
              AND CreatedDate = LAST_N_DAYS:30
            GROUP BY HAM_Connection_Status__c
            ORDER BY COUNT(Id) DESC
        ]) {
            results.add(new NameValue((String) ar.get('st'), (Integer) ar.get('cnt')));
        }

        // Bookmarks with no Connection Status set yet are their own bucket,
        // matching how the alumni actually experience the feature (a bookmark
        // doesn't require a connection request).
        Integer bookmarkedNoStatus = [
            SELECT COUNT()
            FROM HAM_Connection__c
            WHERE HAM_Data_Source__c = :SRC_PORTAL_USER
              AND HAM_Is_bookmarked__c = true
              AND HAM_Connection_Status__c = null
              AND CreatedDate = LAST_N_DAYS:30
        ];
        if (bookmarkedNoStatus > 0) {
            results.add(new NameValue('Bookmarked (no status)', bookmarkedNoStatus));
        }

        return results;
    }

    /* ---------------------------------------------------------- */
    /*  Daily trend — last N days (default 14), Portal User source */
    /* ---------------------------------------------------------- */

    @AuraEnabled(cacheable=true)
    public static List<DailyPoint> getDailyTrend(Integer numDays) {
        Integer days = (numDays == null || numDays <= 0) ? 14 : numDays;

        Map<Date, Integer> countsByDay = new Map<Date, Integer>();
        for (AggregateResult ar : [
            SELECT DAY_ONLY(CreatedDate) d, COUNT(Id) cnt
            FROM HAM_Connection__c
            WHERE HAM_Data_Source__c = :SRC_PORTAL_USER
              AND CreatedDate = LAST_N_DAYS:30
            GROUP BY DAY_ONLY(CreatedDate)
        ]) {
            countsByDay.put((Date) ar.get('d'), (Integer) ar.get('cnt'));
        }

        List<DailyPoint> points = new List<DailyPoint>();
        Date today = Date.today();
        for (Integer i = days - 1; i >= 0; i--) {
            Date d = today.addDays(-i);
            DailyPoint p = new DailyPoint();
            p.day = d;
            p.label = String.valueOf(d.month()) + '/' + String.valueOf(d.day());
            p.count = countsByDay.containsKey(d) ? countsByDay.get(d) : 0;
            points.add(p);
        }
        return points;
    }

    /* ---------------------------------------------------------- */
    /*  All-time totals — Portal User source, no date filter       */
    /* ---------------------------------------------------------- */

    @AuraEnabled(cacheable=true)
    public static AllTimeTotals getAllTimeTotals() {
        AllTimeTotals t = new AllTimeTotals();

        t.total = [SELECT COUNT() FROM HAM_Connection__c WHERE HAM_Data_Source__c = :SRC_PORTAL_USER];
        t.bookmarked = [SELECT COUNT() FROM HAM_Connection__c WHERE HAM_Data_Source__c = :SRC_PORTAL_USER AND HAM_Is_bookmarked__c = true];
        t.favorited = [SELECT COUNT() FROM HAM_Connection__c WHERE HAM_Data_Source__c = :SRC_PORTAL_USER AND HAM_Is_favorite__c = true];
        t.blocked = [SELECT COUNT() FROM HAM_Connection__c WHERE HAM_Data_Source__c = :SRC_PORTAL_USER AND HAM_Is_Blocked__c = true];
        t.plain = [
            SELECT COUNT()
            FROM HAM_Connection__c
            WHERE HAM_Data_Source__c = :SRC_PORTAL_USER
              AND HAM_Is_bookmarked__c = false
              AND HAM_Is_favorite__c = false
              AND HAM_Is_Blocked__c = false
        ];

        return t;
    }
}