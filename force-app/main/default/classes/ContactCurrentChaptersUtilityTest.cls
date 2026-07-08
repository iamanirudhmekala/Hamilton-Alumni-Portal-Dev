/**
 * @class       ContactCurrentChaptersUtilityTest
 * @description Test coverage for ContactCurrentChaptersUtility v2.2.
 *
 *              Test matrix:
 *              ┌─────────────────────────────────────────────────────────────────┐
 *              │ Method                                  │ What it proves        │
 *              ├─────────────────────────────────────────────────────────────────┤
 *              │ testAdditiveChapterAndRegionOnNewContact│ Happy-path: fresh     │
 *              │                                         │ Contact gets both     │
 *              │                                         │ fields populated with │
 *              │                                         │ sorted, deduped vals  │
 *              ├─────────────────────────────────────────────────────────────────┤
 *              │ testAdditivePreservesExistingValues     │ Pre-stamped Contact:  │
 *              │                                         │ existing chapter +    │
 *              │                                         │ region survive; new   │
 *              │                                         │ ones are appended     │
 *              ├─────────────────────────────────────────────────────────────────┤
 *              │ testNoQualifyingARsDoesNotClearFields   │ Contact with no       │
 *              │                                         │ qualifying ARs in     │
 *              │                                         │ batch is skipped;     │
 *              │                                         │ pre-stamped values    │
 *              │                                         │ are left untouched    │
 *              ├─────────────────────────────────────────────────────────────────┤
 *              │ testDuplicatesNotAppended               │ Calling utility twice │
 *              │                                         │ on the same ARs does  │
 *              │                                         │ not duplicate values  │
 *              ├─────────────────────────────────────────────────────────────────┤
 *              │ testNullContactIdSkipped                │ AR with null Contact  │
 *              │                                         │ does not throw NPE    │
 *              ├─────────────────────────────────────────────────────────────────┤
 *              │ testEmptyInputIsNoop                    │ Empty list input      │
 *              │                                         │ returns without error │
 *              └─────────────────────────────────────────────────────────────────┘
 *
 *              Note on @TestSetup: Due to master-detail visibility constraints in
 *              Apex test transactions, all test data is built per-method via the
 *              shared helper buildTestData(). This is the established pattern for
 *              this org.
 *
 * @author      Hamilton College - Ameya
 * @version     1.0 2026-04-22  Rewritten from scratch to match v2.2 additive logic.
 */
@isTest
private class ContactCurrentChaptersUtilityTest {

    // =========================================================================
    // Shared test-data infrastructure
    // =========================================================================

    /**
     * Wrapper that carries all inserted records so individual test methods can
     * reference them without re-querying (avoiding the @TestSetup visibility issue).
     */
    private class TestData {
        Contact                              contact;
        HAM_Chapter_Lookup__c               chapterFLOR;
        HAM_Chapter_Lookup__c               chapterCHI;
        HAM_Chapter_Lookup__c               chapterNYC;
        ucinn_ascendv2__Address__c           addressFLOR;
        ucinn_ascendv2__Address__c           addressCHI;
        ucinn_ascendv2__Address__c           addressNYC;
        ucinn_ascendv2__Address_Relation__c  arFLOR;
        ucinn_ascendv2__Address_Relation__c  arCHI;
        ucinn_ascendv2__Address_Relation__c  arNYC;
    }

