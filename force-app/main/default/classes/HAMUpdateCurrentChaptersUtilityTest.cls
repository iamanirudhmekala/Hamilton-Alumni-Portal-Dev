/**
 * @class       UpdateCurrentChaptersUtilityTest
 * @description Test coverage for UpdateCurrentChaptersUtility.
 *
 *              This utility's entry point accepts a List<Id> of Contact Ids and
 *              re-aggregates all active HAM_Current_Chapter__c records for those
 *              Contacts into the two summary fields on Contact:
 *                  - HAM_Current_Chapters__c  (comma-separated, alpha-sorted chapter names)
 *                  - HAM_Current_Regions__c   (semicolon-separated unique region values)
 *
 *              Because this utility does NOT create junction records itself, each
 *              test method must pre-insert HAM_Current_Chapter__c records before
 *              invoking the utility.
 *
 *              Test matrix:
 *              ┌──────────────────────────────────────────────────────────────────┐
 *              │ Method                                   │ What it proves        │
 *              ├──────────────────────────────────────────────────────────────────┤
 *              │ testHappyPathThreeChapters               │ Contact with 3 active │
 *              │                                          │ junction records gets │
 *              │                                          │ both fields populated │
 *              │                                          │ correctly             │
 *              ├──────────────────────────────────────────────────────────────────┤
 *              │ testInactiveJunctionRecordsExcluded      │ Is_Active__c = false  │
 *              │                                          │ records do not appear │
 *              │                                          │ in either summary     │
 *              ├──────────────────────────────────────────────────────────────────┤
 *              │ testContactWithNoJunctionRecordsCleared  │ Contact with zero     │
 *              │                                          │ active junction       │
 *              │                                          │ records gets both     │
 *              │                                          │ fields set to ''      │
 *              ├──────────────────────────────────────────────────────────────────┤
 *              │ testRegionDeduplication                  │ Two chapters in the   │
 *              │                                          │ same region produce   │
 *              │                                          │ only one region value │
 *              ├──────────────────────────────────────────────────────────────────┤
 *              │ testAlphabeticalChapterOrdering          │ Chapter names appear  │
 *              │                                          │ in ascending alpha    │
 *              │                                          │ order regardless of   │
 *              │                                          │ insert order          │
 *              ├──────────────────────────────────────────────────────────────────┤
 *              │ testBulkMultipleContacts                 │ Two Contacts in one   │
 *              │                                          │ call each get their   │
 *              │                                          │ own correct strings   │
 *              ├──────────────────────────────────────────────────────────────────┤
 *              │ testEmptyListIsNoop                      │ Empty Id list         │
 *              │                                          │ completes without     │
 *              │                                          │ error                 │
 *              └──────────────────────────────────────────────────────────────────┘
 *
 *              Note on @TestSetup: Per org convention (master-detail DML visibility
 *              issues with managed package objects), all test data is built
 *              per-method via buildTestData(). This mirrors the pattern established
 *              in ContactCurrentChaptersUtilityTest.
 *
 * @author      Hamilton College - Ameya
 * @version     1.0  2026-04-30  Initial implementation.
 */
@isTest
private class HAMUpdateCurrentChaptersUtilityTest {

    // =========================================================================
    // Shared test-data infrastructure
    // =========================================================================
 
    /**
     * Wrapper that carries all inserted records so individual test methods can
     * reference them without re-querying, avoiding the @TestSetup visibility issue.
     */
    private class TestData {
        Contact               contactA;
        Contact               contactB;
        HAM_Chapter_Lookup__c chapterFLOR;
        HAM_Chapter_Lookup__c chapterCHI;
        HAM_Chapter_Lookup__c chapterNYC;
    }
 
