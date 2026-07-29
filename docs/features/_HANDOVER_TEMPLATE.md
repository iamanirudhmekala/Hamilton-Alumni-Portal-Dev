<!--
================================================================================
HANDOVER TEMPLATE — HOW TO USE
================================================================================
This is a BLANK, REUSABLE template. Do NOT fill it in directly.

1. COPY this file to a new feature/chat-specific file, e.g.:
     docs/features/HANDOVER_<feature-slug>.md
   (examples: HANDOVER_alumni-self-search.md, HANDOVER_group-notifications.md)

2. Fill in every section. Delete any section that genuinely doesn't apply,
   and delete this comment block once you start.

3. Keep ONE file per feature/chat. When you resume that feature in a later
   chat, UPDATE its file (add a dated sub-heading under §0) rather than
   starting a new one — so each feature has a single, complete history.

Purpose: a self-contained context handoff. Someone (or a fresh chat) should be
able to read only this file and know what was asked, what changed, what works,
what's broken, and what to do next — without re-reading the whole conversation.

Guidance while filling in:
- Absolute dates only (2026-07-21), never "today" / "last week".
- Every file path clickable and repo-relative.
- Be explicit about what is DEPLOYED vs LOCAL-ONLY vs ORG-MANUAL (not in repo).
- Call out repo/org drift loudly — it's the thing that silently breaks later.
================================================================================
-->

# HANDOVER — <Feature / Story Name>
*Last session: <YYYY-MM-DD> · Target org: `<org-alias>` (`<org-domain>`)*
*Status: <In progress | Blocked | Deployed & verified | Handed off>*

---

## 0. Session Log
> One line per session that touched this feature. Newest first. Add a row each
> time you resume — this is the "what happened when" spine of the feature.

| Date | Chat/Session | Summary of what was done | Deployed? |
|---|---|---|---|
| <YYYY-MM-DD> | <this chat> | <one-line summary> | <yes/no/partial> |

---

## 1. Client Request / Goal (this feature)
> What was actually asked for, in the client's terms. Enough that a reader who
> never saw the conversation understands the intent and acceptance criteria.

1. **<Ask 1>:** <description + acceptance criteria>
2. **<Ask 2>:** <description + acceptance criteria>

---

## 2. Files Changed & What Changed
> One sub-section per file. Say WHAT changed and WHY. Include the key before/after
> snippet or the specific method/line when it aids the next person. Note gotchas.

### `<path/to/File.cls>`
- **What:** <change>
- **Why:** <reason>
- **Watch out:** <any coupling, ordering, or consistency requirement>

### `<path/to/component.js>`
- **What:** <change>
- **Why:** <reason>

<!-- repeat per file -->

---

## 3. What's Working After Deployment
> Only list behaviours you actually verified. If not tested, put it in §5, not here.

| Behaviour | Status |
|---|---|
| <behaviour> | ✅ Working |
| <behaviour> | ⚠️ Partial |

---

## 4. Outstanding Issues / Bugs (NOT fixed this session)
> Each with: symptom, root cause (or best current theory), proposed fix, and the
> exact files/lines. Mark whether the diagnosis is confirmed or still a guess.

### 4a. <Issue title>
- **Symptom:** <what the user sees>
- **Root cause:** <confirmed | THEORY — verify> — <explanation>
- **Proposed fix:** <what to do; not yet applied>
- **Relevant files:** <path:lines>

<!-- repeat 4b, 4c... -->

---

## 5. Next Steps (in priority order)
> The to-do list for whoever picks this up. Most important / blocking first.

1. <step>
2. <step>
3. **Parked pending answers:** <open questions waiting on client/user, with the
   options considered and any recommendation>

---

## 6. Key Architecture / Context Notes
> Non-obvious facts that took effort to learn: event names, field mappings, which
> property lives only in dev vs UAT, naming traps, "these must stay consistent".

- <note>
- <note>

---

## 7. Git / Environment / Deployment State
> The single source of truth for "where does this code actually live right now".

- **Deployed to org:** <files, or "none yet">
- **Local-only (uncommitted / not deployed):** <files>
- **Org-manual changes NOT in repo:** <picklist values, FLS, permission-set edits
  made in Setup UI — these are the ones a redeploy silently wipes>
- **⚠️ Repo/org drift:** <anything the repo and org disagree on — flag loudly>
- **Relevant commits / branches:** <hashes + one-line meaning>
- **Companion docs:** <links to feature deep-dive .md files, e.g. Groups.md>
