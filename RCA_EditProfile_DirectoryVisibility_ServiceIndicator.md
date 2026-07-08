# Root Cause Analysis
## Edit Profile — Directory Visibility Toggles & Service Indicator Record Creation Failures

| Field          | Details                                              |
|----------------|------------------------------------------------------|
| **Prepared By**    | Engineering Team                                 |
| **Date**           | 2026-06-15                                       |
| **Affected Module**| `ham_editProfileCmp` / `HAM_EditProfileController` |
| **Severity**       | High — Privacy preferences were silently failing to persist |

---

## 1. Executive Summary

Two independent root causes were identified that collectively caused the Edit Profile component to fail at persisting directory visibility preferences as Service Indicator (SI) records on constituent contacts. In both cases the failure was silent — the UI appeared to function normally but no data was written to the database.

---

## 2. System Context

The Edit Profile component drives directory privacy through the following chain:

1. **`HAM_Object_Fetcher__mdt`** (custom metadata) — configures which fields and privacy toggles appear in the Edit Profile UI. Each record stores a `HAM_Service_Indicator_ID__c` value that represents the expected Portal ID for that toggle.
2. **`ucinn_ascendv2__Service_Indicator_Value__c` (SIV)** — the catalog of all service indicator types. Each record carries a `HAM_Portal_ID__c` field that uniquely identifies it within the portal.
3. **`ucinn_ascendv2__Service_Indicator__c` (SI)** — the contact-level instance record that is created/deactivated at save time to record a constituent's privacy preference.

The Apex method `HAM_EditProfileController.getProfileData` loads SIV records into a `sivMap` keyed by `HAM_Portal_ID__c`, then `buildVisibilityGroups` attempts to look up each metadata record's `HAM_Service_Indicator_ID__c` in that map to build the UI toggle list. `handlePrivacyChanges` uses the same Portal ID value to locate the SIV record and create the SI instance.

---

## 3. Root Cause 1 — Portal ID Mismatch Between SIV Record and HAM_Object_Fetcher__mdt

### Description

The **"Do Not Display"** `ucinn_ascendv2__Service_Indicator_Value__c` record in the org had a `HAM_Portal_ID__c` value that did not match the value configured in its corresponding `HAM_Object_Fetcher__mdt` metadata record's `HAM_Service_Indicator_ID__c` field.

> **Note:** The specific `DeveloperName` of the affected `HAM_Object_Fetcher__mdt` record is not available in the project source files as these custom metadata records are stored in the org and were not deployed to this repository. The DeveloperName must be confirmed by querying the org: `SELECT DeveloperName, HAM_Service_Indicator_ID__c FROM HAM_Object_Fetcher__mdt WHERE HAM_Level_1__c = 'Edit Profile' AND HAM_Service_Indicator_ID__c != null`.

### How the Mismatch Caused the Failure

**Step 1 — sivMap construction** (`HAM_EditProfileController.cls`, `getProfileData`):

```apex
// sivMap is keyed by HAM_Portal_ID__c from the SIV record
for(ucinn_ascendv2__Service_Indicator_Value__c siv : dbSivs) {
    sivMap.put(siv.HAM_Portal_ID__c, siv);
}
```

If the SIV record's `HAM_Portal_ID__c` is `'SIV_VIS_ALUMNI_PRIVACY_X'` (wrong/misspelled value) but the `HAM_Object_Fetcher__mdt` record's `HAM_Service_Indicator_ID__c` is `'SIV_VIS_ALUMNI_PRIVACY'` (correct expected value), the SIV is stored in the map under the wrong key.

**Step 2 — Toggle not rendered** (`buildVisibilityGroups`):

```apex
String portalId = mdt.HAM_Service_Indicator_ID__c; // 'SIV_VIS_ALUMNI_PRIVACY' (from metadata)
if (String.isNotBlank(portalId) && sivMap.containsKey(portalId)) {
    // This branch is NEVER entered — key not found in map
}
```

The toggle for this privacy preference is therefore absent from the UI visibility groups returned to the component.

**Step 3 — SI record never created** (`handlePrivacyChanges`):

```apex
// portalToValueId lookup returns null because the SIV was stored under the wrong key
Map<String, Id> portalToValueId = new Map<String, Id>();
for(ucinn_ascendv2__Service_Indicator_Value__c val : [
    SELECT Id, HAM_Portal_ID__c FROM ucinn_ascendv2__Service_Indicator_Value__c
    WHERE HAM_Portal_ID__c IN :changes.keySet()
]) {
    portalToValueId.put(val.HAM_Portal_ID__c, val.Id);
}
// portalToValueId does not contain the key → no SI record is created
if(!activeMap.containsKey(portalId) && portalToValueId.containsKey(portalId)) {
    upsertList.add(new ucinn_ascendv2__Service_Indicator__c(...));
}
```

### Impact

- The "Do Not Display" privacy toggle was invisible to the constituent on the Edit Profile page.
- Even if the preference change was somehow submitted, no `ucinn_ascendv2__Service_Indicator__c` record was created on the contact.
- The directory continued to show the constituent's profile regardless of their stated preference.

### Resolution

