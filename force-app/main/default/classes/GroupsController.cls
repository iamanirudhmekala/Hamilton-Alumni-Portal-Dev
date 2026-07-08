public with sharing class GroupsController {

    // Wrapper class to pass flattened data to LWC
    public class GroupWrapper {
        @AuraEnabled public Id groupId { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String description { get; set; } 
        @AuraEnabled public String bannerUrl { get; set; }
        @AuraEnabled public Integer memberCount { get; set; }
        @AuraEnabled public String category { get; set; }
        @AuraEnabled public String userRole { get; set; } // E.g., 'Admin' badge
    }

    @AuraEnabled(cacheable=true)
    public static List<GroupWrapper> getGroups(String contactId, String tabMode, String searchTerm, String categoryFilter) {
        List<GroupWrapper> results = new List<GroupWrapper>();
        
        // Get current user's contact ID (assuming Community User)
        //Id contactId = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId()].ContactId;
        if (contactId == null) return results; // Exit if internal user without contact

        // Base Query setup
        String query = 'SELECT Id, Name, Banner_Image_URL__c, Category__c, Active_Member_Count__c, What_We_Offer__c ' +
                       'FROM HAM_Group__c WHERE is_Active__c = true ';
        
        // Apply Search and Filters
        if (String.isNotBlank(searchTerm)) {
            query += 'AND Name LIKE \'%' + String.escapeSingleQuotes(searchTerm) + '%\' ';
        }
        if (String.isNotBlank(categoryFilter)) {
            query += 'AND Category__c = \'' + String.escapeSingleQuotes(categoryFilter) + '\' ';
        }

        // Apply Tab Mode Logic (My Groups vs All Groups)
        if (tabMode == 'MyGroups') {
            query += 'AND Id IN (SELECT Group__c FROM HAM_Group_Member__c WHERE Contact__c = :contactId AND Status__c = \'Active\') ';
        }

        query += 'ORDER BY Name ASC LIMIT 50'; // Pagination limit
        List<HAM_Group__c> groups = Database.query(query);

        // Map Roles if it's "My Groups" to show the "Admin" badge
        Map<Id, String> groupRoleMap = new Map<Id, String>();
        if (tabMode == 'MyGroups') {
            List<HAM_Group_Member__c> members = [SELECT Group__c, Role__c FROM HAM_Group_Member__c 
                                                 WHERE Contact__c = :contactId AND Group__c IN :groups];
            for (HAM_Group_Member__c gm : members) {
                groupRoleMap.put(gm.Group__c, gm.Role__c);
            }
        }

        // Build Wrapper List
        for (HAM_Group__c g : groups) {
            GroupWrapper gw = new GroupWrapper();
            gw.groupId = g.Id;
            gw.name = g.Name;
            gw.bannerUrl = g.Banner_Image_URL__c;
            // Note: Assuming What_We_Offer__c serves as description, strip HTML if it's Rich Text
            gw.description = g.What_We_Offer__c != null ? g.What_We_Offer__c.stripHtmlTags().abbreviate(100) : ''; 
            gw.memberCount = Integer.valueOf(g.Active_Member_Count__c);
            gw.category = g.Category__c;
            gw.userRole = groupRoleMap.containsKey(g.Id) ? groupRoleMap.get(g.Id) : null;
            
            results.add(gw);
        }

        return results;
    }
    
}