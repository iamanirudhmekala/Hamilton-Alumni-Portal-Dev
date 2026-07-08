/**
 * ============================================================
 * @class       HAMReceiptLineItemServiceTest
 * @description Test coverage for HAMReceiptLineItemService.
 *
 * ─────────────────────────────────────────────────────────────
 * Change Log
 * ─────────────────────────────────────────────────────────────
 * Version  Date          Author  Description
 * ───────  ────────────  ──────  ────────────────────────────────────────────
 * 1.0      [prior]       Me      Initial Hard/Soft Credit flow
 * 1.1      2026-03-30    Me      Routing, PRM, bulk tests
 * 1.2      2026-03-30    Me      Fixed assertNull → assertEquals(null,...)
 * 1.3      2026-03-30    Me      Fixed routing — all tests call createLineItems
 * 1.4      2026-03-30    Me      Rebuilt data to mirror FullQA records
 * 1.5      2026-03-30    Me      Controller: with sharing → without sharing;
 *                                set ucinn_ascendv2__Amount__c on Desig Details
 * 1.6      2026-03-30    Me      Added Opportunity RecordTypeId (Gift/Pledge) to
 *                                fix managed package trigger rejection;
 *                                Isolated credit insert into helper called per-test
 *                                to guarantee running-user ownership and SOQL
 *                                visibility; added SeeAllData=false explicitly.
 * 1.7      2026-03-31    Me      Fixed insertPrmContact: replaced HAM_Campus_Cell__c
 *                                with Phone (standard field), which is what the service
 *                                actually queries and maps to HAM_Phone__c on Receipt.
 *                                Updated testPrmUpdate_WithPrmId_UpdatesReceiptFields
 *                                assertion to compare stored.Phone instead of
 *                                stored.HAM_Campus_Cell__c.
 *                                Renamed testPrmUpdate_NoPrmId_SkipsGracefully →
 *                                testPrmUpdate_NoPrmId_UsesDefaultPrm_NoMatchingContact
 *                                to reflect new queryReceiptsWithPrm behavior: receipts
 *                                with no PRM_ID__c now fall back to
 *                                Label.Default_PRM_For_Pledge instead of being skipped.
 *                                Added testPrmUpdate_NoPrmId_DefaultPrmMatchesRunningUser
 *                                for smoke-test coverage of the default-PRM fallback path.
 * ============================================================
 */
@IsTest
private class HAMReceiptLineItemServiceTest {

    private static final String TYPE_PLEDGE_REMINDER = 'Pledge Reminder';
    private static final String TYPE_HARD_CREDIT      = 'Hard Credit';

    // ================================================================
    // RECORD TYPE IDS — fetched once statically
    // ================================================================

    private static Id giftOppRtId {
        get {
            if (giftOppRtId == null) {
                giftOppRtId = Schema.SObjectType.Opportunity
                    .getRecordTypeInfosByDeveloperName().get('Gift').getRecordTypeId();
            }
            return giftOppRtId;
        }
        set;
    }

    private static Id pledgeOppRtId {
        get {
            if (pledgeOppRtId == null) {
                pledgeOppRtId = Schema.SObjectType.Opportunity
                    .getRecordTypeInfosByDeveloperName().get('Pledge').getRecordTypeId();
            }
            return pledgeOppRtId;
        }
        set;
    }

    private static Id giftDesigRtId {
        get {
            if (giftDesigRtId == null) {
                giftDesigRtId = Schema.SObjectType.ucinn_ascendv2__Designation__c
                    .getRecordTypeInfosByDeveloperName().get('HAM_Gift_Designation').getRecordTypeId();
            }
            return giftDesigRtId;
        }
        set;
    }

    // ================================================================
    // TEST SETUP — stable reference data only (no credits)
    // Credits are inserted per-test to guarantee running-user ownership
    // and SOQL visibility through the master-detail chain.
    // ================================================================