Corrected the `HAM_Portal_ID__c` value on the "Do Not Display" `ucinn_ascendv2__Service_Indicator_Value__c` record in the org to match exactly the value specified in the corresponding `HAM_Object_Fetcher__mdt` record's `HAM_Service_Indicator_ID__c` field (`SIV_VIS_ALUMNI_PRIVACY`).

---

## 4. Root Cause 2 — Missing SOQL Filters on the SIV Query (Code Override)

### Description

The primary SIV query inside `HAM_EditProfileController.getProfileData` was missing two critical filter conditions. This was caused by a code override: multiple developers were working against the same Salesforce org instance simultaneously, and a subsequent deployment overwrote the version of the class that contained the correct filters.

### Affected Query

**Broken state** (filters missing after override):

```apex
List<ucinn_ascendv2__Service_Indicator_Value__c> dbSivs = [
    SELECT Id, Name, ucinn_ascendv2__Service_Indicator_Description__c, HAM_Portal_ID__c,
           HAM_Portal_Visible_Name__c, HAM_Parent_Service_Indicator_Value__c,
           HAM_Parent_Service_Indicator_Value__r.HAM_Portal_ID__c
    FROM ucinn_ascendv2__Service_Indicator_Value__c
    WHERE HAM_Portal_ID__c != null
    -- HAM_Category__c filter MISSING
    -- HAM_Is_Visible_On_Portal__c filter MISSING
];
```

**Corrected state** (`HAM_EditProfileController.cls`, lines 123–130):

```apex
List<ucinn_ascendv2__Service_Indicator_Value__c> dbSivs = [
    SELECT Id, Name, ucinn_ascendv2__Service_Indicator_Description__c,
           HAM_Is_Visible_On_Portal__c, HAM_Portal_ID__c, HAM_Portal_Visible_Name__c,
           HAM_Parent_Service_Indicator_Value__c,
           HAM_Parent_Service_Indicator_Value__r.HAM_Portal_ID__c
    FROM ucinn_ascendv2__Service_Indicator_Value__c
    WHERE HAM_Portal_ID__c != null
    AND (HAM_Category__c = 'Directory Visibility' OR HAM_Portal_ID__c = :alumniPrivacyId)
    AND HAM_Is_Visible_On_Portal__c = TRUE
];
```

### What Each Missing Filter Was Doing

| Missing Filter | Purpose |
|---|---|
| `AND (HAM_Category__c = 'Directory Visibility' OR HAM_Portal_ID__c = :alumniPrivacyId)` | Restricts SIV records loaded into `sivMap` to only directory-privacy-relevant values. Without this, SIVs from unrelated categories (Communication Preferences, Marketing Preferences, etc.) were loaded into the map, polluting the visibility group builder and making unintended toggles potentially appear. |
| `AND HAM_Is_Visible_On_Portal__c = TRUE` | Ensures only SIV records explicitly marked as portal-visible are surfaced in the Edit Profile UI. Without this, internal-only service indicator types were included, which could expose system-level flags to the constituent or interfere with the privacy toggle logic. |

### Root Cause of the Override

Multiple developers were deploying Apex class changes to the same org instance without adequate change coordination. A deployment from one developer's local environment that did not include the latest filter conditions was pushed after the corrected version, silently reverting the query to an incomplete state. There was no deployment gate or PR-based review enforcing that the active org version was the canonical source of truth.

### Impact

- The `sivMap` was populated with SIV records from all categories, not just Directory Visibility.
- `buildVisibilityGroups` could surface privacy toggles that should not be visible to alumni.
- SIV records with `HAM_Is_Visible_On_Portal__c = FALSE` (internal system indicators) were included in the map, risking incorrect toggle rendering.
- The master privacy label and description (`masterPrivacyLabel`, `masterPrivacyDescription`) could be incorrectly resolved if an unrelated SIV happened to share a Portal ID key.

### Resolution

Restored both filter conditions to the SIV SOQL query in `HAM_EditProfileController.getProfileData`. Deployment process review was flagged separately to enforce source-control-first discipline (deploy from version control, not individual developer environments) to prevent future overrides of this nature.

---

## 5. Combined Impact Summary

| Root Cause | Symptom | Data Impact |
|---|---|---|
| Portal ID mismatch on "Do Not Display" SIV | Toggle absent from UI; SI record not created | Directory continued to show contact despite opted-out preference |
| Missing SOQL filters due to code override | Unscoped SIV records loaded; incorrect toggles possible | Potential exposure of internal SIV flags; privacy state unreliable |

---

## 6. Preventive Measures

1. **Portal ID values must be validated** at metadata configuration time — the `HAM_Portal_ID__c` on every SIV record used in Edit Profile must exactly match the `HAM_Service_Indicator_ID__c` on the corresponding `HAM_Object_Fetcher__mdt` record. A validation rule or a lightweight test class assertion should enforce this contract.

2. **Deployments must originate from version control**, not from individual developer sandboxes. All changes to shared classes must go through a pull request and be deployed via CI/CD pipeline to eliminate the risk of concurrent overrides.

3. **The SOQL filter combination** (`HAM_Category__c` scope + `HAM_Is_Visible_On_Portal__c = TRUE`) on the SIV query is load-bearing. Any future modification to `HAM_EditProfileController.getProfileData` must preserve both conditions.

---

*Document prepared for attachment to the associated user story. All line number references are based on the version of `HAM_EditProfileController.cls` current as of 2026-06-15.*
