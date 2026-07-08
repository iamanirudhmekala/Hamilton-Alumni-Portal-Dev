/**
 * HAMProvisioningQueueable
 *
 * Async execution unit enqueued by HAMPortalUserProvisioningService.
 * Handles all setup DML (User insert, PermissionSetAssignment insert) and
 * System.setPassword() in a single Queueable context.
 *
 * Inside a Queueable execution context the platform relaxes the
 * MIXED_DML_OPERATION restriction, so setup DML and System.setPassword()
 * (non-setup) can run sequentially in the same method.
 *
 * Depends on: HAMPortalProvisioningDTO  (deploy that class first)
 */
public class HAMProvisioningQueueable implements Queueable {

    private String payloadJson;

    public HAMProvisioningQueueable(String payloadJson) {
        this.payloadJson = payloadJson;
        System.debug('payloadJson - '+payloadJson);
    }

    public void execute(QueueableContext ctx) {
        createAndProvisionUsers(payloadJson);
    }

    // ══════════════════════════════════════════════════════════════════════
    // CORE LOGIC — public so unit tests can call it directly
    // ══════════════════════════════════════════════════════════════════════

    public static void createAndProvisionUsers(String payloadJson) {

        List<HAMPortalProvisioningDTO.ContactPayload> payloads =
            (List<HAMPortalProvisioningDTO.ContactPayload>)
                JSON.deserialize(
                    payloadJson,
                    List<HAMPortalProvisioningDTO.ContactPayload>.class
                );
                System.debug('inside execute - ');

        List<HAMPortalProvisioningDTO.ProvisioningResult>    results   =
            new List<HAMPortalProvisioningDTO.ProvisioningResult>();
        Map<Id, HAMPortalProvisioningDTO.ProvisioningResult> resultMap =
            new Map<Id, HAMPortalProvisioningDTO.ProvisioningResult>();

        for (HAMPortalProvisioningDTO.ContactPayload p : payloads) {
            HAMPortalProvisioningDTO.ProvisioningResult r =
                new HAMPortalProvisioningDTO.ProvisioningResult(p.contactId);
            r.contactName       = p.firstName + ' ' + p.lastName;
            r.contactEmail      = p.email;
            r.accountWasUpdated = p.accountWasUpdated;
            resultMap.put(p.contactId, r);
            results.add(r);
        }

        // ── Step 1: Profile ────────────────────────────────────────────────
        List<Profile> profiles = [
            SELECT Id FROM Profile
            WHERE  Name = :HAMPortalProvisioningDTO.PROFILE_NAME
            LIMIT  1
        ];
        System.debug('Profiles - '+profiles);
        if (profiles.isEmpty()) {
            for (HAMPortalProvisioningDTO.ProvisioningResult r : results) {
                r.errorMessage = 'Profile not found: '
                    + HAMPortalProvisioningDTO.PROFILE_NAME;
            }
            HAMPortalProvisioningDTO.sendResultEmail(results);
            System.debug('results - '+results);
            return;
        }
        Id profileId = profiles[0].Id;

        // ── Step 2: Insert Users (setup DML) ──────────────────────────────
        List<User> usersToInsert = new List<User>();
        for (HAMPortalProvisioningDTO.ContactPayload p : payloads) {
            usersToInsert.add(new User(
                FirstName            = p.firstName,
                LastName             = p.lastName,
                Email                = p.email,
                Username             = p.email,
                FederationIdentifier = p.email,
                Alias                = HAMPortalProvisioningDTO.buildAlias(
                                           p.firstName, p.lastName, p.contactId),
                CommunityNickname    = HAMPortalProvisioningDTO.buildNickname(
                                           p.firstName, p.lastName, p.contactId),
                ContactId            = p.contactId,
                ProfileId            = profileId,
                IsActive             = true,
                EmailEncodingKey     = 'UTF-8',
                LanguageLocaleKey    = 'en_US',
                LocaleSidKey         = 'en_US',
                TimeZoneSidKey       = 'America/New_York'
            ));
        }

        Database.SaveResult[] saveResults = Database.insert(usersToInsert, false);
        List<Id> createdUserIds = new List<Id>();

        for (Integer i = 0; i < saveResults.size(); i++) {
            Database.SaveResult sr = saveResults[i];
            User                u  = usersToInsert[i];
            HAMPortalProvisioningDTO.ProvisioningResult r =
                resultMap.get(u.ContactId);

            if (sr.isSuccess()) {
                r.userId  = sr.getId();
                r.success = true;
                createdUserIds.add(r.userId);
            } else {
                List<String> errs = new List<String>();
                for (Database.Error e : sr.getErrors()) {
                    errs.add(e.getMessage());
                }
                r.errorMessage = String.join(errs, '; ');
            }
        }

        // ── Step 3: Assign permission sets (setup DML) ────────────────────
        if (!createdUserIds.isEmpty()) {
            assignPermissionSets(createdUserIds, resultMap);
        }

        // ── Step 4: Set passwords silently (non-setup — safe in Queueable) ─
        for (HAMPortalProvisioningDTO.ContactPayload p : payloads) {
            HAMPortalProvisioningDTO.ProvisioningResult r =
                resultMap.get(p.contactId);
            if (r.success && r.userId != null) {
                try {
                    System.debug('Password set is '+p.generatedPassword);
                    System.setPassword(r.userId, p.generatedPassword);
                    System.debug(LoggingLevel.INFO,
                        'Password set silently for userId: ' + r.userId);
                } catch (Exception e) {
                    System.debug(LoggingLevel.WARN,
                        'setPassword failed for userId ' + r.userId
                        + ': ' + e.getMessage());
                }
            }
        }

        // ── Step 5: Per-chunk result email ─────────────────────────────────
        HAMPortalProvisioningDTO.sendResultEmail(results);
    }

