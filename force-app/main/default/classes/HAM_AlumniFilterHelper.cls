/**
 * @description Helper class to handle complex filter logic for Alumni Directory.
 * Fetches dynamic filter values and builds complex SOQL WHERE clauses.
 */
@SuppressWarnings('PMD.ApexCRUDViolation,PMD.StdCyclomaticComplexity, PMD.CyclomaticComplexity, PMD.CognitiveComplexity, PMD.NcssCount, PMD.ExcessiveParameterList, PMD.AvoidDebugStatements')
 public inherited sharing class HAM_AlumniFilterHelper {

    /**
     * @description Fetches dropdown options from live Salesforce data or Global Picklists.
     * @param placeholder The name of the filter field (e.g., 'Class Year', 'Employer').
     * @return A sorted List of Strings containing the filter options.
     */
    public static List<String> getDynamicValues(String placeholder) {
        Set<String> values = new set<String>();

        switch on placeholder {
            // 1. CLASS YEAR — dynamic range: lower bound 1945, upper bound currentYear+4
            when 'Class Year' {
                List<String> years = new List<String>();
                Integer upperYear = Date.today().year() + 4;
                // Descending order (newest first)
                for (Integer y = upperYear; y >= 1945; y--) {
                    years.add(String.valueOf(y));
                }
                return years;
            }

            // 2. INDUSTRY (Picklist)
            when 'Industry' {
                return getPicklistValues('Contact', 'HAM_Industry__c');
            }

            // 3. EMPLOYER (Top 500 Most Common Accounts)
            when 'Employer' {
                // Aggregate query ensures unique names and governor limit safety
                for (AggregateResult ar : [SELECT Name
                                           FROM Account
                                           WHERE RecordType.DeveloperName = 'Corporations_and_Organizations'//'New_Corporations_and_Organizations'
                                           GROUP BY Name
                                           ORDER BY COUNT(Id) DESC
                                           LIMIT 500]) {
                    values.add((String)ar.get('Name'));
                }
            }

            // 4. JOB TITLE (Top 500 Most Common from both fields)
            when 'Job Title' {
                
                // Fetch from Standard Field
                for (AggregateResult ar : [SELECT Job_Title__c
                                           FROM Contact
                                           WHERE Job_Title__c != null
                                           GROUP BY Job_Title__c
                                           ORDER BY COUNT(Id) DESC
                                           LIMIT 400]) {
                    values.add((String)ar.get('Job_Title__c'));
                }
                
                // Fetch from LiveAlumni Field
                for (AggregateResult ar : [SELECT HAM_LiveAlumni_Job_Title__c
                                           FROM Contact
                                           WHERE HAM_LiveAlumni_Job_Title__c != null
                                           GROUP BY HAM_LiveAlumni_Job_Title__c
                                           ORDER BY COUNT(Id) DESC
                                           LIMIT 400]) {
                    values.add((String)ar.get('HAM_LiveAlumni_Job_Title__c'));
                }
            }

            // 5. SPORTS ASSOCIATION (Category = 'Student NCAA Athletics')
            when 'Sports Association' {
                for(ucinn_ascendv2__Involvement_Value__c val : [SELECT ucinn_ascendv2__Involvement_Description__c
                                                                FROM ucinn_ascendv2__Involvement_Value__c
                                                                WHERE ucinn_ascendv2__End_Date__c = null
                                                                AND HAM_Category__c = 'Student NCAA Athletics'
                                                                ORDER BY ucinn_ascendv2__Involvement_Description__c]) {
                    values.add(val.ucinn_ascendv2__Involvement_Description__c);
                }
            }

            // 6. STUDENT ORGANIZATIONS (Category = 'Student Clubs', 'Student Private Societies')
            when 'Student Organizations' {
                for(ucinn_ascendv2__Involvement_Value__c val : [SELECT ucinn_ascendv2__Involvement_Description__c
                                                                FROM ucinn_ascendv2__Involvement_Value__c
                                                                WHERE ucinn_ascendv2__End_Date__c = null
                                                                AND (HAM_Category__c = 'Student Clubs' OR HAM_Category__c = 'Student Private Societies')
                                                                ORDER BY ucinn_ascendv2__Involvement_Description__c]) {
                    values.add(val.ucinn_ascendv2__Involvement_Description__c);
                }
            }

            // 7. REGION (From Chapter Lookup records)
            when 'Region' {
                for(HAM_Chapter_Lookup__c chap : [SELECT Name FROM HAM_Chapter_Lookup__c WHERE Name != 'Unassigned Chapter' ORDER BY Name]) {
                    values.add(chap.Name);
                }
            }

            // 8. VOLUNTEER ROLE (All Active Involvements)
            when 'Volunteer Role' {
                for(ucinn_ascendv2__Involvement_Value__c val : [SELECT ucinn_ascendv2__Involvement_Description__c
                                                                FROM ucinn_ascendv2__Involvement_Value__c
                                                                WHERE ucinn_ascendv2__End_Date__c = null
                                                                AND (HAM_Category__c = 'Event' OR HAM_Category__c = 'Fundraising' OR HAM_Category__c = 'Career Center')
                                                                ORDER BY ucinn_ascendv2__Involvement_Description__c]) {
                    values.add(val.ucinn_ascendv2__Involvement_Description__c);
                }
            }

            // 9. ALUMNI COMMITTEE (Category = 'Alumni Council')
            when 'Alumni Committee' {
                for(ucinn_ascendv2__Involvement_Value__c val : [SELECT ucinn_ascendv2__Involvement_Description__c
                                                                FROM ucinn_ascendv2__Involvement_Value__c
                                                                WHERE ucinn_ascendv2__End_Date__c = null
                                                                AND (HAM_Category__c = 'Alumni Council' OR HAM_Category__c = 'Volunteer Committee')
                                                                AND Ham_Display_On_The_Portal__c = true
                                                                ORDER BY ucinn_ascendv2__Involvement_Description__c]) {
                    values.add(val.ucinn_ascendv2__Involvement_Description__c);
                }
            }

            // 10. MAJOR (Distinct values from Degree Info)
            when 'Major' {
                for(ucinn_ascendv2__Post_Code__c major : [SELECT ucinn_ascendv2__Major_Specialty_Description__c
                                          FROM ucinn_ascendv2__Post_Code__c
                                          WHERE ucinn_ascendv2__Major_Specialty_Description__c != null
                                          ORDER BY ucinn_ascendv2__Major_Specialty_Description__c]) {
                    values.add(major.ucinn_ascendv2__Major_Specialty_Description__c);
                }
            }

            // 11. STATIC OPTIONS
            when 'Trustee', 'Couper Guild' {
                return new List<String>{'Yes', 'No'};
            }

            when else {
                return null;
            }
        }
        List<String> sortedList = new List<String>(values);
        sortedList.sort();
        return sortedList;
    }

    /**
     * @description Performs a type-ahead search for values not found in the initial top 500.
     * @param placeholder The filter category.
     * @param searchTerm The string typed by the user.
     * @return List of matching strings.
     */
    public static List<String> searchDynamicValues(String placeholder, String searchTerm) {
        Set<String> values = new Set<String>();
        String searchLike = '%' + String.escapeSingleQuotes(searchTerm) + '%';

        switch on placeholder {
            // CLASS YEAR search — filters all picklist year values by the typed term,
            // allowing years below 1945 (e.g. 1921) to be found via search.
            when 'Class Year' {
                String term = searchTerm == null ? '' : searchTerm.trim();
                if (String.isBlank(term)) {
                    return new List<String>();
                }
                List<String> allPicklistYears = getPicklistValues('Contact', 'ucinn_ascendv2__Birth_Year__c');
                List<String> results = new List<String>();
                for (String yr : allPicklistYears) {
                    if (yr.contains(term)) {
                        results.add(yr);
                    }
                }
                return results;
            }
            when 'Employer' {
                for (AggregateResult ar : [SELECT Name FROM Account
                                           WHERE RecordType.DeveloperName = 'Corporations_and_Organizations'//'New_Corporations_and_Organizations'
                                           AND Name LIKE :searchLike
                                           GROUP BY Name ORDER BY Name ASC LIMIT 50]) {
                    values.add((String)ar.get('Name'));
                }
            }
            when 'Job Title' {
                for (AggregateResult ar : [SELECT Job_Title__c FROM Contact
                                           WHERE Job_Title__c LIKE :searchLike GROUP BY Job_Title__c LIMIT 50]) {
                    values.add((String)ar.get('Job_Title__c'));
                }
                for (AggregateResult ar : [SELECT HAM_LiveAlumni_Job_Title__c FROM Contact
                                           WHERE HAM_LiveAlumni_Job_Title__c LIKE :searchLike GROUP BY HAM_LiveAlumni_Job_Title__c LIMIT 50]) {
                    values.add((String)ar.get('HAM_LiveAlumni_Job_Title__c'));
                }
            }
        }
        List<String> sortedList = new List<String>(values);
        sortedList.sort();
        return sortedList;
    }

    /**
     * @description Constructs dynamic SOQL WHERE clauses for complex filter logic.
     * @param placeholder Filter category.
     * @param values Selected values.
     * @param relationshipLookup Field API name for subqueries.
     * @param relationshipPrefix Prefix for cross-object fields.
     * @return A string representing the WHERE clause segment.
     */
    public static String getSpecificWhereClause(String placeholder, List<String> values, String relationshipLookup, String relationshipPrefix) {
        if (values == null || values.isEmpty()) {
            return '';
        }

        List<String> safeValues = new List<String>();
        for (String v : values) {
            safeValues.add(String.escapeSingleQuotes(v));
        }
        String inClause = '(\'' + String.join(safeValues, '\',\'') + '\')';

        // Ensure prefix isn't null so we can safely append
        String prefix = String.isNotBlank(relationshipPrefix) ? relationshipPrefix : '';

        switch on placeholder {
            // STRICT PREFERENCE: Check Primary -> If Null, Check Secondary
            when 'Employer' {
                return '( (' + prefix + 'Constituent_Employer__r.Name IN ' + inClause + ') OR ((' + prefix + 'Constituent_Employer__c = NULL OR ' + prefix + 'Constituent_Employer__c = \'\') AND ' + prefix + 'HAM_LiveAlumni_Employer__c IN ' + inClause + ') )';
            }
            when 'Job Title' {
               return '( (' + prefix + 'Job_Title__c IN ' + inClause + ') OR ((' + prefix + 'Job_Title__c = NULL OR ' + prefix + 'Job_Title__c = \'\') AND ' + prefix + 'HAM_LiveAlumni_Job_Title__c IN ' + inClause + ') )';
             }

            // REGION: Subquery against HAM_Current_Chapter__c junction object.
            // Matches any constituent who has an active chapter record matching the selected region(s).
            when 'Region' {
                return relationshipLookup + ' IN (SELECT Constituent__c FROM HAM_Current_Chapter__c WHERE Chapter__r.Name IN ' + inClause + ' AND Is_Active__c = true)';
            }

            // VOLUNTEER ROLE: Fiscal Year Logic (July 1 - June 30)
            when 'Volunteer Role' {
                Date today = Date.today();
                Integer startYear = (today.month() >= 7) ? today.year() : today.year() - 1;
                // FY Start: July 1st of startYear. FY End: June 30th of next year.

                String fyStart = startYear + '-07-01';
                String fyEnd = (startYear + 1) + '-06-30';

                return relationshipLookup + ' IN (SELECT ucinn_ascendv2__Contact__c FROM ucinn_ascendv2__Involvement__c ' +
                       'WHERE ucinn_ascendv2__Involvement_Code_Description_Formula__c IN ' + inClause +
                       ' AND ucinn_ascendv2__Start_Date__c <= ' + fyEnd +
                       ' AND (ucinn_ascendv2__End_Date__c >= ' + fyStart + ' OR ucinn_ascendv2__End_Date__c = null))';
            }

            // GENERIC ACTIVE INVOLVEMENT (Sports, Student Orgs, Committee)
            when 'Alumni Committee', 'Student Organizations', 'Sports Association' {
                return relationshipLookup + ' IN (SELECT ucinn_ascendv2__Contact__c FROM ucinn_ascendv2__Involvement__c ' +
                       'WHERE ucinn_ascendv2__Involvement_Code_Description_Formula__c IN ' + inClause +
                       ' AND ucinn_ascendv2__End_Date__c = null)';
            }

            // MAJOR: Degree Info
            when 'Major' {
                return relationshipLookup+ ' IN (SELECT ucinn_ascendv2__Contact__c FROM ucinn_ascendv2__Degree_Information__c '+
                'WHERE ( ucinn_ascendv2__Major_Formula__c IN ' + inClause +
                ' OR ucinn_ascendv2__Second_Major_Formula__c IN ' + inClause +
                ' OR Third_Concentration_Formula__c IN ' + inClause + ' ) )';
            }

            // COUPER GUILD: Yes/No Subquery
            when 'Couper Guild' {
                if (safeValues.contains('Yes')) {
                    return relationshipLookup + ' IN (SELECT ucinn_ascendv2__Contact__c FROM ucinn_ascendv2__Involvement__c WHERE ucinn_ascendv2__Involvement_Code_Description_Formula__c = \'Couper Guild\' AND ucinn_ascendv2__End_Date__c = null)';
                } else if (safeValues.contains('No')) {
                    return relationshipLookup + ' NOT IN (SELECT ucinn_ascendv2__Contact__c FROM ucinn_ascendv2__Involvement__c WHERE ucinn_ascendv2__Involvement_Code_Description_Formula__c = \'Couper Guild\' AND ucinn_ascendv2__End_Date__c != null)';
                }
                return '';
            }

            // TRUSTEE: Direct Field Toggle
            when 'Trustee' {
                if (safeValues.contains('Yes')) {
                    return prefix + 'ucinn_ascendv2__Primary_Contact_Type__c = \'Trustee\'';
                }
                if (safeValues.contains('No')) {
                    return prefix + 'ucinn_ascendv2__Primary_Contact_Type__c != \'Trustee\'';
                }
                return '';
            }

            // FALLBACK: Return Null to use Metadata Field Mapping (e.g. Class Year Text Search, Industry)
            when else {
                return null;
            }
        }
    }

    /**
     * @description Utility to fetch picklist values using Schema describes.
     * @param sObjName Object API Name.
     * @param fieldName Field API Name.
     * @return List of active picklist values.
     */
    private static List<String> getPicklistValues(String sObjName, String fieldName) {
         List<String> values = new List<String>();
         try {
             Schema.SObjectType s = Schema.getGlobalDescribe().get(sObjName);
             Schema.DescribeSObjectResult r = s.getDescribe();
             Map<String,Schema.SObjectField> fields = r.fields.getMap();
             if(fields.containsKey(fieldName)) {
                 for(Schema.PicklistEntry p : fields.get(fieldName).getDescribe().getPicklistValues()) {
                     if(p.isActive()) {
                        values.add(p.getValue());
                     }
                 }
             }
         } catch(Exception e) {
            System.debug(LoggingLevel.ERROR,'Picklist Error: ' + e.getMessage());
         }
         return values;
    }
}