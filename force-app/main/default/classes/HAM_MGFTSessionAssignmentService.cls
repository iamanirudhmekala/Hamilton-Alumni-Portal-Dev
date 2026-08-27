/**
 * HAM_MGFTSessionAssignmentService
 * ---------------------------------
 * Hourly job that groups un-sessioned MGFT / Portal - MakeAGift review
 * transactions into fixed-size review "sessions" of exactly 25 records
 * each. Older transactions are assigned before newer ones. Any remainder
 * (< 25 records) is left unassigned and picked up again on the next run,
 * combined with whatever new records have come in by then.
 *
 * Confirmed via schema lookup (retrieve_semantic_model against Hamilton
 * Production):
 *   - Session object API name: ucinn_ascendv2__Session__c
 *   - Lookup field on ucinn_ascendv2__Review_Transaction_v2__c that
 *     points to it: ucinn_ascendv2__Session__c ("Unassigned" = null).
 *   - ucinn_ascendv2__Session__c has no field-level-required custom
 *     fields, so no required defaults are strictly needed on insert.
 *     Two optional ones are set below for consistency with how sessions
 *     get labeled elsewhere in Ascend -- adjust or remove if your team's
 *     convention differs:
 *       - ucinn_ascendv2__Source__c = 'Make a Gift' (closest matching
 *         picklist value on the Session object; the RTV2-side picklist
 *         value is 'Portal - MakeAGift', but the Session object's
 *         Source picklist doesn't have that exact value).
 *       - HAM_Status__c = 'In Progress'.
 *
 * REMAINING ASSUMPTIONS (please confirm / adjust before deploying):
 *   1. "Portal - MakeAGift" source + "MGFT" record type filter matches
 *      the same scope used in HAM_MGFTReviewTxnCtrl
 *      (HAM_Data_Source__c = 'Portal - MakeAGift', RecordType.Name = 'MGFT').
 *   2. "Came earlier" = ucinn_ascendv2__Transaction_Date__c ascending,
 *      with CreatedDate ascending as a tiebreaker for same-day transactions.
 *      If "earlier" should instead mean CreatedDate (i.e. when the portal
 *      record was created/loaded, not the gift's transaction date), swap
 *      the ORDER BY below.
 *   3. Query LIMIT of 9,975 (a multiple of 25) is used per run to stay
 *      comfortably under the 50,000-row SOQL limit for a single
 *      transaction. Increase if your hourly volume could ever exceed
 *      that (unlikely for MGFT/portal gift volume, but flagging it).
 */
public with sharing class HAM_MGFTSessionAssignmentService {

    private static final String DATA_SOURCE_VALUE = 'Portal - MakeAGift';
    private static final String RECORD_TYPE_NAME = 'MGFT';
    private static final Integer SESSION_SIZE = 25;
    private static final Integer QUERY_LIMIT = 9975; // multiple of 25, < 50k SOQL row limit

    /**
     * Entry point called by the scheduled class. Idempotent / safe to
     * call more than once in a row — if there are fewer than 25
     * unassigned records, it simply does nothing.
     */
    public static void run() {
        List<ucinn_ascendv2__Review_Transaction_v2__c> unassigned = getUnassignedRecordsOldestFirst();

        Integer fullSessionCount = unassigned.size() / SESSION_SIZE; // integer division = floor
        if (fullSessionCount == 0) {
            // Not enough records yet for even one full session of 25.
            // Leave everything unassigned for the next run.
            return;
        }

        List<ucinn_ascendv2__Session__c> newSessions = buildNewSessions(fullSessionCount);
        insert newSessions;

        List<ucinn_ascendv2__Review_Transaction_v2__c> updates =
            buildAssignmentUpdates(unassigned, newSessions, fullSessionCount);
        update updates;
    }

    // ---------------------------------------------------------------
    // Query
    // ---------------------------------------------------------------

    private static List<ucinn_ascendv2__Review_Transaction_v2__c> getUnassignedRecordsOldestFirst() {
        return [
            SELECT Id
            FROM ucinn_ascendv2__Review_Transaction_v2__c
            WHERE HAM_Data_Source__c = :DATA_SOURCE_VALUE
              AND RecordType.Name = :RECORD_TYPE_NAME
              AND ucinn_ascendv2__Session__c = null
            WITH USER_MODE
            ORDER BY ucinn_ascendv2__Transaction_Date__c ASC, CreatedDate ASC
            LIMIT :QUERY_LIMIT
        ];
    }

    // ---------------------------------------------------------------
    // Session creation
    // ---------------------------------------------------------------

    private static List<ucinn_ascendv2__Session__c> buildNewSessions(Integer count) {
        List<ucinn_ascendv2__Session__c> sessions = new List<ucinn_ascendv2__Session__c>();
        for (Integer i = 0; i < count; i++) {
            sessions.add(new ucinn_ascendv2__Session__c(
                ucinn_ascendv2__Source__c = 'Make a Gift',
                HAM_Status__c = 'In Progress'
            ));
        }
        return sessions;
    }

    // ---------------------------------------------------------------
    // Assignment — first fullSessionCount * 25 records (already oldest
    // first from the query) get split into consecutive blocks of 25,
    // one block per new session, in the same order the sessions were
    // inserted.
    // ---------------------------------------------------------------

    private static List<ucinn_ascendv2__Review_Transaction_v2__c> buildAssignmentUpdates(
        List<ucinn_ascendv2__Review_Transaction_v2__c> unassigned,
        List<ucinn_ascendv2__Session__c> newSessions,
        Integer fullSessionCount
    ) {
        List<ucinn_ascendv2__Review_Transaction_v2__c> updates =
            new List<ucinn_ascendv2__Review_Transaction_v2__c>();

        for (Integer s = 0; s < fullSessionCount; s++) {
            Id sessionId = newSessions[s].Id;
            Integer startIdx = s * SESSION_SIZE;
            Integer endIdxExclusive = startIdx + SESSION_SIZE;

            for (Integer i = startIdx; i < endIdxExclusive; i++) {
                updates.add(new ucinn_ascendv2__Review_Transaction_v2__c(
                    Id = unassigned[i].Id,
                    ucinn_ascendv2__Session__c = sessionId
                ));
            }
        }
        return updates;
    }
}