    /**
     * Builds the core test-data graph shared across most test methods.
     * Inserts required Trigger Handlers, Org-Wide Config, Address Type Mappings,
     * two Contacts, and three Chapter Lookup records.
     *
     * HAM_Current_Chapter__c junction records are NOT created here — each test
     * method inserts only the junction records it needs to prove its scenario.
     *
     * Chapters seeded:
     *   FLOR – "Florida (Orlando)"         region: Anytown
     *   CHIL – "Illinois (Chicago)"        region: Chicago
     *   NYNY – "New York (New York City)"  region: NYC
     */
    private static TestData buildTestData() {
 
        // ── Trigger handlers (required for Ascend package) ────────────────────
        insert new List<ucinn_ascendv2__Trigger_Handler__c>{
            new ucinn_ascendv2__Trigger_Handler__c(
                Name                                  = 'ascend_TRIG_AccountHandler',
                ucinn_ascendv2__Class__c              = 'ascend_TRIG_AccountHandler',
                ucinn_ascendv2__Is_Active__c          = true,
                ucinn_ascendv2__Is_Asynchronous__c    = false,
                ucinn_ascendv2__Is_User_Managed__c    = true,
                ucinn_ascendv2__Owned_by_Namespace__c = 'ucinn_ascendv2',
                ucinn_ascendv2__Load_Order__c         = 1.0,
                ucinn_ascendv2__Object__c             = 'Account',
                ucinn_ascendv2__Trigger_Action__c     = 'BeforeInsert;BeforeUpdate;BeforeDelete;AfterInsert;AfterUpdate;AfterDelete;AfterUndelete'
            ),
            new ucinn_ascendv2__Trigger_Handler__c(
                Name                                  = 'ascend_TRIG_ContactHandler',
                ucinn_ascendv2__Class__c              = 'ascend_TRIG_ContactHandler',
                ucinn_ascendv2__Is_Active__c          = true,
                ucinn_ascendv2__Is_Asynchronous__c    = false,
                ucinn_ascendv2__Is_User_Managed__c    = true,
                ucinn_ascendv2__Owned_by_Namespace__c = 'ucinn_ascendv2',
                ucinn_ascendv2__Load_Order__c         = 1.0,
                ucinn_ascendv2__Object__c             = 'Contact',
                ucinn_ascendv2__Trigger_Action__c     = 'BeforeInsert;BeforeUpdate;BeforeDelete;AfterInsert;AfterUpdate;AfterDelete;AfterUndelete'
            )
        };
 
        // ── Org-wide config & address type mappings ───────────────────────────
        insert new ucinn_ascendv2__Org_Wide_Configuration__c(
            Name                                                     = 'Default Org Wide Config',
            ucinn_ascendv2__Is_Multiple_Current_Addresses_Enabled__c = true
        );
 
        insert new List<ucinn_ascendv2__Address_Type_Mapping__c>{
            new ucinn_ascendv2__Address_Type_Mapping__c(
                Name                                                  = 'Contact_Mailing',
                ucinn_ascendv2__Address_Type_Label_Backend_Message__c = 'residence',
                ucinn_ascendv2__Object_API_Name__c                    = 'Contact',
                ucinn_ascendv2__Address_Relation_Type__c              = 'Residence',
                ucinn_ascendv2__Backend_Address_Type_API_Name__c      = 'Residence',
                ucinn_ascendv2__Object_Address_Field_Name__c          = 'MailingAddress'
            ),
            new ucinn_ascendv2__Address_Type_Mapping__c(
                Name                                                  = 'Contact_Other',
                ucinn_ascendv2__Address_Type_Label_Backend_Message__c = 'business',
                ucinn_ascendv2__Object_API_Name__c                    = 'Contact',
                ucinn_ascendv2__Address_Relation_Type__c              = 'Business',
                ucinn_ascendv2__Backend_Address_Type_API_Name__c      = 'Business',
                ucinn_ascendv2__Object_Address_Field_Name__c          = 'OtherAddress'
            )
        };
 
        // ── Contacts ──────────────────────────────────────────────────────────
        TestData td  = new TestData();
        td.contactA  = new Contact(
            FirstName                       = 'Alpha',
            LastName                        = 'Test Constituent',
            ucinn_ascendv2__Contact_Type__c = 'Employee'
        );
        td.contactB  = new Contact(
            FirstName                       = 'Beta',
            LastName                        = 'Test Constituent',
            ucinn_ascendv2__Contact_Type__c = 'Employee'
        );
        insert new List<Contact>{ td.contactA, td.contactB };
 
        // ── Chapter lookup records ────────────────────────────────────────────
        td.chapterFLOR = new HAM_Chapter_Lookup__c(
            Name                = 'Florida (Orlando)',
            HAM_Chapter_Code__c = 'FLOR',
            HAM_Chapter_Type__c = 'Domestic',
            HAM_Region__c       = 'Anytown'
        );
        td.chapterCHI = new HAM_Chapter_Lookup__c(
            Name                = 'Illinois (Chicago)',
            HAM_Chapter_Code__c = 'CHIL',
            HAM_Chapter_Type__c = 'Domestic',
            HAM_Region__c       = 'Chicago'
        );
        td.chapterNYC = new HAM_Chapter_Lookup__c(
            Name                = 'New York (New York City)',
            HAM_Chapter_Code__c = 'NYNY',
            HAM_Chapter_Type__c = 'Domestic',
            HAM_Region__c       = 'NYC'
        );
        insert new List<HAM_Chapter_Lookup__c>{ td.chapterFLOR, td.chapterCHI, td.chapterNYC };
 
        return td;
    }
 
