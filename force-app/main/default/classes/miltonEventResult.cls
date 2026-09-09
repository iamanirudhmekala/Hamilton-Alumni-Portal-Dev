@JsonAccess(serializable='always' deserializable='always')
global class miltonEventResult {

    @AuraEnabled
    global String recordId;

    @AuraEnabled
    global String eventName;

    @AuraEnabled
    global String description;

    @AuraEnabled
    global String imageUrl;

    @AuraEnabled
    global String startDate;

    @AuraEnabled
    global String startTime;

    @AuraEnabled
    global String location;
}