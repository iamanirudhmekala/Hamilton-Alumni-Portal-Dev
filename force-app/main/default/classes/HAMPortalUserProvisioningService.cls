/**
 * HAMPortalUserProvisioningService
 *
 * Synchronous phase only — non-setup DML (Account UPDATE) + validation.
 * Hands off to HAMProvisioningQueueable for all setup DML.
 *
 * Depends on: HAMPortalProvisioningDTO  (deploy that class first)
 */
public with sharing class HAMPortalUserProvisioningService {

    // ══════════════════════════════════════════════════════════════════════
    // PUBLIC ENTRY POINTS
    // ══════════════════════════════════════════════════════════════════════

    /**
     * Full entry point used by the batch class.
     *
     * @param contactIds   Up to 200 Contact Ids per invocation.
     * @param sendToQueue  TRUE in production (enqueues Queueable).
     *                     FALSE in unit tests that invoke the Queueable
     *                     directly to avoid hitting queue limits.
     */
    public static HAMPortalProvisioningDTO.SyncPhaseOutcome provisionUsers(
        List<Id> contactIds,
        Boolean  sendToQueue
    ) {
        List<HAMPortalProvisioningDTO.ProvisioningResult>    results   =
            new List<HAMPortalProvisioningDTO.ProvisioningResult>();
        Map<Id, HAMPortalProvisioningDTO.ProvisioningResult> resultMap =
            new Map<Id, HAMPortalProvisioningDTO.ProvisioningResult>();

        for (Id cId : contactIds) {
            HAMPortalProvisioningDTO.ProvisioningResult r =
                new HAMPortalProvisioningDTO.ProvisioningResult(cId);
            resultMap.put(cId, r);
            results.add(r);
        }

        // ── Step 1: Load & validate contacts ──────────────────────────────
        Map<Id, Contact> contactMap = loadContacts(contactIds, resultMap);

        // ── Step 2: Auto-enable IsPartner (non-setup DML) ─────────────────
        if (!contactMap.isEmpty()) {
            autoEnablePartnerAccounts(contactMap, resultMap);
        }

        // ── Step 3: Filter contacts that already have a portal user ────────
        List<Id> validContactIds = new List<Id>();
        if (!contactMap.isEmpty()) {
            validContactIds = filterExistingUsers(
                new List<Id>(contactMap.keySet()), resultMap
            );
        }

        // ── Step 4: Build payloads ─────────────────────────────────────────
        List<HAMPortalProvisioningDTO.ContactPayload> payloads =
            new List<HAMPortalProvisioningDTO.ContactPayload>();

        for (Id cId : validContactIds) {
            Contact c = contactMap.get(cId);
            HAMPortalProvisioningDTO.ProvisioningResult r = resultMap.get(cId);

            HAMPortalProvisioningDTO.ContactPayload p =
                new HAMPortalProvisioningDTO.ContactPayload();
            p.contactId         = c.Id;
            p.firstName         = c.FirstName;
            p.lastName          = c.LastName;
            p.email             = c.Email;
            p.accountId         = c.AccountId;
            p.generatedPassword = HAMPortalProvisioningDTO.generatePassword();
            p.accountWasUpdated = r.accountWasUpdated;
            payloads.add(p);
        }

        // ── Step 5: Enqueue async provisioning ────────────────────────────
        if (!payloads.isEmpty() && sendToQueue) {
            System.enqueueJob(
                new HAMProvisioningQueueable(JSON.serialize(payloads))
            );
        }

        // ── Step 6: Immediately email any sync-phase failures ─────────────
        List<HAMPortalProvisioningDTO.ProvisioningResult> syncFailures =
            new List<HAMPortalProvisioningDTO.ProvisioningResult>();
        for (HAMPortalProvisioningDTO.ProvisioningResult r : results) {
            if (!r.success && String.isNotBlank(r.errorMessage)) {
                syncFailures.add(r);
            }
        }
        if (!syncFailures.isEmpty()) {
            HAMPortalProvisioningDTO.sendSyncFailureEmail(syncFailures);
        }

        HAMPortalProvisioningDTO.SyncPhaseOutcome outcome =
            new HAMPortalProvisioningDTO.SyncPhaseOutcome();
        outcome.results  = results;
        outcome.payloads = payloads;
        return outcome;
    }

    /**
     * Convenience overload for ad-hoc / non-batch callers.
     * Always enqueues the Queueable.
     */
    public static List<HAMPortalProvisioningDTO.ProvisioningResult> provisionUsers(
        List<Id> contactIds
    ) {
        return provisionUsers(contactIds, true).results;
    }

    // ══════════════════════════════════════════════════════════════════════
    // PRIVATE HELPERS
    // ══════════════════════════════════════════════════════════════════════

    private static Map<Id, Contact> loadContacts(
        List<Id> contactIds,
        Map<Id, HAMPortalProvisioningDTO.ProvisioningResult> resultMap
    ) {
        Map<Id, Contact> contactMap = new Map<Id, Contact>();
        try {
            for (Contact c : [
                SELECT Id, FirstName, LastName, Email, AccountId,
                       Account.IsPartner, Account.Name
                FROM   Contact
                WHERE  Id IN :contactIds
            ]) {
                HAMPortalProvisioningDTO.ProvisioningResult r = resultMap.get(c.Id);
                r.contactName  = c.FirstName + ' ' + c.LastName;
                r.contactEmail = c.Email;

                if (String.isBlank(c.Email)) {
                    r.errorMessage = 'Contact has no email address.';
                } else if (c.AccountId == null) {
                    r.errorMessage = 'Contact has no associated Account.';
                } else {
                    contactMap.put(c.Id, c);
                }
            }
        } catch (Exception e) {
            for (Id cId : contactIds) {
                resultMap.get(cId).errorMessage = 'Query error: ' + e.getMessage();
            }
        }
        return contactMap;
    }

    private static void autoEnablePartnerAccounts(
        Map<Id, Contact> contactMap,
        Map<Id, HAMPortalProvisioningDTO.ProvisioningResult> resultMap
    ) {
        Map<Id, Account>  accountsToUpdate  = new Map<Id, Account>();
        Map<Id, List<Id>> accountToContacts = new Map<Id, List<Id>>();

        for (Contact c : contactMap.values()) {
            if (c.Account != null && c.Account.IsPartner != true) {
                if (!accountsToUpdate.containsKey(c.AccountId)) {
                    accountsToUpdate.put(c.AccountId, new Account(
                        Id        = c.AccountId,
                        IsPartner = true
                    ));
                    accountToContacts.put(c.AccountId, new List<Id>());
                }
                accountToContacts.get(c.AccountId).add(c.Id);
            }
        }

        if (accountsToUpdate.isEmpty()) return;

        Database.SaveResult[] updateResults =
            Database.update(accountsToUpdate.values(), false);

        for (Integer i = 0; i < updateResults.size(); i++) {
            Database.SaveResult sr  = updateResults[i];
            Account             acc = accountsToUpdate.values()[i];

            if (sr.isSuccess()) {
                for (Id cId : accountToContacts.get(acc.Id)) {
                    resultMap.get(cId).accountWasUpdated = true;
                }
            } else {
                String errMsg = 'Failed to set Account IsPartner=true: '
                    + sr.getErrors()[0].getMessage();
                for (Id cId : accountToContacts.get(acc.Id)) {
                    resultMap.get(cId).errorMessage = errMsg;
                    contactMap.remove(cId);
                }
            }
        }
    }

    private static List<Id> filterExistingUsers(
        List<Id> contactIds,
        Map<Id, HAMPortalProvisioningDTO.ProvisioningResult> resultMap
    ) {
        Set<Id> alreadyHasUser = new Set<Id>();
        for (User u : [
            SELECT ContactId FROM User WHERE ContactId IN :contactIds
        ]) {
            alreadyHasUser.add(u.ContactId);
        }

        List<Id> filtered = new List<Id>();
        for (Id cId : contactIds) {
            if (alreadyHasUser.contains(cId)) {
                resultMap.get(cId).errorMessage =
                    'Portal user already exists for this contact.';
            } else {
                filtered.add(cId);
            }
        }
        return filtered;
    }
}