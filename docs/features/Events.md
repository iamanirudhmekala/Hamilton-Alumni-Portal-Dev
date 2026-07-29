# FEATURE METADATA MAP: EVENTS
*Last Synchronized: 2026-07-21 (Auto-verified against live repository)*

The Events feature surfaces Cvent (`CventEvents__Event__c`) and Blackthorn
(`conference360__Event__c`) events to logged-in portal users through two
front-end surfaces:

1. **Full Events page** — `ham_eventsCmp` (tabbed, paginated, filterable list with
   attendee/connection actions and "Host an Event" / "Request Recording" flows).
2. **Home Page widget** — `ham_upcomingEvents` (compact In-Person/Virtual toggle
   card that links out to registration and to the full Events page).

Both are dual-source and metadata-driven: which object/field is queried is
resolved at runtime from `Ham_Events_Metadata__mdt` (Field Label → Field API
Name), so no field API names are hard-coded in the queries.

## 1. Functional UI Behavior

### Full Events page (`ham_eventsCmp`)
- **User Action:** User lands on the Events tab. Chooses a **main tab**
  (Upcoming / Past) and a **sub tab** (My/Registered vs. Other/Non-Registered),
  types in the **search** box, and/or opens the **filter pills** (Event Type,
  Region, etc.). Clicks pagination to move between pages.
- **System Reaction:** The event grid re-queries reactively (via `@wire`) on any
  tab/search/filter/page change and renders event cards (image, title, date,
  place, connection-attendee preview stack).
- **User Action:** Clicks an event's primary button — **Register**, **Modify
  Registration**, or **Request Recording**.
- **System Reaction:** Register/Modify open the registration URL in a new tab;
  Request Recording calls Apex to create a Task + email and shows a confirmation
  modal (button then reads "Recording Requested" and is disabled).
- **User Action:** Clicks the attendee avatar stack or **Show All Attendees**.
- **System Reaction:** Opens a paginated, searchable attendees modal. Per
  attendee the user can **Bookmark**, **Favorite**, **Send/Cancel connection
  request**, **Remove connection**, view the profile overlay, or (for deceased
  alumni) open the **Necrology** link.
- **User Action:** Clicks **Host an Event** → confirms in the modal.
- **System Reaction:** Apex records a "Host an Event" funding interest and shows a
  success confirmation.

### Home Page widget (`ham_upcomingEvents`)
- **User Action:** Toggles **In Person / Virtual**, clicks a card or its
  **Register / Modify Registration** button, or clicks the **View All** arrow.
- **System Reaction:** Register opens the (personalized or package) registration
  URL in a new tab; View All dispatches the shared `navigateevent` so the parent
  page routes to the full Events page. Data is loaded imperatively (non-cacheable)
  the moment the parent supplies `usercontactId`, so registration status is fresh.

## 2. Discovered Execution Stack

### Frontend Layer
- Full page: [`ham_eventsCmp.html`](../../force-app/main/default/lwc/ham_eventsCmp/ham_eventsCmp.html) & [`ham_eventsCmp.js`](../../force-app/main/default/lwc/ham_eventsCmp/ham_eventsCmp.js)
- Home widget: [`ham_upcomingEvents.html`](../../force-app/main/default/lwc/ham_upcomingEvents/ham_upcomingEvents.html) & [`ham_upcomingEvents.js`](../../force-app/main/default/lwc/ham_upcomingEvents/ham_upcomingEvents.js)
- Shared child components: `c-ham_-pagination-util` (pagination),
  `c-ham_custom-toast-cmp` (toasts), `c-ham_alumni-profile-overview-cmp`
  (attendee profile overlay).

### Controller / Apex Layer
- [`HAM_EventsController.cls`](../../force-app/main/default/classes/HAM_EventsController.cls) — `public without sharing`
  - `getEventDetails()` *(cacheable)* → wired grid (main/sub tab, search, filters, OFFSET pagination)
  - `getEventAttendees()` → attendees modal (two-phase preference paging + search)
  - `getFilterMetadataAndValues()` *(cacheable)* → filter pill definitions/values
  - `createTaskForRecording()` → recording-request Task + email (→ `createTask()`, `sendEmailForRecordingRequest()`)
  - `confirmrequest()` → "Host an Event" funding-interest insert
