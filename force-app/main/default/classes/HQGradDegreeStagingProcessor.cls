/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : HQGradDegreeStagingProcessor
 * Purpose         : Converts HAM_HQ_Staging__c "Grad School Degree" rows into real
 *                   ucinn_ascendv2__Degree_Information__c records once they're marked
 *                   HAM_is_Ready_for_Processing__c = true.
 *
 *                   Replaces the record-triggered Flow's scheduled path, which does not
 *                   execute when the triggering insert/update happens under a Guest User
 *                   session (a platform restriction, not a Flow bug) -- the Hamilton Quad
 *                   portal always writes staging records as Guest, so scheduled paths on
 *                   that object trigger never actually queue.
 *
 *                   Runs as a normal Scheduled Apex job, so the "running user" is whoever
 *                   scheduled the job -- never Guest -- and standard sharing/FLS on Account,
 *                   Post Code, Degree Code, and Minor Code all apply normally, with
 *                   SYSTEM_MODE reserved only for the final Degree Information insert and
 *                   the staging-record link-back, matching how the rest of this feature
 *                   already elevates access.
 *
 *                   HAM_School__c / HAM_Degree_Code__c / HAM_Major__c / HAM_Minor__c hold
 *                   EITHER a real Id (HAMEducationSectionController.pick() stores the Id
 *                   whenever the user selected a code-table result) OR free text (an
 *                   unmatched "Other" entry). Each field is resolved by first checking
 *                   whether its stored value is already a valid Id for the expected
 *                   object -- if so it's used directly -- and only falling back to a
 *                   Name/label match when it isn't.
 *
 *  Change History  :
 *  Date          │   Author     │   Change
 *  ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Aug 20, 2026  │ Ameya   │ Initial version, replacing record-triggered scheduled path.
 *  Aug 20, 2026  │ Ameya   │ Fixed resolution: staging fields hold an Id for matched rows
 *                            and free text only for "Other" rows. resolveId() checks Id
 *                            validity against the expected SObjectType first, then falls
 *                            back to the by-Name map; SOQL reverted to filter by
 *                            Name/label so the free-text ("Other") case still resolves.
 *  ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */
