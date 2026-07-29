/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : HAMEducationAmeya<YourName>
 * Created Date    : Jul 16, 2026
 * Last Modified By: Ameya
 * Last Modified On: Jul 16, 2026
 * Description     :This class implements for the Hamilton Quad "Edit Profile > Education"
 *                   section (hqEducationSection LWC). Reads and saves
 *                   ucinn_ascendv2__Degree_Information__c records for the running user's
 *                   Contact: the single "School Degree Information" record (Hamilton
 *                   College majors/minors) and the "Non-School Degree Information" rows
 *                   (Graduate School table), plus typeahead search for Post Code, Minor
 *                   Code, Degree Code, and institution (Account) lookups.
 *  
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Jul 16, 2026  │ Ameya   │ Initial version
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */

public class HAMEducationSectionController {

	
    private static final String SOURCE_VALUE = 'Hamilton Quad';
    private static final String HAMILTON_COLLEGE_ACCOUNT_NAME = 'Hamilton College';
 
    private static Id schoolRecordTypeId {
        get {
            return Schema.SObjectType.ucinn_ascendv2__Degree_Information__c
                .getRecordTypeInfosByDeveloperName()
                .get('School_Degree_Information')
                .getRecordTypeId();
        }
    }
 
    private static Id nonSchoolRecordTypeId {
        get {
            return Schema.SObjectType.ucinn_ascendv2__Degree_Information__c
                .getRecordTypeInfosByDeveloperName()
                .get('Non_School_Degree_Information')
                .getRecordTypeId();
        }
    }
 
    // -------------------------------------------------------------------
    // DTOs
    // -------------------------------------------------------------------
 
    public class CodeOption {
        @AuraEnabled public String id;
        @AuraEnabled public String label;
        public CodeOption(String id, String label) {
            this.id = id;
            this.label = label;
        }
    }
 
    public class HamiltonDegreeData {
        @AuraEnabled public Id recordId;
        @AuraEnabled public List<CodeOption> majors = new List<CodeOption>();
        @AuraEnabled public List<CodeOption> minors = new List<CodeOption>();
    }
 
    public class GradDegreeRow {
        @AuraEnabled public Id recordId;
        @AuraEnabled public Id institutionId;
        @AuraEnabled public String institutionName;
        @AuraEnabled public Id degreeCodeId;
        @AuraEnabled public String degreeCodeName;
        @AuraEnabled public Id postCodeId;
        @AuraEnabled public String postCodeName;
        @AuraEnabled public Id minorCodeId;
        @AuraEnabled public String minorCodeName;
        @AuraEnabled public String degreeYear;
    }
 
    public class EducationData {
        @AuraEnabled public HamiltonDegreeData hamiltonDegree;
        @AuraEnabled public List<GradDegreeRow> gradDegrees = new List<GradDegreeRow>();
    }
 
    // -------------------------------------------------------------------
    // READ
    // -------------------------------------------------------------------
 
