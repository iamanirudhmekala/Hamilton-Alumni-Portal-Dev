/**
 * miltonVolunteerOpportunitySearchAction
 * -------------------
 * Invocable Apex action for Agentforce (Volunteer Opportunities topic).
 * Returns publicly visible volunteer opportunities (Career Center and
 * Events Volunteer categories), excluding any the given contact has already
 * raised their hand for (mirrors the isInterested filtering in
 * HAM_VolunteerOpportunityController.getOpportunities / Ham_VolunteerOppCmp,
 * where those records render with a disabled/withdraw button instead of
 * "Raise Hand").
 */
global with sharing class miltonVolunteerOpportunitySearchAction {

    // ---------- INPUT ----------
    @JsonAccess(serializable='always' deserializable='always')
    global class VolunteerOpportunitySearchRequest {
        @InvocableVariable(label='Contact Id' description='Current user Contact Id. Used to filter out opportunities the contact has already raised their hand for.' required=false)
        global Id contactId;
    }

    // ---------- OUTPUT (invocable action output) ----------
    // miltonVolunteerOpportunitySearchResponse (top-level, global, @AuraEnabled/@JsonAccess
    // — see miltonVolunteerOpportunitySearchResponse.cls) is bound to the
    // miltonVolunteerOpportunityResult Custom Lightning Type so Agentforce can render it
    // via miltonVolunteerOpportunitySearchResultsCard.
    @JsonAccess(serializable='always' deserializable='always')
    global class VolunteerOpportunitySearchOutput {
        @InvocableVariable(label='Volunteer Opportunity Search Result')
        global miltonVolunteerOpportunitySearchResponse result;
    }

    @InvocableMethod(
        label='Volunteer Opportunity Search'
        description='Returns the list of publicly visible volunteer opportunities (Career Center and Events Volunteer categories).'
        category='Volunteer'
    )
    global static List<VolunteerOpportunitySearchOutput> searchVolunteerOpportunities(List<VolunteerOpportunitySearchRequest> requests) {
        List<VolunteerOpportunitySearchOutput> responses = new List<VolunteerOpportunitySearchOutput>();

        for (VolunteerOpportunitySearchRequest req : requests) {
            responses.add(wrap(buildResponse(req.contactId)));
        }

        return responses;
    }

    private static miltonVolunteerOpportunitySearchResponse buildResponse(Id contactId) {
        system.debug('[miltonVolunteerOpportunitySearchAction] buildResponse contactId: ' + contactId);
        miltonVolunteerOpportunitySearchResponse resp = new miltonVolunteerOpportunitySearchResponse();
        resp.opportunities = new List<miltonVolunteerOpportunityResult>();
        resp.contactId = contactId;

        String career = HAM_ConstantsUtil.CAREER_CENTER;
        String event  = HAM_ConstantsUtil.EVENTS_VOLUNTEER;

        String query =
            'SELECT Id, Name, HAM_Description__c, HAM_Image_URL__c, HAM_Category__c, Ham_Display_order__c ' +
            'FROM ucinn_ascendv2__Foundation_Funding_Interests__c ' +
            'WHERE HAM_Is_Publicly_Visible__c = true ' +
            'AND (HAM_Category__c = \'' + String.escapeSingleQuotes(career) + '\' ' +
            'OR HAM_Category__c = \'' + String.escapeSingleQuotes(event) + '\') ' +
            'ORDER BY Ham_Display_order__c ASC NULLS LAST, CreatedDate DESC';

        System.debug('[miltonVolunteerOpportunitySearchAction] buildResponse query: ' + query);

        List<ucinn_ascendv2__Foundation_Funding_Interests__c> records;
        try {
            records = Database.query(query);
            System.debug('[miltonVolunteerOpportunitySearchAction] buildResponse records returned: ' + records.size());
        } catch (Exception e) {
            System.debug('[miltonVolunteerOpportunitySearchAction] buildResponse query threw: ' + e.getMessage());
            resp.isSuccess = false;
            resp.totalCount = 0;
            resp.statusMessage = 'An error occurred while searching volunteer opportunities: ' + e.getMessage();
            return resp;
        }

        // Exclude opportunities the contact has already raised their hand for —
        // same active-interest check (End Date null) as HAM_VolunteerOpportunityController.getOpportunities.
        Set<Id> activeValueIds = new Set<Id>();
        system.debug('<><<><cnt ' + contactId);
        if (contactId != null) {
            for (ucinn_ascendv2__Funding_Interest__c interest : [
                SELECT ucinn_ascendv2__Foundation_Funding_Interest__c
                FROM ucinn_ascendv2__Funding_Interest__c
                WHERE ucinn_ascendv2__Contact__c = :contactId
                AND ucinn_ascendv2__End_Date__c = NULL
            ]) {
                if (interest.ucinn_ascendv2__Foundation_Funding_Interest__c != null) {
                    activeValueIds.add(interest.ucinn_ascendv2__Foundation_Funding_Interest__c);
                }
            }
        }

        for (ucinn_ascendv2__Foundation_Funding_Interests__c rec : records) {
            if (activeValueIds.contains(rec.Id)) {
                continue;
            }
            miltonVolunteerOpportunityResult vo = new miltonVolunteerOpportunityResult();
            vo.recordId     = rec.Id;
            vo.name         = rec.Name;
            vo.description  = rec.HAM_Description__c;
            vo.imageUrl     = rec.HAM_Image_URL__c;
            vo.category     = rec.HAM_Category__c;
            vo.displayOrder = rec.Ham_Display_order__c;
            resp.opportunities.add(vo);
        }

        resp.totalCount     = resp.opportunities.size();
        resp.isSuccess      = true;
        resp.statusMessage  = resp.totalCount + ' volunteer opportunity record(s) found.';
        System.debug('[miltonVolunteerOpportunitySearchAction] buildResponse final: totalCount=' + resp.totalCount
            + ', statusMessage=' + resp.statusMessage);
        return resp;
    }

    private static VolunteerOpportunitySearchOutput wrap(miltonVolunteerOpportunitySearchResponse resp) {
        VolunteerOpportunitySearchOutput output = new VolunteerOpportunitySearchOutput();
        output.result = resp;
        return output;
    }
}