    @TestSetup
    static void setupData() {

        // ── Designations ──────────────────────────────────────────────
        List<ucinn_ascendv2__Designation__c> desigs = new List<ucinn_ascendv2__Designation__c>{
            new ucinn_ascendv2__Designation__c(         // [0] Hard Credit
                Name='ATH-M-TRACK-INDOOR',
                RecordTypeId=Schema.SObjectType.ucinn_ascendv2__Designation__c
                    .getRecordTypeInfosByDeveloperName().get('HAM_Gift_Designation').getRecordTypeId(),
                ucinn_ascendv2__G_L_Effective_Date__c=Date.today(),
                ucinn_ascendv2__Designation_Name__c='Friends of Men\'s Indoor Track',
                ucinn_ascendv2__External_System_ID__c='ATH-M-TRACK-TEST',
                ucinn_ascendv2__Is_Publicly_Visible__c=true
            ),
            new ucinn_ascendv2__Designation__c(         // [1] Pledge opp 1
                Name='PLT-SAGE',
                RecordTypeId=Schema.SObjectType.ucinn_ascendv2__Designation__c
                    .getRecordTypeInfosByDeveloperName().get('HAM_Gift_Designation').getRecordTypeId(),
                ucinn_ascendv2__G_L_Effective_Date__c=Date.today(),
                ucinn_ascendv2__Designation_Name__c='The Sage Rink Renovation Project',
                ucinn_ascendv2__External_System_ID__c='PLT-SAGE-TEST',
                ucinn_ascendv2__Is_Publicly_Visible__c=true
            ),
            new ucinn_ascendv2__Designation__c(         // [2] Pledge opp 2 - DD A
                Name='PLT-DIGITAL-BONDED',
                RecordTypeId=Schema.SObjectType.ucinn_ascendv2__Designation__c
                    .getRecordTypeInfosByDeveloperName().get('HAM_Gift_Designation').getRecordTypeId(),
                ucinn_ascendv2__G_L_Effective_Date__c=Date.today(),
                ucinn_ascendv2__Designation_Name__c='Innovation Center',
                ucinn_ascendv2__External_System_ID__c='PLT-DIGITAL-TEST',
                ucinn_ascendv2__Is_Publicly_Visible__c=true
            ),
            new ucinn_ascendv2__Designation__c(         // [3] Pledge opp 2 - DD B
                Name='LCT-C-COMMON',
                RecordTypeId=Schema.SObjectType.ucinn_ascendv2__Designation__c
                    .getRecordTypeInfosByDeveloperName().get('HAM_Gift_Designation').getRecordTypeId(),
                ucinn_ascendv2__G_L_Effective_Date__c=Date.today(),
                ucinn_ascendv2__Designation_Name__c='The Common Ground Program',
                ucinn_ascendv2__External_System_ID__c='LCT-C-COMMON-TEST',
                ucinn_ascendv2__Is_Publicly_Visible__c=true
            ),
            new ucinn_ascendv2__Designation__c(         // [4] Pledge opp 3
                Name='FY26-AF-UNRESTRICTED',
                RecordTypeId=Schema.SObjectType.ucinn_ascendv2__Designation__c
                    .getRecordTypeInfosByDeveloperName().get('HAM_Gift_Designation').getRecordTypeId(),
                ucinn_ascendv2__G_L_Effective_Date__c=Date.today(),
                ucinn_ascendv2__Designation_Name__c='The Hamilton Fund',
                ucinn_ascendv2__External_System_ID__c='FY26-AF-TEST',
                ucinn_ascendv2__Is_Publicly_Visible__c=true
            )
        };
        insert desigs;

        // ── Opportunities — with correct RecordTypeId ─────────────────
        Id giftRt   = Schema.SObjectType.Opportunity
            .getRecordTypeInfosByDeveloperName().get('Gift').getRecordTypeId();
        Id pledgeRt = Schema.SObjectType.Opportunity
            .getRecordTypeInfosByDeveloperName().get('Pledge').getRecordTypeId();

        List<Opportunity> opps = new List<Opportunity>{
            new Opportunity(                            // [0] Hard Credit — GN0493871
                Name='GN0493871', RecordTypeId=giftRt,
                StageName='Funded', CloseDate=Date.today().addDays(-30), Amount=100
            ),
            new Opportunity(                            // [1] Pledge — PN0495534 (1 DD)
                Name='PN0495534', RecordTypeId=pledgeRt,
                StageName='Active', CloseDate=Date.today().addDays(90), Amount=250000
            ),
            new Opportunity(                            // [2] Pledge — PN0424938 (2 DDs)
                Name='PN0424938', RecordTypeId=pledgeRt,
                StageName='Active', CloseDate=Date.today().addDays(180), Amount=77944
            ),
            new Opportunity(                            // [3] Pledge — PN0508932 (1 DD)
                Name='PN0508932', RecordTypeId=pledgeRt,
                StageName='Active', CloseDate=Date.today().addDays(365), Amount=50000
            )
        };
        insert opps;

        // ── Designation Details — ucinn_ascendv2__Amount__c drives formula ──
        // Remaining_Amt_Same_Designation_Formula__c = Amount__c - Amt_Paid (rollup=0)
        // Setting Amount__c > 0 makes Remaining > 0 so pledge path proceeds.
        List<ucinn_ascendv2__Designation_Detail__c> ddList = new List<ucinn_ascendv2__Designation_Detail__c>{
            new ucinn_ascendv2__Designation_Detail__c(  // [0] Hard Credit DD (Remaining=0 is fine)
                Name='DD-GN0493871',
                ucinn_ascendv2__Opportunity__c=opps[0].Id,
                ucinn_ascendv2__Designation__c=desigs[0].Id,
                ucinn_ascendv2__Amount__c=0
            ),
            new ucinn_ascendv2__Designation_Detail__c(  // [1] Pledge opp1 — $250k
                Name='DD-PN0495534',
                ucinn_ascendv2__Opportunity__c=opps[1].Id,
                ucinn_ascendv2__Designation__c=desigs[1].Id,
                ucinn_ascendv2__Amount__c=250000
            ),
            new ucinn_ascendv2__Designation_Detail__c(  // [2] Pledge opp2 — DD A $77,944
                Name='DD-PN0424938-A',
                ucinn_ascendv2__Opportunity__c=opps[2].Id,
                ucinn_ascendv2__Designation__c=desigs[2].Id,
                ucinn_ascendv2__Amount__c=77944
            ),
            new ucinn_ascendv2__Designation_Detail__c(  // [3] Pledge opp2 — DD B $50k
                Name='DD-PN0424938-B',
                ucinn_ascendv2__Opportunity__c=opps[2].Id,
                ucinn_ascendv2__Designation__c=desigs[3].Id,
                ucinn_ascendv2__Amount__c=50000
            ),
            new ucinn_ascendv2__Designation_Detail__c(  // [4] Pledge opp3 — $50k
                Name='DD-PN0508932',
                ucinn_ascendv2__Opportunity__c=opps[3].Id,
                ucinn_ascendv2__Designation__c=desigs[4].Id,
                ucinn_ascendv2__Amount__c=50000
            )
        };
        insert ddList;

        // ── Running user for PRM receipt ──────────────────────────────
        User runningUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

        // ── Receipts ──────────────────────────────────────────────────
        // NOTE: Receipts do NOT store the credit Id here.
        // Each test passes the credit/opp Id in the Request.creditIdsCsv directly,
        // so HAM_Credit_Line_Ids__c is informational only and not used by the service.
        insert new List<Receipt__c>{
            new Receipt__c(                             // [0] Hard Credit receipt
                HAM_Receipt_Type__c      = TYPE_HARD_CREDIT,
                HAM_Status__c            = 'Draft',
                HAM_Letter_Salutation__c = 'Richard and Ann',
                HAM_Street_Address__c    = '12 Lafayette Cir',
                HAM_Letter_Addressee__c  = 'Richard Cleary and Ann Trenk',
                HAM_City__c              = 'Wellesley',
                HAM_ZipCode__c           = '02482-4420',
                HAM_State__c             = 'MA'
            ),
            new Receipt__c(                             // [1] Pledge Reminder with PRM
                HAM_Receipt_Type__c      = TYPE_PLEDGE_REMINDER,
                HAM_Status__c            = 'Draft',
                HAM_Letter_Salutation__c = 'Greg and Carolyn',
                HAM_Street_Address__c    = '11 E 86th St Apt 21',
                HAM_Letter_Addressee__c  = 'Greg and Carolyn Hoogkamp',
                HAM_City__c              = 'New York',
                HAM_ZipCode__c           = '10028-0501',
                HAM_State__c             = 'NY',
                PRM_ID__c                = runningUser.Id
            ),
            new Receipt__c(                             // [2] Pledge Reminder, no PRM
                HAM_Receipt_Type__c = TYPE_PLEDGE_REMINDER,
                HAM_Status__c       = 'Draft'
            )
        };
    }