    // =========================================================================
    // Test methods
    // =========================================================================
 
    /**
     * Happy-path: a Contact with three active HAM_Current_Chapter__c records
     * receives correctly formatted, alphabetically ordered chapter and region strings.
     *
     * Chapters expected : "Florida (Orlando), Illinois (Chicago), New York (New York City)"
     * Regions  expected : "Anytown; Chicago; NYC"  (semicolon-separated, order may vary)
     */
    @isTest
    static void testHappyPathThreeChapters() {
 
        TestData td = buildTestData();
 
        insert new List<HAM_Current_Chapter__c>{
            new HAM_Current_Chapter__c(
                Chapter__c     = td.chapterFLOR.Id,
                Constituent__c = td.contactA.Id,
                Is_Active__c   = true,
                Source__c      = 'Address Update'
            ),
            new HAM_Current_Chapter__c(
                Chapter__c     = td.chapterCHI.Id,
                Constituent__c = td.contactA.Id,
                Is_Active__c   = true,
                Source__c      = 'Address Update'
            ),
            new HAM_Current_Chapter__c(
                Chapter__c     = td.chapterNYC.Id,
                Constituent__c = td.contactA.Id,
                Is_Active__c   = true,
                Source__c      = 'Address Update'
            )
        };
 
        Test.startTest();
        UpdateCurrentChaptersUtility.updateCurrentChapterOnContact(
            new List<Id>{ td.contactA.Id }
        );
        Test.stopTest();
 
        Contact result = [
            SELECT HAM_Current_Chapters__c, HAM_Current_Regions__c
            FROM   Contact
            WHERE  Id = :td.contactA.Id
        ];
 
        Assert.areEqual(
            'Florida (Orlando), Illinois (Chicago), New York (New York City)',
            result.HAM_Current_Chapters__c,
            'Chapter names should be comma-space delimited and alphabetically sorted.'
        );
 
        // Region order is Set-based so we assert each value is present individually.
        Assert.isTrue(
            result.HAM_Current_Regions__c.contains('Anytown'),
            'Anytown region should be present.'
        );
        Assert.isTrue(
            result.HAM_Current_Regions__c.contains('Chicago'),
            'Chicago region should be present.'
        );
        Assert.isTrue(
            result.HAM_Current_Regions__c.contains('NYC'),
            'NYC region should be present.'
        );
    }
 
    /**
     * Inactive records excluded: when a HAM_Current_Chapter__c has Is_Active__c = false
     * it must not appear in either summary field on the Contact.
     *
     * Setup: two active (FLOR, CHI) + one inactive (NYC).
     * Chapters expected : "Florida (Orlando), Illinois (Chicago)"
     * Regions  expected : must NOT contain "NYC"
     */
    @isTest
    static void testInactiveJunctionRecordsExcluded() {
 
        TestData td = buildTestData();
 
        insert new List<HAM_Current_Chapter__c>{
            new HAM_Current_Chapter__c(
                Chapter__c     = td.chapterFLOR.Id,
                Constituent__c = td.contactA.Id,
                Is_Active__c   = true,
                Source__c      = 'Address Update'
            ),
            new HAM_Current_Chapter__c(
                Chapter__c     = td.chapterCHI.Id,
                Constituent__c = td.contactA.Id,
                Is_Active__c   = true,
                Source__c      = 'Address Update'
            ),
            new HAM_Current_Chapter__c(
                Chapter__c     = td.chapterNYC.Id,
                Constituent__c = td.contactA.Id,
                Is_Active__c   = false,   // <-- inactive; must be excluded
                Source__c      = 'Address Update'
            )
        };
 
        Test.startTest();
        UpdateCurrentChaptersUtility.updateCurrentChapterOnContact(
            new List<Id>{ td.contactA.Id }
        );
        Test.stopTest();
 
        Contact result = [
            SELECT HAM_Current_Chapters__c, HAM_Current_Regions__c
            FROM   Contact
            WHERE  Id = :td.contactA.Id
        ];
 
        Assert.areEqual(
            'Florida (Orlando), Illinois (Chicago)',
            result.HAM_Current_Chapters__c,
            'Inactive junction record chapter should not appear in the summary string.'
        );
        Assert.isFalse(
            result.HAM_Current_Regions__c != null && result.HAM_Current_Regions__c.contains('NYC'),
            'Inactive junction record region should not appear in the region string.'
        );
    }
 
