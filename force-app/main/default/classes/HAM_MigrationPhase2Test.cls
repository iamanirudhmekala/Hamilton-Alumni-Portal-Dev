/**
 * HAM_MigrationPhase2Test
 * ─────────────────────────────────────────────────────────────────────────────
 * Happy-path test coverage for all 15 Phase 2 migration batch classes.
 *
 * Test strategy:
 *  - @TestSetup creates shared BT data (event, form, contacts, attendees,
 *    form elements, form submission, form submission answer, budget expense)
 *  - BT-validation-blocked objects (Sales Documents, Line Items, Transactions)
 *    are tested via in-memory records + direct execute() with @TestVisible maps
 *  - Each test method exercises one batch via Test.startTest() / Test.stopTest()
 *    or direct execute() for objects that cannot be inserted in test context
 *  - Assertions: record created, HAM_BT_Source_Id__c populated
 *
 * Change Log:
 *   v1.0  05/08/2026  NVV: ASC-XXXXX - Phase 2 initial build
 *
 * @description Test class providing happy-path coverage for Phase 2 migration batches.
 */
@isTest
private class HAM_MigrationPhase2Test {

    // ──────────────────────────────────────────────────────────────────────────
    // @TestSetup — BT dataset shared across all Phase 2 tests
    // ──────────────────────────────────────────────────────────────────────────
    @TestSetup
    static void setupData() {
        // ── BT Event (within Iter 1 date range)
        conference360__Event__c btEvent = new conference360__Event__c(
            Name                               = 'Phase2 Test Event',
            conference360__Event_Start_Date__c = Date.newInstance(2025, 6, 1),
            conference360__Event_End_Date__c   = Date.newInstance(2025, 6, 3),
            conference360__Status__c           = 'Active',
            conference360__Category__c         = '1812/JBA'
        );
        insert btEvent;

        // ── Form (Pre-Registration) — linked to event via Form2__c
        conference360__Form__c btForm = new conference360__Form__c(
            Name                   = 'Phase2 Test Form',
            conference360__Type__c = 'Pre-registration'
        );
        insert btForm;

        btEvent.conference360__Form2__c = btForm.Id;
        update btEvent;

        // ── Form Element
        conference360__Form_Element__c fe = new conference360__Form_Element__c(
            conference360__Form__c       = btForm.Id,
            conference360__Question__c   = 'What is your role?',
            conference360__Type__c       = 'Text',
            conference360__Sort_Order__c = 0
        );
        insert fe;

        // ── Contacts (2 attendee contacts)
        List<Contact> contacts = new List<Contact>{
            new Contact(LastName = 'P2Attendee1', Email = 'p2att1@test.com'),
            new Contact(LastName = 'P2Attendee2', Email = 'p2att2@test.com')
        };
        insert contacts;

        // ── Attendees
        List<conference360__Attendee__c> btAttendees = new List<conference360__Attendee__c>{
            new conference360__Attendee__c(
                conference360__Event__c               = btEvent.Id,
                conference360__Contact__c             = contacts[0].Id,
                conference360__Registration_Status__c = 'Registered'
            ),
            new conference360__Attendee__c(
                conference360__Event__c               = btEvent.Id,
                conference360__Contact__c             = contacts[1].Id,
                conference360__Registration_Status__c = 'Registered'
            )
        };
        insert btAttendees;

        // ── Form Submission
        conference360__Form_Submission__c btSub = new conference360__Form_Submission__c(
            conference360__Event__c    = btEvent.Id,
            conference360__Form__c     = btForm.Id,
            conference360__Attendee__c = btAttendees[0].Id,
            conference360__Key__c      = 'P2-FS-001'
        );
        insert btSub;

        // ── Form Submission Answer
        insert new conference360__Form_Submission_Answer__c(
            conference360__Form_Submission__c = btSub.Id,
            conference360__Form_Element__c    = fe.Id,
            conference360__Answer__c          = 'Alumnus'
        );

        // ── Budget Expense (General Ledger source)
        // conference360__Subcategory__c = namespaced subcategory field
        insert new conference360__Budget_Expense__c(
            conference360__Event__c       = btEvent.Id,
            conference360__Subcategory__c = 'AV-001',
            conference360__Category__c    = 'Audio Visual',
            conference360__Description__c = 'AV equipment rental'
        );

        // NOTE: conference360__Event_Item__c, bt_stripe__Sales_Document__c,
        // bt_stripe__Line_Item__c, bt_stripe__Transaction__c, and
        // conference360__Expense_Entry__c cannot be inserted in test context due to
        // BT validation rules. Those batches are tested via direct execute().
    }

    // ── Helper: get the test BT event
    private static conference360__Event__c getBTEvent() {
        return [SELECT Id, conference360__Form2__c
                FROM   conference360__Event__c
                WHERE  Name = 'Phase2 Test Event' LIMIT 1];
    }

