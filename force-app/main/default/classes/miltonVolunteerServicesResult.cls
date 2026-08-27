@JsonAccess(serializable='always' deserializable='always')
global class miltonVolunteerServicesResult {
    @AuraEnabled global String recordId;
    @AuraEnabled global String name;
    @AuraEnabled global String description;
    @AuraEnabled global String imageUrl;
    @AuraEnabled global Date startDate;
    @AuraEnabled global Date endDate;
    @AuraEnabled global String status;
    @AuraEnabled global String computedTab;
}