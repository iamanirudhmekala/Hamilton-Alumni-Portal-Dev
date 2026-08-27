/**
 * miltonVolunteerOpportunityInterestAction
 * -------------------
 * Records a "Raise Hand" click from miltonVolunteerOpportunitySearchResultsCard
 * (Agentforce / Milton chat volunteer opportunities card).
 *
 * Split out from HAM_VolunteerOpportunityController.setInterested into its own
 * class so the Guest User profile backing the embedded chat site only needs
 * Apex Class Access to this one method, not the full shared controller.
 */
public without sharing class miltonVolunteerOpportunityInterestAction {

    @AuraEnabled
    public static String setInterested(Id interestValueId, Id currentUserContactId) {
        Id contactId = currentUserContactId;
        // Fetch category from Foundation Funding Interest
        ucinn_ascendv2__Foundation_Funding_Interests__c interestValue = [
            SELECT HAM_Category__c
            FROM ucinn_ascendv2__Foundation_Funding_Interests__c
            WHERE Id = :interestValueId
            LIMIT 1
        ];
        // Create new Funding Interest
        ucinn_ascendv2__Funding_Interest__c newInterest =
            new ucinn_ascendv2__Funding_Interest__c();

        newInterest.ucinn_ascendv2__Contact__c = contactId;
        newInterest.ucinn_ascendv2__Foundation_Funding_Interest__c = interestValueId;
        newInterest.ucinn_ascendv2__Start_Date__c = System.today();
        newInterest.HAM_Category__c = interestValue.HAM_Category__c;
        newInterest.ucinn_ascendv2__Data_Source__c = 'Hamilton Quad'; //ASC-14664 Adding for reporting

        insert newInterest;
        return newInterest.Id;
    }

    /**
     * Returns the subset of interestValueIds for which the given contact still has
     * an active (End Date null) Funding Interest. Used by
     * miltonVolunteerOpportunitySearchResultsCard to reconcile its locally-persisted
     * "raised hand" flags against current data, since a locally stored flag can go
     * stale once the underlying Funding Interest is withdrawn/deleted.
     */
    @AuraEnabled(cacheable=true)
    public static List<Id> getActiveInterestValueIds(Id contactId, List<Id> interestValueIds) {
        List<Id> activeIds = new List<Id>();
        if (contactId == null || interestValueIds == null || interestValueIds.isEmpty()) {
            return activeIds;
        }
        for (ucinn_ascendv2__Funding_Interest__c interest : [
            SELECT ucinn_ascendv2__Foundation_Funding_Interest__c
            FROM ucinn_ascendv2__Funding_Interest__c
            WHERE ucinn_ascendv2__Contact__c = :contactId
            AND ucinn_ascendv2__Foundation_Funding_Interest__c IN :interestValueIds
            AND ucinn_ascendv2__End_Date__c = NULL
        ]) {
            activeIds.add(interest.ucinn_ascendv2__Foundation_Funding_Interest__c);
        }
        return activeIds;
    }

    // ---------- INPUT ----------
    @JsonAccess(serializable='always' deserializable='always')
    public class VolunteerInterestByNameRequest {
        @InvocableVariable(label='Foundation Funding Interest Name' description='Name of the Foundation Funding Interest (volunteer opportunity) the contact is raising their hand for.' required=true)
        public String interestValueName;

        @InvocableVariable(label='Contact Id' description='Contact Id of the user raising their hand.' required=true)
        public Id contactId;
    }

    // ---------- OUTPUT ----------
    @JsonAccess(serializable='always' deserializable='always')
    public class VolunteerInterestByNameResponse {
        @InvocableVariable(label='Result Message' description='Success or error message describing the outcome.')
        public String message;
    }

    @InvocableMethod(
        label='Create Interest'
        description='Creates a Funding Interest record for the given Foundation Funding Interest name and Contact Id, and returns a success or error message.'
        category='Volunteer'
    )
    public static List<VolunteerInterestByNameResponse> createInterestByName(List<VolunteerInterestByNameRequest> requests) {
        List<VolunteerInterestByNameResponse> responses = new List<VolunteerInterestByNameResponse>();

        for (VolunteerInterestByNameRequest req : requests) {
            responses.add(createInterest(req));
        }

        return responses;
    }

    private static VolunteerInterestByNameResponse createInterest(VolunteerInterestByNameRequest req) {
        VolunteerInterestByNameResponse resp = new VolunteerInterestByNameResponse();

        try {
            List<ucinn_ascendv2__Foundation_Funding_Interests__c> interestValues = [
                SELECT Id, HAM_Category__c
                FROM ucinn_ascendv2__Foundation_Funding_Interests__c
                WHERE Name = :req.interestValueName
                LIMIT 1
            ];

            if (interestValues.isEmpty()) {
                resp.message = 'Error: No volunteer opportunity found with the name "' + req.interestValueName + '".';
                return resp;
            }

            ucinn_ascendv2__Foundation_Funding_Interests__c interestValue = interestValues[0];

            ucinn_ascendv2__Funding_Interest__c newInterest =
                new ucinn_ascendv2__Funding_Interest__c();

            newInterest.ucinn_ascendv2__Contact__c = req.contactId;
            newInterest.ucinn_ascendv2__Foundation_Funding_Interest__c = interestValue.Id;
            newInterest.ucinn_ascendv2__Start_Date__c = System.today();
            newInterest.HAM_Category__c = interestValue.HAM_Category__c;
            newInterest.ucinn_ascendv2__Data_Source__c = 'Hamilton Quad';

            insert newInterest;

            resp.message = 'Successfully inserted the volunteer interest record.';
        } catch (Exception e) {
            resp.message = 'Error: ' + e.getMessage();
        }

        return resp;
    }
}