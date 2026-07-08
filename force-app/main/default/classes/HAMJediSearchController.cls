/**
 * HAMJediSearchController
 *
 * v3.1 - 2026-04-23 - Added fuzzy name search fallback via ucinn_ascendv2__Contact_Name__c
 *                     When primary name search returns no results, splits search tokens
 *                     and matches each against ucinn_ascendv2__Constructed_Name_Formula__c
 *                     (e.g. "Dan Nye" matches "Dan T.H. Nye").
 * v3.2 - 2026-05-06 - ASC-13451: Added ucinn_ascendv2__Is_Deceased__c to all searchContact
 *                     SOQL queries (simple, involvement, fuzzy, fuzzy+involvement) so the
 *                     LWC can render deceased (D) and Hamilton Withdrawn (HW) visual badges.
 */
// 05/06/2026 NVV: ASC-13451 - Added Is_Deceased__c to search queries; removed debug logs; added ApexDoc
public with sharing class HAMJediSearchController {

    /**
     * @description Searches Contact records by name, email, phone, donor ID, class year,
     *              sports association, or student organization. Falls back to fuzzy name
     *              search via Contact_Name__c when primary name search returns no results.
     * @param searchStr Free-text input searched against name, email, or phone fields.
     * @param donorId Donor ID to match exactly.
     * @param classYear Reunion year filter value.
     * @param sportsAssociation NCAA Athletics involvement description filter.
     * @param studentOrganization Student club/society involvement description filter.
     * @param contactId Explicit Contact Id (from record picker).
     * @return List of matching Contact records ordered by HAM_Name_w_Suffix__c.
     */
    @AuraEnabled(cacheable=false)
    public static List<Contact> searchContact(string searchStr, string donorId, string classYear, string sportsAssociation, string studentOrganization, string contactId) {

        List<String> whereConditions = new List<String>();

        // Track whether this is a name search (eligible for fuzzy fallback)
        Boolean isNameSearch = false;

        // Smart search: detect if searching by email, phone, or name
        if(String.isNotBlank(searchStr)){
            String escapedSearchStr = String.escapeSingleQuotes(searchStr);

            // Check if search string contains @ (email search)
            if(searchStr.contains('@')) {
                whereConditions.add('(HAM_PreferredEmail__c LIKE \'%' + escapedSearchStr + '%\' OR Email LIKE \'%' + escapedSearchStr + '%\')');
            }
            // Check if search string contains only numbers and common phone separators (phone search)
            else if(searchStr.replaceAll('[^0-9]', '').length() >= 3 && searchStr.replaceAll('[^a-zA-Z]', '').length() == 0) {
                String numericSearch = searchStr.replaceAll('[^0-9]', '');
                whereConditions.add('(HAM_Formatted_Phone__c LIKE \'%' + String.escapeSingleQuotes(numericSearch) + '%\' OR Phone LIKE \'%' + escapedSearchStr + '%\')');
            }
            // Default to name search
            else {
                whereConditions.add('(HAM_Name_w_Suffix__c LIKE \'%' + escapedSearchStr + '%\' OR FirstName LIKE \'%' + escapedSearchStr + '%\' OR LastName LIKE \'%' + escapedSearchStr + '%\')');
                isNameSearch = true;
            }
        }

        // Add donor ID condition
        if(String.isNotBlank(donorId)){
            whereConditions.add('ucinn_ascendv2__Donor_ID__c = \'' + String.escapeSingleQuotes(donorId) + '\'');
        }

        // Add Class Year condition
        if(String.isNotBlank(classYear)){
            whereConditions.add('HAM_Reunion_Year__c = \'' + String.escapeSingleQuotes(classYear) + '\'');
        }

        // Add Contact ID condition (from record picker)
        if(String.isNotBlank(contactId)){
            whereConditions.add('Id = \'' + String.escapeSingleQuotes(contactId) + '\'');
        }

        // Check if we have involvement filters
        Boolean hasSportsAssociation = String.isNotBlank(sportsAssociation);
        Boolean hasStudentOrganization = String.isNotBlank(studentOrganization);
        Boolean hasInvolvementFilters = hasSportsAssociation || hasStudentOrganization;

        if(whereConditions.isEmpty() && !hasInvolvementFilters) {
            return new List<Contact>();
        }

        if(!hasInvolvementFilters) {
            // Simple query without involvement join
            String queryString = 'SELECT ID, Name, FirstName, LastName, Email, HAM_Name_w_Suffix__c, HAM_Institutional_Suffix__c, ucinn_ascendv2__Primary_Contact_Type__c, ucinn_ascendv2__Is_Deceased__c, ucinn_ascendv2__Donor_ID__c, HAM_PreferredEmail__c, HAM_Formatted_Phone__c, Phone FROM Contact WHERE ';
            queryString += String.join(whereConditions, ' AND ');
            queryString += ' ORDER BY HAM_Name_w_Suffix__c ASC';

            List<Contact> constitiuents = Database.query(queryString);

            // --- FUZZY FALLBACK ---
            if(constitiuents.isEmpty() && isNameSearch && String.isNotBlank(searchStr)) {
                constitiuents = fuzzyNameSearch(searchStr, whereConditions);
            }

            return constitiuents;
        }

        // INVOLVEMENT FILTERS LOGIC
        Set<Id> sportsContactIds = new Set<Id>();
        Set<Id> organizationContactIds = new Set<Id>();
        Set<Id> finalContactIds = new Set<Id>();

        // Query for Sports Association
        if(hasSportsAssociation) {
            String sportsQuery = 'SELECT ucinn_ascendv2__Contact__c FROM ucinn_ascendv2__Involvement__c WHERE ucinn_ascendv2__Involvement_Code_Description_Formula__c = \'' + String.escapeSingleQuotes(sportsAssociation) + '\'';

            List<ucinn_ascendv2__Involvement__c> sportsInvolvements = Database.query(sportsQuery);

            for(ucinn_ascendv2__Involvement__c inv : sportsInvolvements) {
                if(inv.ucinn_ascendv2__Contact__c != null) {
                    sportsContactIds.add(inv.ucinn_ascendv2__Contact__c);
                }
            }
        }

        // Query for Student Organization
        if(hasStudentOrganization) {
            String orgQuery = 'SELECT ucinn_ascendv2__Contact__c FROM ucinn_ascendv2__Involvement__c WHERE ucinn_ascendv2__Involvement_Code_Description_Formula__c = \'' + String.escapeSingleQuotes(studentOrganization) + '\'';

            List<ucinn_ascendv2__Involvement__c> orgInvolvements = Database.query(orgQuery);

            for(ucinn_ascendv2__Involvement__c inv : orgInvolvements) {
                if(inv.ucinn_ascendv2__Contact__c != null) {
                    organizationContactIds.add(inv.ucinn_ascendv2__Contact__c);
                }
            }
        }

        // Combine results using OR logic: union of both sets
        if(hasSportsAssociation && hasStudentOrganization) {
            finalContactIds = new Set<Id>(sportsContactIds);
            finalContactIds.addAll(organizationContactIds);
        } else if(hasSportsAssociation) {
            finalContactIds = sportsContactIds;
        } else if(hasStudentOrganization) {
            finalContactIds = organizationContactIds;
        }

        if(finalContactIds.isEmpty()) {
            return new List<Contact>();
        }

        // Add contact ID condition
        whereConditions.add('ID IN (\'' + String.join(new List<Id>(finalContactIds), '\',\'') + '\')');

        String queryString = 'SELECT ID, Name, FirstName, LastName, Email, HAM_Name_w_Suffix__c, HAM_Institutional_Suffix__c, ucinn_ascendv2__Primary_Contact_Type__c, ucinn_ascendv2__Is_Deceased__c, ucinn_ascendv2__Donor_ID__c, HAM_PreferredEmail__c, HAM_Formatted_Phone__c, Phone FROM Contact WHERE ';
        queryString += String.join(whereConditions, ' AND ');
        queryString += ' ORDER BY HAM_Name_w_Suffix__c ASC';

        List<Contact> constitiuents = Database.query(queryString);

        // --- FUZZY FALLBACK (with involvement filters) ---
        if(constitiuents.isEmpty() && isNameSearch && String.isNotBlank(searchStr)) {
            constitiuents = fuzzyNameSearchWithInvolvement(searchStr, whereConditions, finalContactIds);
        }

        return constitiuents;
    }

    /**
     * Fuzzy name fallback (no involvement filters).
     * 
     * Splits the searchStr into space-delimited tokens and queries
     * ucinn_ascendv2__Contact_Name__c where ucinn_ascendv2__Constructed_Name_Formula__c
     * contains ALL tokens (AND logic). The resulting Contact IDs replace the original
     * name LIKE condition, while all other filters (donorId, classYear, contactId) are
     * preserved from whereConditions (minus the first/name condition).
     * 
     * Example: searchStr = "Dan Nye"
     *   Tokens: ["Dan", "Nye"]
     *   ContactName query: ...WHERE ucinn_ascendv2__Constructed_Name_Formula__c LIKE '%Dan%'
     *                           AND ucinn_ascendv2__Constructed_Name_Formula__c LIKE '%Nye%'
     *   => Matches "Dan T.H. Nye" => returns Contact via ucinn_ascendv2__Contact__c
     */
    private static List<Contact> fuzzyNameSearch(String searchStr, List<String> allWhereConditions) {
        Set<Id> fuzzyContactIds = getFuzzyContactIds(searchStr);

        if(fuzzyContactIds.isEmpty()) {
            return new List<Contact>();
        }

        // Rebuild where conditions: drop the original name LIKE (index 0), keep all others,
        // then add the fuzzy ID set
        List<String> fuzzyConditions = new List<String>();
        // allWhereConditions[0] was the name LIKE clause — skip it, carry forward the rest
        for(Integer i = 1; i < allWhereConditions.size(); i++) {
            fuzzyConditions.add(allWhereConditions.get(i));
        }
        fuzzyConditions.add('ID IN (\'' + String.join(new List<Id>(fuzzyContactIds), '\',\'') + '\')');

        String fuzzyQuery = 'SELECT ID, Name, FirstName, LastName, Email, HAM_Name_w_Suffix__c, HAM_Institutional_Suffix__c, ucinn_ascendv2__Primary_Contact_Type__c, ucinn_ascendv2__Is_Deceased__c, ucinn_ascendv2__Donor_ID__c, HAM_PreferredEmail__c, HAM_Formatted_Phone__c, Phone FROM Contact WHERE ';
        fuzzyQuery += String.join(fuzzyConditions, ' AND ');
        fuzzyQuery += ' ORDER BY HAM_Name_w_Suffix__c ASC';

        List<Contact> results = Database.query(fuzzyQuery);
        return results;
    }

    /**
     * Fuzzy name fallback with involvement filters already applied.
     * Intersects fuzzy Contact IDs with the involvement-filtered finalContactIds.
     */
    private static List<Contact> fuzzyNameSearchWithInvolvement(String searchStr, List<String> allWhereConditions, Set<Id> involvementContactIds) {
        Set<Id> fuzzyContactIds = getFuzzyContactIds(searchStr);

        if(fuzzyContactIds.isEmpty()) {
            return new List<Contact>();
        }

        // Intersect fuzzy hits with involvement-filtered IDs
        fuzzyContactIds.retainAll(involvementContactIds);

        if(fuzzyContactIds.isEmpty()) {
            return new List<Contact>();
        }

        // Rebuild conditions: drop name LIKE (index 0) and the last involvement ID IN
        // clause (last item added before this call), keep middle filters, re-add fuzzy IDs
        List<String> fuzzyConditions = new List<String>();
        for(Integer i = 1; i < allWhereConditions.size() - 1; i++) {
            fuzzyConditions.add(allWhereConditions.get(i));
        }
        fuzzyConditions.add('ID IN (\'' + String.join(new List<Id>(fuzzyContactIds), '\',\'') + '\')');

        String fuzzyQuery = 'SELECT ID, Name, FirstName, LastName, Email, HAM_Name_w_Suffix__c, HAM_Institutional_Suffix__c, ucinn_ascendv2__Primary_Contact_Type__c, ucinn_ascendv2__Is_Deceased__c, ucinn_ascendv2__Donor_ID__c, HAM_PreferredEmail__c, HAM_Formatted_Phone__c, Phone FROM Contact WHERE ';
        fuzzyQuery += String.join(fuzzyConditions, ' AND ');
        fuzzyQuery += ' ORDER BY HAM_Name_w_Suffix__c ASC';

        List<Contact> results = Database.query(fuzzyQuery);
        return results;
    }

    /**
     * Queries ucinn_ascendv2__Contact_Name__c for records where
     * ucinn_ascendv2__Constructed_Name_Formula__c contains ALL space-delimited tokens
     * in the search string. Returns the set of related Contact IDs.
     */
    private static Set<Id> getFuzzyContactIds(String searchStr) {
        // Split on one or more spaces, remove blanks
        List<String> rawTokens = searchStr.trim().split('\\s+');
        List<String> tokens = new List<String>();
        for(String t : rawTokens) {
            if(String.isNotBlank(t)) {
                tokens.add(t);
            }
        }

        if(tokens.isEmpty()) {
            return new Set<Id>();
        }

        // Build AND conditions — each token must appear somewhere in the constructed name
        List<String> tokenConditions = new List<String>();
        for(String token : tokens) {
            tokenConditions.add('ucinn_ascendv2__Constructed_Name_Formula__c LIKE \'%' + String.escapeSingleQuotes(token) + '%\'');
        }

        String contactNameQuery = 'SELECT ucinn_ascendv2__Contact__c FROM ucinn_ascendv2__Contact_Name__c WHERE '
            + String.join(tokenConditions, ' AND ');

        List<ucinn_ascendv2__Contact_Name__c> nameRecords = Database.query(contactNameQuery);

        Set<Id> contactIds = new Set<Id>();
        for(ucinn_ascendv2__Contact_Name__c cn : nameRecords) {
            if(cn.ucinn_ascendv2__Contact__c != null) {
                contactIds.add(cn.ucinn_ascendv2__Contact__c);
            }
        }
        return contactIds;
    }

    /**
     * @description Returns up to 10 Contact records most recently viewed by the current user.
     * @return List of recently viewed Contact records ordered by LastViewedDate descending.
     */
    @AuraEnabled(cacheable=true)
    public static List<Contact> searchRecentRecords() {
        List<Contact> recentlyViewedRecords= [SELECT ID, Name,HAM_Name_w_Suffix__c,ucinn_ascendv2__Donor_ID__c FROM Contact WHERE LastViewedDate != NULL ORDER BY LastViewedDate DESC Limit 10];
        return recentlyViewedRecords;
    }

    /**
     * @description Returns all distinct class year (HAM_Reunion_Year__c) values present on Contact records.
     * @return List of class year strings ordered ascending.
     */
    @AuraEnabled(cacheable=true)
    public static List<String> getClassYearOptions() {
        List<String> classYears = new List<String>();

        try {
            List<AggregateResult> results = [
                SELECT HAM_Reunion_Year__c
                FROM Contact
                WHERE HAM_Reunion_Year__c != null
                GROUP BY HAM_Reunion_Year__c
                ORDER BY HAM_Reunion_Year__c DESC
            ];

            for (AggregateResult ar : results) {
                String year = (String)ar.get('HAM_Reunion_Year__c');
                if (String.isNotBlank(year)) {
                    classYears.add(year);
                }
            }

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving class year options: ' + e.getMessage());
        }

        return classYears;
    }

    /**
     * @description Returns all distinct sports association descriptions from Involvement_Value__c
     *              records categorised as Student NCAA Athletics.
     * @return List of sports association description strings ordered ascending.
     */
    @AuraEnabled(cacheable=true)
    public static List<String> getSportsAssociationOptions() {
        List<String> sportsAssociations = new List<String>();

        try {
            List<ucinn_ascendv2__Involvement_Value__c> results = [
                SELECT id, Name, HAM_Category__c, ucinn_ascendv2__Involvement_Description__c, ucinn_ascendv2__Type__c
                FROM ucinn_ascendv2__Involvement_Value__c
                WHERE HAM_Category__c = 'Student NCAA Athletics'
                ORDER BY ucinn_ascendv2__Involvement_Description__c ASC
            ];

            for (ucinn_ascendv2__Involvement_Value__c record : results) {
                String description = record.ucinn_ascendv2__Involvement_Description__c;
                if (String.isNotBlank(description) && !sportsAssociations.contains(description)) {
                    sportsAssociations.add(description);
                }
            }

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving sports association options: ' + e.getMessage());
        }

        return sportsAssociations;
    }

    /**
     * @description Returns all distinct student organization descriptions from Involvement_Value__c
     *              records categorised as Student Clubs or Student Private Societies.
     * @return List of student organization description strings ordered ascending.
     */
    @AuraEnabled(cacheable=true)
    public static List<String> getStudentOrganizationsOptions() {
        List<String> studentOrganizations = new List<String>();

        try {
            List<ucinn_ascendv2__Involvement_Value__c> results = [
                SELECT id, Name, HAM_Category__c, ucinn_ascendv2__Involvement_Description__c, ucinn_ascendv2__Type__c
                FROM ucinn_ascendv2__Involvement_Value__c
                WHERE HAM_Category__c = 'Student Clubs' OR HAM_Category__c = 'Student Private Societies'
                ORDER BY ucinn_ascendv2__Involvement_Description__c ASC
            ];

            for (ucinn_ascendv2__Involvement_Value__c record : results) {
                String description = record.ucinn_ascendv2__Involvement_Description__c;
                if (String.isNotBlank(description) && !studentOrganizations.contains(description)) {
                    studentOrganizations.add(description);
                }
            }

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving student organizations options: ' + e.getMessage());
        }

        return studentOrganizations;
    }

    // Wrapper class to include engagement level
    public class AssignmentWithEngagement {
        @AuraEnabled public Id Id { get; set; }
        @AuraEnabled public Id ContactId { get; set; }
        @AuraEnabled public String ContactName { get; set; }
        @AuraEnabled public String ContactNameWithSuffix { get; set; }
        @AuraEnabled public String ContactReunionYear { get; set; }
        @AuraEnabled public Id AccountId { get; set; }
        @AuraEnabled public String AccountName { get; set; }
        @AuraEnabled public String EngagementLevel { get; set; }
    }

    /**
     * @description Returns all current Career Advising Assignment records assigned to the
     *              running user, enriched with a calculated engagement level per Account.
     * @return List of AssignmentWithEngagement wrappers.
     */
    @AuraEnabled(cacheable=true)
    public static List<AssignmentWithEngagement> getAssignedRecords() {
        try {
            Id currentUserId = UserInfo.getUserId();

            List<ucinn_ascendv2__Assignment__c> assignments = [
                SELECT Id,
                       ucinn_ascendv2__Contact__c,
                       ucinn_ascendv2__Contact__r.Name,
                       ucinn_ascendv2__Contact__r.HAM_Name_w_Suffix__c,
                       ucinn_ascendv2__Contact__r.HAM_Reunion_Year__c,
                       ucinn_ascendv2__Account__c,
                       ucinn_ascendv2__Account__r.Name
                FROM ucinn_ascendv2__Assignment__c
                WHERE ucinn_ascendv2__Assigned_Relationship_Manager_User__c = :currentUserId
                  AND ucinn_ascendv2__Assignment_Type__c = 'Career Advising'
                  AND HAM_Status__c = 'Current'
            ];


            Set<Id> accountIds = new Set<Id>();
            for (ucinn_ascendv2__Assignment__c assignment : assignments) {
                if (assignment.ucinn_ascendv2__Account__c != null) {
                    accountIds.add(assignment.ucinn_ascendv2__Account__c);
                }
            }

            Map<Id, String> accountEngagementMap = calculateEngagementLevels(accountIds);

            List<AssignmentWithEngagement> result = new List<AssignmentWithEngagement>();
            for (ucinn_ascendv2__Assignment__c assignment : assignments) {
                AssignmentWithEngagement wrapper = new AssignmentWithEngagement();
                wrapper.Id = assignment.Id;
                wrapper.ContactId = assignment.ucinn_ascendv2__Contact__c;
                wrapper.ContactName = assignment.ucinn_ascendv2__Contact__r?.Name;
                wrapper.ContactNameWithSuffix = assignment.ucinn_ascendv2__Contact__r?.HAM_Name_w_Suffix__c;
                wrapper.ContactReunionYear = assignment.ucinn_ascendv2__Contact__r?.HAM_Reunion_Year__c;
                wrapper.AccountId = assignment.ucinn_ascendv2__Account__c;
                wrapper.AccountName = assignment.ucinn_ascendv2__Account__r?.Name;
                wrapper.EngagementLevel = accountEngagementMap.get(assignment.ucinn_ascendv2__Account__c);
                result.add(wrapper);
            }

            return result;
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving assigned records: ' + e.getMessage());
        }
    }

    private static Map<Id, String> calculateEngagementLevels(Set<Id> accountIds) {
        Map<Id, String> engagementMap = new Map<Id, String>();

        if (accountIds.isEmpty()) {
            return engagementMap;
        }

        try {
            Integer orgFiscalMonth = [SELECT FiscalYearStartMonth FROM Organization LIMIT 1].FiscalYearStartMonth;
            Date today = System.today();
            Integer fiscalYearStartYear = (today.month() >= orgFiscalMonth) ? today.year() : today.year() - 1;
            Date currentFiscalYearStart = Date.newInstance(fiscalYearStartYear, orgFiscalMonth, 1);

            List<ucinn_ascendv2__Involvement_Value__c> involvementValues = [
                SELECT Id
                FROM ucinn_ascendv2__Involvement_Value__c
                WHERE ucinn_ascendv2__Type__c = 'Volunteer Engagement'
                AND HAM_Category__c = 'Career Center'
            ];

            if (involvementValues.isEmpty()) {
                for (Id accId : accountIds) {
                    engagementMap.put(accId, 'Prospect');
                }
                return engagementMap;
            }

            List<AggregateResult> aggResults = [
                SELECT ucinn_ascendv2__Account__c accId, COUNT(Id) cnt
                FROM ucinn_ascendv2__Involvement__c
                WHERE ucinn_ascendv2__Involvement_Code__c IN :involvementValues
                AND ucinn_ascendv2__Start_Date__c >= :currentFiscalYearStart
                AND ucinn_ascendv2__Account__c IN :accountIds
                GROUP BY ucinn_ascendv2__Account__c
            ];

            Map<Id, Integer> accountCountMap = new Map<Id, Integer>();
            for (AggregateResult ar : aggResults) {
                Id accId = (Id) ar.get('accId');
                Integer count = (Integer) ar.get('cnt');
                accountCountMap.put(accId, count);
            }

            for (Id accId : accountIds) {
                Integer count = accountCountMap.get(accId) != null ? accountCountMap.get(accId) : 0;
                String level;

                if (count == 0) {
                    level = 'Prospect';
                } else if (count == 1) {
                    level = 'Engaged';
                } else if (count == 2) {
                    level = 'Highly Engaged';
                } else {
                    level = 'Impact';
                }

                engagementMap.put(accId, level);
            }

        } catch (Exception e) {
            for (Id accId : accountIds) {
                engagementMap.put(accId, 'Prospect');
            }
        }

        return engagementMap;
    }
}