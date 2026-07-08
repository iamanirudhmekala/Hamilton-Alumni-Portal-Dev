/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : HAM_GlobalResourcesController
 * Author          : Sachin
 * Created Date    : May 6, 2026
 * Last Modified By: Sachin
 * Last Modified On: May 6, 2026
 * Description     : This class implements logic for fetching college resource from listing object.
 * * Change History  :
 * Date           │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * May 6, 2026    │ Sachin       │ Initial version 
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */
@SuppressWarnings('PMD.NoTrailingWhitespace, PMD.ExcessiveClassLength, PME.ExcessivePublicCount, PMD.ApexCRUDViolation, PMD.EmptyIfStmt, PMD.EmptyStatementBlock, PMD.AvoidNonRestrictiveQueries, PMD.CyclomaticComplexity, PMD.CognitiveComplexity, PMD.NcssCount, PMD.NcssTypeCount, PMD.DetectCopyPasteForApex, PMD.LocalVariableNamingConventions, PMD.ExcessiveParameterList, PMD.ApexSOQLInjection, PMD.AvoidDeeplyNestedIfStmts, PMD.AvoidDebugStatements, PMD.StdCyclomaticComplexity, PMD.NcssMethodCount')
public without sharing class HAM_GlobalResourcesController {

    @AuraEnabled(cacheable=true)
    public static List<ResourceWrapper> getResources() {
        List<ResourceWrapper> results = new List<ResourceWrapper>();

        try {
            // Querying fields used for both logic and the wrapper
            for(HAM_Listing__c rec : [
                SELECT Id, 
                       HAM_Title__c, 
                       HAM_Actual_link__c, 
                       HAM_Image_URL__c 
                FROM HAM_Listing__c 
                WHERE HAM_Category__c = 'Resources' 
                AND HAM_Is_Active__c = true 
                ORDER BY CreatedDate DESC
                LIMIT 100
            ]) {
                // Using the constructor for cleaner list population
                results.add(new ResourceWrapper(rec));
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching resources: ' + e.getMessage());
        }

        return results;
    }

    /**
     * Wrapper class to structure data for Lightning Components
     * Note: {get; set;} is required for the Aura/LWC framework to serialize the object correctly.
     */
    public class ResourceWrapper {
        @AuraEnabled public Id id {get; set;}
        @AuraEnabled public String title {get; set;}
        @AuraEnabled public String linkUrl {get; set;}
        @AuraEnabled public String imageUrl {get; set;}

        // Constructor to map the SObject fields to wrapper properties
        public ResourceWrapper(HAM_Listing__c rec) {
            this.id = rec.Id;
            this.title = rec.HAM_Title__c;
            this.linkUrl = rec.HAM_Actual_link__c;
            this.imageUrl = rec.HAM_Image_URL__c;
        }
    }
}