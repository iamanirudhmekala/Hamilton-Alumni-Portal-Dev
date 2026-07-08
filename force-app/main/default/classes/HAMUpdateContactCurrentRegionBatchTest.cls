/**
 * @class       HAMUpdateContactCurrentRegionBatchTest
 * @description Test class for HAMUpdateContactCurrentRegionBatch.
 *
 *              Conventions mirror ContactCurrentChaptersUtilityTest:
 *              - @TestSetup provisions all shared infrastructure: Trigger Handlers,
 *                Address Type Mappings, Org Wide Configuration, one Contact, three
 *                HAM_Chapter_Lookup__c records (FLOR/CHIL/NYNY), their zip codes,
 *                their Addresses, and three Address Relations (all Status = 'Current').
 *              - RecordTypeId on Address Relation is resolved via
 *                getRecordTypeInfosByDeveloperName().get('Contact_Address_Relation').
 *              - Assertions use Assert.areEqual() throughout.
 *              - Chapter codes and names match the org's existing lookup records so
 *                the region values are deterministic:
 *                    FLOR  Florida (Orlando)           HAM_Region__c = 'Anytown'
 *                    CHIL  Illinois (Chicago)          HAM_Region__c = 'Chicago'
 *                    NYNY  New York (New York City)    HAM_Region__c = 'NYC'
 *
 *              Test scenarios:
 *              1. testCurrentRegionsPositive  - All three ARs current → three
 *                                              HAM_Current_Chapter__c records created,
 *                                              HAM_Current_Chapters__c = 'Florida (Orlando),
 *                                              Illinois (Chicago), New York (New York City)',
 *                                              HAM_Current_Regions__c = 'Anytown;Chicago;NYC'.
 *              2. testCurrentRegionsNegative  - NYC AR set to 'Former' before batch runs
 *                                              → two HAM_Current_Chapter__c records created,
 *                                              HAM_Current_Chapters__c = 'Florida (Orlando),
 *                                              Illinois (Chicago)',
 *                                              HAM_Current_Regions__c = 'Anytown;Chicago'.
 *
 * @author      Hamilton College - Advancement Information Systems (AIS)
 * @version     1.0  2026-04-21  Initial implementation.
 * @version     2.0  2026-05-21  Added assertions for HAM_Current_Chapter__c creation
 *                               and HAM_Current_Chapters__c field.
 */
@IsTest
private class HAMUpdateContactCurrentRegionBatchTest {

    // -------------------------------------------------------------------------
    // Shared test data setup
    // -------------------------------------------------------------------------

