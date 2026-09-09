/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : HAMEducationSectionController
 * Created Date    : Jul 16, 2026
 * Last Modified By: Ameya
 * Last Modified On: Aug 20, 2026 (fixed Degree Type display + pending-row Id resolution)
 * Description     :This class implements for the Hamilton Quad "Edit Profile > Education"
 *                   section (hameducationsectionHQ LWC). Reads and saves
 *                   ucinn_ascendv2__Degree_Information__c records for the running user's
 *                   Contact: the single "School Degree Information" record (Hamilton
 *                   College majors/minors) and the "Non-School Degree Information" rows
 *                   (Graduate School table), plus typeahead search for Post Code, Minor
 *                   Code, Degree Code, and institution (Account) lookups.
 *
 *                   Runs "without sharing" and uses WITH SYSTEM_MODE / SYSTEM_MODE DML on
 *                   the code-table reads and the Degree Information writes, because the
 *                   Hamilton Quad portal user runs under a Guest User License, which blocks
 *                   record-level sharing to these objects regardless of Apex sharing
 *                   keywords or permission-set grants. All write paths remain scoped to the
 *                   running user's own Contact via getRunningUserContactId(), so the System
 *                   Mode elevation does not grant access beyond that Contact's own records.
 *
 *                   Graduate School rows now support free text ("Other") for School,
 *                   Degree Type, Concentration, and Minor when no matching code-table
 *                   record exists. Such rows are staged on HAM_HQ_Staging__c with
 *                   HAM_is_Ready_for_Processing__c = false and surfaced to the user
 *                   alongside their real Degree Information rows (via getEducationData)
 *                   so they see their entry immediately, without knowing it is pending.
 *                   A Task is created for a Data Steward (owner controlled by the
 *                   HQ_Data_Steward_Owner_Id Custom Label) to create the missing
 *                   code-table record(s); once that's done and
 *                   HAM_is_Ready_for_Processing__c is flipped to true, a scheduled Apex
 *                   job (HQGradDegreeStagingProcessor, not a Flow -- see its header for why)
 *                   converts the staging row into a real Degree_Information__c record.
 *
 *  Change History  :
 *  Date          │   Author     │   Change
 *  ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Jul 16, 2026  │ Ameya   │ Initial version
 *  Aug 10, 2026  │ Ameya   │ without sharing + WITH SYSTEM_MODE / SYSTEM_MODE DML to work
 *                            around Guest User License sharing restrictions on Post Code /
 *                            Minor Code / Degree Code / Account lookups and Degree
 *                            Information writes. saveGradDegree now accepts a JSON string
 *                            parameter and deserializes it manually, working around
 *                            unreliable automatic wrapper-parameter binding for this method.
 *                            saveGradDegree now returns a SaveResult (success/message/
 *                            recordId) instead of throwing AuraHandledException for
 *                            business-rule failures, so the LWC can distinguish success
 *                            from failure without relying solely on try/catch.
 *  Aug 19, 2026  │ Ameya   │ saveGradDegree fixed to prefer Id over Name when both are
 *                            present (pick()). Added support for free-text ("Other")
 *                            entries on School/Degree Type/Concentration/Minor: each field
 *                            is considered "unmatched" if text was entered but no Id was
 *                            selected. Rows with any unmatched field are staged with
 *                            HAM_is_Ready_for_Processing__c = false and a Task is created
 *                            for a Data Steward (owner from HQ_Data_Steward_Owner_Id Custom
 *                            Label). getEducationData now merges those pending staging rows
 *                            into the same list returned for real Degree_Information__c
 *                            rows. saveGradDegree/deleteGradDegree now detect whether
 *                            recordId belongs to HAM_HQ_Staging__c or Degree_Information__c
 *                            and route accordingly, so editing or deleting a still-pending
 *                            row updates/removes the staging record instead of a real one.
 *  Aug 20, 2026  │ Ameya   │ Fixed three Degree Type/Concentration/Minor display bugs.
 *                            (1) getEducationData was querying
 *                            ucinn_ascendv2__Degree_Code__r.Name for the display label on
 *                            real Degree_Information__c rows, but Name on that object is
 *                            Ascend's internal identifier, not the human label --
 *                            searchDegreeCodes() already used the correct custom field
 *                            (ucinn_ascendv2__Degree_Code__c) for the dropdown; the read
 *                            path now matches it. (2) That same gradRecs query never had
 *                            WITH SYSTEM_MODE, unlike every other query in this class that
 *                            touches the managed-package code-table objects -- under the
 *                            Guest User license, Degree_Code__r/Post_Code__r/Minor_Code__r
 *                            silently resolved to null (Account__r happened to work because
 *                            Guest has broader default read access to Account) even though
 *                            the base lookup fields on Degree_Information__c itself were
 *                            fine. Added WITH SYSTEM_MODE to match the rest of the class.
 *                            (3) Pending staging rows store either an Id (matched selection)
 *                            or free text ("Other") in their text fields --
 *                            getEducationData now bulk-resolves any field that's actually a
 *                            valid Id for its expected object to that object's display
 *                            label before returning the row, so the table never shows a raw
 *                            Id for a pending entry.
 *  Aug 25, 2026  │ Ameya   │ Minor now matches how Major already displays: searchMinorCodes
 *                            searches/labels by ucinn_ascendv2__Major_Specialty_Description__c
 *                            (the friendly description) instead of the short code field
 *                            ucinn_ascendv2__Minor__c. The grad-row read path now pulls
 *                            ucinn_ascendv2__Minor_Formula__c directly off the
 *                            Degree_Information__c record (a pre-built formula field, same
 *                            one the Hamilton College Degree section already uses) instead
 *                            of relationship-traversing to Minor_Code__r.Minor__c, avoiding
 *                            another instance of the class of bug fixed for Concentration.
 *                            Pending-row Id resolution for Minor now looks up the same
 *                            description field so a matched-but-unprocessed Minor shows its
 *                            full name instead of the short code.
 *  ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */

public without sharing class HAMEducationSectionController {

    private static final String SOURCE_VALUE = 'Hamilton Quad';
    private static final String HAMILTON_COLLEGE_ACCOUNT_NAME = 'Hamilton College';

    private static Id schoolRecordTypeId {
        get {
            return Schema.SObjectType.ucinn_ascendv2__Degree_Information__c
                .getRecordTypeInfosByDeveloperName()
                .get('Hamilton_AIS_Degree_Information')
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

    private static Id gradSchoolStagingRecordTypeId {
        get {
            return Schema.SObjectType.HAM_HQ_Staging__c
                .getRecordTypeInfosByDeveloperName()
                .get('Grad_School_Degree')
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

    /**
     * Represents one Graduate School row shown in the LWC table, whether it
     * backs a real ucinn_ascendv2__Degree_Information__c record or a
     * still-pending HAM_HQ_Staging__c row (isPending = true). Comparable so
     * getEducationData can merge + sort both sources by degreeYear together.
     */
    public class GradDegreeRow implements Comparable {
        @AuraEnabled public Id recordId;
        @AuraEnabled public Boolean isPending = false;
        @AuraEnabled public Id institutionId;
        @AuraEnabled public String institutionName;
        @AuraEnabled public Id degreeCodeId;
        @AuraEnabled public String degreeCodeName;
        @AuraEnabled public Id postCodeId;
        @AuraEnabled public String postCodeName;
        @AuraEnabled public Id minorCodeId;
        @AuraEnabled public String minorCodeName;
        @AuraEnabled public String degreeYear;

        public Integer compareTo(Object compareTo) {
            GradDegreeRow other = (GradDegreeRow) compareTo;
            Integer thisYear = parseYear(this.degreeYear);
            Integer otherYear = parseYear(other.degreeYear);
            return otherYear - thisYear; // descending, blanks sort last
        }

        private Integer parseYear(String y) {
            if (String.isBlank(y) || !y.isNumeric()) {
                return -1;
            }
            return Integer.valueOf(y);
        }
    }

    public class EducationData {
        @AuraEnabled public HamiltonDegreeData hamiltonDegree;
        @AuraEnabled public List<GradDegreeRow> gradDegrees = new List<GradDegreeRow>();
    }

    public class SaveResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public Id recordId;
    }

    // -------------------------------------------------------------------
    // READ
    // -------------------------------------------------------------------

    @AuraEnabled(cacheable=false)
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
                   Third_Minor_Code__c, Third_Minor_Code__r.ucinn_ascendv2__Minor__c,
                   ucinn_ascendv2__Major_Formula__c, ucinn_ascendv2__Second_Major_Formula__c, Third_Concentration_Formula__c,
                   ucinn_ascendv2__Minor_Formula__c, Second_Minor__c, Third_Minor__c
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
                hd.majors.add(new CodeOption(r.ucinn_ascendv2__Post_Code__c, r.ucinn_ascendv2__Major_Formula__c));
            }
            if (r.ucinn_ascendv2__Second_Major_Post_Code__c != null) {
                hd.majors.add(new CodeOption(r.ucinn_ascendv2__Second_Major_Post_Code__c, r.ucinn_ascendv2__Second_Major_Formula__c));
            }
            if (r.third_concentration_code__c != null) {
                hd.majors.add(new CodeOption(r.third_concentration_code__c, r.Third_Concentration_Formula__c));
            }
            if (r.ucinn_ascendv2__Minor_Code__c != null) {
                hd.minors.add(new CodeOption(r.ucinn_ascendv2__Minor_Code__c, r.ucinn_ascendv2__Minor_Formula__c));
            }
            if (r.Second_Minor_Code__c != null) {
                hd.minors.add(new CodeOption(r.Second_Minor_Code__c, r.Second_Minor__c));
            }
            if (r.Third_Minor_Code__c != null) {
                hd.minors.add(new CodeOption(r.Third_Minor_Code__c, r.Third_Minor__c));
            }
        }
        data.hamiltonDegree = hd;

        // ---- Graduate School rows (Non-School record type, already processed) ----
        // NOTE: Degree Code's display label lives in the custom field
        // ucinn_ascendv2__Degree_Code__c on the Degree Code object (the same field
        // searchDegreeCodes() uses for the dropdown label) -- NOT the standard Name
        // field, which is Ascend's internal identifier and is not meant for display.
        List<ucinn_ascendv2__Degree_Information__c> gradRecs = [
            SELECT Id,
                   ucinn_ascendv2__Degree_Institution__c, ucinn_ascendv2__Degree_Institution__r.Name,
                   ucinn_ascendv2__Degree_Code__c, ucinn_ascendv2__Degree_Code__r.ucinn_ascendv2__Degree_Code__c,
                   ucinn_ascendv2__Post_Code__c, ucinn_ascendv2__Post_Code__r.ucinn_ascendv2__Major_Specialty_Description__c,
                   ucinn_ascendv2__Minor_Code__c, ucinn_ascendv2__Minor_Formula__c,
                   ucinn_ascendv2__Conferred_Degree_Year__c
            FROM ucinn_ascendv2__Degree_Information__c
            WHERE ucinn_ascendv2__Contact__c = :contactId
            AND RecordTypeId = :nonSchoolRecordTypeId
            WITH SYSTEM_MODE
        ];

        for (ucinn_ascendv2__Degree_Information__c r : gradRecs) {
            GradDegreeRow row = new GradDegreeRow();
            row.recordId = r.Id;
            row.isPending = false;
            row.institutionId = r.ucinn_ascendv2__Degree_Institution__c;
            row.institutionName = r.ucinn_ascendv2__Degree_Institution__r != null ? r.ucinn_ascendv2__Degree_Institution__r.Name : null;
            row.degreeCodeId = r.ucinn_ascendv2__Degree_Code__c;
            row.degreeCodeName = r.ucinn_ascendv2__Degree_Code__r != null ? r.ucinn_ascendv2__Degree_Code__r.ucinn_ascendv2__Degree_Code__c : null;
            row.postCodeId = r.ucinn_ascendv2__Post_Code__c;
            row.postCodeName = r.ucinn_ascendv2__Post_Code__r != null ? r.ucinn_ascendv2__Post_Code__r.ucinn_ascendv2__Major_Specialty_Description__c : null;
            row.minorCodeId = r.ucinn_ascendv2__Minor_Code__c;
            row.minorCodeName = r.ucinn_ascendv2__Minor_Formula__c;
            row.degreeYear = r.ucinn_ascendv2__Conferred_Degree_Year__c;
            data.gradDegrees.add(row);
        }

        // ---- Pending Graduate School submissions (staging, not yet processed) ----
        // HAM_Is_Processed__c is a formula (true once HAM_Degree_Information__c is
        // populated by the conversion job); we also filter on it as a safety net so
        // a row never briefly double-appears in both lists during the hand-off.
        //
        // HAM_School__c / HAM_Degree_Code__c / HAM_Major__c / HAM_Minor__c each hold
        // EITHER a real Id (the user selected a code-table result -- pick() in
        // saveGradDegree stores the Id in that case) OR free text (an unmatched
        // "Other" entry). The block below bulk-resolves any Id-shaped value to its
        // display label so the table never shows a raw Id.
        List<HAM_HQ_Staging__c> pendingStaging = [
            SELECT Id, HAM_School__c, HAM_Degree_Code__c, HAM_Major__c, HAM_Minor__c,
                   HAM_Degree_Conferred_Year__c
            FROM HAM_HQ_Staging__c
            WHERE HAM_Constituent__c = :contactId
              AND RecordTypeId = :gradSchoolStagingRecordTypeId
              AND HAM_is_Ready_for_Processing__c = false
              AND HAM_Is_Processed__c = false
            WITH SYSTEM_MODE
        ];

        if (!pendingStaging.isEmpty()) {
            List<GradDegreeRow> pendingRows = new List<GradDegreeRow>();
            Set<Id> schoolIds = new Set<Id>();
            Set<Id> degreeCodeIds = new Set<Id>();
            Set<Id> postCodeIds = new Set<Id>();
            Set<Id> minorCodeIds = new Set<Id>();

            for (HAM_HQ_Staging__c s : pendingStaging) {
                GradDegreeRow row = new GradDegreeRow();
                row.recordId = s.Id;
                row.isPending = true;
                row.institutionName = s.HAM_School__c;
                row.degreeCodeName = s.HAM_Degree_Code__c;
                row.postCodeName = s.HAM_Major__c;
                row.minorCodeName = s.HAM_Minor__c;
                row.degreeYear = s.HAM_Degree_Conferred_Year__c;
                pendingRows.add(row);

                addIfIdOfType(row.institutionName, Account.SObjectType, schoolIds);
                addIfIdOfType(row.degreeCodeName, ucinn_ascendv2__Degree_Code__c.SObjectType, degreeCodeIds);
                addIfIdOfType(row.postCodeName, ucinn_ascendv2__Post_Code__c.SObjectType, postCodeIds);
                addIfIdOfType(row.minorCodeName, ucinn_ascendv2__Minor_Code__c.SObjectType, minorCodeIds);
            }

            Map<Id, String> schoolLabelById = new Map<Id, String>();
            if (!schoolIds.isEmpty()) {
                for (Account a : [SELECT Id, Name FROM Account WHERE Id IN :schoolIds WITH SYSTEM_MODE]) {
                    schoolLabelById.put(a.Id, a.Name);
                }
            }

            Map<Id, String> degreeCodeLabelById = new Map<Id, String>();
            if (!degreeCodeIds.isEmpty()) {
                for (ucinn_ascendv2__Degree_Code__c dc : [
                    SELECT Id, ucinn_ascendv2__Degree_Code__c
                    FROM ucinn_ascendv2__Degree_Code__c
                    WHERE Id IN :degreeCodeIds
                    WITH SYSTEM_MODE
                ]) {
                    degreeCodeLabelById.put(dc.Id, dc.ucinn_ascendv2__Degree_Code__c);
                }
            }

            Map<Id, String> postCodeLabelById = new Map<Id, String>();
            if (!postCodeIds.isEmpty()) {
                for (ucinn_ascendv2__Post_Code__c pc : [
                    SELECT Id, ucinn_ascendv2__Major_Specialty_Description__c
                    FROM ucinn_ascendv2__Post_Code__c
                    WHERE Id IN :postCodeIds
                    WITH SYSTEM_MODE
                ]) {
                    postCodeLabelById.put(pc.Id, pc.ucinn_ascendv2__Major_Specialty_Description__c);
                }
            }

            Map<Id, String> minorCodeLabelById = new Map<Id, String>();
            if (!minorCodeIds.isEmpty()) {
                for (ucinn_ascendv2__Minor_Code__c mc : [
                    SELECT Id, ucinn_ascendv2__Description__c
                    FROM ucinn_ascendv2__Minor_Code__c
                    WHERE Id IN :minorCodeIds
                    WITH SYSTEM_MODE
                ]) {
                    minorCodeLabelById.put(mc.Id, mc.ucinn_ascendv2__Description__c);
                }
            }

            for (GradDegreeRow row : pendingRows) {
                row.institutionName = resolveDisplayLabel(row.institutionName, Account.SObjectType, schoolLabelById);
                row.degreeCodeName = resolveDisplayLabel(row.degreeCodeName, ucinn_ascendv2__Degree_Code__c.SObjectType, degreeCodeLabelById);
                row.postCodeName = resolveDisplayLabel(row.postCodeName, ucinn_ascendv2__Post_Code__c.SObjectType, postCodeLabelById);
                row.minorCodeName = resolveDisplayLabel(row.minorCodeName, ucinn_ascendv2__Minor_Code__c.SObjectType, minorCodeLabelById);
                data.gradDegrees.add(row);
            }
        }

        data.gradDegrees.sort();

        return data;
    }

    // -------------------------------------------------------------------
    // TYPEAHEAD SEARCH
    // -------------------------------------------------------------------

    @AuraEnabled(cacheable=false)
    public static List<CodeOption> searchPostCodes(String searchTerm) {
        String term = '%' + String.escapeSingleQuotes(searchTerm) + '%';
        List<CodeOption> results = new List<CodeOption>();
        for (ucinn_ascendv2__Post_Code__c pc : [
            SELECT Id, ucinn_ascendv2__Major_Specialty_Description__c
            FROM ucinn_ascendv2__Post_Code__c
            WHERE ucinn_ascendv2__Is_Active__c = true
              AND ucinn_ascendv2__Major_Specialty_Description__c LIKE :term
              WITH SYSTEM_MODE
            ORDER BY ucinn_ascendv2__Major_Specialty_Description__c
            LIMIT 25
        ]) {
            results.add(new CodeOption(pc.Id, pc.ucinn_ascendv2__Major_Specialty_Description__c));
        }
        return results;
    }

    @AuraEnabled(cacheable=false)
    public static List<CodeOption> searchMinorCodes(String searchTerm) {
        String term = '%' + String.escapeSingleQuotes(searchTerm) + '%';
        List<CodeOption> results = new List<CodeOption>();
        for (ucinn_ascendv2__Minor_Code__c mc : [
            SELECT Id, ucinn_ascendv2__Description__c
            FROM ucinn_ascendv2__Minor_Code__c
            WHERE ucinn_ascendv2__Description__c LIKE :term
            WITH SYSTEM_MODE
            ORDER BY ucinn_ascendv2__Description__c
            LIMIT 25
        ]) {
            results.add(new CodeOption(mc.Id, mc.ucinn_ascendv2__Description__c));
        }
        return results;
    }

    @AuraEnabled(cacheable=false)
    public static List<CodeOption> searchDegreeCodes(String searchTerm) {
        String term = '%' + String.escapeSingleQuotes(searchTerm) + '%';
        List<CodeOption> results = new List<CodeOption>();
        for (ucinn_ascendv2__Degree_Code__c dc : [
            SELECT Id, Name, ucinn_ascendv2__Degree_Code__c
            FROM ucinn_ascendv2__Degree_Code__c
            WHERE ucinn_ascendv2__Is_Active__c = true
              AND ucinn_ascendv2__Degree_Code__c LIKE :term
            WITH SYSTEM_MODE
            ORDER BY ucinn_ascendv2__Degree_Code__c
            LIMIT 25
        ]) {
            results.add(new CodeOption(dc.Id, dc.ucinn_ascendv2__Degree_Code__c));
        }
        return results;
    }

    @AuraEnabled(cacheable=false)
    public static List<CodeOption> searchInstitutions(String searchTerm) {
        String term = '%' + String.escapeSingleQuotes(searchTerm) + '%';
        List<CodeOption> results = new List<CodeOption>();
        for (Account acc : [
            SELECT Id, Name
            FROM Account
            WHERE Name LIKE :term
            AND Type = 'Academic Organization'
            WITH SYSTEM_MODE
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
            WITH SYSTEM_MODE
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

        Database.upsert(rec, AccessLevel.SYSTEM_MODE);
        return rec.Id;
    }

    /**
     * Creates or updates a single "Non-School Degree Information" (Graduate
     * School) row.
     *
     * Accepts the row as a JSON string rather than a strongly-typed
     * GradDegreeRow parameter. Automatic Aura/LWC wrapper-parameter binding
     * for this method was unreliable in testing (fields consistently arrived
     * null server-side despite being populated client-side) -- manual
     * JSON.deserialize sidesteps that platform binding path entirely.
     *
     * A field is "unmatched" when the user typed/kept text but never selected
     * a code-table result (Id is null while the Name is populated) -- i.e. an
     * "Other" / free-text entry. If any of School / Degree Type / Concentration
     * / Minor is unmatched, the row is staged with
     * HAM_is_Ready_for_Processing__c = false and a Task is opened for a Data
     * Steward (owner from the HQ_Data_Steward_Owner_Id Custom Label). If every
     * field the user filled in resolved to a real Id,
     * HAM_is_Ready_for_Processing__c = true and the conversion job picks it up
     * on its next run.
     *
     * If recordId belongs to HAM_HQ_Staging__c (i.e. the row being edited is
     * still pending), the staging record is updated in place rather than
     * treated as a real Degree_Information__c row.
     *
     * Returns a SaveResult rather than throwing on validation/business-rule
     * failures (bad JSON, missing school, missing Contact), so the caller
     * can branch on result.success. Unexpected DML/runtime exceptions are
     * still caught and reported through the same SaveResult shape rather
     * than propagating, so this method never throws under normal use.
     */
    @AuraEnabled
    public static SaveResult saveGradDegree(String rowJson) {
        SaveResult result = new SaveResult();

        GradDegreeRow row;
        try {
            row = (GradDegreeRow) JSON.deserialize(rowJson, GradDegreeRow.class);
        } catch (Exception e) {
            result.success = false;
            result.message = 'Could not read the submitted form: ' + e.getMessage();
            return result;
        }

        if (row == null || (row.institutionId == null && String.isBlank(row.institutionName))) {
            result.success = false;
            result.message = 'School is required.';
            return result;
        }

        Id contactId = getRunningUserContactId();
        if (contactId == null) {
            result.success = false;
            result.message = 'No Contact found for the current user.';
            return result;
        }

        try {
            Boolean editingPendingStagingRow = row.recordId != null
                && row.recordId.getSObjectType() == HAM_HQ_Staging__c.SObjectType;

            if (row.recordId == null || editingPendingStagingRow) {
                Boolean readyForProcessing = isRowReadyForProcessing(row);

                HAM_HQ_Staging__c staging = editingPendingStagingRow
                    ? new HAM_HQ_Staging__c(Id = row.recordId)
                    : new HAM_HQ_Staging__c(RecordTypeId = gradSchoolStagingRecordTypeId, HAM_Constituent__c = contactId);

                staging.HAM_School__c = pick(row.institutionId, row.institutionName);
                staging.HAM_Degree_Code__c = pick(row.degreeCodeId, row.degreeCodeName);
                staging.HAM_Major__c = pick(row.postCodeId, row.postCodeName);
                staging.HAM_Minor__c = pick(row.minorCodeId, row.minorCodeName);
                staging.HAM_Degree_Conferred_Year__c = row.degreeYear;
                staging.HAM_is_Ready_for_Processing__c = readyForProcessing;

                if (editingPendingStagingRow) {
                    Database.update(staging, AccessLevel.SYSTEM_MODE);
                } else {
                    Database.insert(staging, AccessLevel.SYSTEM_MODE);
                }

                if (!readyForProcessing) {
                    createDataStewardTask(staging.Id);
                }

                result.success = true;
                result.recordId = staging.Id;
                result.message = readyForProcessing
                    ? 'Your graduate degree was submitted and will appear on your profile shortly.'
                    : 'Your graduate degree was submitted. A staff member will finish setting it up before it appears fully on your profile.';
            } else {
                // Existing real Degree_Information__c row: update directly.
                ucinn_ascendv2__Degree_Information__c rec = new ucinn_ascendv2__Degree_Information__c(Id = row.recordId);
                rec.ucinn_ascendv2__Degree_Institution__c = row.institutionId;
                rec.ucinn_ascendv2__Degree_Code__c = row.degreeCodeId;
                rec.ucinn_ascendv2__Post_Code__c = row.postCodeId;
                rec.ucinn_ascendv2__Minor_Code__c = row.minorCodeId;
                rec.ucinn_ascendv2__Conferred_Degree_Year__c = row.degreeYear;

                Database.update(rec, AccessLevel.SYSTEM_MODE);

                result.success = true;
                result.recordId = rec.Id;
                result.message = 'Graduate degree saved successfully.';
            }
        } catch (Exception e) {
            result.success = false;
            result.message = 'Unable to save graduate degree: ' + e.getMessage();
        }
        return result;
    }

    @AuraEnabled
    public static void deleteGradDegree(Id recordId) {
        Id contactId = getRunningUserContactId();

        if (recordId.getSObjectType() == HAM_HQ_Staging__c.SObjectType) {
            List<HAM_HQ_Staging__c> toDelete = [
                SELECT Id
                FROM HAM_HQ_Staging__c
                WHERE Id = :recordId
                  AND HAM_Constituent__c = :contactId
                  AND HAM_is_Ready_for_Processing__c = false
                  AND HAM_Is_Processed__c = false
                WITH SYSTEM_MODE
            ];
            if (!toDelete.isEmpty()) {
                Database.delete(toDelete, AccessLevel.SYSTEM_MODE);
            }
            return;
        }

        List<ucinn_ascendv2__Degree_Information__c> toDelete = [
            SELECT Id
            FROM ucinn_ascendv2__Degree_Information__c
            WHERE Id = :recordId
              AND ucinn_ascendv2__Contact__c = :contactId
              AND RecordTypeId = :nonSchoolRecordTypeId
            WITH SYSTEM_MODE
        ];
        if (!toDelete.isEmpty()) {
            Database.delete(toDelete, AccessLevel.SYSTEM_MODE);
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

    /**
     * Prefers the Id (stringified) over the Name when both are present;
     * falls back to the Name if the Id is null (the "Other" / free-text case).
     */
    private static String pick(Id idVal, String nameVal) {
        if (idVal != null) {
            return String.valueOf(idVal);
        }
        return nameVal;
    }

    /**
     * A field is "unmatched" (i.e. free text with no selected code-table
     * record) when text was entered but no Id was ever selected for it.
     * A blank field (e.g. the optional Minor left empty) is not unmatched.
     */
    private static Boolean isUnmatched(Id idVal, String nameVal) {
        return idVal == null && String.isNotBlank(nameVal);
    }

    private static Boolean isRowReadyForProcessing(GradDegreeRow row) {
        return !isUnmatched(row.institutionId, row.institutionName)
            && !isUnmatched(row.degreeCodeId, row.degreeCodeName)
            && !isUnmatched(row.postCodeId, row.postCodeName)
            && !isUnmatched(row.minorCodeId, row.minorCodeName);
    }

    /**
     * If val is a well-formed Id belonging to expectedType, adds it to idSet.
     * Used to collect which pending-row text fields actually hold an Id (a
     * matched selection) versus free text ("Other"), so only the former get
     * bulk-queried for their display label.
     */
    private static void addIfIdOfType(String val, Schema.SObjectType expectedType, Set<Id> idSet) {
        Id parsed = parseIdOfType(val, expectedType);
        if (parsed != null) {
            idSet.add(parsed);
        }
    }

    private static Id parseIdOfType(String val, Schema.SObjectType expectedType) {
        if (String.isBlank(val)) {
            return null;
        }
        try {
            Id possibleId = Id.valueOf(val);
            if (possibleId.getSObjectType() == expectedType) {
                return possibleId;
            }
        } catch (Exception e) {
            // Not a well-formed Id at all -- it's free text.
        }
        return null;
    }

    /**
     * Returns the display label for a pending row's stored field value: if the
     * value is a valid Id for expectedType, looks up its label in labelById
     * (falling back to the raw stored value if the lookup somehow missed --
     * e.g. the record was deleted after the staging row was created). If the
     * value isn't an Id at all, it's already free text ("Other") and is
     * returned as-is.
     */
    private static String resolveDisplayLabel(String storedValue, Schema.SObjectType expectedType, Map<Id, String> labelById) {
        Id parsed = parseIdOfType(storedValue, expectedType);
        if (parsed == null) {
            return storedValue;
        }
        String label = labelById.get(parsed);
        return label != null ? label : storedValue;
    }

    /**
     * Owner (Queue or User) for data-steward Tasks, read from the
     * HQ_Data_Steward_Owner_Id Custom Label so the assignee can be changed
     * without a code deploy. Returns null (unassigned Task) if the label is
     * blank or hasn't been set yet.
     */
    private static Id getDataStewardOwnerId() {
        String ownerIdStr = Label.HQ_Data_Steward_Owner_Id;
        if (String.isBlank(ownerIdStr) || ownerIdStr == 'REPLACE_WITH_QUEUE_OR_USER_ID') {
            return null;
        }
        try {
            return Id.valueOf(ownerIdStr);
        } catch (Exception e) {
            return null;
        }
    }

    private static void createDataStewardTask(Id stagingId) {
        Task t = new Task();
        t.WhatId = stagingId;
        t.Subject = 'HQ grad degree needs new code-table record(s)';
        t.Description = 'A Hamilton Quad user submitted a graduate degree with a school, degree '
            + 'type, concentration, or minor that does not yet exist in Ascend. Create the '
            + 'missing record(s) (Account / Degree Code / Post Code / Minor Code) so the text '
            + 'exactly matches this staging record, then check "Ready for Processing" on the '
            + 'staging record to publish it to the constituent\'s profile.';
        Id ownerId = getDataStewardOwnerId();
        if (ownerId != null) {
            t.OwnerId = ownerId;
        }
        t.ActivityDate = Date.today().addDays(3);
        t.Status = 'Not Started';
        t.Priority = 'Normal';
        Database.insert(t, AccessLevel.SYSTEM_MODE);
    }

    private static Id getRunningUserContactId() {
        User u = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        return u.ContactId;
    }

    private static Id cachedHamiltonAccountId;
    private static Id getHamiltonCollegeAccountId() {
        if (cachedHamiltonAccountId == null) {
            List<Account> accs = [
                SELECT Id FROM Account WHERE Name = :HAMILTON_COLLEGE_ACCOUNT_NAME
                WITH SYSTEM_MODE
                LIMIT 1
            ];
            if (!accs.isEmpty()) {
                cachedHamiltonAccountId = accs[0].Id;
            }
        }
        return cachedHamiltonAccountId;
    }

}