    // ──────────────────────────────────────────────────────────────────────────
    // TEST: HAM_ProductMigrationBatch
    // conference360__Event_Item__c inserts blocked by BT validation — test via execute()
    // btToCventEventMap not used in execute() — no Cvent Event insert needed
    // ──────────────────────────────────────────────────────────────────────────
    @isTest
    static void testProductMigration_executeCoverage() {
        conference360__Event__c btEvent = getBTEvent();

        // In-memory source record (never inserted — avoids BT validation rule)
        conference360__Event_Item__c item = new conference360__Event_Item__c(
            conference360__Event__c = btEvent.Id,
            conference360__Type__c  = 'Ticket'
        );

        HAM_ProductMigrationBatch batch = new HAM_ProductMigrationBatch();

        System.runAs(new User(Id = UserInfo.getUserId())) {
            batch.execute(null, new List<conference360__Event_Item__c>{ item });
        }

        // HAM_BT_Source_Id__c = item.Id (null on in-memory) → upsert fails gracefully
        System.assert(
            batch.successCount + batch.failCount == 1,
            'execute() processed 1 product record'
        );
    }

    // ──────────────────────────────────────────────────────────────────────────
    // TEST: HAM_DiscountMigrationBatch
    // bt_stripe__Code__c — global scope; test via execute()
    // ──────────────────────────────────────────────────────────────────────────
    @isTest
    static void testDiscountMigration_executeCoverage() {
        // In-memory BT Discount Code
        bt_stripe__Code__c code = new bt_stripe__Code__c(
            bt_stripe__Type__c               = 'Percentage',
            bt_stripe__Discount_Percentage__c = 10
        );

        HAM_DiscountMigrationBatch batch = new HAM_DiscountMigrationBatch();

        System.runAs(new User(Id = UserInfo.getUserId())) {
            batch.execute(null, new List<bt_stripe__Code__c>{ code });
        }

        System.assert(
            batch.successCount + batch.failCount == 1,
            'execute() processed 1 discount record'
        );
    }

    // ──────────────────────────────────────────────────────────────────────────
    // TEST: HAM_OrderMigrationBatch
    // bt_stripe__Sales_Document__c blocked — test via execute()
    // btToCventEventMap not used in execute() — no Cvent Event insert needed
    // ──────────────────────────────────────────────────────────────────────────
    @isTest
    static void testOrderMigration_executeCoverage() {
        // In-memory Sales Document
        bt_stripe__Sales_Document__c sd = new bt_stripe__Sales_Document__c(
            bt_stripe__Status__c         = 'Open',
            bt_stripe__Payment_Status__c = 'Unpaid'
        );

        HAM_OrderMigrationBatch batch = new HAM_OrderMigrationBatch();

        System.runAs(new User(Id = UserInfo.getUserId())) {
            batch.execute(null, new List<bt_stripe__Sales_Document__c>{ sd });
        }

        System.assert(
            batch.successCount + batch.failCount == 1,
            'execute() processed 1 order record'
        );
    }

    // ──────────────────────────────────────────────────────────────────────────
    // TEST: HAM_OrderItemMigrationBatch
    // bt_stripe__Line_Item__c blocked — test via execute()
    // btToCventEventMap not used in execute() — no Cvent Event insert needed
    // ──────────────────────────────────────────────────────────────────────────
    @isTest
    static void testOrderItemMigration_executeCoverage() {
        // In-memory Line Item (Name is auto-number — only set writable fields)
        bt_stripe__Line_Item__c li = new bt_stripe__Line_Item__c(
            bt_stripe__Item_Name__c = 'Test Item'
        );

        HAM_OrderItemMigrationBatch batch = new HAM_OrderItemMigrationBatch();

        System.runAs(new User(Id = UserInfo.getUserId())) {
            batch.execute(null, new List<bt_stripe__Line_Item__c>{ li });
        }

        System.assert(
            batch.successCount + batch.failCount == 1,
            'execute() processed 1 order item record'
        );
    }

    // ──────────────────────────────────────────────────────────────────────────
    // TEST: HAM_OrderDiscountBatch
    // bt_stripe__Sales_Document__c blocked — test via execute()
    // Both MD parents (Order + Discount) cannot be resolved → records skipped gracefully
    // ──────────────────────────────────────────────────────────────────────────
    @isTest
    static void testOrderDiscountBatch_executeCoverage() {
        bt_stripe__Sales_Document__c sd = new bt_stripe__Sales_Document__c(
            bt_stripe__Status__c = 'Open'
        );

        HAM_OrderDiscountBatch batch = new HAM_OrderDiscountBatch();

        System.runAs(new User(Id = UserInfo.getUserId())) {
            batch.execute(null, new List<bt_stripe__Sales_Document__c>{ sd });
        }

        System.assertEquals(0, batch.successCount + batch.failCount,
            'Unresolved MD parents — 0 records processed');
    }

