/**
 * HamCCVolunteerDashboardController
 *
 * Two independently callable @AuraEnabled methods so the LWC fires both
 * in connectedCallback and both tabs are fully populated on load — no lazy
 * rendering on tab switch.
 *
 *  getVolunteerDashboardData()
 *    Scope : ucinn_ascendv2__Contact__c != null
 *    Tab   : "Alumni / Parents"
 *    Returns: DashboardData — same field shape as the original getDashboardData
 *             so all existing HTML bindings (data.*) require zero changes.
 *
 *  getEmployerDashboardData()
 *    Scope : ucinn_ascendv2__Account__r.HAM_Is_Career_Center_Org__c = TRUE
 *    Tab   : "Employer Engagement"
 *    Returns: EmployerDashboardData whose field names match the existing HTML
 *             bindings for the employer tab:
 *             employerData.totalInvolvements / .uniqueEmployers / .currentCount
 *             .multiEngagementCount / .byCode / .byMonth / .topVolunteers
 *
 * Confirmed org facts (FullQA):
 *   - FiscalYearStartMonth = 7 (July)
 *   - Career Center Involvement Values: Type='Volunteer Engagement', HAM_Category__c='Career Center'
 *   - HAM_Reunion_Year__c on Contact is a String (e.g. '1990')
 *   - HAM_Is_Career_Center_Org__c = TRUE flags real employer accounts
 */
