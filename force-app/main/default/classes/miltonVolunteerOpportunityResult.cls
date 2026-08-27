@JsonAccess(serializable='always' deserializable='always')
global class miltonVolunteerOpportunityResult {

    @AuraEnabled
    global String recordId;

    @AuraEnabled
    global String name;

    @AuraEnabled
    global String description;

    @AuraEnabled
    global String imageUrl;

    @AuraEnabled
    global String category;

    @AuraEnabled
    global Decimal displayOrder;
}