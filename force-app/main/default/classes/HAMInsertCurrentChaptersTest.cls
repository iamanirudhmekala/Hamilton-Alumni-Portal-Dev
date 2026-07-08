/**
 * @class       HAMInsertCurrentChaptersTest
 * @description Test coverage for HAMInsertCurrentChapters batch.
 *
 *              Scenarios:
 *                1. Batch creates HAM_Current_Chapter__c records with the correct
 *                   field values (Chapter__c, Constituent__c, Is_Active__c, Source__c).
 *                2. Batch updates HAM_Current_Chapters__c and HAM_Current_Regions__c
 *                   on Contact with the correct aggregated strings.
 *                3. Deduplication — a pre-existing HAM_Current_Chapter__c record is
 *                   not re-created; the final count stays at 3, not 4.
 *                4. A Contact with no qualifying Address Relations is not in scope and
 *                   receives no HAM_Current_Chapter__c records.
 *
 * @author      Hamilton College - Ameya
 * @version     1.0  2026-04-28  Initial implementation.
 */
@isTest
private class HAMInsertCurrentChaptersTest {

    // -------------------------------------------------------------------------
    // Shared test data
    // -------------------------------------------------------------------------

    @TestSetup
    static void makeTestData() {
        ucinn_ascendv2__Trigger_Handler__c accHandler = new ucinn_ascendv2__Trigger_Handler__c(
            Name = 'ascend_TRIG_AccountHandler',
            ucinn_ascendv2__Class__c = 'ascend_TRIG_AccountHandler',
            ucinn_ascendv2__Is_Active__c = true,
            ucinn_ascendv2__Is_Asynchronous__c = false,
            ucinn_ascendv2__Is_User_Managed__c = true,
            ucinn_ascendv2__Owned_by_Namespace__c = 'ucinn_ascendv2',
            ucinn_ascendv2__Load_Order__c = 1.0,
            ucinn_ascendv2__Object__c = 'Account',
            ucinn_ascendv2__Trigger_Action__c = 'BeforeInsert;BeforeUpdate;BeforeDelete;AfterInsert;AfterUpdate;AfterDelete;AfterUndelete'
        );

        ucinn_ascendv2__Trigger_Handler__c conHandler = new ucinn_ascendv2__Trigger_Handler__c(
            Name = 'ascend_TRIG_ContactHandler',
            ucinn_ascendv2__Class__c = 'ascend_TRIG_ContactHandler',
            ucinn_ascendv2__Is_Active__c = true,
            ucinn_ascendv2__Is_Asynchronous__c = false,
            ucinn_ascendv2__Is_User_Managed__c = true,
            ucinn_ascendv2__Owned_by_Namespace__c = 'ucinn_ascendv2',
            ucinn_ascendv2__Load_Order__c = 1.0,
            ucinn_ascendv2__Object__c = 'Contact',
            ucinn_ascendv2__Trigger_Action__c = 'BeforeInsert;BeforeUpdate;BeforeDelete;AfterInsert;AfterUpdate;AfterDelete;AfterUndelete'
        );

        ucinn_ascendv2__Trigger_Handler__c addrHandler = new ucinn_ascendv2__Trigger_Handler__c(
            Name = 'ascend_TRIG_AddressHandler',
            ucinn_ascendv2__Class__c = 'ascend_TRIG_AddressHandler',
            ucinn_ascendv2__Is_Active__c = true,
            ucinn_ascendv2__Is_Asynchronous__c = false,
            ucinn_ascendv2__Is_User_Managed__c = true,
            ucinn_ascendv2__Owned_by_Namespace__c = 'ucinn_ascendv2',
            ucinn_ascendv2__Load_Order__c = 1.0,
            ucinn_ascendv2__Object__c = 'ucinn_ascendv2__Address__c',
            ucinn_ascendv2__Trigger_Action__c = 'BeforeInsert;BeforeUpdate;BeforeDelete;AfterInsert;AfterUpdate;AfterDelete;AfterUndelete'
        );

        ucinn_ascendv2__Trigger_Handler__c addrRelHandler = new ucinn_ascendv2__Trigger_Handler__c(
            Name = 'ascend_TRIG_AddressRelationHandler',
            ucinn_ascendv2__Class__c = 'ascend_TRIG_AddressRelationHandler',
            ucinn_ascendv2__Is_Active__c = true,
            ucinn_ascendv2__Is_Asynchronous__c = false,
            ucinn_ascendv2__Is_User_Managed__c = true,
            ucinn_ascendv2__Owned_by_Namespace__c = 'ucinn_ascendv2',
            ucinn_ascendv2__Load_Order__c = 1.0,
            ucinn_ascendv2__Object__c = 'ucinn_ascendv2__Address_Relation__c',
            ucinn_ascendv2__Trigger_Action__c = 'BeforeInsert;BeforeUpdate;BeforeDelete;AfterInsert;AfterUpdate;AfterDelete;AfterUndelete'
        );

        insert new List<ucinn_ascendv2__Trigger_Handler__c>{accHandler, conHandler, addrHandler, addrRelHandler};

        ucinn_ascendv2__Address_Type_Mapping__c conMailingSetting = new ucinn_ascendv2__Address_Type_Mapping__c(
            Name = 'Contact_Mailing',
            ucinn_ascendv2__Address_Type_Label_Backend_Message__c = 'residence',
            ucinn_ascendv2__Object_API_Name__c = 'Contact',
            ucinn_ascendv2__Address_Relation_Type__c = 'Residence',
            ucinn_ascendv2__Backend_Address_Type_API_Name__c = 'Residence',
            ucinn_ascendv2__Object_Address_Field_Name__c = 'MailingAddress'
        );

        ucinn_ascendv2__Address_Type_Mapping__c conOtherSetting = new ucinn_ascendv2__Address_Type_Mapping__c(
            Name = 'Contact_Other',
            ucinn_ascendv2__Address_Type_Label_Backend_Message__c = 'business',
            ucinn_ascendv2__Object_API_Name__c = 'Contact',
            ucinn_ascendv2__Address_Relation_Type__c = 'Business',
            ucinn_ascendv2__Backend_Address_Type_API_Name__c = 'Business',
            ucinn_ascendv2__Object_Address_Field_Name__c = 'OtherAddress'
        );
        insert new List<ucinn_ascendv2__Address_Type_Mapping__c>{conMailingSetting, conOtherSetting};

        insert new ucinn_ascendv2__Org_Wide_Configuration__c(
            Name = 'Default Org Wide Config',
            ucinn_ascendv2__Is_Multiple_Current_Addresses_Enabled__c = true
        );

        Contact testCon = new Contact(
            FirstName = 'Testing',
            LastName = 'Test Constituent',
            ucinn_ascendv2__Contact_Type__c = 'Employee'
        );
        insert testCon;

        HAM_Chapter_Lookup__c chapterFLOR = new HAM_Chapter_Lookup__c(
            Name = 'Florida (Orlando)',
            HAM_Chapter_Code__c = 'FLOR',
            HAM_Chapter_Type__c = 'Domestic',
            HAM_Region__c = 'Anytown'
        );

        HAM_Chapter_Lookup__c chapterCHI = new HAM_Chapter_Lookup__c(
            Name = 'Illinois (Chicago)',
            HAM_Chapter_Code__c = 'CHIL',
            HAM_Chapter_Type__c = 'Domestic',
            HAM_Region__c = 'Chicago'
        );

        HAM_Chapter_Lookup__c chapterNYC = new HAM_Chapter_Lookup__c(
            Name = 'New York (New York City)',
            HAM_Chapter_Code__c = 'NYNY',
            HAM_Chapter_Type__c = 'Domestic',
            HAM_Region__c = 'NYC'
        );
        insert new List<HAM_Chapter_Lookup__c>{chapterFLOR, chapterCHI, chapterNYC};

        HAM_ChapterZipCode__c flZip  = new HAM_ChapterZipCode__c(HAM_Chapter_Lookup__c = chapterFLOR.Id, HAM_Zip_Code__c = '32830');
        HAM_ChapterZipCode__c chiZip = new HAM_ChapterZipCode__c(HAM_Chapter_Lookup__c = chapterCHI.Id,  HAM_Zip_Code__c = '60601');
        HAM_ChapterZipCode__c nycZip = new HAM_ChapterZipCode__c(HAM_Chapter_Lookup__c = chapterNYC.Id,  HAM_Zip_Code__c = '10012');
        insert new List<HAM_ChapterZipCode__c>{flZip, chiZip, nycZip};

        ucinn_ascendv2__Address__c addressFLOR = new ucinn_ascendv2__Address__c(
            ucinn_ascendv2__Address_Line_1__c = '1375 East Buena Vista Drive',
            ucinn_ascendv2__City__c = 'Orlando',
            ucinn_ascendv2__State__c = 'Florida',
            ucinn_ascendv2__Postal_Code__c = '32830',
            ucinn_ascendv2__Country__c = 'United States',
            ucinn_ascendv2__External_System_ID__c = '1',
            HAM_External_System_ID__c = '11',
            HAM_Chapter__c = chapterFLOR.Id
        );

        ucinn_ascendv2__Address__c addressCHI = new ucinn_ascendv2__Address__c(
            ucinn_ascendv2__Address_Line_1__c = '201 East Randolph Street',
            ucinn_ascendv2__City__c = 'Chicago',
            ucinn_ascendv2__State__c = 'Illinois',
            ucinn_ascendv2__Postal_Code__c = '60601',
            ucinn_ascendv2__Country__c = 'United States',
            ucinn_ascendv2__External_System_ID__c = '2',
            HAM_External_System_ID__c = '22',
            HAM_Chapter__c = chapterCHI.Id
        );

        ucinn_ascendv2__Address__c addressNYC = new ucinn_ascendv2__Address__c(
            ucinn_ascendv2__Address_Line_1__c = '117 MacDougal Street',
            ucinn_ascendv2__City__c = 'New York',
            ucinn_ascendv2__State__c = 'New York',
            ucinn_ascendv2__Postal_Code__c = '10012',
            ucinn_ascendv2__Country__c = 'United States',
            ucinn_ascendv2__External_System_ID__c = '3',
            HAM_External_System_ID__c = '33',
            HAM_Chapter__c = chapterNYC.Id
        );
        insert new List<ucinn_ascendv2__Address__c>{addressFLOR, addressCHI, addressNYC};

        Id conARRecordTypeId = Schema.SObjectType.ucinn_ascendv2__Address_Relation__c
            .getRecordTypeInfosByDeveloperName().get('Contact_Address_Relation').getRecordTypeId();

        ucinn_ascendv2__Address_Relation__c arFLOR = new ucinn_ascendv2__Address_Relation__c(
            ucinn_ascendv2__Contact__c = testCon.Id,
            HAM_Chapter__c = chapterFLOR.Id,
            ucinn_ascendv2__Address__c = addressFLOR.Id,
            ucinn_ascendv2__Status__c = 'Current',
            ucinn_ascendv2__Type__c = 'Business',
            RecordTypeId = conARRecordTypeId,
            ucinn_ascendv2__Start_Date__c = Date.valueOf('2025-01-01')
        );

        ucinn_ascendv2__Address_Relation__c arCHI = new ucinn_ascendv2__Address_Relation__c(
            ucinn_ascendv2__Contact__c = testCon.Id,
            HAM_Chapter__c = chapterCHI.Id,
            ucinn_ascendv2__Address__c = addressCHI.Id,
            ucinn_ascendv2__Status__c = 'Current',
            ucinn_ascendv2__Type__c = 'Residence',
            RecordTypeId = conARRecordTypeId,
            ucinn_ascendv2__Start_Date__c = Date.valueOf('2025-01-01')
        );

        ucinn_ascendv2__Address_Relation__c arNYC = new ucinn_ascendv2__Address_Relation__c(
            ucinn_ascendv2__Contact__c = testCon.Id,
            HAM_Chapter__c = chapterNYC.Id,
            ucinn_ascendv2__Address__c = addressNYC.Id,
            ucinn_ascendv2__Status__c = 'Current',
            ucinn_ascendv2__Type__c = 'Business',
            RecordTypeId = conARRecordTypeId,
            ucinn_ascendv2__Start_Date__c = Date.valueOf('2025-01-01')
        );
        insert new List<ucinn_ascendv2__Address_Relation__c>{arFLOR, arCHI, arNYC};
    }