    @AuraEnabled(cacheable=true)
    public static EducationData getEducationData() {
        EducationData data = new EducationData();
        Id contactId = getRunningUserContactId();
 
        if (contactId == null) {
            data.hamiltonDegree = new HamiltonDegreeData();
            return data;
        }
 
        // ---- Hamilton College Degree (single record, School record type) ----
        List<ucinn_ascendv2__Degree_Information__c> schoolRecs = [
            SELECT Id,
                   ucinn_ascendv2__Post_Code__c, ucinn_ascendv2__Post_Code__r.ucinn_ascendv2__Major_Specialty_Description__c,
                   ucinn_ascendv2__Second_Major_Post_Code__c, ucinn_ascendv2__Second_Major_Post_Code__r.ucinn_ascendv2__Major_Specialty_Description__c,
                   third_concentration_code__c, third_concentration_code__r.ucinn_ascendv2__Major_Specialty_Description__c,
                   ucinn_ascendv2__Minor_Code__c, ucinn_ascendv2__Minor_Code__r.ucinn_ascendv2__Minor__c,
                   Second_Minor_Code__c, Second_Minor_Code__r.ucinn_ascendv2__Minor__c,
                   Third_Minor_Code__c, Third_Minor_Code__r.ucinn_ascendv2__Minor__c
            FROM ucinn_ascendv2__Degree_Information__c
            WHERE ucinn_ascendv2__Contact__c = :contactId
              AND RecordTypeId = :schoolRecordTypeId
            LIMIT 1
        ];
 
        HamiltonDegreeData hd = new HamiltonDegreeData();
        if (!schoolRecs.isEmpty()) {
            ucinn_ascendv2__Degree_Information__c r = schoolRecs[0];
            hd.recordId = r.Id;
            if (r.ucinn_ascendv2__Post_Code__c != null) {
                hd.majors.add(new CodeOption(r.ucinn_ascendv2__Post_Code__c, r.ucinn_ascendv2__Post_Code__r.ucinn_ascendv2__Major_Specialty_Description__c));
            }
            if (r.ucinn_ascendv2__Second_Major_Post_Code__c != null) {
                hd.majors.add(new CodeOption(r.ucinn_ascendv2__Second_Major_Post_Code__c, r.ucinn_ascendv2__Second_Major_Post_Code__r.ucinn_ascendv2__Major_Specialty_Description__c));
            }
            if (r.third_concentration_code__c != null) {
                hd.majors.add(new CodeOption(r.third_concentration_code__c, r.third_concentration_code__r.ucinn_ascendv2__Major_Specialty_Description__c));
            }
            if (r.ucinn_ascendv2__Minor_Code__c != null) {
                hd.minors.add(new CodeOption(r.ucinn_ascendv2__Minor_Code__c, r.ucinn_ascendv2__Minor_Code__r.ucinn_ascendv2__Minor__c));
            }
            if (r.Second_Minor_Code__c != null) {
                hd.minors.add(new CodeOption(r.Second_Minor_Code__c, r.Second_Minor_Code__r.ucinn_ascendv2__Minor__c));
            }
            if (r.Third_Minor_Code__c != null) {
                hd.minors.add(new CodeOption(r.Third_Minor_Code__c, r.Third_Minor_Code__r.ucinn_ascendv2__Minor__c));
            }
        }
        data.hamiltonDegree = hd;
 
        // ---- Graduate School rows (Non-School record type) ----
        List<ucinn_ascendv2__Degree_Information__c> gradRecs = [
            SELECT Id,
                   ucinn_ascendv2__Degree_Institution__c, ucinn_ascendv2__Degree_Institution__r.Name,
                   ucinn_ascendv2__Degree_Code__c, ucinn_ascendv2__Degree_Code__r.Name,
                   ucinn_ascendv2__Post_Code__c, ucinn_ascendv2__Post_Code__r.ucinn_ascendv2__Major_Specialty_Description__c,
                   ucinn_ascendv2__Minor_Code__c, ucinn_ascendv2__Minor_Code__r.ucinn_ascendv2__Minor__c,
                   ucinn_ascendv2__Conferred_Degree_Year__c
            FROM ucinn_ascendv2__Degree_Information__c
            WHERE ucinn_ascendv2__Contact__c = :contactId
              AND RecordTypeId = :nonSchoolRecordTypeId
            ORDER BY ucinn_ascendv2__Conferred_Degree_Year__c DESC NULLS LAST
        ];
 
        for (ucinn_ascendv2__Degree_Information__c r : gradRecs) {
            GradDegreeRow row = new GradDegreeRow();
            row.recordId = r.Id;
            row.institutionId = r.ucinn_ascendv2__Degree_Institution__c;
            row.institutionName = r.ucinn_ascendv2__Degree_Institution__r != null ? r.ucinn_ascendv2__Degree_Institution__r.Name : null;
            row.degreeCodeId = r.ucinn_ascendv2__Degree_Code__c;
            row.degreeCodeName = r.ucinn_ascendv2__Degree_Code__r != null ? r.ucinn_ascendv2__Degree_Code__r.Name : null;
            row.postCodeId = r.ucinn_ascendv2__Post_Code__c;
            row.postCodeName = r.ucinn_ascendv2__Post_Code__r != null ? r.ucinn_ascendv2__Post_Code__r.ucinn_ascendv2__Major_Specialty_Description__c : null;
            row.minorCodeId = r.ucinn_ascendv2__Minor_Code__c;
            row.minorCodeName = r.ucinn_ascendv2__Minor_Code__r != null ? r.ucinn_ascendv2__Minor_Code__r.ucinn_ascendv2__Minor__c : null;
            row.degreeYear = r.ucinn_ascendv2__Conferred_Degree_Year__c;
            data.gradDegrees.add(row);
        }
 
        return data;
    }
 
