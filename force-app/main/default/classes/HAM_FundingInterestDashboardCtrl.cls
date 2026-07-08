/**
 * HAM_FundingInterestDashboardCtrl
 * ------------------------------------------------------------------
 * Supplies aggregate metrics for the "Funding Interest" tab
 * (ucinn_ascendv2__Funding_Interest__c). Aggregate-only, same
 * `without sharing` rationale as HAM_ConnectionsDashboardCtrl —
 * see that class header for the full explanation.
 */
public without sharing class HAM_FundingInterestDashboardCtrl {

    public class Kpis {
        @AuraEnabled public Integer new30;
        @AuraEnabled public Integer new30WithDataSource;
        @AuraEnabled public Integer allTimeTotal;
    }

    public class NameValue {
        @AuraEnabled public String name;
        @AuraEnabled public Integer value;
        public NameValue(String name, Integer value) {
            this.name = name;
            this.value = value;
        }
    }

    @AuraEnabled(cacheable=true)
    public static Kpis getKpis() {
        Kpis k = new Kpis();
        k.new30 = [
            SELECT COUNT() FROM ucinn_ascendv2__Funding_Interest__c WHERE CreatedDate = LAST_N_DAYS:30
        ];
        k.new30WithDataSource = [
            SELECT COUNT() FROM ucinn_ascendv2__Funding_Interest__c
            WHERE CreatedDate = LAST_N_DAYS:30 AND ucinn_ascendv2__Data_Source__c != null
        ];
        k.allTimeTotal = [SELECT COUNT() FROM ucinn_ascendv2__Funding_Interest__c];
        return k;
    }

    @AuraEnabled(cacheable=true)
    public static List<NameValue> getNewByCategory30() {
        List<NameValue> results = new List<NameValue>();
        for (AggregateResult ar : [
            SELECT HAM_Category__c cat, COUNT(Id) cnt
            FROM ucinn_ascendv2__Funding_Interest__c
            WHERE CreatedDate = LAST_N_DAYS:30 AND HAM_Category__c != null
            GROUP BY HAM_Category__c
            ORDER BY COUNT(Id) DESC
        ]) {
            results.add(new NameValue((String) ar.get('cat'), (Integer) ar.get('cnt')));
        }
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static List<NameValue> getAllTimeByCategory() {
        List<NameValue> results = new List<NameValue>();
        for (AggregateResult ar : [
            SELECT HAM_Category__c cat, COUNT(Id) cnt
            FROM ucinn_ascendv2__Funding_Interest__c
            WHERE HAM_Category__c != null
            GROUP BY HAM_Category__c
            ORDER BY COUNT(Id) DESC
        ]) {
            results.add(new NameValue((String) ar.get('cat'), (Integer) ar.get('cnt')));
        }
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static Integer getAllTimeNoCategoryCount() {
        return [
            SELECT COUNT() FROM ucinn_ascendv2__Funding_Interest__c WHERE HAM_Category__c = null
        ];
    }
}