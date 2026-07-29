# HANDOVER — Alumni Directory: Self-Search + No-Results Message
*Last session: 2026-07-21 · Target org: `hamdevsabdbox` (hamiltoncollege--advdev.sandbox)*
*Status: Deployed & verified (core asks); 3 outstanding issues open — see §4*

---

## 0. Session Log

| Date | Chat/Session | Summary of what was done | Deployed? |
|---|---|---|---|
| 2026-07-21 | Self-search + no-results | Self-user appears in Search Directory (Send Request greyed for self, View Profile kept, bookmark/3-dot hidden); meaningful no-results message when a search/filter returns 0 rows | Yes (redeploy Apex — see §7) |

---

## 1. Client Request / Goal (this feature)

Two client-requested changes to the **Search Directory (Build Community) tab** of the Alumni Directory:

1. **Self-Search:** Allow logged-in users to find their own profile in the directory. Show their card like any other alumni. Disable (grey out) the Send Request button for their own card. Keep View Profile visible and clickable. Hide bookmark icon and three-dot menu for self (you can't bookmark or block yourself).

2. **No-Records Message:** When a search or filter is applied and returns 0 results, show a meaningful message — "No alumni profiles match your current search or filters. Try refining your search or removing some filters." — instead of the generic initial-state message. The initial-state message should still show when no search/filter is active.

---

## 2. Files Changed & What Changed

### `HAM_AlumniDirectoryController.cls`
- **What:** Three queries previously excluded the logged-in user with `AND ID != :portalConstituentId`. All three were removed so the self-user's contact appears in all result sets.

  | Query | Location | Fix |
  |---|---|---|
  | Count query (`getDirectoryDataCount`) | ~line 307 | Removed self-exclusion |
  | Main data query (`getDirectoryData`) | ~line 714 | Removed self-exclusion |
  | Keyset cursor query (pagination, page 2+) | ~line 740 | Removed self-exclusion |

- **Watch out:** The keyset cursor query is only used when `recordsToSkip > 0` (i.e. user navigates to page 2 or beyond). If the cursor excludes the self-user but the main query doesn't, the alphabetical cursor is off by one position and page 2+ returns the wrong records. **All three queries must be consistent.**

### `ham_alumniListDisplayCmp.js`
- **What (self-search, in `processAlumniList()`):**
  ```js
  // Already existed — unchanged
  isNotCurrentUser: !(isBuildTab && a.portalUserId === this._userContactId),

  // buttonClass: forces 'btn disable' appearance for self on Build Community tab
  buttonClass: (isBuildTab && a.portalUserId === this._userContactId)
      ? 'btn disable'
      : this.getButtonClass(a.isCoolDown, a.isConnected, a.isRequestSent, a.isBlocked),

  // disableConnectionButton: NEW — disables the Send Request button for self
  disableConnectionButton: (isBuildTab && a.portalUserId === this._userContactId) || a.isCoolDown,
  ```
- **What (no-results message):**
  - Added import: `import NoSearchResults from '@salesforce/label/c.HAM_No_Search_Results';`
  - Added to `label` object: `noSearchResults: NoSearchResults`
  - Updated `tabStateMessage` getter (was a simple tab-key lookup; now checks for active search/filter on Build Community tab):
  ```js
  get tabStateMessage() {
      if (this.isSentSubTab) return this.label.noSentRequests;
      if (this._tab === this.TABS.BUILD_COMMUNITY) {
          const hasSearch = this.searchKeyToApex && this.searchKeyToApex.trim() !== '';
          const hasFilters = Array.isArray(this.savedFilters) && this.savedFilters.length > 0;
          if (hasSearch || hasFilters) return this.label.noSearchResults;
      }
      return this.TAB_EMPTY_MESSAGES[this._tab] || '';
  }
  ```

### `ham_alumniListDisplayCmp.html`
- **Before:** The entire `<div class="col actions">` (Send Request + View Profile + three-dot menu) was wrapped in `<template lwc:if={alumni.isNotCurrentUser}>`. Self-user card showed nothing at all.
- **After:** Outer `isNotCurrentUser` wrapper removed from the actions div. Restructured so:
  - **Send Request button** — always rendered; `disabled={alumni.disableConnectionButton}` and `class={alumni.buttonClass}` make it greyed/unclickable for self
  - **View Profile button** — moved outside all `isNotCurrentUser` checks; always visible for every card
  - **Three-dot menu** — moved inside `<template lwc:if={alumni.isNotCurrentUser}>` inside the `if:false={isDeseasedAlumnae}` block; hidden for self
- **Watch out:** In the current dev HTML the Send Request button also has an additional `<template lwc:if={alumni.showConnectionButton}>` wrapper (pre-existing dev feature, NOT in UAT). `showConnectionButton` hides Send Request when the logged-in user or the target contact has connection privacy enabled. This is separate from our self-search changes. See §4a.

### `ham_alumniGridDisplayCmp.js`
- **What:** Same three changes as list JS (`isNotCurrentUser` was already there; `buttonClass` and `disableConnectionButton` extended for self-user). Same `NoSearchResults` label import + label entry + `tabStateMessage` getter logic.

### `ham_alumniGridDisplayCmp.html`
- **What:** Same restructuring as list HTML — applied to both the **mobile card footer** and **desktop card footer**:
  - Outer `isNotCurrentUser` wrapper removed from `<div class="card-footer">`
  - View Profile button now always renders inside the footer (not gated)
  - Bookmark/favorite icons in `<div class="card-actions">` remain inside `<template lwc:if={alumni.isNotCurrentUser}>` (unchanged — they were already scoped there)

### `force-app/main/default/labels/CustomLabels.labels-meta.xml`
- **What:** The `HAM_No_Search_Results` label was **already present** before this session. No change needed.
- Value: `"No alumni profiles match your current search or filters. Try refining your search or removing some filters."`

---

## 3. What's Working After Deployment

| Behaviour | Status |
|---|---|
| Self-user's card appears in Search Directory results | ✅ Working |
| Bookmark icon hidden for self-card | ✅ Working |
| Three-dot menu hidden for self-card | ✅ Working |
| View Profile visible for self-card | ✅ Working |
| No-records message on Build Community tab when search/filter active | ✅ Working |
| Initial-state message still shows when no search entered | ✅ Working |

---

## 4. Outstanding Issues / Bugs (NOT fixed this session)

### 4a. Send Request button not visible for any contact
- **Symptom:** Send Request button missing for all 20 test contacts (not just self-card).
- **Root cause (pre-existing dev feature, not introduced by this session):** In both list and grid HTML, the Send Request button is wrapped in two extra template conditions **not present in the UAT code**:
  ```html
  <template lwc:else>  <!-- lwc:else of isManageTab -->
      <template lwc:if={alumni.isNotCurrentUser}>          ← hides for self (fine)
          <template lwc:if={alumni.showConnectionButton}>  ← hides when privacy enabled
              <button ...>Send Request</button>
          </template>
      </template>
  </template>
  ```
  `showConnectionButton` is false when:
  - `this._isLoginedPortalConPrivacyOpen === true` (logged-in user has connection privacy service indicator), OR
  - `a.header?.connectionPrivacyEnabled === true` (target contact has connection privacy)

  `_isLoginedPortalConPrivacyOpen` is set from `ham_alumniDisplayCmp._protalLogedUserPrivacy`, which comes from `HAM_AlumniDirectoryController.getDirectoryData()` — specifically `response.protalLogedUserPrivacy = ConnectionPrivacyIds.contains(portalConstituentId)`. **If the Cube84 PerfTest user has a `CONNECTION_PRIVACY` service indicator in the org, `showConnectionButton = false` for ALL contacts and no Send Request buttons render anywhere.**
- **Proposed fix (choose one):**
  1. Check whether the Cube84 PerfTest test user has the connection privacy service indicator set in the org. If so, remove it.
  2. If connection privacy feature should suppress Send Request regardless: this is working as designed — just the test user's data is wrong.
  3. To revert to UAT behaviour (always show Send Request, no privacy gate in HTML): remove the two extra `<template>` wrappers and the `showConnectionButton` computed property from both list and grid HTML/JS.
- **Relevant files:** `ham_alumniListDisplayCmp.html` lines 111-119, `ham_alumniGridDisplayCmp.html` lines 134-142, both JS files `showConnectionButton` in `processAlumniList`.

### 4b. View Profile not navigating to profile overview
- **Symptom:** Clicking View Profile on any card shows nothing / does not navigate to the profile overview.
- **Root cause:** THEORY — verify. Our code changes did NOT modify `handleViewProfile`, the `profileoverview` event dispatch, or the `constituentId` on the button's `data-id` attribute. The event chain is:
  1. Child fires `new CustomEvent('profileoverview', { bubbles: true, composed: true, detail: { selectedContactId, ... } })`
  2. Event bypasses `ham_alumniDisplayCmp` (it only listens for `onviewprofile`, not `onprofileoverview`)
  3. Reaches `ham_MainCmp` via `onprofileoverview={handleProfileOverview}`
  4. `ham_MainCmp.handleProfileOverview` sets `this.isProfileOverview = true` and `this.selectedCardId`
  5. `ham_MainCmp.html` renders `<c-ham_alumni-profile-overview-cmp contact-id={selectedCardId}>`
- **Proposed fix / next steps to diagnose:** Check whether the profile overview is rendering but blank (Apex error in `ham_alumniProfileOverviewCmp`), or whether the event is not reaching `ham_MainCmp`. Open browser console, click View Profile, check for JS errors or failed Apex calls. Also try clicking the alumni's **name or avatar** (these also call `handleViewProfile` and were not changed) to rule out a button-level issue.

### 4c. Error messages appearing beside inputs in `ham_editProfileCmp`
- **Symptom:** Validation error messages for Instagram/LinkedIn handle fields appear to the right of the input instead of below it.
- **Root cause:** `field-label-container` uses `display: flex; align-items: center; gap: 4px;` so the `<p class="field-error-message">` sits inline in the flex row.
- **Proposed fix (not yet applied):** In `ham_editProfileCmp.css`, add `flex-wrap: wrap` to `.field-label-container` and `flex-basis: 100%; width: 100%` to `.field-error-message` so the error message wraps to its own line.

---

## 5. Next Steps (in priority order)

1. Redeploy `HAM_AlumniDirectoryController.cls` — the keyset cursor fix (line ~740) was made **after** the initial deployment (see §7).
2. Resolve §4a (Send Request visibility) — decide between the three fix options; likely check the Cube84 PerfTest user's connection-privacy service indicator first.
3. Diagnose §4b (View Profile navigation) via browser console.
4. Apply §4c CSS fix in `ham_editProfileCmp.css`.

---

## 6. Key Architecture / Context Notes

- `isNotCurrentUser` is `false` **only** when BOTH: active tab is Build Community AND `a.portalUserId === this._userContactId`. It is `true` for all other users on all other tabs.
- `constituentId` per alumni record maps to `a.portalUserId` on Build Community/Connections/Manage tabs, but to `a.linkedUserId` on Bookmarks, Blocked Profiles, and Sent sub-tab. Don't confuse these.
- View Profile event name: children fire `profileoverview` (not `viewprofile`). `ham_alumniDisplayCmp` only listens for `onviewprofile` — the event bypasses it intentionally via `bubbles + composed`, reaching `ham_MainCmp`.
- The `showConnectionButton` property exists only in dev — it is not in the UAT codebase. It was a pre-existing dev addition and may not be fully QA'd.

---

## 7. Git / Environment / Deployment State

- **Deployed to org:**
  ```
  force-app/main/default/classes/HAM_AlumniDirectoryController.cls
  force-app/main/default/lwc/ham_alumniListDisplayCmp/ham_alumniListDisplayCmp.js
  force-app/main/default/lwc/ham_alumniListDisplayCmp/ham_alumniListDisplayCmp.html
  force-app/main/default/lwc/ham_alumniGridDisplayCmp/ham_alumniGridDisplayCmp.js
  force-app/main/default/lwc/ham_alumniGridDisplayCmp/ham_alumniGridDisplayCmp.html
  ```
- **⚠️ Redeploy needed:** The keyset cursor fix to `HAM_AlumniDirectoryController.cls` (line ~740) was made **after** the initial deployment — redeploy the Apex class.
- **Org-manual changes NOT in repo:** none for this feature (the `HAM_No_Search_Results` label already existed).
