# HANDOVER — Group Notifications Enhancement
*Last session: 2026-07-13 · Target org: `hamdevsabdbox` (hamiltoncollege--advdev.sandbox)*
*Status: In progress — core blockers root-caused & fixed in org; local LWC edits uncommitted; repo/org drift outstanding*

> Companion doc: [Groups.md](Groups.md) has the full architecture map + implementation-status
> tables. The 2026-07-13 findings are synced there as **Section 8/9** (root causes, navigation
> fixes, repo drift, open bug). Note Groups.md also gained a **Section 7** from ANOTHER developer's
> concurrent "Group Members directory parity" story (2026-07-09) — be aware their work touches
> `Ham_GroupsController`, `HAM_AlumniDirectoryController`, and `ham_groupMembers`.
> This file is the "where we are right now / what to do next" summary.

---

## 0. Session Log

| Date | Chat/Session | Summary of what was done | Deployed? |
|---|---|---|---|
| 2026-07-13 | Precedence + Members card | Shipped notification precedence rules (master toggle cascades off to Tagged/Amplified; one alert per post, "New post in {Group}" beats mention message) + Figma Members sidebar card. Details in [Groups.md](Groups.md) §9. | No — uncommitted, not deployed |
| 2026-07-09 | Root-cause blockers | Root-caused & fixed both long-standing blockers (toggle persistence = FLS; no notifications = restricted picklist missing `Groups`). Deep-link parser, clickable bell rows, mobile View Group fix. | Org-manual fixes applied; LWC edits local |

---

## 1. Client Request / Goal (this feature)

Group Notifications user story: Tagged (`"{Full Name} mentioned you! in [Group Name]"`),
Amplified (`"Check out this post/resource in [Group Name]!"`), and the 3-toggle bell settings
panel (Send Me / Tagged / Amplified) on the group dashboard, with Save-button UX.

---

## 2. Files Changed & What Changed

> Two categories: (A) MAJOR blocker root-causes fixed directly in the org 2026-07-09;
> (B) new LWC work completed 2026-07-13 (local, not yet confirmed deployed).

### (A) Blocker root-causes — FIXED in org (2026-07-09)

**2a. Toggle persistence bug — SOLVED**
- **Root cause:** portal permission sets granted the toggle fields **read but not edit** FLS
  (`HAM_Partner_Community_Permission`: Notify_on_Tagged/Amplified editable=false;
  `HAM_Portal_Access_Internal`: all three editable=false). `Ham_GroupsController.updateNotificationPreferences`
  runs `Security.stripInaccessible(AccessType.UPDATABLE, ...)`, which **silently stripped** the
  fields → no-op update → no exception → LWC `.then()` fired → `refreshApex` repainted the old
  value. The earlier `without sharing` fix was necessary but insufficient — sharing ≠ FLS.
- **Fix applied by user directly in the org:** edit FLS granted on the notification-preference
  fields for the portal permission set(s). **⚠️ Verify repo permission-set XML matches the org.**
- **User confirmed toggles now persist.**
- **Optional hardening (proposed, NOT implemented):** post-strip guard in
  `updateNotificationPreferences` — throw `AuraHandledException` if `stripInaccessible` removed
  any requested field, so future FLS regressions fail loudly instead of silently reverting.

**2b. No notifications ever delivered — SOLVED**
- **Root cause:** `HAM_Notification__c.HAM_Source_Type__c` is a **restricted picklist** whose
  values were only `Connection / News / Event / Campaign` — **no `Groups` value** — while all
  four group dispatch paths write `HAM_Source_Type__c = 'Groups'` (queueable lines 165/310/439 +
  `Ham_GroupsController` ~1074). Insert died with `INVALID_OR_NULL_FOR_RESTRICTED_PICKLIST`,
  swallowed by the queueable's blanket try/catch → `AsyncApexJob` showed **Completed, 0 errors**
  → empty bell. Connection notifications worked because `'Connection'` is a valid value.
- **Fix applied by user directly in the org:** added `Groups` picklist value via Setup UI.
  **User confirmed notifications now work.**
- **⚠️ REPO DRIFT (single most important pending repo task):** the local field metadata
  `objects/HAM_Notification__c/fields/HAM_Source_Type__c.field-meta.xml` still lacks the
  `Groups` value — **update the XML (or retrieve the field) or the next deploy of that object
  wipes the fix.**
- **Optional hardening (proposed, NOT implemented):** stop swallowing DML failures into
  `System.debug` in `HAM_NotificationQueueable` — 2nd silent-failure bug in this feature.

