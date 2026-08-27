@IsTest
private class HAM_MGFTSessionAssignmentServiceTest {

    private static final Integer SEED_COUNT = 55; // 55 = 2 full sessions (50) + 5 leftover

    @TestSetup
    static void setup() {
        // NOTE: This assumes the MGFT record type already exists in the org /
        // is creatable in a test context, same assumption as
        // HAM_MGFTReviewTxnCtrlTest. Adjust field values below to match your
        // sandbox's required fields / validation rules if this fails to insert.
        //
        // NOTE: ucinn_ascendv2__Session__c showed no field-level-required
        // custom fields via schema lookup, so no extra fields are set on it
        // here. If your org has a validation rule on that object (analogous
        // to RTV2's "Please specify an external system ID" rule), this
        // insert in HAM_MGFTSessionAssignmentService.buildNewSessions() may
        // need additional defaults -- if these tests fail on session insert,
        // that's the first place to look.

        Id mgftRtId = [
            SELECT Id FROM RecordType
            WHERE SobjectType = 'ucinn_ascendv2__Review_Transaction_v2__c'
              AND DeveloperName = 'MGFT'
            LIMIT 1
        ].Id;

        Contact c = new Contact(
            FirstName = 'Test',
            LastName = 'Donor'
        );
        insert c;

        // Seed SEED_COUNT transactions with strictly descending transaction
        // dates (today, today-1, today-2, ...) so "oldest first" ordering is
        // unambiguous and independent of insert/CreatedDate order: index 0
        // is the newest record, index SEED_COUNT-1 is the oldest.
        List<ucinn_ascendv2__Review_Transaction_v2__c> txns = new List<ucinn_ascendv2__Review_Transaction_v2__c>();
        for (Integer i = 0; i < SEED_COUNT; i++) {
            txns.add(new ucinn_ascendv2__Review_Transaction_v2__c(
                RecordTypeId = mgftRtId,
                HAM_Data_Source__c = 'Portal - MakeAGift',
                ucinn_ascendv2__Transaction_Date__c = Date.today().addDays(-i),
                ucinn_ascendv2__Total_Transaction_Amount__c = 100,
                ucinn_ascendv2__Contact__c = c.Id,
                // Required by an org validation rule ("Please specify an
                // external system ID for review transaction"). Any unique
                // string satisfies it in a test context.
                ucinn_ascendv2__External_System_ID__c = 'MGFT-SESSION-TEST-' + i
            ));
        }
        insert txns;
    }

    @IsTest
    static void testRunAssignsFullSessionsOldestFirst() {
        Test.startTest();
        HAM_MGFTSessionAssignmentService.run();
        Test.stopTest();

        List<ucinn_ascendv2__Session__c> sessions = [SELECT Id FROM ucinn_ascendv2__Session__c];
        System.assertEquals(2, sessions.size(), 'Expected floor(55/25) = 2 sessions to be created');

        for (ucinn_ascendv2__Session__c s : sessions) {
            Integer cnt = [
                SELECT COUNT()
                FROM ucinn_ascendv2__Review_Transaction_v2__c
                WHERE ucinn_ascendv2__Session__c = :s.Id
            ];
            System.assertEquals(25, cnt, 'Each session should have exactly 25 transactions');
        }

        List<ucinn_ascendv2__Review_Transaction_v2__c> unassigned = [
            SELECT Id, ucinn_ascendv2__Transaction_Date__c
            FROM ucinn_ascendv2__Review_Transaction_v2__c
            WHERE ucinn_ascendv2__Session__c = null
        ];
        System.assertEquals(5, unassigned.size(), 'Remainder of 5 records (55 mod 25) should stay unassigned');

        // The 5 leftover records should be the 5 *newest* (today, today-1,
        // ..., today-4) since the 50 oldest were the ones sessioned.
        Date cutoff = Date.today().addDays(-4);
        for (ucinn_ascendv2__Review_Transaction_v2__c t : unassigned) {
            System.assert(
                t.ucinn_ascendv2__Transaction_Date__c >= cutoff,
                'Unassigned leftovers should be the most recent records, not the oldest'
            );
        }
    }

    @IsTest
    static void testRunDoesNothingWhenFewerThan25Unassigned() {
        // Pre-assign 31 of the 55 seeded records to a stub session so only
        // 24 remain unassigned -- below the 25-record threshold.
        ucinn_ascendv2__Session__c stubSession = new ucinn_ascendv2__Session__c();
        insert stubSession;

        List<ucinn_ascendv2__Review_Transaction_v2__c> allTxns = [
            SELECT Id
            FROM ucinn_ascendv2__Review_Transaction_v2__c
            ORDER BY ucinn_ascendv2__Transaction_Date__c ASC
        ];

        List<ucinn_ascendv2__Review_Transaction_v2__c> toPreassign = new List<ucinn_ascendv2__Review_Transaction_v2__c>();
        for (Integer i = 0; i < 31; i++) {
            toPreassign.add(new ucinn_ascendv2__Review_Transaction_v2__c(
                Id = allTxns[i].Id,
                ucinn_ascendv2__Session__c = stubSession.Id
            ));
        }
        update toPreassign;

        Test.startTest();
        HAM_MGFTSessionAssignmentService.run();
        Test.stopTest();

        // Only the pre-existing stub session should exist -- no new ones,
        // since only 24 records were left unassigned (< 25).
        List<ucinn_ascendv2__Session__c> sessions = [SELECT Id FROM ucinn_ascendv2__Session__c];
        System.assertEquals(1, sessions.size(), 'No new session should be created for fewer than 25 unassigned records');
    }

    @IsTest
    static void testSchedulerInvokesService() {
        Test.startTest();
        new HAM_MGFTSessionAssignmentScheduler().execute(null);
        Test.stopTest();

        // Scheduler should delegate straight to the service, so the outcome
        // matches testRunAssignsFullSessionsOldestFirst exactly.
        List<ucinn_ascendv2__Session__c> sessions = [SELECT Id FROM ucinn_ascendv2__Session__c];
        System.assertEquals(2, sessions.size(), 'Scheduler should delegate to the service and create sessions the same way');

        Integer unassignedCount = [
            SELECT COUNT()
            FROM ucinn_ascendv2__Review_Transaction_v2__c
            WHERE ucinn_ascendv2__Session__c = null
        ];
        System.assertEquals(5, unassignedCount, 'Scheduler run should leave the same 5-record remainder as a direct service call');
    }
}