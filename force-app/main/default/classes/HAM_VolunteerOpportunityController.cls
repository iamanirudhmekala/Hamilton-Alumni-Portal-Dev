/**
* @File Name : HAM_VolunteerOpportunityController.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : December 23, 2025 
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | December 23, 2025 |  Sachin | Initial Version
* 2.0 | July 16, 2026 |  Hamilton Adv | ASC-14664 Add Data source for the HQ Hand raise
**/

public without sharing class HAM_VolunteerOpportunityController {
	
    /**
     * Wrapper class for volunteer opportunities with interest status
     */
	public class OpportunityWrapper {
        @AuraEnabled public ucinn_ascendv2__Foundation_Funding_Interests__c opp {get;set;}
        @AuraEnabled public Boolean isInterested {get;set;} // True = Show Withdraw
        @AuraEnabled public Id activeInterestId {get;set;}  // Interest Id for withdrawing    
    }

    /**
     * Wrapper class for volunteer activity records
     */
	public class MyActivityWrapper {
        @AuraEnabled public String id {get;set;}
        @AuraEnabled public String name {get;set;}
        @AuraEnabled public String description {get;set;}
        @AuraEnabled public String imageUrl {get;set;}
        @AuraEnabled public Date startDate {get;set;}
        @AuraEnabled public Date endDate {get;set;}
        @AuraEnabled public String status {get;set;} // Current, Former
        @AuraEnabled public String computedTab {get;set;} // Helper for JS: Current, Upcoming, Past
    }

	/**
     * @description Counts total PAST volunteer activities for pagination calculation
     * Filters by contact, volunteer engagement type, and optional date range
     * 
     * @param currentUserContactId - Contact Id of the logged in user
     * @param fromDate - Optional start date filter
     * @param toDate - Optional end date filter
     * @return Integer - Total count of past activities matching criteria
     */
    @AuraEnabled(cacheable=true)
    public static Integer getPastActivityCount(Id currentUserContactId, Date fromDate, Date toDate) {
        
        String volunteerengage = HAM_ConstantsUtil.VOLUNTEER_ENGAGEMENT;
        
        String query = 'SELECT COUNT() FROM ucinn_ascendv2__Involvement__c ' + 
                       'WHERE ucinn_ascendv2__Contact__c = :currentUserContactId ' + 
                       'AND ucinn_ascendv2__Involvement_Code__c != null AND ucinn_ascendv2__Involvement_Type_Formula__c = \''+ String.escapeSingleQuotes(volunteerengage) + '\'';
        
        // "Past" Logic: Status is Former OR (Status is Current AND End Date is Past)
        query += 'AND (ucinn_ascendv2__Status__c = \'Former\') '; 

        if (fromDate != null) query += 'AND ucinn_ascendv2__Start_Date__c >= :fromDate ';
        if (toDate != null) query += 'AND ucinn_ascendv2__Start_Date__c <= :toDate ';

        try {
            return Database.countQuery(query);
        } catch(Exception e) {
            return 0;
        }
    }

	/**
     * @description Fetches paginated past volunteer activities using keyset pagination (seek method)
     * Retrieves activities with status 'Former' sorted by start date descending
     * Uses keyset pagination to avoid OFFSET performance issues with large datasets
     * 
     * @param pageSize - Number of records to retrieve per page
     * @param recordsToSkip - Number of records to skip (for page calculation)
     * @param currentUserContactId - Contact Id of the logged in user
     * @param fromDate - Optional start date filter
     * @param toDate - Optional end date filter
     * @return List<MyActivityWrapper> - List of past activities with formatted data
     */
    @AuraEnabled(cacheable=true)
    public static List<MyActivityWrapper> getPastVolunteerActivities(
        Integer pageSize, 
        Integer recordsToSkip, 
        Id currentUserContactId, 
        Date fromDate, 
        Date toDate
    ) {
        List<MyActivityWrapper> result = new List<MyActivityWrapper>();
        
        // Get Volunteer Enganement value 
        String volunteerengage = HAM_ConstantsUtil.VOLUNTEER_ENGAGEMENT;
        
        // Build Base Criteria
        String baseWhere = 'WHERE ucinn_ascendv2__Contact__c = :currentUserContactId ' + 
                           'AND ucinn_ascendv2__Involvement_Code__c != null AND ucinn_ascendv2__Involvement_Type_Formula__c = \''+ String.escapeSingleQuotes(volunteerengage) + '\' ' + 
                           'AND ucinn_ascendv2__Status__c = \'Former\' '; // Targeting Past Tab

        if (fromDate != null) baseWhere += 'AND ucinn_ascendv2__Start_Date__c >= :fromDate ';
        if (toDate != null) baseWhere += 'AND ucinn_ascendv2__Start_Date__c <= :toDate ';

        // Select Fields
        String selectFields = 'SELECT Id, ucinn_ascendv2__Start_Date__c, ucinn_ascendv2__End_Date__c, ucinn_ascendv2__Status__c, ' +
                              'ucinn_ascendv2__Involvement_Code__c, ucinn_ascendv2__Involvement_Code__r.Name, ' +
                              'ucinn_ascendv2__Involvement_Code__r.ucinn_ascendv2__Involvement_Description__c, ' +
                              'ucinn_ascendv2__Involvement_Code__r.HAM_Portal_Image_URL__c ';

        // PAGINATION LOGIC (The "Seek" Pattern)
        String finalQuery = selectFields + 'FROM ucinn_ascendv2__Involvement__c ' + baseWhere;

        // PAGE 1: Simple Limit
        if (recordsToSkip == 0) {
            // Order by Date DESC, then Id DESC for deterministic sorting
            finalQuery += ' ORDER BY ucinn_ascendv2__Start_Date__c DESC, Id DESC LIMIT :pageSize';
        } 
        // PAGE > 1: Fetch skip records to find the cursor (Last Date & Id)
        else {
            // A. Fetch the records we want to skip to find the "Last Record" of the previous page
            String skipQuery = 'SELECT Id, ucinn_ascendv2__Start_Date__c FROM ucinn_ascendv2__Involvement__c ' + 
                               baseWhere + 
                               ' ORDER BY ucinn_ascendv2__Start_Date__c DESC, Id DESC LIMIT :recordsToSkip';
            
            List<ucinn_ascendv2__Involvement__c> skippedList = Database.query(skipQuery);
            
            if (!skippedList.isEmpty()) {
                // Get the last record from the skipped list
                ucinn_ascendv2__Involvement__c lastRecord = skippedList[skippedList.size() - 1];
                Date lastDate = lastRecord.ucinn_ascendv2__Start_Date__c;
                Id lastId = lastRecord.Id;

                // B. Filter for records "After" that last record (Date < lastDate OR (Date = lastDate AND Id < lastId))
                // Note: Since we sort DESC, "After" means "Smaller" date/id
                finalQuery += ' AND (ucinn_ascendv2__Start_Date__c < :lastDate OR (ucinn_ascendv2__Start_Date__c = :lastDate AND Id < :lastId)) ' +
                              ' ORDER BY ucinn_ascendv2__Start_Date__c DESC, Id DESC LIMIT :pageSize';
            } else {
                // Fallback if something went wrong (return empty)
                return result; 
            }
        }

        List<ucinn_ascendv2__Involvement__c> involvements = Database.query(finalQuery);

        // Map to Wrapper
        for(ucinn_ascendv2__Involvement__c inv : involvements) {
            MyActivityWrapper wrap = new MyActivityWrapper();
            wrap.id = inv.Id;
            wrap.name = inv.ucinn_ascendv2__Involvement_Code__r.Name;
            wrap.description = inv.ucinn_ascendv2__Involvement_Code__r.ucinn_ascendv2__Involvement_Description__c;
            wrap.imageUrl = inv.ucinn_ascendv2__Involvement_Code__r.HAM_Portal_Image_URL__c;
            wrap.startDate = inv.ucinn_ascendv2__Start_Date__c;
            wrap.endDate = inv.ucinn_ascendv2__End_Date__c;
            wrap.status = inv.ucinn_ascendv2__Status__c;
            wrap.computedTab = 'Past'; // We know these are past
            result.add(wrap);
        }

        return result;
    }

	/**
     * @description Fetches current and upcoming volunteer activities for a user
     * Returns activities with null end dates, categorized as 'Current' or 'Upcoming'
     * based on start date relative to today
     * 
     * @param currentUserContactId - Contact Id of the logged in user
     * @param fromDate - Optional start date filter (currently unused)
     * @param toDate - Optional end date filter (currently unused)
     * @return List<MyActivityWrapper> - List of current and upcoming activities
     */
    @AuraEnabled(cacheable=true)
    public static List<MyActivityWrapper> getMyVolunteerActivities(Id currentUserContactId, Date fromDate, Date toDate) {
        List<MyActivityWrapper> result = new List<MyActivityWrapper>();
        Date today = System.today();
        
        // Get Volunteer Enganement value 
        String volunteerengage = HAM_ConstantsUtil.VOLUNTEER_ENGAGEMENT;
        
		// Base Query
        String query = 'SELECT Id, ucinn_ascendv2__Start_Date__c, ucinn_ascendv2__End_Date__c, ucinn_ascendv2__Status__c, ' +
                       'ucinn_ascendv2__Involvement_Code__c, ucinn_ascendv2__Involvement_Code__r.Name, ' +
                       'ucinn_ascendv2__Involvement_Code__r.ucinn_ascendv2__Involvement_Description__c, ' +
                       'ucinn_ascendv2__Involvement_Code__r.HAM_Portal_Image_URL__c ' +
                       'FROM ucinn_ascendv2__Involvement__c ' +
                       'WHERE ucinn_ascendv2__Contact__c = :currentUserContactId AND ucinn_ascendv2__Involvement_Type_Formula__c = \''+ String.escapeSingleQuotes(volunteerengage) + '\' '+ 
                       'AND (ucinn_ascendv2__End_Date__c = null OR ucinn_ascendv2__End_Date__c > :today)'; // Only Open (Current/Upcoming)

        query += 'ORDER BY ucinn_ascendv2__Start_Date__c ASC';

		// fetch records from junction object (Involvement) and Parent (Involvement Value)
        List<ucinn_ascendv2__Involvement__c> involvements = Database.query(query);

        for(ucinn_ascendv2__Involvement__c inv : involvements) {
            MyActivityWrapper wrap = new MyActivityWrapper();
            wrap.id = inv.Id;
            // Map fields from Parent Involvement Value
            wrap.name = inv.ucinn_ascendv2__Involvement_Code__r.Name;
            wrap.description = inv.ucinn_ascendv2__Involvement_Code__r.ucinn_ascendv2__Involvement_Description__c;
            wrap.imageUrl = inv.ucinn_ascendv2__Involvement_Code__r.HAM_Portal_Image_URL__c;
            
            // Map fields from junction Object
            wrap.startDate = inv.ucinn_ascendv2__Start_Date__c;
            wrap.endDate = inv.ucinn_ascendv2__End_Date__c;
            wrap.status = inv.ucinn_ascendv2__Status__c; // 'Current' or 'Former'

            // Compute Tab Category logic
			if (inv.ucinn_ascendv2__Start_Date__c > today) {
				wrap.computedTab = 'Upcoming';
			} else {
				wrap.computedTab = 'Current';
			}

            result.add(wrap);
        }

        return result;
    }

	/**
     * @description Retrieves volunteer opportunities with user's interest status
     * Fetches Foundation Funding Interests marked as volunteer opportunities
     * and cross-references with user's active Funding Interest records
     * 
     * @param recordLimit - Maximum number of opportunities to return (0 or null for all)
     * @param currentUserContactId - Contact Id of the logged in user
     * @param recordToSkip - Number of records to skip
     * @return List<OpportunityWrapper> - List of opportunities with interest status
     */
	@AuraEnabled
    public static List<OpportunityWrapper> getOpportunities(Integer recordLimit, Integer recordToSkip, Id currentUserContactId) {
        
		List<OpportunityWrapper> result = new List<OpportunityWrapper>();
        
        Id contactId = currentUserContactId;

		String career = HAM_ConstantsUtil.CAREER_CENTER;
		String event  = HAM_ConstantsUtil.EVENTS_VOLUNTEER;

        // Fetch Volunteer Opportunities (Interest Values)
        // If recordLimit is passed (e.g., 2), we limit the query.
        String query =
			'SELECT Id, Name, HAM_Description__c, HAM_Image_URL__c, HAM_Category__c,Ham_Display_order__c ' +
			'FROM ucinn_ascendv2__Foundation_Funding_Interests__c ' +
			'WHERE HAM_Is_Publicly_Visible__c = true ' +
			'AND (HAM_Category__c = \'' + String.escapeSingleQuotes(career) + '\' ' +
			'OR HAM_Category__c = \'' + String.escapeSingleQuotes(event) + '\') ' +
			'ORDER BY Ham_Display_order__c ASC NULLS LAST, CreatedDate DESC';
		
		if (recordLimit != null && recordLimit > 0) {
			query += ' LIMIT ' + recordLimit;
		}

        if(recordToSkip != null && recordToSkip > 0){
            query += 'OFFSET ' +recordToSkip;
        }

        List<ucinn_ascendv2__Foundation_Funding_Interests__c> opportunities = Database.query(query);

        // Fetch ACTIVE Interest Records for this Contact
        // We only care about Open interests (End Date is null)
        List<ucinn_ascendv2__Funding_Interest__c> myInterests = [
            SELECT Id, ucinn_ascendv2__Foundation_Funding_Interest__c 
            FROM ucinn_ascendv2__Funding_Interest__c 
            WHERE ucinn_ascendv2__Contact__c = :contactId 
            AND ucinn_ascendv2__End_Date__c = NULL
        ];

        Set<Id> activeValueIds = new Set<Id>();
        Map<Id, Id> foundationInterestToInterestId = new Map<Id, Id>();

        for (ucinn_ascendv2__Funding_Interest__c i : myInterests) {
			if (i.ucinn_ascendv2__Foundation_Funding_Interest__c != null) {
				foundationInterestToInterestId.put(
					i.ucinn_ascendv2__Foundation_Funding_Interest__c,
					i.Id
				);
			}
		}

        // Build Wrapper
        for (ucinn_ascendv2__Foundation_Funding_Interests__c val : opportunities) {
			OpportunityWrapper wrap = new OpportunityWrapper();
			wrap.opp = val;

			Id activeInterestId = foundationInterestToInterestId.get(val.Id);

			if (activeInterestId != null) {
				wrap.isInterested = true;
				wrap.activeInterestId = activeInterestId;
			} else {
				wrap.isInterested = false;
				wrap.activeInterestId = null;
			}
            result.add(wrap);
        }
        return result;
    }

    /**
     * @description Creates a new Funding Interest record when user expresses interest
     * Sets start date to today and copies category from the opportunity
     * 
     * @param interestValueId - Id of the Foundation Funding Interest (opportunity)
     * @param currentUserContactId - Contact Id of the logged in user
     * @return String - Id of the newly created Funding Interest record
     */
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
     * @description Withdraws user's interest by setting end date on Funding Interest record
     * Sets end date to today to mark the interest as inactive
     * 
     * @param interestId - Id of the Funding Interest record to withdraw
     */
    @AuraEnabled
    public static void withdrawInterest(Id interestId) {
        ucinn_ascendv2__Funding_Interest__c intRecord = new ucinn_ascendv2__Funding_Interest__c(Id = interestId);
        intRecord.ucinn_ascendv2__End_Date__c = System.today();
        update intRecord;
    }

    /**
     * @description Retrieves the count of volunteer opportunities.
     * 
     * @param recordLimit - Maximum number of opportunities to return (0 or null for all)
     * @param recordToSkip - Number of records to skip
     * @param currentUserContactId - Contact Id of the logged in user
     * @return Integer - Count of opportunities
     */
    @AuraEnabled
    public static Integer getOpportunitiesCount() {
        
		List<OpportunityWrapper> result = new List<OpportunityWrapper>();

		String career = HAM_ConstantsUtil.CAREER_CENTER;
		String event  = HAM_ConstantsUtil.EVENTS_VOLUNTEER;

        // Fetch Volunteer Opportunities (Interest Values)
        // If recordLimit is passed (e.g., 2), we limit the query.
        String query =
			'SELECT count() ' +
			'FROM ucinn_ascendv2__Foundation_Funding_Interests__c ' +
			'WHERE HAM_Is_Publicly_Visible__c = true ' +
			'AND (HAM_Category__c = \'' + String.escapeSingleQuotes(career) + '\' ' +
			'OR HAM_Category__c = \'' + String.escapeSingleQuotes(event) + '\') ';        
        Integer opportunitiesCount = Database.countQuery(query);
        return opportunitiesCount;
    }

    /**
     * ============================================================================
     * ADDED FOR COMMITTEES SUB-TAB
     * ============================================================================
     */

    /**
     * @description Retrieves the total count of Committee activities for pagination.
     * @param currentUserContactId - Contact Id of the logged in user
     * @return Integer - Count of committee records
     */
    @AuraEnabled(cacheable=true)
    public static Integer getCommitteesCount(Id currentUserContactId) {
        String query = 'SELECT count() FROM ucinn_ascendv2__Involvement__c ' +
                       'WHERE ucinn_ascendv2__Contact__c = :currentUserContactId ' +
                       'AND (RecordType.DeveloperName = \'Board_of_Trustees\' OR RecordType.DeveloperName = \'Committee\') ' +
                       'AND HAM_Volunteer_Activity__c = true';
                       
        return Database.countQuery(query);
    }

    /**
     * @description Fetches paginated Committee activities for the user.
     * Maps the Formula field to Name and Role to Description.
     * * @param recordLimit - Number of records to retrieve per page
     * @param recordToSkip - Number of records to skip (Offset)
     * @param currentUserContactId - Contact Id of the logged in user
     * @return List<MyActivityWrapper> - List of formatted committee activities
     */
    @AuraEnabled(cacheable=true)
    public static List<MyActivityWrapper> getCommitteeActivities(Integer recordLimit, Integer recordToSkip, Id currentUserContactId) {
        List<MyActivityWrapper> result = new List<MyActivityWrapper>();
        
        String query = 'SELECT Id, ucinn_ascendv2__Involvement_Code_Description_Formula__c, ' +
                       'ucinn_ascendv2__Role__c, ucinn_ascendv2__Start_Date__c, ' +
                       'ucinn_ascendv2__End_Date__c, ucinn_ascendv2__Status__c ' +
                       'FROM ucinn_ascendv2__Involvement__c ' +
                       'WHERE ucinn_ascendv2__Contact__c = :currentUserContactId ' +
                       'AND (RecordType.DeveloperName = \'Board_of_Trustees\' OR RecordType.DeveloperName = \'Committee\') ' +
                       'AND HAM_Volunteer_Activity__c = true ' +
                       'ORDER BY ucinn_ascendv2__Start_Date__c DESC NULLS LAST, Id DESC ';
                       
        if (recordLimit != null && recordLimit > 0) {
            query += ' LIMIT ' + recordLimit;
        }
        if (recordToSkip != null && recordToSkip > 0) {
            query += ' OFFSET ' + recordToSkip;
        }

        List<ucinn_ascendv2__Involvement__c> involvements = Database.query(query);

        for(ucinn_ascendv2__Involvement__c inv : involvements) {
            MyActivityWrapper wrap = new MyActivityWrapper();
            wrap.id = inv.Id;
            // Map Formula field as the Title
            wrap.name = inv.ucinn_ascendv2__Involvement_Code_Description_Formula__c;
            // Map Role field as the Description
            wrap.description = inv.ucinn_ascendv2__Role__c;
            wrap.startDate = inv.ucinn_ascendv2__Start_Date__c;
            wrap.endDate = inv.ucinn_ascendv2__End_Date__c;
            wrap.status = inv.ucinn_ascendv2__Status__c;
            wrap.computedTab = 'Committees'; 
            result.add(wrap);
        }
        
        return result;
    }
}