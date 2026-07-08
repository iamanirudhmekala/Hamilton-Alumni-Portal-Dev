/**
 * @description Service class to process Service Indicator records for marketing campaigns
 * @author Salesforce Developer
 */
public class HamMktgCampaignService {

    /**
     * @description Main method to process service indicators by category.
     *              For any SI whose Value carries an Associated Campaign Id,
     *              the contact is added to or removed from that campaign depending
     *              on whether the SI has an End Date.
     * @param serviceIndicatorIds List of Service Indicator IDs to process
     * @param contactId           Contact ID to filter records
     */
    public static void processServiceIndicators(
        List<Id> serviceIndicatorIds,
        Id contactId
    ) {
        // ── 1. Query all relevant Service Indicators ──────────────────────────
        List<ucinn_ascendv2__Service_Indicator__c> serviceIndicators = [
            SELECT
                ucinn_ascendv2__Contact__c,
                ucinn_ascendv2__End_Date__c,
                ucinn_ascendv2__Start_Date__c,
                ucinn_ascendv2__Service_Indicator_Value__c,
                ucinn_ascendv2__Source__c,
                ucinn_ascendv2__Service_Indicator_Value__r.HAM_Category__c,
                ucinn_ascendv2__Service_Indicator_Value__r.HAM_Associated_Campaign_Id__c
            FROM ucinn_ascendv2__Service_Indicator__c
            WHERE Id IN :serviceIndicatorIds
            AND ucinn_ascendv2__Contact__c = :contactId
        ];

        if (serviceIndicators.isEmpty()) {
            return;
        }

        // ── 2. Categorize records & collect campaign-linked SIs ───────────────
        Map<String, List<ucinn_ascendv2__Service_Indicator__c>> categorizedRecords =
            new Map<String, List<ucinn_ascendv2__Service_Indicator__c>>{
                'Communication Preferences' => new List<ucinn_ascendv2__Service_Indicator__c>(),
                'Directory Visibility'      => new List<ucinn_ascendv2__Service_Indicator__c>(),
                'Marketing Preferences'     => new List<ucinn_ascendv2__Service_Indicator__c>(),
                'Privacy Controls'          => new List<ucinn_ascendv2__Service_Indicator__c>(),
                'Volunteer Preferences'     => new List<ucinn_ascendv2__Service_Indicator__c>(),
                'Email Preferences'         => new List<ucinn_ascendv2__Service_Indicator__c>()
            };

        // Collect every SI that references a campaign, regardless of category
        List<ucinn_ascendv2__Service_Indicator__c> campaignLinkedSIs =
            new List<ucinn_ascendv2__Service_Indicator__c>();

        Set<Id> campaignIds = new Set<Id>();

        for (ucinn_ascendv2__Service_Indicator__c si : serviceIndicators) {
            String category = si.ucinn_ascendv2__Service_Indicator_Value__r.HAM_Category__c;

            // Route into the correct category bucket (skip unknown/null categories)
            if (String.isNotBlank(category) && categorizedRecords.containsKey(category)) {
                categorizedRecords.get(category).add(si);
            }

            // Independently track any SI that carries a campaign Id
            Id associatedCampaignId =
                si.ucinn_ascendv2__Service_Indicator_Value__r.HAM_Associated_Campaign_Id__c;

            if (associatedCampaignId != null) {
                campaignLinkedSIs.add(si);
                campaignIds.add(associatedCampaignId);
            }
        }

        // ── 3. Sync CampaignMembers for every campaign-linked SI ──────────────
        if (!campaignLinkedSIs.isEmpty()) {
            // Build a map of existing CampaignMember records for this contact
            Map<Id, CampaignMember> campaignMemberMap = new Map<Id, CampaignMember>();

            for (CampaignMember cm : [
                SELECT Id, CampaignId, ContactId
                FROM CampaignMember
                WHERE CampaignId IN :campaignIds
                AND ContactId = :contactId
            ]) {
                campaignMemberMap.put(cm.CampaignId, cm);
            }

            syncCampaignMembers(campaignLinkedSIs, campaignMemberMap, contactId);
        }

        // ── 4. Delegate to category-specific processors ───────────────────────
        if (!categorizedRecords.get('Communication Preferences').isEmpty()) {
            processCommunicationPreferences(
                categorizedRecords.get('Communication Preferences')
            );
        }
        if (!categorizedRecords.get('Directory Visibility').isEmpty()) {
            processDirectoryVisibility(
                categorizedRecords.get('Directory Visibility')
            );
        }
        if (!categorizedRecords.get('Marketing Preferences').isEmpty()) {
            processMarketingPreferences(
                categorizedRecords.get('Marketing Preferences'),
                buildCampaignMemberMap(
                    categorizedRecords.get('Marketing Preferences'), contactId
                )
            );
        }
        if (!categorizedRecords.get('Email Preferences').isEmpty()) {
            processEmailPreferences(
                categorizedRecords.get('Email Preferences'),
                buildCampaignMemberMap(
                    categorizedRecords.get('Email Preferences'), contactId
                )
            );
        }
        if (!categorizedRecords.get('Privacy Controls').isEmpty()) {
            processPrivacyControls(
                categorizedRecords.get('Privacy Controls')
            );
        }
        if (!categorizedRecords.get('Volunteer Preferences').isEmpty()) {
            processVolunteerPreferences(
                categorizedRecords.get('Volunteer Preferences')
            );
        }
    }

    // ── Private Helpers ────────────────────────────────────────────────────────