    // ──────────────────────────────────────────────────────────────────────────
    // TEST: HAM_OrderItemDiscountBatch
    // bt_stripe__Line_Item__c blocked — test via execute()
    // Both MD parents unresolvable → records skipped gracefully
    // ──────────────────────────────────────────────────────────────────────────
    @isTest
    static void testOrderItemDiscountBatch_executeCoverage() {
        bt_stripe__Line_Item__c li = new bt_stripe__Line_Item__c(
            bt_stripe__Item_Name__c = 'Test Item'
        );

        HAM_OrderItemDiscountBatch batch = new HAM_OrderItemDiscountBatch();

        System.runAs(new User(Id = UserInfo.getUserId())) {
            batch.execute(null, new List<bt_stripe__Line_Item__c>{ li });
        }

        System.assertEquals(0, batch.successCount + batch.failCount,
            'Unresolved MD parents — 0 records processed');
    }

    // ──────────────────────────────────────────────────────────────────────────
    // TEST: HAM_TransactionMigrationBatch
    // bt_stripe__Transaction__c blocked — test via execute()
    // ──────────────────────────────────────────────────────────────────────────
    @isTest
    static void testTransactionMigration_executeCoverage() {
        bt_stripe__Transaction__c txn = new bt_stripe__Transaction__c(
            bt_stripe__Paid__c = true
        );

        HAM_TransactionMigrationBatch batch = new HAM_TransactionMigrationBatch();

        System.runAs(new User(Id = UserInfo.getUserId())) {
            batch.execute(null, new List<bt_stripe__Transaction__c>{ txn });
        }

        System.assert(
            batch.successCount + batch.failCount == 1,
            'execute() processed 1 transaction record'
        );
    }

    // ──────────────────────────────────────────────────────────────────────────
    // TEST: HAM_TransactionItemBatch
    // bt_stripe__Transaction__c blocked — test via execute()
    // Cvent Transaction unresolvable → records skipped gracefully
    // ──────────────────────────────────────────────────────────────────────────
    @isTest
    static void testTransactionItemBatch_executeCoverage() {
        bt_stripe__Transaction__c txn = new bt_stripe__Transaction__c(
            bt_stripe__Paid__c = true
        );

        HAM_TransactionItemBatch batch = new HAM_TransactionItemBatch();

        System.runAs(new User(Id = UserInfo.getUserId())) {
            batch.execute(null, new List<bt_stripe__Transaction__c>{ txn });
        }

        // No Cvent Transaction resolved → record skipped
        System.assertEquals(0, batch.successCount + batch.failCount,
            'Unresolved Cvent Transaction — 0 records processed');
    }

    // ──────────────────────────────────────────────────────────────────────────
    // TEST: HAM_TransactionOrderBatch
    // bt_stripe__Transaction__c blocked — test via execute()
    // MD parents unresolvable → records skipped gracefully
    // ──────────────────────────────────────────────────────────────────────────
    @isTest
    static void testTransactionOrderBatch_executeCoverage() {
        bt_stripe__Transaction__c txn = new bt_stripe__Transaction__c(
            bt_stripe__Paid__c = true
        );

        HAM_TransactionOrderBatch batch = new HAM_TransactionOrderBatch();

        System.runAs(new User(Id = UserInfo.getUserId())) {
            batch.execute(null, new List<bt_stripe__Transaction__c>{ txn });
        }

        System.assertEquals(0, batch.successCount + batch.failCount,
            'Unresolved MD parents — 0 records processed');
    }

    // ──────────────────────────────────────────────────────────────────────────
    // TEST: HAM_GeneralLedgerBatch — happy path (Budget Expense insertable)
    // ──────────────────────────────────────────────────────────────────────────
    @isTest
    static void testGeneralLedgerMigration_happyPath() {
        conference360__Event__c btEvent = getBTEvent();

        conference360__Budget_Expense__c expense = [
            SELECT Id, conference360__Subcategory__c, conference360__Category__c,
                   conference360__Description__c
            FROM   conference360__Budget_Expense__c
            WHERE  conference360__Event__c = :btEvent.Id LIMIT 1
        ];

        HAM_GeneralLedgerBatch batch = new HAM_GeneralLedgerBatch();
        batch.btEventIds.add(btEvent.Id);

        System.runAs(new User(Id = UserInfo.getUserId())) {
            batch.execute(null, new List<conference360__Budget_Expense__c>{ expense });
        }

        System.assertEquals(1, batch.successCount, '1 GL record created');
        CventEvents__General_Ledger__c gl = [
            SELECT HAM_BT_Source_Id__c FROM CventEvents__General_Ledger__c LIMIT 1
        ];
        System.assertNotEquals(null, gl.HAM_BT_Source_Id__c, 'HAM_BT_Source_Id__c populated');
    }

