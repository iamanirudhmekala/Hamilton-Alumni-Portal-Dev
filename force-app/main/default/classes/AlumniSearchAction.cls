/**
 * AlumniSearchAction
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
public with sharing class AlumniSearchAction {

    // ---------- INPUT ----------
    public class AlumniSearchRequest {
        @InvocableVariable(label='Alumni Name' description='Full or partial contact name' required=false)
        public String alumniName;

        @InvocableVariable(label='Major / Degree' description='Full or partial major/degree text' required=false)
        public String majorDegree;

        @InvocableVariable(label='Class of Year' description='Graduation year' required=false)
        public String classOfYear;
    }

    // ---------- OUTPUT (per record) ----------
    public class AlumniResult {
        @InvocableVariable(label='Record Id')
        public String recordId;

        @InvocableVariable(label='Contact Id')
        public String contactId;

        @InvocableVariable(label='Alumni Name')
        public String alumniName;

        @InvocableVariable(label='Profile Picture URL')
        public String profilePictureUrl;

        @InvocableVariable(label='Major / Degree')
        public String majorDegree;

        @InvocableVariable(label='Class of Year')
        public String classOfYear;
    }

    // ---------- OUTPUT (wrapper) ----------
    public class AlumniSearchResponse {
        @InvocableVariable(label='Alumni Records')
        public List<AlumniResult> alumniRecords;

        @InvocableVariable(label='Total Count')
        public Integer totalCount;

        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Status Message')
        public String statusMessage;
    }

    @InvocableMethod(
        label='Search Alumni'
        description='Searches Alumni Degree Information records by name, major/degree, and/or class of year. Requires at least one parameter.'
        category='Alumni'
    )
    public static List<AlumniSearchResponse> searchAlumni(List<AlumniSearchRequest> requests) {
        List<AlumniSearchResponse> responses = new List<AlumniSearchResponse>();

        for (AlumniSearchRequest req : requests) {
            AlumniSearchResponse resp = new AlumniSearchResponse();
            resp.alumniRecords = new List<AlumniResult>();

            String name   = req.alumniName;
            String degree = req.majorDegree;
            String year   = req.classOfYear;

            // Safety-net validation (topic should already enforce this)
            if (String.isBlank(name) && String.isBlank(degree) && String.isBlank(year)) {
                resp.isSuccess = false;
                resp.totalCount = 0;
                resp.statusMessage = 'No search criteria provided. Please provide at least one of: name, major/degree, or class of year.';
                responses.add(resp);
                continue;
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

            List<ucinn_ascendv2__Degree_Information__c> records;
            try {
                records = Database.query(query);
            } catch (Exception e) {
                resp.isSuccess = false;
                resp.totalCount = 0;
                resp.statusMessage = 'An error occurred while searching alumni records: ' + e.getMessage();
                responses.add(resp);
                continue;
            }

            for (ucinn_ascendv2__Degree_Information__c rec : records) {
                AlumniResult ar = new AlumniResult();
                ar.recordId = rec.Id;

                if (rec.ucinn_ascendv2__Contact__r != null) {
                    ar.contactId           = rec.ucinn_ascendv2__Contact__r.Id;
                    ar.alumniName          = rec.ucinn_ascendv2__Contact__r.Name;
                    ar.profilePictureUrl   = rec.ucinn_ascendv2__Contact__r.HAM_Profile_Picture_URL__c;
                    ar.classOfYear         = rec.ucinn_ascendv2__Contact__r.HAM_Reunion_Year__c != null
                                                ? String.valueOf(rec.ucinn_ascendv2__Contact__r.HAM_Reunion_Year__c)
                                                : null;
                }
                ar.majorDegree = rec.ucinn_ascendv2__Major_Degree_Formula__c;

                resp.alumniRecords.add(ar);
            }

            resp.totalCount     = resp.alumniRecords.size();
            resp.isSuccess      = true;
            resp.statusMessage  = resp.totalCount + ' alumni record(s) found.';
            responses.add(resp);
        }

        return responses;
    }
}