/**
 * HAM_MigrationUtil
 * ─────────────────────────────────────────────────────────────────────────────
 * Shared utility class for the Blackthorn → Cvent migration pipeline.
 * Used by all batch classes — do NOT modify without testing all dependent batches.
 *
 * Objects referenced:
 *   Source : conference360__Event__c, conference360__Attendee__c (and children)
 *   Target : CventEvents__Event__c, CventEvents__Attendee__c, HAM_* custom objects
 *   Log    : HAM_Migration_Log__c
 *
 * Change Log:
 *   v1.0  2026-04-09  Initial deployment
 *   v1.1  2026-04-14  PMD static analysis fixes
 *   v1.2  2026-04-16  Populate HAM_Log_Level__c, HAM_BT_Event__c, HAM_Cvent_Event__c on error logs
 * @description Shared utility methods for the HAM Blackthorn-to-Cvent migration pipeline.
 */
public without sharing class HAM_MigrationUtil {

    // ─── UUID v4 ──────────────────────────────────────────────────────────────
    /**
     * @description Generates a RFC 4122-compliant UUID v4 string (36 chars).
     * Used for CventEvents__pkg_EventStub__c and CventEvents__AttendeeStub__c.
     * @return String 36-character UUID
     */
    public static String generateUUID() {
        Blob   b   = Crypto.generateAesKey(128);
        String hex = EncodingUtil.convertToHex(b);
        return hex.substring(0, 8)  + '-' +
               hex.substring(8, 12) + '-' +
               '4' + hex.substring(13, 16) + '-' +
               hex.substring(16, 20) + '-' +
               hex.substring(20, 32);
    }

    // ─── Event Code (18-char alphanumeric) ────────────────────────────────────
    /**
     * @description Generates an 18-character alphanumeric code for CventEvents__pkg_Code__c.
     * @return String 18-character uppercase alphanumeric code
     */
    public static String generateCode() {
        Blob   b   = Crypto.generateAesKey(128);
        String hex = EncodingUtil.convertToHex(b).toUpperCase();
        return hex.substring(0, 18);
    }

    // ─── Safe Truncate ────────────────────────────────────────────────────────
    /**
     * @description Truncates a string to maxLen characters without throwing.
     * @param val    String to truncate
     * @param maxLen Maximum allowed length
     * @return String truncated value or null
     */
    public static String truncate(String val, Integer maxLen) {
        if (val == null)            { return null; }
        if (val.length() <= maxLen) { return val; }
        return val.substring(0, maxLen);
    }

    // ─── Event Status Mapping ─────────────────────────────────────────────────
    /**
     * @description Maps Blackthorn conference360__Status__c → CventEvents__pkg_EventStatus__c
     * @param btStatus Blackthorn event status value
     * @return String Cvent event status — never null
     */
    public static String mapEventStatus(String btStatus) {
        if ('Completed'.equals(btStatus)) { return 'Completed'; }
        if ('Cancelled'.equals(btStatus)) { return 'Cancelled'; }
        return 'Upcoming';
    }

    // ─── Attendee Status Mapping ──────────────────────────────────────────────
    /**
     * @description Maps Blackthorn conference360__Registration_Status__c
     *   → CventEvents__Status__c (REQUIRED field — never returns null).
     * @param btStatus Blackthorn attendee registration status
     * @return String Cvent attendee status — never null
     */
    public static String mapAttendeeStatus(String btStatus) {
        if (btStatus == null)                        { return 'No Response'; }
        if ('Registered'.equals(btStatus))           { return 'Accepted'; }
        if ('Invited'.equals(btStatus))              { return 'Invitation Sent'; }
        if ('Canceled'.equals(btStatus))             { return 'Cancelled'; }
        if ('Declined'.equals(btStatus))             { return 'Declined'; }
        if ('Waitlisted - Pending'.equals(btStatus)) { return 'Waitlisted'; }
        if ('To Invite'.equals(btStatus))            { return 'Invitation Not Sent'; }
        if ('Pending'.equals(btStatus))              { return 'Registration Pending'; }
        return 'No Response';
    }

    // ─── Capacity Mapping ─────────────────────────────────────────────────────
    /**
     * @description Converts BT Attendee_Limit__c to Cvent Capacity.
     * Cvent uses 0 to mean unlimited. BT uses very large numbers for unlimited.
     * @param btLimit Blackthorn attendee limit value
     * @return Integer Cvent capacity (0 = unlimited)
     */
    public static Integer mapCapacity(Decimal btLimit) {
        if (btLimit == null || btLimit >= 999999) { return 0; }
        return btLimit.intValue();
    }

    // ─── Error Logger ─────────────────────────────────────────────────────────
    /**
     * @description Writes upsert failures to HAM_Migration_Log__c.
     * Populates HAM_Log_Level__c (Error), and attempts to extract BT/Cvent event
     * lookups from the record dynamically (silently skipped if field not present).
     * @param results  List of UpsertResult from Database.upsert()
     * @param records  The SObject list passed to Database.upsert() (parallel index)
     * @param objType  Label stored in HAM_Object_Type__c
     */
    public static void logErrors(
        List<Database.UpsertResult> results,
        List<SObject>               records,
        String                      objType
    ) {
        List<HAM_Migration_Log__c> logs = new List<HAM_Migration_Log__c>();
        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess()) {
                String btId = null;
                try { btId = (String) records[i].get('HAM_BT_Source_Id__c'); } catch (SObjectException e) { System.debug(LoggingLevel.WARN, 'Could not retrieve source Id: ' + e.getMessage()); }
                if (btId == null) {
                    try { btId = (String) records[i].get('HAM_BT_Attendee_Id__c'); } catch (SObjectException e) { System.debug(LoggingLevel.WARN, 'Could not retrieve source Id: ' + e.getMessage()); }
                }
                if (btId == null) {
                    try { btId = (String) records[i].get('HAM_BT_Event_Id__c'); } catch (SObjectException e) { System.debug(LoggingLevel.WARN, 'Could not retrieve source Id: ' + e.getMessage()); }
                }

                Id btEventId    = null;
                Id cventEventId = null;
                try { btEventId    = (Id) records[i].get('conference360__Event__c'); } catch (SObjectException e) { System.debug(LoggingLevel.WARN, 'BT event field not on record: ' + e.getMessage()); }
                try { cventEventId = (Id) records[i].get('CventEvents_Event__c');    } catch (SObjectException e) { System.debug(LoggingLevel.WARN, 'Cvent event field not on record: ' + e.getMessage()); }

                String msg = results[i].getErrors()[0].getMessage();
                logs.add(new HAM_Migration_Log__c(
                    HAM_Object_Type__c    = objType,
                    HAM_Record_Id__c      = btId,
                    HAM_Error_Message__c  = msg,
                    HAM_Migration_Date__c = System.now(),
                    HAM_Log_Level__c      = 'Error',
                    HAM_BT_Event__c       = btEventId,
                    HAM_Cvent_Event__c    = cventEventId
                ));
            }
        }
        if (!logs.isEmpty()) {
            if (HAM_Migration_Log__c.SObjectType.getDescribe().isCreateable()) {
                insert logs;
            }
        }
    }

    // ─── Summary Logger ───────────────────────────────────────────────────────
    /**
     * @description Writes a QC Summary log entry at the end of a batch run.
     * @param objType    Label stored in HAM_Object_Type__c
     * @param btCount    Total BT source records processed
     * @param cventCount Total Cvent target records successfully created/updated
     */
    public static void logSummary(String objType, Integer btCount, Integer cventCount) {
        if (!HAM_Migration_Log__c.SObjectType.getDescribe().isCreateable()) { return; }
        insert new HAM_Migration_Log__c(
            HAM_Object_Type__c    = objType,
            HAM_Migration_Date__c = System.now(),
            HAM_Log_Level__c      = 'QC Summary',
            HAM_BT_Count__c       = btCount,
            HAM_Cvent_Count__c    = cventCount
        );
    }
}