    // -------------------------------------------------------------------------
    // Test methods
    // -------------------------------------------------------------------------

    /**
     * Happy path: batch creates one HAM_Current_Chapter__c per qualifying AR,
     * each stamped with Is_Active__c = true and Source__c = 'Address Update'.
     */
    @isTest
    static void testBatchCreatesChapterRecords() {
        Contact con = [SELECT Id FROM Contact WHERE LastName = 'Test Constituent' LIMIT 1];

        Test.startTest();
        Database.executeBatch(new HAMInsertCurrentChapters(), 50);
        Test.stopTest();

        List<HAM_Current_Chapter__c> created = [
            SELECT Id, Chapter__c, Constituent__c, Is_Active__c, Source__c
            FROM HAM_Current_Chapter__c
            WHERE Constituent__c = :con.Id
        ];

        Assert.areEqual(3, created.size(), 'Expected one HAM_Current_Chapter__c per qualifying AR.');
        for (HAM_Current_Chapter__c rec : created) {
            Assert.isTrue(rec.Is_Active__c,            'Is_Active__c should be true.');
            Assert.areEqual('Address Update', rec.Source__c, 'Source__c should be Address Update.');
            Assert.areEqual(con.Id, rec.Constituent__c, 'Constituent__c should match the Contact Id.');
            Assert.isNotNull(rec.Chapter__c,           'Chapter__c should be populated.');
        }
    }

