public with sharing class hamCCVolunteerEngagementController {

    /* =====================================================
     * Wrapper Classes
     * ===================================================== */
    public class CCEngagementData {
        @AuraEnabled public Integer currentYearScore { get; set; }
        @AuraEnabled public Integer lastYearScore { get; set; }
        @AuraEnabled public Integer last2YearScore { get; set; }
        @AuraEnabled public Integer currentFiscalYear { get; set; }
        @AuraEnabled public Integer lastFiscalYear { get; set; }
        @AuraEnabled public List<ucinn_ascendv2__Involvement__c> ccInvolvments { get; set; }
        @AuraEnabled public Boolean currentYearTrend { get; set; }
        @AuraEnabled public Boolean lastYearTrend { get; set; }
    }

    public class ActivityWrapper {
        @AuraEnabled public String recordid;
        @AuraEnabled public String startDate;
        @AuraEnabled public String endDate;
        @AuraEnabled public String involvmentCode;
        @AuraEnabled public String handshakeLink;
        @AuraEnabled public String representativeId;
        @AuraEnabled public Boolean isAlumni;
        @AuraEnabled public String involvementDescription;
    }

    public class UpdateWrapper {
        @AuraEnabled public String recordId;
        @AuraEnabled public String parentRecordId;
        @AuraEnabled public String startDate;
        @AuraEnabled public String endDate;
        @AuraEnabled public String involvmentCode;
        @AuraEnabled public String handshakeLink;
        @AuraEnabled public String representativeId;
        @AuraEnabled public Boolean isAlumni;
        @AuraEnabled public String involvementDescription;
    }

    /* =====================================================
     * GET ENGAGEMENT DATA
     * ===================================================== */
    @AuraEnabled(cacheable=true)
    public static CCEngagementData getEngagementData(String recordId, Boolean isAlumni) {

        CCEngagementData res = initResult();

        if (String.isBlank(recordId) || isAlumni == null) {
            return res;
        }

        try {
            List<Id> valueIds = new List<Id>();
            for (ucinn_ascendv2__Involvement_Value__c v :
                [SELECT Id
                 FROM ucinn_ascendv2__Involvement_Value__c
                 WHERE ucinn_ascendv2__Type__c = 'Volunteer Engagement'
                 AND HAM_Category__c = 'Career Center']
            ) {
                valueIds.add(v.Id);
            }

            if (valueIds.isEmpty()) return res;

            List<ucinn_ascendv2__Involvement__c> invs;

            if (isAlumni) {
                invs = [
                    SELECT Id, Name, ucinn_ascendv2__Contact__c,
                                ucinn_ascendv2__Status__c,
                                Owner.Name, HAM_CC_Score__c,
                                ucinn_ascendv2__Involvement_Code_Description_Formula__c,
                                ucinn_ascendv2__Start_Date__c,
                                ucinn_ascendv2__End_Date__c, HAM_Handshake_Link__c,
                                ucinn_ascendv2__Involvement_Code__r.Name,
                                OwnerId, ucinn_ascendv2__Involvement_Code__c,
                                ucinn_ascendv2__Involvement_Description__c
                    FROM ucinn_ascendv2__Involvement__c
                    WHERE ucinn_ascendv2__Contact__c = :recordId
                    AND ucinn_ascendv2__Involvement_Code__c IN :valueIds
                    ORDER BY ucinn_ascendv2__Status__c ASC
                ];
            } else {
                invs = [
                    SELECT Id, Name, ucinn_ascendv2__Account__c,
                                ucinn_ascendv2__Status__c,
                                Owner.Name, HAM_CC_Score__c,
                                ucinn_ascendv2__Involvement_Code_Description_Formula__c,
                                ucinn_ascendv2__Start_Date__c,
                                ucinn_ascendv2__End_Date__c, HAM_Handshake_Link__c,
                                ucinn_ascendv2__Involvement_Code__r.Name,
                                OwnerId, ucinn_ascendv2__Involvement_Code__c,
                                ucinn_ascendv2__Involvement_Description__c
                    FROM ucinn_ascendv2__Involvement__c
                    WHERE ucinn_ascendv2__Account__c = :recordId
                    AND ucinn_ascendv2__Involvement_Code__c IN :valueIds
                    ORDER BY ucinn_ascendv2__Status__c ASC
                ];
            }

            if (invs.isEmpty()) return res;
            res.ccInvolvments = invs;

            calculateScores(res, invs);

        } catch (Exception e) {
            throw new AuraHandledException('Error loading engagement data: ' + e.getMessage());
        }

        return res;
    }

    /* =====================================================
     * INSERT INVOLVEMENT (POSITIVE PATH)
     * ===================================================== */
    @AuraEnabled
    public static CCEngagementData insertInvolvement(String payload) {

        ActivityWrapper dto =
            (ActivityWrapper) JSON.deserialize(payload, ActivityWrapper.class);

        if (dto == null || String.isBlank(dto.recordid) || dto.isAlumni == null) {
            throw new AuraHandledException('Invalid input: Missing required fields.');
        }

        ucinn_ascendv2__Involvement__c inv =
            new ucinn_ascendv2__Involvement__c();

        inv.RecordTypeId =
            Schema.SObjectType.ucinn_ascendv2__Involvement__c
                .getRecordTypeInfosByDeveloperName()
                .get('Volunteer_Engagement')
                .getRecordTypeId();

        if (dto.isAlumni) {
            inv.ucinn_ascendv2__Contact__c = dto.recordid;
        } else {
            inv.ucinn_ascendv2__Account__c = dto.recordid;
        }

        inv.ucinn_ascendv2__Start_Date__c = String.isBlank(dto.startDate)
            ? Date.today() : Date.valueOf(dto.startDate);

        inv.ucinn_ascendv2__Involvement_Code__c = dto.involvmentCode;

        if (!String.isBlank(dto.representativeId)) {
            inv.OwnerId = dto.representativeId;
        }

        if (!String.isBlank(dto.handshakeLink)) {
            inv.HAM_Handshake_Link__c = dto.handshakeLink;
        }

        if (!String.isBlank(dto.involvementDescription)) {
            inv.ucinn_ascendv2__Involvement_Description__c = dto.involvementDescription;
        }

        try {
            insert inv;
        } catch (DmlException e) {
            throw new AuraHandledException('Failed to create Involvement: ' + e.getMessage());
        }

        return getEngagementData(dto.recordid, dto.isAlumni);
    }

    /* =====================================================
     * UPDATE INVOLVEMENT
     * ===================================================== */
    @AuraEnabled
    public static CCEngagementData updateInvolvement(String payload) {

        UpdateWrapper dto =
            (UpdateWrapper) JSON.deserialize(payload, UpdateWrapper.class);

        if (dto == null || String.isBlank(dto.recordId) || 
            String.isBlank(dto.parentRecordId) || dto.isAlumni == null) {
            throw new AuraHandledException('Invalid input: Missing required fields.');
        }

        ucinn_ascendv2__Involvement__c inv;
        
        try {
            inv = [
                SELECT Id, ucinn_ascendv2__Start_Date__c, ucinn_ascendv2__End_Date__c,
                       ucinn_ascendv2__Involvement_Code__c, OwnerId, HAM_Handshake_Link__c,
                       ucinn_ascendv2__Involvement_Description__c
                FROM ucinn_ascendv2__Involvement__c
                WHERE Id = :dto.recordId
                LIMIT 1
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Involvement record not found: ' + e.getMessage());
        }

        // Update fields if provided
        if (!String.isBlank(dto.startDate)) {
            inv.ucinn_ascendv2__Start_Date__c = Date.valueOf(dto.startDate);
        }

        if (!String.isBlank(dto.endDate)) {
            inv.ucinn_ascendv2__End_Date__c = Date.valueOf(dto.endDate);
        }

        if (!String.isBlank(dto.involvmentCode)) {
            inv.ucinn_ascendv2__Involvement_Code__c = dto.involvmentCode;
        }

        if (!String.isBlank(dto.representativeId)) {
            inv.OwnerId = dto.representativeId;
        }

        if (!String.isBlank(dto.handshakeLink)) {
            inv.HAM_Handshake_Link__c = dto.handshakeLink;
        }

        inv.ucinn_ascendv2__Involvement_Description__c = String.isBlank(dto.involvementDescription)
            ? null : dto.involvementDescription;

        try {
            update inv;
        } catch (DmlException e) {
            throw new AuraHandledException('Failed to update Involvement: ' + e.getMessage());
        }

        return getEngagementData(dto.parentRecordId, dto.isAlumni);
    }

    /* =====================================================
     * QUICK-SELECT INVOLVEMENT CODES
     * ===================================================== */
    public class QuickSelectResult {
        @AuraEnabled public List<ucinn_ascendv2__Involvement_Value__c> topCodes { get; set; }
        @AuraEnabled public List<ucinn_ascendv2__Involvement_Value__c> moreCodes { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static QuickSelectResult getQuickSelectCodes() {
        QuickSelectResult res = new QuickSelectResult();
        res.topCodes  = new List<ucinn_ascendv2__Involvement_Value__c>();
        res.moreCodes = new List<ucinn_ascendv2__Involvement_Value__c>();

        Map<Id, ucinn_ascendv2__Involvement_Value__c> allCodesMap = new Map<Id, ucinn_ascendv2__Involvement_Value__c>([
            SELECT Id, Name
            FROM ucinn_ascendv2__Involvement_Value__c
            WHERE ucinn_ascendv2__Type__c = 'Volunteer Engagement'
            AND HAM_Category__c = 'Career Center'
            AND HAM_Volunteer_Activity__c = true
        ]);

        if (allCodesMap.isEmpty()) return res;

        // Iterate aggregate in COUNT DESC order to preserve usage ranking
        Set<Id> seen = new Set<Id>();
        for (AggregateResult ar : [
            SELECT ucinn_ascendv2__Involvement_Code__c codeId, COUNT(Id) cnt
            FROM ucinn_ascendv2__Involvement__c
            WHERE ucinn_ascendv2__Involvement_Code__c IN :allCodesMap.keySet()
            GROUP BY ucinn_ascendv2__Involvement_Code__c
            ORDER BY COUNT(Id) DESC
        ]) {
            Id codeId = (Id) ar.get('codeId');
            if (!allCodesMap.containsKey(codeId)) continue;
            seen.add(codeId);
            Integer cnt = (Integer) ar.get('cnt');
            if (res.topCodes.size() < 5 && cnt >= 3) {
                res.topCodes.add(allCodesMap.get(codeId));
            } else {
                res.moreCodes.add(allCodesMap.get(codeId));
            }
        }

        // Codes with zero usage go at the end of moreCodes
        for (Id codeId : allCodesMap.keySet()) {
            if (!seen.contains(codeId)) {
                res.moreCodes.add(allCodesMap.get(codeId));
            }
        }

        // Fallback: no qualifying top codes → promote first 5 from moreCodes (already usage-ordered)
        if (res.topCodes.isEmpty()) {
            List<ucinn_ascendv2__Involvement_Value__c> promoted = new List<ucinn_ascendv2__Involvement_Value__c>();
            List<ucinn_ascendv2__Involvement_Value__c> remaining = new List<ucinn_ascendv2__Involvement_Value__c>();
            for (Integer i = 0; i < res.moreCodes.size(); i++) {
                if (i < 5) {
                    promoted.add(res.moreCodes[i]);
                } else {
                    remaining.add(res.moreCodes[i]);
                }
            }
            res.topCodes = promoted;
            res.moreCodes = remaining;
        }

        return res;
    }

    /* =====================================================
     * INVOLVEMENT DESCRIPTION PICKLIST VALUES
     * ===================================================== */
    @AuraEnabled(cacheable=true)
    public static List<String> getInvolvementDescriptionValues() {
        List<String> values = new List<String>();
        for (Schema.PicklistEntry e : ucinn_ascendv2__Involvement__c.ucinn_ascendv2__Involvement_Description__c
                .getDescribe().getPicklistValues()) {
            if (e.isActive()) {
                values.add(e.getLabel());
            }
        }
        return values;
    }

    /* =====================================================
     * HELPERS
     * ===================================================== */
    private static CCEngagementData initResult() {
        CCEngagementData r = new CCEngagementData();
        r.currentYearScore = 0;
        r.lastYearScore = 0;
        r.last2YearScore = 0;
        r.currentYearTrend = false;
        r.lastYearTrend = false;
        r.ccInvolvments = new List<ucinn_ascendv2__Involvement__c>();
        r.currentFiscalYear = 0;
        r.lastFiscalYear = 0;
        return r;
    }

    private static void calculateScores(
        CCEngagementData r,
        List<ucinn_ascendv2__Involvement__c> invs
    ) {
        Integer startMonth =
            [SELECT FiscalYearStartMonth FROM Organization].FiscalYearStartMonth;

        Date today = Date.today();
        Integer fyYear =
            today.month() >= startMonth ? today.year() : today.year() - 1;

        Date fyStart = Date.newInstance(fyYear, startMonth, 1);
        Date lastFY = fyStart.addYears(-1);
        Date twoFY = fyStart.addYears(-2);
        Date nextFY = fyStart.addYears(1);

        r.currentFiscalYear = fyStart.year();
        r.lastFiscalYear = lastFY.year();

        for (ucinn_ascendv2__Involvement__c i : invs) {
            if (i.ucinn_ascendv2__Start_Date__c >= fyStart &&
                i.ucinn_ascendv2__Start_Date__c < nextFY) {
                r.currentYearScore += Integer.ValueOf(i.HAM_CC_Score__c);
            } else if (i.ucinn_ascendv2__Start_Date__c >= lastFY &&
                       i.ucinn_ascendv2__Start_Date__c < fyStart) {
                r.lastYearScore += Integer.ValueOf(i.HAM_CC_Score__c);
            } else if (i.ucinn_ascendv2__Start_Date__c >= twoFY &&
                       i.ucinn_ascendv2__Start_Date__c < lastFY) {
                r.last2YearScore += Integer.ValueOf(i.HAM_CC_Score__c);
            }
        }

        r.currentYearTrend = r.currentYearScore >= r.lastYearScore;
        r.lastYearTrend = r.lastYearScore >= r.last2YearScore;
    }
}