@isTest
private class HAMPortalUserProvisioningServiceTest {

    private static final String PROFILE_NAME = 'Partner Community Login User';
    private static final String PERM_PARTNER = 'HAM_Partner_Community_Permission';
    private static final String PERM_STRIPE  = 'Stripe_Permissions';

    private static final Id HOUSEHOLD_RT_ID =
        Schema.SObjectType.Account
              .getRecordTypeInfosByDeveloperName()
              .get('Household')
              .getRecordTypeId();

    // ── Factories ──────────────────────────────────────────────────────────

    private static Contact makeContact(
        String firstName,
        String lastName,
        String email,
        Boolean partnerFlag
    ) {
        Account acc = new Account(
            Name         = firstName + ' ' + lastName + ' Household',
            RecordTypeId = HOUSEHOLD_RT_ID
        );
        insert acc;

        if (partnerFlag) {
            acc.IsPartner = true;
            update acc;
        }

        Contact c = new Contact(
            FirstName = firstName,
            LastName  = lastName,
            Email     = email,
            AccountId = acc.Id
        );
        insert c;
        return c;
    }

    private static User getRunAsUser() {
        return [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
    }

    private static void assertPermSetsAssigned(Id userId) {
        List<PermissionSetAssignment> psas = [
            SELECT PermissionSet.Name
            FROM   PermissionSetAssignment
            WHERE  AssigneeId = :userId
              AND  PermissionSet.Name IN (:PERM_PARTNER, :PERM_STRIPE)
        ];
        Set<String> assigned = new Set<String>();
        for (PermissionSetAssignment psa : psas) {
            assigned.add(psa.PermissionSet.Name);
        }
        System.assert(assigned.contains(PERM_PARTNER),
            'HAM_Partner_Community_Permission should be assigned');
        System.assert(assigned.contains(PERM_STRIPE),
            'Stripe_Permissions should be assigned');
    }

    // Helper: pre-create a portal User for a Contact via Queueable core logic.
    // Used outside startTest/stopTest where enqueueJob would never execute.
    private static void preCreateUser(Contact c) {
        HAMPortalProvisioningDTO.ContactPayload p = new HAMPortalProvisioningDTO.ContactPayload();
        p.contactId         = c.Id;
        p.firstName         = c.FirstName;
        p.lastName          = c.LastName;
        p.email             = c.Email;
        p.accountId         = c.AccountId;
        p.generatedPassword = HAMPortalProvisioningDTO.generatePassword();
        p.accountWasUpdated = false;
        System.runAs(getRunAsUser()) {
            HAMProvisioningQueueable.createAndProvisionUsers(
                JSON.serialize(new List<HAMPortalProvisioningDTO.ContactPayload>{ p })
            );
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // SYNC PHASE — provisionUsers(ids, sendToQueue=false)
    // Tests the service in isolation: no Queueable, no User DML.
    // ═══════════════════════════════════════════════════════════════════════

    @isTest
    static void test_syncPhase_validContact_payloadBuilt() {
        Contact c = makeContact('Jane', 'Doe', 'jane.doe.svc@testham.edu.invalid', true);

        Test.startTest();
        HAMPortalProvisioningDTO.SyncPhaseOutcome outcome =
            HAMPortalUserProvisioningService.provisionUsers(new List<Id>{ c.Id }, false);
        Test.stopTest();

        System.assertEquals(1, outcome.results.size(),  'Should return 1 result');
        System.assertEquals(1, outcome.payloads.size(), 'Should build 1 payload');

        HAMPortalProvisioningDTO.ProvisioningResult r = outcome.results[0];
        System.assertEquals(c.Id,    r.contactId,    'contactId should match');
        System.assertEquals(c.Email, r.contactEmail, 'contactEmail should match');
        System.assertEquals('Jane Doe', r.contactName, 'contactName should be set');
        System.assertEquals(null, r.errorMessage,    'No error for valid contact');
        System.assertEquals(false, r.accountWasUpdated, 'Account was already partner');
    }

    @isTest
    static void test_syncPhase_nonPartnerAccount_accountWasUpdatedTrue() {
        Contact c = makeContact('John', 'Flip', 'john.flip.svc@testham.edu.invalid', false);

        Test.startTest();
        HAMPortalProvisioningDTO.SyncPhaseOutcome outcome =
            HAMPortalUserProvisioningService.provisionUsers(new List<Id>{ c.Id }, false);
        Test.stopTest();

        HAMPortalProvisioningDTO.ProvisioningResult r = outcome.results[0];
        System.assertEquals(null, r.errorMessage,    'No error after auto-flip');
        System.assert(r.accountWasUpdated,           'accountWasUpdated must be true');
        System.assertEquals(1, outcome.payloads.size(), 'Payload built after flip');

        Account after = [SELECT IsPartner FROM Account WHERE Id = :c.AccountId];
        System.assertEquals(true, after.IsPartner, 'Account should be flipped in DB');
    }

    @isTest
    static void test_syncPhase_noEmail_errorSet() {
        Account acc = new Account(Name = 'No Email Svc Household', RecordTypeId = HOUSEHOLD_RT_ID);
        insert acc;
        acc.IsPartner = true;
        update acc;
        Contact c = new Contact(FirstName = 'No', LastName = 'EmailSvc', AccountId = acc.Id);
        insert c;

        Test.startTest();
        HAMPortalProvisioningDTO.SyncPhaseOutcome outcome =
            HAMPortalUserProvisioningService.provisionUsers(new List<Id>{ c.Id }, false);
        Test.stopTest();

        HAMPortalProvisioningDTO.ProvisioningResult r = outcome.results[0];
        System.assertNotEquals(null, r.errorMessage, 'Error message should be set');
        System.assert(r.errorMessage.containsIgnoreCase('email'),
            'Error should mention email, got: ' + r.errorMessage);
        System.assertEquals(0, outcome.payloads.size(), 'No payload for failed contact');
    }

    @isTest
    static void test_syncPhase_emptyList_returnsEmpty() {
        Test.startTest();
        HAMPortalProvisioningDTO.SyncPhaseOutcome outcome =
            HAMPortalUserProvisioningService.provisionUsers(new List<Id>(), false);
        Test.stopTest();

        System.assertEquals(0, outcome.results.size(),  'Empty input returns empty results');
        System.assertEquals(0, outcome.payloads.size(), 'Empty input returns empty payloads');
    }

    @isTest
    static void test_syncPhase_existingUser_filteredOut() {
        Contact c = makeContact('Existing', 'SvcUser', 'existing.svcuser@testham.edu.invalid', true);
        preCreateUser(c);

        Test.startTest();
        HAMPortalProvisioningDTO.SyncPhaseOutcome outcome =
            HAMPortalUserProvisioningService.provisionUsers(new List<Id>{ c.Id }, false);
        Test.stopTest();

        HAMPortalProvisioningDTO.ProvisioningResult r = outcome.results[0];
        System.assertNotEquals(null, r.errorMessage,
            'Error should be set for contact with existing user');
        System.assert(r.errorMessage.containsIgnoreCase('already exists'),
            'Error should mention already exists, got: ' + r.errorMessage);
        System.assertEquals(0, outcome.payloads.size(), 'No payload when user already exists');
    }

    @isTest
    static void test_syncPhase_mixedContacts_correctResults() {
        Contact c1 = makeContact('Alice', 'SvcOk',   'alice.svcok@testham.edu.invalid',   true);
        Contact c3 = makeContact('Charlie', 'SvcFlp', 'charlie.svcflp@testham.edu.invalid', false);

        Account acc2 = new Account(
            Name = 'NoEmail Svc Household', RecordTypeId = HOUSEHOLD_RT_ID
        );
        insert acc2;
        acc2.IsPartner = true;
        update acc2;
        Contact c2 = new Contact(FirstName = 'Bob', LastName = 'SvcNoEmail', AccountId = acc2.Id);
        insert c2;

        Test.startTest();
        HAMPortalProvisioningDTO.SyncPhaseOutcome outcome =
            HAMPortalUserProvisioningService.provisionUsers(
                new List<Id>{ c1.Id, c2.Id, c3.Id }, false
            );
        Test.stopTest();

        System.assertEquals(3, outcome.results.size(),  'Should return 3 results');
        System.assertEquals(2, outcome.payloads.size(), '2 payloads (c2 has no email)');

        Map<Id, HAMPortalProvisioningDTO.ProvisioningResult> resultMap =
            new Map<Id, HAMPortalProvisioningDTO.ProvisioningResult>();
        for (HAMPortalProvisioningDTO.ProvisioningResult r : outcome.results) {
            resultMap.put(r.contactId, r);
        }

        System.assertEquals(null, resultMap.get(c1.Id).errorMessage,   'c1 should have no error');
        System.assertNotEquals(null, resultMap.get(c2.Id).errorMessage, 'c2 should have error');
        System.assertEquals(null, resultMap.get(c3.Id).errorMessage,   'c3 should have no error after flip');
        System.assert(resultMap.get(c3.Id).accountWasUpdated,          'c3 accountWasUpdated must be true');
    }

    // ═══════════════════════════════════════════════════════════════════════
    // CONVENIENCE OVERLOAD — provisionUsers(ids)
    // ═══════════════════════════════════════════════════════════════════════

    @isTest
    static void test_convenientOverload_returnsResultsList() {
        Contact c = makeContact('Conv', 'Test', 'conv.test.svc@testham.edu.invalid', true);

        Test.startTest();
        List<HAMPortalProvisioningDTO.ProvisioningResult> results =
            HAMPortalUserProvisioningService.provisionUsers(new List<Id>{ c.Id });
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Convenience overload should return 1 result');
        System.assertEquals(c.Id, results[0].contactId, 'contactId should match');
    }

    // ═══════════════════════════════════════════════════════════════════════
    // END-TO-END — sync + Queueable both run within startTest/stopTest
    // ═══════════════════════════════════════════════════════════════════════

    @isTest
    static void test_e2e_userCreatedWithCorrectFields() {
        Contact c = makeContact('Jane', 'E2E', 'jane.e2e.svc@testham.edu.invalid', true);

        Test.startTest();
        System.runAs(getRunAsUser()) {
            HAMPortalUserProvisioningService.provisionUsers(new List<Id>{ c.Id });
        }
        Test.stopTest();

        User u = [
            SELECT Username, Email, IsActive, Profile.Name, ContactId
            FROM   User WHERE ContactId = :c.Id
        ];
        System.assertEquals(c.Email,      u.Username,      'Username must equal Contact Email');
        System.assertEquals(c.Email,      u.Email,         'Email must match');
        System.assert(u.IsActive,                           'User must be active');
        System.assertEquals(PROFILE_NAME, u.Profile.Name,  'Profile must be Partner Community Login User');
        System.assertEquals(c.Id,         u.ContactId,     'User must be linked to Contact');
    }

    @isTest
    static void test_e2e_permSetsAssigned() {
        Contact c = makeContact('Perm', 'E2E', 'perm.e2e.svc@testham.edu.invalid', true);

        Test.startTest();
        System.runAs(getRunAsUser()) {
            HAMPortalUserProvisioningService.provisionUsers(new List<Id>{ c.Id });
        }
        Test.stopTest();

        User u = [SELECT Id FROM User WHERE ContactId = :c.Id];
        assertPermSetsAssigned(u.Id);
    }

    @isTest
    static void test_e2e_nonPartnerAccount_userCreatedAccountFlipped() {
        Contact c = makeContact('Flip', 'E2E', 'flip.e2e.svc@testham.edu.invalid', false);

        Test.startTest();
        System.runAs(getRunAsUser()) {
            HAMPortalUserProvisioningService.provisionUsers(new List<Id>{ c.Id });
        }
        Test.stopTest();

        List<User> users = [SELECT Id FROM User WHERE ContactId = :c.Id];
        System.assertEquals(1, users.size(), 'User should be created even with non-partner account');

        Account after = [SELECT IsPartner FROM Account WHERE Id = :c.AccountId];
        System.assertEquals(true, after.IsPartner, 'Account should be flipped to partner');
    }

    @isTest
    static void test_e2e_alreadyExistingUser_skippedGracefully() {
        Contact c = makeContact('Already', 'E2E', 'already.e2e.svc@testham.edu.invalid', true);
        preCreateUser(c);

        Test.startTest();
        System.runAs(getRunAsUser()) {
            HAMPortalUserProvisioningService.provisionUsers(new List<Id>{ c.Id });
        }
        Test.stopTest();

        List<User> users = [SELECT Id FROM User WHERE ContactId = :c.Id];
        System.assertEquals(1, users.size(), 'Should still be exactly 1 user — duplicate skipped');
    }

    @isTest
    static void test_e2e_duplicateEmail_oneSucceedsOneFails() {
        Account acc = new Account(Name = 'Dupe Svc Household', RecordTypeId = HOUSEHOLD_RT_ID);
        insert acc;
        acc.IsPartner = true;
        update acc;

        Contact c1 = new Contact(
            FirstName = 'Twin', LastName = 'SvcOne',
            Email = 'twin.svc@testham.edu.invalid', AccountId = acc.Id
        );
        Contact c2 = new Contact(
            FirstName = 'Twin', LastName = 'SvcTwo',
            Email = 'twin.svc@testham.edu.invalid', AccountId = acc.Id
        );
        insert new List<Contact>{ c1, c2 };

        Test.startTest();
        System.runAs(getRunAsUser()) {
            HAMPortalUserProvisioningService.provisionUsers(
                new List<Id>{ c1.Id, c2.Id }
            );
        }
        Test.stopTest();

        List<User> users = [
            SELECT Id FROM User WHERE ContactId IN :new List<Id>{ c1.Id, c2.Id }
        ];
        System.assertEquals(1, users.size(),
            'Only one user should be created for duplicate email');
    }

    @isTest
    static void test_e2e_mixedContacts_partialSuccess() {
        Contact c1 = makeContact('Alice', 'SvcGood', 'alice.svcgood@testham.edu.invalid', true);
        Contact c3 = makeContact('Charlie', 'SvcFlp', 'charlie.svcflip@testham.edu.invalid', false);

        Account acc2 = new Account(
            Name = 'NoEmail Svc2 Household', RecordTypeId = HOUSEHOLD_RT_ID
        );
        insert acc2;
        acc2.IsPartner = true;
        update acc2;
        Contact c2 = new Contact(
            FirstName = 'Bob', LastName = 'SvcNoEmail2', AccountId = acc2.Id
        );
        insert c2;

        Test.startTest();
        System.runAs(getRunAsUser()) {
            HAMPortalUserProvisioningService.provisionUsers(
                new List<Id>{ c1.Id, c2.Id, c3.Id }
            );
        }
        Test.stopTest();

        List<User> users = [
            SELECT Id FROM User
            WHERE  ContactId IN :new List<Id>{ c1.Id, c2.Id, c3.Id }
        ];
        System.assertEquals(2, users.size(),
            '2 of 3 contacts should get users (c2 skipped — no email)');
    }
}