    @TestSetup
    static void makeTestData() {

        // -- Trigger Handlers (mirrors ContactCurrentChaptersUtilityTest) -----
        ucinn_ascendv2__Trigger_Handler__c accHandler = new ucinn_ascendv2__Trigger_Handler__c(
            Name                                    = 'ascend_TRIG_AccountHandler',
            ucinn_ascendv2__Class__c                = 'ascend_TRIG_AccountHandler',
            ucinn_ascendv2__Is_Active__c            = true,
            ucinn_ascendv2__Is_Asynchronous__c      = false,
            ucinn_ascendv2__Is_User_Managed__c      = true,
            ucinn_ascendv2__Owned_by_Namespace__c   = 'ucinn_ascendv2',
            ucinn_ascendv2__Load_Order__c           = 1.0,
            ucinn_ascendv2__Object__c               = 'Account',
            ucinn_ascendv2__Trigger_Action__c       = 'BeforeInsert;BeforeUpdate;BeforeDelete;AfterInsert;AfterUpdate;AfterDelete;AfterUndelete'
        );

        ucinn_ascendv2__Trigger_Handler__c conHandler = new ucinn_ascendv2__Trigger_Handler__c(
            Name                                    = 'ascend_TRIG_ContactHandler',
            ucinn_ascendv2__Class__c                = 'ascend_TRIG_ContactHandler',
            ucinn_ascendv2__Is_Active__c            = true,
            ucinn_ascendv2__Is_Asynchronous__c      = false,
            ucinn_ascendv2__Is_User_Managed__c      = true,
            ucinn_ascendv2__Owned_by_Namespace__c   = 'ucinn_ascendv2',
            ucinn_ascendv2__Load_Order__c           = 1.0,
            ucinn_ascendv2__Object__c               = 'Contact',
            ucinn_ascendv2__Trigger_Action__c       = 'BeforeInsert;BeforeUpdate;BeforeDelete;AfterInsert;AfterUpdate;AfterDelete;AfterUndelete'
        );

        ucinn_ascendv2__Trigger_Handler__c addrHandler = new ucinn_ascendv2__Trigger_Handler__c(
            Name                                    = 'ascend_TRIG_AddressHandler',
            ucinn_ascendv2__Class__c                = 'ascend_TRIG_AddressHandler',
            ucinn_ascendv2__Is_Active__c            = true,
            ucinn_ascendv2__Is_Asynchronous__c      = false,
            ucinn_ascendv2__Is_User_Managed__c      = true,
            ucinn_ascendv2__Owned_by_Namespace__c   = 'ucinn_ascendv2',
            ucinn_ascendv2__Load_Order__c           = 1.0,
            ucinn_ascendv2__Object__c               = 'ucinn_ascendv2__Address__c',
            ucinn_ascendv2__Trigger_Action__c       = 'BeforeInsert;BeforeUpdate;BeforeDelete;AfterInsert;AfterUpdate;AfterDelete;AfterUndelete'
        );

        ucinn_ascendv2__Trigger_Handler__c addrRelHandler = new ucinn_ascendv2__Trigger_Handler__c(
            Name                                    = 'ascend_TRIG_AddressRelationHandler',
            ucinn_ascendv2__Class__c                = 'ascend_TRIG_AddressRelationHandler',
            ucinn_ascendv2__Is_Active__c            = true,
            ucinn_ascendv2__Is_Asynchronous__c      = false,
            ucinn_ascendv2__Is_User_Managed__c      = true,
            ucinn_ascendv2__Owned_by_Namespace__c   = 'ucinn_ascendv2',
            ucinn_ascendv2__Load_Order__c           = 1.0,
            ucinn_ascendv2__Object__c               = 'ucinn_ascendv2__Address_Relation__c',
            ucinn_ascendv2__Trigger_Action__c       = 'BeforeInsert;BeforeUpdate;BeforeDelete;AfterInsert;AfterUpdate;AfterDelete;AfterUndelete'
        );

        insert new List<ucinn_ascendv2__Trigger_Handler__c>{
            accHandler, conHandler, addrHandler, addrRelHandler
        };

        // -- Address Type Mappings --------------------------------------------
        ucinn_ascendv2__Address_Type_Mapping__c conMailingSetting = new ucinn_ascendv2__Address_Type_Mapping__c(
            Name                                                    = 'Contact_Mailing',
            ucinn_ascendv2__Address_Type_Label_Backend_Message__c   = 'residence',
            ucinn_ascendv2__Object_API_Name__c                      = 'Contact',
            ucinn_ascendv2__Address_Relation_Type__c                = 'Residence',
            ucinn_ascendv2__Backend_Address_Type_API_Name__c        = 'Residence',
            ucinn_ascendv2__Object_Address_Field_Name__c            = 'MailingAddress'
        );

        ucinn_ascendv2__Address_Type_Mapping__c conOtherSetting = new ucinn_ascendv2__Address_Type_Mapping__c(
            Name                                                    = 'Contact_Other',
            ucinn_ascendv2__Address_Type_Label_Backend_Message__c   = 'business',
            ucinn_ascendv2__Object_API_Name__c                      = 'Contact',
            ucinn_ascendv2__Address_Relation_Type__c                = 'Business',
            ucinn_ascendv2__Backend_Address_Type_API_Name__c        = 'Business',
            ucinn_ascendv2__Object_Address_Field_Name__c            = 'OtherAddress'
        );

        insert new List<ucinn_ascendv2__Address_Type_Mapping__c>{
            conMailingSetting, conOtherSetting
        };

        // -- Org Wide Configuration -------------------------------------------
        insert new ucinn_ascendv2__Org_Wide_Configuration__c(
            Name                                                    = 'Default Org Wide Config',
            ucinn_ascendv2__Is_Multiple_Current_Addresses_Enabled__c = true
        );

        // -- Contact ----------------------------------------------------------
        Contact testCon = new Contact(
            FirstName                       = 'Testing',
            LastName                        = 'Test Constituent',
            ucinn_ascendv2__Contact_Type__c = 'Employee'
        );
        insert testCon;

        // -- Chapter Lookups --------------------------------------------------
        //    Same codes/names as ContactCurrentChaptersUtilityTest.
        //    Regions sourced from the org's existing records:
        //        FLOR → 'Anytown'   CHIL → 'Chicago'   NYNY → 'NYC'
        HAM_Chapter_Lookup__c chapterFLOR = new HAM_Chapter_Lookup__c(
            Name                = 'Florida (Orlando)',
            HAM_Chapter_Code__c = 'FLOR',
            HAM_Chapter_Type__c = 'Domestic',
            HAM_Region__c = 'Anytown'
        );

        HAM_Chapter_Lookup__c chapterCHI = new HAM_Chapter_Lookup__c(
            Name                = 'Illinois (Chicago)',
            HAM_Chapter_Code__c = 'CHIL',
            HAM_Chapter_Type__c = 'Domestic',
            HAM_Region__c = 'Chicago'
        );

        HAM_Chapter_Lookup__c chapterNYC = new HAM_Chapter_Lookup__c(
            Name                = 'New York (New York City)',
            HAM_Chapter_Code__c = 'NYNY',
            HAM_Chapter_Type__c = 'Domestic',
            HAM_Region__c = 'NYC'
        );

        insert new List<HAM_Chapter_Lookup__c>{ chapterFLOR, chapterCHI, chapterNYC };

        // -- Chapter Zip Codes ------------------------------------------------
        HAM_ChapterZipCode__c flZip = new HAM_ChapterZipCode__c(
            HAM_Chapter_Lookup__c = chapterFLOR.Id,
            HAM_Zip_Code__c       = '32830'
        );

        HAM_ChapterZipCode__c chiZip = new HAM_ChapterZipCode__c(
            HAM_Chapter_Lookup__c = chapterCHI.Id,
            HAM_Zip_Code__c       = '60601'
        );

        HAM_ChapterZipCode__c nycZip = new HAM_ChapterZipCode__c(
            HAM_Chapter_Lookup__c = chapterNYC.Id,
            HAM_Zip_Code__c       = '10012'
        );

        insert new List<HAM_ChapterZipCode__c>{ flZip, chiZip, nycZip };

        // -- Addresses --------------------------------------------------------
        ucinn_ascendv2__Address__c addressFLOR = new ucinn_ascendv2__Address__c(
            ucinn_ascendv2__Address_Line_1__c   = '1375 East Buena Vista Drive',
            ucinn_ascendv2__City__c             = 'Orlando',
            ucinn_ascendv2__State__c            = 'Florida',
            ucinn_ascendv2__Postal_Code__c      = '32830',
            ucinn_ascendv2__Country__c          = 'United States',
            ucinn_ascendv2__External_System_ID__c = '1',
            HAM_External_System_ID__c           = '11',
            HAM_Chapter__c                      = chapterFLOR.Id
        );

        ucinn_ascendv2__Address__c addressCHI = new ucinn_ascendv2__Address__c(
            ucinn_ascendv2__Address_Line_1__c   = '201 East Randolph Street',
            ucinn_ascendv2__City__c             = 'Chicago',
            ucinn_ascendv2__State__c            = 'Illinois',
            ucinn_ascendv2__Postal_Code__c      = '60601',
            ucinn_ascendv2__Country__c          = 'United States',
            ucinn_ascendv2__External_System_ID__c = '2',
            HAM_External_System_ID__c           = '22',
            HAM_Chapter__c                      = chapterCHI.Id
        );

        ucinn_ascendv2__Address__c addressNYC = new ucinn_ascendv2__Address__c(
            ucinn_ascendv2__Address_Line_1__c   = '117 MacDougal Street',
            ucinn_ascendv2__City__c             = 'New York',
            ucinn_ascendv2__State__c            = 'New York',
            ucinn_ascendv2__Postal_Code__c      = '10012',
            ucinn_ascendv2__Country__c          = 'United States',
            ucinn_ascendv2__External_System_ID__c = '3',
            HAM_External_System_ID__c           = '33',
            HAM_Chapter__c                      = chapterNYC.Id
        );

        insert new List<ucinn_ascendv2__Address__c>{ addressFLOR, addressCHI, addressNYC };

        // -- Address Relations ------------------------------------------------
        Id conARRecordTypeId = Schema.SObjectType.ucinn_ascendv2__Address_Relation__c
            .getRecordTypeInfosByDeveloperName()
            .get('Contact_Address_Relation')
            .getRecordTypeId();

        ucinn_ascendv2__Address_Relation__c arFLOR = new ucinn_ascendv2__Address_Relation__c(
            ucinn_ascendv2__Contact__c      = testCon.Id,
            HAM_Chapter__c                  = chapterFLOR.Id,
            ucinn_ascendv2__Address__c      = addressFLOR.Id,
            ucinn_ascendv2__Status__c       = 'Current',
            ucinn_ascendv2__Type__c         = 'Business',
            RecordTypeId                    = conARRecordTypeId,
            ucinn_ascendv2__Start_Date__c   = Date.valueOf('2025-01-01')
        );

        ucinn_ascendv2__Address_Relation__c arCHI = new ucinn_ascendv2__Address_Relation__c(
            ucinn_ascendv2__Contact__c      = testCon.Id,
            HAM_Chapter__c                  = chapterCHI.Id,
            ucinn_ascendv2__Address__c      = addressCHI.Id,
            ucinn_ascendv2__Status__c       = 'Current',
            ucinn_ascendv2__Type__c         = 'Residence',
            RecordTypeId                    = conARRecordTypeId,
            ucinn_ascendv2__Start_Date__c   = Date.valueOf('2025-01-01')
        );

        ucinn_ascendv2__Address_Relation__c arNYC = new ucinn_ascendv2__Address_Relation__c(
            ucinn_ascendv2__Contact__c      = testCon.Id,
            HAM_Chapter__c                  = chapterNYC.Id,
            ucinn_ascendv2__Address__c      = addressNYC.Id,
            ucinn_ascendv2__Status__c       = 'Current',
            ucinn_ascendv2__Type__c         = 'Business',
            RecordTypeId                    = conARRecordTypeId,
            ucinn_ascendv2__Start_Date__c   = Date.valueOf('2025-01-01')
        );

        insert new List<ucinn_ascendv2__Address_Relation__c>{ arFLOR, arCHI, arNYC };
    }

