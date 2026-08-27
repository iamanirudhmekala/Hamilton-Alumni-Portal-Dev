/**
 * HAM_MGFTReviewTxnCtrl
 * ---------------------
 * Backend for the "MGFT / Portal - MakeAGift" Review Transaction list view
 * used on the new Gift Officers app tab.
 *
 * Scope of every query is hard-locked to:
 *   HAM_Data_Source__c = 'Portal - MakeAGift'
 *   RecordType.Name    = 'MGFT'
 *
 * ASSUMPTIONS (please confirm / adjust if incorrect):
 *   1. Hamilton's fiscal year runs July 1 - June 30 (FYxx = Jul (xx-1) - Jun xx).
 *      If Hamilton uses a different FY convention, update fiscalYearRange().
 *   2. ucinn_ascendv2__Designation_1__c ... _5__c relate to
 *      ucinn_ascendv2__Designation__c; the display name shown is that
 *      object's ucinn_ascendv2__Designation_Name__c field (semicolon-joined,
 *      blanks skipped) -- confirmed via schema lookup.
 *   3. "PRM" = Contact.ucinn_ascendv2__PRM__c (lookup to User); we display
 *      the User's Name.
 *   4. "Primary Constituent type" = Contact.ucinn_ascendv2__Primary_Contact_Type__c
 *      (plain text field on Contact, confirmed via schema lookup).
 *   5. "Name w/ suffix" = Contact.HAM_Name_w_Suffix__c (existing formula
 *      field on Contact, confirmed via schema lookup).
 *   6. "Appeal Code" filter is driven off ucinn_ascendv2__Campaign__c
 *      (the Appeal lookup on the transaction), displaying the related
 *      Campaign's ucinn_ascendv2__Motivation_Code__c as the option label.
 *      That same Motivation Code is also shown as a column in the table.
 */
