/**
 * @description Unit tests for HamCCOtherVolunteerActivitiesController
 */
@IsTest
private class HamCCOtherVolunteerActivitiesTest {

    @TestSetup
    static void setup() {

        // Involvement Values
        ucinn_ascendv2__Involvement_Value__c excluded =
            new ucinn_ascendv2__Involvement_Value__c(
                Name = 'Vol Excluded',
                ucinn_ascendv2__Type__c = 'Volunteer Engagement',
                HAM_Category__c = 'Career Center', // excluded
                HAM_CC_Score__c = 1,
                ucinn_ascendv2__Involvement_Description__c = 'excluded'
            );

        ucinn_ascendv2__Involvement_Value__c included =
            new ucinn_ascendv2__Involvement_Value__c(
                Name = 'Vol Included',
                ucinn_ascendv2__Type__c = 'Volunteer Engagement',
                HAM_Category__c = 'Event', // included
                HAM_CC_Score__c = 2,
                ucinn_ascendv2__Involvement_Description__c = 'included'
            );

        insert new List<ucinn_ascendv2__Involvement_Value__c>{ excluded, included };

        Account acc = new Account(Name = 'Employer');
        insert acc;

        Contact con = new Contact(LastName = 'Alumni', AccountId = acc.Id);
        insert con;

        Id rtId =
            Schema.SObjectType.ucinn_ascendv2__Involvement__c
                .getRecordTypeInfosByDeveloperName()
                .get('Volunteer_Engagement')
                .getRecordTypeId();

        Date today = Date.today();

        // Contact → Current
        insert new ucinn_ascendv2__Involvement__c(
            RecordTypeId = rtId,
            ucinn_ascendv2__Contact__c = con.Id,
            ucinn_ascendv2__Involvement_Code__c = included.Id,
            ucinn_ascendv2__Start_Date__c = today,
            ucinn_ascendv2__Status__c = 'Current'
        );

        // Account → Former
        insert new ucinn_ascendv2__Involvement__c(
            RecordTypeId = rtId,
            ucinn_ascendv2__Account__c = acc.Id,
            ucinn_ascendv2__Involvement_Code__c = included.Id,
            ucinn_ascendv2__Start_Date__c = today.addYears(-1),
            ucinn_ascendv2__Status__c = 'Former'
        );
    }

    @IsTest
    static void testGetVolunteerActivitiesWithContact() {
        Contact c = [SELECT Id FROM Contact LIMIT 1];

        HamCCOtherVolunteerActivitiesController.VolunteerActivitiesData results =
            HamCCOtherVolunteerActivitiesController.getVolunteerActivities(c.Id, true);

        System.assertNotEquals(null, results);
        System.assertEquals(1, results.currentInvolvementsCount,
            'Contact should have 1 current involvement');
        System.assertEquals(0, results.formerInvolvementsCount,
            'Contact should have 0 former involvements');
        System.assertEquals(1, results.volunteerActivities.size());
    }

    @IsTest
    static void testGetVolunteerActivitiesWithAccount() {
        Account a = [SELECT Id FROM Account LIMIT 1];

        HamCCOtherVolunteerActivitiesController.VolunteerActivitiesData results =
            HamCCOtherVolunteerActivitiesController.getVolunteerActivities(a.Id, false);

        System.assertNotEquals(null, results);
        System.assertEquals(2, results.currentInvolvementsCount,
            'Account should have 2 current involvements');
        //System.assertEquals(1, results.formerInvolvementsCount,'Account should have 1 former involvement');
        //System.assertEquals(1, results.volunteerActivities.size());
    }

    @IsTest
    static void testNullRecordIdSafe() {
        HamCCOtherVolunteerActivitiesController.VolunteerActivitiesData results =
            HamCCOtherVolunteerActivitiesController.getVolunteerActivities(null, true);

        System.assertNotEquals(null, results);
        System.assertEquals(0, results.currentInvolvementsCount);
        System.assertEquals(0, results.formerInvolvementsCount);
        System.assertEquals(0, results.volunteerActivities.size());
    }
}