### (B) New LWC work (2026-07-13, local, NOT yet confirmed deployed)

| # | Change | File(s) | Status |
|---|---|---|---|
| 1 | **Deep-link parser fix**: `case 'groups'` in `checkUrlForDeepLink` now routes to Community tab + Groups subtab and reads `groupId`/`subview` (previously activated the *disabled* student-only Groups tab and dropped all params → push-notification taps landed on a dead view). Retroactively fixes all stored `?view=groups&...` action URLs. | `lwc/ham_MainCmp/ham_MainCmp.js` (~line 535) | Implemented; lint-clean (all 26 eslint errors pre-existing) |
| 2 | **Clickable bell notification rows**: rows with `HAM_Action_URL__c` get `clickable` class + `data-url` + onclick → `window.location.href` (full reload re-enters the same deep-link parser — one code path for bell clicks and push taps, desktop + mobile). `stopPropagation()` added to connection Accept/Ignore handlers. Also makes connection rows navigate (`?view=directory&tab=Manage%20Invitations`). | `lwc/ham_notificationBell/{js,html,css}` | Implemented |
| 3 | **Mobile "View Group" button fix**: `.mobile-card` wrapper was missing `data-id` — its bubbled click handler dispatched `viewgroup` with `groupId: undefined`, instantly cancelling the button's correct navigation (handler reads `event.currentTarget.dataset.id`). Added `data-id={group.groupId}` (mirrors desktop card, line 73). Safe with Show More (`handleToggleDescription` already stopPropagations). | `lwc/ham_groupsDiscovery/ham_groupsDiscovery.html` (~line 251) | Implemented |

> Also 2026-07-13: `docs/Prompt_Templates/GEMINI.MD` was **moved to root as `CLAUDE.md`**
> (agent rules file — two-phase plan/execute gate, Salesforce standards). Note its §5's
> `run_code_analyzer` should be read as the `sf code-analyzer` CLI for non-Gemini agents.

---

## 3. What's Working After Deployment

| Behaviour | Status |
|---|---|
| Toggle preferences persist (after org FLS fix) | ✅ Working (user-confirmed) |
| Group notifications delivered to bell (after `Groups` picklist value) | ✅ Working (user-confirmed) |
| Deep-link parser / clickable bell rows / mobile View Group | ⚠️ Implemented locally, not confirmed deployed |

---

## 4. Outstanding Issues / Bugs (NOT fixed this session)

### 4a. Group dashboard bell-settings popup won't close on outside click (desktop + mobile)
- **Symptom:** clicking the bell in a group opens the Notification Settings popup, but clicking outside it does not close it.
- **Root cause:** THEORY — verify. `ham_groupDashboard` has `isNotificationDropdownOpen`, toggled only by the bell button (`toggleNotificationDropdown`, js ~line 181) and closed programmatically in `handleBackAction` (~285) and one other path (~311). **The dropdown markup (html ~lines 54-60+) has NO backdrop element and no document/outside-click listener** — so nothing ever closes it on an outside tap. Contrast the header bell `ham_notificationBell.html` lines 92-94: it renders an invisible fixed `div.backdrop` (z-index 9000, under the z-9999 dropdown) with `onclick={toggleDropdown}` — the established in-repo pattern for click-outside-to-close.
- **Proposed fix:** replicate the backdrop pattern in `ham_groupDashboard`: render a `<div class="backdrop">` alongside the dropdown when `isNotificationDropdownOpen`, whose onclick closes the dropdown AND (per the Save-button UX) **discards `pendingNotificationChanges`** — closing without Save must stage-discard, same as Cancel. Check z-index vs the dropdown's, and verify on mobile (touch) too.
- **Note:** May already be fixed in an earlier pass — `notif-backdrop` + `closeNotificationDropdown` are reportedly in `ham_groupDashboard`. **Retest first, then strike this if resolved.**

---

## 5. Next Steps (in priority order)

0. **Run `Ham_GroupsControllerTest`** — could not be executed 2026-07-13: the sandbox's
   `Ham_GroupsController` is behind the local working tree (org's `resolveReport` has a
   different signature), so the test class doesn't compile against the org. Needs a deploy
   of the local Apex first — and that working tree also carries another developer's
   in-progress `ham_groupAdmin` changes, so coordinate before deploying.
1. **Fix repo/org drift** (critical): add `Groups` to `HAM_Source_Type__c.field-meta.xml`;
   verify permission-set XML edit-FLS matches what the user granted in the org.
