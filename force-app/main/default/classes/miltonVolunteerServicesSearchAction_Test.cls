/**
 * @description Test class for miltonVolunteerServicesSearchAction. Covers the default
 * ("Current") activity type - splitting Current vs. Upcoming by start date - the "Past"
 * activity type with its from/to date range filters, and case-insensitive activity type input.
 */
@IsTest
private class miltonVolunteerServicesSearchAction_Test {

    @TestSetup
    static void setup() {
        Contact con = new Contact(FirstName = 'Milton', LastName = 'VolunteerHistoryUser', Email = 'volhistory@miltontest.com');
        insert con;

        List<ucinn_ascendv2__Involvement_Value__c> involvementValues = new List<ucinn_ascendv2__Involvement_Value__c>{
            new ucinn_ascendv2__Involvement_Value__c(
                Name = 'Current Engagement',
                ucinn_ascendv2__Involvement_Description__c = 'Currently active engagement',
                HAM_Portal_Image_URL__c = 'https://example.com/current.jpg',
                ucinn_ascendv2__Type__c = HAM_ConstantsUtil.VOLUNTEER_ENGAGEMENT
            ),
            new ucinn_ascendv2__Involvement_Value__c(
                Name = 'Upcoming Engagement',
                ucinn_ascendv2__Involvement_Description__c = 'Starts in the future',
                HAM_Portal_Image_URL__c = 'https://example.com/upcoming.jpg',
                ucinn_ascendv2__Type__c = HAM_ConstantsUtil.VOLUNTEER_ENGAGEMENT
            ),
            new ucinn_ascendv2__Involvement_Value__c(
                Name = 'Past Engagement Recent',
                ucinn_ascendv2__Involvement_Description__c = 'Completed engagement, recent',
                HAM_Portal_Image_URL__c = 'https://example.com/pastrecent.jpg',
                ucinn_ascendv2__Type__c = HAM_ConstantsUtil.VOLUNTEER_ENGAGEMENT
            ),
            new ucinn_ascendv2__Involvement_Value__c(
                Name = 'Past Engagement Old',
                ucinn_ascendv2__Involvement_Description__c = 'Completed engagement, older',
                HAM_Portal_Image_URL__c = 'https://example.com/pastold.jpg',
                ucinn_ascendv2__Type__c = HAM_ConstantsUtil.VOLUNTEER_ENGAGEMENT
            )
        };
        insert involvementValues;

        Id volunteerRtId = Schema.SObjectType.ucinn_ascendv2__Involvement__c
            .getRecordTypeInfosByDeveloperName().get('Volunteer_Engagement').getRecordTypeId();

        insert new List<ucinn_ascendv2__Involvement__c>{
            new ucinn_ascendv2__Involvement__c(
                RecordTypeId = volunteerRtId,
                ucinn_ascendv2__Contact__c = con.Id,
                ucinn_ascendv2__Involvement_Code__c = involvementValues[0].Id,
                ucinn_ascendv2__Start_Date__c = Date.today().addDays(-10),
                ucinn_ascendv2__End_Date__c = null,
                ucinn_ascendv2__Status__c = 'Current'
            ),
            new ucinn_ascendv2__Involvement__c(
                RecordTypeId = volunteerRtId,
                ucinn_ascendv2__Contact__c = con.Id,
                ucinn_ascendv2__Involvement_Code__c = involvementValues[1].Id,
                ucinn_ascendv2__Start_Date__c = Date.today().addDays(15),
                ucinn_ascendv2__End_Date__c = null,
                ucinn_ascendv2__Status__c = 'Current'
            ),
            new ucinn_ascendv2__Involvement__c(
                RecordTypeId = volunteerRtId,
                ucinn_ascendv2__Contact__c = con.Id,
                ucinn_ascendv2__Involvement_Code__c = involvementValues[2].Id,
                ucinn_ascendv2__Start_Date__c = Date.today().addDays(-15),
                ucinn_ascendv2__End_Date__c = Date.today().addDays(-5),
                ucinn_ascendv2__Status__c = 'Former'
            ),
            new ucinn_ascendv2__Involvement__c(
                RecordTypeId = volunteerRtId,
                ucinn_ascendv2__Contact__c = con.Id,
                ucinn_ascendv2__Involvement_Code__c = involvementValues[3].Id,
                ucinn_ascendv2__Start_Date__c = Date.today().addDays(-200),
                ucinn_ascendv2__End_Date__c = Date.today().addDays(-190),
                ucinn_ascendv2__Status__c = 'Former'
            )
        };
    }

