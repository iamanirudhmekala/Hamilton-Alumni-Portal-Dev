# FEATURE METADATA MAP: ALUMNI DIRECTORY
*Last Synchronized: 2026-07-09 (Auto-verified against live repository)*

**Change log (2026-07-09):** `getDirectoryData` and `getDirectoryDataCount` gained a trailing optional `List<Id> scopeContactIds` parameter so the Groups module's Members page (`Ham_GroupsController.getGroupMembersDirectory`) can serve group-scoped pages through this engine. Null scope (all pre-existing callers) is behaviour-identical. See `docs/features/Groups.md` §7.

## 1. Functional UI Behavior
- User Action: The portal user opens the Alumni Directory page, which renders a tabbed interface (Search Directory, My Connections, Bookmarked Profiles, Manage Invitations, Blocked Profiles). The user types a search term, selects filter values (Class Year, Industry, Region, plus a "More Filters" modal with 8 secondary filters), toggles between list/grid views, pages through results, and triggers connection actions (connect, accept, reject, bookmark, favorite, block) on individual alumni cards. Users can also save their current filter selection as a preference.
- System Reaction: The result set refreshes reactively as search/filter/tab/page state changes (wired Apex with `refreshApex`). Record counts and pagination update per tab. On first visit with no saved preferences, default filters are pre-applied from the user's own Contact data (class year, current chapters). Connection actions show a custom toast and update card state; a Lightning Message Service channel (`ham_notificationChannel__c`) refreshes the view when notifications arrive.

## 2. Discovered Execution Stack
- **Frontend Layer:**
  - `force-app/main/default/lwc/ham_alumniDisplayCmp/ham_alumniDisplayCmp.html` & `.js` — master component: tabs, search, pagination, view toggle, orchestrates all data loads.
  - Child LWCs composed inside it: `ham_alumniSearchFilterCmp` (filter UI + More Filters modal, dispatches `filterchange`), `ham_alumniListDisplayCmp` / `ham_alumniGridDisplayCmp` (result rendering + connection actions), `ham_PaginationUtil`, `ham_customToastCmp`.
  - Related: `ham_alumniProfileOverviewCmp` (profile overlay, also calls connection service).
- **Controller/Apex Layer:**
  - `force-app/main/default/classes/HAM_AlumniDirectoryController.cls` (`public without sharing`) →
    `getDirectoryTabset()`, `getFilterMetadataAndValues()`, `searchFilterOptions()`, `getDirectoryData()`, `getDirectoryDataCount()`, `getSavedUserPreferences()`, `saveUserPreferences()`, `getContactDefaultFilterData()`.
  - `force-app/main/default/classes/HAM_AlumniFilterHelper.cls` — delegate for `getDynamicValues()`, `searchDynamicValues()`, `getSpecificWhereClause()` (dynamic filter values + WHERE clause building per placeholder).
  - `force-app/main/default/classes/HAM_AlumniConnectionService.cls` (`public without sharing`) → `handleConnectionRequest()`, `handleAccept()`, `handleReject()`, `checkUserStatus()` — invoked from the list/grid/profile-overview LWCs, not from the directory controller.
  - `Ham_DirectoryController.cls` exists but is DEPRECATED — do not extend it.
- **Automation/Data Layer:**
  - Objects queried: `Contact` (+ child `HAM_Connections__r` / `HAM_Connections1__r`), `HAM_Connection__c`, `ucinn_ascendv2__Service_Indicator__c`, `ucinn_ascendv2__Degree_Information__c`, `ucinn_ascendv2__Contact_Name__c`, `HAM_Portal_User_Preference__c`.
  - DML: insert/update on `HAM_Portal_User_Preference__c` (saveUserPreferences); update on `HAM_Connection__c` and notification records (HAM_AlumniConnectionService accept/reject flows).
  - Custom Metadata (configuration-driven behavior):
    - `HAM_Filters__mdt` — 12 active filter records, ordered by `HAM_Order__c`: 1 Class Year, 2 Industry, 3 Region, 4 More Filters, 5 Student Organizations, 6 Employer, 7 Sports Association, 8 Volunteer Role, 9 Major, 10 Alumni Committee, 11 Job Title, 12 Trustee.
    - `Ham_Directory_Tabset__mdt` — 6 records, all `Is_Active__c = true`: Search Directory (1), Build Your Alumni Community (1), My Connections (2), Bookmarked Profiles (3), Manage Invitations (4), Blocked Profiles (5).
    - `HAM_Meta_Data__mdt` — per-tab field display config (Header/Fields/Flags).
    - `Ham_Service_Indicators__mdt` — field-level privacy per service indicator (e.g. `SIV_VIS_ALUMNI_PRIVACY`, `SIV_VIS_PROFILE_PIC`).
  - Custom Labels: `ham_AlumniDefaultFilter`, `ham_AlumniDefaultFilterPortal`, `ham_AlumniDefaultFilterLinked` (base WHERE clauses), plus UI labels (`ham_BuildAlumniCommunity`, `HAM_Blocked_Profiles`, `ham_Directory_Menu`, etc.).
  - No Flows or `InvocableMethod` entry points are involved in this feature.

## 3. Current Technical Logic Summary
1. On load, `ham_alumniDisplayCmp` wires to `getDirectoryTabset` and `getFilterMetadataAndValues`, which read `Ham_Directory_Tabset__mdt` and `HAM_Filters__mdt` (values resolved dynamically per placeholder by `HAM_AlumniFilterHelper`).
2. Saved filters are fetched from `HAM_Portal_User_Preference__c` via `getSavedUserPreferences`; if none exist, `getContactDefaultFilterData` derives defaults (class year, chapters) from the user's Contact.
3. Search/filter/tab/page state is passed to `getDirectoryData` / `getDirectoryDataCount`, which build dynamic SOQL over `Contact` and `HAM_Connection__c`, gated by label-driven base WHERE clauses and `HAM_AlumniFilterHelper.getSpecificWhereClause` per selected filter.
4. Field display and privacy are applied server-side using `HAM_Meta_Data__mdt` and `Ham_Service_Indicators__mdt` (service-indicator records hide fields/photos for opted-out constituents) before wrapped results return to the LWC.
5. Connection actions from list/grid/profile cards call `HAM_AlumniConnectionService`, which updates `HAM_Connection__c` (and related notifications); saving filter preferences upserts `HAM_Portal_User_Preference__c` keyed by `Portal_Contact__c`.
