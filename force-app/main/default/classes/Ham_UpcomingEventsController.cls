/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : Ham_UpcomingEventsController
 * Author          : Immanuel
 * Created Date    : May 11, 2026
 * Description     : Apex controller for the ham_upcomingEvents LWC on the Home Page.
 *                   Fetches upcoming CventEvents__Event__c records split into two
 *                   lists — My Events (the user is registered) and Other Events —
 *                   so the LWC can switch between them via toggle without extra calls.
 *
 * Data sources:
 *   Object   : CventEvents__Event__c, CventEvents__Attendee__c (registration)
 *   Metadata : Ham_Events_Metadata__mdt  (Field_Label__c → Field_API_Name__c)
 *   Label    : Ham_CventsWhereClause     (Public / active status conditions)
 *
 * Change History  :
 *  Date          │ Author  │ Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  May 11, 2026  │ Immanuel  │ Initial version
 *  May 20, 2026  │ Immanuel  │ Fix: Rewrote In-Person query to honour ticket preference order —
 *                             category-first (no region), region fallback only when 0 category
 *                             matches, gap-fill only within the region-fallback path.
 *  Jul 1, 2026   │ Immanuel  │ Change: "Upcoming" is now determined by EndDate (when populated
 *                             and > today) instead of StartDate; StartDate >= today remains the
 *                             fallback when EndDate is blank. Time fields are no longer considered.
 *  Jul 9, 2026   │ Immanuel  │ Change: NOT-registered button URL now prefers
 *                             ADVEssentialsURLforascend__c (metadata label "RegistrationLink1")
 *                             when populated, falling back to CventEvents__pkg_RegistrationLink__c.
 *                             Registered-event URL logic (personalizedLink) is unchanged.
 *  Sep 3, 2026   │ Anirudh   │ Added getHomePageEventThumbnail for the home page Events
 *                             redirection card.
 *  Sep 9, 2026   │ Anirudh   │ Change: toggle lists are now My Events (registered) and
 *                             Other Events, replacing In-Person / Virtual. Region and
 *                             category preference ordering removed; Blackthorn events
 *                             stay excluded as all upcoming events are created in Cvent.
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */
@SuppressWarnings('PMD.NoTrailingWhitespace, PMD.ExcessiveClassLength, PMD.ApexDoc, PMD.DebugsShouldUseLoggingLevel, PMD.ApexCRUDViolation, PMD.AvoidNonRestrictiveQueries, PMD.CyclomaticComplexity, PMD.CognitiveComplexity, PMD.NcssCount, PMD.ApexSOQLInjection, PMD.AvoidDebugStatements')
public without sharing class Ham_UpcomingEventsController {

    // ─────────────────────────────────────────────────────────────────────────
    // WRAPPER CLASSES
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Top-level wrapper returned to the LWC.
     * Splitting into two lists lets the toggle switch instantly in JS
     * without needing a second Apex call.
     */
    public class HomeEventsWrapper {
        @AuraEnabled public List<EventItem> myEvents;      // registered
        @AuraEnabled public List<EventItem> otherEvents;   // everything else

        public HomeEventsWrapper() {
            this.myEvents    = new List<EventItem>();
            this.otherEvents = new List<EventItem>();
        }
    }

    /** Flat event record passed to the LWC card renderer. */
    public class EventItem {
        @AuraEnabled public String  id;
        @AuraEnabled public String  title;
        @AuraEnabled public String  imageUrl;
        @AuraEnabled public String  startDate;          // 'YYYY-MM-DD' — formatted in LWC
        @AuraEnabled public String  endDate;            // 'YYYY-MM-DD' — formatted in LWC
        @AuraEnabled public String  location;
        @AuraEnabled public String  description;
        @AuraEnabled public String  registrationLink;   // NOT registered: ADVEssentialsURLforascend__c if populated, else CventEvents__pkg_RegistrationLink__c
        @AuraEnabled public Boolean isRegistered;       // true when the logged-in user has an Attendee record for this event
        @AuraEnabled public String  personalizedLink;   // CventEvents__PersonalizedRegistrationLink__c — used when registered
    }

    // ─────────────────────────────────────────────────────────────────────────
    // CONSTANTS — Field Label keys (must match Ham_Events_Metadata__mdt records)
    // ─────────────────────────────────────────────────────────────────────────
    private static final String LABEL_EVENT_NAME       = 'EventName';
    private static final String LABEL_IMAGE            = 'ImageURL';
    private static final String LABEL_START_DATE       = 'StartDate';
    private static final String LABEL_END_DATE         = 'EndDate';
    private static final String LABEL_PLACE            = 'Place';
    private static final String LABEL_DESCRIPTION      = 'Description';
    private static final String LABEL_REG_LINK         = 'RegistrationLink';
    private static final String LABEL_ESSENTIALS_LINK  = 'RegistrationLink1';   // ADVEssentialsURLforascend__c — preferred over LABEL_REG_LINK when not registered

    private static final String CVENT_OBJECT_API       = 'CventEvents__Event__c';
    private static final Integer MAX_RECORDS           = 3;        // desktop cap; mobile slicing done in LWC

    // Home page redirection card: when the resolved event has no image, fall back to the
    // card's static production image rather than walking on to the next event.
    // Flip to true to skip imageless events instead (pending BA confirmation).
    private static final Boolean SKIP_EVENTS_WITHOUT_IMAGE = false;

    // ─────────────────────────────────────────────────────────────────────────
    // PUBLIC WIRE METHOD
    // ─────────────────────────────────────────────────────────────────────────
    /**
     * @description Fetches the upcoming Cvent events behind the Home Page widget's
     *              toggle, split into the two lists it shows:
     *
     *   My Events    — upcoming events the user is registered for, i.e. a
     *                  CventEvents__Attendee__c record exists for them.
     *   Other Events — every other upcoming event.
     *
     *  Both lists apply Ham_CventsWhereClause (Public, status not Pending/Cancelled/
     *  Deleted) and the "upcoming" filter below, ORDER BY StartDate ASC LIMIT 3.
     *
     *  "Upcoming" filter:
     *    - EndDate populated and > TODAY  →  upcoming
     *    - EndDate blank                  →  fall back to StartDate >= TODAY
     *    - Time fields are not considered — only date values are compared.
     *
     *  Blackthorn (conference360__Event__c) events are deliberately excluded: every
     *  upcoming event is now created in Cvent. The former In-Person region/category
     *  preference ordering was removed at the same time — both per the Sep 7, 2026
     *  decision to make the widget mirror the Events tab.
     *
     * @param contactId  Contact Id of the logged-in portal user (@api from LWC)
     * @return HomeEventsWrapper with myEvents and otherEvents lists
     */
    @AuraEnabled
    public static HomeEventsWrapper getHomePageEvents(String contactId) {

        HomeEventsWrapper result = new HomeEventsWrapper();

        if (String.isBlank(contactId)) {
            return result;
        }

        // ── 1. Build metadata field map ──────────────────────────────────────
        Map<String, String> fieldLabelToApi = new Map<String, String>();
        Set<String> selectFields = new Set<String>{ 'Id' };

        for (Ham_Events_Metadata__mdt mdt : [
            SELECT Field_Label__c, Field_API_Name__c
            FROM Ham_Events_Metadata__mdt
            WHERE Object_API_Name__c = :CVENT_OBJECT_API
              AND Object_Active__c   = true
              AND Field_Retrievable__c = true
        ]) {
            if (String.isNotBlank(mdt.Field_Label__c) && String.isNotBlank(mdt.Field_API_Name__c)) {
                fieldLabelToApi.put(mdt.Field_Label__c, mdt.Field_API_Name__c);
                selectFields.add(mdt.Field_API_Name__c);
            }
        }

        if (fieldLabelToApi.isEmpty()) {
            System.debug('Ham_UpcomingEventsController: No metadata records found for ' + CVENT_OBJECT_API);
            return result;
        }

        // Resolve field API names from metadata labels
        String titleApi          = fieldLabelToApi.get(LABEL_EVENT_NAME);
        String imageApi          = fieldLabelToApi.get(LABEL_IMAGE);
        String startDateApi      = fieldLabelToApi.get(LABEL_START_DATE);
        String endDateApi        = fieldLabelToApi.get(LABEL_END_DATE);
        String locationApi       = fieldLabelToApi.get(LABEL_PLACE);
        String descriptionApi    = fieldLabelToApi.get(LABEL_DESCRIPTION);
        String regLinkApi        = fieldLabelToApi.get(LABEL_REG_LINK);
        String essentialsLinkApi = fieldLabelToApi.get(LABEL_ESSENTIALS_LINK);

        // Guard: both queries order by start date, so it is essential
        if (String.isBlank(startDateApi)) {
            System.debug('Ham_UpcomingEventsController: Required metadata field (StartDate) is missing.');
            return result;
        }

        // ── 2. What the user is registered for ───────────────────────────────
        // One pass gives both the My/Other split and the personalized links the
        // "Modify Registration" button needs.
        Map<Id, String> eventIdToPersonalizedLink = new Map<Id, String>();

        for (CventEvents__Attendee__c att : [
            SELECT CventEvents__Event__c,
                   CventEvents__PersonalizedRegistrationLink__c
            FROM   CventEvents__Attendee__c
            WHERE  CventEvents__Contact__c = :contactId
            AND    CventEvents__Event__c  != null
        ]) {
            eventIdToPersonalizedLink.put(
                att.CventEvents__Event__c,
                att.CventEvents__PersonalizedRegistrationLink__c != null
                    ? att.CventEvents__PersonalizedRegistrationLink__c
                    : ''
            );
        }

        Set<Id> registeredEventIds = eventIdToPersonalizedLink.keySet();

        // ── 3. Shared query parts ────────────────────────────────────────────
        String selectClause = 'SELECT ' + String.join(new List<String>(selectFields), ', ');
        String fromClause   = ' FROM ' + CVENT_OBJECT_API;
        Date   today        = Date.today();

        // An event is upcoming if:
        //   EndDate is populated and > today  →  upcoming, regardless of StartDate
        //   EndDate is blank on the record     →  fall back to StartDate >= today
        // Falls back to StartDate >= today entirely if EndDate is not in metadata.
        // Time fields are intentionally ignored — only date values are compared.
        String upcomingFilter;
        if (String.isNotBlank(endDateApi)) {
            upcomingFilter = '((' + endDateApi + ' != null AND ' + endDateApi + ' > :today)'
                + ' OR (' + endDateApi + ' = null AND ' + startDateApi + ' >= :today))';
        } else {
            upcomingFilter = startDateApi + ' >= :today';
        }

        String baseConditions = ' WHERE ' + System.Label.Ham_CventsWhereClause + ' AND ' + upcomingFilter;
        String orderAndLimit  = ' ORDER BY ' + startDateApi + ' ASC LIMIT ' + MAX_RECORDS;

        // ── 4. My Events — upcoming events the user is registered for ────────
        List<CventEvents__Event__c> myRecords = new List<CventEvents__Event__c>();

        if (!registeredEventIds.isEmpty()) {
            String myQuery = selectClause + fromClause + baseConditions
                + ' AND Id IN :registeredEventIds' + orderAndLimit;

            try {
                myRecords = Database.query(myQuery);
            } catch (Exception e) {
                System.debug('Ham_UpcomingEventsController — My Events query error: ' + e.getMessage());
            }
        }

        // ── 5. Other Events — everything else that is upcoming ───────────────
        List<CventEvents__Event__c> otherRecords = new List<CventEvents__Event__c>();

        String otherQuery = selectClause + fromClause + baseConditions
            + (registeredEventIds.isEmpty() ? '' : ' AND Id NOT IN :registeredEventIds')
            + orderAndLimit;

        try {
            otherRecords = Database.query(otherQuery);
        } catch (Exception e) {
            System.debug('Ham_UpcomingEventsController — Other Events query error: ' + e.getMessage());
        }

        result.myEvents = mapToEventItems(
            myRecords, titleApi, imageApi, startDateApi, endDateApi,
            locationApi, descriptionApi, regLinkApi, essentialsLinkApi
        );

        result.otherEvents = mapToEventItems(
            otherRecords, titleApi, imageApi, startDateApi, endDateApi,
            locationApi, descriptionApi, regLinkApi, essentialsLinkApi
        );

        // ── 6. Stamp registration state on My Events ─────────────────────────
        // Every My Event is registered by definition, so the card shows "Modify
        // Registration" and links to the attendee's personalized link.
        for (EventItem item : result.myEvents) {
            String personalizedLink = eventIdToPersonalizedLink.get((Id) item.id);
            item.isRegistered     = true;
            item.personalizedLink = personalizedLink != null ? personalizedLink : '';
        }

        return result;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // PRIVATE HELPERS
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Maps a list of CventEvents__Event__c SObjects to EventItem wrappers
     * using the dynamically resolved field API names.
     * Date fields are returned as 'YYYY-MM-DD' strings (via String.valueOf(Date));
     * the LWC formatDate() helper converts them to display format.
     */
    private static List<EventItem> mapToEventItems(
        List<CventEvents__Event__c> records,
        String titleApi,
        String imageApi,
        String startDateApi,
        String endDateApi,
        String locationApi,
        String descriptionApi,
        String regLinkApi,
        String essentialsLinkApi
    ) {
        List<EventItem> items = new List<EventItem>();

        for (CventEvents__Event__c rec : records) {
            EventItem item       = new EventItem();
            item.id               = rec.Id;
            item.title            = getStringField(rec, titleApi);
            item.imageUrl         = getStringField(rec, imageApi);
            item.startDate        = getDateField(rec, startDateApi);
            item.endDate          = getDateField(rec, endDateApi);
            item.location         = getStringField(rec, locationApi);
            item.description      = getStringField(rec, descriptionApi);
            item.registrationLink = resolveRegistrationLink(rec, essentialsLinkApi, regLinkApi);
            item.isRegistered     = false;
            item.personalizedLink = '';
            items.add(item);
        }

        return items;
    }

    /**
     * Resolves the button URL for a NOT-registered event: prefers the
     * ADVEssentialsURLforascend__c metadata field (LABEL_ESSENTIALS_LINK) when populated,
     * otherwise falls back to CventEvents__pkg_RegistrationLink__c (LABEL_REG_LINK).
     * Registered-event URL logic (personalizedLink from the Attendee record) is unaffected.
     */
    private static String resolveRegistrationLink(SObject rec, String essentialsLinkApi, String regLinkApi) {
        String essentialsValue = getStringField(rec, essentialsLinkApi);
        if (String.isNotBlank(essentialsValue) && essentialsValue != '-') {
            return essentialsValue;
        }
        return getStringField(rec, regLinkApi);
    }

    /** Safely retrieves a String field value from an SObject. Returns '' on null/ '-' on missing. */
    private static String getStringField(SObject rec, String fieldApi) {
        if (String.isBlank(fieldApi)) return '';
        Object val = rec.get(fieldApi);
        return val != null ? String.valueOf(val) : '-';
    }

    /**
     * Safely retrieves a Date field value from an SObject.
     * Returns 'YYYY-MM-DD' string so the LWC formatDate() can parse it.
     * Returns '' if null or '-' on field API is blank.
     */
    private static String getDateField(SObject rec, String fieldApi) {
        if (String.isBlank(fieldApi)) return '';
        Object val = rec.get(fieldApi);
        return val != null ? String.valueOf(val) : '-';  // Date.valueOf() → 'YYYY-MM-DD'
    }

    // ─────────────────────────────────────────────────────────────────────────
    // HOME PAGE REDIRECTION CARD THUMBNAIL
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @description Resolves the image shown on the Home Page "Events" redirection card.
     *              Preference order:
     *                1. Next upcoming event the logged-in user is registered for.
     *                2. Next upcoming event overall.
     *              Registration is determined by an existing CventEvents__Attendee__c
     *              record, the same signal getHomePageEvents uses for isRegistered.
     *
     *              Deliberately independent of the In-Person / Virtual split used by
     *              getHomePageEvents so the card is unaffected when that widget changes.
     *
     *              When the resolved event has no image the method returns null and the
     *              LWC keeps its static production image — it does NOT walk on to the
     *              next event. Flip SKIP_EVENTS_WITHOUT_IMAGE to change that.
     *
     * @param contactId Contact Id of the logged-in portal user.
     * @return Image URL of the resolved event, or null when nothing resolves.
     */
    public static String getHomePageEventThumbnail(String contactId) {

        if (String.isBlank(contactId)) {
            return null;
        }

        // ── Resolve field API names from metadata (same source as getHomePageEvents) ──
        Map<String, String> fieldLabelToApi = new Map<String, String>();

        for (Ham_Events_Metadata__mdt mdt : [
            SELECT Field_Label__c, Field_API_Name__c
            FROM Ham_Events_Metadata__mdt
            WHERE Object_API_Name__c = :CVENT_OBJECT_API
              AND Object_Active__c   = true
              AND Field_Retrievable__c = true
        ]) {
            if (String.isNotBlank(mdt.Field_Label__c) && String.isNotBlank(mdt.Field_API_Name__c)) {
                fieldLabelToApi.put(mdt.Field_Label__c, mdt.Field_API_Name__c);
            }
        }

        String imageApi     = fieldLabelToApi.get(LABEL_IMAGE);
        String startDateApi = fieldLabelToApi.get(LABEL_START_DATE);
        String endDateApi   = fieldLabelToApi.get(LABEL_END_DATE);

        if (String.isBlank(imageApi) || String.isBlank(startDateApi)) {
            System.debug('Ham_UpcomingEventsController: Image / StartDate metadata missing for thumbnail.');
            return null;
        }

        Date today = Date.today();

        // Same "upcoming" rule as getHomePageEvents: EndDate when populated, else StartDate.
        String upcomingFilter;
        if (String.isNotBlank(endDateApi)) {
            upcomingFilter = '((' + endDateApi + ' != null AND ' + endDateApi + ' > :today)'
                + ' OR (' + endDateApi + ' = null AND ' + startDateApi + ' >= :today))';
        } else {
            upcomingFilter = startDateApi + ' >= :today';
        }

        String baseConditions = ' WHERE ' + System.Label.Ham_CventsWhereClause + ' AND ' + upcomingFilter;

        if (SKIP_EVENTS_WITHOUT_IMAGE) {
            baseConditions += ' AND ' + imageApi + ' != null';
        }

        String selectClause  = 'SELECT Id, ' + imageApi + ', ' + startDateApi;
        String orderAndLimit = ' ORDER BY ' + startDateApi + ' ASC LIMIT 1';

        // ── 1. Next upcoming event the user is registered for ────────────────
        Set<Id> registeredEventIds = new Set<Id>();

        for (CventEvents__Attendee__c att : [
            SELECT CventEvents__Event__c
            FROM   CventEvents__Attendee__c
            WHERE  CventEvents__Contact__c = :contactId
            AND    CventEvents__Event__c  != null
        ]) {
            registeredEventIds.add(att.CventEvents__Event__c);
        }

        if (!registeredEventIds.isEmpty()) {
            String registeredQuery = selectClause + ' FROM ' + CVENT_OBJECT_API
                + baseConditions + ' AND Id IN :registeredEventIds' + orderAndLimit;

            try {
                List<CventEvents__Event__c> registeredRecords = Database.query(registeredQuery);
                if (!registeredRecords.isEmpty()) {
                    return blankToNull(getStringField(registeredRecords[0], imageApi));
                }
            } catch (Exception e) {
                System.debug('Ham_UpcomingEventsController — registered thumbnail query error: ' + e.getMessage());
            }
        }

        // ── 2. Fallback: next upcoming event overall ─────────────────────────
        String upcomingQuery = selectClause + ' FROM ' + CVENT_OBJECT_API
            + baseConditions + orderAndLimit;

        try {
            List<CventEvents__Event__c> upcomingRecords = Database.query(upcomingQuery);
            if (!upcomingRecords.isEmpty()) {
                return blankToNull(getStringField(upcomingRecords[0], imageApi));
            }
        } catch (Exception e) {
            System.debug('Ham_UpcomingEventsController — upcoming thumbnail query error: ' + e.getMessage());
        }

        return null;
    }

    /**
     * getStringField returns '-' for a missing field API and '' for a null value;
     * neither is a usable image URL, so both collapse to null for the caller.
     */
    private static String blankToNull(String value) {
        return (String.isBlank(value) || value == '-') ? null : value;
    }
}