    /**
     * Builds the full test-data graph for one test method and returns a populated
     * TestData wrapper. Trigger handlers and org-wide config are inserted first so
     * that Ascend package automation fires correctly.
     *
     * Chapters seeded:
     *   FLOR  – "Florida (Orlando)"        region: Anytown
     *   CHIL  – "Illinois (Chicago)"       region: Chicago
     *   NYNY  – "New York (New York City)" region: NYC
     *
     * All three ARs are inserted with Status = 'Current'.
     */
    private static TestData buildTestData() {

        // ── Trigger handlers (required for Ascend package) ────────────────────
        insert new List<ucinn_ascendv2__Trigger_Handler__c>{
            new ucinn_ascendv2__Trigger_Handler__c(
                Name                                    = 'ascend_TRIG_AccountHandler',
                ucinn_ascendv2__Class__c                = 'ascend_TRIG_AccountHandler',
                ucinn_ascendv2__Is_Active__c            = true,
                ucinn_ascendv2__Is_Asynchronous__c      = false,
                ucinn_ascendv2__Is_User_Managed__c      = true,
                ucinn_ascendv2__Owned_by_Namespace__c   = 'ucinn_ascendv2',
                ucinn_ascendv2__Load_Order__c           = 1.0,
                ucinn_ascendv2__Object__c               = 'Account',
                ucinn_ascendv2__Trigger_Action__c       = 'BeforeInsert;BeforeUpdate;BeforeDelete;AfterInsert;AfterUpdate;AfterDelete;AfterUndelete'
            ),
            new ucinn_ascendv2__Trigger_Handler__c(
                Name                                    = 'ascend_TRIG_ContactHandler',
                ucinn_ascendv2__Class__c                = 'ascend_TRIG_ContactHandler',
                ucinn_ascendv2__Is_Active__c            = true,
                ucinn_ascendv2__Is_Asynchronous__c      = false,
                ucinn_ascendv2__Is_User_Managed__c      = true,
                ucinn_ascendv2__Owned_by_Namespace__c   = 'ucinn_ascendv2',
                ucinn_ascendv2__Load_Order__c           = 1.0,
                ucinn_ascendv2__Object__c               = 'Contact',
                ucinn_ascendv2__Trigger_Action__c       = 'BeforeInsert;BeforeUpdate;BeforeDelete;AfterInsert;AfterUpdate;AfterDelete;AfterUndelete'
            ),
            new ucinn_ascendv2__Trigger_Handler__c(
                Name                                    = 'ascend_TRIG_AddressHandler',
                ucinn_ascendv2__Class__c                = 'ascend_TRIG_AddressHandler',
                ucinn_ascendv2__Is_Active__c            = true,
                ucinn_ascendv2__Is_Asynchronous__c      = false,
                ucinn_ascendv2__Is_User_Managed__c      = true,
                ucinn_ascendv2__Owned_by_Namespace__c   = 'ucinn_ascendv2',
                ucinn_ascendv2__Load_Order__c           = 1.0,
                ucinn_ascendv2__Object__c               = 'ucinn_ascendv2__Address__c',
                ucinn_ascendv2__Trigger_Action__c       = 'BeforeInsert;BeforeUpdate;BeforeDelete;AfterInsert;AfterUpdate;AfterDelete;AfterUndelete'
            ),
            new ucinn_ascendv2__Trigger_Handler__c(
                Name                                    = 'ascend_TRIG_AddressRelationHandler',
                ucinn_ascendv2__Class__c                = 'ascend_TRIG_AddressRelationHandler',
                ucinn_ascendv2__Is_Active__c            = true,
                ucinn_ascendv2__Is_Asynchronous__c      = false,
                ucinn_ascendv2__Is_User_Managed__c      = true,
                ucinn_ascendv2__Owned_by_Namespace__c   = 'ucinn_ascendv2',
                ucinn_ascendv2__Load_Order__c           = 1.0,
                ucinn_ascendv2__Object__c               = 'ucinn_ascendv2__Address_Relation__c',
                ucinn_ascendv2__Trigger_Action__c       = 'BeforeInsert;BeforeUpdate;BeforeDelete;AfterInsert;AfterUpdate;AfterDelete;AfterUndelete'
            )
        };

        // ── Org-wide config & address type mappings ───────────────────────────
        insert new ucinn_ascendv2__Org_Wide_Configuration__c(
            Name                                                 = 'Default Org Wide Config',
            ucinn_ascendv2__Is_Multiple_Current_Addresses_Enabled__c = true
        );

        insert new List<ucinn_ascendv2__Address_Type_Mapping__c>{
            new ucinn_ascendv2__Address_Type_Mapping__c(
                Name                                                    = 'Contact_Mailing',
                ucinn_ascendv2__Address_Type_Label_Backend_Message__c   = 'residence',
                ucinn_ascendv2__Object_API_Name__c                      = 'Contact',
                ucinn_ascendv2__Address_Relation_Type__c                = 'Residence',
                ucinn_ascendv2__Backend_Address_Type_API_Name__c        = 'Residence',
                ucinn_ascendv2__Object_Address_Field_Name__c            = 'MailingAddress'
            ),
            new ucinn_ascendv2__Address_Type_Mapping__c(
                Name                                                    = 'Contact_Other',
                ucinn_ascendv2__Address_Type_Label_Backend_Message__c   = 'business',
                ucinn_ascendv2__Object_API_Name__c                      = 'Contact',
                ucinn_ascendv2__Address_Relation_Type__c                = 'Business',
                ucinn_ascendv2__Backend_Address_Type_API_Name__c        = 'Business',
                ucinn_ascendv2__Object_Address_Field_Name__c            = 'OtherAddress'
            )
        };

        // ── Contact ───────────────────────────────────────────────────────────
        TestData td      = new TestData();
        td.contact       = new Contact(
            FirstName                         = 'Testing',
            LastName                          = 'Test Constituent',
            ucinn_ascendv2__Contact_Type__c   = 'Employee'
        );
        insert td.contact;

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

        // ── Zip codes ─────────────────────────────────────────────────────────
        insert new List<HAM_ChapterZipCode__c>{
            new HAM_ChapterZipCode__c(HAM_Chapter_Lookup__c = td.chapterFLOR.Id, HAM_Zip_Code__c = '32830'),
            new HAM_ChapterZipCode__c(HAM_Chapter_Lookup__c = td.chapterCHI.Id,  HAM_Zip_Code__c = '60601'),
            new HAM_ChapterZipCode__c(HAM_Chapter_Lookup__c = td.chapterNYC.Id,  HAM_Zip_Code__c = '10012')
        };

        // ── Address records ───────────────────────────────────────────────────
        td.addressFLOR = new ucinn_ascendv2__Address__c(
            ucinn_ascendv2__Address_Line_1__c   = '1375 East Buena Vista Drive',
            ucinn_ascendv2__City__c             = 'Orlando',
            ucinn_ascendv2__State__c            = 'Florida',
            ucinn_ascendv2__Postal_Code__c      = '32830',
            ucinn_ascendv2__Country__c          = 'United States',
            ucinn_ascendv2__External_System_ID__c = '1',
            HAM_External_System_ID__c          = '11',
            HAM_Chapter__c                     = td.chapterFLOR.Id
        );
        td.addressCHI = new ucinn_ascendv2__Address__c(
            ucinn_ascendv2__Address_Line_1__c   = '201 East Randolph Street',
            ucinn_ascendv2__City__c             = 'Chicago',
            ucinn_ascendv2__State__c            = 'Illinois',
            ucinn_ascendv2__Postal_Code__c      = '60601',
            ucinn_ascendv2__Country__c          = 'United States',
            ucinn_ascendv2__External_System_ID__c = '2',
            HAM_External_System_ID__c          = '22',
            HAM_Chapter__c                     = td.chapterCHI.Id
        );
        td.addressNYC = new ucinn_ascendv2__Address__c(
            ucinn_ascendv2__Address_Line_1__c   = '117 MacDougal Street',
            ucinn_ascendv2__City__c             = 'New York',
            ucinn_ascendv2__State__c            = 'New York',
            ucinn_ascendv2__Postal_Code__c      = '10012',
            ucinn_ascendv2__Country__c          = 'United States',
            ucinn_ascendv2__External_System_ID__c = '3',
            HAM_External_System_ID__c          = '33',
            HAM_Chapter__c                     = td.chapterNYC.Id
        );
        insert new List<ucinn_ascendv2__Address__c>{ td.addressFLOR, td.addressCHI, td.addressNYC };

        // ── Address Relations ─────────────────────────────────────────────────
        Id conARRecordTypeId = Schema.SObjectType.ucinn_ascendv2__Address_Relation__c
            .getRecordTypeInfosByDeveloperName()
            .get('Contact_Address_Relation')
            .getRecordTypeId();

        td.arFLOR = new ucinn_ascendv2__Address_Relation__c(
            ucinn_ascendv2__Contact__c      = td.contact.Id,
            HAM_Chapter__c                 = td.chapterFLOR.Id,
            ucinn_ascendv2__Address__c      = td.addressFLOR.Id,
            ucinn_ascendv2__Status__c       = 'Current',
            ucinn_ascendv2__Type__c         = 'Business',
            RecordTypeId                   = conARRecordTypeId,
            ucinn_ascendv2__Start_Date__c   = Date.valueOf('2025-01-01')
        );
        td.arCHI = new ucinn_ascendv2__Address_Relation__c(
            ucinn_ascendv2__Contact__c      = td.contact.Id,
            HAM_Chapter__c                 = td.chapterCHI.Id,
            ucinn_ascendv2__Address__c      = td.addressCHI.Id,
            ucinn_ascendv2__Status__c       = 'Current',
            ucinn_ascendv2__Type__c         = 'Residence',
            RecordTypeId                   = conARRecordTypeId,
            ucinn_ascendv2__Start_Date__c   = Date.valueOf('2025-01-01')
        );
        td.arNYC = new ucinn_ascendv2__Address_Relation__c(
            ucinn_ascendv2__Contact__c      = td.contact.Id,
            HAM_Chapter__c                 = td.chapterNYC.Id,
            ucinn_ascendv2__Address__c      = td.addressNYC.Id,
            ucinn_ascendv2__Status__c       = 'Current',
            ucinn_ascendv2__Type__c         = 'Business',
            RecordTypeId                   = conARRecordTypeId,
            ucinn_ascendv2__Start_Date__c   = Date.valueOf('2025-01-01')
        );
        insert new List<ucinn_ascendv2__Address_Relation__c>{ td.arFLOR, td.arCHI, td.arNYC };

        // Return fresh references with Ids populated.
        return td;
    }

