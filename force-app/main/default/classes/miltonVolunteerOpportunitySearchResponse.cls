@JsonAccess(serializable='always' deserializable='always')
global class miltonVolunteerOpportunitySearchResponse {

    @AuraEnabled
    global List<miltonVolunteerOpportunityResult> opportunities;

    @AuraEnabled
    global Id contactId;

    @AuraEnabled
    global Integer totalCount;

    @AuraEnabled
    global Boolean isSuccess;

    @AuraEnabled
    global String statusMessage;
}