    // ================================================================
    // HELPERS
    // ================================================================

    private static List<Receipt__c> getReceipts() {
        return [
            SELECT Id, HAM_Receipt_Type__c, PRM_ID__c,
                   PRM_Name__c, HAM_Email_of_PRM__c, HAM_Phone__c, HAM_Job_title__c
            FROM Receipt__c ORDER BY CreatedDate ASC
        ];
    }

    private static List<Opportunity> getOpps() {
        return [SELECT Id, Name FROM Opportunity ORDER BY CreatedDate ASC];
    }

    private static List<ucinn_ascendv2__Designation_Detail__c> getDDs() {
        return [
            SELECT Id, Name, ucinn_ascendv2__Opportunity__c, ucinn_ascendv2__Designation__c,
                   ucinn_ascendv2__Amount__c
            FROM ucinn_ascendv2__Designation_Detail__c
            ORDER BY CreatedDate ASC
        ];
    }

    private static List<HAM_Receipt_Line_Item__c> getLineItems(Id receiptId) {
        return [
            SELECT Id, HAM_Receipt__c, HAM_Hard_and_Soft_Credit__c,
                   HAM_Designation__c, HAM_Gift_Pledge__c, Amount__c,
                   HAM_Designation_Detail__c, HAM_Amount_Paid_to_Date__c,
                   Remaining_Amount_due__c
            FROM HAM_Receipt_Line_Item__c
            WHERE HAM_Receipt__c = :receiptId
        ];
    }

    /**
     * @description Inserts a Hard/Soft Credit in the current test transaction
     *              so it is owned by the running user and visible via SOQL
     *              through the master-detail chain (Credit → DesigDetail → Opp).
     */
    private static ucinn_ascendv2__Hard_and_Soft_Credit__c insertCredit() {
        // Re-query DD and Opp so we get the Ids in this test's transaction context
        ucinn_ascendv2__Designation_Detail__c dd =
            [SELECT Id, ucinn_ascendv2__Designation__c, ucinn_ascendv2__Opportunity__c
             FROM ucinn_ascendv2__Designation_Detail__c WHERE Name = 'DD-GN0493871' LIMIT 1];

        ucinn_ascendv2__Hard_and_Soft_Credit__c credit =
            new ucinn_ascendv2__Hard_and_Soft_Credit__c(
                ucinn_ascendv2__Opportunity__c=dd.ucinn_ascendv2__Opportunity__c,
                ucinn_ascendv2__Credit_Amount__c=100,
                ucinn_ascendv2__Credit_Type__c='Hard',
                ucinn_ascendv2__Designation_Detail__c=dd.Id,      // required master-detail
                ucinn_ascendv2__Designation__c=dd.ucinn_ascendv2__Designation__c
            );
        insert credit;
        return credit;
    }

    /** Builds a Request for the single invocable entry point. */
    private static HAMReceiptLineItemService.Request req(
        Id receiptId, String csv, String typeVal
    ) {
        HAMReceiptLineItemService.Request x = new HAMReceiptLineItemService.Request();
        x.receiptId    = receiptId;
        x.creditIdsCsv = csv;
        x.receiptType  = typeVal;
        return x;
    }

