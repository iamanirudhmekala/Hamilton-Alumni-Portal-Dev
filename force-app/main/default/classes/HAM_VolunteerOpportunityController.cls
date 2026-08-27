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
* 3.0 | August 11, 2026 |  Hamilton Adv | ASC-14686 Collapse 4-tab Volunteer Service to Current/Past: added merged record methods, removed superseded getMyVolunteerActivities/getPastVolunteerActivities/getPastActivityCount/getCommitteeActivities/getCommitteesCount
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
        @AuraEnabled public String computedTab {get;set;} // Helper for JS: Current, Past
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
     * ADDED FOR CURRENT/PAST BUCKET MERGE (Activity + Committees combined)
     * ============================================================================
     * A record is treated as "current" if Status is not Former AND (End Date is
     * empty or in the future), and "past" if Status is Former OR End Date has
     * already passed. Checking both signals means a record still lands in the
     * correct bucket even if only one of the two fields was kept up to date -
     * and since "current" is defined as the exact logical complement of "past",
     * every record lands in exactly one bucket, never both, never neither.
     */

    /**
     * @description Maps an Involvement record to MyActivityWrapper, branching on RecordType
     * to populate Activity fields (via Involvement_Code__r) vs Committee/Board fields
     * (Formula/Role) - the same field mapping the two record types use today.
     *
     * @param inv - Involvement record queried with the fields both branches need
     * @param computedTab - 'Current' or 'Past', passed in by the caller
     * @return MyActivityWrapper - Populated wrapper
     */
    private static MyActivityWrapper buildActivityWrapper(ucinn_ascendv2__Involvement__c inv, String computedTab) {
        MyActivityWrapper wrap = new MyActivityWrapper();
        wrap.id = inv.Id;
        wrap.startDate = inv.ucinn_ascendv2__Start_Date__c;
        wrap.endDate = inv.ucinn_ascendv2__End_Date__c;
        wrap.status = inv.ucinn_ascendv2__Status__c;
        wrap.computedTab = computedTab;

        String recordTypeName = inv.RecordType != null ? inv.RecordType.DeveloperName : null;
        if (recordTypeName == 'Committee' || recordTypeName == 'Board_of_Trustees') {
            wrap.name = inv.ucinn_ascendv2__Involvement_Code_Description_Formula__c;
            wrap.description = inv.ucinn_ascendv2__Role__c;
            wrap.imageUrl = null;
        } else {
            wrap.name = inv.ucinn_ascendv2__Involvement_Code__r.Name;
            wrap.description = inv.ucinn_ascendv2__Involvement_Code__r.ucinn_ascendv2__Involvement_Description__c;
            wrap.imageUrl = inv.ucinn_ascendv2__Involvement_Code__r.HAM_Portal_Image_URL__c;
        }
        return wrap;
    }

    /**
     * @description Counts total CURRENT volunteer records (merged Activity + Committee/Board).
     *
     * @param currentUserContactId - Contact Id of the logged in user
     * @return Integer - Total count of current records matching criteria
     */
    @AuraEnabled(cacheable=true)
    public static Integer getCurrentVolunteerRecordsCount(Id currentUserContactId) {
        String volunteerengage = HAM_ConstantsUtil.VOLUNTEER_ENGAGEMENT;

        String query = 'SELECT COUNT() FROM ucinn_ascendv2__Involvement__c ' +
                       'WHERE ucinn_ascendv2__Contact__c = :currentUserContactId ' +
                       'AND ((ucinn_ascendv2__Involvement_Type_Formula__c = \'' + String.escapeSingleQuotes(volunteerengage) + '\') ' +
                       'OR ((RecordType.DeveloperName = \'Board_of_Trustees\' OR RecordType.DeveloperName = \'Committee\') AND HAM_Volunteer_Activity__c = true)) ' +
                       'AND (ucinn_ascendv2__Status__c != \'Former\' OR ucinn_ascendv2__Status__c = null) ' +
                       'AND (ucinn_ascendv2__End_Date__c = null OR ucinn_ascendv2__End_Date__c > TODAY)';

        try {
            return Database.countQuery(query);
        } catch(Exception e) {
            return 0;
        }
    }

    /**
     * @description Fetches paginated CURRENT volunteer records, merging Activity and
     * Committee/Board involvements into one list sorted by start date ascending.
     * See getCurrentVolunteerRecordsCount for the current-bucket definition.
     *
     * @param recordLimit - Number of records to retrieve per page
     * @param recordToSkip - Number of records to skip (offset)
     * @param currentUserContactId - Contact Id of the logged in user
     * @return List<MyActivityWrapper> - Merged current records
     */
    @AuraEnabled(cacheable=true)
    public static List<MyActivityWrapper> getCurrentVolunteerRecords(Integer recordLimit, Integer recordToSkip, Id currentUserContactId) {
        List<MyActivityWrapper> result = new List<MyActivityWrapper>();
        String volunteerengage = HAM_ConstantsUtil.VOLUNTEER_ENGAGEMENT;

        String query = 'SELECT Id, ucinn_ascendv2__Start_Date__c, ucinn_ascendv2__End_Date__c, ucinn_ascendv2__Status__c, ' +
                       'RecordType.DeveloperName, ' +
                       'ucinn_ascendv2__Involvement_Code__r.Name, ' +
                       'ucinn_ascendv2__Involvement_Code__r.ucinn_ascendv2__Involvement_Description__c, ' +
                       'ucinn_ascendv2__Involvement_Code__r.HAM_Portal_Image_URL__c, ' +
                       'ucinn_ascendv2__Involvement_Code_Description_Formula__c, ' +
                       'ucinn_ascendv2__Role__c ' +
                       'FROM ucinn_ascendv2__Involvement__c ' +
                       'WHERE ucinn_ascendv2__Contact__c = :currentUserContactId ' +
                       'AND ((ucinn_ascendv2__Involvement_Type_Formula__c = \'' + String.escapeSingleQuotes(volunteerengage) + '\') ' +
                       'OR ((RecordType.DeveloperName = \'Board_of_Trustees\' OR RecordType.DeveloperName = \'Committee\') AND HAM_Volunteer_Activity__c = true)) ' +
                       'AND (ucinn_ascendv2__Status__c != \'Former\' OR ucinn_ascendv2__Status__c = null) ' +
                       'AND (ucinn_ascendv2__End_Date__c = null OR ucinn_ascendv2__End_Date__c > TODAY) ' +
                       'ORDER BY ucinn_ascendv2__Start_Date__c ASC NULLS LAST, Id ASC';

        if (recordLimit != null && recordLimit > 0) {
            query += ' LIMIT ' + recordLimit;
        }
        if (recordToSkip != null && recordToSkip > 0) {
            query += ' OFFSET ' + recordToSkip;
        }

        List<ucinn_ascendv2__Involvement__c> involvements = Database.query(query);

        for (ucinn_ascendv2__Involvement__c inv : involvements) {
            result.add(buildActivityWrapper(inv, 'Current'));
        }

        return result;
    }

    /**
     * @description Counts total PAST volunteer records (merged Activity + Committee/Board).
     *
     * @param currentUserContactId - Contact Id of the logged in user
     * @param fromDate - Optional start date filter
     * @param toDate - Optional end date filter
     * @return Integer - Total count of past records matching criteria
     */
    @AuraEnabled(cacheable=true)
    public static Integer getPastVolunteerRecordsCount(Id currentUserContactId, Date fromDate, Date toDate) {
        String volunteerengage = HAM_ConstantsUtil.VOLUNTEER_ENGAGEMENT;

        String query = 'SELECT COUNT() FROM ucinn_ascendv2__Involvement__c ' +
                       'WHERE ucinn_ascendv2__Contact__c = :currentUserContactId ' +
                       'AND ((ucinn_ascendv2__Involvement_Type_Formula__c = \'' + String.escapeSingleQuotes(volunteerengage) + '\') ' +
                       'OR ((RecordType.DeveloperName = \'Board_of_Trustees\' OR RecordType.DeveloperName = \'Committee\') AND HAM_Volunteer_Activity__c = true)) ' +
                       'AND (ucinn_ascendv2__Status__c = \'Former\' OR (ucinn_ascendv2__End_Date__c != null AND ucinn_ascendv2__End_Date__c <= TODAY)) ';

        if (fromDate != null) query += 'AND ucinn_ascendv2__Start_Date__c >= :fromDate ';
        if (toDate != null) query += 'AND ucinn_ascendv2__Start_Date__c <= :toDate ';

        try {
            return Database.countQuery(query);
        } catch(Exception e) {
            return 0;
        }
    }

    /**
     * @description Fetches paginated PAST volunteer records, merging Activity and
     * Committee/Board involvements into one list sorted by end date descending.
     * See getPastVolunteerRecordsCount for the past-bucket definition. Carries forward
     * the optional date-range filter from the original Past tab.
     *
     * @param recordLimit - Number of records to retrieve per page
     * @param recordToSkip - Number of records to skip (offset)
     * @param currentUserContactId - Contact Id of the logged in user
     * @param fromDate - Optional start date filter
     * @param toDate - Optional end date filter
     * @return List<MyActivityWrapper> - Merged past records
     */
    @AuraEnabled(cacheable=true)
    public static List<MyActivityWrapper> getPastVolunteerRecords(
        Integer recordLimit,
        Integer recordToSkip,
        Id currentUserContactId,
        Date fromDate,
        Date toDate
    ) {
        List<MyActivityWrapper> result = new List<MyActivityWrapper>();
        String volunteerengage = HAM_ConstantsUtil.VOLUNTEER_ENGAGEMENT;

        String query = 'SELECT Id, ucinn_ascendv2__Start_Date__c, ucinn_ascendv2__End_Date__c, ucinn_ascendv2__Status__c, ' +
                       'RecordType.DeveloperName, ' +
                       'ucinn_ascendv2__Involvement_Code__r.Name, ' +
                       'ucinn_ascendv2__Involvement_Code__r.ucinn_ascendv2__Involvement_Description__c, ' +
                       'ucinn_ascendv2__Involvement_Code__r.HAM_Portal_Image_URL__c, ' +
                       'ucinn_ascendv2__Involvement_Code_Description_Formula__c, ' +
                       'ucinn_ascendv2__Role__c ' +
                       'FROM ucinn_ascendv2__Involvement__c ' +
                       'WHERE ucinn_ascendv2__Contact__c = :currentUserContactId ' +
                       'AND ((ucinn_ascendv2__Involvement_Type_Formula__c = \'' + String.escapeSingleQuotes(volunteerengage) + '\') ' +
                       'OR ((RecordType.DeveloperName = \'Board_of_Trustees\' OR RecordType.DeveloperName = \'Committee\') AND HAM_Volunteer_Activity__c = true)) ' +
                       'AND (ucinn_ascendv2__Status__c = \'Former\' OR (ucinn_ascendv2__End_Date__c != null AND ucinn_ascendv2__End_Date__c <= TODAY)) ';

        if (fromDate != null) query += 'AND ucinn_ascendv2__Start_Date__c >= :fromDate ';
        if (toDate != null) query += 'AND ucinn_ascendv2__Start_Date__c <= :toDate ';

        query += 'ORDER BY ucinn_ascendv2__End_Date__c DESC NULLS LAST, Id DESC';

        if (recordLimit != null && recordLimit > 0) {
            query += ' LIMIT ' + recordLimit;
        }
        if (recordToSkip != null && recordToSkip > 0) {
            query += ' OFFSET ' + recordToSkip;
        }

        List<ucinn_ascendv2__Involvement__c> involvements = Database.query(query);

        for (ucinn_ascendv2__Involvement__c inv : involvements) {
            result.add(buildActivityWrapper(inv, 'Past'));
        }

        return result;
    }
}