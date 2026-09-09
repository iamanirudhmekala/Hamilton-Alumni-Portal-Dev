@JsonAccess(serializable='always' deserializable='always')
global class miltonEventSearchResponse {

    @AuraEnabled
    global List<miltonEventResult> events;

    @AuraEnabled
    global Id contactId;

    @AuraEnabled
    global Integer totalCount;

    @AuraEnabled
    global Boolean isSuccess;

    @AuraEnabled
    global String statusMessage;
}