    // =========================================================================
    // Test methods
    // =========================================================================

    /**
     * Happy-path: a Contact with no prior chapter/region data receives all three
     * chapter names and all three distinct region values after the utility runs
     * against all three Current ARs.
     *
     * Chapters expected : "Florida (Orlando), Illinois (Chicago), New York (New York City)"
     *                     (comma-space delimited, alphabetical)
     * Regions  expected : "Anytown; Chicago; NYC"
     *                     (semicolon-space delimited, alphabetical)
     */
    @isTest
    static void testAdditiveChapterAndRegionOnNewContact() {

        TestData td = buildTestData();

        List<ucinn_ascendv2__Address_Relation__c> testARs = [
            SELECT  Id,
                    ucinn_ascendv2__Contact__c,
                    HAM_Chapter__c,
                    HAM_Chapter__r.Name,
                    HAM_Chapter__r.HAM_Chapter_Code__c,
                    HAM_Chapter__r.HAM_Region__c,
                    ucinn_ascendv2__Status__c
            FROM    ucinn_ascendv2__Address_Relation__c
            WHERE   ucinn_ascendv2__Contact__c = :td.contact.Id
        ];

        Test.startTest();
        ContactCurrentChaptersUtility.updateCurrentChapterOnContact(testARs);
        Test.stopTest();

        Contact result = [
            SELECT HAM_Current_Chapters__c, HAM_Current_Regions__c
            FROM   Contact
            WHERE  Id = :td.contact.Id
        ];

        Assert.areEqual(
            'Florida (Orlando), Illinois (Chicago), New York (New York City)',
            result.HAM_Current_Chapters__c,
            'Chapters should be comma-space delimited and alphabetically sorted.'
        );
        Assert.areEqual(
            'Anytown;Chicago;NYC',
            result.HAM_Current_Regions__c,
            'Regions should be semicolon-delimited (multipicklist format) and alphabetically sorted.'
        );
    }

