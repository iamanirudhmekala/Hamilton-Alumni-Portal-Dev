@JsonAccess(serializable='always' deserializable='always')
global class miltonVolunteerServicesSearchResponse {

    @AuraEnabled
    global List<miltonVolunteerServicesResult> activities;

    @AuraEnabled
    global Id contactId;

    @AuraEnabled
    global Integer totalCount;

    @AuraEnabled
    global Boolean isSuccess;

    @AuraEnabled
    global String statusMessage;
}