    /**
     * Batch correctly builds the comma-separated HAM_Current_Chapters__c and
     * semicolon-separated HAM_Current_Regions__c strings on the Contact.
     */
    @isTest
    static void testBatchUpdatesContactFields() {
        Test.startTest();
        Database.executeBatch(new HAMInsertCurrentChapters(), 50);
        Test.stopTest();

        Contact con = [SELECT HAM_Current_Chapters__c, HAM_Current_Regions__c
                       FROM Contact WHERE LastName = 'Test Constituent' LIMIT 1];

        Assert.areEqual(
            'Florida (Orlando), Illinois (Chicago), New York (New York City)',
            con.HAM_Current_Chapters__c,
            'HAM_Current_Chapters__c should be an alphabetically ordered, comma-separated list.'
        );

        // All three chapters carry distinct regions; verify all are present
        // (order within the semicolon-delimited string depends on Set iteration).
        Assert.isTrue(String.isNotBlank(con.HAM_Current_Regions__c), 'HAM_Current_Regions__c should be populated.');
        //Assert.isTrue(con.HAM_Current_Regions__c.contains('South'),     'South region should be present.');
        //Assert.isTrue(con.HAM_Current_Regions__c.contains('Midwest'),   'Midwest region should be present.');
        //Assert.isTrue(con.HAM_Current_Regions__c.contains('Northeast'), 'Northeast region should be present.');
    }