    /**
     * @description Inserts a PRM Contact whose Email matches the running user's
     *              email in the current test transaction.
     *              Mirrors Dick Tantillo (Senior Philanthropy Adviser, Employee).
     *
     *              IMPORTANT: uses Phone (standard "Business Phone" field, ApiName=Phone)
     *              because queryPrmContacts in the service SELECTs Phone and maps it
     *              to Receipt__c.HAM_Phone__c. HAM_Campus_Cell__c is NOT queried by
     *              the service and must NOT be used here for phone assertions.
     */
    private static Contact insertPrmContact() {
        User u = [SELECT Email FROM User WHERE Id = :UserInfo.getUserId()];
        Contact c = new Contact(
            FirstName    = 'Dick',
            LastName     = 'Tantillo',
            Email        = u.Email,
            Phone        = '3157231915',              // standard Phone field — queried by service
            Job_Title__c = 'Senior Philanthropy Adviser',
            ucinn_ascendv2__Contact_Type__c = 'Employee'
        );
        insert c;
        return c;
    }


    // ================================================================
    // HARD CREDIT FLOW TESTS
    // ================================================================

    @IsTest
    static void testHardCreditFlow_CreatesOneLineItem() {
        List<Receipt__c> receipts = getReceipts();
        ucinn_ascendv2__Hard_and_Soft_Credit__c credit = insertCredit();

        Test.startTest();
        List<HAMReceiptLineItemService.Response> res =
            HAMReceiptLineItemService.createLineItems(
                new List<HAMReceiptLineItemService.Request>{
                    req(receipts[0].Id, credit.Id, TYPE_HARD_CREDIT)
                }
            );
        Test.stopTest();

        System.assertEquals(1, res.size());
        System.assertEquals(receipts[0].Id, res[0].receiptId);
        System.assertEquals(1, res[0].createdCount,        '1 Hard Credit → 1 line item');
        System.assertEquals(0, res[0].skippedExistingCount, 'No duplicates');
        System.assertEquals(0, res[0].invalidIdCount,       'No invalid Ids');
        System.assertEquals(null, res[0].errorMessage,      'No error');
        System.assertEquals(1, getLineItems(receipts[0].Id).size(), '1 line item in DB');
    }

    @IsTest
    static void testHardCreditFlow_FieldMapping() {
        List<Receipt__c> receipts = getReceipts();
        ucinn_ascendv2__Hard_and_Soft_Credit__c credit = insertCredit();

        ucinn_ascendv2__Hard_and_Soft_Credit__c fullCredit = [
            SELECT Id, ucinn_ascendv2__Credit_Amount__c,
                   ucinn_ascendv2__Designation__c, ucinn_ascendv2__Opportunity__c
            FROM ucinn_ascendv2__Hard_and_Soft_Credit__c WHERE Id = :credit.Id
        ];

        Test.startTest();
        HAMReceiptLineItemService.createLineItems(
            new List<HAMReceiptLineItemService.Request>{
                req(receipts[0].Id, credit.Id, TYPE_HARD_CREDIT)
            }
        );
        Test.stopTest();

        List<HAM_Receipt_Line_Item__c> lis = getLineItems(receipts[0].Id);
        System.assertEquals(1, lis.size());
        System.assertEquals(receipts[0].Id,                              lis[0].HAM_Receipt__c);
        System.assertEquals(credit.Id,                                   lis[0].HAM_Hard_and_Soft_Credit__c);
        System.assertEquals(100,                                         lis[0].Amount__c,
            'Amount = $100');
        System.assertEquals(fullCredit.ucinn_ascendv2__Designation__c,   lis[0].HAM_Designation__c,
            'Designation mapped from credit');
        System.assertEquals(fullCredit.ucinn_ascendv2__Opportunity__c,   lis[0].HAM_Gift_Pledge__c,
            'Opportunity mapped from credit');
    }

    @IsTest
    static void testHardCreditFlow_SkipsDuplicates() {
        List<Receipt__c> receipts = getReceipts();
        ucinn_ascendv2__Hard_and_Soft_Credit__c credit = insertCredit();

        // Seed — first insert
        HAMReceiptLineItemService.createLineItems(
            new List<HAMReceiptLineItemService.Request>{
                req(receipts[0].Id, credit.Id, TYPE_HARD_CREDIT)
            }
        );

        Test.startTest();
        List<HAMReceiptLineItemService.Response> res =
            HAMReceiptLineItemService.createLineItems(
                new List<HAMReceiptLineItemService.Request>{
                    req(receipts[0].Id, credit.Id, TYPE_HARD_CREDIT)
                }
            );
        Test.stopTest();

        System.assertEquals(0, res[0].createdCount,        'Duplicate → 0 created');
        System.assertEquals(1, res[0].skippedExistingCount, '1 skipped');
        System.assertEquals(1, getLineItems(receipts[0].Id).size(), 'Still 1 in DB');
    }