public with sharing class HamCCVolunteerDashboardController {

    /* =========================================================
     * Shared inner classes
     * ========================================================= */

    public class CodeCount {
        @AuraEnabled public String  label { get; set; }
        @AuraEnabled public Integer total { get; set; }
        @AuraEnabled public Integer pct   { get; set; }
    }

    public class MonthCount {
        @AuraEnabled public Integer yr    { get; set; }
        @AuraEnabled public Integer mo    { get; set; }
        @AuraEnabled public String  label { get; set; }
        @AuraEnabled public Integer total { get; set; }
    }

    /* =========================================================
     * TAB 1 — Alumni / Parents wrappers
     * Field names are identical to the original getDashboardData
     * return shape — HTML binds to data.* unchanged.
     * ========================================================= */

    public class DashboardData {
        @AuraEnabled public Integer              totalInvolvements { get; set; }
        @AuraEnabled public Integer              uniqueVolunteers  { get; set; }
        @AuraEnabled public Integer              currentCount      { get; set; }
        @AuraEnabled public Integer              formerCount       { get; set; }
        @AuraEnabled public Integer              multiRoleCount    { get; set; }
        @AuraEnabled public Decimal              avgPerVolunteer   { get; set; }
        @AuraEnabled public String               fyLabel           { get; set; }
        @AuraEnabled public List<CodeCount>      byCode            { get; set; }
        @AuraEnabled public List<MonthCount>     byMonth           { get; set; }
        @AuraEnabled public List<ClassYearCount> byClassYear       { get; set; }
        @AuraEnabled public List<CodeCount>      activeByCode      { get; set; }
        @AuraEnabled public List<TopVolunteer>   topVolunteers     { get; set; }
    }

    public class ClassYearCount {
        @AuraEnabled public String  yr    { get; set; }
        @AuraEnabled public Integer total { get; set; }
    }

    public class TopVolunteer {
        @AuraEnabled public String  contactName  { get; set; }
        @AuraEnabled public String  contactId    { get; set; }
        @AuraEnabled public Integer involvements { get; set; }
        @AuraEnabled public String  status       { get; set; }
        @AuraEnabled public Integer rank         { get; set; }
    }

    /* =========================================================
     * TAB 2 — Employer Engagement wrapper
     * Field names match the existing HTML employer tab bindings:
     *   employerData.totalInvolvements / .uniqueEmployers /
     *   .currentCount / .multiEngagementCount / .byCode /
     *   .byMonth / .topVolunteers
     * topVolunteers reuses TopVolunteer; JS maps accountName into
     * contactName and accountId into contactId so the table HTML
     * renders without any template changes.
     * ========================================================= */

    public class EmployerDashboardData {
        @AuraEnabled public Integer            totalInvolvements    { get; set; }
        @AuraEnabled public Integer            uniqueEmployers      { get; set; }
        @AuraEnabled public Integer            currentCount         { get; set; }
        @AuraEnabled public Integer            multiEngagementCount { get; set; }
        @AuraEnabled public Decimal            avgPerEmployer       { get; set; }
        @AuraEnabled public String             fyLabel              { get; set; }
        @AuraEnabled public List<CodeCount>    byCode               { get; set; }
        @AuraEnabled public List<MonthCount>   byMonth              { get; set; }
        @AuraEnabled public List<TopVolunteer> topVolunteers        { get; set; }
    }

    /* =========================================================
     * Shared helpers
     * ========================================================= */

    private static Date[] getFYBounds() {
        Integer s = [SELECT FiscalYearStartMonth FROM Organization LIMIT 1].FiscalYearStartMonth;
        Date    t = Date.today();
        Integer y = t.month() >= s ? t.year() : t.year() - 1;
        Date    start = Date.newInstance(y, s, 1);
        return new Date[]{ start, start.addYears(1) };
    }

    private static String buildFYLabel(Date s, Date e) {
        String[] M = new String[]{'','Jan','Feb','Mar','Apr','May','Jun',
                                  'Jul','Aug','Sep','Oct','Nov','Dec'};
        Date last = e.addDays(-1);
        return 'FY ' + s.year() + '-' + String.valueOf(last.year()).substring(2)
            + '  (' + M[s.month()] + ' ' + s.year()
            + ' \u2013 ' + M[last.month()] + ' ' + last.year() + ')';
    }

    private static List<Id> getCCValueIds() {
        List<Id> ids = new List<Id>();
        for (ucinn_ascendv2__Involvement_Value__c v : [
            SELECT Id FROM ucinn_ascendv2__Involvement_Value__c
            WHERE ucinn_ascendv2__Type__c = 'Volunteer Engagement'
            AND   HAM_Category__c = 'Career Center'
        ]) { ids.add(v.Id); }
        return ids;
    }

    private static Map<String, Integer> buildMonthMap(Date fyStart) {
        Map<String, Integer> m = new Map<String, Integer>();
        for (Integer i = 0; i < 12; i++) {
            Date slot = fyStart.addMonths(i);
            m.put(String.valueOf(slot.year()) + '-'
                  + String.valueOf(slot.month()).leftPad(2, '0'), 0);
        }
        return m;
    }

    private static List<MonthCount> monthMapToList(Map<String, Integer> mm) {
        String[] M = new String[]{'','Jan','Feb','Mar','Apr','May','Jun',
                                  'Jul','Aug','Sep','Oct','Nov','Dec'};
        List<String> keys = new List<String>(mm.keySet());
        keys.sort();
        List<MonthCount> out = new List<MonthCount>();
        for (String k : keys) {
            Integer yr = Integer.valueOf(k.substring(0, 4));
            Integer mo = Integer.valueOf(k.substring(5));
            MonthCount mc = new MonthCount();
            mc.yr = yr; mc.mo = mo;
            mc.label = M[mo] + ' ' + String.valueOf(yr).substring(2);
            mc.total = mm.get(k);
            out.add(mc);
        }
        return out;
    }

    private static List<CodeCount> sortDesc(List<CodeCount> items) {
        for (Integer i = 1; i < items.size(); i++) {
            CodeCount p = items[i]; Integer j = i - 1;
            while (j >= 0 && items[j].total < p.total) { items[j+1] = items[j]; j--; }
            items[j+1] = p;
        }
        return items;
    }

    private static List<CodeCount> buildCodeList(Map<String, Integer> src, Integer cap) {
        List<CodeCount> codeItems = new List<CodeCount>();
        for (String k : src.keySet()) {
            CodeCount cc = new CodeCount(); cc.label = k; cc.total = src.get(k);
            codeItems.add(cc);
        }
        codeItems = sortDesc(codeItems);
        Integer mx = codeItems.isEmpty() ? 1 : codeItems[0].total;
        List<CodeCount> out = new List<CodeCount>();
        for (Integer i = 0; i < Math.min(cap, codeItems.size()); i++) {
            codeItems[i].pct = (codeItems[i].total * 100) / mx;
            out.add(codeItems[i]);
        }
        return out;
    }

    /* =========================================================
     * METHOD 1 — getVolunteerDashboardData
     * Scope: Contact != null  |  Tab: Alumni / Parents
     * ========================================================= */
    @AuraEnabled(cacheable=true)
    public static DashboardData getVolunteerDashboardData() {

        DashboardData res = new DashboardData();
        res.totalInvolvements = 0; res.uniqueVolunteers = 0;
        res.currentCount = 0;     res.formerCount = 0;
        res.multiRoleCount = 0;   res.avgPerVolunteer = 0;
        res.fyLabel = '';
        res.byCode = new List<CodeCount>();   res.byMonth = new List<MonthCount>();
        res.byClassYear = new List<ClassYearCount>();
        res.activeByCode = new List<CodeCount>();
        res.topVolunteers = new List<TopVolunteer>();

        try {
            Date[] b = getFYBounds();
            Date fyStart = b[0], fyEnd = b[1];
            res.fyLabel = buildFYLabel(fyStart, fyEnd);

            List<Id> vIds = getCCValueIds();
            if (vIds.isEmpty()) return res;

            List<ucinn_ascendv2__Involvement__c> invs = [
                SELECT Id,
                       ucinn_ascendv2__Contact__c,
                       ucinn_ascendv2__Contact__r.Name,
                       ucinn_ascendv2__Contact__r.HAM_Name_w_Suffix__c,
                       ucinn_ascendv2__Contact__r.HAM_Reunion_Year__c,
                       ucinn_ascendv2__Status__c,
                       ucinn_ascendv2__Start_Date__c,
                       ucinn_ascendv2__Involvement_Code__r.ucinn_ascendv2__Involvement_Description__c
                FROM ucinn_ascendv2__Involvement__c
                WHERE ucinn_ascendv2__Involvement_Code__c IN :vIds
                AND   ucinn_ascendv2__Contact__c != null
                AND   ucinn_ascendv2__Start_Date__c >= :fyStart
                AND   ucinn_ascendv2__Start_Date__c <  :fyEnd
                ORDER BY ucinn_ascendv2__Start_Date__c ASC
            ];
            if (invs.isEmpty()) return res;
            res.totalInvolvements = invs.size();

            Set<Id>              cIds      = new Set<Id>();
            Map<Id, Integer>     cntMap    = new Map<Id, Integer>();
            Map<Id, String>      nameMap   = new Map<Id, String>();
            Map<Id, String>      statMap   = new Map<Id, String>();
            Map<String, Integer> codeAll   = new Map<String, Integer>();
            Map<String, Integer> codeAct   = new Map<String, Integer>();
            Map<String, Integer> yearMap   = new Map<String, Integer>();
            Map<String, Integer> monthMap  = buildMonthMap(fyStart);

            for (ucinn_ascendv2__Involvement__c inv : invs) {
                Id cId = inv.ucinn_ascendv2__Contact__c;
                cIds.add(cId);
                Boolean isCurrent = inv.ucinn_ascendv2__Status__c == 'Current';
                if (isCurrent) res.currentCount++; else res.formerCount++;
                cntMap.put(cId, (cntMap.containsKey(cId) ? cntMap.get(cId) : 0) + 1);
                String nm = inv.ucinn_ascendv2__Contact__r.HAM_Name_w_Suffix__c;
                if (String.isNotBlank(nm) && !nameMap.containsKey(cId)) nameMap.put(cId, nm);
                if (isCurrent)                    statMap.put(cId, 'Current');
                else if (!statMap.containsKey(cId)) statMap.put(cId, 'Former');
                String cl = inv.ucinn_ascendv2__Involvement_Code__r?.ucinn_ascendv2__Involvement_Description__c;
                if (String.isBlank(cl)) cl = 'Unknown';
                codeAll.put(cl, (codeAll.containsKey(cl) ? codeAll.get(cl) : 0) + 1);
                if (isCurrent) codeAct.put(cl, (codeAct.containsKey(cl) ? codeAct.get(cl) : 0) + 1);
                String mk = String.valueOf(inv.ucinn_ascendv2__Start_Date__c.year()) + '-'
                    + String.valueOf(inv.ucinn_ascendv2__Start_Date__c.month()).leftPad(2,'0');
                if (monthMap.containsKey(mk)) monthMap.put(mk, monthMap.get(mk) + 1);
                String cy = inv.ucinn_ascendv2__Contact__r.HAM_Reunion_Year__c;
                if (String.isBlank(cy)) cy = 'Unknown';
                yearMap.put(cy, (yearMap.containsKey(cy) ? yearMap.get(cy) : 0) + 1);
            }

            res.uniqueVolunteers = cIds.size();
            res.avgPerVolunteer  = res.uniqueVolunteers > 0
                ? (Decimal.valueOf(res.totalInvolvements) / res.uniqueVolunteers).setScale(2) : 0;
            for (Id cId : cntMap.keySet()) if (cntMap.get(cId) >= 2) res.multiRoleCount++;

            res.byCode       = buildCodeList(codeAll, 10);
            res.activeByCode = buildCodeList(codeAct, 10);
            res.byMonth      = monthMapToList(monthMap);

            List<String> yrs = new List<String>(); Boolean hasUnk = false;
            for (String y : yearMap.keySet()) { if (y == 'Unknown') hasUnk = true; else yrs.add(y); }
            yrs.sort(); if (hasUnk) yrs.add('Unknown');
            for (String y : yrs) {
                ClassYearCount c = new ClassYearCount(); c.yr = y; c.total = yearMap.get(y);
                res.byClassYear.add(c);
            }

            List<Id> sIds = new List<Id>(nameMap.keySet());
            for (Integer i = 1; i < sIds.size(); i++) {
                Id p = sIds[i]; Integer j = i - 1;
                while (j >= 0 && cntMap.get(sIds[j]) < cntMap.get(p)) { sIds[j+1] = sIds[j]; j--; }
                sIds[j+1] = p;
            }
            Integer rank = 1, prev = -1, disp = 1;
            for (Id cId : sIds) {
                if (res.topVolunteers.size() >= 10) break;
                Integer cnt = cntMap.get(cId);
                if (cnt != prev) disp = rank;
                TopVolunteer tv = new TopVolunteer();
                tv.contactId = cId; tv.contactName = nameMap.get(cId);
                tv.involvements = cnt; tv.status = statMap.get(cId); tv.rank = disp;
                res.topVolunteers.add(tv);
                prev = cnt; rank++;
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error loading volunteer data: ' + e.getMessage());
        }
        return res;
    }

    /* =========================================================
     * METHOD 2 — getEmployerDashboardData
     * Scope: Account.HAM_Is_Career_Center_Org__c = TRUE  |  Tab: Employer Engagement
     * ========================================================= */
    @AuraEnabled(cacheable=true)
    public static EmployerDashboardData getEmployerDashboardData() {

        EmployerDashboardData res = new EmployerDashboardData();
        res.totalInvolvements    = 0; res.uniqueEmployers      = 0;
        res.currentCount         = 0; res.multiEngagementCount = 0;
        res.avgPerEmployer       = 0; res.fyLabel              = '';
        res.byCode        = new List<CodeCount>();
        res.byMonth       = new List<MonthCount>();
        res.topVolunteers = new List<TopVolunteer>();

        try {
            Date[] b = getFYBounds();
            Date fyStart = b[0], fyEnd = b[1];
            res.fyLabel = buildFYLabel(fyStart, fyEnd);

            List<Id> vIds = getCCValueIds();
            if (vIds.isEmpty()) return res;

            List<ucinn_ascendv2__Involvement__c> invs = [
                SELECT Id,
                       ucinn_ascendv2__Account__c,
                       ucinn_ascendv2__Account__r.Name,
                       ucinn_ascendv2__Status__c,
                       ucinn_ascendv2__Start_Date__c,
                       ucinn_ascendv2__Involvement_Code__r.ucinn_ascendv2__Involvement_Description__c
                FROM ucinn_ascendv2__Involvement__c
                WHERE ucinn_ascendv2__Involvement_Code__c IN :vIds
                AND   ucinn_ascendv2__Account__c != null
                AND   ucinn_ascendv2__Account__r.HAM_Is_Career_Center_Org__c = TRUE
                AND   ucinn_ascendv2__Start_Date__c >= :fyStart
                AND   ucinn_ascendv2__Start_Date__c <  :fyEnd
                ORDER BY ucinn_ascendv2__Start_Date__c ASC
            ];
            if (invs.isEmpty()) return res;
            res.totalInvolvements = invs.size();

            Set<Id>              aIds     = new Set<Id>();
            Map<Id, Integer>     cntMap   = new Map<Id, Integer>();
            Map<Id, String>      nameMap  = new Map<Id, String>();
            Map<Id, String>      statMap  = new Map<Id, String>();
            Map<String, Integer> codeMap  = new Map<String, Integer>();
            Map<String, Integer> monthMap = buildMonthMap(fyStart);

            for (ucinn_ascendv2__Involvement__c inv : invs) {
                Id aId = inv.ucinn_ascendv2__Account__c;
                aIds.add(aId);
                Boolean isCurrent = inv.ucinn_ascendv2__Status__c == 'Current';
                if (isCurrent) res.currentCount++;
                cntMap.put(aId, (cntMap.containsKey(aId) ? cntMap.get(aId) : 0) + 1);
                if (!nameMap.containsKey(aId)) nameMap.put(aId, inv.ucinn_ascendv2__Account__r.Name);
                if (isCurrent)                    statMap.put(aId, 'Current');
                else if (!statMap.containsKey(aId)) statMap.put(aId, 'Former');
                String cl = inv.ucinn_ascendv2__Involvement_Code__r?.ucinn_ascendv2__Involvement_Description__c;
                if (String.isBlank(cl)) cl = 'Unknown';
                codeMap.put(cl, (codeMap.containsKey(cl) ? codeMap.get(cl) : 0) + 1);
                String mk = String.valueOf(inv.ucinn_ascendv2__Start_Date__c.year()) + '-'
                    + String.valueOf(inv.ucinn_ascendv2__Start_Date__c.month()).leftPad(2,'0');
                if (monthMap.containsKey(mk)) monthMap.put(mk, monthMap.get(mk) + 1);
            }

            res.uniqueEmployers = aIds.size();
            res.avgPerEmployer  = res.uniqueEmployers > 0
                ? (Decimal.valueOf(res.totalInvolvements) / res.uniqueEmployers).setScale(2) : 0;
            for (Id aId : cntMap.keySet()) if (cntMap.get(aId) >= 2) res.multiEngagementCount++;

            res.byCode  = buildCodeList(codeMap, 10);
            res.byMonth = monthMapToList(monthMap);

            // topVolunteers reuses TopVolunteer wrapper so the existing HTML table works.
            // JS _processEmployerData maps accountId→contactId and accountName→contactName.
            List<Id> sIds = new List<Id>(nameMap.keySet());
            for (Integer i = 1; i < sIds.size(); i++) {
                Id p = sIds[i]; Integer j = i - 1;
                while (j >= 0 && cntMap.get(sIds[j]) < cntMap.get(p)) { sIds[j+1] = sIds[j]; j--; }
                sIds[j+1] = p;
            }
            Integer rank = 1, prev = -1, disp = 1;
            for (Id aId : sIds) {
                if (res.topVolunteers.size() >= 10) break;
                Integer cnt = cntMap.get(aId);
                if (cnt != prev) disp = rank;
                TopVolunteer tv = new TopVolunteer();
                tv.contactId    = aId;               // accountId — JS remaps contactUrl to Account view
                tv.contactName  = nameMap.get(aId);  // accountName — renders in Name column
                tv.involvements = cnt;
                tv.status       = statMap.get(aId);
                tv.rank         = disp;
                res.topVolunteers.add(tv);
                prev = cnt; rank++;
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error loading employer data: ' + e.getMessage());
        }
        return res;
    }
}