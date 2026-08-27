@JsonAccess(serializable='always' deserializable='always')
global class miltonAlumniSearchResponse {

    @AuraEnabled
    global List<miltonAlumniResult> alumniRecords;

    @AuraEnabled
    global Id contactId;

    @AuraEnabled
    global Integer totalCount;

    @AuraEnabled
    global Boolean isSuccess;

    @AuraEnabled
    global String statusMessage;
}