    /**
     * Clear-on-no-records: a Contact passed in with zero active HAM_Current_Chapter__c
     * records should have both summary fields explicitly set to empty string.
     *
     * Pre-stamp the Contact with stale values first to confirm they are overwritten.
     */
    @isTest
    static void testContactWithNoJunctionRecordsCleared() {
 
        TestData td = buildTestData();
 
        // Pre-stamp stale values so we can confirm they get cleared.
        update new Contact(
            Id                      = td.contactA.Id,
            HAM_Current_Chapters__c = 'Florida (Orlando)',
            HAM_Current_Regions__c  = 'Anytown'
        );
 
        // No HAM_Current_Chapter__c records inserted for this Contact.
 
        Test.startTest();
        UpdateCurrentChaptersUtility.updateCurrentChapterOnContact(
            new List<Id>{ td.contactA.Id }
        );
        Test.stopTest();
 
        Contact result = [
            SELECT HAM_Current_Chapters__c, HAM_Current_Regions__c
            FROM   Contact
            WHERE  Id = :td.contactA.Id
        ];
 
        Assert.areEqual(
            null,
            result.HAM_Current_Chapters__c,
            'HAM_Current_Chapters__c should be cleared when no active junction records exist.'
        );
        Assert.areEqual(
            null,
            result.HAM_Current_Regions__c,
            'HAM_Current_Regions__c should be cleared when no active junction records exist.'
        );
    }
 
    /**
     * Region deduplication: two active junction records pointing to chapters in the
     * same region must produce only one occurrence of that region value in the
     * semicolon-separated string.
     *
     * Setup: FLOR (Anytown) + CHI (Chicago) — then a second chapter also mapped to
     * Anytown is inserted. Only one "Anytown" should appear.
     *
     * To simulate a second Anytown chapter without creating a new lookup record,
     * we insert a second HAM_Current_Chapter__c pointing to the same chapterFLOR.
     * Since the utility deduplicates chapter names in its loop, we instead create a
     * second distinct chapter lookup that shares the same HAM_Region__c value.
     */
    @isTest
    static void testRegionDeduplication() {
 
        TestData td = buildTestData();
 
        // A second Florida chapter — different name but same region as FLOR.
        HAM_Chapter_Lookup__c chapterFLOR2 = new HAM_Chapter_Lookup__c(
            Name                = 'Florida (Tampa)',
            HAM_Chapter_Code__c = 'FTAM',
            HAM_Chapter_Type__c = 'Domestic',
            HAM_Region__c       = 'Anytown'   // same region as chapterFLOR
        );
        insert chapterFLOR2;
 
        insert new List<HAM_Current_Chapter__c>{
            new HAM_Current_Chapter__c(
                Chapter__c     = td.chapterFLOR.Id,
                Constituent__c = td.contactA.Id,
                Is_Active__c   = true,
                Source__c      = 'Address Update'
            ),
            new HAM_Current_Chapter__c(
                Chapter__c     = chapterFLOR2.Id,
                Constituent__c = td.contactA.Id,
                Is_Active__c   = true,
                Source__c      = 'Address Update'
            )
        };
 
        Test.startTest();
        UpdateCurrentChaptersUtility.updateCurrentChapterOnContact(
            new List<Id>{ td.contactA.Id }
        );
        Test.stopTest();
 
        Contact result = [
            SELECT HAM_Current_Regions__c
            FROM   Contact
            WHERE  Id = :td.contactA.Id
        ];
 
        // Count occurrences of "Anytown" — should be exactly 1.
        Integer occurrences = result.HAM_Current_Regions__c.countMatches('Anytown');
        Assert.areEqual(
            1,
            occurrences,
            'Anytown region should appear only once even when two chapters share the same region.'
        );
    }
 
