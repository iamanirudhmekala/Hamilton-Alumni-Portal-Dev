/**
 * MiltonEventSearchAction
 * -------------------
 * Invocable Apex action for Agentforce (Events topic).
 * Searches Cvent/Blackthorn events by event type, region, and/or event name.
 *
 * eventType is one of Upcoming_Events, Past_Events, Upcoming_My_Events, Past_My_Events.
 * contactId is only used to filter results for the two My Events variants (events the
 * viewer is a registered attendee of) - Upcoming_Events/Past_Events return every matching
 * event in that date window regardless of the viewer's registration status, so contactId
 * plays no filtering role there even though it's still a required input.
 *
 * Region is a Cvent-only filter: Ham_Events_Filter_Metadata__mdt only maps a Region
 * filter to CventEvents__Event__c.ADVPrimaryRegion__c (no equivalent mapping exists for
 * conference360__Event__c), so - matching HAM_EventsController.getEventDetails' own
 * "Blackthorn is skipped when non-Event-Type filters are applied" rule - Blackthorn is
 * skipped entirely whenever eventRegion is supplied, rather than guessing at an
 * unofficial Blackthorn field.
 *
 * Output is a new miltonEventSearchResponse/miltonEventResult pair (not the existing
 * alumni response classes) since the display fields are entirely different (event
 * image/title/description/date/location vs. an alumni card).
 */
