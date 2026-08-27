/**
 * miltonAlumniSearchAction
 * -------------------
 * Invocable Apex action for Agentforce (Alumni Search topic).
 * Accepts up to 3 optional inputs — Name, Major/Degree, Class of Year.
 * At least ONE must be provided by the calling agent topic (enforced here
 * as a safety net even though the topic instructions already require it).
 *
 * NOTE ON HAM_Reunion_Year__c:
 * This sample assumes the field resolves to a TEXT value (common for
 * Ascendv2 formula fields used for display, e.g. "1992").
 * If it is actually a NUMBER field in your org, change the WHERE clause
 * for year from a LIKE bind to an exact Integer equality bind
 * (see comment in buildYearFilter()).
 */
global with sharing class miltonAlumniSearchAction {

    // ---------- INPUT ----------
    @JsonAccess(serializable='always' deserializable='always')
    global class AlumniSearchRequest {
        @InvocableVariable(label='Alumni Name' description='Full or partial contact name' required=false)
        global String alumniName;

        @InvocableVariable(label='Major / Degree' description='Full or partial major/degree text' required=false)
        global String majorDegree;

        @InvocableVariable(label='Class of Year' description='Graduation year' required=false)
        global String classOfYear;

        @InvocableVariable(label='Contact Id' description='Contact Id of the currently authenticated user (the chat viewer). Must be bound to the Contact Id of the authenticated session; never accept as free text or infer from conversation.' required=true)
        global Id contactId;
    }

    // ---------- OUTPUT (invocable action output) ----------
    // miltonAlumniSearchResponse (top-level, global, @AuraEnabled/@JsonAccess — see
    // miltonAlumniSearchResponse.cls) is bound to the miltonAlumniSearchResult
    // Custom Lightning Type so Agentforce can render it via miltonAlumniSearchResultsCard.
    // It's nested here as a field so the field itself stays @InvocableVariable,
    // which is what makes it show up as an action output in Agent Builder.
    @JsonAccess(serializable='always' deserializable='always')
    global class AlumniSearchOutput {
        @InvocableVariable(label='Alumni Search Result')
        global miltonAlumniSearchResponse result;
    }

    @InvocableMethod(
        label='Alumni Search'
        description='Searches Alumni Degree Information records by name, major/degree, and/or class of year. Requires at least one parameter.'
        category='Alumni'
    )
    global static List<AlumniSearchOutput> searchAlumni(List<AlumniSearchRequest> requests) {
        List<AlumniSearchOutput> responses = new List<AlumniSearchOutput>();

        for (AlumniSearchRequest req : requests) {
            responses.add(wrap(buildResponse(req.alumniName, req.majorDegree, req.classOfYear, req.contactId)));
        }

        return responses;
    }

    private static miltonAlumniSearchResponse buildResponse(String name, String degree, String year, Id viewerContactId) {
        miltonAlumniSearchResponse resp = new miltonAlumniSearchResponse();
        resp.alumniRecords = new List<miltonAlumniResult>();
        resp.contactId = viewerContactId;

        // Safety-net validation (topic should already enforce this)
        if (String.isBlank(name) && String.isBlank(degree) && String.isBlank(year)) {
            System.debug('[miltonAlumniSearchAction] buildResponse: all inputs blank, returning early.');
            resp.isSuccess = false;
            resp.totalCount = 0;
            resp.statusMessage = 'No search criteria provided. Please provide at least one of: name, major/degree, or class of year.';
            return resp;
        }

        List<String> whereClauses = new List<String>();

        // Bind variables must be in scope at the point Database.query() executes.
        String namePattern;
        String degreePattern;
        String yearPattern;

        if (String.isNotBlank(name)) {
            namePattern = '%' + name.trim() + '%';
            whereClauses.add('ucinn_ascendv2__Contact__r.Name LIKE :namePattern');
        }
        if (String.isNotBlank(degree)) {
            degreePattern = '%' + degree.trim() + '%';
            whereClauses.add('ucinn_ascendv2__Major_Degree_Formula__c LIKE :degreePattern');
        }
        if (String.isNotBlank(year)) {
            yearPattern = '%' + year.trim() + '%';
            // If HAM_Reunion_Year__c is a Number field, replace the line above/below with:
            //   Integer yearVal = Integer.valueOf(year.trim());
            //   whereClauses.add('ucinn_ascendv2__Contact__r.HAM_Reunion_Year__c = :yearVal');
            whereClauses.add('ucinn_ascendv2__Contact__r.HAM_Reunion_Year__c LIKE :yearPattern');
        }

        String query =
            'SELECT Id, ' +
            '       ucinn_ascendv2__Contact__r.Id, ' +
            '       ucinn_ascendv2__Contact__r.Name, ' +
            '       ucinn_ascendv2__Contact__r.HAM_Profile_Picture_URL__c, ' +
            '       ucinn_ascendv2__Major_Degree_Formula__c, ' +
            '       ucinn_ascendv2__Contact__r.HAM_Reunion_Year__c ' +
            'FROM ucinn_ascendv2__Degree_Information__c ' +
            'WHERE ' + String.join(whereClauses, ' AND ') +
            ' WITH SECURITY_ENFORCED ' +
            'LIMIT 50';

        System.debug('[miltonAlumniSearchAction] buildResponse query: ' + query);

        List<ucinn_ascendv2__Degree_Information__c> records;
        try {
            records = Database.query(query);
            System.debug('[miltonAlumniSearchAction] buildResponse records returned: ' + records.size());
        } catch (Exception e) {
            System.debug('[miltonAlumniSearchAction] buildResponse query threw: ' + e.getMessage());
            resp.isSuccess = false;
            resp.totalCount = 0;
            resp.statusMessage = 'An error occurred while searching alumni records: ' + e.getMessage();
            return resp;
        }

        Set<Id> alumniContactIds = new Set<Id>();
        for (ucinn_ascendv2__Degree_Information__c rec : records) {
            if (rec.ucinn_ascendv2__Contact__r != null) {
                alumniContactIds.add(rec.ucinn_ascendv2__Contact__r.Id);
            }
        }
        Map<Id, miltonAlumniConnectionAction.ConnectionFlags> flagsByContactId =
            miltonAlumniConnectionAction.getConnectionFlags(viewerContactId, new List<Id>(alumniContactIds));

        for (ucinn_ascendv2__Degree_Information__c rec : records) {
            miltonAlumniResult ar = new miltonAlumniResult();
            ar.recordId = rec.Id;

            if (rec.ucinn_ascendv2__Contact__r != null) {
                ar.contactId           = rec.ucinn_ascendv2__Contact__r.Id;
                ar.alumniName          = rec.ucinn_ascendv2__Contact__r.Name;
                ar.profilePictureUrl   = rec.ucinn_ascendv2__Contact__r.HAM_Profile_Picture_URL__c;
                ar.classOfYear         = rec.ucinn_ascendv2__Contact__r.HAM_Reunion_Year__c != null
                                            ? String.valueOf(rec.ucinn_ascendv2__Contact__r.HAM_Reunion_Year__c)
                                            : null;

                miltonAlumniConnectionAction.ConnectionFlags flags = flagsByContactId.get(rec.ucinn_ascendv2__Contact__r.Id);
                if (flags != null) {
                    ar.isConnected      = flags.isConnected;
                    ar.isBookmarked     = flags.isBookmarked;
                    ar.isRequestSent    = flags.isRequestSent;
                    ar.isActive         = flags.isActive;
                    ar.isSelf           = flags.isSelf;
                }
            }
            ar.majorDegree = rec.ucinn_ascendv2__Major_Degree_Formula__c;

            resp.alumniRecords.add(ar);
        }

        resp.totalCount     = resp.alumniRecords.size();
        resp.isSuccess      = true;
        resp.statusMessage  = resp.totalCount + ' alumni record(s) found.';
        System.debug('[miltonAlumniSearchAction] buildResponse final: totalCount=' + resp.totalCount
            + ', statusMessage=' + resp.statusMessage);
        return resp;
    }

    private static AlumniSearchOutput wrap(miltonAlumniSearchResponse resp) {
        AlumniSearchOutput output = new AlumniSearchOutput();
        output.result = resp;
        return output;
    }
}