    // -------------------------------------------------------------------------
    // Test methods
    // -------------------------------------------------------------------------

    /**
     * Scenario 1 – Positive: all three ARs current.
     *
     * Run batch with FLOR, CHIL, NYNY all Status = 'Current'.
     * Expected:
     *   - Three active HAM_Current_Chapter__c records created.
     *   - HAM_Current_Chapters__c = 'Florida (Orlando), Illinois (Chicago), New York (New York City)'.
     *   - HAM_Current_Regions__c  = 'Anytown;Chicago;NYC' (sorted).
     */
    @IsTest
    static void testCurrentRegionsPositive() {

        Test.startTest();
        Database.executeBatch(new HAMUpdateContactCurrentRegionBatch(), 200);
        Test.stopTest();

        Contact updatedContact = [
            SELECT Id, HAM_Current_Chapters__c, HAM_Current_Regions__c
            FROM Contact
        ];

        List<HAM_Current_Chapter__c> chapterRecords = [
            SELECT Id
            FROM HAM_Current_Chapter__c
            WHERE Constituent__c = :updatedContact.Id
              AND Is_Active__c = true
        ];

        Assert.areEqual(
            3,
            chapterRecords.size(),
            'Three active HAM_Current_Chapter__c records should be created for three current ARs.'
        );
        Assert.areEqual(
            'Florida (Orlando), Illinois (Chicago), New York (New York City)',
            updatedContact.HAM_Current_Chapters__c,
            'HAM_Current_Chapters__c should contain all three chapter names in alphabetical order.'
        );
        Assert.areEqual(
            'Anytown;Chicago;NYC',
            updatedContact.HAM_Current_Regions__c,
            'All three current ARs should produce a sorted semicolon-delimited region string.'
        );
    }

