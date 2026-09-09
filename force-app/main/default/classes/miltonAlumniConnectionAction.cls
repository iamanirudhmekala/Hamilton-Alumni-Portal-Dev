/**
 * miltonAlumniConnectionAction
 * -------------------
 * Bookmark/connection actions for miltonAlumniSearchResultsCard
 * (Agentforce / Milton chat alumni search card).
 *
 * Does NOT duplicate any connection logic — every write delegates straight
 * to the existing, unmodified HAM_AlumniConnectionService.handleConnectionRequest.
 * This class exists only so the Guest User profile backing the embedded
 * chat site needs Apex Class Access to just this one narrow method, not the
 * full shared HAM_AlumniConnectionService (which also handles Favorite,
 * Block, Accept, Reject, and the internal member-portal directory) —
 * mirrors why miltonVolunteerOpportunityInterestAction was split out from
 * HAM_VolunteerOpportunityController.
 *
 * getConnectionFlags() runs the read-side lookups this class needs to run
 * without sharing (Guest/portal users don't have sharing access to
 * Ham_Connection__c rows between two other contacts). It's called both
 * internally by miltonAlumniSearchAction (a with sharing class, to enrich
 * search results) and directly from the LWC (to reconcile a locally-cached
 * button state against current backend truth after a chat message is
 * replayed from a stale/frozen snapshot on browser refresh).
 */
public without sharing class miltonAlumniConnectionAction {

    public class ConnectionFlags {
        @AuraEnabled public Boolean isConnected = false;
        @AuraEnabled public Boolean isBookmarked = false;
        @AuraEnabled public Boolean isRequestSent = false;
        @AuraEnabled public Boolean isSelf = false;
    }

    private static final Set<String> ALLOWED_FUNCTION_TYPES = new Set<String>{
        HAM_ConstantsUtil.SEND_REQUEST,
        HAM_ConstantsUtil.CANCEL_REQUEST,
        HAM_ConstantsUtil.REMOVE_CONNECTION,
        HAM_ConstantsUtil.BOOKMARK,
        HAM_ConstantsUtil.REMOVE_BOOKMARK
    };

    /**
     * Looks up connection/bookmark status for a set of alumni Contact Ids,
     * relative to the given viewer Contact Id. Always returns one entry per
     * input alumniContactId. Active status is not part of this — it comes
     * straight from Contact.HAM_Is_Active__c on the caller's own query
     * (see miltonAlumniSearchAction), since that data is already in hand
     * there and doesn't need a second query/loop here.
     */
    @AuraEnabled(cacheable=true)
    public static Map<Id, ConnectionFlags> getConnectionFlags(Id viewerContactId, List<Id> alumniContactIds) {
        Set<Id> alumniContactIdSet = new Set<Id>(alumniContactIds);
        Map<Id, ConnectionFlags> flagsByContactId = new Map<Id, ConnectionFlags>();
        for (Id alumniId : alumniContactIdSet) {
            flagsByContactId.put(alumniId, new ConnectionFlags());
        }

        if (viewerContactId == null || alumniContactIdSet.isEmpty()) {
            return flagsByContactId;
        }

        if (flagsByContactId.containsKey(viewerContactId)) {
            flagsByContactId.get(viewerContactId).isSelf = true;
        }

        for (Ham_Connection__c conn : [
            SELECT HAM_Portal_User__c, HAM_Linked_Constituent__c, HAM_Connection_Status__c, HAM_Is_bookmarked__c
            FROM Ham_Connection__c
            WHERE (HAM_Portal_User__c = :viewerContactId AND HAM_Linked_Constituent__c IN :alumniContactIds)
            OR (HAM_Portal_User__c IN :alumniContactIds AND HAM_Linked_Constituent__c = :viewerContactId)
        ]) {
            Id otherId = conn.HAM_Portal_User__c == viewerContactId ? conn.HAM_Linked_Constituent__c : conn.HAM_Portal_User__c;
            ConnectionFlags flags = flagsByContactId.get(otherId);
            if (flags == null) {
                continue;
            }

            if (conn.HAM_Connection_Status__c == HAM_ConstantsUtil.CONNECTED) {
                flags.isConnected = true;
            }
            if (conn.HAM_Portal_User__c == viewerContactId) {
                if (conn.HAM_Connection_Status__c == HAM_ConstantsUtil.REQUEST_SENT) {
                    flags.isRequestSent = true;
                }
                if (conn.HAM_Is_bookmarked__c == true) {
                    flags.isBookmarked = true;
                }
            }
        }

        return flagsByContactId;
    }

    @AuraEnabled
    public static String updateConnection(String portalId, String linkedConstituentId, String functionType) {
        if (!ALLOWED_FUNCTION_TYPES.contains(functionType)) {
            return 'Error';
        }
        return HAM_AlumniConnectionService.handleConnectionRequest(portalId, linkedConstituentId, null, functionType);
    }

    /**
     * Passthrough to HAM_AlumniConnectionService.checkUserStatus — same
     * pre-check ham_alumniListDisplayCmp/ham_alumniGridDisplayCmp run before
     * a Send Request click, so this card never calls updateConnection for a
     * contact with no linked User record at all (that would otherwise hit
     * handleSendRequest's unguarded constituentUser[0] on an empty list).
     */
    @AuraEnabled(cacheable=true)
    public static String checkUserStatus(String linkedConstituentId) {
        return HAM_AlumniConnectionService.checkUserStatus(linkedConstituentId);
    }
}