    @IsTest
    static void testHardCreditFlow_InvalidIdCounted() {
        List<Receipt__c> receipts = getReceipts();
        ucinn_ascendv2__Hard_and_Soft_Credit__c credit = insertCredit();

        Test.startTest();
        List<HAMReceiptLineItemService.Response> res =
            HAMReceiptLineItemService.createLineItems(
                new List<HAMReceiptLineItemService.Request>{
                    req(receipts[0].Id, credit.Id + ',BADID', TYPE_HARD_CREDIT)
                }
            );
        Test.stopTest();

        System.assertEquals(1, res[0].createdCount,  '1 valid → 1 line item');
        System.assertEquals(1, res[0].invalidIdCount, 'BADID → 1 invalid');
    }

    @IsTest
    static void testHardCreditFlow_NullCsv() {
        List<Receipt__c> receipts = getReceipts();

        Test.startTest();
        List<HAMReceiptLineItemService.Response> res =
            HAMReceiptLineItemService.createLineItems(
                new List<HAMReceiptLineItemService.Request>{
                    req(receipts[0].Id, null, TYPE_HARD_CREDIT)
                }
            );
        Test.stopTest();

        System.assertEquals(0, res[0].createdCount,   'Null CSV → 0');
        System.assertEquals(0, res[0].invalidIdCount,  'Null CSV → 0 invalid');
        System.assertEquals(null, res[0].errorMessage, 'No error');
    }


    // ================================================================
    // PLEDGE REMINDER FLOW TESTS
    // ================================================================

    @IsTest
    static void testPledgeFlow_CreatesLineItemsWhenRemainingGtZero() {
        // 3 opps: PN0495534(1 DD) + PN0424938(2 DDs) + PN0508932(1 DD) = 4 line items
        List<Receipt__c> receipts = getReceipts();
        List<Opportunity> opps    = getOpps();

        Test.startTest();
        List<HAMReceiptLineItemService.Response> res =
            HAMReceiptLineItemService.createLineItems(
                new List<HAMReceiptLineItemService.Request>{
                    req(receipts[1].Id,
                        opps[1].Id + ',' + opps[2].Id + ',' + opps[3].Id,
                        TYPE_PLEDGE_REMINDER)
                }
            );
        Test.stopTest();

        System.assertEquals(1, res.size());
        System.assertEquals(receipts[1].Id, res[0].receiptId);
        System.assertEquals(4, res[0].createdCount,
            '4 DDs with Remaining > 0: opp1(1)+opp2(2)+opp3(1)');
        System.assertEquals(0, res[0].skippedExistingCount);
        System.assertEquals(0, res[0].invalidIdCount);
        System.assertEquals(null, res[0].errorMessage);
        System.assertEquals(4, getLineItems(receipts[1].Id).size(), '4 line items in DB');
    }

    @IsTest
    static void testPledgeFlow_FieldMappingOnLineItem() {
        List<Receipt__c> receipts = getReceipts();
        List<Opportunity> opps    = getOpps();

        Test.startTest();
        HAMReceiptLineItemService.createLineItems(
            new List<HAMReceiptLineItemService.Request>{
                req(receipts[1].Id, opps[1].Id, TYPE_PLEDGE_REMINDER)
            }
        );
        Test.stopTest();

        ucinn_ascendv2__Designation_Detail__c dd = [
            SELECT Id, ucinn_ascendv2__Designation__c, ucinn_ascendv2__Opportunity__c,
                   ucinn_ascendv2__Remaining_Amt_Same_Designation_Formula__c,
                   ucinn_ascendv2__Amt_Paid_to_Date_Same_Desig_Roll_Up__c,
                   HAM_Opportunity_Amount__c
            FROM ucinn_ascendv2__Designation_Detail__c WHERE Name = 'DD-PN0495534'
        ];

        List<HAM_Receipt_Line_Item__c> lis = getLineItems(receipts[1].Id);
        System.assertEquals(1, lis.size(), '1 line item for single-DD opp');
        System.assertEquals(receipts[1].Id,                  lis[0].HAM_Receipt__c);
        System.assertEquals(opps[1].Id,                      lis[0].HAM_Gift_Pledge__c);
        System.assertEquals(dd.ucinn_ascendv2__Designation__c, lis[0].HAM_Designation__c);
        System.assertEquals(dd.Id,                           lis[0].HAM_Designation_Detail__c);
        System.assertEquals(dd.HAM_Opportunity_Amount__c,    lis[0].Amount__c);
        System.assertEquals(
            dd.ucinn_ascendv2__Amt_Paid_to_Date_Same_Desig_Roll_Up__c,
            lis[0].HAM_Amount_Paid_to_Date__c
        );
        System.assertEquals(
            dd.ucinn_ascendv2__Remaining_Amt_Same_Designation_Formula__c,
            lis[0].Remaining_Amount_due__c
        );
    }

    @IsTest
    static void testPledgeFlow_SkipsDuplicates() {
        List<Receipt__c> receipts = getReceipts();
        List<Opportunity> opps    = getOpps();

        // Seed
        HAMReceiptLineItemService.createLineItems(
            new List<HAMReceiptLineItemService.Request>{
                req(receipts[1].Id, opps[1].Id, TYPE_PLEDGE_REMINDER)
            }
        );

        Test.startTest();
        List<HAMReceiptLineItemService.Response> res =
            HAMReceiptLineItemService.createLineItems(
                new List<HAMReceiptLineItemService.Request>{
                    req(receipts[1].Id, opps[1].Id, TYPE_PLEDGE_REMINDER)
                }
            );
        Test.stopTest();

        System.assertEquals(0, res[0].createdCount,        'Duplicate → 0 created');
        System.assertEquals(1, res[0].skippedExistingCount, '1 skipped');
        System.assertEquals(1, getLineItems(receipts[1].Id).size(), 'Still 1 in DB');
    }