    /**
     * Scenario 2 – Negative: NYC AR already Former before batch runs.
     *
     * Set the NYC AR to 'Former', then run the batch once.
     * Expected:
     *   - Two active HAM_Current_Chapter__c records created (FLOR + CHIL only).
     *   - HAM_Current_Chapters__c = 'Florida (Orlando), Illinois (Chicago)'.
     *   - HAM_Current_Regions__c  = 'Anytown;Chicago' (NYC excluded).
     */
    @IsTest
    static void testCurrentRegionsNegative() {

        ucinn_ascendv2__Address_Relation__c nycAR = [
            SELECT Id, ucinn_ascendv2__Status__c
            FROM   ucinn_ascendv2__Address_Relation__c
            WHERE  HAM_Chapter__r.Name = 'New York (New York City)'
        ];
        nycAR.ucinn_ascendv2__Status__c = 'Former';
        update nycAR;

        Test.startTest();
        Database.executeBatch(new HAMUpdateContactCurrentRegionBatch(), 200);
        Test.stopTest();

        Contact updatedContact = [
            SELECT Id, HAM_Current_Chapters__c, HAM_Current_Regions__c
            FROM Contact
        ];

        List<HAM_Current_Chapter__c> chapterRecords = [
            SELECT Id
            FROM HAM_Current_Chapter__c
            WHERE Constituent__c = :updatedContact.Id
              AND Is_Active__c = true
        ];

        Assert.areEqual(
            2,
            chapterRecords.size(),
            'Only two active HAM_Current_Chapter__c records should exist when NYC AR is Former.'
        );
        Assert.areEqual(
            'Florida (Orlando), Illinois (Chicago)',
            updatedContact.HAM_Current_Chapters__c,
            'HAM_Current_Chapters__c should exclude the Former NYC chapter.'
        );
        Assert.areEqual(
            'Anytown;Chicago',
            updatedContact.HAM_Current_Regions__c,
            'An AR with Status = Former should be excluded; only the two remaining regions should appear.'
        );
    }
}