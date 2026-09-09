@JsonAccess(serializable='always' deserializable='always')
global class miltonAlumniResult {

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
    global String email;

    @AuraEnabled
    global String classOfYear;

    @AuraEnabled
    global Boolean isConnected;

    @AuraEnabled
    global Boolean isBookmarked;

    @AuraEnabled
    global Boolean isRequestSent;

    @AuraEnabled
    global Boolean isActive;

    @AuraEnabled
    global Boolean isSelf;

    @AuraEnabled
    global Boolean isDeceased;

    @AuraEnabled
    global Boolean connectionPrivacyEnabled;
}