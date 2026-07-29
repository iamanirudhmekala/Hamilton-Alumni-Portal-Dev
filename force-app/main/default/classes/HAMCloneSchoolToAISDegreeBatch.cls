/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : HAMCloneSchoolToAISDegreeBatch
 * Author          : <YourName>
 * Created Date    : Jul 16, 2026
 * Last Modified By: <YourName>
 * Last Modified On: Jul 16, 2026
 * Description     : One-time/rerunnable batch that clones every
 *                   ucinn_ascendv2__Degree_Information__c record of record type
 *                   "School Degree Information" (School_Degree_Information) into a
 *                   new record of record type "Hamilton AIS Degree Information"
 *                   (Hamilton_AIS_Degree_Information), full field-for-field clone
 *                   (all creatable fields, dynamically described - not a hardcoded
 *                   field list). After a source record is successfully cloned, the
 *                   ORIGINAL record is flagged HAMRolledOver__c = true so the batch
 *                   is safely rerunnable (only un-rolled-over records are picked up
 *                   on subsequent runs) and so existing reports/list views can
 *                   distinguish already-migrated rows.
 *
 *                   NOTE: Hamilton_AIS_Degree_Information record type and the
 *                   HAMRolledOver__c checkbox currently exist in the lower
 *                   (FullQA) sandbox only, per Ameya (Jul 16, 2026). This batch
 *                   will throw a clear AsyncException out of start() if either
 *                   is missing in whatever org it's deployed to - confirm both
 *                   exist before scheduling/running in a new environment.
 *  
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Jul 16, 2026  │ <YourName>   │ Initial version
 *  Jul 16, 2026  │ <YourName>   │ Renamed inner exception class to drop the
 *                │              │ underscore, matching the outer class rename
 *                │              │ (HAM_CloneSchoolToAISDegreeBatchException ->
 *                │              │ HAMCloneSchoolToAISDegreeBatchException).
 *  Jul 20, 2026  │ Ameya        │ Fixed start() incorrectly throwing "field not
 *                │              │ found (or is not creatable)" for HAMRolledOver__c
 *                │              │ every time, regardless of FLS/case. Root cause:
 *                │              │ the check tested membership in the "cloneable
 *                │              │ fields" list, but HAMRolledOver__c is deliberately
 *                │              │ excluded from that list (EXCLUDE_FROM_CLONE) since
 *                │              │ it's set explicitly rather than copied verbatim -
 *                │              │ so the check could never pass. Replaced with a
 *                │              │ direct describe lookup on the field itself,
 *                │              │ independent of EXCLUDE_FROM_CLONE.
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */

public with sharing class HAMCloneSchoolToAISDegreeBatch implements Database.Batchable<SObject>, Database.Stateful  {

	private static final String OBJ_API_NAME = 'ucinn_ascendv2__Degree_Information__c';
    private static final String SOURCE_RT_DEV_NAME = 'School_Degree_Information';
    private static final String TARGET_RT_DEV_NAME = 'Hamilton_AIS_Degree_Information';
    private static final String ROLLED_OVER_FIELD = 'HAMRolledOver__c';
 
    // Fields that must never be copied onto the clone even though they're
    // technically creatable (identity / record-type fields we set explicitly).
    private static final Set<String> EXCLUDE_FROM_CLONE = new Set<String>{
        'id',
        'recordtypeid',
        'hamrolledover__c'
    };
 
    private Id sourceRecordTypeId;
    private Id targetRecordTypeId;
    private List<String> cloneableFieldApiNames;
 
    // ---- Stateful counters for the finish() summary email ----
    private Integer totalSourceRecords = 0;
    private Integer totalCloned = 0;
    private Integer totalCloneErrors = 0;
    private Integer totalFlagErrors = 0;
    private List<String> errorMessages = new List<String>();
 
    // -------------------------------------------------------------------
    // START
    // -------------------------------------------------------------------
    public Database.QueryLocator start(Database.BatchableContext bc) {
        Map<String, Schema.RecordTypeInfo> rtByDevName =
            Schema.SObjectType.ucinn_ascendv2__Degree_Information__c.getRecordTypeInfosByDeveloperName();
 
        if (!rtByDevName.containsKey(SOURCE_RT_DEV_NAME)) {
            throw new HAMCloneSchoolToAISDegreeBatchException(
                'Record Type "' + SOURCE_RT_DEV_NAME + '" was not found on ' + OBJ_API_NAME + '.'
            );
        }
        if (!rtByDevName.containsKey(TARGET_RT_DEV_NAME)) {
            throw new HAMCloneSchoolToAISDegreeBatchException(
                'Record Type "' + TARGET_RT_DEV_NAME + '" was not found on ' + OBJ_API_NAME
                + '. Confirm it has been deployed/created in this org before running this batch.'
            );
        }
 
        sourceRecordTypeId = rtByDevName.get(SOURCE_RT_DEV_NAME).getRecordTypeId();
        targetRecordTypeId = rtByDevName.get(TARGET_RT_DEV_NAME).getRecordTypeId();
 
        cloneableFieldApiNames = getCloneableFieldApiNames();

        // Checked independently of getCloneableFieldApiNames()/EXCLUDE_FROM_CLONE,
        // since HAMRolledOver__c is deliberately excluded from that "copy these
        // values verbatim" list (we set it explicitly on both original and clone)
        // - so it will NEVER appear in that list, by design, regardless of FLS.
        Schema.SObjectField rolledOverField = Schema.SObjectType.ucinn_ascendv2__Degree_Information__c
            .fields.getMap().get(ROLLED_OVER_FIELD.toLowerCase());
        if (rolledOverField == null) {
            throw new HAMCloneSchoolToAISDegreeBatchException(
                'Field "' + ROLLED_OVER_FIELD + '" was not found on ' + OBJ_API_NAME
                + '. Confirm it has been deployed/created in this org before running this batch.'
            );
        }
        Schema.DescribeFieldResult rolledOverFieldDescribe = rolledOverField.getDescribe();
        if (!rolledOverFieldDescribe.isCreateable() || !rolledOverFieldDescribe.isUpdateable()) {
            throw new HAMCloneSchoolToAISDegreeBatchException(
                'Field "' + ROLLED_OVER_FIELD + '" exists on ' + OBJ_API_NAME
                + ' but the running user does not have Create/Edit field-level security on it.'
            );
        }
 
        String query = 'SELECT ' + String.join(cloneableFieldApiNames, ', ')
            + ' FROM ' + OBJ_API_NAME
            + ' WHERE RecordTypeId = :sourceRecordTypeId'
            + ' AND (' + ROLLED_OVER_FIELD + ' = false OR ' + ROLLED_OVER_FIELD + ' = null)';
 
        return Database.getQueryLocator(query);
    }
 
    // -------------------------------------------------------------------
    // EXECUTE
    // -------------------------------------------------------------------
    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        totalSourceRecords += scope.size();
 
        List<ucinn_ascendv2__Degree_Information__c> originals =
            (List<ucinn_ascendv2__Degree_Information__c>) scope;
 
        List<ucinn_ascendv2__Degree_Information__c> clones = new List<ucinn_ascendv2__Degree_Information__c>();
        for (ucinn_ascendv2__Degree_Information__c src : originals) {
            ucinn_ascendv2__Degree_Information__c cloneRec = src.clone(false, false, false, false);
            cloneRec.RecordTypeId = targetRecordTypeId;
            cloneRec.put(ROLLED_OVER_FIELD, false);
            clones.add(cloneRec);
        }
 
        List<Database.SaveResult> insertResults = Database.insert(clones, false);
 
        List<ucinn_ascendv2__Degree_Information__c> toFlag = new List<ucinn_ascendv2__Degree_Information__c>();
        for (Integer i = 0; i < insertResults.size(); i++) {
            Database.SaveResult sr = insertResults[i];
            if (sr.isSuccess()) {
                totalCloned++;
                toFlag.add(new ucinn_ascendv2__Degree_Information__c(
                    Id = originals[i].Id,
                    HAMRolledOver__c = true
                ));
            } else {
                totalCloneErrors++;
                for (Database.Error err : sr.getErrors()) {
                    errorMessages.add('Clone failed for source record ' + originals[i].Id + ': ' + err.getMessage());
                }
            }
        }
 
        if (!toFlag.isEmpty()) {
            List<Database.SaveResult> updateResults = Database.update(toFlag, false);
            for (Integer i = 0; i < updateResults.size(); i++) {
                if (!updateResults[i].isSuccess()) {
                    totalFlagErrors++;
                    for (Database.Error err : updateResults[i].getErrors()) {
                        errorMessages.add('Rolled-over flag update failed for source record '
                            + toFlag[i].Id + ': ' + err.getMessage());
                    }
                }
            }
        }
    }
 
    // -------------------------------------------------------------------
    // FINISH
    // -------------------------------------------------------------------
    public void finish(Database.BatchableContext bc) {
        AsyncApexJob job = [
            SELECT Id, Status, NumberOfErrors, JobItemsProcessed, TotalJobItems, CreatedBy.Email
            FROM AsyncApexJob
            WHERE Id = :bc.getJobId()
        ];
 
        String body = 'HAMCloneSchoolToAISDegreeBatch finished with status: ' + job.Status + '\n\n'
            + 'Source records evaluated : ' + totalSourceRecords + '\n'
            + 'Successfully cloned      : ' + totalCloned + '\n'
            + 'Clone failures           : ' + totalCloneErrors + '\n'
            + 'Rolled-over flag failures: ' + totalFlagErrors + '\n';
 
        if (!errorMessages.isEmpty()) {
            Integer sampleSize = Math.min(errorMessages.size(), 25);
            body += '\nFirst ' + sampleSize + ' error(s):\n';
            for (Integer i = 0; i < sampleSize; i++) {
                body += '- ' + errorMessages[i] + '\n';
            }
        }
 
        if (job.CreatedBy != null && String.isNotBlank(job.CreatedBy.Email)) {
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ job.CreatedBy.Email });
            mail.setSubject('Degree Information clone batch (School -> Hamilton AIS) - ' + job.Status);
            mail.setPlainTextBody(body);
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
        }
 
        System.debug(LoggingLevel.INFO, body);
    }
 
    // -------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------
 
    /**
     * Dynamically builds the list of field API names on
     * ucinn_ascendv2__Degree_Information__c that are safe to SELECT and copy
     * onto the clone: every creatable field (this naturally excludes formula
     * fields and system audit fields, which are not creatable) minus Id,
     * RecordTypeId, and the rolled-over flag itself, which are set explicitly.
     */
    private List<String> getCloneableFieldApiNames() {
        Map<String, Schema.SObjectField> fieldMap =
            Schema.SObjectType.ucinn_ascendv2__Degree_Information__c.fields.getMap();
 
        List<String> fieldNames = new List<String>();
        for (String apiName : fieldMap.keySet()) {
            Schema.DescribeFieldResult fd = fieldMap.get(apiName).getDescribe();
            if (fd.isCreateable() && !EXCLUDE_FROM_CLONE.contains(apiName.toLowerCase())) {
                fieldNames.add(fd.getName());
            }
        }
        // Id is always needed on the query for the finish/flag-back step.
        fieldNames.add('Id');
        return fieldNames;
    }
 
    public class HAMCloneSchoolToAISDegreeBatchException extends Exception {}

}