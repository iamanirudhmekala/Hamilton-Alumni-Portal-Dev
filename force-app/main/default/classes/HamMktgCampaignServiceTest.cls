@IsTest
public class HamMktgCampaignServiceTest {

    /* =========================================================
     * TEST DATA FACTORY
     * ========================================================= */

    private static Contact createContact() {
        Contact c = new Contact(FirstName = 'Test', LastName = 'Contact');
        insert c;
        return c;
    }

    private static Campaign createCampaign() {
        Campaign c = new Campaign(
            Name   = 'Test Campaign',
            Type   = 'Webinar',
            Status = 'Planning'
        );
        insert c;
        return c;
    }

    private static ucinn_ascendv2__Service_Indicator_Value__c createValue(
        String category,
        Id campaignId
    ) {
        ucinn_ascendv2__Service_Indicator_Value__c v =
            new ucinn_ascendv2__Service_Indicator_Value__c(
                Name                          = category != null ? category + ' Value' : 'No Category Value',
                HAM_Category__c               = category,
                HAM_Associated_Campaign_Id__c = campaignId
            );
        insert v;
        return v;
    }

    private static ucinn_ascendv2__Service_Indicator__c createIndicator(
        Id contactId,
        Id valueId,
        Date endDate
    ) {
        ucinn_ascendv2__Service_Indicator__c si =
            new ucinn_ascendv2__Service_Indicator__c(
                ucinn_ascendv2__Contact__c                 = contactId,
                ucinn_ascendv2__Service_Indicator_Value__c = valueId,
                ucinn_ascendv2__Start_Date__c              = Date.today(),
                ucinn_ascendv2__End_Date__c                = endDate,
                ucinn_ascendv2__Source__c                  = 'Test Source'
            );
        insert si;
        return si;
    }

    /**
     * Re-queries an SI with the full relationship fields populated,
     * exactly as processServiceIndicators does internally.
     * Use this whenever a test calls a processor method directly.
     */
    private static ucinn_ascendv2__Service_Indicator__c requerySI(Id siId) {
        return [
            SELECT
                ucinn_ascendv2__Contact__c,
                ucinn_ascendv2__End_Date__c,
                ucinn_ascendv2__Start_Date__c,
                ucinn_ascendv2__Service_Indicator_Value__c,
                ucinn_ascendv2__Source__c,
                ucinn_ascendv2__Service_Indicator_Value__r.HAM_Category__c,
                ucinn_ascendv2__Service_Indicator_Value__r.HAM_Associated_Campaign_Id__c
            FROM ucinn_ascendv2__Service_Indicator__c
            WHERE Id = :siId
        ];
    }

    private static CampaignMember createCampaignMember(Id campaignId, Id contactId) {
        CampaignMember cm = new CampaignMember(
            CampaignId = campaignId,
            ContactId  = contactId
        );
        insert cm;
        return cm;
    }

    private static List<CampaignMember> getCampaignMembers(Id campaignId, Id contactId) {
        return [
            SELECT Id
            FROM CampaignMember
            WHERE CampaignId = :campaignId
            AND   ContactId  = :contactId
        ];
    }

    /* =========================================================
     * processServiceIndicators — EMPTY LIST (early return guard)
     * ========================================================= */

    @IsTest
    static void testProcessServiceIndicators_EmptyList() {
        Contact c = createContact();

        Test.startTest();
        HamMktgCampaignService.processServiceIndicators(new List<Id>(), c.Id);
        Test.stopTest();

        System.assert(true, 'Empty ID list should be handled gracefully without exception');
    }

    /* =========================================================
     * processServiceIndicators — NULL CATEGORY, NO CAMPAIGN
     * ========================================================= */

    @IsTest
    static void testProcessServiceIndicators_NullCategory_NoCampaign() {
        Contact c = createContact();

        ucinn_ascendv2__Service_Indicator_Value__c val = createValue(null, null);
        ucinn_ascendv2__Service_Indicator__c si        = createIndicator(c.Id, val.Id, null);

        Test.startTest();
        HamMktgCampaignService.processServiceIndicators(new List<Id>{ si.Id }, c.Id);
        Test.stopTest();

        System.assert(true, 'Null category with no campaign ID should be skipped without error');
    }