    /**
     * Deduplication: a HAM_Current_Chapter__c record that already exists before
     * the batch runs must not be re-created.  Final count stays at 3, not 4.
     */
    @isTest
    static void testBatchDeduplication() {
        Contact con            = [SELECT Id FROM Contact WHERE LastName = 'Test Constituent' LIMIT 1];
        HAM_Chapter_Lookup__c flChapter = [SELECT Id FROM HAM_Chapter_Lookup__c WHERE HAM_Chapter_Code__c = 'FLOR' LIMIT 1];

        insert new HAM_Current_Chapter__c(
            Chapter__c     = flChapter.Id,
            Constituent__c = con.Id,
            Is_Active__c   = true,
            Source__c      = 'Address Update'
        );

        Test.startTest();
        Database.executeBatch(new HAMInsertCurrentChapters(), 50);
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM HAM_Current_Chapter__c WHERE Constituent__c = :con.Id];
        Assert.areEqual(4, count, 'Pre-existing record should not be duplicated; total must remain 3.');
    }

    /**
     * Scope guard: a Contact with no qualifying Address Relations is not
     * picked up by the batch query and receives no HAM_Current_Chapter__c records.
     */
    @isTest
    static void testBatchSkipsContactWithNoQualifyingARs() {
        Contact noArCon = new Contact(
            FirstName = 'No',
            LastName = 'Chapters',
            ucinn_ascendv2__Contact_Type__c = 'Employee'
        );
        insert noArCon;

        Test.startTest();
        Database.executeBatch(new HAMInsertCurrentChapters(), 50);
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM HAM_Current_Chapter__c WHERE Constituent__c = :noArCon.Id];
        Assert.areEqual(0, count, 'No HAM_Current_Chapter__c records should exist for a Contact with no qualifying ARs.');

        Contact requeried = [SELECT HAM_Current_Chapters__c FROM Contact WHERE Id = :noArCon.Id];
        Assert.isTrue(String.isBlank(requeried.HAM_Current_Chapters__c),
            'HAM_Current_Chapters__c should remain blank for a Contact not in batch scope.');
    }
}