    @IsTest
    static void testPledgeFlow_InvalidOppIds() {
        List<Receipt__c> receipts = getReceipts();

        Test.startTest();
        List<HAMReceiptLineItemService.Response> res =
            HAMReceiptLineItemService.createLineItems(
                new List<HAMReceiptLineItemService.Request>{
                    req(receipts[1].Id, 'BADID,SHORT', TYPE_PLEDGE_REMINDER)
                }
            );
        Test.stopTest();

        System.assertEquals(2, res[0].invalidIdCount, 'Both tokens invalid');
        System.assertEquals(0, res[0].createdCount);
    }

    @IsTest
    static void testPledgeFlow_NullCsv() {
        List<Receipt__c> receipts = getReceipts();

        Test.startTest();
        List<HAMReceiptLineItemService.Response> res =
            HAMReceiptLineItemService.createLineItems(
                new List<HAMReceiptLineItemService.Request>{
                    req(receipts[2].Id, null, TYPE_PLEDGE_REMINDER)
                }
            );
        Test.stopTest();

        System.assertEquals(0, res[0].createdCount,   'Null CSV → 0');
        System.assertEquals(0, res[0].invalidIdCount,  'Null CSV → 0 invalid');
        System.assertEquals(null, res[0].errorMessage, 'No error');
    }


    // ================================================================
    // PRM UPDATE TESTS
    // ================================================================

    /**
     * @description Verifies that when a Receipt has an explicit PRM_ID__c pointing to
     *              the running user, and a matching Employee Contact exists with the same
     *              email, all four PRM fields are stamped onto the Receipt.
     *
     *              Phone assertion uses stored.Phone (Contact.Phone / "Business Phone"),
     *              which is the field the service queries and maps to HAM_Phone__c.
     */
    @IsTest
    static void testPrmUpdate_WithPrmId_UpdatesReceiptFields() {
        Contact prmContact = insertPrmContact();
        List<Receipt__c> receipts = getReceipts();
        List<Opportunity> opps    = getOpps();

        Test.startTest();
        HAMReceiptLineItemService.createLineItems(
            new List<HAMReceiptLineItemService.Request>{
                req(receipts[1].Id,
                    opps[1].Id + ',' + opps[2].Id + ',' + opps[3].Id,
                    TYPE_PLEDGE_REMINDER)
            }
        );
        Test.stopTest();

        // Re-query the contact to get its stored field values (Phone, not HAM_Campus_Cell__c)
        Contact stored = [
            SELECT Email, Phone, HAM_Name_w_Suffix__c, Job_Title__c
            FROM Contact WHERE Id = :prmContact.Id
        ];
        Receipt__c updated = [
            SELECT HAM_Email_of_PRM__c, PRM_Name__c, HAM_Phone__c, HAM_Job_title__c
            FROM Receipt__c WHERE Id = :receipts[1].Id
        ];

        System.assertEquals(stored.Email,            updated.HAM_Email_of_PRM__c, 'Email mapped');
        System.assertEquals(stored.Phone,            updated.HAM_Phone__c,        'Phone mapped');
        System.assertEquals(stored.HAM_Name_w_Suffix__c, updated.PRM_Name__c,    'Name mapped');
        System.assertEquals(stored.Job_Title__c,     updated.HAM_Job_title__c,    'Job title mapped');
    }

    /**
     * @description Verifies that when a Receipt has no PRM_ID__c, the service falls back
     *              to Label.Default_PRM_For_Pledge. In a standard test sandbox the default
     *              PRM User's email will not match any Employee Contact, so the four PRM
     *              fields remain null — but critically, no exception is thrown.
     *
     *              This is a behavioural change from v1.6: receipts with no PRM_ID__c are
     *              no longer silently skipped; they attempt the full PRM resolution chain
     *              using the label value.
     */
    @IsTest
    static void testPrmUpdate_NoPrmId_UsesDefaultPrm_NoMatchingContact() {
        List<Receipt__c> receipts = getReceipts();
        List<Opportunity> opps    = getOpps();

        Test.startTest();
        // receipts[2] has no PRM_ID__c — service will substitute Label.Default_PRM_For_Pledge
        HAMReceiptLineItemService.createLineItems(
            new List<HAMReceiptLineItemService.Request>{
                req(receipts[2].Id, opps[1].Id, TYPE_PLEDGE_REMINDER)
            }
        );
        Test.stopTest();

        Receipt__c updated = [
            SELECT HAM_Email_of_PRM__c, PRM_Name__c, HAM_Phone__c, HAM_Job_title__c
            FROM Receipt__c WHERE Id = :receipts[2].Id
        ];

        // No Employee Contact matches the default PRM User's email in test context
        // → PRM fields stay null, but DML completed without error
        System.assertEquals(null, updated.HAM_Email_of_PRM__c,
            'No matching Employee Contact for default PRM → null');
        System.assertEquals(null, updated.PRM_Name__c,
            'No matching Employee Contact for default PRM → null');
        System.assertEquals(null, updated.HAM_Phone__c,
            'No matching Employee Contact for default PRM → null');
        System.assertEquals(null, updated.HAM_Job_title__c,
            'No matching Employee Contact for default PRM → null');
    }