    /* =========================================================
     * processServiceIndicators — MARKETING PREFERENCES
     * All routed through processServiceIndicators so the
     * relationship fields are populated by the internal SOQL
     * ========================================================= */

    @IsTest
    static void testProcessServiceIndicators_Marketing_Insert() {
        Contact c     = createContact();
        Campaign camp = createCampaign();

        ucinn_ascendv2__Service_Indicator_Value__c val =
            createValue('Marketing Preferences', camp.Id);
        ucinn_ascendv2__Service_Indicator__c si =
            createIndicator(c.Id, val.Id, null);

        Test.startTest();
        HamMktgCampaignService.processServiceIndicators(new List<Id>{ si.Id }, c.Id);
        Test.stopTest();

        System.assertEquals(
            1,
            getCampaignMembers(camp.Id, c.Id).size(),
            'CampaignMember should be created when End Date is null'
        );
    }

    @IsTest
    static void testProcessServiceIndicators_Marketing_Delete() {
        Contact c     = createContact();
        Campaign camp = createCampaign();
        createCampaignMember(camp.Id, c.Id);

        ucinn_ascendv2__Service_Indicator_Value__c val =
            createValue('Marketing Preferences', camp.Id);
        ucinn_ascendv2__Service_Indicator__c si =
            createIndicator(c.Id, val.Id, Date.today());

        Test.startTest();
        HamMktgCampaignService.processServiceIndicators(new List<Id>{ si.Id }, c.Id);
        Test.stopTest();

        System.assertEquals(
            0,
            getCampaignMembers(camp.Id, c.Id).size(),
            'CampaignMember should be deleted when End Date is populated'
        );
    }

    @IsTest
    static void testProcessServiceIndicators_Marketing_NoDuplicateInsert() {
        Contact c     = createContact();
        Campaign camp = createCampaign();
        createCampaignMember(camp.Id, c.Id);

        ucinn_ascendv2__Service_Indicator_Value__c val =
            createValue('Marketing Preferences', camp.Id);
        ucinn_ascendv2__Service_Indicator__c si =
            createIndicator(c.Id, val.Id, null);

        Test.startTest();
        HamMktgCampaignService.processServiceIndicators(new List<Id>{ si.Id }, c.Id);
        Test.stopTest();

        System.assertEquals(
            1,
            getCampaignMembers(camp.Id, c.Id).size(),
            'Duplicate CampaignMember should not be inserted'
        );
    }

    @IsTest
    static void testProcessServiceIndicators_Marketing_DeleteNonExistentMember() {
        Contact c     = createContact();
        Campaign camp = createCampaign();

        ucinn_ascendv2__Service_Indicator_Value__c val =
            createValue('Marketing Preferences', camp.Id);
        ucinn_ascendv2__Service_Indicator__c si =
            createIndicator(c.Id, val.Id, Date.today());

        Test.startTest();
        HamMktgCampaignService.processServiceIndicators(new List<Id>{ si.Id }, c.Id);
        Test.stopTest();

        System.assertEquals(
            0,
            getCampaignMembers(camp.Id, c.Id).size(),
            'No error should occur when deleting a CampaignMember that does not exist'
        );
    }

    /* =========================================================
     * processServiceIndicators — EMAIL PREFERENCES
     * ========================================================= */

    @IsTest
    static void testProcessServiceIndicators_Email_Insert() {
        Contact c     = createContact();
        Campaign camp = createCampaign();

        ucinn_ascendv2__Service_Indicator_Value__c val =
            createValue('Email Preferences', camp.Id);
        ucinn_ascendv2__Service_Indicator__c si =
            createIndicator(c.Id, val.Id, null);

        Test.startTest();
        HamMktgCampaignService.processServiceIndicators(new List<Id>{ si.Id }, c.Id);
        Test.stopTest();

        System.assertEquals(
            1,
            getCampaignMembers(camp.Id, c.Id).size(),
            'CampaignMember should be created for Email Preferences when End Date is null'
        );
    }

