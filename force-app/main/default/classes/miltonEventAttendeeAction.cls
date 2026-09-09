/**
 * miltonEventAttendeeAction
 * -------------------
 * Invocable Apex action for Agentforce (Alumni Search topic).
 * Given an event name (e.g. "Reunions '26"), finds every Cvent/Blackthorn
 * event whose title matches and returns only the alumni registered as
 * attendees on those events who are also a Connection of the viewer -
 * same connectionsOnly=true scope as HAM_EventsController.getEventAttendees.
 * Reuses the exact same result shape, privacy rules, and
 * miltonAlumniSearchResultsCard rendering as miltonAlumniSearchAction.
 *
 * Output is deliberately the existing miltonAlumniSearchResponse/miltonAlumniResult
 * classes (not a new "event attendee" DTO) - a Custom Lightning Type's renderer
 * component can only declare one sourceType, so miltonAlumniSearchResultsCard can't
 * also be wired to a second, differently-named type. Reusing the response class
 * means this action rides the existing "miltonAlumniSearchResult" Lightning Type
 * and card with zero new/duplicate LWC or type metadata.
 *
 * Does NOT modify miltonAlumniSearchAction, HAM_EventsController, or any
 * other existing class - the shared field/object references (Cvent and
 * Blackthorn event/attendee objects, Service Indicator visibility rules,
 * miltonAlumniConnectionAction.getConnectionFlags) are only read from here.
 */