public with sharing class HAM_MGFTReviewTxnCtrl {

    private static final String DATA_SOURCE_VALUE = 'Portal - MakeAGift';
    private static final String RECORD_TYPE_NAME = 'MGFT';
    private static final Integer ROW_LIMIT = 2000;
    private static final Integer FISCAL_YEAR_LOOKBACK = 8; // how many FY options to expose

    // ---------------------------------------------------------------
    // Wrapper types
    // ---------------------------------------------------------------

    public class FilterRequest {
        @AuraEnabled public Date startDate;        // ucinn_ascendv2__Transaction_Date__c >=
        @AuraEnabled public Date endDate;           // ucinn_ascendv2__Transaction_Date__c <=
        @AuraEnabled public String donorName;       // matched against Name w/Suffix (contains)
        @AuraEnabled public String fiscalYear1;     // e.g. 'FY2026'
        @AuraEnabled public String fiscalYear2;     // e.g. 'FY2025'
        @AuraEnabled public Id appealCampaignId;    // ucinn_ascendv2__Campaign__c
    }

    public class TransactionRow {
        @AuraEnabled public Id recordId;
        @AuraEnabled public Date transactionDate;
        @AuraEnabled public String donorName;
        @AuraEnabled public Decimal totalAmount;
        @AuraEnabled public String designations;
        @AuraEnabled public Boolean isAnonymous;
        @AuraEnabled public String prmName;
        @AuraEnabled public String email;
        @AuraEnabled public String primaryConstituentType;
        @AuraEnabled public String appealCode;
        @AuraEnabled public String transactionType;
    }

    public class SelectOption implements Comparable {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        public SelectOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
        public Integer compareTo(Object compareTo) {
            SelectOption other = (SelectOption) compareTo;
            if (this.label == other.label) return 0;
            if (this.label == null) return -1;
            if (other.label == null) return 1;
            return this.label.compareTo(other.label);
        }
    }

    // ---------------------------------------------------------------
    // Main query
    // ---------------------------------------------------------------

    @AuraEnabled(cacheable=true)
    public static List<TransactionRow> getTransactions(FilterRequest filters) {
        if (filters == null) {
            filters = new FilterRequest();
        }

        List<String> whereClauses = new List<String>();
        Map<String, Object> binds = new Map<String, Object>();

        whereClauses.add('HAM_Data_Source__c = :dataSourceValue');
        binds.put('dataSourceValue', DATA_SOURCE_VALUE);

        whereClauses.add('RecordType.Name = :recordTypeName');
        binds.put('recordTypeName', RECORD_TYPE_NAME);

        // Fiscal year filter takes precedence over manual start/end date
        // when one or more fiscal years are selected. Any two selected
        // fiscal years are OR'd together (record must fall in EITHER one).
        List<String> fyOrClauses = new List<String>();
        Integer fyIdx = 0;
        for (String fy : new List<String>{ filters.fiscalYear1, filters.fiscalYear2 }) {
            if (String.isNotBlank(fy)) {
                Date[] range = fiscalYearRange(fy);
                String startKey = 'fyStart' + fyIdx;
                String endKey = 'fyEnd' + fyIdx;
                fyOrClauses.add('(ucinn_ascendv2__Transaction_Date__c >= :' + startKey +
                                 ' AND ucinn_ascendv2__Transaction_Date__c <= :' + endKey + ')');
                binds.put(startKey, range[0]);
                binds.put(endKey, range[1]);
                fyIdx++;
            }
        }

        if (!fyOrClauses.isEmpty()) {
            whereClauses.add('(' + String.join(fyOrClauses, ' OR ') + ')');
        } else {
            if (filters.startDate != null) {
                whereClauses.add('ucinn_ascendv2__Transaction_Date__c >= :startDate');
                binds.put('startDate', filters.startDate);
            }
            if (filters.endDate != null) {
                whereClauses.add('ucinn_ascendv2__Transaction_Date__c <= :endDate');
                binds.put('endDate', filters.endDate);
            }
        }

        if (String.isNotBlank(filters.donorName)) {
            whereClauses.add('ucinn_ascendv2__Contact__r.HAM_Name_w_Suffix__c LIKE :donorNameLike');
            binds.put('donorNameLike', '%' + String.escapeSingleQuotes(filters.donorName) + '%');
        }

        if (filters.appealCampaignId != null) {
            whereClauses.add('ucinn_ascendv2__Campaign__c = :appealCampaignId');
            binds.put('appealCampaignId', filters.appealCampaignId);
        }

        String soql =
            'SELECT Id, ' +
            'ucinn_ascendv2__Transaction_Date__c, ' +
            'ucinn_ascendv2__Total_Transaction_Amount__c, ' +
            'ucinn_ascendv2__Is_Anonymous__c, ' +
            'ucinn_ascendv2__Email_1__c, ' +
            'ucinn_ascendv2__Contact__r.HAM_Name_w_Suffix__c, ' +
            'ucinn_ascendv2__Contact__r.ucinn_ascendv2__Primary_Contact_Type__c, ' +
            'ucinn_ascendv2__Contact__r.ucinn_ascendv2__PRM__r.Name, ' +
            'ucinn_ascendv2__Designation_1__r.ucinn_ascendv2__Designation_Name__c, ' +
            'ucinn_ascendv2__Designation_2__r.ucinn_ascendv2__Designation_Name__c, ' +
            'ucinn_ascendv2__Designation_3__r.ucinn_ascendv2__Designation_Name__c, ' +
            'ucinn_ascendv2__Designation_4__r.ucinn_ascendv2__Designation_Name__c, ' +
            'ucinn_ascendv2__Designation_5__r.ucinn_ascendv2__Designation_Name__c, ' +
            'ucinn_ascendv2__Campaign__r.ucinn_ascendv2__Motivation_Code__c, ' +
            'ucinn_ascendv2__Transaction_Type__c ' +
            'FROM ucinn_ascendv2__Review_Transaction_v2__c ' +
            'WHERE ' + String.join(whereClauses, ' AND ') + ' ' +
            'ORDER BY ucinn_ascendv2__Transaction_Date__c DESC ' +
            'LIMIT ' + ROW_LIMIT;

        List<ucinn_ascendv2__Review_Transaction_v2__c> records =
            (List<ucinn_ascendv2__Review_Transaction_v2__c>) Database.queryWithBinds(
                soql, binds, AccessLevel.USER_MODE
            );

        List<TransactionRow> rows = new List<TransactionRow>();
        for (ucinn_ascendv2__Review_Transaction_v2__c rec : records) {
            TransactionRow row = new TransactionRow();
            row.recordId = rec.Id;
            row.transactionDate = rec.ucinn_ascendv2__Transaction_Date__c;
            row.totalAmount = rec.ucinn_ascendv2__Total_Transaction_Amount__c;
            row.isAnonymous = rec.ucinn_ascendv2__Is_Anonymous__c;
            row.email = rec.ucinn_ascendv2__Email_1__c;

            row.donorName = rec.ucinn_ascendv2__Contact__r != null
                ? rec.ucinn_ascendv2__Contact__r.HAM_Name_w_Suffix__c
                : null;
            row.primaryConstituentType = rec.ucinn_ascendv2__Contact__r != null
                ? rec.ucinn_ascendv2__Contact__r.ucinn_ascendv2__Primary_Contact_Type__c
                : null;
            row.prmName = (rec.ucinn_ascendv2__Contact__r != null &&
                           rec.ucinn_ascendv2__Contact__r.ucinn_ascendv2__PRM__r != null)
                ? rec.ucinn_ascendv2__Contact__r.ucinn_ascendv2__PRM__r.Name
                : null;

            row.appealCode = rec.ucinn_ascendv2__Campaign__r != null
                ? rec.ucinn_ascendv2__Campaign__r.ucinn_ascendv2__Motivation_Code__c
                : null;

            row.transactionType = rec.ucinn_ascendv2__Transaction_Type__c;

            List<String> designationNames = new List<String>();
            if (rec.ucinn_ascendv2__Designation_1__r != null) designationNames.add(rec.ucinn_ascendv2__Designation_1__r.ucinn_ascendv2__Designation_Name__c);
            if (rec.ucinn_ascendv2__Designation_2__r != null) designationNames.add(rec.ucinn_ascendv2__Designation_2__r.ucinn_ascendv2__Designation_Name__c);
            if (rec.ucinn_ascendv2__Designation_3__r != null) designationNames.add(rec.ucinn_ascendv2__Designation_3__r.ucinn_ascendv2__Designation_Name__c);
            if (rec.ucinn_ascendv2__Designation_4__r != null) designationNames.add(rec.ucinn_ascendv2__Designation_4__r.ucinn_ascendv2__Designation_Name__c);
            if (rec.ucinn_ascendv2__Designation_5__r != null) designationNames.add(rec.ucinn_ascendv2__Designation_5__r.ucinn_ascendv2__Designation_Name__c);
            row.designations = String.join(designationNames, '; ');

            rows.add(row);
        }
        return rows;
    }

    // ---------------------------------------------------------------
    // Filter option pickers
    // ---------------------------------------------------------------

    /**
     * Appeal Code options: distinct Campaigns referenced by MGFT / Portal -
     * MakeAGift transactions, labeled with the Campaign's Motivation Code.
     */
    @AuraEnabled(cacheable=true)
    public static List<SelectOption> getAppealCodeOptions() {
        List<SelectOption> options = new List<SelectOption>();
        Set<Id> seen = new Set<Id>();

        for (ucinn_ascendv2__Review_Transaction_v2__c rec : [
            SELECT ucinn_ascendv2__Campaign__c,
                   ucinn_ascendv2__Campaign__r.Name,
                   ucinn_ascendv2__Campaign__r.ucinn_ascendv2__Motivation_Code__c
            FROM ucinn_ascendv2__Review_Transaction_v2__c
            WHERE HAM_Data_Source__c = :DATA_SOURCE_VALUE
              AND RecordType.Name = :RECORD_TYPE_NAME
              AND ucinn_ascendv2__Campaign__c != null
            WITH USER_MODE
            LIMIT 50000
        ]) {
            if (!seen.contains(rec.ucinn_ascendv2__Campaign__c)) {
                seen.add(rec.ucinn_ascendv2__Campaign__c);
                String code = rec.ucinn_ascendv2__Campaign__r.ucinn_ascendv2__Motivation_Code__c;
                String label = String.isNotBlank(code)
                    ? code
                    : rec.ucinn_ascendv2__Campaign__r.Name;
                options.add(new SelectOption(label, rec.ucinn_ascendv2__Campaign__c));
            }
        }
        options.sort();
        return options;
    }

    /**
     * Fiscal year options, most recent first, e.g. 'FY2026' = Jul 2025 - Jun 2026.
     */
    @AuraEnabled(cacheable=true)
    public static List<SelectOption> getFiscalYearOptions() {
        List<SelectOption> options = new List<SelectOption>();
        Integer currentFy = fiscalYearForDate(Date.today());
        for (Integer i = 0; i < FISCAL_YEAR_LOOKBACK; i++) {
            Integer fy = currentFy - i;
            String value = 'FY' + fy;
            String label = 'FY' + fy + ' (Jul ' + (fy - 1) + ' - Jun ' + fy + ')';
            options.add(new SelectOption(label, value));
        }
        return options;
    }

    // ---------------------------------------------------------------
    // Analytics
    // ---------------------------------------------------------------

    /**
     * Total ucinn_ascendv2__Total_Transaction_Amount__c for MGFT / Portal -
     * MakeAGift transactions dated today. Independent of the list view's
     * filters -- always reflects "today" regardless of what the user has
     * searched for.
     */
    @AuraEnabled(cacheable=true)
    public static Decimal getTodayTotalAmount() {
        Date today = Date.today();

        AggregateResult[] results = [
            SELECT SUM(ucinn_ascendv2__Total_Transaction_Amount__c) totalAmt
            FROM ucinn_ascendv2__Review_Transaction_v2__c
            WHERE HAM_Data_Source__c = :DATA_SOURCE_VALUE
              AND RecordType.Name = :RECORD_TYPE_NAME
              AND ucinn_ascendv2__Transaction_Date__c = :today
            WITH USER_MODE
        ];

        Object sumValue = results.isEmpty() ? null : results[0].get('totalAmt');
        return sumValue == null ? 0 : (Decimal) sumValue;
    }

    // ---------------------------------------------------------------
    // Fiscal year helpers  (July 1 - June 30) -- adjust here if Hamilton
    // uses a different fiscal year convention.
    // ---------------------------------------------------------------

    private static Integer fiscalYearForDate(Date d) {
        return d.month() >= 7 ? d.year() + 1 : d.year();
    }

    private static Date[] fiscalYearRange(String fyLabel) {
        // fyLabel expected like 'FY2026'
        Integer fy = Integer.valueOf(fyLabel.replaceAll('[^0-9]', ''));
        Date startDate = Date.newInstance(fy - 1, 7, 1);
        Date endDate = Date.newInstance(fy, 6, 30);
        return new List<Date>{ startDate, endDate };
    }
}