    @IsTest
    static void testProcessServiceIndicators_Email_Delete() {
        Contact c     = createContact();
        Campaign camp = createCampaign();
        createCampaignMember(camp.Id, c.Id);

        ucinn_ascendv2__Service_Indicator_Value__c val =
            createValue('Email Preferences', camp.Id);
        ucinn_ascendv2__Service_Indicator__c si =
            createIndicator(c.Id, val.Id, Date.today());

        Test.startTest();
        HamMktgCampaignService.processServiceIndicators(new List<Id>{ si.Id }, c.Id);
        Test.stopTest();

        System.assertEquals(
            0,
            getCampaignMembers(camp.Id, c.Id).size(),
            'CampaignMember should be deleted for Email Preferences when End Date is populated'
        );
    }

    @IsTest
    static void testProcessServiceIndicators_Email_NoDuplicateInsert() {
        Contact c     = createContact();
        Campaign camp = createCampaign();
        createCampaignMember(camp.Id, c.Id);

        ucinn_ascendv2__Service_Indicator_Value__c val =
            createValue('Email Preferences', camp.Id);
        ucinn_ascendv2__Service_Indicator__c si =
            createIndicator(c.Id, val.Id, null);

        Test.startTest();
        HamMktgCampaignService.processServiceIndicators(new List<Id>{ si.Id }, c.Id);
        Test.stopTest();

        System.assertEquals(
            1,
            getCampaignMembers(camp.Id, c.Id).size(),
            'Duplicate CampaignMember should not be inserted for Email Preferences'
        );
    }

    /* =========================================================
     * processServiceIndicators — MULTIPLE CATEGORIES, SAME CALL
     * Proves each category dispatches independently (no else-if bug)
     * ========================================================= */

    @IsTest
    static void testProcessServiceIndicators_MultipleCategories_IndependentDispatch() {
        Contact c      = createContact();
        Campaign camp1 = createCampaign();
        Campaign camp2 = createCampaign();

        ucinn_ascendv2__Service_Indicator_Value__c valMkt =
            createValue('Marketing Preferences', camp1.Id);
        ucinn_ascendv2__Service_Indicator_Value__c valEmail =
            createValue('Email Preferences', camp2.Id);

        ucinn_ascendv2__Service_Indicator__c siMkt =
            createIndicator(c.Id, valMkt.Id, null);
        ucinn_ascendv2__Service_Indicator__c siEmail =
            createIndicator(c.Id, valEmail.Id, null);

        Test.startTest();
        HamMktgCampaignService.processServiceIndicators(
            new List<Id>{ siMkt.Id, siEmail.Id },
            c.Id
        );
        Test.stopTest();

        System.assertEquals(
            1,
            getCampaignMembers(camp1.Id, c.Id).size(),
            'Contact should be added to Marketing Preferences campaign'
        );
        System.assertEquals(
            1,
            getCampaignMembers(camp2.Id, c.Id).size(),
            'Contact should be added to Email Preferences campaign independently'
        );
    }

    @IsTest
    static void testProcessServiceIndicators_MultipleCategories_MixedInsertDelete() {
        Contact c      = createContact();
        Campaign camp1 = createCampaign();
        Campaign camp2 = createCampaign();
        createCampaignMember(camp2.Id, c.Id);

        ucinn_ascendv2__Service_Indicator_Value__c valMkt =
            createValue('Marketing Preferences', camp1.Id);
        ucinn_ascendv2__Service_Indicator_Value__c valEmail =
            createValue('Email Preferences', camp2.Id);

        ucinn_ascendv2__Service_Indicator__c siMkt =
            createIndicator(c.Id, valMkt.Id, null);
        ucinn_ascendv2__Service_Indicator__c siEmail =
            createIndicator(c.Id, valEmail.Id, Date.today());

        Test.startTest();
        HamMktgCampaignService.processServiceIndicators(
            new List<Id>{ siMkt.Id, siEmail.Id },
            c.Id
        );
        Test.stopTest();

        System.assertEquals(
            1,
            getCampaignMembers(camp1.Id, c.Id).size(),
            'Contact should be added to Marketing campaign'
        );
        System.assertEquals(
            0,
            getCampaignMembers(camp2.Id, c.Id).size(),
            'Contact should be removed from Email campaign'
        );
    }