    /**
     * Alphabetical ordering: junction records inserted in reverse-alpha order must
     * still produce a chapter string sorted A→Z.
     *
     * Insert order: NYC → CHI → FLOR (reverse alpha).
     * Chapters expected: "Florida (Orlando), Illinois (Chicago), New York (New York City)"
     */
    @isTest
    static void testAlphabeticalChapterOrdering() {
 
        TestData td = buildTestData();
 
        // Insert deliberately in reverse-alpha order.
        insert new List<HAM_Current_Chapter__c>{
            new HAM_Current_Chapter__c(
                Chapter__c     = td.chapterNYC.Id,
                Constituent__c = td.contactA.Id,
                Is_Active__c   = true,
                Source__c      = 'Address Update'
            ),
            new HAM_Current_Chapter__c(
                Chapter__c     = td.chapterCHI.Id,
                Constituent__c = td.contactA.Id,
                Is_Active__c   = true,
                Source__c      = 'Address Update'
            ),
            new HAM_Current_Chapter__c(
                Chapter__c     = td.chapterFLOR.Id,
                Constituent__c = td.contactA.Id,
                Is_Active__c   = true,
                Source__c      = 'Address Update'
            )
        };
 
        Test.startTest();
        UpdateCurrentChaptersUtility.updateCurrentChapterOnContact(
            new List<Id>{ td.contactA.Id }
        );
        Test.stopTest();
 
        Contact result = [
            SELECT HAM_Current_Chapters__c
            FROM   Contact
            WHERE  Id = :td.contactA.Id
        ];
 
        Assert.areEqual(
            'Florida (Orlando), Illinois (Chicago), New York (New York City)',
            result.HAM_Current_Chapters__c,
            'Chapter names must appear in ascending alphabetical order regardless of insert order.'
        );
    }
 
    /**
     * Bulk / multi-contact: two Contacts processed in a single call each receive
     * their own independently-correct chapter and region strings.
     *
     * contactA → FLOR + CHI
     * contactB → NYC only
     */
    @isTest
    static void testBulkMultipleContacts() {
 
        TestData td = buildTestData();
 
        insert new List<HAM_Current_Chapter__c>{
            // contactA
            new HAM_Current_Chapter__c(
                Chapter__c     = td.chapterFLOR.Id,
                Constituent__c = td.contactA.Id,
                Is_Active__c   = true,
                Source__c      = 'Address Update'
            ),
            new HAM_Current_Chapter__c(
                Chapter__c     = td.chapterCHI.Id,
                Constituent__c = td.contactA.Id,
                Is_Active__c   = true,
                Source__c      = 'Address Update'
            ),
            // contactB
            new HAM_Current_Chapter__c(
                Chapter__c     = td.chapterNYC.Id,
                Constituent__c = td.contactB.Id,
                Is_Active__c   = true,
                Source__c      = 'Address Update'
            )
        };
 
        Test.startTest();
        UpdateCurrentChaptersUtility.updateCurrentChapterOnContact(
            new List<Id>{ td.contactA.Id, td.contactB.Id }
        );
        Test.stopTest();
 
        Map<Id, Contact> results = new Map<Id, Contact>([
            SELECT Id, HAM_Current_Chapters__c, HAM_Current_Regions__c
            FROM   Contact
            WHERE  Id IN (:td.contactA.Id, :td.contactB.Id)
        ]);
 
        Contact resultA = results.get(td.contactA.Id);
        Assert.areEqual(
            'Florida (Orlando), Illinois (Chicago)',
            resultA.HAM_Current_Chapters__c,
            'contactA should have only its own two chapters.'
        );
 
        Contact resultB = results.get(td.contactB.Id);
        Assert.areEqual(
            'New York (New York City)',
            resultB.HAM_Current_Chapters__c,
            'contactB should have only its own chapter.'
        );
        Assert.isTrue(
            resultB.HAM_Current_Regions__c.contains('NYC'),
            'contactB region should contain NYC.'
        );
    }
 
    /**
     * Empty-input guard: passing an empty Id list must return without throwing
     * an exception or performing any DML.
     */
    @isTest
    static void testEmptyListIsNoop() {
 
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            UpdateCurrentChaptersUtility.updateCurrentChapterOnContact(
                new List<Id>()
            );
        } catch (Exception ex) {
            exceptionThrown = true;
        }
        Test.stopTest();
 
        Assert.isFalse(exceptionThrown, 'An empty Id list must not throw an exception.');
    }
}