global with sharing class miltonEventAttendeeAction {

    // Portal IDs of the Service Indicator Value records that gate what's shown on a result -
    // same values/semantics as miltonAlumniSearchAction.
    private static final String DO_NOT_DISPLAY_EMAIL_SVID = 'SIV_VIS_EMAIL';
    private static final String DO_NOT_DISPLAY_CONNECTION_SVID = 'SIV_VIS_CONNECTION';
    private static final String ALUMNI_PRIVACY_SVID = 'SIV_VIS_ALUMNI_PRIVACY';

    // ---------- INPUT ----------
    @JsonAccess(serializable='always' deserializable='always')
    global class EventAttendeeRequest {
        @InvocableVariable(label='Event Name' description='Full or partial event name to search for, e.g. "Reunions \'26"' required=true)
        global String eventName;

        @InvocableVariable(label='Contact Id' description='Contact Id of the currently authenticated user (the chat viewer). Must be bound to the Contact Id of the authenticated session; never accept as free text or infer from conversation.' required=true)
        global Id contactId;
    }

    // ---------- OUTPUT (invocable action output) ----------
    @JsonAccess(serializable='always' deserializable='always')
    global class EventAttendeeOutput {
        @InvocableVariable(label='Event Attendee Search Result')
        global miltonAlumniSearchResponse result;
    }

    @InvocableMethod(
        label='Event Attendee Search'
        description='Searches Cvent/Blackthorn events by name and returns the attendees registered for matching events who are also a connection of the viewer. Requires an event name.'
        category='Alumni'
    )
    global static List<EventAttendeeOutput> searchEventAttendees(List<EventAttendeeRequest> requests) {
        List<EventAttendeeOutput> responses = new List<EventAttendeeOutput>();

        for (EventAttendeeRequest req : requests) {
            responses.add(wrap(buildResponse(req.eventName, req.contactId)));
        }

        return responses;
    }

    private static miltonAlumniSearchResponse buildResponse(String eventName, Id viewerContactId) {
        miltonAlumniSearchResponse resp = new miltonAlumniSearchResponse();
        resp.alumniRecords = new List<miltonAlumniResult>();
        resp.contactId = viewerContactId;

        if (String.isBlank(eventName)) {
            System.debug('[miltonEventAttendeeAction] buildResponse: eventName blank, returning early.');
            resp.isSuccess = false;
            resp.totalCount = 0;
            resp.statusMessage = 'No event name provided. Please provide an event name to search for attendees.';
            return resp;
        }

        String namePattern = '%' + eventName.trim() + '%';
        Boolean isCventsActive = Boolean.valueOf(System.label.Ham_IsCventsActive);
        Boolean isBlackthornActive = Boolean.valueOf(System.label.Ham_IsBlackthornActive);

        // Step 1 - find the event(s) matching the given name, per source.
        Set<Id> cventEventIds = new Set<Id>();
        Set<Id> blackthornEventIds = new Set<Id>();

        if (isCventsActive) {
            try {
                for (CventEvents__Event__c ev : [
                    SELECT Id FROM CventEvents__Event__c
                    WHERE CventEvents__pkg_Title__c LIKE :namePattern
                    WITH SECURITY_ENFORCED
                    LIMIT 200
                ]) {
                    cventEventIds.add(ev.Id);
                }
            } catch (Exception e) {
                System.debug('[miltonEventAttendeeAction] buildResponse Cvent event query threw: ' + e.getMessage());
            }
        }

        if (isBlackthornActive) {
            try {
                for (conference360__Event__c ev : [
                    SELECT Id FROM conference360__Event__c
                    WHERE Name LIKE :namePattern
                    WITH SECURITY_ENFORCED
                    LIMIT 200
                ]) {
                    blackthornEventIds.add(ev.Id);
                }
            } catch (Exception e) {
                System.debug('[miltonEventAttendeeAction] buildResponse Blackthorn event query threw: ' + e.getMessage());
            }
        }

        Integer matchedEventCount = cventEventIds.size() + blackthornEventIds.size();
        if (matchedEventCount == 0) {
            resp.isSuccess = true;
            resp.totalCount = 0;
            resp.statusMessage = 'No event found matching "' + eventName + '".';
            return resp;
        }

        // Step 2 - fetch the related list of attendees for the matched event(s).
        Set<Id> attendeeContactIds = new Set<Id>();

        if (!cventEventIds.isEmpty()) {
            try {
                for (CventEvents__Attendee__c att : [
                    SELECT CventEvents__Contact__c
                    FROM CventEvents__Attendee__c
                    WHERE CventEvents__Event__c IN :cventEventIds
                    AND CventEvents__Contact__c != null
                    WITH SECURITY_ENFORCED
                    LIMIT 2000
                ]) {
                    attendeeContactIds.add(att.CventEvents__Contact__c);
                }
            } catch (Exception e) {
                System.debug('[miltonEventAttendeeAction] buildResponse Cvent attendee query threw: ' + e.getMessage());
            }
        }

        if (!blackthornEventIds.isEmpty()) {
            try {
                for (conference360__Attendee__c att : [
                    SELECT conference360__Contact__c
                    FROM conference360__Attendee__c
                    WHERE conference360__Event__c IN :blackthornEventIds
                    AND conference360__Contact__c != null
                    WITH SECURITY_ENFORCED
                    LIMIT 2000
                ]) {
                    attendeeContactIds.add(att.conference360__Contact__c);
                }
            } catch (Exception e) {
                System.debug('[miltonEventAttendeeAction] buildResponse Blackthorn attendee query threw: ' + e.getMessage());
            }
        }

        // The viewer never appears as their own attendee, and anyone blocked in either
        // direction is excluded - same as HAM_EventsController.getEventAttendees.
        attendeeContactIds.remove(viewerContactId);

        ServiceIndicatorVisibilityHelper visibilityHelper = new ServiceIndicatorVisibilityHelper();
        Set<Id> blockedContactIds = visibilityHelper.getBlockedContactIds(viewerContactId, new List<Id>(attendeeContactIds));
        attendeeContactIds.removeAll(blockedContactIds);

        if (attendeeContactIds.isEmpty()) {
            resp.isSuccess = true;
            resp.totalCount = 0;
            resp.statusMessage = 'Found "' + eventName + '", but no attendees are registered yet.';
            return resp;
        }

        // Connections-only scope: same rule as HAM_EventsController.getEventAttendees'
        // connectionsOnly=true mode - only attendees the viewer is truly Connected to
        // (HAM_Is_Connected__c = true) are shown, not merely bookmarked or request-sent.
        Map<Id, miltonAlumniConnectionAction.ConnectionFlags> flagsByContactId =
            miltonAlumniConnectionAction.getConnectionFlags(viewerContactId, new List<Id>(attendeeContactIds));

        Set<Id> connectionContactIds = new Set<Id>();
        for (Id candidateId : attendeeContactIds) {
            miltonAlumniConnectionAction.ConnectionFlags flags = flagsByContactId.get(candidateId);
            if (flags != null && flags.isConnected) {
                connectionContactIds.add(candidateId);
            }
        }

        if (connectionContactIds.isEmpty()) {
            resp.isSuccess = true;
            resp.totalCount = 0;
            resp.statusMessage = 'No attendees from your connections for "' + eventName + '".';
            return resp;
        }
        attendeeContactIds = connectionContactIds;

        // Same "collapse multiple Degree_Information records per contact, concatenate
        // distinct majorDegree values" pattern as miltonAlumniSearchAction. Attendees with
        // no Degree_Information record at all will not appear, matching that same scope.
        // Only active contacts of an eligible constituent type are shown - an attendee
        // whose ucinn_ascendv2__Contact_Type__c multipicklist has none of these values
        // (e.g. Student, Friend) is excluded even if they are otherwise a connection.
        List<ucinn_ascendv2__Degree_Information__c> records;
        try {
            records = [
                SELECT Id,
                       ucinn_ascendv2__Contact__r.Id,
                       ucinn_ascendv2__Contact__r.Name,
                       ucinn_ascendv2__Contact__r.LastName,
                       ucinn_ascendv2__Contact__r.HAM_Profile_Picture_URL__c,
                       ucinn_ascendv2__Major_Degree_Formula__c,
                       ucinn_ascendv2__Contact__r.HAM_Reunion_Year__c,
                       ucinn_ascendv2__Contact__r.HAM_Is_Active__c,
                       ucinn_ascendv2__Contact__r.ucinn_ascendv2__Is_Deceased__c,
                       ucinn_ascendv2__Contact__r.Email
                FROM ucinn_ascendv2__Degree_Information__c
                WHERE ucinn_ascendv2__Contact__c IN :attendeeContactIds
                AND ucinn_ascendv2__Contact__r.HAM_Is_Active__c = true
                AND ucinn_ascendv2__Contact__r.ucinn_ascendv2__Contact_Type__c INCLUDES
                    ('Hamilton College','Employee','Former Employee','Kirkland Alumnae','Retiree')
                WITH SECURITY_ENFORCED
                LIMIT 2000
            ];
        } catch (Exception e) {
            System.debug('[miltonEventAttendeeAction] buildResponse Degree_Information query threw: ' + e.getMessage());
            resp.isSuccess = false;
            resp.totalCount = 0;
            resp.statusMessage = 'An error occurred while looking up attendee details: ' + e.getMessage();
            return resp;
        }

        List<Id> orderedContactIds = new List<Id>();
        Map<Id, ucinn_ascendv2__Degree_Information__c> representativeRecordByContact = new Map<Id, ucinn_ascendv2__Degree_Information__c>();
        Map<Id, List<String>> degreeValuesByContact = new Map<Id, List<String>>();

        for (ucinn_ascendv2__Degree_Information__c rec : records) {
            if (rec.ucinn_ascendv2__Contact__r == null) {
                continue;
            }
            Id contactId = rec.ucinn_ascendv2__Contact__r.Id;
            if (!representativeRecordByContact.containsKey(contactId)) {
                representativeRecordByContact.put(contactId, rec);
                degreeValuesByContact.put(contactId, new List<String>());
                orderedContactIds.add(contactId);
            }

            String degreeValue = rec.ucinn_ascendv2__Major_Degree_Formula__c;
            if (String.isNotBlank(degreeValue) && !degreeValuesByContact.get(contactId).contains(degreeValue)) {
                degreeValuesByContact.get(contactId).add(degreeValue);
            }
        }

        Set<Id> alumniContactIds = new Set<Id>(orderedContactIds);

        // Alumni who have opted out of directory visibility entirely must not appear at all.
        Set<Id> alumniPrivacyContactIds = visibilityHelper.getContactIdsWithActiveIndicator(
            new List<Id>(alumniContactIds), ALUMNI_PRIVACY_SVID
        );
        if (!alumniPrivacyContactIds.isEmpty()) {
            List<Id> visibleContactIds = new List<Id>();
            for (Id contactId : orderedContactIds) {
                if (!alumniPrivacyContactIds.contains(contactId)) {
                    visibleContactIds.add(contactId);
                }
            }
            orderedContactIds = visibleContactIds;
            alumniContactIds = new Set<Id>(orderedContactIds);
        }

        // flagsByContactId was already computed above (for the connections-only filter) -
        // every contact reaching this point is guaranteed isConnected=true, so it's reused
        // as-is rather than re-querying.
        Set<Id> hideEmailContactIds = visibilityHelper.getContactIdsWithActiveIndicator(
            new List<Id>(alumniContactIds), DO_NOT_DISPLAY_EMAIL_SVID
        );
        Set<Id> hideConnectionContactIds = visibilityHelper.getContactIdsWithActiveIndicator(
            new List<Id>(alumniContactIds), DO_NOT_DISPLAY_CONNECTION_SVID
        );

        // Every remaining contact is a connection (filtered above), so this reduces to
        // last-name alphabetical order - reusing the same Comparable sort as miltonAlumniSearchAction.
        List<AttendeeSortEntry> sortEntries = new List<AttendeeSortEntry>();
        for (Id contactId : orderedContactIds) {
            Boolean isConnected = flagsByContactId.containsKey(contactId) && flagsByContactId.get(contactId).isConnected;
            String lastName = representativeRecordByContact.get(contactId).ucinn_ascendv2__Contact__r.LastName;
            sortEntries.add(new AttendeeSortEntry(contactId, isConnected, lastName));
        }
        sortEntries.sort();

        Integer resultLimit = 50;
        for (AttendeeSortEntry sortEntry : sortEntries) {
            if (resp.alumniRecords.size() >= resultLimit) {
                break;
            }
            Id contactId = sortEntry.contactId;
            ucinn_ascendv2__Degree_Information__c rec = representativeRecordByContact.get(contactId);

            miltonAlumniResult ar = new miltonAlumniResult();
            ar.recordId          = rec.Id;
            ar.contactId         = contactId;
            ar.alumniName        = rec.ucinn_ascendv2__Contact__r.Name;
            ar.profilePictureUrl = rec.ucinn_ascendv2__Contact__r.HAM_Profile_Picture_URL__c;
            ar.classOfYear       = rec.ucinn_ascendv2__Contact__r.HAM_Reunion_Year__c != null
                                        ? String.valueOf(rec.ucinn_ascendv2__Contact__r.HAM_Reunion_Year__c)
                                        : null;

            ar.isActive = rec.ucinn_ascendv2__Contact__r.HAM_Is_Active__c == true;
            ar.isDeceased = rec.ucinn_ascendv2__Contact__r.ucinn_ascendv2__Is_Deceased__c == true;
            ar.connectionPrivacyEnabled = hideConnectionContactIds.contains(contactId);

            ar.email = hideEmailContactIds.contains(contactId)
                ? null
                : rec.ucinn_ascendv2__Contact__r.Email;

            miltonAlumniConnectionAction.ConnectionFlags flags = flagsByContactId.get(contactId);
            if (flags != null) {
                ar.isConnected   = flags.isConnected;
                ar.isBookmarked  = flags.isBookmarked;
                ar.isRequestSent = flags.isRequestSent;
                ar.isSelf        = flags.isSelf;
            }

            ar.majorDegree = String.join(degreeValuesByContact.get(contactId), ', ');

            resp.alumniRecords.add(ar);
        }

        resp.totalCount    = resp.alumniRecords.size();
        resp.isSuccess     = true;
        resp.statusMessage = resp.totalCount + ' attendee(s) found for "' + eventName + '" across '
            + matchedEventCount + ' matching event(s).';
        System.debug('[miltonEventAttendeeAction] buildResponse final: totalCount=' + resp.totalCount
            + ', statusMessage=' + resp.statusMessage);
        return resp;
    }

    private static EventAttendeeOutput wrap(miltonAlumniSearchResponse resp) {
        EventAttendeeOutput output = new EventAttendeeOutput();
        output.result = resp;
        return output;
    }

    /**
     * Sort key for ordering attendees: connected alumni first, then everyone else,
     * each group in last-name alphabetical order. Same logic as
     * miltonAlumniSearchAction.AlumniSortEntry, duplicated here (rather than modifying
     * that class) since it's a private inner class there.
     */
    private class AttendeeSortEntry implements Comparable {
        private Id contactId;
        private Boolean isConnected;
        private String lastNameLower;

        private AttendeeSortEntry(Id contactId, Boolean isConnected, String lastName) {
            this.contactId = contactId;
            this.isConnected = isConnected == true;
            this.lastNameLower = String.isBlank(lastName) ? '' : lastName.toLowerCase();
        }

        public Integer compareTo(Object other) {
            AttendeeSortEntry otherEntry = (AttendeeSortEntry) other;
            if (this.isConnected != otherEntry.isConnected) {
                return this.isConnected ? -1 : 1;
            }
            return this.lastNameLower.compareTo(otherEntry.lastNameLower);
        }
    }

    /**
     * Determines which attendees have an active (latest child record has no End Date)
     * Service Indicator for the given parent Service Indicator Value Portal ID - same
     * logic as miltonAlumniSearchAction.ServiceIndicatorVisibilityHelper, duplicated here
     * (rather than modifying that class) since it's a private inner class there.
     * Declared 'without sharing' for the same reason: the portal/guest viewer has no
     * sharing access to another alumni's own Service Indicator records.
     */
    private without sharing class ServiceIndicatorVisibilityHelper {
        private Set<Id> getContactIdsWithActiveIndicator(List<Id> contactIds, String portalId) {
            Set<Id> activeContactIds = new Set<Id>();
            if (contactIds == null || contactIds.isEmpty()) {
                return activeContactIds;
            }

            Id contactIndicatorRtId = Schema.SObjectType.ucinn_ascendv2__Service_Indicator__c
                .getRecordTypeInfosByName().get(HAM_ConstantsUtil.CONTACT_SERVICE_INDICATOR_RECORD_TYPE).getRecordTypeId();

            Map<Id, ucinn_ascendv2__Service_Indicator__c> latestByContact = new Map<Id, ucinn_ascendv2__Service_Indicator__c>();
            for (ucinn_ascendv2__Service_Indicator__c si : [
                SELECT ucinn_ascendv2__Contact__c, ucinn_ascendv2__End_Date__c
                FROM ucinn_ascendv2__Service_Indicator__c
                WHERE RecordTypeId = :contactIndicatorRtId
                AND ucinn_ascendv2__Contact__c IN :contactIds
                AND ucinn_ascendv2__Service_Indicator_Value__r.HAM_Portal_ID__c = :portalId
                ORDER BY ucinn_ascendv2__Contact__c ASC, CreatedDate DESC
            ]) {
                if (!latestByContact.containsKey(si.ucinn_ascendv2__Contact__c)) {
                    latestByContact.put(si.ucinn_ascendv2__Contact__c, si);
                }
            }

            for (ucinn_ascendv2__Service_Indicator__c latest : latestByContact.values()) {
                if (latest.ucinn_ascendv2__End_Date__c == null) {
                    activeContactIds.add(latest.ucinn_ascendv2__Contact__c);
                }
            }
            return activeContactIds;
        }

        /**
         * Contacts blocked in either direction relative to the viewer - same rule
         * HAM_EventsController.getEventAttendees applies before showing an attendee.
         * A blocked HAM_Connection__c row has HAM_Is_Blocked__c = true and no other
         * flags set, so it must be looked up separately from any bookmark/connected query.
         */
        private Set<Id> getBlockedContactIds(Id viewerContactId, List<Id> candidateContactIds) {
            Set<Id> blockedContactIds = new Set<Id>();
            if (viewerContactId == null || candidateContactIds == null || candidateContactIds.isEmpty()) {
                return blockedContactIds;
            }

            for (HAM_Connection__c conn : [
                SELECT HAM_Portal_User__c, HAM_Linked_Constituent__c
                FROM HAM_Connection__c
                WHERE HAM_Is_Blocked__c = true
                AND ((HAM_Portal_User__c = :viewerContactId AND HAM_Linked_Constituent__c IN :candidateContactIds)
                     OR (HAM_Linked_Constituent__c = :viewerContactId AND HAM_Portal_User__c IN :candidateContactIds))
            ]) {
                Id otherId = conn.HAM_Portal_User__c == viewerContactId
                    ? conn.HAM_Linked_Constituent__c
                    : conn.HAM_Portal_User__c;
                if (otherId != null) {
                    blockedContactIds.add(otherId);
                }
            }
            return blockedContactIds;
        }
    }
}