/**
 * HAM_ServiceIndicatorDashboardCtrl
 * ------------------------------------------------------------------
 * Supplies metrics for the "Service Indicators" tab
 * (ucinn_ascendv2__Service_Indicator__c), filtered to activity
 * performed by Experience Cloud partner users (User.UserType =
 * 'PowerPartner') on either CreatedBy or LastModifiedBy — i.e. alumni
 * managing their own privacy/visibility preferences on Hamilton Quad,
 * with internal staff and batch loads excluded.
 *
 * PRIVACY NOTE — "latest 10" feed: getLatestActivity() deliberately
 * does NOT select the Contact/constituent on the Service Indicator
 * record. This tab already tells you *who is capable of changing
 * these settings* (partner users only), but naming the specific
 * alumnus who flipped, say, "Do Not Display Phone" would turn an
 * aggregate usage feed into a personal-preference disclosure — the
 * exact thing this dashboard is supposed to avoid surfacing. Keep it
 * to indicator type + action + timestamp only.
 *
 * SHARING MODEL: `without sharing`, same rationale as the other
 * controllers in this dashboard — see HAM_ConnectionsDashboardCtrl.
 */
public without sharing class HAM_ServiceIndicatorDashboardCtrl {

    private static final String PARTNER_USER_TYPE = 'PowerPartner';

    // Injected by tests when no PowerPartner profile exists in the sandbox.
    // Always null in production — the production SOQL path is unchanged.
    @TestVisible
    private static List<ucinn_ascendv2__Service_Indicator__c> testLatestActivityRecords = null;

    /* ---------------------------------------------------------- */
    /*  Wrapper types                                              */
    /* ---------------------------------------------------------- */

    public class Totals {
        @AuraEnabled public Integer created30;
        @AuraEnabled public Integer modified30;
    }

    public class IndicatorActivity {
        @AuraEnabled public String name;
        @AuraEnabled public Integer created;
        @AuraEnabled public Integer modified;
        @AuraEnabled public Integer total;
    }

    public class WeeklyTopIndicators {
        @AuraEnabled public String weekLabel;
        @AuraEnabled public Boolean isPartialWeek;
        @AuraEnabled public List<IndicatorActivity> topIndicators;
    }

    public class LatestActivityRow {
        @AuraEnabled public String indicatorName;
        @AuraEnabled public String action;      // 'Created' or 'Modified'
        @AuraEnabled public Datetime activityTime;
        @AuraEnabled public String activityDate; // formatted
        @AuraEnabled public String activityTimeOfDay; // formatted
    }

    /* ---------------------------------------------------------- */
    /*  Totals — last 30 days, partner users only                  */
    /* ---------------------------------------------------------- */

    @AuraEnabled(cacheable=true)
    public static Totals getPartnerTotals() {
        Totals t = new Totals();
        t.created30 = [
            SELECT COUNT()
            FROM ucinn_ascendv2__Service_Indicator__c
            WHERE CreatedDate = LAST_N_DAYS:30 AND CreatedBy.UserType = :PARTNER_USER_TYPE
        ];
        t.modified30 = [
            SELECT COUNT()
            FROM ucinn_ascendv2__Service_Indicator__c
            WHERE LastModifiedDate = LAST_N_DAYS:30 AND LastModifiedBy.UserType = :PARTNER_USER_TYPE
        ];
        return t;
    }

    /* ---------------------------------------------------------- */
    /*  Activity by indicator type — last 30 days, partner users   */
    /*  (used for the overall bar chart, unbucketed by week)        */
    /* ---------------------------------------------------------- */

    @AuraEnabled(cacheable=true)
    public static List<IndicatorActivity> getActivityByIndicatorType30() {
        return buildIndicatorActivity(Datetime.now().addDays(-30), Datetime.now(), null);
    }

    /* ---------------------------------------------------------- */
    /*  Top 10 indicator types PER WEEK, over the last N weeks      */
    /*  (default 4 rolling 7-day weeks, ~last 30 days)              */
    /* ---------------------------------------------------------- */

    @AuraEnabled(cacheable=true)
    public static List<WeeklyTopIndicators> getTopIndicatorsByWeek(Integer numWeeks) {
        Integer weeks = (numWeeks == null || numWeeks <= 0) ? 4 : numWeeks;
        List<WeeklyTopIndicators> result = new List<WeeklyTopIndicators>();
        Datetime now = Datetime.now();

        for (Integer i = weeks - 1; i >= 0; i--) {
            Datetime windowEnd = now.addDays(-7 * i);
            Datetime windowStart = windowEnd.addDays(-7);

            List<IndicatorActivity> weekActivity = buildIndicatorActivity(windowStart, windowEnd, 10);

            WeeklyTopIndicators wp = new WeeklyTopIndicators();
            Date startDate = windowStart.dateGmt();
            wp.weekLabel = 'Wk of ' + String.valueOf(startDate.month()) + '/' + String.valueOf(startDate.day());
            wp.isPartialWeek = (i == 0);
            wp.topIndicators = weekActivity;
            result.add(wp);
        }
        return result;
    }

    /**
     * Shared helper: builds created/modified counts per Service Indicator
     * Value, for partner users, within [windowStart, windowEnd), optionally
     * truncated to the top N by total activity.
     */
    private static List<IndicatorActivity> buildIndicatorActivity(Datetime windowStart, Datetime windowEnd, Integer topN) {
        Map<Id, Integer> createdById = new Map<Id, Integer>();
        Map<Id, Integer> modifiedById = new Map<Id, Integer>();

        for (AggregateResult ar : [
            SELECT ucinn_ascendv2__Service_Indicator_Value__c sivId, COUNT(Id) cnt
            FROM ucinn_ascendv2__Service_Indicator__c
            WHERE CreatedDate >= :windowStart AND CreatedDate < :windowEnd
              AND CreatedBy.UserType = :PARTNER_USER_TYPE
              AND ucinn_ascendv2__Service_Indicator_Value__c != null
            GROUP BY ucinn_ascendv2__Service_Indicator_Value__c
        ]) {
            createdById.put((Id) ar.get('sivId'), (Integer) ar.get('cnt'));
        }

        for (AggregateResult ar : [
            SELECT ucinn_ascendv2__Service_Indicator_Value__c sivId, COUNT(Id) cnt
            FROM ucinn_ascendv2__Service_Indicator__c
            WHERE LastModifiedDate >= :windowStart AND LastModifiedDate < :windowEnd
              AND LastModifiedBy.UserType = :PARTNER_USER_TYPE
              AND ucinn_ascendv2__Service_Indicator_Value__c != null
            GROUP BY ucinn_ascendv2__Service_Indicator_Value__c
        ]) {
            modifiedById.put((Id) ar.get('sivId'), (Integer) ar.get('cnt'));
        }

        Set<Id> allIds = new Set<Id>();
        allIds.addAll(createdById.keySet());
        allIds.addAll(modifiedById.keySet());

        Map<Id, String> namesById = new Map<Id, String>();
        if (!allIds.isEmpty()) {
            for (ucinn_ascendv2__Service_Indicator_Value__c siv : [
                SELECT Id, Name
                FROM ucinn_ascendv2__Service_Indicator_Value__c
                WHERE Id IN :allIds
            ]) {
                namesById.put(siv.Id, siv.Name);
            }
        }

        List<IndicatorActivity> activity = new List<IndicatorActivity>();
        for (Id sivId : allIds) {
            IndicatorActivity ia = new IndicatorActivity();
            ia.name = namesById.containsKey(sivId) ? namesById.get(sivId) : '(unknown)';
            ia.created = createdById.containsKey(sivId) ? createdById.get(sivId) : 0;
            ia.modified = modifiedById.containsKey(sivId) ? modifiedById.get(sivId) : 0;
            ia.total = ia.created + ia.modified;
            activity.add(ia);
        }

        activity.sort(new IndicatorActivityComparator());

        if (topN != null && activity.size() > topN) {
            List<IndicatorActivity> trimmed = new List<IndicatorActivity>();
            for (Integer i = 0; i < topN; i++) {
                trimmed.add(activity[i]);
            }
            return trimmed;
        }
        return activity;
    }

    @TestVisible
    private class IndicatorActivityComparator implements Comparator<IndicatorActivity> {
        public Integer compare(IndicatorActivity a, IndicatorActivity b) {
            return b.total - a.total;
        }
    }

    /* ---------------------------------------------------------- */
    /*  Latest 10 — most recent partner-user touches, anonymized    */
    /* ---------------------------------------------------------- */

    @AuraEnabled(cacheable=true)
    public static List<LatestActivityRow> getLatestActivity(Integer limitCount) {
        Integer lim = (limitCount == null || limitCount <= 0) ? 10 : limitCount;

        Boolean usingStub = Test.isRunningTest() && testLatestActivityRecords != null;
        List<ucinn_ascendv2__Service_Indicator__c> siRecords = usingStub
            ? testLatestActivityRecords
            : [
                SELECT ucinn_ascendv2__Service_Indicator_Value__r.Name,
                       CreatedDate, LastModifiedDate,
                       CreatedBy.UserType, LastModifiedBy.UserType
                FROM ucinn_ascendv2__Service_Indicator__c
                WHERE CreatedBy.UserType = :PARTNER_USER_TYPE
                   OR LastModifiedBy.UserType = :PARTNER_USER_TYPE
                ORDER BY LastModifiedDate DESC
                LIMIT :lim
            ];

        List<LatestActivityRow> rows = new List<LatestActivityRow>();
        for (ucinn_ascendv2__Service_Indicator__c siv : siRecords) {
            // When using the test stub, treat every record as partner-touched
            // so the row-building logic is exercised regardless of UserType.
            Boolean modifiedByPartner = usingStub || siv.LastModifiedBy.UserType == PARTNER_USER_TYPE;
            Boolean createdByPartner  = usingStub || siv.CreatedBy.UserType == PARTNER_USER_TYPE;
            Boolean isCreateEvent = siv.CreatedDate == siv.LastModifiedDate;

            // Only surface an action this partner user is actually
            // responsible for; skip rows where the *only* partner touch
            // isn't reflected in LastModifiedDate (rare, but be defensive).
            if (!modifiedByPartner && !createdByPartner) {
                continue;
            }

            LatestActivityRow row = new LatestActivityRow();
            row.indicatorName = siv.ucinn_ascendv2__Service_Indicator_Value__r != null
                ? siv.ucinn_ascendv2__Service_Indicator_Value__r.Name
                : '(unknown)';
            row.action = (isCreateEvent && createdByPartner) ? 'Created' : 'Modified';
            row.activityTime = siv.LastModifiedDate;
            row.activityDate = siv.LastModifiedDate.format('yyyy-MM-dd');
            row.activityTimeOfDay = siv.LastModifiedDate.format('hh:mm a');
            rows.add(row);
        }
        return rows;
    }
}