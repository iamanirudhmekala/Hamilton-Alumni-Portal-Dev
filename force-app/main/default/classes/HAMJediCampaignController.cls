public with sharing class HAMJediCampaignController {

    @AuraEnabled(cacheable=true)
    public static List<Campaign> getCampaignDetails(String contactId) {
        List<Campaign> campaigns = new List<Campaign>();

        // First, get all CampaignMember records for this contact
        List<CampaignMember> campaignMembers = [
            SELECT Id, CampaignId
            FROM CampaignMember
            WHERE ContactId = :contactId
        ];

        // Extract Campaign Ids
        Set<Id> campaignIds = new Set<Id>();
        for (CampaignMember cm : campaignMembers) {
            if (cm.CampaignId != null) {
                campaignIds.add(cm.CampaignId);
            }
        }

        // Fetch Campaign details if we have any Ids
        if (!campaignIds.isEmpty()) {
            campaigns = [
                SELECT Id, Name, HAM_Fiscal_Year__c, StartDate, EndDate, ParentId, Parent.Name, IsActive
                FROM Campaign
                WHERE Id IN :campaignIds
                ORDER BY StartDate DESC NULLS LAST
            ];
        }

        return campaigns;
    }
}