2. **Fix/retest the bell-popup outside-click bug** (§4a, backdrop pattern).
3. **Deploy + retest** the three §2(B) LWC changes if not yet deployed
   (`ham_MainCmp`, `ham_notificationBell`, `ham_groupsDiscovery`) — hard refresh (Ctrl+Shift+R).
   Test: bell row click → lands in group; push tap on mobile → same; connection Accept/Ignore
   still work without navigating; mobile View Group button opens the group and stays.
4. **Mobile QA pass** of the new surfaces: bell settings dropdown (toggles + Save/Cancel),
   @mention popovers near virtual keyboard, clickable notification rows' tap targets.
5. **Optional hardening** (both proposed, user said not required yet): post-strip guard
   in `updateNotificationPreferences`; un-swallow queueable DML exceptions.
6. **Parked pending client answers:**
   - `postId` deep-link (scroll-to-post in feed) — ~5 components, scoped as own step.
   - Revive student-only Groups tab? (commented out in `ham_MainCmp.html` ~259-269 & ~332-335;
     if revived, deep-link parser needs an `isStudent` branch — mind the wire-timing issue:
     `isStudent` resolves after URL parsing).
   - Master-toggle semantics: is "Send Me Notifications" a pure gate or the every-post
     subscription? (Recommended: add 4th field `Notify_on_New_Posts__c`, master = pure gate.)
   - ~~Mention dedupe~~ — **ANSWERED 2026-07-13 and shipped, but the client chose the
     *opposite* precedence to what was recommended here:** the generic "New post in X"
     message wins and the mention alert is dropped (not the other way round). Since the
     master toggle is also the every-post subscription, that suppresses *all* post
     @mentions; only comment @mentions fire. See Groups.md §9b before touching it.
   - Amplified vs pinned feed ordering (recommended: Pinned > Amplified > chronological, via a
     third initial-load block excluded from keyset pagination — do NOT sort the paginated query
     by Is_Amplified__c, it breaks `Id < :lastPostId`). Un-amplify / re-amplify semantics.
   - New-post copy alignment (title = group name; author masked as "Someone" when anonymous).

---

## 6. Key Architecture / Context Notes

- Sharing ≠ FLS: `stripInaccessible(AccessType.UPDATABLE, ...)` silently drops fields the running
  user can't edit — a `without sharing` class still can't write fields the perm set marks
  read-only. This was the root of the "toggles won't persist" bug (§2a).
- `HAM_Source_Type__c` is a **restricted** picklist; any Apex writing a value not in the picklist
  throws `INVALID_OR_NULL_FOR_RESTRICTED_PICKLIST`. The queueable's blanket try/catch swallowed it
  into `System.debug`, so `AsyncApexJob` reported success with an empty bell (§2b).
- All four group dispatch paths write `HAM_Source_Type__c = 'Groups'` (queueable lines 165/310/439
  + `Ham_GroupsController` ~1074).
- Bell click-outside-to-close pattern: invisible fixed `div.backdrop` (z-9000) under the z-9999
  dropdown with `onclick={toggleDropdown}` — see `ham_notificationBell.html` lines 92-94.
- Deep-link parser lives in `ham_MainCmp.checkUrlForDeepLink` (~line 535). `isStudent` resolves
  *after* URL parsing (wire timing) — relevant if the student-only Groups tab is revived.

---

## 7. Git / Environment / Deployment State

- **Deployed to org:** earlier sessions' work (schema, amplify, mentions, Save-button UX) — see git history.
- **Local-only (uncommitted / not deployed):** this feature's three §2(B) LWC edits
  (`ham_MainCmp`, `ham_notificationBell`, `ham_groupsDiscovery`) + the 2026-07-13 precedence
  + Members-card work.
- **Org-manual changes NOT in repo:** `Groups` picklist value on `HAM_Source_Type__c`;
  edit FLS on notification-preference fields (both applied via Setup UI).
- **⚠️ Repo/org drift:** `HAM_Source_Type__c.field-meta.xml` lacks the `Groups` value (redeploy
  wipes the org fix); permission-set XML may not match the org's edit-FLS grant. **Fix both.**
- **Relevant commits / branches:** `2259d93` = pre-retrieve snapshot branch;
  `a7de443` = post-retrieve reconciliation.
- **Coordination:** another developer works in the same sandbox/files (Group Members parity story,
  `ham_groupAdmin` in-progress) — coordinate before deploying.
- **Companion docs:** [Groups.md](Groups.md) (full architecture map; §7 = other dev's parity story;
  §8/§9 = this feature's findings). `create_cube84_users.apex` (repo root) is an unrelated
  standalone anonymous-Apex script for creating 8 internal Cube84 dev users in QA/UAT.