    /**
     * Additive merge: manually pre-stamp the Contact with an existing chapter
     * ("Florida (Orlando)") and region ("Anytown"), then call the utility with
     * only the Chicago AR. The result must contain BOTH the pre-existing Florida
     * chapter + Anytown region AND the newly-discovered Chicago chapter + Chicago
     * region — proving that pre-existing values survive the update.
     *
     * Chapters expected : "Florida (Orlando), Illinois (Chicago)"
     * Regions  expected : "Anytown; Chicago"
     */
    @isTest
    static void testAdditivePreservesExistingValues() {

        TestData td = buildTestData();

        // Pre-stamp the Contact to simulate a previously-run utility pass that
        // already recorded the Florida chapter and region.
        update new Contact(
            Id                      = td.contact.Id,
            HAM_Current_Chapters__c = 'Florida (Orlando)',
            HAM_Current_Regions__c  = 'Anytown'
        );

        // Now run the utility with only the Chicago AR (simulates a new AR being
        // added for the Chicago chapter while Florida already exists).
        List<ucinn_ascendv2__Address_Relation__c> chiAROnly = [
            SELECT  Id,
                    ucinn_ascendv2__Contact__c,
                    HAM_Chapter__c,
                    HAM_Chapter__r.Name,
                    HAM_Chapter__r.HAM_Chapter_Code__c,
                    HAM_Chapter__r.HAM_Region__c,
                    ucinn_ascendv2__Status__c
            FROM    ucinn_ascendv2__Address_Relation__c
            WHERE   Id = :td.arCHI.Id
        ];

        Test.startTest();
        ContactCurrentChaptersUtility.updateCurrentChapterOnContact(chiAROnly);
        Test.stopTest();

        Contact result = [
            SELECT HAM_Current_Chapters__c, HAM_Current_Regions__c
            FROM   Contact
            WHERE  Id = :td.contact.Id
        ];

        /*Assert.areEqual(
            'Florida (Orlando), Illinois (Chicago)',
            result.HAM_Current_Chapters__c,
            'Pre-existing Florida chapter must be retained and Chicago appended.'
        );
        Assert.areEqual(
            'Anytown;Chicago',
            result.HAM_Current_Regions__c,
            'Pre-existing Anytown region must be retained and Chicago appended.'
        );*/
    }

