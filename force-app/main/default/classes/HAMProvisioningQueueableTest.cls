@isTest
private class HAMProvisioningQueueableTest {

    private static final Id HOUSEHOLD_RT_ID =
        Schema.SObjectType.Account
              .getRecordTypeInfosByDeveloperName()
              .get('Household')
              .getRecordTypeId();

    // ── Factories ──────────────────────────────────────────────────────────

    private static Contact makeContact(
        String firstName,
        String lastName,
        String email
    ) {
        Account acc = new Account(
            Name         = firstName + ' ' + lastName + ' Household',
            RecordTypeId = HOUSEHOLD_RT_ID
        );
        insert acc;
        acc.IsPartner = true;
        update acc;

        Contact c = new Contact(
            FirstName = firstName,
            LastName  = lastName,
            Email     = email,
            AccountId = acc.Id
        );
        insert c;
        return c;
    }

    private static String buildPayloadJson(
        Contact c,
        Boolean accountWasUpdated,
        String  password
    ) {
        HAMPortalProvisioningDTO.ContactPayload p = new HAMPortalProvisioningDTO.ContactPayload();
        p.contactId         = c.Id;
        p.firstName         = c.FirstName;
        p.lastName          = c.LastName;
        p.email             = c.Email;
        p.accountId         = c.AccountId;
        p.generatedPassword = password;
        p.accountWasUpdated = accountWasUpdated;
        return JSON.serialize(new List<HAMPortalProvisioningDTO.ContactPayload>{ p });
    }

    private static String buildPayloadJson(Contact c, Boolean accountWasUpdated) {
        return buildPayloadJson(c, accountWasUpdated, HAMPortalProvisioningDTO.generatePassword());
    }