    // ══════════════════════════════════════════════════════════════════════
    // PRIVATE HELPERS
    // ══════════════════════════════════════════════════════════════════════

    private static void assignPermissionSets(
        List<Id> userIds,
        Map<Id, HAMPortalProvisioningDTO.ProvisioningResult> resultMap
    ) {
        Map<String, Id> permSetMap = new Map<String, Id>();
        for (PermissionSet ps : [
            SELECT Id, Name
            FROM   PermissionSet
            WHERE  Name IN (
                :HAMPortalProvisioningDTO.PERM_SET_PARTNER,
                :HAMPortalProvisioningDTO.PERM_SET_STRIPE
            )
        ]) {
            permSetMap.put(ps.Name, ps.Id);
        }

        if (!permSetMap.containsKey(HAMPortalProvisioningDTO.PERM_SET_PARTNER)
            || !permSetMap.containsKey(HAMPortalProvisioningDTO.PERM_SET_STRIPE)) {
            System.debug(LoggingLevel.WARN,
                'One or more permission sets not found. Found: '
                + permSetMap.keySet());
            return;
        }

        Id partnerPermSetId = permSetMap.get(HAMPortalProvisioningDTO.PERM_SET_PARTNER);
        Id stripePermSetId  = permSetMap.get(HAMPortalProvisioningDTO.PERM_SET_STRIPE);

        Set<Id>     userIdSet       = new Set<Id>(userIds);
        Set<String> alreadyAssigned = new Set<String>();
        for (PermissionSetAssignment existing : [
            SELECT AssigneeId, PermissionSetId
            FROM   PermissionSetAssignment
            WHERE  AssigneeId IN :userIdSet
              AND  PermissionSetId IN (:partnerPermSetId, :stripePermSetId)
        ]) {
            alreadyAssigned.add(
                existing.AssigneeId + '_' + existing.PermissionSetId
            );
        }

        List<PermissionSetAssignment> assignments =
            new List<PermissionSetAssignment>();
        for (Id uId : userIds) {
            if (!alreadyAssigned.contains(uId + '_' + partnerPermSetId)) {
                assignments.add(new PermissionSetAssignment(
                    AssigneeId      = uId,
                    PermissionSetId = partnerPermSetId
                ));
            }
            if (!alreadyAssigned.contains(uId + '_' + stripePermSetId)) {
                assignments.add(new PermissionSetAssignment(
                    AssigneeId      = uId,
                    PermissionSetId = stripePermSetId
                ));
            }
        }

        if (assignments.isEmpty()) return;

        Database.SaveResult[] psaResults = Database.insert(assignments, false);
        for (Integer i = 0; i < psaResults.size(); i++) {
            if (!psaResults[i].isSuccess()) {
                System.debug(LoggingLevel.WARN,
                    'PSA insert failed: '
                    + psaResults[i].getErrors()[0].getMessage());
            }
        }
    }
}