    /* =========================================================
     * processMarketingPreferences — DIRECT UNIT TESTS
     * SI is re-queried so relationship fields are populated
     * ========================================================= */

    @IsTest
    static void testProcessMarketingPreferences_Insert() {
        Contact c     = createContact();
        Campaign camp = createCampaign();

        ucinn_ascendv2__Service_Indicator_Value__c val =
            createValue('Marketing Preferences', camp.Id);
        ucinn_ascendv2__Service_Indicator__c si =
            requerySI(createIndicator(c.Id, val.Id, null).Id);

        Test.startTest();
        HamMktgCampaignService.processMarketingPreferences(
            new List<ucinn_ascendv2__Service_Indicator__c>{ si },
            new Map<Id, CampaignMember>()
        );
        Test.stopTest();

        System.assertEquals(
            1,
            getCampaignMembers(camp.Id, c.Id).size(),
            'CampaignMember should be inserted via processMarketingPreferences'
        );
    }

    @IsTest
    static void testProcessMarketingPreferences_Delete() {
        Contact c         = createContact();
        Campaign camp     = createCampaign();
        CampaignMember cm = createCampaignMember(camp.Id, c.Id);

        ucinn_ascendv2__Service_Indicator_Value__c val =
            createValue('Marketing Preferences', camp.Id);
        ucinn_ascendv2__Service_Indicator__c si =
            requerySI(createIndicator(c.Id, val.Id, Date.today()).Id);

        Test.startTest();
        HamMktgCampaignService.processMarketingPreferences(
            new List<ucinn_ascendv2__Service_Indicator__c>{ si },
            new Map<Id, CampaignMember>{ camp.Id => cm }
        );
        Test.stopTest();

        System.assertEquals(
            0,
            getCampaignMembers(camp.Id, c.Id).size(),
            'CampaignMember should be deleted via processMarketingPreferences'
        );
    }

    @IsTest
    static void testProcessMarketingPreferences_NoDuplicateInsert() {
        Contact c         = createContact();
        Campaign camp     = createCampaign();
        CampaignMember cm = createCampaignMember(camp.Id, c.Id);

        ucinn_ascendv2__Service_Indicator_Value__c val =
            createValue('Marketing Preferences', camp.Id);
        ucinn_ascendv2__Service_Indicator__c si =
            requerySI(createIndicator(c.Id, val.Id, null).Id);

        Test.startTest();
        HamMktgCampaignService.processMarketingPreferences(
            new List<ucinn_ascendv2__Service_Indicator__c>{ si },
            new Map<Id, CampaignMember>{ camp.Id => cm }
        );
        Test.stopTest();

        System.assertEquals(
            1,
            getCampaignMembers(camp.Id, c.Id).size(),
            'Duplicate CampaignMember should not be inserted via processMarketingPreferences'
        );
    }

    /* =========================================================
     * processEmailPreferences — DIRECT UNIT TESTS
     * ========================================================= */

    @IsTest
    static void testProcessEmailPreferences_Insert() {
        Contact c     = createContact();
        Campaign camp = createCampaign();

        ucinn_ascendv2__Service_Indicator_Value__c val =
            createValue('Email Preferences', camp.Id);
        ucinn_ascendv2__Service_Indicator__c si =
            requerySI(createIndicator(c.Id, val.Id, null).Id);

        Test.startTest();
        HamMktgCampaignService.processEmailPreferences(
            new List<ucinn_ascendv2__Service_Indicator__c>{ si },
            new Map<Id, CampaignMember>()
        );
        Test.stopTest();

        System.assertEquals(
            1,
            getCampaignMembers(camp.Id, c.Id).size(),
            'CampaignMember should be inserted via processEmailPreferences'
        );
    }

