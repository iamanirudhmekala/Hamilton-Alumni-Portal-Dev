public with sharing class HAMJediAsksController {
    @AuraEnabled(cacheable=true)
    public static List<Opportunity> getJediAsks(String contactId) {
        List<Opportunity> opportunities = [
            SELECT
                Id,
                Name,
                ucinn_ascendv2__Submitted_Amount__c,
                HAM_Expected_Amount__c,
                StageName,
                ucinn_ascendv2__Submitted_Date__c,
                CloseDate
            FROM Opportunity
            WHERE RecordType.DeveloperName = 'Proposal'
            AND Id IN (
                SELECT OpportunityId
                FROM OpportunityContactRole
                WHERE ContactId = :contactId
            )
            ORDER BY CloseDate DESC NULLS LAST
        ];

        return opportunities;
    }
}