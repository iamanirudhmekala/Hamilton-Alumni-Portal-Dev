/**
 * @description Test class for miltonVolunteerOpportunitySearchAction. Covers the
 * publicly-visible/category filtering, and exclusion of opportunities the calling
 * contact has already raised their hand for (active Funding Interest, End Date null).
 */
@IsTest
private class miltonVolOpportunitySearchAction_Test {

    @TestSetup
    static void setup() {
        List<ucinn_ascendv2__Foundation_Funding_Interests__c> opportunities = new List<ucinn_ascendv2__Foundation_Funding_Interests__c>{
            new ucinn_ascendv2__Foundation_Funding_Interests__c(
                Name = 'Career Mentoring',
                HAM_Description__c = 'Help students with career guidance',
                HAM_Image_URL__c = 'https://example.com/image1.jpg',
                HAM_Category__c = HAM_ConstantsUtil.CAREER_CENTER,
                HAM_Is_Publicly_Visible__c = true,
                Ham_Display_order__c = 1
            ),
            new ucinn_ascendv2__Foundation_Funding_Interests__c(
                Name = 'Alumni Event Volunteer',
                HAM_Description__c = 'Assist with alumni events',
                HAM_Image_URL__c = 'https://example.com/image2.jpg',
                HAM_Category__c = HAM_ConstantsUtil.EVENTS_VOLUNTEER,
                HAM_Is_Publicly_Visible__c = true,
                Ham_Display_order__c = 2
            ),
            // Wrong category - must never be returned regardless of visibility
            new ucinn_ascendv2__Foundation_Funding_Interests__c(
                Name = 'Athletics Program',
                HAM_Category__c = 'Athletics',
                HAM_Is_Publicly_Visible__c = true
            ),
            // Not publicly visible - must never be returned regardless of category
            new ucinn_ascendv2__Foundation_Funding_Interests__c(
                Name = 'Hidden Career Opportunity',
                HAM_Category__c = HAM_ConstantsUtil.CAREER_CENTER,
                HAM_Is_Publicly_Visible__c = false
            )
        };
        insert opportunities;

        Contact con = new Contact(FirstName = 'Milton', LastName = 'VolunteerSearcher', Email = 'volsearch@miltontest.com');
        insert con;

        // Contact has already raised their hand for the Career Mentoring opportunity
        insert new ucinn_ascendv2__Funding_Interest__c(
            ucinn_ascendv2__Contact__c = con.Id,
            ucinn_ascendv2__Foundation_Funding_Interest__c = opportunities[0].Id,
            ucinn_ascendv2__Start_Date__c = Date.today().addDays(-5),
            ucinn_ascendv2__End_Date__c = null
        );
    }

    @IsTest
    static void testSearch_NoContactId_ReturnsAllPubliclyVisibleInScopeCategories() {
        miltonVolunteerOpportunitySearchAction.VolunteerOpportunitySearchRequest req =
            new miltonVolunteerOpportunitySearchAction.VolunteerOpportunitySearchRequest();

        Test.startTest();
        List<miltonVolunteerOpportunitySearchAction.VolunteerOpportunitySearchOutput> outputs =
            miltonVolunteerOpportunitySearchAction.searchVolunteerOpportunities(
                new List<miltonVolunteerOpportunitySearchAction.VolunteerOpportunitySearchRequest>{ req }
            );
        Test.stopTest();

        miltonVolunteerOpportunitySearchResponse resp = outputs[0].result;
        Assert.isTrue(resp.isSuccess, 'Search should succeed');
        Assert.areEqual(2, resp.totalCount, 'Only the two publicly visible Career/Events records should be returned');

        Set<String> names = new Set<String>();
        for (miltonVolunteerOpportunityResult vo : resp.opportunities) {
            names.add(vo.name);
        }
        Assert.isTrue(names.contains('Career Mentoring'), 'Career Mentoring should be included with no contact filter');
        Assert.isTrue(names.contains('Alumni Event Volunteer'));
        Assert.isFalse(names.contains('Athletics Program'), 'Wrong category must be excluded');
        Assert.isFalse(names.contains('Hidden Career Opportunity'), 'Non publicly-visible record must be excluded');
    }

    @IsTest
    static void testSearch_WithContactId_ExcludesAlreadyRaisedHand() {
        Contact con = [SELECT Id FROM Contact WHERE LastName = 'VolunteerSearcher' LIMIT 1];

        miltonVolunteerOpportunitySearchAction.VolunteerOpportunitySearchRequest req =
            new miltonVolunteerOpportunitySearchAction.VolunteerOpportunitySearchRequest();
        req.contactId = con.Id;

        Test.startTest();
        List<miltonVolunteerOpportunitySearchAction.VolunteerOpportunitySearchOutput> outputs =
            miltonVolunteerOpportunitySearchAction.searchVolunteerOpportunities(
                new List<miltonVolunteerOpportunitySearchAction.VolunteerOpportunitySearchRequest>{ req }
            );
        Test.stopTest();

        miltonVolunteerOpportunitySearchResponse resp = outputs[0].result;
        Assert.isTrue(resp.isSuccess, 'Search should succeed');
        Assert.areEqual(1, resp.totalCount, 'The already-raised-hand opportunity must be excluded');
        Assert.areEqual('Alumni Event Volunteer', resp.opportunities[0].name);
    }
}