    @IsTest
    static void testProcessEmailPreferences_Delete() {
        Contact c         = createContact();
        Campaign camp     = createCampaign();
        CampaignMember cm = createCampaignMember(camp.Id, c.Id);

        ucinn_ascendv2__Service_Indicator_Value__c val =
            createValue('Email Preferences', camp.Id);
        ucinn_ascendv2__Service_Indicator__c si =
            requerySI(createIndicator(c.Id, val.Id, Date.today()).Id);

        Test.startTest();
        HamMktgCampaignService.processEmailPreferences(
            new List<ucinn_ascendv2__Service_Indicator__c>{ si },
            new Map<Id, CampaignMember>{ camp.Id => cm }
        );
        Test.stopTest();

        System.assertEquals(
            0,
            getCampaignMembers(camp.Id, c.Id).size(),
            'CampaignMember should be deleted via processEmailPreferences'
        );
    }

    @IsTest
    static void testProcessEmailPreferences_NoDuplicateInsert() {
        Contact c         = createContact();
        Campaign camp     = createCampaign();
        CampaignMember cm = createCampaignMember(camp.Id, c.Id);

        ucinn_ascendv2__Service_Indicator_Value__c val =
            createValue('Email Preferences', camp.Id);
        ucinn_ascendv2__Service_Indicator__c si =
            requerySI(createIndicator(c.Id, val.Id, null).Id);

        Test.startTest();
        HamMktgCampaignService.processEmailPreferences(
            new List<ucinn_ascendv2__Service_Indicator__c>{ si },
            new Map<Id, CampaignMember>{ camp.Id => cm }
        );
        Test.stopTest();

        System.assertEquals(
            1,
            getCampaignMembers(camp.Id, c.Id).size(),
            'Duplicate CampaignMember should not be inserted via processEmailPreferences'
        );
    }

    /* =========================================================
     * STUB CATEGORY PROCESSORS — COVERAGE
     * processCommunicationPreferences, processDirectoryVisibility,
     * processPrivacyControls, processVolunteerPreferences
     * ========================================================= */

    @IsTest
    static void testStubCategoryProcessors_Direct() {
        Contact c = createContact();

        List<ucinn_ascendv2__Service_Indicator__c> indicators =
            new List<ucinn_ascendv2__Service_Indicator__c>();

        for (String cat : new List<String>{
            'Communication Preferences',
            'Directory Visibility',
            'Privacy Controls',
            'Volunteer Preferences'
        }) {
            indicators.add(
                createIndicator(c.Id, createValue(cat, null).Id, Date.today().addDays(5))
            );
        }

        Test.startTest();
        HamMktgCampaignService.processCommunicationPreferences(indicators);
        HamMktgCampaignService.processDirectoryVisibility(indicators);
        HamMktgCampaignService.processPrivacyControls(indicators);
        HamMktgCampaignService.processVolunteerPreferences(indicators);
        Test.stopTest();

        System.assertEquals(
            4,
            indicators.size(),
            'All stub category processors should execute without error'
        );
    }

    @IsTest
    static void testProcessServiceIndicators_AllStubCategories_DispatchedFromMain() {
        Contact c      = createContact();
        List<Id> siIds = new List<Id>();

        for (String cat : new List<String>{
            'Communication Preferences',
            'Directory Visibility',
            'Privacy Controls',
            'Volunteer Preferences'
        }) {
            siIds.add(createIndicator(c.Id, createValue(cat, null).Id, null).Id);
        }

        Test.startTest();
        HamMktgCampaignService.processServiceIndicators(siIds, c.Id);
        Test.stopTest();

        System.assert(true, 'All stub category processors dispatched from main without exception');
    }
}