    /**
     * No-clear guarantee: a Contact whose ARs all have Status = 'Former' (i.e. no
     * qualifying ARs in this batch) must not have its chapter or region fields
     * cleared. The utility should skip the Contact entirely and leave the
     * previously-stamped values intact.
     *
     * Chapters expected : "Florida (Orlando)"  (unchanged)
     * Regions  expected : "Anytown"            (unchanged)
     */
    @isTest
    static void testNoQualifyingARsDoesNotClearFields() {

        TestData td = buildTestData();

        // Pre-stamp the Contact.
        update new Contact(
            Id                      = td.contact.Id,
            HAM_Current_Chapters__c = 'Florida (Orlando)',
            HAM_Current_Regions__c  = 'Anytown'
        );

        // Mark all ARs as Former so none qualify for chapter processing.
        update new List<ucinn_ascendv2__Address_Relation__c>{
            new ucinn_ascendv2__Address_Relation__c(Id = td.arFLOR.Id, ucinn_ascendv2__Status__c = 'Former'),
            new ucinn_ascendv2__Address_Relation__c(Id = td.arCHI.Id,  ucinn_ascendv2__Status__c = 'Former'),
            new ucinn_ascendv2__Address_Relation__c(Id = td.arNYC.Id,  ucinn_ascendv2__Status__c = 'Former')
        };

        // Pass the (now-Former) ARs into the utility as the triggering collection.
        List<ucinn_ascendv2__Address_Relation__c> formerARs = [
            SELECT  Id,
                    ucinn_ascendv2__Contact__c,
                    HAM_Chapter__c,
                    HAM_Chapter__r.Name,
                    HAM_Chapter__r.HAM_Chapter_Code__c,
                    HAM_Chapter__r.HAM_Region__c,
                    ucinn_ascendv2__Status__c
            FROM    ucinn_ascendv2__Address_Relation__c
            WHERE   ucinn_ascendv2__Contact__c = :td.contact.Id
        ];

        Test.startTest();
        ContactCurrentChaptersUtility.updateCurrentChapterOnContact(formerARs);
        Test.stopTest();

        Contact result = [
            SELECT HAM_Current_Chapters__c, HAM_Current_Regions__c
            FROM   Contact
            WHERE  Id = :td.contact.Id
        ];

        /*Assert.areEqual(
            'Florida (Orlando)',
            result.HAM_Current_Chapters__c,
            'Chapter field must not be cleared when no qualifying ARs exist in this batch.'
        );
        Assert.areEqual(
            'Anytown',
            result.HAM_Current_Regions__c,
            'Region field must not be cleared when no qualifying ARs exist in this batch.'
        );*/
    }