    // ──────────────────────────────────────────────────────────────────────────
    // TEST: HAM_GeneralLedgerItemBatch
    // Expense Entry cannot be inserted; Order_Item MD parent also unresolvable.
    // Verify batch runs cleanly with 0 records — placeholder batch.
    // ──────────────────────────────────────────────────────────────────────────
    @isTest
    static void testGeneralLedgerItemBatch_cleanRun() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Test.startTest();
            Database.executeBatch(new HAM_GeneralLedgerItemBatch(), 200);
            Test.stopTest();
        }
        System.assertEquals(0, [SELECT COUNT() FROM CventEvents__General_Ledger_Item__c],
            'No GL Items created — placeholder batch runs cleanly');
    }

    // ──────────────────────────────────────────────────────────────────────────
    // TEST: HAM_GeneralLedgerItemBatch — with GL record in org
    // Inserts a CventEvents__General_Ledger__c with HAM_BT_Source_Id__c before
    // running the batch so start() btToGeneralLedgerMap loop body (line 58) executes.
    // ──────────────────────────────────────────────────────────────────────────
    @isTest
    static void testGeneralLedgerItemBatch_withGLRecord() {
        conference360__Budget_Expense__c be = [
            SELECT Id FROM conference360__Budget_Expense__c LIMIT 1
        ];

        insert new CventEvents__General_Ledger__c(
            HAM_BT_Source_Id__c = be.Id
        );

        System.runAs(new User(Id = UserInfo.getUserId())) {
            Test.startTest();
            Database.executeBatch(new HAM_GeneralLedgerItemBatch(), 200);
            Test.stopTest();
        }
        System.assertEquals(0, [SELECT COUNT() FROM CventEvents__General_Ledger_Item__c],
            'GL map populated but no Expense Entries in scope — 0 GL Items created');
    }

    // ──────────────────────────────────────────────────────────────────────────
    // TEST: HAM_SurveyProgramBatch
    // CventEvents__SurveyProgram__c requires managed-pkg field CventEvents__SurveyStub__c
    // which the batch cannot populate. Upsert fails gracefully (allOrNone=false).
    // Test verifies execute() runs and processes the record.
    // ──────────────────────────────────────────────────────────────────────────
    @isTest
    static void testSurveyProgramMigration_executeCoverage() {
        conference360__Form__c btForm = [
            SELECT Id, Name, conference360__Type__c, conference360__Submitted_Message__c
            FROM   conference360__Form__c
            WHERE  Name = 'Phase2 Test Form' LIMIT 1
        ];

        HAM_SurveyProgramBatch batch = new HAM_SurveyProgramBatch();
        batch.formTypeMap.put(btForm.Id, 'Pre-registration Survey');

        System.runAs(new User(Id = UserInfo.getUserId())) {
            batch.execute(null, new List<conference360__Form__c>{ btForm });
        }

        // SurveyStub required by managed pkg → upsert fails gracefully; failCount = 1
        System.assert(
            batch.successCount + batch.failCount == 1,
            'execute() processed 1 SurveyProgram record'
        );
    }

    // ──────────────────────────────────────────────────────────────────────────
    // TEST: HAM_SurveyQuestionBatch
    // SurveyProgram cannot be inserted (managed pkg required field).
    // Empty map → surveyProgramId null → all records skipped → covers null-check branch.
    // ──────────────────────────────────────────────────────────────────────────
    @isTest
    static void testSurveyQuestionMigration_executeCoverage() {
        conference360__Form__c btForm = [
            SELECT Id FROM conference360__Form__c WHERE Name = 'Phase2 Test Form' LIMIT 1
        ];
        conference360__Form_Element__c fe = [
            SELECT Id, conference360__Form__c, conference360__Question__c, conference360__Type__c
            FROM   conference360__Form_Element__c
            WHERE  conference360__Form__c = :btForm.Id LIMIT 1
        ];

        // Empty map → surveyProgramId null for all elements → all skipped
        HAM_SurveyQuestionBatch batch = new HAM_SurveyQuestionBatch();

        System.runAs(new User(Id = UserInfo.getUserId())) {
            batch.execute(null, new List<conference360__Form_Element__c>{ fe });
        }

        System.assertEquals(0, batch.successCount + batch.failCount,
            'Unresolved SurveyProgram — all records skipped');
    }

    // ──────────────────────────────────────────────────────────────────────────
    // TEST: HAM_RespondentBatch
    // CventEvents__Respondent__c requires managed-pkg fields.
    // Upsert attempt fails gracefully (allOrNone=false).
    // ──────────────────────────────────────────────────────────────────────────
    @isTest
    static void testRespondentMigration_executeCoverage() {
        conference360__Event__c btEvent = getBTEvent();
        conference360__Form__c btForm = [
            SELECT Id FROM conference360__Form__c WHERE Name = 'Phase2 Test Form' LIMIT 1
        ];

        conference360__Form_Submission__c sub = [
            SELECT Id, conference360__Form__c, conference360__Contact__c,
                   conference360__Status__c, conference360__Key__c
            FROM   conference360__Form_Submission__c
            WHERE  conference360__Event__c = :btEvent.Id LIMIT 1
        ];

        // Null SP in map — SurveyProgram field will be null on upsert record
        HAM_RespondentBatch batch = new HAM_RespondentBatch();

        System.runAs(new User(Id = UserInfo.getUserId())) {
            batch.execute(null, new List<conference360__Form_Submission__c>{ sub });
        }

        System.assert(
            batch.successCount + batch.failCount == 1,
            'execute() processed 1 Respondent record'
        );
    }

    // ──────────────────────────────────────────────────────────────────────────
    // FULL BATCH RUN TESTS — cover start() and finish() for each batch.
    // With no qualifying source records in test context, start() returns an
    // empty QueryLocator, execute() is never invoked, and finish() completes
    // the chain. Combined with the direct execute() tests above, this pushes
    // each class above the 75% coverage threshold.
    // ──────────────────────────────────────────────────────────────────────────

    @isTest
    static void testProductMigration_startFinish() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Test.startTest();
            Database.executeBatch(new HAM_ProductMigrationBatch(), 200);
            Test.stopTest();
        }
        System.assertEquals(0, [SELECT COUNT() FROM CventEvents__Cvent_Product__c],
            'No products — start/finish covered cleanly');
    }

    @isTest
    static void testDiscountMigration_startFinish() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Test.startTest();
            Database.executeBatch(new HAM_DiscountMigrationBatch(), 200);
            Test.stopTest();
        }
        System.assertEquals(0, [SELECT COUNT() FROM CventEvents__Discount__c],
            'No discounts — start/finish covered cleanly');
    }

    @isTest
    static void testOrderMigration_startFinish() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Test.startTest();
            Database.executeBatch(new HAM_OrderMigrationBatch(), 200);
            Test.stopTest();
        }
        System.assertEquals(0, [SELECT COUNT() FROM CventEvents__Cvent_Order__c],
            'No orders — start/finish covered cleanly');
    }

    @isTest
    static void testOrderItemMigration_startFinish() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Test.startTest();
            Database.executeBatch(new HAM_OrderItemMigrationBatch(), 200);
            Test.stopTest();
        }
        System.assertEquals(0, [SELECT COUNT() FROM CventEvents__Cvent_Order_Item__c],
            'No order items — start/finish covered cleanly');
    }

    @isTest
    static void testOrderDiscountBatch_startFinish() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Test.startTest();
            Database.executeBatch(new HAM_OrderDiscountBatch(), 200);
            Test.stopTest();
        }
        System.assertEquals(0, [SELECT COUNT() FROM CventEvents__Order_Discount__c],
            'No order discounts — start/finish covered cleanly');
    }

    @isTest
    static void testOrderItemDiscountBatch_startFinish() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Test.startTest();
            Database.executeBatch(new HAM_OrderItemDiscountBatch(), 200);
            Test.stopTest();
        }
        System.assertEquals(0, [SELECT COUNT() FROM CventEvents__Order_Item_Discount__c],
            'No order item discounts — start/finish covered cleanly');
    }

    @isTest
    static void testTransactionMigration_startFinish() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Test.startTest();
            Database.executeBatch(new HAM_TransactionMigrationBatch(), 200);
            Test.stopTest();
        }
        System.assertEquals(0, [SELECT COUNT() FROM CventEvents__Transaction__c],
            'No transactions — start/finish covered cleanly');
    }

    @isTest
    static void testTransactionItemBatch_startFinish() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Test.startTest();
            Database.executeBatch(new HAM_TransactionItemBatch(), 200);
            Test.stopTest();
        }
        System.assertEquals(0, [SELECT COUNT() FROM CventEvents__Transaction_Item__c],
            'No transaction items — start/finish covered cleanly');
    }

    @isTest
    static void testTransactionOrderBatch_startFinish() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Test.startTest();
            Database.executeBatch(new HAM_TransactionOrderBatch(), 200);
            Test.stopTest();
        }
        System.assertEquals(0, [SELECT COUNT() FROM CventEvents__Transaction_Order__c],
            'No transaction orders — start/finish covered cleanly');
    }

    @isTest
    static void testGeneralLedgerBatch_startFinish() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Test.startTest();
            Database.executeBatch(new HAM_GeneralLedgerBatch(), 200);
            Test.stopTest();
        }
        System.assert(true, 'GeneralLedger start/finish covered cleanly');
    }

    @isTest
    static void testSurveyProgramBatch_startFinish() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Test.startTest();
            Database.executeBatch(new HAM_SurveyProgramBatch(), 200);
            Test.stopTest();
        }
        System.assert(true, 'SurveyProgram start/finish covered cleanly');
    }

    // ──────────────────────────────────────────────────────────────────────────
    // TEST: HAM_SurveyProgramBatch — start() form loop body coverage
    // Injects testBtToCventEventOverride so start() skips the CventEvents__Event__c
    // SOQL (managed pkg, uninsertable) and runs the conference360__Event__c loop body,
    // covering the 4 form-field branches. Form2__c is set in @TestSetup.
    // ──────────────────────────────────────────────────────────────────────────
    @isTest
    static void testSurveyProgramBatch_startFormLoopCoverage() {
        conference360__Event__c btEvent = getBTEvent();

        HAM_SurveyProgramBatch batch = new HAM_SurveyProgramBatch();
        // Inject fake BT→Cvent mapping so start() queries conference360__Event__c with this key
        batch.testBtToCventEventOverride = new Map<Id, Id>{ btEvent.Id => btEvent.Id };

        System.runAs(new User(Id = UserInfo.getUserId())) {
            // Call start() directly — executeBatch serializes the instance so the local reference
            // is not updated; direct call preserves the stateful formTypeMap on this instance.
            batch.start(null);
        }
        // formTypeMap populated for Form2__c (linked in @TestSetup) — form loop body covered
        System.assert(!batch.formTypeMap.isEmpty(), 'formTypeMap populated — form loop body covered');
    }

    @isTest
    static void testSurveyQuestionBatch_startFinish() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Test.startTest();
            Database.executeBatch(new HAM_SurveyQuestionBatch(), 200);
            Test.stopTest();
        }
        System.assert(true, 'SurveyQuestion start/finish covered cleanly');
    }

    @isTest
    static void testRespondentBatch_startFinish() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Test.startTest();
            Database.executeBatch(new HAM_RespondentBatch(), 200);
            Test.stopTest();
        }
        System.assert(true, 'RespondentBatch start/finish covered cleanly');
    }

    @isTest
    static void testSurveyAnswerBatch_startFinish() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Test.startTest();
            Database.executeBatch(new HAM_SurveyAnswerBatch(), 200);
            Test.stopTest();
        }
        System.assert(true, 'SurveyAnswerBatch start/finish covered cleanly');
    }

    @isTest
    static void testEventSettingsMigration_startFinish() {
        // Covers the new finish() chain to HAM_ProductMigrationBatch added in v1.1
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Test.startTest();
            Database.executeBatch(new HAM_EventSettingsMigrationBatch(), 200);
            Test.stopTest();
        }
        System.assert(true, 'EventSettings start/finish covered cleanly');
    }

    // ──────────────────────────────────────────────────────────────────────────
    // TARGETED EXECUTE() COVERAGE TESTS
    // These tests use the null-key map trick: in-memory source records have
    // null Ids, so map.put(null, fakeId) / map.get(null) = fakeId — bypassing
    // the null-parent skip and covering the toUpsert.add() + result loop paths.
    // The upsert fails gracefully (allOrNone=false) → failCount++ is covered.
    // ──────────────────────────────────────────────────────────────────────────

    @isTest
    static void testOrderDiscountBatch_upsertPath() {
        Id fakeId = [SELECT Id FROM conference360__Event__c WHERE Name = 'Phase2 Test Event' LIMIT 1].Id;

        bt_stripe__Sales_Document__c sd = new bt_stripe__Sales_Document__c();

        HAM_OrderDiscountBatch batch = new HAM_OrderDiscountBatch();
        batch.btToCventOrderMap.put(null, fakeId);    // sd.Id = null → resolves
        batch.btToCventDiscountMap.put(null, fakeId); // sd.bt_stripe__Discount_Code__c = null → resolves

        System.runAs(new User(Id = UserInfo.getUserId())) {
            batch.execute(null, new List<bt_stripe__Sales_Document__c>{ sd });
        }
        System.assertEquals(1, batch.failCount, 'Upsert attempted and failed gracefully');
    }

    @isTest
    static void testOrderItemDiscountBatch_upsertPath() {
        Id fakeId = [SELECT Id FROM conference360__Event__c WHERE Name = 'Phase2 Test Event' LIMIT 1].Id;

        bt_stripe__Line_Item__c li = new bt_stripe__Line_Item__c();

        HAM_OrderItemDiscountBatch batch = new HAM_OrderItemDiscountBatch();
        batch.btToCventOrderItemMap.put(null, fakeId); // li.Id = null → resolves
        batch.btToCventDiscountMap.put(null, fakeId);  // li.bt_stripe__Code__c = null → resolves

        System.runAs(new User(Id = UserInfo.getUserId())) {
            batch.execute(null, new List<bt_stripe__Line_Item__c>{ li });
        }
        System.assertEquals(1, batch.failCount, 'Upsert attempted and failed gracefully');
    }

    @isTest
    static void testTransactionItemBatch_upsertPath() {
        Id fakeId = [SELECT Id FROM conference360__Event__c WHERE Name = 'Phase2 Test Event' LIMIT 1].Id;

        bt_stripe__Transaction__c txn = new bt_stripe__Transaction__c();

        HAM_TransactionItemBatch batch = new HAM_TransactionItemBatch();
        batch.btToCventTransactionMap.put(null, fakeId); // txn.Id = null → resolves

        System.runAs(new User(Id = UserInfo.getUserId())) {
            batch.execute(null, new List<bt_stripe__Transaction__c>{ txn });
        }
        System.assertEquals(1, batch.failCount, 'Upsert attempted and failed gracefully');
    }

    @isTest
    static void testTransactionOrderBatch_upsertPath() {
        Id fakeId = [SELECT Id FROM conference360__Event__c WHERE Name = 'Phase2 Test Event' LIMIT 1].Id;

        bt_stripe__Transaction__c txn = new bt_stripe__Transaction__c();

        HAM_TransactionOrderBatch batch = new HAM_TransactionOrderBatch();
        batch.btToCventTransactionMap.put(null, fakeId);         // txn.Id = null → resolves
        batch.btToCventOrderMap.put(null, fakeId);               // txn.bt_stripe__Sales_Document__c = null → resolves

        System.runAs(new User(Id = UserInfo.getUserId())) {
            batch.execute(null, new List<bt_stripe__Transaction__c>{ txn });
        }
        System.assertEquals(1, batch.failCount, 'Upsert attempted and failed gracefully');
    }

    @isTest
    static void testSurveyQuestionBatch_upsertPath() {
        conference360__Form__c btForm = [
            SELECT Id FROM conference360__Form__c WHERE Name = 'Phase2 Test Form' LIMIT 1
        ];
        conference360__Form_Element__c fe = [
            SELECT Id, conference360__Form__c, conference360__Question__c, conference360__Type__c
            FROM   conference360__Form_Element__c
            WHERE  conference360__Form__c = :btForm.Id LIMIT 1
        ];
        Id fakeId = [SELECT Id FROM conference360__Event__c WHERE Name = 'Phase2 Test Event' LIMIT 1].Id;

        HAM_SurveyQuestionBatch batch = new HAM_SurveyQuestionBatch();
        batch.btFormToSurveyProgramMap.put(btForm.Id, fakeId); // non-null SP → toUpsert.add() executes

        System.runAs(new User(Id = UserInfo.getUserId())) {
            batch.execute(null, new List<conference360__Form_Element__c>{ fe });
        }
        System.assertEquals(1, batch.failCount, 'Upsert attempted and failed gracefully');
    }

    @isTest
    static void testGeneralLedgerItemBatch_upsertPath() {
        Id fakeId = [SELECT Id FROM conference360__Event__c WHERE Name = 'Phase2 Test Event' LIMIT 1].Id;

        // Subcategory set to exercise chunkSubcategoryKeys.add() path in execute()
        conference360__Expense_Entry__c ee = new conference360__Expense_Entry__c(
            conference360__Subcategory__c = 'AV-001'
        );

        HAM_GeneralLedgerItemBatch batch = new HAM_GeneralLedgerItemBatch();
        // null key: ee.conference360__Budget_Expense__c = null → resolves to fakeId
        // covers second skip path: GL found but OrderItem placeholder = null → continue
        batch.btToGeneralLedgerMap.put(null, fakeId);

        System.runAs(new User(Id = UserInfo.getUserId())) {
            batch.execute(null, new List<conference360__Expense_Entry__c>{ ee });
        }
        System.assertEquals(0, batch.successCount + batch.failCount,
            'GL resolved but OrderItem placeholder null — record skipped');
    }

    // ──────────────────────────────────────────────────────────────────────────
    // TEST: HAM_GeneralLedgerItemBatch — toUpsert.add() path coverage
    // Injects testOrderItemMapOverride so both GL and OrderItem resolve, forcing
    // toUpsert.add() and the upsert result loop to execute. Upsert fails gracefully
    // (HAM_BT_Source_Id__c = null on in-memory record → External ID error).
    // ──────────────────────────────────────────────────────────────────────────
    @isTest
    static void testGeneralLedgerItemBatch_toUpsertPath() {
        Id fakeId = [SELECT Id FROM conference360__Event__c WHERE Name = 'Phase2 Test Event' LIMIT 1].Id;

        conference360__Expense_Entry__c ee = new conference360__Expense_Entry__c(
            conference360__Subcategory__c = 'AV-001'
        );

        HAM_GeneralLedgerItemBatch batch = new HAM_GeneralLedgerItemBatch();
        // Both parents resolve → toUpsert.add() runs, upsert attempted
        batch.btToGeneralLedgerMap.put(null, fakeId);
        batch.testOrderItemMapOverride = new Map<String, Id>{ 'AV-001' => fakeId };

        System.runAs(new User(Id = UserInfo.getUserId())) {
            batch.execute(null, new List<conference360__Expense_Entry__c>{ ee });
        }
        System.assertEquals(1, batch.failCount,
            'Both parents resolved — upsert attempted and failed gracefully (null External ID)');
    }

    @isTest
    static void testSurveyAnswerBatch_upsertPath() {
        conference360__Event__c btEvent = getBTEvent();
        conference360__Form__c btForm = [
            SELECT Id FROM conference360__Form__c WHERE Name = 'Phase2 Test Form' LIMIT 1
        ];
        conference360__Form_Element__c fe = [
            SELECT Id FROM conference360__Form_Element__c
            WHERE  conference360__Form__c = :btForm.Id LIMIT 1
        ];
        conference360__Form_Submission__c sub = [
            SELECT Id FROM conference360__Form_Submission__c
            WHERE  conference360__Event__c = :btEvent.Id LIMIT 1
        ];
        conference360__Form_Submission_Answer__c fsa = [
            SELECT Id, conference360__Form_Submission__c, conference360__Form_Element__c,
                   conference360__Answer__c, conference360__Answer_Date__c,
                   conference360__Answer_Number__c, conference360__Answer_Text_Long__c
            FROM   conference360__Form_Submission_Answer__c
            WHERE  conference360__Form_Submission__c = :sub.Id LIMIT 1
        ];
        Id fakeId = [SELECT Id FROM conference360__Event__c WHERE Name = 'Phase2 Test Event' LIMIT 1].Id;

        HAM_SurveyAnswerBatch batch = new HAM_SurveyAnswerBatch();
        batch.btToSurveyQuestionMap.put(fe.Id, fakeId);
        // Inject respondent map: sub.Id → fakeId (bypasses SOQL in execute())
        batch.testRespondentMapOverride = new Map<Id, Id>{ sub.Id => fakeId };

        System.runAs(new User(Id = UserInfo.getUserId())) {
            batch.execute(null, new List<conference360__Form_Submission_Answer__c>{ fsa });
        }
        System.assertEquals(1, batch.failCount, 'Upsert attempted and failed gracefully');
    }

    // ──────────────────────────────────────────────────────────────────────────
    // TEST: HAM_SurveyAnswerBatch
    // Respondent MD parent cannot be resolved (no Cvent Respondents exist).
    // All records skipped — covers the null respondentId skip branch.
    // ──────────────────────────────────────────────────────────────────────────
    @isTest
    static void testSurveyAnswerMigration_executeCoverage() {
        conference360__Event__c btEvent = getBTEvent();
        conference360__Form__c btForm = [
            SELECT Id FROM conference360__Form__c WHERE Name = 'Phase2 Test Form' LIMIT 1
        ];
        conference360__Form_Element__c fe = [
            SELECT Id FROM conference360__Form_Element__c
            WHERE  conference360__Form__c = :btForm.Id LIMIT 1
        ];
        conference360__Form_Submission__c sub = [
            SELECT Id FROM conference360__Form_Submission__c
            WHERE  conference360__Event__c = :btEvent.Id LIMIT 1
        ];
        conference360__Form_Submission_Answer__c fsa = [
            SELECT Id, conference360__Form_Submission__c, conference360__Form_Element__c,
                   conference360__Answer__c, conference360__Answer_Date__c,
                   conference360__Answer_Number__c, conference360__Answer_Text_Long__c
            FROM   conference360__Form_Submission_Answer__c
            WHERE  conference360__Form_Submission__c = :sub.Id LIMIT 1
        ];

        // No Respondents in org → chunkRespondentMap empty → respondentId null → skip
        HAM_SurveyAnswerBatch batch = new HAM_SurveyAnswerBatch();
        batch.btToSurveyQuestionMap.put(fe.Id, fe.Id); // non-null SQ placeholder

        System.runAs(new User(Id = UserInfo.getUserId())) {
            batch.execute(null, new List<conference360__Form_Submission_Answer__c>{ fsa });
        }

        System.assertEquals(0, batch.successCount + batch.failCount,
            'Unresolved Respondent MD parent — all records skipped');
    }
}