- [`Ham_UpcomingEventsController.cls`](../../force-app/main/default/classes/Ham_UpcomingEventsController.cls) — `public without sharing`
  - `getHomePageEvents()` → home widget (Cvent-only; category→region→gap-fill preference logic; In-Person/Virtual split)
- Attendee connection actions delegate to
  [`HAM_AlumniConnectionService.cls`](../../force-app/main/default/classes/HAM_AlumniConnectionService.cls) —
  `handleConnectionRequest()` and `checkUserStatus()` (shared alumni-connection feature).

### Automation / Data Layer
- **Read objects:** `CventEvents__Event__c`, `conference360__Event__c` (events);
  `CventEvents__Attendee__c`, `conference360__Attendee__c` (attendees/registration);
  `HAM_Connection__c` (bookmark/favorite/connected/request-sent state);
  `ucinn_ascendv2__Service_Indicator__c` (privacy: alumni/connection/profile-pic);
  `Contact` (name, grad year, profile pic, deceased);
  `ucinn_ascendv2__Foundation_Funding_Interests__c` (Host an Event lookup);
  `Task`, `User`, `EmailTemplate`, `OrgWideEmailAddress`.
- **DML (writes):**
  - `insert Task` — recording request (`createTask`).
  - `insert ucinn_ascendv2__Funding_Interest__c` — Host an Event (`confirmrequest`),
    record type `Contact_Funding_Interest`.
  - `Messaging.sendEmail(...)` — recording-request notification (saved as Activity
    on the event + contact).
- **Custom Metadata:**
  - `Ham_Events_Metadata__mdt` — Field Label → Field API Name map per source object
    (e.g. `Cvents Total Capacity`, `Blackthorn Event Total Capacity`). Only rows
    with `Object_Active__c = true AND Field_Retrievable__c = true` are used.
  - `Ham_Events_Filter_Metadata__mdt` — active filter pill definitions (order,
    reference object/field, picklist vs. static values).
- **Custom Labels (feature toggles / config):** `Ham_IsCventsActive`,
  `Ham_IsBlackthornActive`, `Ham_CventsWhereClause`, `Ham_BlackThornWhereClause`,
  `ham_homeEvents_Categories`, `ham_EventsMainTab1/2`, `ham_EventsMainTab*SubTab*`,
  `ham_TaskOwnerName`, `ham_recordingRequestTaskSubject`, `ham_OrgWideFromAddr`,
  `ham_RecordingReqToAddr`, plus many UI-text labels.
- **Constants:** `HAM_ConstantsUtil` (`CVENT_OBJECT_API`, `BLACKTHORN_OBJECT_API`,
  `HOST_AN_EVENT`, and the three Service-Indicator IDs).
- **No triggers or Flows** are invoked by this feature.

## 3. Current Technical Logic Summary

1. The LWC supplies `userContactId` + tab/search/filter/page state; `getEventDetails`
   (cacheable `@wire`) resolves active field APIs from `Ham_Events_Metadata__mdt`
   and dynamically builds SOQL against Cvent and Blackthorn, gated by the
   `Ham_Is*Active` labels and their WHERE-clause labels.
2. The user's `HAM_Connection__c` rows and active `Service_Indicator__c` records
   drive attendee previews (max 3, preference-sorted) and privacy stripping
   (alumni/connection/profile-pic), while separate aggregate/count queries return
   true connection counts and total record counts for OFFSET pagination.
3. Cvent takes page priority and Blackthorn fills remaining slots; results are
   mapped into `EventWrapper`/`EventItem` (dates/times formatted, register vs.
   modify vs. request-recording button derived) and returned to the grid.
4. The attendees modal (`getEventAttendees`) uses a two-phase strategy —
   in-memory preference sorting for the bounded connection set, then governor-safe
   COUNT + LIMIT/OFFSET for the potentially huge non-preference set — hydrating
   full Contact data only for the ≤6 rows on the current page.
5. Write paths are isolated actions: Request Recording inserts a `Task` and sends
   an org-wide email (saved as Activity); Host an Event inserts a
   `Funding_Interest__c`; and all connection/bookmark/favorite actions are
   delegated to `HAM_AlumniConnectionService`.
