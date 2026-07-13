/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : HAM_EventsController
 * Author          : Nilesh
 * Created Date    : Mar 20, 2026
 * Last Modified By: 
 * Last Modified On: Apr 13, 2026
 * Description     : This class is used to Handle all Events related operataion Events page.
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Mar 20, 2026  │ Nilesh       │ Initial version
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */

@SuppressWarnings('PMD.NoTrailingWhitespace, PMD.ExcessiveClassLength, PME.ExcessivePublicCount, PMD.ApexCRUDViolation, PMD.EmptyIfStmt, PMD.EmptyStatementBlock, PMD.AvoidNonRestrictiveQueries, PMD.CyclomaticComplexity, PMD.CognitiveComplexity, PMD.NcssCount, PMD.NcssTypeCount, PMD.DetectCopyPasteForApex, PMD.LocalVariableNamingConventions, PMD.ExcessiveParameterList, PMD.ApexSOQLInjection, PMD.AvoidDeeplyNestedIfStmts, PMD.AvoidDebugStatements, PMD.StdCyclomaticComplexity, PMD.NcssMethodCount')

public without sharing class HAM_EventsController {


    @AuraEnabled
    public static String confirmrequest(Id contactId) {
         
        //System.debug('contactId -'+contactId);
        List<ucinn_ascendv2__Funding_Interest__c> toInsert = new List<ucinn_ascendv2__Funding_Interest__c>();

        List<ucinn_ascendv2__Foundation_Funding_Interests__c> ffiList = [ SELECT Id, Name,HAM_Category__c FROM ucinn_ascendv2__Foundation_Funding_Interests__c 
                                                                          WHERE Name =: HAM_ConstantsUtil.HOST_AN_EVENT 
                                                                          LIMIT 1
                                                                        ];        
         //  Check if no record found
        if (ffiList.isEmpty()) {
            return 'No Foundation Funding Interest record found for "Host an Event"';
        }

        Id targetRecordTypeId = Schema.SObjectType.ucinn_ascendv2__Funding_Interest__c
            .getRecordTypeInfosByDeveloperName()
            .get('Contact_Funding_Interest')
            .getRecordTypeId();

        ucinn_ascendv2__Funding_Interest__c newRec = new ucinn_ascendv2__Funding_Interest__c();
        newRec.ucinn_ascendv2__Contact__c = contactId;
        newRec.ucinn_ascendv2__Foundation_Funding_Interest__c = ffiList[0].Id;
        newRec.RecordTypeId = targetRecordTypeId; 
        newRec.HAM_Category__c =ffiList[0].HAM_Category__c;
        newRec.ucinn_ascendv2__Start_Date__c = Date.today();

        toInsert.add(newRec);
        if(!toInsert.isEmpty()) insert toInsert;
         
        return 'Success';
    }

    // ─────────────────────────────────────────────────────────────────────────
    // WRAPPER CLASSES
    // ─────────────────────────────────────────────────────────────────────────

    /** Wrapper object for events */
    public class EventWrapper {
        @AuraEnabled public List<EventItem> events;
        @AuraEnabled public Integer totalEventsCount = 0;

        public EventWrapper() {
            events = new List<EventItem>();
        }
    }

    /** Event attributes */
    public class EventItem {
        @AuraEnabled public String name;
        @AuraEnabled public String image;
        @AuraEnabled public String description;
        @AuraEnabled public String startDate;
        @AuraEnabled public String startTime;
        @AuraEnabled public String place;
        @AuraEnabled public String city;
        @AuraEnabled public String redirectionURL;
        @AuraEnabled public Boolean isVirtual;
        @AuraEnabled public Boolean isInPerson;
        @AuraEnabled public Boolean isUpcomingEvent;
        @AuraEnabled public Boolean isPastEvent;
        @AuraEnabled public Boolean isRegistered;  
        @AuraEnabled public Boolean allowModifyEvent;
        @AuraEnabled public Boolean allowRegisterEvent;
        @AuraEnabled public Boolean disableRecordingRequest;
        @AuraEnabled public Boolean showRequestRecording;
        @AuraEnabled public String attendeeCount;
        @AuraEnabled public Integer totalConnectionCount;        
        @AuraEnabled public Id eventId;
        @AuraEnabled public String eventObjectAPI;
        @AuraEnabled public DateTime eventCreatedDate;
        @AuraEnabled public String eventStartDateCursor;  
        @AuraEnabled public List<AttendeeWrapper> attendees; 
    }

    /** Attendee attributes */
    public class AttendeeWrapper {
        @AuraEnabled public Id attendeeId;
        @AuraEnabled public String lastName;
        @AuraEnabled public String profilePic;
        @AuraEnabled public Boolean isBookmarked;
        @AuraEnabled public Boolean isConnected;
        @AuraEnabled public Boolean isFavorite;
    }

    //Service Indicator IDs. Used for service indicator setup in event attendees.
    public static final string ALUMNI_PRIVACY = HAM_ConstantsUtil.ALUMNI_PRIVCACY_SVID;
    public static final string CONNECTION_PRIVACY = HAM_ConstantsUtil.CONNECTION_PRIVCACY_SVID;
    public static final string PROFILEPIC_PRIVACY = HAM_ConstantsUtil.PROFILEPIC_PRIVCACY_SVID;

    // ─────────────────────────────────────────────────────────────────────────
    // SORT HELPER — AttendeeWrapper
    // Preference: connected+fav > connected+bookmarked > connections-only > bookmarked-only > lastName ASC
    // ─────────────────────────────────────────────────────────────────────────
    @TestVisible
    private static List<AttendeeWrapper> sortAttendeesByPreference(List<AttendeeWrapper> attendees) {
        Map<Integer, List<AttendeeWrapper>> buckets = new Map<Integer, List<AttendeeWrapper>>{
            1 => new List<AttendeeWrapper>(),
            2 => new List<AttendeeWrapper>(),
            3 => new List<AttendeeWrapper>(),
            4 => new List<AttendeeWrapper>(),
            5 => new List<AttendeeWrapper>()
        };

        for (AttendeeWrapper aw : attendees) {
            if (aw.isConnected == true && aw.isFavorite == true) {
                buckets.get(1).add(aw);
            } else if (aw.isConnected == true && aw.isBookmarked == true) {
                buckets.get(2).add(aw);
            } else if (aw.isConnected == true) {
                buckets.get(3).add(aw);
            } else if (aw.isBookmarked == true) {
                buckets.get(4).add(aw);
            } else {
                buckets.get(5).add(aw);
            }
        }

        // Sort each bucket alphabetically by lastName
        for (Integer b : buckets.keySet()) {
            List<AttendeeWrapper> PreferenceGroup = buckets.get(b);
            for (Integer i = 0; i < PreferenceGroup.size() - 1; i++) {
                for (Integer j = 0; j < PreferenceGroup.size() - i - 1; j++) {
                    String nameA = PreferenceGroup[j].lastName != null ? PreferenceGroup[j].lastName.toLowerCase() : '';
                    String nameB = PreferenceGroup[j+1].lastName != null ? PreferenceGroup[j+1].lastName.toLowerCase() : '';
                    if (nameA > nameB) {
                        AttendeeWrapper temp = PreferenceGroup[j];
                        PreferenceGroup[j] = PreferenceGroup[j+1];
                        PreferenceGroup[j+1] = temp;
                    }
                }
            }
        }

        List<AttendeeWrapper> sorted = new List<AttendeeWrapper>();
        sorted.addAll(buckets.get(1));
        sorted.addAll(buckets.get(2));
        sorted.addAll(buckets.get(3));
        sorted.addAll(buckets.get(4));
        sorted.addAll(buckets.get(5));
        return sorted;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // SORT HELPER — EventAttendee (used in getEventAttendees)
    // Same preference logic for the "Show All Attendees" modal
    // ─────────────────────────────────────────────────────────────────────────
   	@TestVisible
    private static List<EventAttendee> sortEventAttendeesByPreference(List<EventAttendee> attendees) {
        Map<Integer, List<EventAttendee>> buckets = new Map<Integer, List<EventAttendee>>{
            1 => new List<EventAttendee>(),
            2 => new List<EventAttendee>(),
            3 => new List<EventAttendee>(),
            4 => new List<EventAttendee>(),
            5 => new List<EventAttendee>()
        };

        for (EventAttendee ea : attendees) {
            if (ea.isConnected == true && ea.isFavorite == true) {
                buckets.get(1).add(ea);
            } else if (ea.isConnected == true && ea.isBookmarked == true) {
                buckets.get(2).add(ea);
            } else if (ea.isConnected == true) {
                buckets.get(3).add(ea);
            } else if (ea.isBookmarked == true) {
                buckets.get(4).add(ea);
            } else {
                buckets.get(5).add(ea);
            }
        }

        for (Integer b : buckets.keySet()) {
            List<EventAttendee> PreferenceGroup = buckets.get(b);
            for (Integer i = 0; i < PreferenceGroup.size() - 1; i++) {
                for (Integer j = 0; j < PreferenceGroup.size() - i - 1; j++) {
                    String nameA = PreferenceGroup[j].lastName != null ? PreferenceGroup[j].lastName.toLowerCase() : '';
                    String nameB = PreferenceGroup[j+1].lastName != null ? PreferenceGroup[j+1].lastName.toLowerCase() : '';
                    if (nameA > nameB) {
                        EventAttendee temp = PreferenceGroup[j];
                        PreferenceGroup[j] = PreferenceGroup[j+1];
                        PreferenceGroup[j+1] = temp;
                    }
                }
            }
        }

        List<EventAttendee> sorted = new List<EventAttendee>();
        sorted.addAll(buckets.get(1));
        sorted.addAll(buckets.get(2));
        sorted.addAll(buckets.get(3));
        sorted.addAll(buckets.get(4));
        sorted.addAll(buckets.get(5));
        return sorted;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // GET EVENT DETAILS
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @description Returns paginated events data with connection-attendee previews (max 3, preference-sorted).
     * Pagination: OFFSET-based — supports next, previous, and direct page jump.
     * Sorting: Cvent by CventEvents__pkg_StartDate__c, Blackthorn by conference360__Event_Start_Date__c.
     * Cvent has priority — fills page first; Blackthorn takes remaining slots.
     *
     * @param constituentId   Contact Id of the logged-in user
     * @param mainTab         Active main tab (Upcoming / Past)
     * @param subTab          Active sub tab
     * @param searchKey       Event name filter
     * @param pageSize        Records per page (3 mobile / 6 desktop)
     * @param recordsToSkip   OFFSET = (currentPage - 1) * pageSize
     * @param filters         Active filter payload
     */
    @AuraEnabled(cacheable=true)
    public static EventWrapper getEventDetails(
        Id constituentId,
        String mainTab,
        String subTab,
        String searchKey,
        Integer pageSize,
        Integer recordsToSkip,
        List<Map<String, Object>> filters
    ) {

        // fix OFFSET at 2000
        Integer safeOffset = (recordsToSkip != null) ? recordsToSkip : 0;
        if (safeOffset > 2000) {
            safeOffset = 2000;
        }

        // Labels
        Boolean isCventsActive = Boolean.valueOf(System.label.Ham_IsCventsActive);
        Boolean isBlackthornActive = Boolean.valueOf(System.label.Ham_IsBlackthornActive);
        String CventsWhereClause = System.label.Ham_CventsWhereClause;
        String BlackthornWhereClause = System.label.Ham_BlackThornWhereClause;

        // Query strings
        String CventQuery;
        String CventCountQuery;
        String BlackthornQuery;
        String BlackthornCountQuery;

        Map<String, String> cventFieldLabelToApi = new Map<String, String>();
        Map<String, String> blackthornFieldLabelToApi = new Map<String, String>();
        List<CventEvents__Event__c> cventEvents = new List<CventEvents__Event__c>();
        List<conference360__Event__c> blackthornEvents = new List<conference360__Event__c>();
        Integer cventEventsCount = 0;
        Integer blackthornEventsCount = 0;

        // ── Metadata field maps ──────────────────────────────────────────────
        List<Ham_Events_Metadata__mdt> eventsMetadata = [
            SELECT id, Field_Label__c, Field_API_Name__c, Object_API_Name__c, Object_Active__c, Field_Retrievable__c
            FROM Ham_Events_Metadata__mdt
            WHERE Object_Active__c = true AND Field_Retrievable__c = true
        ];

        for (Ham_Events_Metadata__mdt ev : eventsMetadata) {
            if (isCventsActive && ev.Object_Active__c && ev.Field_Retrievable__c
                    && ev.Object_API_Name__c == HAM_ConstantsUtil.CVENT_OBJECT_API) {
                cventFieldLabelToApi.put(ev.Field_Label__c, ev.Field_API_Name__c);
            }
            if (isBlackthornActive && ev.Object_Active__c && ev.Field_Retrievable__c
                    && ev.Object_API_Name__c == HAM_ConstantsUtil.BLACKTHORN_OBJECT_API) {
                blackthornFieldLabelToApi.put(ev.Field_Label__c, ev.Field_API_Name__c);
            }
        }

        // ── Connections ──────────────────────────────────────────────────────
        Set<String> Connections = new Set<String>();
        Map<Id, HAM_Connection__c> ConnectionMap = new Map<Id, HAM_Connection__c>();

        for (HAM_Connection__c connection : [
            SELECT Id, HAM_Linked_Constituent__c, HAM_Portal_User__c,
                   HAM_Is_bookmarked__c, HAM_Is_Connected__c, HAM_Is_favorite__c
            FROM HAM_Connection__c
            WHERE HAM_Is_Blocked__c = FALSE AND HAM_Is_Connected__c = TRUE
              AND (HAM_Portal_User__c = :constituentId OR  HAM_Linked_Constituent__c = :constituentId)
        ]) {
            if (connection.HAM_Portal_User__c == constituentId) {
                Connections.add(connection.HAM_Linked_Constituent__c);
                ConnectionMap.put(connection.HAM_Linked_Constituent__c, connection);
            } else if (connection.HAM_Linked_Constituent__c == constituentId) {
                Connections.add(connection.HAM_Portal_User__c);
            }
        }

        // ── Service Indicators — scoped to Connections only ────
        // Build per-contact SI map, then strip ALUMNI_PRIVACY contacts from
        // Connections and ConnectionMap before any subquery or aggregate runs.
        Map<Id, Set<String>> connectionSIMap = new Map<Id, Set<String>>();
        Set<String> siCodes = new Set<String>{ ALUMNI_PRIVACY, CONNECTION_PRIVACY, PROFILEPIC_PRIVACY };
        if (!Connections.isEmpty()) {
            for (ucinn_ascendv2__Service_Indicator__c si : [
                SELECT ucinn_ascendv2__Contact__c,
                       ucinn_ascendv2__Service_Indicator_Value__r.HAM_Portal_ID__c
                FROM ucinn_ascendv2__Service_Indicator__c
                WHERE ucinn_ascendv2__Is_Active__c = true
                  AND ucinn_ascendv2__Contact__c IN :Connections
                  AND ucinn_ascendv2__Service_Indicator_Value__r.HAM_Portal_ID__c IN :siCodes
            ]) {
                Id cid = si.ucinn_ascendv2__Contact__c;
                String code = si.ucinn_ascendv2__Service_Indicator_Value__r.HAM_Portal_ID__c;
                if (!connectionSIMap.containsKey(cid)) connectionSIMap.put(cid, new Set<String>());
                connectionSIMap.get(cid).add(code);
            }
        }

        // Remove ALUMNI_PRIVACY contacts from Connections and ConnectionMap so
        // all downstream subqueries and aggregate counts are automatically correct.
        for (Id cid : connectionSIMap.keySet()) {
            if (connectionSIMap.get(cid).contains(ALUMNI_PRIVACY)) {
                Connections.remove(cid);
                ConnectionMap.remove(cid);
            }
        }

        // ── Registered attendee maps (to know My/Other subtab) ──────────────
        Date today = Date.today();
        DateTime now = System.now();
        Time currentTime = Time.newInstance(now.hour(), now.minute(), now.second(), now.millisecond());

        String CventAttendeeQuery;
        String BlackthornAttendeeQuery;
        Map<Id, CventEvents__Attendee__c> CventAttendeeMap = new Map<Id, CventEvents__Attendee__c>();
        Map<Id, conference360__Attendee__c> BlackthornAttendeeMap = new Map<Id, conference360__Attendee__c>();

        if (mainTab == System.label.ham_EventsMainTab1) {
            if (isCventsActive) {
                CventAttendeeQuery = 'SELECT CventEvents__Event__c, CventEvents__PersonalizedRegistrationLink__c '
                    + 'FROM CventEvents__Attendee__c '
                    + 'WHERE CventEvents__Contact__c = :constituentId '
                    + 'AND ((CventEvents__Event__r.CventEvents__pkg_EndDate__c != null AND CventEvents__Event__r.CventEvents__pkg_EndDate__c >= :today) '
                    + 'OR (CventEvents__Event__r.CventEvents__pkg_EndDate__c = null AND CventEvents__Event__r.CventEvents__pkg_StartDate__c >= :today)) ';
            }

            if (isBlackthornActive) {
                BlackthornAttendeeQuery = 'SELECT conference360__Event__c, conference360__AttendeeLink__c '
                    + 'FROM conference360__Attendee__c '
                    + 'WHERE conference360__Contact__c = :constituentId '
                    + 'AND ((conference360__Event__r.conference360__Event_End_Date__c != null AND conference360__Event__r.conference360__Event_End_Date__c >= :today) '
                    + 'OR (conference360__Event__r.conference360__Event_End_Date__c = null AND conference360__Event__r.conference360__Event_Start_Date__c >= :today)) ';
            }
        } else if (mainTab == System.label.ham_EventsMainTab2) {
            if (isCventsActive) {
                CventAttendeeQuery = 'SELECT CventEvents__Event__c, CventEvents__PersonalizedRegistrationLink__c '
                    + 'FROM CventEvents__Attendee__c '
                    + 'WHERE CventEvents__Contact__c = :constituentId '
                    + 'AND ((CventEvents__Event__r.CventEvents__pkg_EndDate__c != null AND CventEvents__Event__r.CventEvents__pkg_EndDate__c < :today) '
                    + 'OR (CventEvents__Event__r.CventEvents__pkg_EndDate__c = null AND CventEvents__Event__r.CventEvents__pkg_StartDate__c < :today)) ';
            }
            if (isBlackthornActive) {
                BlackthornAttendeeQuery = 'SELECT conference360__Event__c, conference360__AttendeeLink__c '
                    + 'FROM conference360__Attendee__c '
                    + 'WHERE conference360__Contact__c = :constituentId '
                    + 'AND ((conference360__Event__r.conference360__Event_End_Date__c != null AND conference360__Event__r.conference360__Event_End_Date__c < :today) '
                    + 'OR (conference360__Event__r.conference360__Event_End_Date__c = null AND conference360__Event__r.conference360__Event_Start_Date__c < :today)) ';
            }
        }

        if (!String.isBlank(CventAttendeeQuery)) {
            for (CventEvents__Attendee__c att : Database.Query(CventAttendeeQuery)) {
                CventAttendeeMap.put(att.CventEvents__Event__c, att);
            }
        }
        if (!String.isBlank(BlackthornAttendeeQuery)) {
            for (conference360__Attendee__c att : Database.Query(BlackthornAttendeeQuery)) {
                BlackthornAttendeeMap.put(att.conference360__Event__c, att);
            }
        }

        // ── CVENT QUERY ──────────────────────────────────────────────────────
        if (isCventsActive && !cventFieldLabelToApi.values().isEmpty()) {

            // Subquery: only 3 connection attendees for preview — governor limit protection
            String CventSubquery =
                '(SELECT CventEvents__Contact__c, '
                + 'CventEvents__Contact__r.LastName, '
                + 'CventEvents__Contact__r.HAM_Profile_Picture_URL__c '
                + 'FROM CventEvents__Attendees__r '
                + 'WHERE CventEvents__Contact__c IN :Connections '
                + 'LIMIT 3)';

            CventQuery =
                'SELECT Id, CreatedDate, '
                + String.join(new List<String>(cventFieldLabelToApi.values()), ', ')
                + ', ' + CventSubquery
                + ' FROM ' + HAM_ConstantsUtil.CVENT_OBJECT_API
                + ' WHERE ' + CventsWhereClause;

            CventCountQuery = 'SELECT Count() FROM ' + HAM_ConstantsUtil.CVENT_OBJECT_API
                            + ' WHERE ' + CventsWhereClause;

            Set<Id> CventsRegistered = CventAttendeeMap != null ? CventAttendeeMap.keySet() : new Set<Id>();

            if (subTab == System.label.ham_EventsMainTab1SubTab1 || subTab == System.label.ham_EventsMainTab2SubTab1) {
                CventQuery += ' AND Id IN :CventsRegistered';
                CventCountQuery += ' AND Id IN :CventsRegistered';
            } else if (subTab == System.label.ham_EventsMainTab1SubTab2 || subTab == System.label.ham_EventsMainTab2SubTab2) {
                CventQuery += ' AND Id NOT IN :CventsRegistered';
                CventCountQuery += ' AND Id NOT IN :CventsRegistered';
            }

            if (mainTab == System.label.ham_EventsMainTab1) {
                CventQuery += ' AND ((CventEvents__pkg_EndDate__c != null AND CventEvents__pkg_EndDate__c >= :today) OR (CventEvents__pkg_EndDate__c = null AND CventEvents__pkg_StartDate__c >= :today)) ';
                CventCountQuery += ' AND ((CventEvents__pkg_EndDate__c != null AND CventEvents__pkg_EndDate__c >= :today) OR (CventEvents__pkg_EndDate__c = null AND CventEvents__pkg_StartDate__c >= :today)) ';
            } else if (mainTab == System.label.ham_EventsMainTab2) {
                CventQuery += ' AND ((CventEvents__pkg_EndDate__c != null AND CventEvents__pkg_EndDate__c < :today) OR (CventEvents__pkg_EndDate__c = null AND CventEvents__pkg_StartDate__c < :today)) ';
                CventCountQuery += ' AND ((CventEvents__pkg_EndDate__c != null AND CventEvents__pkg_EndDate__c < :today) OR (CventEvents__pkg_EndDate__c = null AND CventEvents__pkg_StartDate__c < :today)) ';
            }

            if (!String.isBlank(searchKey)) {
                String likeKey = '%' + searchKey + '%';
                CventQuery  += ' AND CventEvents__pkg_Title__c LIKE :likeKey ';
                CventCountQuery += ' AND CventEvents__pkg_Title__c LIKE :likeKey ';
            }

            if (filters != null && !filters.isEmpty()) {
                String filtersClause = buildWhereClause(filters);
                CventQuery += filtersClause;
                CventCountQuery += filtersClause;
            }

            // OFFSET-based pagination
            // Upcoming: soonest first (ASC). Past: most recently occurred (DESC).
            String cventSortDir = (mainTab == System.label.ham_EventsMainTab1) ? 'ASC' : 'DESC';
            Integer cventOffset = safeOffset;

            CventQuery += ' ORDER BY CventEvents__pkg_StartDate__c ' + cventSortDir
                        + ', Id ' + cventSortDir
                        + ' LIMIT :pageSize OFFSET :cventOffset';
        }

        //System.debug('Cvent Query : ' + CventQuery);
        //System.debug('Cvent Count Query : ' + CventCountQuery);

        if (CventQuery != null && !String.isBlank(CventQuery)) {
            try { cventEvents = Database.query(CventQuery); }
            catch (Exception e) { System.debug('Error querying Cvents: ' + e.getMessage()); }
        }
        if (CventCountQuery != null && !String.isBlank(CventCountQuery)) {
            try { cventEventsCount = Database.countQuery(CventCountQuery); }
            catch (Exception e) { System.debug('Error querying Cvent count: ' + e.getMessage()); }
        }

        // Extract Event Type selected values from filter payload
        List<String> eventTypeSelectedValues = new List<String>();
        if (filters != null) {
            for (Map<String, Object> f : filters) {
                String ph = (String) f.get('placeholder');
                if (ph != null && ph.equalsIgnoreCase('Event Type')) {
                    List<Object> vals = (List<Object>) f.get('values');
                    if (vals != null) {
                        for (Object v : vals) eventTypeSelectedValues.add(String.valueOf(v));
                    }
                }
            }
        }
        boolean hasEventTypeFilter = !eventTypeSelectedValues.isEmpty();

        // Build the Blackthorn Calendar_Location clause (null = skip BT entirely e.g. only Hybrid selected)
        String btEventTypeClause = hasEventTypeFilter
            ? buildBlackthornEventTypeClause(eventTypeSelectedValues)
            : '';
        boolean skipBlackthornForEventType = (hasEventTypeFilter && btEventTypeClause == null);

        // ── BLACKTHORN QUERY ─────────────────────────────────────────────────
        // Blackthorn is skipped when filters are applied (Cvent-only feature)
        if (isBlackthornActive && !blackthornFieldLabelToApi.values().isEmpty() && 
            !skipBlackthornForEventType && (filters == null || filters.isEmpty() || hasEventTypeFilter)) {

            // Subquery: only 3 connection attendees for preview — governor limit protection
            String BlackthornSubquery =
                '(SELECT conference360__Contact__c, '
                + 'conference360__Contact__r.LastName, '
                + 'conference360__Contact__r.HAM_Profile_Picture_URL__c '
                + 'FROM conference360__Attendees__r '
                + 'WHERE conference360__Contact__c IN :Connections '
                + 'LIMIT 3)';

            BlackthornQuery =
                'SELECT Id, CreatedDate, '
                + String.join(new List<String>(blackthornFieldLabelToApi.values()), ', ')
                + ', ' + BlackthornSubquery
                + ' FROM ' + HAM_ConstantsUtil.BLACKTHORN_OBJECT_API
                + ' WHERE ' + BlackthornWhereClause;

            BlackthornCountQuery = 'SELECT Count() FROM ' + HAM_ConstantsUtil.BLACKTHORN_OBJECT_API
                                 + ' WHERE ' + BlackthornWhereClause;

            Set<Id> BlackthornRegistered = BlackthornAttendeeMap != null ? BlackthornAttendeeMap.keySet() : new Set<Id>();

            if (subTab == System.label.ham_EventsMainTab1SubTab1 || subTab == System.label.ham_EventsMainTab2SubTab1) {
                BlackthornQuery += ' AND Id IN :BlackthornRegistered';
                BlackthornCountQuery += ' AND Id IN :BlackthornRegistered';
            } else if (subTab == System.label.ham_EventsMainTab1SubTab2 || subTab == System.label.ham_EventsMainTab2SubTab2) {
                BlackthornQuery  += ' AND Id NOT IN :BlackthornRegistered';
                BlackthornCountQuery += ' AND Id NOT IN :BlackthornRegistered';
            }


            if (mainTab == System.label.ham_EventsMainTab1) {
                BlackthornQuery += ' AND ((conference360__Event_End_Date__c != null AND conference360__Event_End_Date__c >= :today) OR (conference360__Event_End_Date__c = null AND conference360__Event_Start_Date__c >= :today)) ';
                BlackthornCountQuery += ' AND ((conference360__Event_End_Date__c != null AND conference360__Event_End_Date__c >= :today) OR (conference360__Event_End_Date__c = null AND conference360__Event_Start_Date__c >= :today)) ';
            } else if (mainTab == System.label.ham_EventsMainTab2) {
                BlackthornQuery += ' AND ((conference360__Event_End_Date__c != null AND conference360__Event_End_Date__c < :today) OR (conference360__Event_End_Date__c = null AND conference360__Event_Start_Date__c < :today)) ';
                BlackthornCountQuery += ' AND ((conference360__Event_End_Date__c != null AND conference360__Event_End_Date__c < :today) OR (conference360__Event_End_Date__c = null AND conference360__Event_Start_Date__c < :today)) ';
            }

            if (!String.isBlank(searchKey)) {
                String likeKey = '%' + searchKey + '%';
                BlackthornQuery += ' AND Name LIKE :likeKey ';
                BlackthornCountQuery += ' AND Name LIKE :likeKey ';
            }

            // Blackthorn fills remaining slots after Cvent on each page.
            String btSortDir = (mainTab == System.label.ham_EventsMainTab1) ? 'ASC' : 'DESC';
            Integer btLimit = pageSize - cventEvents.size();
            Integer btOffset = safeOffset - cventEventsCount;
            if (btOffset < 0) {
                btOffset = 0;
            }
            if (btOffset > 2000) {
                btOffset = 2000;
            }

            // Apply Event Type → Calendar_Location mapping to Blackthorn
            if (hasEventTypeFilter && String.isNotBlank(btEventTypeClause)) {
                BlackthornQuery      += btEventTypeClause;
                BlackthornCountQuery += btEventTypeClause;
            }

            BlackthornQuery += ' ORDER BY conference360__Event_Start_Date__c ' + btSortDir
                             + ', Id ' + btSortDir
                             + ' LIMIT :btLimit OFFSET :btOffset';
        }

        //System.debug('Blackthorn Query : ' + BlackthornQuery);
        //System.debug('Blackthorn Count Query : ' + BlackthornCountQuery);

        if (BlackthornQuery != null && !String.isBlank(BlackthornQuery)) {
            try {
                blackthornEvents = Database.query(BlackthornQuery);
            } catch (Exception e) { System.debug('Error querying Blackthorn: ' + e.getMessage()); }
        }
        if (BlackthornCountQuery != null && !String.isBlank(BlackthornCountQuery)) {
            try { blackthornEventsCount = Database.countQuery(BlackthornCountQuery); }
            catch (Exception e) { System.debug('Error querying Blackthorn count: ' + e.getMessage()); }
        }

        // ── Connection attendee counts per event ────────
        // The subquery is LIMIT 3 for governor safety, so we are doing a separate aggregate
        // to know the true total number of connections attending each event.
        Map<Id, Integer> cventConnectionCountMap     = new Map<Id, Integer>();
        Map<Id, Integer> blackthornConnectionCountMap = new Map<Id, Integer>();

        if (!cventEvents.isEmpty() && !Connections.isEmpty()) {
            Set<Id> cventEventIds = new Map<Id, CventEvents__Event__c>(cventEvents).keySet();
            for (AggregateResult ar : [
                SELECT CventEvents__Event__c eventId, COUNT(Id) cnt
                FROM CventEvents__Attendee__c
                WHERE CventEvents__Event__c IN :cventEventIds
                AND CventEvents__Contact__c IN :Connections
                GROUP BY CventEvents__Event__c
            ]) {
                cventConnectionCountMap.put((Id) ar.get('eventId'), (Integer) ar.get('cnt'));
            }
        }

        if (!blackthornEvents.isEmpty() && !Connections.isEmpty()) {
            Set<Id> btEventIds = new Map<Id, conference360__Event__c>(blackthornEvents).keySet();
            for (AggregateResult ar : [
                SELECT conference360__Event__c eventId, COUNT(Id) cnt
                FROM conference360__Attendee__c
                WHERE conference360__Event__c IN :btEventIds
                AND conference360__Contact__c IN :Connections
                GROUP BY conference360__Event__c
            ]) {
                blackthornConnectionCountMap.put((Id) ar.get('eventId'), (Integer) ar.get('cnt'));
            }
        }

        // ── Recording requests ───────────────────────────────────────────────
        Set<Id> recordingRequestedEventIds = new Set<Id>();
        for (Task tk : [SELECT WhatId FROM Task
                        WHERE (WhatId IN :cventEvents OR WhatId IN :blackthornEvents)
                        AND WhoId = :constituentId]) {
            recordingRequestedEventIds.add(tk.WhatId);
        }

        // ── Build response ───────────────────────────────────────────────────
        EventWrapper response = new EventWrapper();
        response.totalEventsCount = cventEventsCount + blackthornEventsCount;

        // ── Cvent events ────────────────────────────────────────────────────
        if (!cventEvents.isEmpty()) {
            for (CventEvents__Event__c event : cventEvents) {

                EventItem item  = new EventItem();
                item.eventId = event.Id;
                item.name = getStringOrDefault(event.get(cventFieldLabelToApi.get('EventName')), '-');
                item.description = getStringOrDefault(event.get(cventFieldLabelToApi.get('Description')), '-');
                item.place = getStringOrDefault(event.get(cventFieldLabelToApi.get('Place')), '-');
                item.city = getStringOrDefault(event.get(cventFieldLabelToApi.get('City')), '-');
                item.image = (String) event.get(cventFieldLabelToApi.get('ImageURL'));
                item.isRegistered = CventAttendeeMap.containsKey(event.Id);

                if (item.isRegistered) {
                    item.redirectionURL = (String) CventAttendeeMap.get(event.Id).CventEvents__PersonalizedRegistrationLink__c;
                } else {
                    //Check if ADVEssentialsURLforascend__c has value in it. If it has value, use it. Else fallback to CventEvents__pkg_RegistrationLink__c
                    String advEssentialsURL = (String) event.get(cventFieldLabelToApi.get('RegistrationLink1'));
                    item.redirectionURL = String.isNotBlank(advEssentialsURL) ? advEssentialsURL : (String) event.get(cventFieldLabelToApi.get('RegistrationLink'));
                }

                Date eventDate = (Date) event.get(cventFieldLabelToApi.get('StartDate'));
                Time eventTime = (Time) event.get(cventFieldLabelToApi.get('StartTime'));
                Date endDate   = (Date) event.get(cventFieldLabelToApi.get('EndDate'));

                if (eventDate != null) {
                    DateTime dt = (eventTime != null)
                        ? DateTime.newInstance(eventDate, eventTime)
                        : DateTime.newInstance(eventDate, Time.newInstance(0,0,0,0));

                    // Use end date when available, otherwise start date. Date-only comparison.
                    Date checkDate = (endDate != null) ? endDate : eventDate;
                    item.isUpcomingEvent = (checkDate >= today);

                    item.isPastEvent = !item.isUpcomingEvent;
                    item.startDate      = dt.format('MMM d, yyyy');
                    item.startTime      = dt.format('hh:mm a');
                    item.eventStartDateCursor = String.valueOf(eventDate);
                } else {
                    item.startDate = '-';
                    item.startTime = '-';
                    item.eventStartDateCursor = null;
                }

                if (item.isUpcomingEvent == true) {
                    item.allowModifyEvent  = item.isRegistered;
                    item.allowRegisterEvent = !item.isRegistered;
                } else if (item.isPastEvent == true) {
                    item.showRequestRecording  = !item.isRegistered;
                    item.disableRecordingRequest = recordingRequestedEventIds.contains(event.Id);
                }

                String format = getStringOrDefault(event.get(cventFieldLabelToApi.get('Format')), '-');
                item.isVirtual  = format != null && format.contains('Virtual');
                item.isInPerson = format != null && format.contains('In Person');

                item.eventObjectAPI   = HAM_ConstantsUtil.CVENT_OBJECT_API;
                item.eventCreatedDate = event.CreatedDate;

                // Build attendee preview
                item.attendees = new List<AttendeeWrapper>();
                if (event.CventEvents__Attendees__r != null) {
                    List<AttendeeWrapper> rawAttendees = new List<AttendeeWrapper>();
                    for (CventEvents__Attendee__c att : event.CventEvents__Attendees__r) {
                        AttendeeWrapper aw = new AttendeeWrapper();
                        aw.attendeeId = att.CventEvents__Contact__c;
                        aw.lastName = att.CventEvents__Contact__r.LastName;

                        // PROFILEPIC_PRIVACY: use null so LWC falls back to default image
                        Set<String> attSI = connectionSIMap.get(att.CventEvents__Contact__c);
                        aw.profilePic = (attSI != null && attSI.contains(PROFILEPIC_PRIVACY)) ? null : att.CventEvents__Contact__r.HAM_Profile_Picture_URL__c;

                        if (ConnectionMap.containsKey(att.CventEvents__Contact__c)) {
                            aw.isBookmarked = ConnectionMap.get(att.CventEvents__Contact__c).HAM_Is_bookmarked__c;
                            aw.isConnected  = ConnectionMap.get(att.CventEvents__Contact__c).HAM_Is_Connected__c;
                            aw.isFavorite   = ConnectionMap.get(att.CventEvents__Contact__c).HAM_Is_favorite__c;
                        } else {
                            aw.isBookmarked = false;
                            aw.isConnected  = false;
                            aw.isFavorite   = false;
                        }
                        rawAttendees.add(aw);
                    }
                    // Sort by preference before sending to LWC
                    item.attendees = sortAttendeesByPreference(rawAttendees);
                    item.totalConnectionCount = cventConnectionCountMap.containsKey(event.Id)
                                                ? cventConnectionCountMap.get(event.Id) : 0;
                } else {
                    item.totalConnectionCount = 0;
                }

                response.events.add(item);
            }
        }

        // ── Blackthorn events ────────────────────────────────────────────────
        if (!blackthornEvents.isEmpty()) {
            for (conference360__Event__c event : blackthornEvents) {

                EventItem item  = new EventItem();
                item.eventId = event.Id;
                item.name = getStringOrDefault(event.get(blackthornFieldLabelToApi.get('EventName')), '-');
                item.description = getStringOrDefault(event.get(blackthornFieldLabelToApi.get('Description')), '-');
                item.place = getStringOrDefault(event.get(blackthornFieldLabelToApi.get('Place')), '-');
                item.city = getStringOrDefault(event.get(blackthornFieldLabelToApi.get('City')), '-');
                item.image = (String) event.get(blackthornFieldLabelToApi.get('ImageURL'));
                item.isRegistered = BlackthornAttendeeMap.containsKey(event.Id);

                if (item.isRegistered) {
                    item.redirectionURL = (String) BlackthornAttendeeMap.get(event.Id).conference360__AttendeeLink__c;
                } else {
                    item.redirectionURL = (String) event.get(blackthornFieldLabelToApi.get('RegistrationLink'));
                }

                Date eventDate = (Date) event.get(blackthornFieldLabelToApi.get('StartDate'));
                Time eventTime = (Time) event.get(blackthornFieldLabelToApi.get('StartTime'));
                Date endDate   = (Date) event.get(blackthornFieldLabelToApi.get('EndDate'));

                if (eventDate != null) {
                    DateTime dt = (eventTime != null)
                        ? DateTime.newInstance(eventDate, eventTime)
                        : DateTime.newInstance(eventDate, Time.newInstance(0,0,0,0));

                    // Use end date when available, otherwise start date. Date-only comparison.
                    Date checkDate = (endDate != null) ? endDate : eventDate;
                    item.isUpcomingEvent = (checkDate >= today);

                    item.isPastEvent = !item.isUpcomingEvent;
                    item.startDate      = dt.format('MMM d, yyyy');
                    item.startTime      = dt.format('hh:mm a');
                    item.eventStartDateCursor = String.valueOf(eventDate);
                } else {
                    item.startDate = '-';
                    item.startTime = '-';
                    item.eventStartDateCursor = null;
                }

                if (item.isUpcomingEvent == true) {
                    item.allowModifyEvent  = item.isRegistered;
                    item.allowRegisterEvent = !item.isRegistered;
                } else if (item.isPastEvent == true) {
                    item.showRequestRecording    = !item.isRegistered;
                    item.disableRecordingRequest = recordingRequestedEventIds.contains(event.Id);
                }

                String format = (String) event.get(blackthornFieldLabelToApi.get('Format'));
                item.isVirtual = format != null && !String.isBlank(format);
                item.isInPerson = !item.isVirtual;

                item.eventObjectAPI = HAM_ConstantsUtil.BLACKTHORN_OBJECT_API;
                item.eventCreatedDate = event.CreatedDate;

                // Build attendee preview (subquery already limited to 3 )
                item.attendees = new List<AttendeeWrapper>();
                if (event.conference360__Attendees__r != null) {
                    List<AttendeeWrapper> rawAttendees = new List<AttendeeWrapper>();
                    for (conference360__Attendee__c att : event.conference360__Attendees__r) {
                        AttendeeWrapper aw = new AttendeeWrapper();
                        aw.attendeeId = att.conference360__Contact__c;
                        aw.lastName  = att.conference360__Contact__r.LastName;

                        // PROFILEPIC_PRIVACY: use null so LWC falls back to default image
                        Set<String> attSI = connectionSIMap.get(att.conference360__Contact__c);
                        aw.profilePic = (attSI != null && attSI.contains(PROFILEPIC_PRIVACY)) ? null : att.conference360__Contact__r.HAM_Profile_Picture_URL__c;

                        if (ConnectionMap.containsKey(att.conference360__Contact__c)) {
                            aw.isBookmarked = ConnectionMap.get(att.conference360__Contact__c).HAM_Is_bookmarked__c;
                            aw.isConnected = ConnectionMap.get(att.conference360__Contact__c).HAM_Is_Connected__c;
                            aw.isFavorite = ConnectionMap.get(att.conference360__Contact__c).HAM_Is_favorite__c;
                        } else {
                            aw.isBookmarked = false;
                            aw.isConnected = false;
                            aw.isFavorite = false;
                        }
                        rawAttendees.add(aw);
                    }
                    // Sort by preference before sending to LWC
                    item.attendees    = sortAttendeesByPreference(rawAttendees);
                    item.totalConnectionCount = blackthornConnectionCountMap.containsKey(event.Id)
                                                ? blackthornConnectionCountMap.get(event.Id) : 0;

                } else {
                    item.totalConnectionCount = 0;
                }

                response.events.add(item);
            }
        }

        return response;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // HELPER — default string
    // ─────────────────────────────────────────────────────────────────────────
    private static String getStringOrDefault(Object value, String defaultVal) {
        return value != null ? String.valueOf(value) : defaultVal;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // GET EVENT ATTENDEES — "Show All Attendees" modal
    // Returns ALL attendees of the event, sorted by same preference.
    // Connections bubble to top; non-connections sorted alphabetically on lastName after.
    // ─────────────────────────────────────────────────────────────────────────

    /** Wrapper for event attendees modal */
    public class EventAttendeeWrapper {
        @AuraEnabled public List<EventAttendee> eventAttendees;
        @AuraEnabled public Integer totalAttendeeCount = 0;
        @AuraEnabled public Boolean loggedInUserHasConnectionPrivacy = false;

        public EventAttendeeWrapper() {
            eventAttendees = new List<EventAttendee>();
        }
    }

    /** Single attendee row for modal */
    public class EventAttendee {
        @AuraEnabled public String attendeeId;
        @AuraEnabled public String name;
        @AuraEnabled public String lastName;
        @AuraEnabled public String profilePic;
        @AuraEnabled public String graduationYear;
        @AuraEnabled public Boolean isConnected;
        @AuraEnabled public Boolean isBookmarked;
        @AuraEnabled public Boolean isFavorite;
        @AuraEnabled public Boolean isRejected;
        @AuraEnabled public String connectionStatus;
        @AuraEnabled public Boolean hideConnectionRequest;
        @AuraEnabled public Boolean isDeceased;
    }

    /**
     * @description Paginated, searchable attendee loader for the attendees modal.
     *
     * Architecture — two-pass to preserve global preference ordering without hitting
     * governor limits on large events (50 K+ attendees):
     *
     *  Phase 1 — PREFERENCE attendees (connections / bookmarks / request-sent)
     *    - The user's ConnectionMap is bounded by their own relationship count (hundreds,
     *      never tens of thousands), so we can safely fetch all matching IDs in one query,
     *      sort them in-memory by the preference buckets (connected+fav → connected+bkm →
     *      bookmarked-only → rest), then slice the current page's IDs out of the sorted list.
     *
     *  Phase 2 — NON-PREFERENCE attendees ("all" mode only)
     *    - These are the potentially-massive group.  We only issue a COUNT query (governor
     *      safe) for the total, and then a LIMIT/OFFSET query for the exact records that
     *      fall on the current page after the preference block is exhausted.
     *
     *  Full contact data (name, photo, degree) is only fetched for the ≤6 contacts on
     *  the current page, keeping every query well inside Salesforce limits.
     *
     * @param eventId         Event record Id
     * @param ConstituentId   Logged-in user's Contact Id
     * @param objectApi       'CventEvents__Event__c' or 'conference360__Event__c'
     * @param connectionsOnly true → connections-only modal; false → all-attendees modal
     * @param searchKey       Name search term (applied server-side, fires on Enter / icon click)
     * @param pageSize        Records per page (always 6)
     * @param recordsToSkip   OFFSET = (currentPage - 1) * pageSize
     */
    @AuraEnabled
    public static EventAttendeeWrapper getEventAttendees(
        Id      eventId,
        Id      ConstituentId,
        String  objectApi,
        Boolean connectionsOnly,
        String  searchKey,
        Integer pageSize,
        Integer recordsToSkip
    ) {
        // ── Safe defaults ────────────────────────────────────────────────────
        Integer safePageSize = (pageSize != null && pageSize > 0) ? pageSize : 6;
        Integer safeOffset   = (recordsToSkip != null && recordsToSkip >= 0) ? recordsToSkip : 0;

        if (safeOffset > 2000){
            safeOffset = 2000;   // SOQL OFFSET
        }

        String likeKey = String.isNotBlank(searchKey)
            ? '%' + String.escapeSingleQuotes(searchKey.trim()) + '%'
            : null;

        // ── Service Indicators — one query for all 3 types ───────────────────
        // privacyContactIds drives Phase 1 & 2 exclusions (pagination accuracy).
        // serviceIndicatorMap drives PROFILE_PIC and CONNECTION on the final page.

        Map<Id, Set<String>> serviceIndicatorMap = new Map<Id, Set<String>>();
        Set<Id> privacyContactIds = new Set<Id>();
        Set<String> siCodes = new Set<String>{ ALUMNI_PRIVACY, CONNECTION_PRIVACY, PROFILEPIC_PRIVACY };

        for (ucinn_ascendv2__Service_Indicator__c si : [
            SELECT ucinn_ascendv2__Contact__c,
                   ucinn_ascendv2__Service_Indicator_Value__r.HAM_Portal_ID__c
            FROM ucinn_ascendv2__Service_Indicator__c
            WHERE ucinn_ascendv2__Is_Active__c = true
              AND ucinn_ascendv2__Service_Indicator_Value__r.HAM_Portal_ID__c IN :siCodes
        ]) {
            Id cid = si.ucinn_ascendv2__Contact__c;
            String code = si.ucinn_ascendv2__Service_Indicator_Value__r.HAM_Portal_ID__c;
            if (!serviceIndicatorMap.containsKey(cid)) serviceIndicatorMap.put(cid, new Set<String>());
            serviceIndicatorMap.get(cid).add(code);
            if (code == ALUMNI_PRIVACY) privacyContactIds.add(cid);
        }

        // Check whether the logged-in user has CONNECTION_PRIVACY — drives Rule A in LWC
        Set<String> loggedInUserSI = serviceIndicatorMap.get(ConstituentId);
        Boolean loggedInUserHasConnectionPrivacy = (loggedInUserSI != null && loggedInUserSI.contains(CONNECTION_PRIVACY));

        // ── Build ConnectionMap & SecondaryConnectionMap ─────────────────────
        // ConnectionMap  : user → others (bookmark / connected / request-sent)
        // SecondaryMap   : others → user (used only for isRejected check)
        Map<Id, HAM_Connection__c> ConnectionMap       = new Map<Id, HAM_Connection__c>();
        Map<Id, HAM_Connection__c> SecondaryConnectionMap = new Map<Id, HAM_Connection__c>();

        for (HAM_Connection__c conn : [
            SELECT Id, HAM_Portal_User__c, HAM_Linked_Constituent__c,
                   HAM_Is_bookmarked__c, HAM_Is_Connected__c, HAM_Is_favorite__c,
                   HAM_Connection_Status__c, HAM_Rejected_Date__c
            FROM HAM_Connection__c
            WHERE (HAM_Portal_User__c = :ConstituentId OR HAM_Linked_Constituent__c = :ConstituentId)
              AND (HAM_Is_bookmarked__c = TRUE OR HAM_Is_Connected__c = TRUE
                   OR HAM_Connection_Status__c = 'Request Sent' OR HAM_Rejected_Date__c != null)
              AND HAM_Is_Blocked__c = FALSE
        ]) {
            if (conn.HAM_Portal_User__c == ConstituentId) {
                ConnectionMap.put(conn.HAM_Linked_Constituent__c, conn);
            } else {
                SecondaryConnectionMap.put(conn.HAM_Portal_User__c, conn);
            }
        }

        // Blocked contacts (in either direction) must be hidden from attendee results.
        // These records have HAM_Is_Blocked__c = true and no other flags set, so they
        // never enter the connection query above — they must be fetched separately.
        Set<Id> blockedContactIds = new Set<Id>();
        for (HAM_Connection__c conn : [
            SELECT HAM_Portal_User__c, HAM_Linked_Constituent__c
            FROM HAM_Connection__c
            WHERE (HAM_Portal_User__c = :ConstituentId OR HAM_Linked_Constituent__c = :ConstituentId)
              AND HAM_Is_Blocked__c = TRUE
        ]) {
            Id otherId = (conn.HAM_Portal_User__c == ConstituentId)
                ? conn.HAM_Linked_Constituent__c
                : conn.HAM_Portal_User__c;
            if (otherId != null) blockedContactIds.add(otherId);
        }

        // ── Determine which ConnectionMap IDs are eligible for Phase 1 ───────
        // connections-only modal → only truly connected people
        // all-attendees modal   → all of ConnectionMap (connected + bookmarked + request-sent)
        Set<Id> preferenceEligibleIds = new Set<Id>();
        for (Id cid : ConnectionMap.keyset()) {
            if (connectionsOnly) {
                if (ConnectionMap.get(cid).HAM_Is_Connected__c) preferenceEligibleIds.add(cid);
            } else {
                preferenceEligibleIds.add(cid);
            }
        }

        EventAttendeeWrapper response = new EventAttendeeWrapper();
        response.loggedInUserHasConnectionPrivacy = loggedInUserHasConnectionPrivacy;

        // ════════════════════════════════════════════════════════════════════
        // PHASE 1 — collect preference attendee IDs for this event
        // Governor safe: bounded by the user's relationship count, not event size
        // ════════════════════════════════════════════════════════════════════
        Set<Id> preferenceAttendingIds = new Set<Id>();

        if (!preferenceEligibleIds.isEmpty()) {
            if (objectApi == HAM_ConstantsUtil.CVENT_OBJECT_API) {
                String q = 'SELECT CventEvents__Contact__c'
                         + ' FROM CventEvents__Attendee__c'
                         + ' WHERE CventEvents__Event__c = :eventId'
                         + ' AND CventEvents__Contact__c IN :preferenceEligibleIds';

                if (likeKey != null){
                     q += ' AND CventEvents__Contact__r.Name LIKE :likeKey';
                }

                try {
                    for (CventEvents__Attendee__c a : Database.query(q))
                        preferenceAttendingIds.add(a.CventEvents__Contact__c);
                } catch (Exception ex) {
                    System.debug(LoggingLevel.ERROR, 'Phase 1 Cvent error: ' + ex.getMessage());
                }

            } else if (objectApi == HAM_ConstantsUtil.BLACKTHORN_OBJECT_API) {
                String q = 'SELECT conference360__Contact__c'
                         + ' FROM conference360__Attendee__c'
                         + ' WHERE conference360__Event__c = :eventId'
                         + ' AND conference360__Contact__c IN :preferenceEligibleIds';
                if (likeKey != null) q += ' AND conference360__Contact__r.Name LIKE :likeKey';
                try {
                    for (conference360__Attendee__c a : Database.query(q))
                        preferenceAttendingIds.add(a.conference360__Contact__c);
                } catch (Exception ex) {
                    System.debug(LoggingLevel.ERROR, 'Phase 1 Blackthorn error: ' + ex.getMessage());
                }
            }
        }

        // ALUMNI_PRIVACY: remove from preference set before bucketing
        // so preferenceCount and the page slice are both accurate.
        preferenceAttendingIds.removeAll(privacyContactIds);

        // ── Sort preference IDs by preference bucket + last name ───
        // Fetch last names only for the preference set
        Map<Id, String> lastNameMap = new Map<Id, String>();
        if (!preferenceAttendingIds.isEmpty()) {
            for (Contact c : [SELECT Id, LastName FROM Contact WHERE Id IN :preferenceAttendingIds]) {
                lastNameMap.put(c.Id, c.LastName != null ? c.LastName.toLowerCase() : '');
            }
        }

        Map<Integer, List<Id>> buckets = new Map<Integer, List<Id>>{
            1 => new List<Id>(), 2 => new List<Id>(),
            3 => new List<Id>(), 4 => new List<Id>(),
            5 => new List<Id>()
        };
        for (Id attId : preferenceAttendingIds) {
            HAM_Connection__c conn = ConnectionMap.get(attId);

            if (conn.HAM_Is_Connected__c && conn.HAM_Is_favorite__c) {
                buckets.get(1).add(attId);
            } else if (conn.HAM_Is_Connected__c && conn.HAM_Is_bookmarked__c) {
                buckets.get(2).add(attId);
            } else if (conn.HAM_Is_Connected__c) {
                buckets.get(3).add(attId);
            } else if (conn.HAM_Is_bookmarked__c) {
                buckets.get(4).add(attId);
            } else {
                buckets.get(5).add(attId);
            }
        }

        // Bubble-sort each bucket alphabetically by last name (same algorithm as existing helpers)
        for (Integer b : new List<Integer>{1, 2, 3, 4, 5}) {
            List<Id> bucket = buckets.get(b);
            for (Integer i = 0; i < bucket.size() - 1; i++) {
                for (Integer j = 0; j < bucket.size() - i - 1; j++) {
                    String nA = lastNameMap.containsKey(bucket[j])   ? lastNameMap.get(bucket[j])   : '';
                    String nB = lastNameMap.containsKey(bucket[j+1]) ? lastNameMap.get(bucket[j+1]) : '';
                    if (nA > nB) {
                        Id tmp = bucket[j]; bucket[j] = bucket[j+1]; bucket[j+1] = tmp;
                    }
                }
            }
        }

        List<Id> sortedPreferenceIds = new List<Id>();
        sortedPreferenceIds.addAll(buckets.get(1));
        sortedPreferenceIds.addAll(buckets.get(2));
        sortedPreferenceIds.addAll(buckets.get(3));
        sortedPreferenceIds.addAll(buckets.get(4));
        sortedPreferenceIds.addAll(buckets.get(5));
        Integer preferenceCount = sortedPreferenceIds.size();

        // ════════════════════════════════════════════════════════════════════
        // PHASE 2 — non-preference total count ("all" mode only)
        // Only a COUNT query here — no rows returned, no limit risk
        // ════════════════════════════════════════════════════════════════════
        Integer nonPreferenceCount = 0;
        Set<Id> preferenceAttendingSet = new Set<Id>(preferenceAttendingIds); // SOQL bind
        // Also exclude ALUMNI_PRIVACY contacts from Phase 2 count so totalAttendeeCount
        // is accurate and pagination has no gaps.
        preferenceAttendingSet.addAll(privacyContactIds);
        preferenceAttendingSet.addAll(blockedContactIds);

        if (!connectionsOnly) {
            String countQ;
            if (objectApi == HAM_ConstantsUtil.CVENT_OBJECT_API) {
                countQ = 'SELECT COUNT_DISTINCT(CventEvents__Contact__c) uniqueCount FROM CventEvents__Attendee__c'
                       + ' WHERE CventEvents__Event__c = :eventId'
                       + ' AND CventEvents__Contact__c NOT IN :preferenceAttendingSet'
                       + ' AND CventEvents__Contact__c != :ConstituentId';
                if (likeKey != null) countQ += ' AND CventEvents__Contact__r.Name LIKE :likeKey';
            } else {
                countQ = 'SELECT COUNT_DISTINCT(conference360__Contact__c) uniqueCount FROM conference360__Attendee__c'
                       + ' WHERE conference360__Event__c = :eventId'
                       + ' AND conference360__Contact__c NOT IN :preferenceAttendingSet'
                       + ' AND conference360__Contact__c != :ConstituentId';
                if (likeKey != null) countQ += ' AND conference360__Contact__r.Name LIKE :likeKey';
            }
            

            try {
                List<AggregateResult> countResult = Database.query(countQ);
                nonPreferenceCount = (countResult.isEmpty()) ? 0 : (Integer) countResult[0].get('uniqueCount');
            } catch (Exception ex) { 
                System.debug(LoggingLevel.ERROR, 'Non-pref count error: ' + ex.getMessage()); 
            }
            
        }

        response.totalAttendeeCount = connectionsOnly
            ? preferenceCount
            : (preferenceCount + nonPreferenceCount);

        // ════════════════════════════════════════════════════════════════════
        // DETERMINE which contact IDs fall on the requested page
        // ════════════════════════════════════════════════════════════════════
        List<Id> pageIds = new List<Id>();

        // Slice from the preference block (if the page starts within it)
        if (safeOffset < preferenceCount) {
            Integer prefEnd = Math.min(safeOffset + safePageSize, preferenceCount);
            for (Integer i = safeOffset; i < prefEnd; i++) pageIds.add(sortedPreferenceIds[i]);
        }

        // Fill remaining slots from the non-preference block ("all" mode only).
        // Exclude by preferenceAttendingIds (the exact set of preference attendees found
        // for this event) rather than allConnectionMapIds (all connection-map members,
        // many of whom may not be attending). Using a copied Set<Id> — not keyset() view —
        // is required for reliable bind-variable behaviour in Database.query().

        if (!connectionsOnly && pageIds.size() < safePageSize) {
            Integer npOffset = Math.max(0, safeOffset - preferenceCount);
            
            if (npOffset > 2000){
                npOffset = 2000;
            }

            Integer npLimit  = safePageSize - pageIds.size();
            Set<Id> excludeIds = new Set<Id>(preferenceAttendingIds); // SOQL bind
            excludeIds.addAll(privacyContactIds); // also exclude ALUMNI_PRIVACY from data query
            excludeIds.addAll(blockedContactIds);

            String npQ;
            if (objectApi == HAM_ConstantsUtil.CVENT_OBJECT_API) {
                npQ = 'SELECT CventEvents__Contact__c, CventEvents__Contact__r.LastName'
                    + ' FROM CventEvents__Attendee__c'
                    + ' WHERE CventEvents__Event__c = :eventId'
                    + ' AND CventEvents__Contact__c NOT IN :excludeIds'
                    + ' AND CventEvents__Contact__c != :ConstituentId'
                    + ' AND CventEvents__Contact__c != null';

                if (likeKey != null) {
                    npQ += ' AND CventEvents__Contact__r.Name LIKE :likeKey';
                }

                npQ += ' GROUP BY CventEvents__Contact__c, CventEvents__Contact__r.LastName'
                    + ' ORDER BY CventEvents__Contact__r.LastName ASC NULLS LAST, CventEvents__Contact__c ASC'
                    + ' LIMIT :npLimit OFFSET :npOffset';

                try {
                    for (AggregateResult ar : Database.query(npQ)) {
                        pageIds.add((Id) ar.get('CventEvents__Contact__c'));
                    }
                } catch (Exception ex) {
                    System.debug(LoggingLevel.ERROR, 'NP Cvent data error: ' + ex.getMessage());
                }

            } else if (objectApi == HAM_ConstantsUtil.BLACKTHORN_OBJECT_API) {
                npQ = 'SELECT conference360__Contact__c, conference360__Contact__r.LastName'
                    + ' FROM conference360__Attendee__c'
                    + ' WHERE conference360__Event__c = :eventId'
                    + ' AND conference360__Contact__c NOT IN :excludeIds'
                    + ' AND conference360__Contact__c != :ConstituentId'
                    + ' AND conference360__Contact__c != null';

                if (likeKey != null) {
                    npQ += ' AND conference360__Contact__r.Name LIKE :likeKey';
                }

                npQ += ' GROUP BY conference360__Contact__c, conference360__Contact__r.LastName'
                    + ' ORDER BY conference360__Contact__r.LastName ASC NULLS LAST, conference360__Contact__c ASC'
                    + ' LIMIT :npLimit OFFSET :npOffset';

                try {
                    for (AggregateResult ar : Database.query(npQ)) {
                        pageIds.add((Id) ar.get('conference360__Contact__c'));
                    }
                } catch (Exception ex) {
                    System.debug(LoggingLevel.ERROR, 'NP Blackthorn data error: ' + ex.getMessage());
                }
            }
        }

        // ════════════════════════════════════════════════════════════════════
        // FETCH FULL CONTACT DATA — scoped to ≤6 page IDs only
        // Degree map + Contact query are both fully governor-safe here
        // ════════════════════════════════════════════════════════════════════
        if (!pageIds.isEmpty()) {

            // Contact data (only for the current page's contacts)
            Map<Id, Contact> contactMap = new Map<Id, Contact>([
                SELECT Id, ucinn_ascendv2__Expanded_Name_Formula__c, LastName,
                       HAM_Profile_Picture_URL__c, ucinn_ascendv2__Degree_Year_Formula__c,
                       ucinn_ascendv2__Is_Deceased__c
                FROM Contact
                WHERE Id IN :pageIds
            ]);

            // Build EventAttendee objects — iterate pageIds to preserve page order
            for (Id contactId : pageIds) {
                Contact c = contactMap.get(contactId);
                if (c == null) continue;

                EventAttendee att = new EventAttendee();
                att.attendeeId     = contactId;
                att.name           = c.ucinn_ascendv2__Expanded_Name_Formula__c;
                att.lastName       = c.LastName;
                String gradYr = c.ucinn_ascendv2__Degree_Year_Formula__c;
                att.graduationYear = (String.isBlank(gradYr) || gradYr == '0') ? '-' : gradYr;

                // ── Service Indicators ───────────────────────────────────────
                Set<String> attSI = serviceIndicatorMap.get(contactId);

                // PROFILEPIC_PRIVACY: null profile pic so LWC uses fallback image
                att.profilePic = (attSI != null && attSI.contains(PROFILEPIC_PRIVACY)) ? null: c.HAM_Profile_Picture_URL__c;

                if (ConnectionMap.containsKey(contactId)) {
                    HAM_Connection__c conn = ConnectionMap.get(contactId);
                    att.connectionStatus = conn.HAM_Connection_Status__c != null
                                          ? conn.HAM_Connection_Status__c : '-';
                    att.isBookmarked = conn.HAM_Is_bookmarked__c;
                    att.isConnected  = conn.HAM_Is_Connected__c;
                    att.isFavorite   = conn.HAM_Is_favorite__c;
                } else {
                    att.connectionStatus = '-';
                    att.isBookmarked     = false;
                    att.isConnected      = false;
                    att.isFavorite       = false;
                }

                // CONNECTION_PRIVACY: hide Send Request only when not yet connected
                att.hideConnectionRequest = (attSI != null && attSI.contains(CONNECTION_PRIVACY) && att.isConnected == false);

                // isRejected: other party rejected within the last 30 days — disable Send Request
                HAM_Connection__c secConn = SecondaryConnectionMap.get(contactId);
                if (secConn != null && secConn.HAM_Rejected_Date__c != null
                    && Math.abs(Date.today().daysBetween(secConn.HAM_Rejected_Date__c)) <= 30
                ) {
                    att.isRejected = true;
                } else {
                    att.isRejected = false;
                }

                att.isDeceased = c.ucinn_ascendv2__Is_Deceased__c == true;

                response.eventAttendees.add(att);
            }
        }

        // Order is already correct:
        // preference IDs  → sorted by bucket priority + last name (in-memory)
        // non-preference  → sorted by last name ASC via SOQL ORDER BY
        // No post-sort needed.
        return response;
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // FILTER METADATA
    // ─────────────────────────────────────────────────────────────────────────
    public class FilterWrapper {
        @AuraEnabled public String fieldApiName;
        @AuraEnabled public String placeholder;
        @AuraEnabled public String type;
        @AuraEnabled public String order;
        @AuraEnabled public List<String> values;
    }

    @AuraEnabled(cacheable=true)
    public static List<FilterWrapper> getFilterMetadataAndValues() {
        List<Ham_Events_Filter_Metadata__mdt> filtersMetadata = [
            SELECT Id, Label, HAM_Reference_Object_API__c, HAM_Reference_Field_API__c,
                   HAM_Direct_Filter__c, HAM_Order__c, HAM_Reference_Values__c,
                   HAM_Placeholder__c, HAM_Reference_Type__c
            FROM Ham_Events_Filter_Metadata__mdt
            WHERE Is_Active__c = TRUE
            ORDER BY HAM_Order__c
        ];
        
        List<FilterWrapper> filterWrappers = new List<FilterWrapper>();
        
        for (Ham_Events_Filter_Metadata__mdt filterMdt : filtersMetadata) {
            FilterWrapper fw = new FilterWrapper();
            fw.fieldApiName = filterMdt.HAM_Reference_Field_API__c;
            fw.placeholder = filterMdt.HAM_Placeholder__c;
            fw.type = filterMdt.HAM_Reference_Type__c;
            fw.order = filterMdt.HAM_Order__c;
            fw.values = new List<String>();

            if (filterMdt.HAM_Reference_Type__c == 'Picklist') {
                fw.values = getPicklistValues(filterMdt.HAM_Reference_Object_API__c, filterMdt.HAM_Reference_Field_API__c);
            } else if (String.isNotBlank(filterMdt.HAM_Reference_Values__c)) {
                fw.values.addAll(filterMdt.HAM_Reference_Values__c.split('[,;\\n]+'));
                for (Integer i = 0; i < fw.values.size(); i++) {
                    fw.values[i] = fw.values[i].trim();
                }
            }
            filterWrappers.add(fw);
        }
        return filterWrappers;
    }

    @TestVisible
    private static List<String> getPicklistValues(String sObjName, String fieldName) {
        List<String> values = new List<String>();
        try {
            Schema.SObjectType s = Schema.getGlobalDescribe().get(sObjName);
            Schema.DescribeSObjectResult r = s.getDescribe();
            Map<String, Schema.SObjectField> fields = r.fields.getMap();
            if (fields.containsKey(fieldName)) {
                for (Schema.PicklistEntry p : fields.get(fieldName).getDescribe().getPicklistValues()) {
                    if (p.isActive()) values.add(p.getValue());
                }
            }
        } catch (Exception e) { 
            System.debug(LoggingLevel.error, 'Picklist Error: ' + e.getMessage()); 
        }
        return values;
    }

    private static String buildWhereClause(List<Map<String, Object>> filters) {
        List<String> conditions = new List<String>();
        if (filters != null) {
            for (Map<String, Object> f : filters) {
                String fieldApiName  = (String) f.get('fieldApiName');
                List<Object> valuesObj = (List<Object>) f.get('values');
                if (String.isBlank(fieldApiName) || valuesObj == null || valuesObj.isEmpty()) continue;

                List<String> safeValues = new List<String>();
                Boolean hasAnytown = false;

                for (Object val : valuesObj) {
                    String strVal = String.valueOf(val);
                    safeValues.add('\'' + String.escapeSingleQuotes(strVal) + '\'');
                    if (strVal.equalsIgnoreCase('Anytown')) {
                        hasAnytown = true;
                    }
                }

                String condition = fieldApiName + ' IN (' + String.join(safeValues, ',') + ')';

                // When "Anytown" is selected, also pull in records with a
                // blank region so general/unassigned events aren't missed.
                // Wrapping in parentheses ensures the OR is scoped only to this field's
                // condition and doesn't bleed into other filter conditions.
                if (hasAnytown) {
                    condition = '(' + condition + ' OR ' + fieldApiName + ' = null)';
                }

                conditions.add(condition);
            }
        }
        return conditions.isEmpty() ? '' : ' AND ' + String.join(conditions, ' AND ');
    }

    @TestVisible
    private static String buildBlackthornEventTypeClause(List<String> eventTypeValues) {
        boolean hasVirtual  = false;
        boolean hasInPerson = false;
        for (String val : eventTypeValues) {
            if (val.equalsIgnoreCase('Virtual'))   hasVirtual  = true;
            if (val.equalsIgnoreCase('In-Person')) hasInPerson = true;
            // 'Hybrid' has no Blackthorn equivalent — ignored in clause
        }
        if (hasVirtual && hasInPerson) return '';                         // all BT events qualify
        if (hasVirtual)                return ' AND conference360__Calendar_Location__c != null';
        if (hasInPerson)               return ' AND conference360__Calendar_Location__c = null';
        return null; // only Hybrid selected — signal to skip Blackthorn entirely
    }

    // ─────────────────────────────────────────────────────────────────────────
    // CREATE TASK FOR RECORDING
    // ─────────────────────────────────────────────────────────────────────────
    @AuraEnabled
    public static String createTaskForRecording(Id eventId, Id constituentId, String objectApi) {
        String returnValue;
        
        Id taskOwnerId = getTaskOwnerId();
        if (taskOwnerId == null) {
            return 'Error - Task Owner not found';
        }

        String taskResult  = createTask(eventId, taskOwnerId, constituentId);
        if (taskResult .contains('Error')) {
            return taskResult ;
        }

        sendEmailForRecordingRequest(eventId, constituentId, objectApi);
        return 'Success';
    }

    private static Id getTaskOwnerId() {
        String TaskOwnerName = System.Label.ham_TaskOwnerName;
        if (String.isBlank(TaskOwnerName)) return null;
        List<User> Users = [SELECT Id FROM User WHERE IsActive = TRUE AND Name LIKE :('%' + TaskOwnerName + '%') LIMIT 1];
        return Users.isEmpty() ? null : Users[0].Id;
    }

    private static String createTask(Id eventId, Id ownerId, Id constituentId) {
        String TaskSubject = System.label.ham_recordingRequestTaskSubject;
        Task task = new Task(
            WhatId  = eventId,
            WhoId   = constituentId,
            OwnerId = ownerId,
            Subject = TaskSubject,
            Status  = 'Not Started'
        );
        try {
            insert task;
            return 'Success';
        } catch (Exception ex) {
            System.debug('Error creating task: ' + ex.getMessage());
            return 'Error creating task: ' + ex.getMessage();
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // EMAIL FOR RECORDING REQUEST
    // ─────────────────────────────────────────────────────────────────────────
    private static void sendEmailForRecordingRequest(Id eventId, Id constituentId, String objectApi) {
        
        String OWFromAddress = System.label.ham_OrgWideFromAddr;
        String RecordingRequestToAddr = System.label.ham_RecordingReqToAddr;

        EmailTemplate template = [SELECT Id, Subject, Body, HtmlValue FROM EmailTemplate WHERE DeveloperName = 'Ham_Event_Request_Template' LIMIT 1];

        String subject = template.Subject;
        String body = template.Body;

        SObject who = Database.query('SELECT Name, Email FROM Contact WHERE Id = :constituentId');
        String userName = (String) who.get('Name');
        String userEmail = (String) who.get('Email');

        String eventName;
        String eventDate;
        String eventLocation;
        String baseUrl  = URL.getOrgDomainUrl().toExternalForm();
        String recordUrl = baseUrl + '/' + eventId;

        if (objectApi == HAM_ConstantsUtil.CVENT_OBJECT_API) {
            CventEvents__Event__c ev = [SELECT CventEvents__pkg_Title__c, CventEvents__pkg_StartDate__c, CventEvents__pkg_Location__c
                                        FROM CventEvents__Event__c WHERE Id = :eventId LIMIT 1];
            eventName = '<a href="' + recordUrl + '">' + ev.CventEvents__pkg_Title__c + '</a>';
            eventDate = ev.CventEvents__pkg_StartDate__c != null ? ev.CventEvents__pkg_StartDate__c.format() : '';
            eventLocation = ev.CventEvents__pkg_Location__c;
        } else if (objectApi == HAM_ConstantsUtil.BLACKTHORN_OBJECT_API) {
            conference360__Event__c ev = [SELECT Name, conference360__Event_Start_Date__c, conference360__Venue_Name__c
                                          FROM conference360__Event__c WHERE Id = :eventId LIMIT 1];
            eventName = '<a href="' + recordUrl + '">' + ev.Name + '</a>';
            eventDate = ev.conference360__Event_Start_Date__c != null ? ev.conference360__Event_Start_Date__c.format() : '';
            eventLocation = ev.conference360__Venue_Name__c;
        }

        String requestDateTime = System.now().format();
        body = eventName != null ? body.replace('[EventName]', eventName) : body.replace('[EventName]', '-');
        body = eventDate != null ? body.replace('[EventDate]', eventDate) : body.replace('[EventDate]', '-');
        body = eventLocation != null ? body.replace('[EventLocation]', eventLocation) : body.replace('[EventLocation]', '-');
        body = userName != null ? body.replace('[UserName]', userName) : body.replace('[UserName]', '-');
        body = userEmail != null ? body.replace('[UserEmail]', userEmail) : body.replace('[UserEmail]', '-');
        body = body.replace('[DateTime]]', requestDateTime);

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[] {RecordingRequestToAddr});
        mail.setSubject(subject);
        mail.setHtmlBody(body);

        
        // Relate the email to the event and the constituent
        mail.setWhatId(eventId);        //links email to the event record
        mail.setTargetObjectId(constituentId);  // links email to the Contact. This is required when we use setWhatId.
        mail.setSaveAsActivity(true);  // Saving as an activity log on both event and contact
        

        OrgWideEmailAddress owea = [SELECT Id FROM OrgWideEmailAddress WHERE Address = :OWFromAddress LIMIT 1];
        mail.setOrgWideEmailAddressId(owea.Id);
        //mail.setSaveAsActivity(false);
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
    }
}