/**
* @File Name : HAM_MainController.cls
* @Description : Fetches 'My Links' menu items from HAM_Meta_Data__mdt.
* @Author : Cube84 - Sachin
* @Last Modified By : Sachin
* @Last Modified On : July 7, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | July 7, 2025 |  Sachin | Initial Version
* 1.1 | Sept 04, 2025 |  Sachin |  Done as part of Optimization
* 1.2 | Oct 30, 2025 |  Sachin |  create a new method to fetch primary consitutent type
* 1.3  | Apr 20,2026 | Anirudh | Student portal changes

**/
@SuppressWarnings('PMD.NoTrailingWhitespace, PMD.ExcessiveClassLength, PME.ExcessivePublicCount, PMD.ApexCRUDViolation, PMD.EmptyIfStmt, PMD.EmptyStatementBlock, PMD.AvoidNonRestrictiveQueries, PMD.CyclomaticComplexity, PMD.CognitiveComplexity, PMD.NcssCount, PMD.NcssTypeCount, PMD.DetectCopyPasteForApex, PMD.LocalVariableNamingConventions, PMD.ExcessiveParameterList, PMD.ApexSOQLInjection, PMD.AvoidDeeplyNestedIfStmts, PMD.AvoidDebugStatements, PMD.StdCyclomaticComplexity, PMD.NcssMethodCount')
public without sharing class HAM_MainController {
	
	/**
     * @Description : Fetches 'My Links' menu items from HAM_Meta_Data__mdt.
     * @return List<HAM_Meta_Data__mdt> List of metadata records for 'My Links'.
     */
    @AuraEnabled(cacheable=true)
    public static List<HAM_Meta_Data__mdt> getMyLinksMetaData() {
        List<HAM_Meta_Data__mdt> myLinks = [
            SELECT Id, MasterLabel, HAM_Display_Label__c, HAM_Redirect_Link__c, HAM_Order__c
            FROM HAM_Meta_Data__mdt WHERE HAM_Level_1__c = :HAM_ConstantsUtil.NAVBAR 
            ORDER BY HAM_Order__c];
        return myLinks;
    }


    /**
     * @Description : Fetches Logged in user's Portal Contact Record with required fields.
     * @return Data Type: Contact
     */
    @AuraEnabled(cacheable=true)
    public static Contact fetchLoggedInUserInfo() {
        try {
            
            Id currentUserId = UserInfo.getUserId();
            // 1. Get the current session user
            List<User> currentUsers = [SELECT Email, ContactId FROM User WHERE Id = :currentUserId LIMIT 1];
            if (currentUsers.isEmpty()) return null;

            Id targetContactId = currentUsers[0].ContactId;

            // 2. FALLBACK: If internal user (no ContactId), find their portal record
            if (targetContactId == null) {
                // Find an active Portal User with the same email
                List<User> portalUsers = [
                    SELECT ContactId 
                    FROM User 
                    WHERE Email = :currentUsers[0].Email 
                    AND ContactId != null 
                    AND IsActive = true 
                    AND Profile.Name = 'Partner Community Login User'
                    LIMIT 1
                ];
                if (!portalUsers.isEmpty()) {
                    targetContactId = portalUsers[0].ContactId;
                }
            }

            // 3. Final Query: Fetch the Contact record
            if (targetContactId != null) {
                List<Contact> contacts = [
                    SELECT Id, Name, Birthdate, HAM_Profile_Picture_URL__c,
                        HAM_Reunion_Year__c, ucinn_ascendv2__Contact_Type__c,
                        ucinn_ascendv2__Primary_Contact_Type__c,
                        Hamilton_Portal_Override__c,FirstName
                    FROM Contact
                    WHERE Id = :targetContactId
                    LIMIT 1
                ];
                return !contacts.isEmpty() ? contacts[0] : null;
            }
        } catch (Exception e) {
            System.debug('CRITICAL ERROR in fetchLoggedInUserInfo: ' + e.getMessage());
        }
        return null;
    }

    @AuraEnabled(cacheable=true)
    public static Contact getPrimaryContactType(Id contactId) {
        if (contactId == null) {
            return null;
        }
        Contact contactRecord = [
            SELECT ucinn_ascendv2__Primary_Contact_Type__c
            FROM Contact
            WHERE Id = :contactId
            LIMIT 1
        ];

        if (contactRecord != null) {
            return contactRecord;
        } else {
            return null;
        }
    }

    /**
     * @description: Returns the count of active Partner Community users with a linked Contact
     * @return Integer - count of registered portal users
     */
    @AuraEnabled(cacheable=true)
    public static Integer getRegisteredUsersCount() {
        return [
            SELECT COUNT() FROM User
            WHERE Profile.Name = 'Partner Community Login User'
            AND IsActive = true
            AND ContactId != null
        ];
    }

    /**
     * @description: Fetches the Feature Toggle status for the Giving App
     * @return Boolean - True if active, False if inactive (down)
     */
    @AuraEnabled(cacheable=true)
    public static Boolean getGivingAppStatus() {
        try {
            Ham_GivingApp_Feature_Toggle__mdt toggle = [
                SELECT Is_Active__c 
                FROM Ham_GivingApp_Feature_Toggle__mdt 
                WHERE DeveloperName = 'Giving_App'
                LIMIT 1
            ];
            return toggle.Is_Active__c;
        } catch (Exception e) {
            // Default to true so the app doesn't break if the metadata record goes missing
            return true; 
        }
    }
}