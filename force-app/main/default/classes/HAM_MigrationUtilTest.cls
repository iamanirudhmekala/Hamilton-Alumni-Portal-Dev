/**
 * HAM_MigrationUtilTest
 * ─────────────────────────────────────────────────────────────────────────────
 * Test class for HAM_MigrationUtil.
 * Target coverage: 100%
 *
 * Change Log:
 *   v1.0  2026-04-09  Initial deployment
 *   v1.1  2026-04-14  PMD static analysis fixes (RunAs, ApexDoc)
 * @description Test class for HAM_MigrationUtil covering all utility methods.
 */
@isTest
private class HAM_MigrationUtilTest {

    @isTest
    static void testGenerateUUID() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            String uuid = HAM_MigrationUtil.generateUUID();
            System.assertNotEquals(null, uuid, 'UUID should not be null');
            System.assertEquals(36, uuid.length(), 'UUID should be 36 chars');
            System.assert(uuid.contains('-'), 'UUID should contain hyphens');
            // Verify two calls produce different values
            String uuid2 = HAM_MigrationUtil.generateUUID();
            System.assertNotEquals(uuid, uuid2, 'UUIDs should be unique');
        }
    }

    @isTest
    static void testGenerateCode() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            String code = HAM_MigrationUtil.generateCode();
            System.assertNotEquals(null, code, 'Code should not be null');
            System.assertEquals(18, code.length(), 'Code should be 18 chars');
        }
    }

    @isTest
    static void testTruncate() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            System.assertEquals(null,    HAM_MigrationUtil.truncate(null, 10),                  'Null input → null');
            System.assertEquals('Hello', HAM_MigrationUtil.truncate('Hello', 10),               'Short string unchanged');
            System.assertEquals('Hello', HAM_MigrationUtil.truncate('Hello', 5),                'Exact length unchanged');
            System.assertEquals('Hello', HAM_MigrationUtil.truncate('Hello World', 5),          'Truncated correctly');
            System.assertEquals('1812/JBA', HAM_MigrationUtil.truncate('1812/JBA', 30),         'Category fits 30-char limit');
        }
    }

    @isTest
    static void testMapEventStatus() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            System.assertEquals('Upcoming',  HAM_MigrationUtil.mapEventStatus('Active'));
            System.assertEquals('Completed', HAM_MigrationUtil.mapEventStatus('Completed'));
            System.assertEquals('Cancelled', HAM_MigrationUtil.mapEventStatus('Cancelled'));
            System.assertEquals('Upcoming',  HAM_MigrationUtil.mapEventStatus(null),   'Null → Upcoming default');
            System.assertEquals('Upcoming',  HAM_MigrationUtil.mapEventStatus('Unknown'), 'Unknown → Upcoming default');
        }
    }

    @isTest
    static void testMapAttendeeStatus() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            // Live statuses confirmed from FullQA (ref event: 502 Registered, 42 Canceled, 2 Declined, 2 null)
            System.assertEquals('Accepted',             HAM_MigrationUtil.mapAttendeeStatus('Registered'));
            System.assertEquals('Invitation Sent',      HAM_MigrationUtil.mapAttendeeStatus('Invited'));
            System.assertEquals('Cancelled',            HAM_MigrationUtil.mapAttendeeStatus('Canceled'));
            System.assertEquals('Declined',             HAM_MigrationUtil.mapAttendeeStatus('Declined'));
            System.assertEquals('Waitlisted',           HAM_MigrationUtil.mapAttendeeStatus('Waitlisted - Pending'));
            System.assertEquals('Invitation Not Sent',  HAM_MigrationUtil.mapAttendeeStatus('To Invite'));
            System.assertEquals('Registration Pending', HAM_MigrationUtil.mapAttendeeStatus('Pending'));
            System.assertEquals('No Response',          HAM_MigrationUtil.mapAttendeeStatus(null));
            System.assertEquals('No Response',          HAM_MigrationUtil.mapAttendeeStatus('Unknown'));
        }
    }

    @isTest
    static void testMapCapacity() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            System.assertEquals(0,   HAM_MigrationUtil.mapCapacity(null),         'Null → 0 (unlimited)');
            System.assertEquals(0,   HAM_MigrationUtil.mapCapacity(999999),       'Large → 0 (unlimited)');
            System.assertEquals(0,   HAM_MigrationUtil.mapCapacity(2000108),      'BT ref event value → 0');
            System.assertEquals(200, HAM_MigrationUtil.mapCapacity(200),          'Normal capacity preserved');
            System.assertEquals(1,   HAM_MigrationUtil.mapCapacity(1),            'Min capacity');
        }
    }

    @isTest
    static void testLogErrors_noErrors() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            // Build a dummy upsert result list with all successes — no logs written
            // We test this by ensuring HAM_Migration_Log__c count stays 0
            List<HAM_Migration_Log__c> before = [SELECT Id FROM HAM_Migration_Log__c];
            // Nothing to insert — method handles empty gracefully, but we verify no exception
            HAM_MigrationUtil.logErrors(
                new List<Database.UpsertResult>(),
                new List<SObject>(),
                'Test'
            );
            List<HAM_Migration_Log__c> after = [SELECT Id FROM HAM_Migration_Log__c];
            System.assertEquals(before.size(), after.size(), 'No log records created for empty results');
        }
    }
}