    // -------------------------------------------------------------------
    // TYPEAHEAD SEARCH
    // -------------------------------------------------------------------
 
    @AuraEnabled(cacheable=true)
    public static List<CodeOption> searchPostCodes(String searchTerm) {
        String term = '%' + String.escapeSingleQuotes(searchTerm) + '%';
        List<CodeOption> results = new List<CodeOption>();
        for (ucinn_ascendv2__Post_Code__c pc : [
            SELECT Id, ucinn_ascendv2__Major_Specialty_Description__c
            FROM ucinn_ascendv2__Post_Code__c
            WHERE ucinn_ascendv2__Is_Active__c = true
              AND ucinn_ascendv2__Major_Specialty_Description__c LIKE :term
            ORDER BY ucinn_ascendv2__Major_Specialty_Description__c
            LIMIT 25
        ]) {
            results.add(new CodeOption(pc.Id, pc.ucinn_ascendv2__Major_Specialty_Description__c));
        }
        return results;
    }
 
    @AuraEnabled(cacheable=true)
    public static List<CodeOption> searchMinorCodes(String searchTerm) {
        String term = '%' + String.escapeSingleQuotes(searchTerm) + '%';
        List<CodeOption> results = new List<CodeOption>();
        for (ucinn_ascendv2__Minor_Code__c mc : [
            SELECT Id, ucinn_ascendv2__Minor__c
            FROM ucinn_ascendv2__Minor_Code__c
            WHERE ucinn_ascendv2__Minor__c LIKE :term
            ORDER BY ucinn_ascendv2__Minor__c
            LIMIT 25
        ]) {
            results.add(new CodeOption(mc.Id, mc.ucinn_ascendv2__Minor__c));
        }
        return results;
    }
 
    @AuraEnabled(cacheable=true)
    public static List<CodeOption> searchDegreeCodes(String searchTerm) {
        String term = '%' + String.escapeSingleQuotes(searchTerm) + '%';
        List<CodeOption> results = new List<CodeOption>();
        for (ucinn_ascendv2__Degree_Code__c dc : [
            SELECT Id, Name
            FROM ucinn_ascendv2__Degree_Code__c
            WHERE ucinn_ascendv2__Is_Active__c = true
              AND Name LIKE :term
            ORDER BY Name
            LIMIT 25
        ]) {
            results.add(new CodeOption(dc.Id, dc.Name));
        }
        return results;
    }
 
    @AuraEnabled(cacheable=true)
    public static List<CodeOption> searchInstitutions(String searchTerm) {
        String term = '%' + String.escapeSingleQuotes(searchTerm) + '%';
        List<CodeOption> results = new List<CodeOption>();
        for (Account acc : [
            SELECT Id, Name
            FROM Account
            WHERE Name LIKE :term
            ORDER BY Name
            LIMIT 25
        ]) {
            results.add(new CodeOption(acc.Id, acc.Name));
        }
        return results;
    }
 
    // -------------------------------------------------------------------
    // SAVE / DELETE
    // -------------------------------------------------------------------
 