    /**
     * @description Builds a CampaignMember map scoped to a specific list of SIs and contact.
     *              Used so that each category processor receives only the members
     *              relevant to its own set of campaigns.
     */
    private static Map<Id, CampaignMember> buildCampaignMemberMap(
        List<ucinn_ascendv2__Service_Indicator__c> indicators,
        Id contactId
    ) {
        Set<Id> campaignIds = new Set<Id>();
        for (ucinn_ascendv2__Service_Indicator__c si : indicators) {
            Id cId = si.ucinn_ascendv2__Service_Indicator_Value__r.HAM_Associated_Campaign_Id__c;
            if (cId != null) {
                campaignIds.add(cId);
            }
        }

        Map<Id, CampaignMember> cmMap = new Map<Id, CampaignMember>();
        if (!campaignIds.isEmpty()) {
            for (CampaignMember cm : [
                SELECT Id, CampaignId, ContactId
                FROM CampaignMember
                WHERE CampaignId IN :campaignIds
                AND ContactId = :contactId
            ]) {
                cmMap.put(cm.CampaignId, cm);
            }
        }
        return cmMap;
    }

    /**
     * @description Core sync logic: adds the contact to a campaign when the SI
     *              has no End Date, and removes them when an End Date is present.
     *              Works for any category – the caller decides which SIs to pass in.
     * @param indicators       Campaign-linked Service Indicators to evaluate
     * @param campaignMemberMap Existing CampaignMember records keyed by CampaignId
     * @param contactId        The contact being processed
     */
    private static void syncCampaignMembers(
        List<ucinn_ascendv2__Service_Indicator__c> indicators,
        Map<Id, CampaignMember> campaignMemberMap,
        Id contactId
    ) {
        List<CampaignMember> toInsert = new List<CampaignMember>();
        List<CampaignMember> toDelete = new List<CampaignMember>();

        for (ucinn_ascendv2__Service_Indicator__c si : indicators) {
            Id campaignId =
                si.ucinn_ascendv2__Service_Indicator_Value__r.HAM_Associated_Campaign_Id__c;
            if(campaignId != Null){
                if (si.ucinn_ascendv2__End_Date__c == null) {
                    // No End Date → contact should be a member
                    if (!campaignMemberMap.containsKey(campaignId)) {
                        toInsert.add(new CampaignMember(
                            CampaignId = campaignId,
                            ContactId  = contactId
                        ));
                        // Prevent duplicate inserts within the same batch
                        campaignMemberMap.put(campaignId, new CampaignMember(
                            CampaignId = campaignId,
                            ContactId  = contactId
                        ));
                    }
                } else {
                    // End Date present → contact should NOT be a member
                    if (campaignMemberMap.containsKey(campaignId)) {
                        toDelete.add(campaignMemberMap.get(campaignId));
                        campaignMemberMap.remove(campaignId);
                    }
                }
            }
        }

        if (!toInsert.isEmpty()) {
            insert toInsert;
        }
        if (!toDelete.isEmpty()) {
            delete toDelete;
        }
    }

    // ── Public Category Processors ─────────────────────────────────────────────

    /**
     * @description Process Communication Preferences category
     */
    public static void processCommunicationPreferences(
        List<ucinn_ascendv2__Service_Indicator__c> serviceIndicators
    ) {
        System.debug(
            'Processing Communication Preferences: ' +
            serviceIndicators.size() + ' records'
        );
    }

    /**
     * @description Process Directory Visibility category
     */
    public static void processDirectoryVisibility(
        List<ucinn_ascendv2__Service_Indicator__c> serviceIndicators
    ) {
        System.debug(
            'Processing Directory Visibility: ' +
            serviceIndicators.size() + ' records'
        );
    }

    /**
     * @description Process Marketing Preferences category.
     *              Adds or removes the contact from the associated campaign
     *              based on the SI End Date.
     * @param serviceIndicators List of service indicators in Marketing Preferences category
     * @param campaignMemberMap Existing CampaignMember records keyed by CampaignId
     */
    public static void processMarketingPreferences(
        List<ucinn_ascendv2__Service_Indicator__c> serviceIndicators,
        Map<Id, CampaignMember> campaignMemberMap
    ) {
        syncCampaignMembers(
            serviceIndicators,
            campaignMemberMap,
            serviceIndicators[0].ucinn_ascendv2__Contact__c
        );
    }

    /**
     * @description Process Privacy Controls category
     */
    public static void processPrivacyControls(
        List<ucinn_ascendv2__Service_Indicator__c> serviceIndicators
    ) {
        System.debug(
            'Processing Privacy Controls: ' +
            serviceIndicators.size() + ' records'
        );
    }

    /**
     * @description Process Volunteer Preferences category
     */
    public static void processVolunteerPreferences(
        List<ucinn_ascendv2__Service_Indicator__c> serviceIndicators
    ) {
        System.debug(
            'Processing Volunteer Preferences: ' +
            serviceIndicators.size() + ' records'
        );
    }

    /**
     * @description Process Email Preferences category.
     *              Adds or removes the contact from the associated campaign
     *              based on the SI End Date.
     * @param serviceIndicators List of service indicators in Email Preferences category
     * @param campaignMemberMap Existing CampaignMember records keyed by CampaignId
     */
    public static void processEmailPreferences(
        List<ucinn_ascendv2__Service_Indicator__c> serviceIndicators,
        Map<Id, CampaignMember> campaignMemberMap
    ) {
        syncCampaignMembers(
            serviceIndicators,
            campaignMemberMap,
            serviceIndicators[0].ucinn_ascendv2__Contact__c
        );
    }
}