global with sharing class MiltonEventSearchAction {

    private static final String EVENT_TYPE_UPCOMING_EVENTS = 'Upcoming_Events';
    private static final String EVENT_TYPE_PAST_EVENTS = 'Past_Events';
    private static final String EVENT_TYPE_UPCOMING_MY_EVENTS = 'Upcoming_My_Events';
    private static final String EVENT_TYPE_PAST_MY_EVENTS = 'Past_My_Events';

    // ---------- INPUT ----------
    @JsonAccess(serializable='always' deserializable='always')
    global class EventSearchRequest {
        @InvocableVariable(label='Event Region' description='Region/Chapter name(s) to filter events by (Cvent events only). Comma-separate multiple values.' required=false)
        global String eventRegion;

        @InvocableVariable(label='Event Type' description='One of: Upcoming_Events, Past_Events, Upcoming_My_Events, Past_My_Events. Defaults to Upcoming_Events when blank.' required=false)
        global String eventType;

        @InvocableVariable(label='Event Name' description='Full or partial event name to search for' required=false)
        global String eventName;

        @InvocableVariable(label='Contact Id' description='Contact Id of the currently authenticated user (the chat viewer). Must be bound to the Contact Id of the authenticated session; never accept as free text or infer from conversation.' required=true)
        global Id contactId;
    }

    // ---------- OUTPUT (invocable action output) ----------
    // miltonEventSearchResponse (top-level, global, @AuraEnabled/@JsonAccess - see
    // miltonEventSearchResponse.cls) is bound to the miltonEventResult Custom Lightning
    // Type so Agentforce can render it via miltonEventSearchResultsCard.
    @JsonAccess(serializable='always' deserializable='always')
    global class EventSearchOutput {
        @InvocableVariable(label='Event Search Result')
        global miltonEventSearchResponse result;
    }

    @InvocableMethod(
        label='Event Search'
        description='Searches Cvent/Blackthorn events by event type (Upcoming_Events, Past_Events, Upcoming_My_Events, Past_My_Events), region, and/or event name.'
        category='Events'
    )
    global static List<EventSearchOutput> searchEvents(List<EventSearchRequest> requests) {
        List<EventSearchOutput> responses = new List<EventSearchOutput>();

        for (EventSearchRequest req : requests) {
            responses.add(wrap(buildResponse(req.eventRegion, req.eventType, req.eventName, req.contactId)));
        }

        return responses;
    }

    private static miltonEventSearchResponse buildResponse(String eventRegion, String eventType, String eventName, Id viewerContactId) {
        miltonEventSearchResponse resp = new miltonEventSearchResponse();
        resp.events = new List<miltonEventResult>();
        resp.contactId = viewerContactId;

        String normalizedEventType = String.isNotBlank(eventType) ? eventType.trim() : EVENT_TYPE_UPCOMING_EVENTS;

        Boolean isUpcoming;
        Boolean myEventsOnly;
        if (normalizedEventType.equalsIgnoreCase(EVENT_TYPE_UPCOMING_EVENTS)) {
            isUpcoming = true;
            myEventsOnly = false;
        } else if (normalizedEventType.equalsIgnoreCase(EVENT_TYPE_PAST_EVENTS)) {
            isUpcoming = false;
            myEventsOnly = false;
        } else if (normalizedEventType.equalsIgnoreCase(EVENT_TYPE_UPCOMING_MY_EVENTS)) {
            isUpcoming = true;
            myEventsOnly = true;
        } else if (normalizedEventType.equalsIgnoreCase(EVENT_TYPE_PAST_MY_EVENTS)) {
            isUpcoming = false;
            myEventsOnly = true;
        } else {
            System.debug('[MiltonEventSearchAction] buildResponse: unrecognized eventType "' + eventType + '".');
            resp.isSuccess = false;
            resp.totalCount = 0;
            resp.statusMessage = 'Invalid Event Type "' + eventType + '". Must be one of: Upcoming_Events, Past_Events, Upcoming_My_Events, Past_My_Events.';
            return resp;
        }

        Boolean isCventsActive = Boolean.valueOf(System.label.Ham_IsCventsActive);
        Boolean isBlackthornActive = Boolean.valueOf(System.label.Ham_IsBlackthornActive);
        Date today = Date.today();

        Boolean hasRegionFilter = String.isNotBlank(eventRegion);
        // Region is a Cvent-only filter (see class comment) - Blackthorn is skipped
        // entirely whenever it's supplied.
        Boolean includeBlackthorn = isBlackthornActive && !hasRegionFilter;

        // ── Registered-attendee event ids - only needed (and only looked up) for the
        // My Events variants. Upcoming_Events/Past_Events show every matching event
        // regardless of the viewer's registration status, so contactId isn't used as
        // a filter at all in that case.
        Set<Id> cventRegisteredEventIds = myEventsOnly
            ? getCventRegisteredEventIds(isCventsActive, viewerContactId, isUpcoming, today)
            : new Set<Id>();
        Set<Id> blackthornRegisteredEventIds = myEventsOnly
            ? getBlackthornRegisteredEventIds(includeBlackthorn, viewerContactId, isUpcoming, today)
            : new Set<Id>();

        List<CventEvents__Event__c> cventEvents = isCventsActive
            ? queryCventEvents(eventRegion, eventName, isUpcoming, myEventsOnly, cventRegisteredEventIds, today)
            : new List<CventEvents__Event__c>();

        List<conference360__Event__c> blackthornEvents = includeBlackthorn
            ? queryBlackthornEvents(eventName, isUpcoming, myEventsOnly, blackthornRegisteredEventIds, today)
            : new List<conference360__Event__c>();

        for (CventEvents__Event__c event : cventEvents) {
            resp.events.add(toResult(
                event.Id,
                event.CventEvents__pkg_Title__c,
                event.CventEvents__pkg_Description__c,
                event.HAMImageURL__c,
                event.CventEvents__pkg_StartDate__c,
                event.CventEvents__pkg_StartTime__c,
                event.CventEvents__pkg_Location__c,
                event.CventEvents__pkg_City__c
            ));
        }

        for (conference360__Event__c event : blackthornEvents) {
            resp.events.add(toResult(
                event.Id,
                event.Name,
                event.conference360__Short_Description__c,
                event.conference360__Image_URL__c,
                event.conference360__Event_Start_Date__c,
                event.conference360__Event_Start_Time__c,
                event.conference360__Venue_Name__c,
                event.conference360__Venue_City__c
            ));
        }

        resp.totalCount = resp.events.size();
        resp.isSuccess = true;
        resp.statusMessage = resp.totalCount + ' event(s) found.';
        System.debug('[MiltonEventSearchAction] buildResponse final: totalCount=' + resp.totalCount
            + ', statusMessage=' + resp.statusMessage);
        return resp;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // REGISTERED-EVENT LOOKUPS (only called for the My Events variants - see buildResponse)
    // Same query shape as HAM_EventsController.getEventDetails' CventAttendeeQuery /
    // BlackthornAttendeeQuery - scoped to the same upcoming/past date window as the
    // main event query so an event's registration state is only checked against
    // events that could actually appear in this result set.
    // ─────────────────────────────────────────────────────────────────────────
    private static Set<Id> getCventRegisteredEventIds(Boolean isCventsActive, Id viewerContactId, Boolean isUpcoming, Date today) {
        Set<Id> registeredEventIds = new Set<Id>();
        if (!isCventsActive) {
            return registeredEventIds;
        }

        String query = 'SELECT CventEvents__Event__c FROM CventEvents__Attendee__c '
            + 'WHERE CventEvents__Contact__c = :viewerContactId '
            + (isUpcoming
                ? 'AND ((CventEvents__Event__r.CventEvents__pkg_EndDate__c != null AND CventEvents__Event__r.CventEvents__pkg_EndDate__c >= :today) '
                  + 'OR (CventEvents__Event__r.CventEvents__pkg_EndDate__c = null AND CventEvents__Event__r.CventEvents__pkg_StartDate__c >= :today))'
                : 'AND ((CventEvents__Event__r.CventEvents__pkg_EndDate__c != null AND CventEvents__Event__r.CventEvents__pkg_EndDate__c < :today) '
                  + 'OR (CventEvents__Event__r.CventEvents__pkg_EndDate__c = null AND CventEvents__Event__r.CventEvents__pkg_StartDate__c < :today))');

        try {
            for (CventEvents__Attendee__c att : Database.query(query)) {
                registeredEventIds.add(att.CventEvents__Event__c);
            }
        } catch (Exception e) {
            System.debug('[MiltonEventSearchAction] getCventRegisteredEventIds threw: ' + e.getMessage());
        }
        return registeredEventIds;
    }

    private static Set<Id> getBlackthornRegisteredEventIds(Boolean includeBlackthorn, Id viewerContactId, Boolean isUpcoming, Date today) {
        Set<Id> registeredEventIds = new Set<Id>();
        if (!includeBlackthorn) {
            return registeredEventIds;
        }

        String query = 'SELECT conference360__Event__c FROM conference360__Attendee__c '
            + 'WHERE conference360__Contact__c = :viewerContactId '
            + (isUpcoming
                ? 'AND ((conference360__Event__r.conference360__Event_End_Date__c != null AND conference360__Event__r.conference360__Event_End_Date__c >= :today) '
                  + 'OR (conference360__Event__r.conference360__Event_End_Date__c = null AND conference360__Event__r.conference360__Event_Start_Date__c >= :today))'
                : 'AND ((conference360__Event__r.conference360__Event_End_Date__c != null AND conference360__Event__r.conference360__Event_End_Date__c < :today) '
                  + 'OR (conference360__Event__r.conference360__Event_End_Date__c = null AND conference360__Event__r.conference360__Event_Start_Date__c < :today))');

        try {
            for (conference360__Attendee__c att : Database.query(query)) {
                registeredEventIds.add(att.conference360__Event__c);
            }
        } catch (Exception e) {
            System.debug('[MiltonEventSearchAction] getBlackthornRegisteredEventIds threw: ' + e.getMessage());
        }
        return registeredEventIds;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // EVENT QUERIES
    // ─────────────────────────────────────────────────────────────────────────
    private static List<CventEvents__Event__c> queryCventEvents(
        String eventRegion, String eventName, Boolean isUpcoming, Boolean myEventsOnly,
        Set<Id> registeredEventIds, Date today
    ) {
        String namePattern;
        String query = 'SELECT Id, CventEvents__pkg_Title__c, CventEvents__pkg_Description__c, HAMImageURL__c, '
            + 'CventEvents__pkg_StartDate__c, CventEvents__pkg_StartTime__c, CventEvents__pkg_EndDate__c, '
            + 'CventEvents__pkg_Location__c, CventEvents__pkg_City__c '
            + 'FROM CventEvents__Event__c '
            + 'WHERE ' + System.label.Ham_CventsWhereClause;

        query += isUpcoming
            ? ' AND ((CventEvents__pkg_EndDate__c != null AND CventEvents__pkg_EndDate__c >= :today) OR (CventEvents__pkg_EndDate__c = null AND CventEvents__pkg_StartDate__c >= :today))'
            : ' AND ((CventEvents__pkg_EndDate__c != null AND CventEvents__pkg_EndDate__c < :today) OR (CventEvents__pkg_EndDate__c = null AND CventEvents__pkg_StartDate__c < :today))';

        // Upcoming_Events/Past_Events show every matching event regardless of the
        // viewer's registration status - contactId only narrows results for the
        // My Events variants.
        if (myEventsOnly) {
            query += registeredEventIds.isEmpty() ? ' AND Id = null' : ' AND Id IN :registeredEventIds';
        }

        if (String.isNotBlank(eventName)) {
            namePattern = '%' + eventName.trim() + '%';
            query += ' AND CventEvents__pkg_Title__c LIKE :namePattern';
        }

        if (String.isNotBlank(eventRegion)) {
            String regionCondition = buildRegionCondition(eventRegion);
            if (regionCondition == null) {
                // No usable region value survived parsing - fail safe to zero results
                // rather than silently dropping the filter and returning everything.
                query += ' AND Id = null';
            } else {
                query += ' AND ' + regionCondition;
            }
        }

        query += ' WITH SECURITY_ENFORCED';
        query += isUpcoming
            ? ' ORDER BY CventEvents__pkg_StartDate__c ASC, Id ASC LIMIT 50'
            : ' ORDER BY CventEvents__pkg_StartDate__c DESC, Id DESC LIMIT 50';

        System.debug('[MiltonEventSearchAction] queryCventEvents query: ' + query);

        try {
            return Database.query(query);
        } catch (Exception e) {
            System.debug('[MiltonEventSearchAction] queryCventEvents threw: ' + e.getMessage());
            return new List<CventEvents__Event__c>();
        }
    }

    private static List<conference360__Event__c> queryBlackthornEvents(
        String eventName, Boolean isUpcoming, Boolean myEventsOnly, Set<Id> registeredEventIds, Date today
    ) {
        String namePattern;
        String query = 'SELECT Id, Name, conference360__Short_Description__c, conference360__Image_URL__c, '
            + 'conference360__Event_Start_Date__c, conference360__Event_Start_Time__c, conference360__Event_End_Date__c, '
            + 'conference360__Venue_Name__c, conference360__Venue_City__c '
            + 'FROM conference360__Event__c '
            + 'WHERE ' + System.label.Ham_BlackThornWhereClause;

        query += isUpcoming
            ? ' AND ((conference360__Event_End_Date__c != null AND conference360__Event_End_Date__c >= :today) OR (conference360__Event_End_Date__c = null AND conference360__Event_Start_Date__c >= :today))'
            : ' AND ((conference360__Event_End_Date__c != null AND conference360__Event_End_Date__c < :today) OR (conference360__Event_End_Date__c = null AND conference360__Event_Start_Date__c < :today))';

        // Upcoming_Events/Past_Events show every matching event regardless of the
        // viewer's registration status - contactId only narrows results for the
        // My Events variants.
        if (myEventsOnly) {
            query += registeredEventIds.isEmpty() ? ' AND Id = null' : ' AND Id IN :registeredEventIds';
        }

        if (String.isNotBlank(eventName)) {
            namePattern = '%' + eventName.trim() + '%';
            query += ' AND Name LIKE :namePattern';
        }

        query += ' WITH SECURITY_ENFORCED';
        query += isUpcoming
            ? ' ORDER BY conference360__Event_Start_Date__c ASC, Id ASC LIMIT 50'
            : ' ORDER BY conference360__Event_Start_Date__c DESC, Id DESC LIMIT 50';

        System.debug('[MiltonEventSearchAction] queryBlackthornEvents query: ' + query);

        try {
            return Database.query(query);
        } catch (Exception e) {
            System.debug('[MiltonEventSearchAction] queryBlackthornEvents threw: ' + e.getMessage());
            return new List<conference360__Event__c>();
        }
    }

    /**
     * Builds the ADVPrimaryRegion__c IN (...) condition from a comma-separated eventRegion
     * value. Same "Anytown" special-case as HAM_EventsController.buildWhereClause - when
     * Anytown is selected, blank-region events are pulled in too so general/unassigned
     * events aren't missed. Returns null when no usable value survives parsing.
     */
    private static String buildRegionCondition(String eventRegion) {
        List<String> quotedValues = new List<String>();
        Boolean hasAnytown = false;

        for (String val : eventRegion.split(',')) {
            if (String.isNotBlank(val)) {
                String trimmedVal = val.trim();
                quotedValues.add('\'' + String.escapeSingleQuotes(trimmedVal) + '\'');
                if (trimmedVal.equalsIgnoreCase('Anytown')) {
                    hasAnytown = true;
                }
            }
        }

        if (quotedValues.isEmpty()) {
            return null;
        }

        String condition = 'ADVPrimaryRegion__c IN (' + String.join(quotedValues, ',') + ')';
        return hasAnytown ? '(' + condition + ' OR ADVPrimaryRegion__c = null)' : condition;
    }

    private static miltonEventResult toResult(
        Id recordId, String eventName, String description, String imageUrl,
        Date startDate, Time startTime, String place, String city
    ) {
        miltonEventResult result = new miltonEventResult();
        result.recordId = recordId;
        result.eventName = eventName;
        result.description = description;
        result.imageUrl = imageUrl;
        result.location = String.isNotBlank(place) ? place : city;

        if (startDate != null) {
            DateTime dt = startTime != null
                ? DateTime.newInstance(startDate, startTime)
                : DateTime.newInstance(startDate, Time.newInstance(0, 0, 0, 0));
            result.startDate = dt.format('MMM d, yyyy');
            result.startTime = dt.format('hh:mm a');
        }

        return result;
    }

    private static EventSearchOutput wrap(miltonEventSearchResponse resp) {
        EventSearchOutput output = new EventSearchOutput();
        output.result = resp;
        return output;
    }
}