@JsonAccess(serializable='always' deserializable='always')
global class Milton_AlumniSearchResponse {

    @AuraEnabled
    global List<Milton_AlumniResult> alumniRecords;

    @AuraEnabled
    global Integer totalCount;

    @AuraEnabled
    global Boolean isSuccess;

    @AuraEnabled
    global String statusMessage;
}