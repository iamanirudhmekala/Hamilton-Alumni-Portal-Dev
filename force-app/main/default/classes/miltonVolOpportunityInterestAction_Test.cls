/**
 * @description Test class for miltonVolunteerOpportunityInterestAction. Covers setInterested,
 * the null/empty-input guards and active-only filtering on getActiveInterestValueIds, and both
 * the success, not-found and exception branches of createInterestByName.
 */
@IsTest
private class miltonVolOpportunityInterestAction_Test {

    @TestSetup
    static void setup() {
        Contact con = new Contact(FirstName = 'Milton', LastName = 'RaiseHandUser', Email = 'raisehand@miltontest.com');
        insert con;

        insert new List<ucinn_ascendv2__Foundation_Funding_Interests__c>{
            new ucinn_ascendv2__Foundation_Funding_Interests__c(
                Name = 'Career Mentoring',
                HAM_Category__c = HAM_ConstantsUtil.CAREER_CENTER,
                HAM_Is_Publicly_Visible__c = true
            ),
            new ucinn_ascendv2__Foundation_Funding_Interests__c(
                Name = 'Alumni Event Volunteer',
                HAM_Category__c = HAM_ConstantsUtil.EVENTS_VOLUNTEER,
                HAM_Is_Publicly_Visible__c = true
            )
        };
    }

    private static Contact getContact() {
        return [SELECT Id FROM Contact WHERE LastName = 'RaiseHandUser' LIMIT 1];
    }

    private static ucinn_ascendv2__Foundation_Funding_Interests__c getOpportunity(String name) {
        return [SELECT Id, HAM_Category__c FROM ucinn_ascendv2__Foundation_Funding_Interests__c WHERE Name = :name LIMIT 1];
    }

    @IsTest
    static void testSetInterested_CreatesFundingInterest() {
        Contact con = getContact();
        ucinn_ascendv2__Foundation_Funding_Interests__c opportunity = getOpportunity('Career Mentoring');

        Test.startTest();
        String newId = miltonVolunteerOpportunityInterestAction.setInterested(opportunity.Id, con.Id);
        Test.stopTest();

        Assert.isNotNull(newId, 'A new Funding Interest Id should be returned');

        ucinn_ascendv2__Funding_Interest__c created = [
            SELECT ucinn_ascendv2__Contact__c, ucinn_ascendv2__Foundation_Funding_Interest__c, HAM_Category__c, ucinn_ascendv2__Data_Source__c
            FROM ucinn_ascendv2__Funding_Interest__c
            WHERE Id = :newId
        ];
        Assert.areEqual(con.Id, created.ucinn_ascendv2__Contact__c);
        Assert.areEqual(opportunity.Id, created.ucinn_ascendv2__Foundation_Funding_Interest__c);
        Assert.areEqual(HAM_ConstantsUtil.CAREER_CENTER, created.HAM_Category__c);
        Assert.areEqual('Hamilton Quad', created.ucinn_ascendv2__Data_Source__c);
    }

    @IsTest
    static void testGetActiveInterestValueIds_NullAndEmptyInputsReturnEmpty() {
        Contact con = getContact();
        ucinn_ascendv2__Foundation_Funding_Interests__c opportunity = getOpportunity('Career Mentoring');

        Test.startTest();
        List<Id> nullContact = miltonVolunteerOpportunityInterestAction.getActiveInterestValueIds(null, new List<Id>{ opportunity.Id });
        List<Id> nullIds = miltonVolunteerOpportunityInterestAction.getActiveInterestValueIds(con.Id, null);
        List<Id> emptyIds = miltonVolunteerOpportunityInterestAction.getActiveInterestValueIds(con.Id, new List<Id>());
        Test.stopTest();

        Assert.isTrue(nullContact.isEmpty(), 'Null contact must short-circuit to an empty list');
        Assert.isTrue(nullIds.isEmpty(), 'Null interest value ids must short-circuit to an empty list');
        Assert.isTrue(emptyIds.isEmpty(), 'Empty interest value ids must short-circuit to an empty list');
    }