    /**
     * Upserts the single "School Degree Information" record for the running
     * user's Contact with the chosen major(s) and minor(s) (up to 3 each).
     */
    @AuraEnabled
    public static Id saveHamiltonDegree(List<String> majorIds, List<String> minorIds) {
        Id contactId = getRunningUserContactId();
        if (contactId == null) {
            throw new AuraHandledException('No Contact found for the current user.');
        }
        if (majorIds != null && majorIds.size() > 3) {
            throw new AuraHandledException('You may select up to 3 majors.');
        }
        if (minorIds != null && minorIds.size() > 3) {
            throw new AuraHandledException('You may select up to 3 minors.');
        }
 
        ucinn_ascendv2__Degree_Information__c rec;
        List<ucinn_ascendv2__Degree_Information__c> existing = [
            SELECT Id
            FROM ucinn_ascendv2__Degree_Information__c
            WHERE ucinn_ascendv2__Contact__c = :contactId
              AND RecordTypeId = :schoolRecordTypeId
            LIMIT 1
        ];
 
        rec = existing.isEmpty() ? new ucinn_ascendv2__Degree_Information__c() : existing[0];
        rec.RecordTypeId = schoolRecordTypeId;
        rec.ucinn_ascendv2__Contact__c = contactId;
        rec.ucinn_ascendv2__Source__c = SOURCE_VALUE;
        rec.ucinn_ascendv2__Degree_Institution__c = getHamiltonCollegeAccountId();
 
        rec.ucinn_ascendv2__Post_Code__c = getAt(majorIds, 0);
        rec.ucinn_ascendv2__Second_Major_Post_Code__c = getAt(majorIds, 1);
        rec.third_concentration_code__c = getAt(majorIds, 2);
 
        rec.ucinn_ascendv2__Minor_Code__c = getAt(minorIds, 0);
        rec.Second_Minor_Code__c = getAt(minorIds, 1);
        rec.Third_Minor_Code__c = getAt(minorIds, 2);
 
        upsert rec;
        return rec.Id;
    }
 
    /**
     * Creates or updates a single "Non-School Degree Information" (Graduate
     * School) row.
     */
    @AuraEnabled
    public static Id saveGradDegree(GradDegreeRow row) {
        if (row == null || row.institutionId == null) {
            throw new AuraHandledException('School is required.');
        }
        Id contactId = getRunningUserContactId();
        if (contactId == null) {
            throw new AuraHandledException('No Contact found for the current user.');
        }
 
        ucinn_ascendv2__Degree_Information__c rec = row.recordId != null
            ? new ucinn_ascendv2__Degree_Information__c(Id = row.recordId)
            : new ucinn_ascendv2__Degree_Information__c();
 
        rec.RecordTypeId = nonSchoolRecordTypeId;
        rec.ucinn_ascendv2__Contact__c = contactId;
        rec.ucinn_ascendv2__Source__c = SOURCE_VALUE;
        rec.ucinn_ascendv2__Degree_Institution__c = row.institutionId;
        rec.ucinn_ascendv2__Degree_Code__c = row.degreeCodeId;
        rec.ucinn_ascendv2__Post_Code__c = row.postCodeId;
        rec.ucinn_ascendv2__Minor_Code__c = row.minorCodeId;
        rec.ucinn_ascendv2__Conferred_Degree_Year__c = row.degreeYear;
 
        upsert rec;
        return rec.Id;
    }
 
    @AuraEnabled
    public static void deleteGradDegree(Id recordId) {
        Id contactId = getRunningUserContactId();
        List<ucinn_ascendv2__Degree_Information__c> toDelete = [
            SELECT Id
            FROM ucinn_ascendv2__Degree_Information__c
            WHERE Id = :recordId
              AND ucinn_ascendv2__Contact__c = :contactId
              AND RecordTypeId = :nonSchoolRecordTypeId
        ];
        if (!toDelete.isEmpty()) {
            delete toDelete;
        }
    }
 
    // -------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------
 
    private static String getAt(List<String> ids, Integer idx) {
        if (ids == null || ids.size() <= idx) {
            return null;
        }
        String val = ids[idx];
        return String.isBlank(val) ? null : val;
    }
 
    private static Id getRunningUserContactId() {
        User u = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        return u.ContactId;
    }
 
    private static Id cachedHamiltonAccountId;
    private static Id getHamiltonCollegeAccountId() {
        if (cachedHamiltonAccountId == null) {
            List<Account> accs = [
                SELECT Id FROM Account WHERE Name = :HAMILTON_COLLEGE_ACCOUNT_NAME LIMIT 1
            ];
            if (!accs.isEmpty()) {
                cachedHamiltonAccountId = accs[0].Id;
            }
        }
        return cachedHamiltonAccountId;
    }

}