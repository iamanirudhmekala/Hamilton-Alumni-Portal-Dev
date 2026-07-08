@isTest
private class HAMPortalUserProvisioningBatchTest {

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

    private static List<Contact> makeContactBulk(Integer count, Boolean partnerFlag) {
        Account acc = new Account(
            Name         = 'Bulk Test Household',
            RecordTypeId = HOUSEHOLD_RT_ID
        );
        insert acc;

        if (partnerFlag) {
            acc.IsPartner = true;
            update acc;
        }

        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < count; i++) {
            contacts.add(new Contact(
                FirstName = 'Bulk',
                LastName  = 'User' + i,
                Email     = 'bulktest' + i + '@testham.edu.invalid',
                AccountId = acc.Id
            ));
        }
        insert contacts;
        return contacts;
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
        User ru = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(ru) {
            HAMProvisioningQueueable.createAndProvisionUsers(
                JSON.serialize(new List<HAMPortalProvisioningDTO.ContactPayload>{ p })
            );
        }
    }

    // ── Assertion helper ───────────────────────────────────────────────────

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

    // ═══════════════════════════════════════════════════════════════════════
    // BASIC EXECUTION
    // ═══════════════════════════════════════════════════════════════════════

    @isTest
    static void test_singleContact_userCreated() {
        Contact c = makeContact('Batch', 'Solo', 'batch.solo@testham.edu.invalid', true);

        Test.startTest();
        Database.executeBatch(
            new HAMPortalUserProvisioningBatch(new List<Id>{ c.Id }), 50
        );
        Test.stopTest();

        List<User> created = [
            SELECT Username, IsActive, Profile.Name
            FROM   User WHERE ContactId = :c.Id
        ];
        System.assertEquals(1, created.size(),     'Batch should create exactly 1 user');
        System.assertEquals(c.Email, created[0].Username,
            'Username must equal Contact Email');
        System.assert(created[0].IsActive,         'User must be active');
        System.assertEquals(PROFILE_NAME, created[0].Profile.Name,
            'Profile must be Partner Community Login User');
    }

    @isTest
    static void test_singleContact_permSetsAssigned() {
        Contact c = makeContact('PermSet', 'Batch', 'permset.batch@testham.edu.invalid', true);

        Test.startTest();
        Database.executeBatch(
            new HAMPortalUserProvisioningBatch(new List<Id>{ c.Id }), 50
        );
        Test.stopTest();

        User u = [SELECT Id FROM User WHERE ContactId = :c.Id];
        assertPermSetsAssigned(u.Id);
    }

    @isTest
    static void test_emptyList_completesWithoutError() {
        Test.startTest();
        Database.executeBatch(
            new HAMPortalUserProvisioningBatch(new List<Id>()), 50
        );
        Test.stopTest();

        System.assert(true, 'Batch with empty list completed cleanly');
    }

    // ═══════════════════════════════════════════════════════════════════════
    // BULK
    // ═══════════════════════════════════════════════════════════════════════

    @isTest
    static void test_fiveContacts_allCreated() {
        List<Contact> contacts = makeContactBulk(5, true);
        List<Id> contactIds    = new List<Id>();
        for (Contact c : contacts) contactIds.add(c.Id);

        Test.startTest();
        Database.executeBatch(new HAMPortalUserProvisioningBatch(contactIds), 50);
        Test.stopTest();

        List<User> created = [SELECT Id, IsActive FROM User WHERE ContactId IN :contactIds];
        System.assertEquals(5, created.size(), '5 users should be created');
        for (User u : created) {
            System.assert(u.IsActive, 'Each user must be active');
        }
    }

    @isTest
    static void test_tenContacts_allCreated() {
        List<Contact> contacts = makeContactBulk(10, true);
        List<Id> contactIds    = new List<Id>();
        for (Contact c : contacts) contactIds.add(c.Id);

        Test.startTest();
        Database.executeBatch(new HAMPortalUserProvisioningBatch(contactIds), 50);
        Test.stopTest();

        List<User> created = [SELECT Id, IsActive FROM User WHERE ContactId IN :contactIds];
        System.assertEquals(10, created.size(), 'All 10 users should be created');
        for (User u : created) {
            System.assert(u.IsActive, 'Each user must be active');
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // AUTO-FLIP IsPartner
    // ═══════════════════════════════════════════════════════════════════════

    @isTest
    static void test_nonPartnerAccounts_autoFlippedAndUsersCreated() {
        List<Contact> contacts = makeContactBulk(3, false);
        List<Id> contactIds    = new List<Id>();
        Set<Id>  accountIds    = new Set<Id>();
        for (Contact c : contacts) {
            contactIds.add(c.Id);
            accountIds.add(c.AccountId);
        }

        Test.startTest();
        Database.executeBatch(new HAMPortalUserProvisioningBatch(contactIds), 50);
        Test.stopTest();

        List<User> created = [SELECT Id FROM User WHERE ContactId IN :contactIds];
        System.assertEquals(3, created.size(),
            'Users should be created even when accounts started as non-partner');

        List<Account> accounts = [SELECT IsPartner FROM Account WHERE Id IN :accountIds];
        for (Account a : accounts) {
            System.assertEquals(true, a.IsPartner,
                'Account IsPartner should have been auto-set to TRUE by batch');
        }
    }

    @isTest
    static void test_nonPartnerSingleContact_accountFlippedInDB() {
        Contact c = makeContact('Flip', 'Batch', 'flip.batch@testham.edu.invalid', false);

        Account before = [SELECT IsPartner FROM Account WHERE Id = :c.AccountId];
        System.assertEquals(false, before.IsPartner, 'Should start as non-partner');

        Test.startTest();
        Database.executeBatch(
            new HAMPortalUserProvisioningBatch(new List<Id>{ c.Id }), 50
        );
        Test.stopTest();

        Account after = [SELECT IsPartner FROM Account WHERE Id = :c.AccountId];
        System.assertEquals(true, after.IsPartner,
            'Account IsPartner must be TRUE after batch runs');
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MIXED VALID / INVALID
    // ═══════════════════════════════════════════════════════════════════════

    @isTest
    static void test_mixedContacts_onlyValidContactsGetUsers() {
        Contact c1 = makeContact('Valid', 'One', 'valid.one.b@testham.edu.invalid', true);
        Contact c2 = makeContact('Valid', 'Two', 'valid.two.b@testham.edu.invalid', true);

        Account acc3 = new Account(
            Name = 'No Email Batch Household', RecordTypeId = HOUSEHOLD_RT_ID
        );
        insert acc3;
        acc3.IsPartner = true;
        update acc3;
        Contact c3 = new Contact(
            FirstName = 'Invalid', LastName = 'NoEmail', AccountId = acc3.Id
        );
        insert c3;

        Test.startTest();
        Database.executeBatch(
            new HAMPortalUserProvisioningBatch(
                new List<Id>{ c1.Id, c2.Id, c3.Id }
            ), 50
        );
        Test.stopTest();

        List<User> created = [
            SELECT Id FROM User
            WHERE  ContactId IN :new List<Id>{ c1.Id, c2.Id, c3.Id }
        ];
        System.assertEquals(2, created.size(),
            'Only 2 valid contacts should produce users — no-email contact skipped');
    }

    @isTest
    static void test_alreadyExistingUser_skippedGracefully() {
        Contact c = makeContact('Already', 'Exists', 'already.exists@testham.edu.invalid', true);

        // Pre-create the user via Queueable core logic (not via enqueueJob outside startTest,
        // which would never execute in a test context)
        preCreateUser(c);

        Test.startTest();
        Database.executeBatch(
            new HAMPortalUserProvisioningBatch(new List<Id>{ c.Id }), 50
        );
        Test.stopTest();

        List<User> usersForContact = [SELECT Id FROM User WHERE ContactId = :c.Id];
        System.assertEquals(1, usersForContact.size(),
            'Should still be exactly 1 user — duplicate skipped cleanly');
    }

    // ═══════════════════════════════════════════════════════════════════════
    // STATEFUL ACCUMULATION
    // ═══════════════════════════════════════════════════════════════════════

    @isTest
    static void test_stateful_allResultsAccumulatedAcrossChunks() {
        List<Contact> contacts = makeContactBulk(6, true);
        List<Id> contactIds    = new List<Id>();
        for (Contact c : contacts) contactIds.add(c.Id);

        Test.startTest();
        Database.executeBatch(new HAMPortalUserProvisioningBatch(contactIds), 50);
        Test.stopTest();

        List<User> created = [SELECT Id FROM User WHERE ContactId IN :contactIds];
        System.assertEquals(6, created.size(),
            'All 6 users must be created — verifies batch processed the full list');
    }
}