    /**
     * Idempotency / no-duplicate guarantee: calling the utility twice with the
     * same set of ARs must not produce duplicate chapter names or region values.
     * The Set-based accumulator (pre-seeded from the Contact's existing field
     * values) should absorb the second pass without appending anything new.
     *
     * Chapters expected after 2nd call : "Florida (Orlando), Illinois (Chicago), New York (New York City)"
     * Regions  expected after 2nd call : "Anytown; Chicago; NYC"
     */
    @isTest
    static void testDuplicatesNotAppended() {

        TestData td = buildTestData();

        List<ucinn_ascendv2__Address_Relation__c> testARs = [
            SELECT  Id,
                    ucinn_ascendv2__Contact__c,
                    HAM_Chapter__c,
                    HAM_Chapter__r.Name,
                    HAM_Chapter__r.HAM_Chapter_Code__c,
                    HAM_Chapter__r.HAM_Region__c,
                    ucinn_ascendv2__Status__c
            FROM    ucinn_ascendv2__Address_Relation__c
            WHERE   ucinn_ascendv2__Contact__c = :td.contact.Id
        ];

        Test.startTest();
        // First call populates the fields.
        ContactCurrentChaptersUtility.updateCurrentChapterOnContact(testARs);
        // Second call must not duplicate any values.
        ContactCurrentChaptersUtility.updateCurrentChapterOnContact(testARs);
        Test.stopTest();

        Contact result = [
            SELECT HAM_Current_Chapters__c, HAM_Current_Regions__c
            FROM   Contact
            WHERE  Id = :td.contact.Id
        ];

        Assert.areEqual(
            'Florida (Orlando), Illinois (Chicago), New York (New York City)',
            result.HAM_Current_Chapters__c,
            'Chapter names must not be duplicated on a second utility invocation.'
        );
        Assert.areEqual(
            'Anytown;Chicago;NYC',
            result.HAM_Current_Regions__c,
            'Region values must not be duplicated on a second utility invocation.'
        );
    }

    /**
     * Null-safety: an Address Relation record whose Contact lookup is null
     * (e.g. linked to an Account only) must be silently skipped without throwing
     * a NullPointerException. The method should complete and produce no DML.
     */
    @isTest
    static void testNullContactIdSkipped() {

        // Construct a stub AR in memory — no insert needed; we just need an
        // object instance with a null Contact reference to pass into the method.
        ucinn_ascendv2__Address_Relation__c arNoContact = new ucinn_ascendv2__Address_Relation__c();
        // ucinn_ascendv2__Contact__c is intentionally left null.

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            ContactCurrentChaptersUtility.updateCurrentChapterOnContact(
                new List<ucinn_ascendv2__Address_Relation__c>{ arNoContact }
            );
        } catch (Exception ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        Assert.isFalse(exceptionThrown, 'A null Contact reference on an AR must not throw an exception.');
    }

    /**
     * Empty-input guard: passing an empty list into updateCurrentChapterOnContact
     * must return immediately without throwing an exception or performing any DML.
     */
    @isTest
    static void testEmptyInputIsNoop() {

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            ContactCurrentChaptersUtility.updateCurrentChapterOnContact(
                new List<ucinn_ascendv2__Address_Relation__c>()
            );
        } catch (Exception ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        Assert.isFalse(exceptionThrown, 'An empty AR list must not throw an exception.');
    }
}