    @IsTest
    static void testGetActiveInterestValueIds_ReturnsOnlyActiveMatches() {
        Contact con = getContact();
        ucinn_ascendv2__Foundation_Funding_Interests__c active = getOpportunity('Career Mentoring');
        ucinn_ascendv2__Foundation_Funding_Interests__c withdrawn = getOpportunity('Alumni Event Volunteer');

        insert new List<ucinn_ascendv2__Funding_Interest__c>{
            new ucinn_ascendv2__Funding_Interest__c(
                ucinn_ascendv2__Contact__c = con.Id,
                ucinn_ascendv2__Foundation_Funding_Interest__c = active.Id,
                ucinn_ascendv2__Start_Date__c = Date.today().addDays(-5),
                ucinn_ascendv2__End_Date__c = null
            ),
            new ucinn_ascendv2__Funding_Interest__c(
                ucinn_ascendv2__Contact__c = con.Id,
                ucinn_ascendv2__Foundation_Funding_Interest__c = withdrawn.Id,
                ucinn_ascendv2__Start_Date__c = Date.today().addDays(-20),
                ucinn_ascendv2__End_Date__c = Date.today().addDays(-1)
            )
        };

        Test.startTest();
        List<Id> activeIds = miltonVolunteerOpportunityInterestAction.getActiveInterestValueIds(
            con.Id, new List<Id>{ active.Id, withdrawn.Id }
        );
        Test.stopTest();

        Assert.areEqual(1, activeIds.size(), 'Only the still-active interest should be returned');
        Assert.areEqual(active.Id, activeIds[0]);
    }

    @IsTest
    static void testCreateInterestByName_Success() {
        Contact con = getContact();

        miltonVolunteerOpportunityInterestAction.VolunteerInterestByNameRequest req =
            new miltonVolunteerOpportunityInterestAction.VolunteerInterestByNameRequest();
        req.interestValueName = 'Career Mentoring';
        req.contactId = con.Id;

        Test.startTest();
        List<miltonVolunteerOpportunityInterestAction.VolunteerInterestByNameResponse> responses =
            miltonVolunteerOpportunityInterestAction.createInterestByName(
                new List<miltonVolunteerOpportunityInterestAction.VolunteerInterestByNameRequest>{ req }
            );
        Test.stopTest();

        Assert.areEqual('Successfully inserted the volunteer interest record.', responses[0].message);
    }

    @IsTest
    static void testCreateInterestByName_NotFound() {
        miltonVolunteerOpportunityInterestAction.VolunteerInterestByNameRequest req =
            new miltonVolunteerOpportunityInterestAction.VolunteerInterestByNameRequest();
        req.interestValueName = 'Does Not Exist Opportunity';
        req.contactId = getContact().Id;

        Test.startTest();
        List<miltonVolunteerOpportunityInterestAction.VolunteerInterestByNameResponse> responses =
            miltonVolunteerOpportunityInterestAction.createInterestByName(
                new List<miltonVolunteerOpportunityInterestAction.VolunteerInterestByNameRequest>{ req }
            );
        Test.stopTest();

        Assert.isTrue(responses[0].message.startsWith('Error: No volunteer opportunity found'), 'Unknown name must report a not-found error');
    }

    @IsTest
    static void testCreateInterestByName_InsertFailureIsCaught() {
        miltonVolunteerOpportunityInterestAction.VolunteerInterestByNameRequest req =
            new miltonVolunteerOpportunityInterestAction.VolunteerInterestByNameRequest();
        req.interestValueName = 'Career Mentoring';
        // Well-formed but non-existent Contact Id - forces an invalid cross-reference error on insert.
        req.contactId = (Id) '003000000000000AAA';

        Test.startTest();
        List<miltonVolunteerOpportunityInterestAction.VolunteerInterestByNameResponse> responses =
            miltonVolunteerOpportunityInterestAction.createInterestByName(
                new List<miltonVolunteerOpportunityInterestAction.VolunteerInterestByNameRequest>{ req }
            );
        Test.stopTest();

        Assert.isTrue(responses[0].message.startsWith('Error: '), 'A DML failure must be caught and reported as an error message');
    }
}