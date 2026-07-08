/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : Ham_UpcomingEventsController
 * Author          : Immanuel
 * Created Date    : May 11, 2026
 * Description     : Apex controller for the ham_upcomingEvents LWC on the Home Page.
 *                   Fetches upcoming CventEvents__Event__c records split into two
 *                   lists — In-Person (region + category filtered) and Virtual —
 *                   so the LWC can switch between them via toggle without extra calls.
 *
 * Data sources:
 *   Object   : CventEvents__Event__c
 *   Metadata : Ham_Events_Metadata__mdt  (Field_Label__c → Field_API_Name__c)
 *   Label    : ham_homeEvents_Categories (comma-separated, e.g. "Reunion,Homecoming")
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
        @AuraEnabled public List<EventItem> inPersonEvents;
        @AuraEnabled public List<EventItem> virtualEvents;

        public HomeEventsWrapper() {
            this.inPersonEvents = new List<EventItem>();
            this.virtualEvents  = new List<EventItem>();
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
        @AuraEnabled public String  registrationLink;   // CventEvents__pkg_RegistrationLink__c — used when NOT registered
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
    private static final String LABEL_FORMAT           = 'Format';
    private static final String LABEL_CATEGORY         = 'Category';
    private static final String LABEL_REGION           = 'Region';

    private static final String CVENT_OBJECT_API       = 'CventEvents__Event__c';
    private static final String FORMAT_IN_PERSON       = 'In-Person';
    private static final String FORMAT_VIRTUAL         = 'Virtual';
    private static final Integer MAX_RECORDS           = 3;        // desktop cap; mobile slicing done in LWC

    // ─────────────────────────────────────────────────────────────────────────
    // PUBLIC WIRE METHOD
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @description Fetches upcoming In-Person and Virtual Cvent events for the
     *              Home Page widget.
     *
     *  In-Person rules (preference order):
     *    1st — ADVEventCategories__c IN (ham_homeEvents_Categories) — no region filter.
     *          If any matches (1–3) are found, these are returned and no further query runs.
     *    2nd — Only when 0 category matches: ADVPrimaryRegion__c IN (user's regions).
     *          If >= 3 region matches → return 3.
     *          If 1–2 region matches → return those + gap-fill remaining slots with
     *          any upcoming In-Person events (no region/category restriction).
     *    Both paths apply: ADVPublicPrivate__c = 'Public',
     *          CventEvents__pkg_Status__c NOT IN ('Pending','Cancelled','Deleted'),
     *          "upcoming" filter (below), ORDER BY StartDate ASC LIMIT 3.
     *
     *  Virtual rules:
     *    - ADVEventFormat__c = 'Virtual'
     *    - ADVPublicPrivate__c = 'Public' AND CventEvents__pkg_Status__c NOT IN ('Pending','Cancelled','Deleted')
     *    - "upcoming" filter (below)
     *    - ORDER BY StartDate ASC LIMIT 3
     *
     *  "Upcoming" filter (applies to both In-Person and Virtual):
     *    - EndDate populated and > TODAY  →  upcoming
     *    - EndDate blank                  →  fall back to StartDate >= TODAY
     *    - Time fields are not considered — only date values are compared.
     *
     * @param contactId  Contact Id of the logged-in portal user (@api from LWC)
     * @return HomeEventsWrapper with inPersonEvents and virtualEvents lists
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
        String titleApi        = fieldLabelToApi.get(LABEL_EVENT_NAME);
        String imageApi        = fieldLabelToApi.get(LABEL_IMAGE);
        String startDateApi    = fieldLabelToApi.get(LABEL_START_DATE);
        String endDateApi      = fieldLabelToApi.get(LABEL_END_DATE);
        String locationApi     = fieldLabelToApi.get(LABEL_PLACE);
        String descriptionApi  = fieldLabelToApi.get(LABEL_DESCRIPTION);
        String regLinkApi      = fieldLabelToApi.get(LABEL_REG_LINK);
        String formatApi       = fieldLabelToApi.get(LABEL_FORMAT);
        String categoryApi     = fieldLabelToApi.get(LABEL_CATEGORY);
        String regionApi       = fieldLabelToApi.get(LABEL_REGION);

        // Guard: format field is essential for both queries
        if (String.isBlank(formatApi) || String.isBlank(startDateApi)) {
            System.debug('Ham_UpcomingEventsController: Required metadata fields (Format / StartDate) are missing.');
            return result;
        }

        // ── 2. Get logged-in user's regions from Contact ─────────────────────
        // HAM_Current_Regions__c is a multiselect picklist — stored semicolon-delimited
        List<String> userRegions = new List<String>();
        List<Contact> contacts = [
            SELECT HAM_Current_Regions__c
            FROM Contact
            WHERE Id = :contactId
            LIMIT 1
        ];
        if (!contacts.isEmpty() && String.isNotBlank(contacts[0].HAM_Current_Regions__c)) {
            for (String region : contacts[0].HAM_Current_Regions__c.split(';')) {
                String trimmed = region.trim();
                if (String.isNotBlank(trimmed)) {
                    userRegions.add(trimmed);
                }
            }
        }

        //System.debug('Events home userRegions: '+userRegions);

        // ── 3. Get allowed event categories from custom label ────────────────
        // ham_homeEvents_Categories is comma-separated e.g. "Reunion,Homecoming"
        List<String> allowedCategories = new List<String>();
        String categoriesLabel = System.Label.ham_homeEvents_Categories;
        if (String.isNotBlank(categoriesLabel)) {
            for (String cat : categoriesLabel.split(',')) {
                String trimmed = cat.trim();
                if (String.isNotBlank(trimmed)) {
                    allowedCategories.add(trimmed);
                }
            }
        }


        // ── 4. Build shared query parts ──────────────────────────────────────
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

        // Base conditions applied to every query
        String baseConditions = ' WHERE ' + System.Label.Ham_CventsWhereClause + ' AND ' + upcomingFilter;
        String orderAndLimit  = ' ORDER BY ' + startDateApi + ' ASC LIMIT ' + MAX_RECORDS;

        // ── 5. Query In-Person events — 3-step preference logic ─────────────
        //
        //  Step A (1st preference): Category IN (Reunion/Homecoming), no region filter.
        //                           → 3 results : done.
        //                           → 1–2 results: carry forward; Step B fills remaining slots.
        //                           → 0 results  : Step B fills all 3 slots.
        //
        //  Step B (2nd preference): Region IN (user's regions), no category filter.
        //                           Only queries for the remaining slots after Step A.
        //                           Already-fetched IDs are excluded.
        //
        //  Gap-fill (last resort):  If slots are still empty after A + B,
        //                           pick earliest upcoming In-Person events with
        //                           no region/category restriction.
        //                           Already-fetched IDs are excluded.
        // ─────────────────────────────────────────────────────────────────────────
        List<CventEvents__Event__c> inPersonRecords = new List<CventEvents__Event__c>();

        String inPersonBase = baseConditions
            + ' AND ' + formatApi + ' = \'' + FORMAT_IN_PERSON + '\'';

        // ── Step A: Category-first query (no region restriction) ─────────────
        if (!allowedCategories.isEmpty() && String.isNotBlank(categoryApi)) {

            String categoryWhere = inPersonBase
                + ' AND ' + categoryApi + ' IN :allowedCategories';

            String categoryQuery = selectClause + fromClause + categoryWhere + orderAndLimit;
            //System.debug('Events home — Step A categoryQuery: ' + categoryQuery);

            try {
                inPersonRecords = Database.query(categoryQuery);
            } catch (Exception e) {
                System.debug('Ham_UpcomingEventsController — Step A (category) query error: ' + e.getMessage());
            }
        }

        // ── Step B: Region query — fills remaining slots after Step A ─────────
        // Runs whether Step A returned 0, 1, or 2 — as long as slots remain.
        if (inPersonRecords.size() < MAX_RECORDS && !userRegions.isEmpty() && String.isNotBlank(regionApi)) {

            Set<Id> fetchedIds = new Map<Id, SObject>(inPersonRecords).keySet();
            Integer needed     = MAX_RECORDS - inPersonRecords.size();

            String regionWhere = inPersonBase
                + ' AND ' + regionApi + ' IN :userRegions'
                + (fetchedIds.isEmpty() ? '' : ' AND Id NOT IN :fetchedIds');

            String regionQuery = selectClause + fromClause + regionWhere
                + ' ORDER BY ' + startDateApi + ' ASC LIMIT :needed';
            //System.debug('Events home — Step B regionQuery: ' + regionQuery);

            try {
                List<CventEvents__Event__c> regionRecords = Database.query(regionQuery);
                inPersonRecords.addAll(regionRecords);
            } catch (Exception e) {
                System.debug('Ham_UpcomingEventsController — Step B (region) query error: ' + e.getMessage());
            }
        }

        // ── Gap-fill: no region/category filter — fills any remaining slots ───
        // Runs only if Step A + Step B together returned fewer than 3 records.
        // Picks the earliest upcoming In-Person events, excluding already fetched IDs.
        if (inPersonRecords.size() < MAX_RECORDS) {

            Set<Id> fetchedIds = new Map<Id, SObject>(inPersonRecords).keySet();
            Integer needed     = MAX_RECORDS - inPersonRecords.size();

            String fillWhere = inPersonBase
                + (fetchedIds.isEmpty() ? '' : ' AND Id NOT IN :fetchedIds');

            String fillQuery = selectClause + fromClause + fillWhere
                + ' ORDER BY ' + startDateApi + ' ASC LIMIT :needed';

            try {
                List<CventEvents__Event__c> fillRecords = Database.query(fillQuery);
                inPersonRecords.addAll(fillRecords);
            } catch (Exception e) {
                System.debug('Ham_UpcomingEventsController — gap-fill query error: ' + e.getMessage());
            }
        }

        result.inPersonEvents = mapToEventItems(
            inPersonRecords, titleApi, imageApi, startDateApi,
            endDateApi, locationApi, descriptionApi, regLinkApi
        );

        // ── 6. Query Virtual events ──────────────────────────────────────────
        String virtualWhere = baseConditions
            + ' AND ' + formatApi + ' = \'' + FORMAT_VIRTUAL + '\'';

        String virtualQuery = selectClause + fromClause + virtualWhere + orderAndLimit;

        try {
            List<CventEvents__Event__c> virtualRecords = Database.query(virtualQuery);
            result.virtualEvents = mapToEventItems(
                virtualRecords, titleApi, imageApi, startDateApi,
                endDateApi, locationApi, descriptionApi, regLinkApi
            );
        } catch (Exception e) {
            System.debug('Ham_UpcomingEventsController — Virtual query error: ' + e.getMessage());
        }

        // ──with registration status ──────────────────────────────
        // Query CventEvents__Attendee__c once for ALL event IDs in both lists,
        // then flag each EventItem that the logged-in user has already registered for.
        //
        // Note: getHomePageEvents is non-cacheable (imperative call from LWC) so
        // registration status is always fresh on each page load.
        List<EventItem> allItems = new List<EventItem>();
        allItems.addAll(result.inPersonEvents);
        allItems.addAll(result.virtualEvents);

        Set<Id> eventIds = new Set<Id>();
        for (EventItem item : allItems) {
            if (String.isNotBlank(item.id)) {
                eventIds.add((Id) item.id);
            }
        }

        if (!eventIds.isEmpty()) {
            // Map: Event Id → personalized registration link from the attendee record
            Map<Id, String> eventIdToPersonalizedLink = new Map<Id, String>();

            for (CventEvents__Attendee__c att : [
                SELECT CventEvents__Event__c,
                       CventEvents__PersonalizedRegistrationLink__c
                FROM   CventEvents__Attendee__c
                WHERE  CventEvents__Event__c   IN :eventIds
                AND    CventEvents__Contact__c  = :contactId
            ]) {
                eventIdToPersonalizedLink.put(
                    att.CventEvents__Event__c,
                    att.CventEvents__PersonalizedRegistrationLink__c != null
                        ? att.CventEvents__PersonalizedRegistrationLink__c
                        : ''
                );
            }

            // Stamp isRegistered + personalizedLink on every matching EventItem
            for (EventItem item : allItems) {
                if (eventIdToPersonalizedLink.containsKey((Id) item.id)) {
                    item.isRegistered     = true;
                    item.personalizedLink = eventIdToPersonalizedLink.get((Id) item.id);
                }
            }
        }

        //System.debug('Events home result: '+result);
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
        String regLinkApi
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
            item.registrationLink = getStringField(rec, regLinkApi);
            item.isRegistered     = false; 
            item.personalizedLink = '';
            items.add(item);
        }

        return items;
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
}