    private static Contact getContact() {
        return [SELECT Id FROM Contact WHERE LastName = 'VolunteerHistoryUser' LIMIT 1];
    }

    @IsTest
    static void testSearch_DefaultActivityType_SplitsCurrentAndUpcoming() {
        miltonVolunteerServicesSearchAction.VolunteerServicesSearchRequest req =
            new miltonVolunteerServicesSearchAction.VolunteerServicesSearchRequest();
        req.contactId = getContact().Id;

        Test.startTest();
        List<miltonVolunteerServicesSearchAction.VolunteerServicesSearchOutput> outputs =
            miltonVolunteerServicesSearchAction.searchVolunteerServices(
                new List<miltonVolunteerServicesSearchAction.VolunteerServicesSearchRequest>{ req }
            );
        Test.stopTest();

        miltonVolunteerServicesSearchResponse resp = outputs[0].result;
        Assert.isTrue(resp.isSuccess, 'Search should succeed');
        Assert.areEqual(2, resp.totalCount, 'Only the two non-Former engagements should be returned');

        Map<String, String> tabByName = new Map<String, String>();
        for (miltonVolunteerServicesResult item : resp.activities) {
            tabByName.put(item.name, item.computedTab);
        }
        Assert.areEqual('Current', tabByName.get('Current Engagement'));
        Assert.areEqual('Upcoming', tabByName.get('Upcoming Engagement'));
    }

    @IsTest
    static void testSearch_PastActivityType_WithDateRangeFilter() {
        miltonVolunteerServicesSearchAction.VolunteerServicesSearchRequest req =
            new miltonVolunteerServicesSearchAction.VolunteerServicesSearchRequest();
        req.contactId = getContact().Id;
        req.activityType = 'Past';
        req.fromDate = Date.today().addDays(-30);
        req.toDate = Date.today();

        Test.startTest();
        List<miltonVolunteerServicesSearchAction.VolunteerServicesSearchOutput> outputs =
            miltonVolunteerServicesSearchAction.searchVolunteerServices(
                new List<miltonVolunteerServicesSearchAction.VolunteerServicesSearchRequest>{ req }
            );
        Test.stopTest();

        miltonVolunteerServicesSearchResponse resp = outputs[0].result;
        Assert.isTrue(resp.isSuccess, 'Search should succeed');
        Assert.areEqual(1, resp.totalCount, 'Only the recent Former engagement falls inside the date range');
        Assert.areEqual('Past Engagement Recent', resp.activities[0].name);
        Assert.areEqual('Past', resp.activities[0].computedTab);
    }

    @IsTest
    static void testSearch_PastActivityType_IsCaseInsensitiveAndUnbounded() {
        miltonVolunteerServicesSearchAction.VolunteerServicesSearchRequest req =
            new miltonVolunteerServicesSearchAction.VolunteerServicesSearchRequest();
        req.contactId = getContact().Id;
        req.activityType = 'past';

        Test.startTest();
        List<miltonVolunteerServicesSearchAction.VolunteerServicesSearchOutput> outputs =
            miltonVolunteerServicesSearchAction.searchVolunteerServices(
                new List<miltonVolunteerServicesSearchAction.VolunteerServicesSearchRequest>{ req }
            );
        Test.stopTest();

        miltonVolunteerServicesSearchResponse resp = outputs[0].result;
        Assert.isTrue(resp.isSuccess, 'Lower-case "past" must still be treated as the Past activity type');
        Assert.areEqual(2, resp.totalCount, 'With no date bounds, both Former engagements should be returned');
    }
}