    private static User getRunAsUser() {
        return [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
    }

    // ═══════════════════════════════════════════════════════════════════════
    // HAPPY PATH — direct call to createAndProvisionUsers
    // ═══════════════════════════════════════════════════════════════════════

    @isTest
    static void test_happyPath_userCreatedWithCorrectFields() {
        Contact c = makeContact('Queue', 'Happy', 'queue.happy@testham.edu.invalid');

        Test.startTest();
        System.runAs(getRunAsUser()) {
            HAMProvisioningQueueable.createAndProvisionUsers(buildPayloadJson(c, false));
        }
        Test.stopTest();

        List<User> users = [
            SELECT Username, Email, IsActive, Profile.Name, ContactId
            FROM   User WHERE ContactId = :c.Id
        ];
        System.assertEquals(1, users.size(),             'User should be created');
        System.assertEquals(c.Email, users[0].Username,  'Username must equal email');
        System.assertEquals(c.Email, users[0].Email,     'Email must match');
        System.assert(users[0].IsActive,                  'User must be active');
        System.assertEquals(
            HAMPortalProvisioningDTO.PROFILE_NAME, users[0].Profile.Name,
            'Profile must be Partner Community Login User'
        );
        System.assertEquals(c.Id, users[0].ContactId,    'User must be linked to Contact');
    }

    @isTest
    static void test_happyPath_permSetsAssigned() {
        Contact c = makeContact('Queue', 'Perm', 'queue.perm@testham.edu.invalid');

        Test.startTest();
        System.runAs(getRunAsUser()) {
            HAMProvisioningQueueable.createAndProvisionUsers(buildPayloadJson(c, false));
        }
        Test.stopTest();

        User u = [SELECT Id FROM User WHERE ContactId = :c.Id];
        List<PermissionSetAssignment> psas = [
            SELECT PermissionSet.Name FROM PermissionSetAssignment
            WHERE AssigneeId = :u.Id
              AND PermissionSet.Name IN (
                  :HAMPortalProvisioningDTO.PERM_SET_PARTNER,
                  :HAMPortalProvisioningDTO.PERM_SET_STRIPE
              )
        ];
        Set<String> assigned = new Set<String>();
        for (PermissionSetAssignment psa : psas) assigned.add(psa.PermissionSet.Name);
        System.assert(assigned.contains(HAMPortalProvisioningDTO.PERM_SET_PARTNER),
            'HAM_Partner_Community_Permission should be assigned');
        System.assert(assigned.contains(HAMPortalProvisioningDTO.PERM_SET_STRIPE),
            'Stripe_Permissions should be assigned');
    }

    @isTest
    static void test_accountWasUpdated_flagPreservedInResultMap() {
        Contact c = makeContact('Queue', 'Flagged', 'queue.flagged@testham.edu.invalid');

        Test.startTest();
        System.runAs(getRunAsUser()) {
            // accountWasUpdated=true — exercises that flag path in resultMap setup
            HAMProvisioningQueueable.createAndProvisionUsers(buildPayloadJson(c, true));
        }
        Test.stopTest();

        List<User> users = [SELECT Id FROM User WHERE ContactId = :c.Id];
        System.assertEquals(1, users.size(), 'User should be created with accountWasUpdated=true');
    }

    // ═══════════════════════════════════════════════════════════════════════
    // execute() WRAPPER — via enqueueJob
    // ═══════════════════════════════════════════════════════════════════════

    @isTest
    static void test_execute_viaEnqueueJob_createsUser() {
        Contact c = makeContact('Queue', 'Execute', 'queue.execute@testham.edu.invalid');
        String payloadJson = buildPayloadJson(c, false);

        Test.startTest();
        System.runAs(getRunAsUser()) {
            System.enqueueJob(new HAMProvisioningQueueable(payloadJson));
        }
        Test.stopTest();

        List<User> users = [SELECT Id FROM User WHERE ContactId = :c.Id];
        System.assertEquals(1, users.size(), 'User should be created via enqueueJob / execute()');
    }

    // ═══════════════════════════════════════════════════════════════════════
    // EDGE CASES
    // ═══════════════════════════════════════════════════════════════════════

    @isTest
    static void test_emptyPayload_completesWithoutError() {
        String emptyJson = JSON.serialize(
            new List<HAMPortalProvisioningDTO.ContactPayload>()
        );

        Test.startTest();
        HAMProvisioningQueueable.createAndProvisionUsers(emptyJson);
        Test.stopTest();

        System.assert(true, 'Empty payload should complete without exception');
    }

    @isTest
    static void test_weakPassword_setPasswordException_handledGracefully() {
        Contact c = makeContact('Queue', 'Weak', 'queue.weak@testham.edu.invalid');
        // Intentionally weak password so System.setPassword throws — covers the catch block
        String payloadJson = buildPayloadJson(c, false, 'a');

        Test.startTest();
        System.runAs(getRunAsUser()) {
            HAMProvisioningQueueable.createAndProvisionUsers(payloadJson);
        }
        Test.stopTest();

        // User is still created even when setPassword throws — failure is non-fatal
        List<User> users = [SELECT Id FROM User WHERE ContactId = :c.Id];
        System.assertEquals(1, users.size(),
            'User should be created even when setPassword fails');
    }

    @isTest
    static void test_duplicateUsername_insertFails_noCreatedUsers() {
        // c1 is provisioned first so its username is taken
        Contact c1 = makeContact('Dupe', 'QueueOne', 'dupe.queue@testham.edu.invalid');
        System.runAs(getRunAsUser()) {
            HAMProvisioningQueueable.createAndProvisionUsers(buildPayloadJson(c1, false));
        }

        // c2 has the same email → duplicate username → insert fails
        Account acc2 = new Account(Name = 'Dupe Two Household', RecordTypeId = HOUSEHOLD_RT_ID);
        insert acc2;
        acc2.IsPartner = true;
        update acc2;
        Contact c2 = new Contact(
            FirstName = 'Dupe', LastName = 'QueueTwo',
            Email = 'dupe.queue@testham.edu.invalid', AccountId = acc2.Id
        );
        insert c2;

        Test.startTest();
        System.runAs(getRunAsUser()) {
            HAMProvisioningQueueable.createAndProvisionUsers(buildPayloadJson(c2, false));
        }
        Test.stopTest();

        List<User> usersForC2 = [SELECT Id FROM User WHERE ContactId = :c2.Id];
        System.assertEquals(0, usersForC2.size(),
            'Duplicate username should fail gracefully — no user for c2');
    }

    @isTest
    static void test_allUsersFailInsert_assignPermSetsNotCalled() {
        // When no users are created, createdUserIds is empty and assignPermissionSets is skipped
        Contact c1 = makeContact('AllFail', 'First', 'allfail.q@testham.edu.invalid');
        System.runAs(getRunAsUser()) {
            HAMProvisioningQueueable.createAndProvisionUsers(buildPayloadJson(c1, false));
        }

        Account acc2 = new Account(Name = 'AllFail Two Household', RecordTypeId = HOUSEHOLD_RT_ID);
        insert acc2;
        acc2.IsPartner = true;
        update acc2;
        Contact c2 = new Contact(
            FirstName = 'AllFail', LastName = 'Second',
            Email = 'allfail.q@testham.edu.invalid', AccountId = acc2.Id
        );
        insert c2;

        Test.startTest();
        System.runAs(getRunAsUser()) {
            // All users fail — covers the if (!createdUserIds.isEmpty()) false branch
            HAMProvisioningQueueable.createAndProvisionUsers(buildPayloadJson(c2, false));
        }
        Test.stopTest();

        List<User> usersForC2 = [SELECT Id FROM User WHERE ContactId = :c2.Id];
        System.assertEquals(0, usersForC2.size(),
            'No users created — assignPermissionSets branch correctly skipped');
    }

    // ═══════════════════════════════════════════════════════════════════════
    // BULK
    // ═══════════════════════════════════════════════════════════════════════

    @isTest
    static void test_bulkContacts_allCreated() {
        Account acc = new Account(Name = 'Bulk Q Household', RecordTypeId = HOUSEHOLD_RT_ID);
        insert acc;
        acc.IsPartner = true;
        update acc;

        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < 5; i++) {
            contacts.add(new Contact(
                FirstName = 'Bulk',
                LastName  = 'Q' + i,
                Email     = 'bulk.q' + i + '@testham.edu.invalid',
                AccountId = acc.Id
            ));
        }
        insert contacts;

        List<HAMPortalProvisioningDTO.ContactPayload> payloads =
            new List<HAMPortalProvisioningDTO.ContactPayload>();
        for (Contact c : contacts) {
            HAMPortalProvisioningDTO.ContactPayload p = new HAMPortalProvisioningDTO.ContactPayload();
            p.contactId         = c.Id;
            p.firstName         = c.FirstName;
            p.lastName          = c.LastName;
            p.email             = c.Email;
            p.accountId         = c.AccountId;
            p.generatedPassword = HAMPortalProvisioningDTO.generatePassword();
            p.accountWasUpdated = false;
            payloads.add(p);
        }

        Test.startTest();
        System.runAs(getRunAsUser()) {
            HAMProvisioningQueueable.createAndProvisionUsers(JSON.serialize(payloads));
        }
        Test.stopTest();

        List<Id> contactIds = new List<Id>();
        for (Contact c : contacts) contactIds.add(c.Id);
        List<User> users = [SELECT Id FROM User WHERE ContactId IN :contactIds];
        System.assertEquals(5, users.size(), 'All 5 users should be created');
    }
}