public with sharing class HQGradDegreeStagingProcessor implements Schedulable {

    public void execute(SchedulableContext ctx) {
        processReadyStagingRecords();
    }

    /**
     * Finds every "ready" grad-school staging row not yet processed, resolves each
     * field (School/Degree Type/Concentration/Minor) to its matching code-table Id --
     * directly, if the stored value is already a valid Id, or by exact Name/label
     * match if it's free text -- creates the real Degree Information record, and
     * links it back on the staging row. Any row that can't be fully resolved is
     * flagged back to HAM_is_Ready_for_Processing__c = false with a follow-up Task,
     * rather than silently left in limbo.
     */
    public static void processReadyStagingRecords() {
        Id gradSchoolRecordTypeId = Schema.SObjectType.HAM_HQ_Staging__c
            .getRecordTypeInfosByDeveloperName().get('Grad_School_Degree').getRecordTypeId();
        Id nonSchoolDegreeRecordTypeId = Schema.SObjectType.ucinn_ascendv2__Degree_Information__c
            .getRecordTypeInfosByDeveloperName().get('Non_School_Degree_Information').getRecordTypeId();

        List<HAM_HQ_Staging__c> readyRows = [
            SELECT Id, HAM_Constituent__c, HAM_School__c, HAM_Degree_Code__c,
                   HAM_Major__c, HAM_Minor__c, HAM_Degree_Conferred_Year__c
            FROM HAM_HQ_Staging__c
            WHERE RecordTypeId = :gradSchoolRecordTypeId
              AND HAM_is_Ready_for_Processing__c = true
              AND HAM_Is_Processed__c = false
            LIMIT 200
        ];

        if (readyRows.isEmpty()) {
            return;
        }

        // ---- Bulk-resolve every distinct FREE-TEXT (non-Id) value to its Id, one query
        //      per object. Values that are already valid Ids for the expected object are
        //      resolved directly in the per-row loop below via resolveId(), so they don't
        //      need to appear in these name/label lookups at all. ----
        Set<String> schoolNames = new Set<String>();
        Set<String> degreeCodeNames = new Set<String>();
        Set<String> postCodeLabels = new Set<String>();
        Set<String> minorLabels = new Set<String>();

        for (HAM_HQ_Staging__c s : readyRows) {
            if (String.isNotBlank(s.HAM_School__c) && !isIdOfType(s.HAM_School__c, Account.SObjectType)) {
                schoolNames.add(s.HAM_School__c);
            }
            if (String.isNotBlank(s.HAM_Degree_Code__c) && !isIdOfType(s.HAM_Degree_Code__c, ucinn_ascendv2__Degree_Code__c.SObjectType)) {
                degreeCodeNames.add(s.HAM_Degree_Code__c);
            }
            if (String.isNotBlank(s.HAM_Major__c) && !isIdOfType(s.HAM_Major__c, ucinn_ascendv2__Post_Code__c.SObjectType)) {
                postCodeLabels.add(s.HAM_Major__c);
            }
            if (String.isNotBlank(s.HAM_Minor__c) && !isIdOfType(s.HAM_Minor__c, ucinn_ascendv2__Minor_Code__c.SObjectType)) {
                minorLabels.add(s.HAM_Minor__c);
            }
        }

        Map<String, Id> accountByName = new Map<String, Id>();
        for (Account a : [SELECT Id, Name FROM Account WHERE Name IN :schoolNames AND Type = 'Academic Organization']) {
            accountByName.put(a.Name, a.Id);
        }

        Map<String, Id> degreeCodeByName = new Map<String, Id>();
        for (ucinn_ascendv2__Degree_Code__c dc : [
            SELECT Id, ucinn_ascendv2__Degree_Code__c
            FROM ucinn_ascendv2__Degree_Code__c
            WHERE ucinn_ascendv2__Degree_Code__c IN :degreeCodeNames AND ucinn_ascendv2__Is_Active__c = true
        ]) {
            degreeCodeByName.put(dc.ucinn_ascendv2__Degree_Code__c, dc.Id);
        }

        Map<String, Id> postCodeByLabel = new Map<String, Id>();
        for (ucinn_ascendv2__Post_Code__c pc : [
            SELECT Id, ucinn_ascendv2__Major_Specialty_Description__c
            FROM ucinn_ascendv2__Post_Code__c
            WHERE ucinn_ascendv2__Major_Specialty_Description__c IN :postCodeLabels AND ucinn_ascendv2__Is_Active__c = true
        ]) {
            postCodeByLabel.put(pc.ucinn_ascendv2__Major_Specialty_Description__c, pc.Id);
        }

        Map<String, Id> minorCodeByLabel = new Map<String, Id>();
        for (ucinn_ascendv2__Minor_Code__c mc : [
            SELECT Id, ucinn_ascendv2__Minor__c
            FROM ucinn_ascendv2__Minor_Code__c
            WHERE ucinn_ascendv2__Minor__c IN :minorLabels
        ]) {
            minorCodeByLabel.put(mc.ucinn_ascendv2__Minor__c, mc.Id);
        }

        // ---- Build the Degree Information inserts + staging link-backs ----
        List<ucinn_ascendv2__Degree_Information__c> toInsert = new List<ucinn_ascendv2__Degree_Information__c>();
        List<HAM_HQ_Staging__c> resolvedStaging = new List<HAM_HQ_Staging__c>();
        List<HAM_HQ_Staging__c> unresolvedStaging = new List<HAM_HQ_Staging__c>();

        for (HAM_HQ_Staging__c s : readyRows) {
            Id accountId = resolveId(s.HAM_School__c, Account.SObjectType, accountByName);
            Id degreeCodeId = resolveId(s.HAM_Degree_Code__c, ucinn_ascendv2__Degree_Code__c.SObjectType, degreeCodeByName);
            Id postCodeId = resolveId(s.HAM_Major__c, ucinn_ascendv2__Post_Code__c.SObjectType, postCodeByLabel);

            // Minor is optional: a genuinely blank Minor is fine; text/an Id that fails
            // to resolve is what makes the row unresolved.
            Id minorCodeId = resolveId(s.HAM_Minor__c, ucinn_ascendv2__Minor_Code__c.SObjectType, minorCodeByLabel);
            Boolean minorUnresolved = String.isNotBlank(s.HAM_Minor__c) && minorCodeId == null;

            if (accountId == null || degreeCodeId == null || postCodeId == null || minorUnresolved) {
                unresolvedStaging.add(s);
                continue;
            }

            ucinn_ascendv2__Degree_Information__c degree = new ucinn_ascendv2__Degree_Information__c();
            degree.RecordTypeId = nonSchoolDegreeRecordTypeId;
            degree.ucinn_ascendv2__Contact__c = s.HAM_Constituent__c;
            degree.ucinn_ascendv2__Degree_Institution__c = accountId;
            degree.ucinn_ascendv2__Degree_Code__c = degreeCodeId;
            degree.ucinn_ascendv2__Post_Code__c = postCodeId;
            degree.ucinn_ascendv2__Minor_Code__c = minorCodeId;
            degree.ucinn_ascendv2__Conferred_Degree_Year__c = s.HAM_Degree_Conferred_Year__c;
            degree.ucinn_ascendv2__Source__c = 'Hamilton Quad';
            toInsert.add(degree);
            resolvedStaging.add(s);
        }

        if (!toInsert.isEmpty()) {
            List<Database.SaveResult> insertResults = Database.insert(toInsert, false, AccessLevel.SYSTEM_MODE);

            List<HAM_HQ_Staging__c> toUpdate = new List<HAM_HQ_Staging__c>();
            for (Integer i = 0; i < insertResults.size(); i++) {
                HAM_HQ_Staging__c s = resolvedStaging[i];
                if (insertResults[i].isSuccess()) {
                    toUpdate.add(new HAM_HQ_Staging__c(
                        Id = s.Id,
                        HAM_Degree_Information__c = insertResults[i].getId()
                    ));
                } else {
                    unresolvedStaging.add(s);
                }
            }
            if (!toUpdate.isEmpty()) {
                Database.update(toUpdate, false, AccessLevel.SYSTEM_MODE);
            }
        }

        if (!unresolvedStaging.isEmpty()) {
            flagUnresolvedRows(unresolvedStaging);
        }
    }

    /**
     * Resolves a staging field's stored value to an Id: if the value is already a
     * valid Id belonging to expectedType, returns it directly (the "matched
     * selection" case). Otherwise treats it as free text and looks it up in
     * byNameOrLabel (the "Other" case). Returns null if it resolves to neither.
     */
    private static Id resolveId(String storedValue, Schema.SObjectType expectedType, Map<String, Id> byNameOrLabel) {
        if (String.isBlank(storedValue)) {
            return null;
        }
        Id directId = parseIdOfType(storedValue, expectedType);
        if (directId != null) {
            return directId;
        }
        return byNameOrLabel.get(storedValue);
    }

    private static Boolean isIdOfType(String val, Schema.SObjectType expectedType) {
        return parseIdOfType(val, expectedType) != null;
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
            // Not a well-formed Id at all -- it's free text. Fall through to null.
        }
        return null;
    }

    /**
     * A row can end up here if a Data Steward checked "Ready for Processing" before
     * the code-table record actually existed, or the text doesn't match exactly.
     * Flip it back to not-ready and re-open (or create) a Task rather than let it
     * disappear from view.
     */
    private static void flagUnresolvedRows(List<HAM_HQ_Staging__c> unresolvedStaging) {
        List<HAM_HQ_Staging__c> toReset = new List<HAM_HQ_Staging__c>();
        List<Task> followUpTasks = new List<Task>();

        for (HAM_HQ_Staging__c s : unresolvedStaging) {
            toReset.add(new HAM_HQ_Staging__c(Id = s.Id, HAM_is_Ready_for_Processing__c = false));

            Task t = new Task();
            t.WhatId = s.Id;
            t.Subject = 'HQ grad degree still unresolved after marking Ready';
            t.Description = 'This staging record was marked "Ready for Processing" but the School, '
                + 'Degree Type, Concentration, or Minor text doesn\'t exactly match an existing '
                + 'record yet. Double-check spelling/capitalization against the staging record\'s '
                + 'text, then re-check "Ready for Processing" once it lines up.';
            Id ownerId = getDataStewardOwnerId();
            if (ownerId != null) {
                t.OwnerId = ownerId;
            }
            t.ActivityDate = Date.today().addDays(1);
            t.Status = 'Not Started';
            t.Priority = 'High';
            followUpTasks.add(t);
        }

        if (!toReset.isEmpty()) {
            Database.update(toReset, false, AccessLevel.SYSTEM_MODE);
        }
        if (!followUpTasks.isEmpty()) {
            Database.insert(followUpTasks, false, AccessLevel.SYSTEM_MODE);
        }
    }

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

    /**
     * Schedules this job every 15 minutes (4 jobs, offset by 15 min each, since a
     * single System.schedule() job can't self-reschedule at sub-hourly granularity
     * across hour boundaries without chaining). Run each line once, one time, from
     * Anonymous Apex (Setup > Apex Classes > Schedule Apex also works, but only
     * supports one cron per job there -- use anonymous Apex for the offset jobs).
     */
    // System.schedule('HQ Grad Degree Processor :00', '0 0 * * * ?', new HQGradDegreeStagingProcessor());
    // System.schedule('HQ Grad Degree Processor :15', '0 15 * * * ?', new HQGradDegreeStagingProcessor());
    // System.schedule('HQ Grad Degree Processor :30', '0 30 * * * ?', new HQGradDegreeStagingProcessor());
    // System.schedule('HQ Grad Degree Processor :45', '0 45 * * * ?', new HQGradDegreeStagingProcessor());
}