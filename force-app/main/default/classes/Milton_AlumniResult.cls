@JsonAccess(serializable='always' deserializable='always')
global class Milton_AlumniResult {

    @AuraEnabled
    global String recordId;

    @AuraEnabled
    global String contactId;

    @AuraEnabled
    global String alumniName;

    @AuraEnabled
    global String profilePictureUrl;

    @AuraEnabled
    global String majorDegree;

    @AuraEnabled
    global String classOfYear;
}