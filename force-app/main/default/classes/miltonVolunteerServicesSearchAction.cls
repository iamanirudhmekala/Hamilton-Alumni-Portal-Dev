/**
 * miltonVolunteerServicesSearchAction
 * -------------------
 * Invocable Apex action for Agentforce (Volunteer Services topic).
 * Returns the calling contact's own volunteer activity history —
 * either their Current/Upcoming engagements or their Past (completed)
 * engagements, optionally bounded by a date range for Past.
 *
 * Split out from HAM_VolunteerOpportunityController into its own class,
 * with its own SOQL, so the Guest User profile backing the embedded chat
 * site only needs Apex Class Access to this one method, not the full
 * shared controller — mirrors miltonVolunteerOpportunityInterestAction.
 *
 * contactId must be bound to the authenticated caller's own Contact by
 * the Agentforce topic configuration (never accepted as free text) —
 * this class runs without sharing, so contactId is the only access
 * control gate on a person's private volunteer activity history.
 */
public without sharing class miltonVolunteerServicesSearchAction {

    // ---------- INPUT ----------
    @JsonAccess(serializable='always' deserializable='always')
    public class VolunteerServicesSearchRequest {
        @InvocableVariable(label='Contact Id' description='Contact Id of the currently authenticated user. Must be bound to the Contact Id of the authenticated session; never accept as free text or infer from conversation.' required=true)
        public Id contactId;

        @InvocableVariable(label='Activity Type' description='Which set of volunteer activities to return: "Current" (current and upcoming volunteer engagements) or "Past" (completed engagements). Defaults to "Current" when omitted or blank.' required=false)
        public String activityType;

        @InvocableVariable(label='From Date' description='Optional inclusive start-of-range filter, format YYYY-MM-DD. Only applied when Activity Type is "Past".' required=false)
        public Date fromDate;

        @InvocableVariable(label='To Date' description='Optional inclusive end-of-range filter, format YYYY-MM-DD. Only applied when Activity Type is "Past".' required=false)
        public Date toDate;
    }

    // ---------- OUTPUT ----------
    @JsonAccess(serializable='always' deserializable='always')
    public class VolunteerServicesSearchOutput {
        @InvocableVariable(label='Volunteer Services Search Result')
        public miltonVolunteerServicesSearchResponse result;
    }

    @InvocableMethod(
        label='Volunteer Services Search'
        description='Returns the current/upcoming or past volunteer activity history for the calling contact.'
        category='Volunteer'
    )
    public static List<VolunteerServicesSearchOutput> searchVolunteerServices(List<VolunteerServicesSearchRequest> requests) {
        List<VolunteerServicesSearchOutput> responses = new List<VolunteerServicesSearchOutput>();

        for (VolunteerServicesSearchRequest req : requests) {
            responses.add(wrap(buildResponse(req.contactId, req.activityType, req.fromDate, req.toDate)));
        }

        return responses;
    }

    private static miltonVolunteerServicesSearchResponse buildResponse(Id contactId, String activityType, Date fromDate, Date toDate) {
        miltonVolunteerServicesSearchResponse resp = new miltonVolunteerServicesSearchResponse();
        resp.activities = new List<miltonVolunteerServicesResult>();
        resp.contactId = contactId;

        Boolean isPast = 'Past'.equalsIgnoreCase(activityType);
        String volunteerEngagement = HAM_ConstantsUtil.VOLUNTEER_ENGAGEMENT;
        Date today = System.today();

        String query =
            'SELECT Id, ucinn_ascendv2__Start_Date__c, ucinn_ascendv2__End_Date__c, ucinn_ascendv2__Status__c, ' +
            'ucinn_ascendv2__Involvement_Code__c, ucinn_ascendv2__Involvement_Code__r.Name, ' +
            'ucinn_ascendv2__Involvement_Code__r.ucinn_ascendv2__Involvement_Description__c, ' +
            'ucinn_ascendv2__Involvement_Code__r.HAM_Portal_Image_URL__c ' +
            'FROM ucinn_ascendv2__Involvement__c ' +
            'WHERE ucinn_ascendv2__Contact__c = :contactId ' +
            'AND ucinn_ascendv2__Involvement_Type_Formula__c = :volunteerEngagement ' +
            'AND ucinn_ascendv2__Involvement_Code__c != null ';

        if (isPast) {
            query += 'AND ucinn_ascendv2__Status__c = \'Former\' ';
            if (fromDate != null) {
                query += 'AND ucinn_ascendv2__Start_Date__c >= :fromDate ';
            }
            if (toDate != null) {
                query += 'AND ucinn_ascendv2__Start_Date__c <= :toDate ';
            }
            query += 'ORDER BY ucinn_ascendv2__Start_Date__c DESC LIMIT 25';
        } else {
            query += 'AND (ucinn_ascendv2__End_Date__c = null OR ucinn_ascendv2__End_Date__c > :today) ';
            query += 'ORDER BY ucinn_ascendv2__Start_Date__c ASC LIMIT 25';
        }

        List<ucinn_ascendv2__Involvement__c> involvements;
        try {
            involvements = Database.query(query);
        } catch (Exception e) {
            resp.isSuccess = false;
            resp.totalCount = 0;
            resp.statusMessage = 'An error occurred while searching volunteer services: ' + e.getMessage();
            return resp;
        }

        for (ucinn_ascendv2__Involvement__c inv : involvements) {
            miltonVolunteerServicesResult item = new miltonVolunteerServicesResult();
            item.recordId = inv.Id;
            item.name = inv.ucinn_ascendv2__Involvement_Code__r.Name;
            item.description = inv.ucinn_ascendv2__Involvement_Code__r.ucinn_ascendv2__Involvement_Description__c;
            item.imageUrl = inv.ucinn_ascendv2__Involvement_Code__r.HAM_Portal_Image_URL__c;
            item.startDate = inv.ucinn_ascendv2__Start_Date__c;
            item.endDate = inv.ucinn_ascendv2__End_Date__c;
            item.status = inv.ucinn_ascendv2__Status__c;

            if (isPast) {
                item.computedTab = 'Past';
            } else if (inv.ucinn_ascendv2__Start_Date__c > today) {
                item.computedTab = 'Upcoming';
            } else {
                item.computedTab = 'Current';
            }

            resp.activities.add(item);
        }

        resp.totalCount = resp.activities.size();
        resp.isSuccess = true;
        resp.statusMessage = resp.totalCount + ' volunteer service record(s) found.';
        return resp;
    }

    private static VolunteerServicesSearchOutput wrap(miltonVolunteerServicesSearchResponse resp) {
        VolunteerServicesSearchOutput output = new VolunteerServicesSearchOutput();
        output.result = resp;
        return output;
    }
}