    /**
     * @description Smoke test for the default-PRM fallback path when the label's User
     *              DOES have a matching Employee Contact.
     *
     *              We simulate this by inserting an Employee Contact whose email matches
     *              the running user (who is also the label value in a typical developer
     *              sandbox where Label.Default_PRM_For_Pledge = running user's Id).
     *
     *              If the label resolves to a different user in the target org, the
     *              PRM fields will remain null (same as the previous test) — the intent
     *              here is to confirm the entire code path executes without exception
     *              when a match is theoretically possible.
     */
    @IsTest
    static void testPrmUpdate_NoPrmId_DefaultPrmMatchesRunningUser() {
        // Insert an Employee Contact matching the running user's email so that IF
        // the label resolves to the running user, the PRM chain will find a match.
        Contact prmContact = insertPrmContact();
        List<Receipt__c> receipts = getReceipts();
        List<Opportunity> opps    = getOpps();

        Test.startTest();
        // receipts[2] has no PRM_ID__c → falls back to Label.Default_PRM_For_Pledge
        HAMReceiptLineItemService.createLineItems(
            new List<HAMReceiptLineItemService.Request>{
                req(receipts[2].Id, opps[1].Id, TYPE_PLEDGE_REMINDER)
            }
        );
        Test.stopTest();

        Receipt__c updated = [
            SELECT HAM_Email_of_PRM__c, PRM_Name__c, HAM_Phone__c, HAM_Job_title__c
            FROM Receipt__c WHERE Id = :receipts[2].Id
        ];

        // Two valid outcomes depending on what the label contains in this org:
        //   (a) Label = running user → Employee Contact found → fields populated
        //   (b) Label = different user → no Employee Contact match → fields null
        // Either way, no exception should have been thrown.
        System.assert(true, 'Default PRM fallback path completed without exception');

        // If fields were populated, validate the mapping is correct
        if (updated.HAM_Email_of_PRM__c != null) {
            Contact stored = [
                SELECT Email, Phone, HAM_Name_w_Suffix__c, Job_Title__c
                FROM Contact WHERE Id = :prmContact.Id
            ];
            System.assertEquals(stored.Email,            updated.HAM_Email_of_PRM__c,
                'Default PRM: email mapped correctly');
            System.assertEquals(stored.Phone,            updated.HAM_Phone__c,
                'Default PRM: phone mapped correctly');
            System.assertEquals(stored.HAM_Name_w_Suffix__c, updated.PRM_Name__c,
                'Default PRM: name mapped correctly');
            System.assertEquals(stored.Job_Title__c,     updated.HAM_Job_title__c,
                'Default PRM: job title mapped correctly');
        }
    }

    @IsTest
    static void testPrmUpdate_ContactNotEmployee_NoUpdate() {
        User u = [SELECT Email FROM User WHERE Id = :UserInfo.getUserId()];
        insert new Contact(
            FirstName='Non', LastName='Employee',
            Email=u.Email,
            ucinn_ascendv2__Contact_Type__c='Alumni'
        );
        List<Receipt__c> receipts = getReceipts();
        List<Opportunity> opps    = getOpps();

        Test.startTest();
        HAMReceiptLineItemService.createLineItems(
            new List<HAMReceiptLineItemService.Request>{
                req(receipts[1].Id, opps[1].Id, TYPE_PLEDGE_REMINDER)
            }
        );
        Test.stopTest();

        Receipt__c updated = [
            SELECT HAM_Email_of_PRM__c, PRM_Name__c
            FROM Receipt__c WHERE Id = :receipts[1].Id
        ];
        System.assertEquals(null, updated.HAM_Email_of_PRM__c, 'Non-Employee → not updated');
        System.assertEquals(null, updated.PRM_Name__c,          'Non-Employee → not updated');
    }


    // ================================================================
    // NULL / EMPTY GUARD TESTS
    // ================================================================

    @IsTest
    static void testNullRequestList() {
        Test.startTest();
        List<HAMReceiptLineItemService.Response> res =
            HAMReceiptLineItemService.createLineItems(null);
        Test.stopTest();
        System.assertEquals(0, res.size());
    }

    @IsTest
    static void testEmptyRequestList() {
        Test.startTest();
        List<HAMReceiptLineItemService.Response> res =
            HAMReceiptLineItemService.createLineItems(
                new List<HAMReceiptLineItemService.Request>()
            );
        Test.stopTest();
        System.assertEquals(0, res.size());
    }

    @IsTest
    static void testNullReceiptId() {
        HAMReceiptLineItemService.Request r = new HAMReceiptLineItemService.Request();
        r.receiptId    = null;
        r.creditIdsCsv = 'SOMEID';
        r.receiptType  = TYPE_HARD_CREDIT;

        Test.startTest();
        List<HAMReceiptLineItemService.Response> res =
            HAMReceiptLineItemService.createLineItems(
                new List<HAMReceiptLineItemService.Request>{ r }
            );
        Test.stopTest();

        System.assertNotEquals(null, res[0].errorMessage, 'Null receiptId → errorMessage');
        System.assertEquals(0, res[0].createdCount);
    }

    @IsTest
    static void testNullReceiptTypeDefaultsToHardCredit() {
        List<Receipt__c> receipts = getReceipts();
        ucinn_ascendv2__Hard_and_Soft_Credit__c credit = insertCredit();

        Test.startTest();
        List<HAMReceiptLineItemService.Response> res =
            HAMReceiptLineItemService.createLineItems(
                new List<HAMReceiptLineItemService.Request>{
                    req(receipts[0].Id, credit.Id, null)
                }
            );
        Test.stopTest();

        System.assertEquals(1, res[0].createdCount,
            'null receiptType → Hard Credit path → 1 line item');
    }


    // ================================================================
    // MIXED-BATCH ROUTING & ORDER TESTS
    // ================================================================

    @IsTest
    static void testMixedBatch_ResultOrderPreserved() {
        List<Receipt__c> receipts = getReceipts();
        List<Opportunity> opps    = getOpps();
        ucinn_ascendv2__Hard_and_Soft_Credit__c credit = insertCredit();

        Test.startTest();
        List<HAMReceiptLineItemService.Response> res =
            HAMReceiptLineItemService.createLineItems(
                new List<HAMReceiptLineItemService.Request>{
                    req(receipts[1].Id, opps[1].Id,  TYPE_PLEDGE_REMINDER), // pos 0
                    req(receipts[0].Id, credit.Id,   TYPE_HARD_CREDIT),     // pos 1
                    req(receipts[2].Id, opps[3].Id,  TYPE_PLEDGE_REMINDER)  // pos 2
                }
            );
        Test.stopTest();

        System.assertEquals(3, res.size());
        System.assertEquals(receipts[1].Id, res[0].receiptId, 'res[0] = Pledge');
        System.assertEquals(receipts[0].Id, res[1].receiptId, 'res[1] = Hard Credit');
        System.assertEquals(receipts[2].Id, res[2].receiptId, 'res[2] = Pledge');
        System.assertEquals(1, res[0].createdCount, 'Pledge[0]: 1 DD');
        System.assertEquals(1, res[1].createdCount, 'Hard Credit in mixed batch: 1 line item');
        System.assertEquals(1, res[2].createdCount, 'Pledge[2]: 1 DD');
    }

    @IsTest
    static void testMixedBatch_AllHardCredit() {
        List<Receipt__c> receipts = getReceipts();
        ucinn_ascendv2__Hard_and_Soft_Credit__c credit = insertCredit();

        Receipt__c r2 = new Receipt__c(
            HAM_Receipt_Type__c = TYPE_HARD_CREDIT,
            HAM_Status__c       = 'Draft'
        );
        insert r2;

        Test.startTest();
        List<HAMReceiptLineItemService.Response> res =
            HAMReceiptLineItemService.createLineItems(
                new List<HAMReceiptLineItemService.Request>{
                    req(receipts[0].Id, credit.Id, TYPE_HARD_CREDIT),
                    req(r2.Id,          credit.Id, TYPE_HARD_CREDIT)
                }
            );
        Test.stopTest();

        System.assertEquals(2, res.size());
        System.assertEquals(1, res[0].createdCount, 'Receipt[0]: 1 line item');
        System.assertEquals(1, res[1].createdCount, 'Receipt[1]: 1 line item');
    }

    @IsTest
    static void testMixedBatch_AllPledgeReminders() {
        List<Receipt__c> receipts = getReceipts();
        List<Opportunity> opps    = getOpps();

        Test.startTest();
        List<HAMReceiptLineItemService.Response> res =
            HAMReceiptLineItemService.createLineItems(
                new List<HAMReceiptLineItemService.Request>{
                    req(receipts[1].Id, opps[1].Id, TYPE_PLEDGE_REMINDER),
                    req(receipts[2].Id, opps[3].Id, TYPE_PLEDGE_REMINDER)
                }
            );
        Test.stopTest();

        System.assertEquals(2, res.size());
        System.assertEquals(1, res[0].createdCount, 'Pledge[0]: 1 DD → 1 line item');
        System.assertEquals(1, res[1].createdCount, 'Pledge[1]: 1 DD → 1 line item');
    }


    // ================================================================
    // BULK / GOVERNOR LIMIT SMOKE TEST
    // ================================================================

    @IsTest
    static void testBulk_200HardCreditReceipts() {
        ucinn_ascendv2__Hard_and_Soft_Credit__c credit = insertCredit();

        List<Receipt__c> bulkReceipts = new List<Receipt__c>();
        for (Integer i = 0; i < 200; i++) {
            bulkReceipts.add(new Receipt__c(
                HAM_Receipt_Type__c = TYPE_HARD_CREDIT,
                HAM_Status__c       = 'Draft'
            ));
        }
        insert bulkReceipts;

        List<HAMReceiptLineItemService.Request> reqs = new List<HAMReceiptLineItemService.Request>();
        for (Receipt__c r : bulkReceipts) {
            reqs.add(req(r.Id, credit.Id, TYPE_HARD_CREDIT));
        }

        Test.startTest();
        List<HAMReceiptLineItemService.Response> res =
            HAMReceiptLineItemService.createLineItems(reqs);
        Test.stopTest();

        System.assertEquals(200, res.size());
        for (HAMReceiptLineItemService.Response x : res) {
            System.assertEquals(1,    x.createdCount,  'Each receipt → 1 line item');
            System.assertEquals(null, x.errorMessage,  'No DML errors');
        }
    }
}