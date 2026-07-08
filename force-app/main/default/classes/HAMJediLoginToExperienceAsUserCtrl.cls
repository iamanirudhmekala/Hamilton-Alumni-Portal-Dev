/**
 * @description Controller for the "Log in to Experience as User" functionality.
 * Checks user permissions and builds the servlet.su login URL for Hamilton Portal community users.
 */
public without sharing class HAMJediLoginToExperienceAsUserCtrl {

    /**
     * @description Checks if the current user can log in as the community user associated with the given Contact.
     * Returns true if the user is a System Administrator or has the HAM_View_Portal_Profiles permission set,
     * and the Contact has an active community user in the Hamilton Portal.
     * @param contactId The Contact record Id to check
     * @return Boolean true if login-as is available, false otherwise
     */
    @AuraEnabled(cacheable=true)
    public static Boolean canLoginAsUser(String contactId) {
        if (String.isBlank(contactId)) {
            return false;
        }
        String profileName = [SELECT Profile.Name FROM User WHERE Id = :UserInfo.getUserId()].Profile.Name;
        if (profileName != 'System Administrator') {
            List<PermissionSetAssignment> psaList = [
                SELECT Id FROM PermissionSetAssignment
                WHERE AssigneeId = :UserInfo.getUserId()
                AND PermissionSet.Name = 'HAM_View_Portal_Profiles'
                LIMIT 1
            ];
            if (psaList.isEmpty()) {
                return false;
            }
        }
        List<User> communityUsers = [
            SELECT Id FROM User
            WHERE ContactId = :contactId AND IsActive = true
            LIMIT 1
        ];
        return !communityUsers.isEmpty();
    }

    /** @description The servlet.su URL to log in as the community user */
    public String loginUrl { get; private set; }
    /** @description Error message if the login URL cannot be built */
    public String errorMessage { get; private set; }

    /**
     * @description Constructor for VF page action. Reads contactId from page parameters,
     * queries the Hamilton Portal network and member, and builds the login URL.
     */
    public HAMJediLoginToExperienceAsUserCtrl() {
        String contactId = ApexPages.currentPage().getParameters().get('contactId');

        if (String.isBlank(contactId)) {
            errorMessage = 'No Contact ID provided.';
            return;
        }

        List<Network> networks = [
            SELECT Id FROM Network
            WHERE Status = 'Live' AND Name = 'Hamilton Portal'
            LIMIT 1
        ];

        if (networks.isEmpty()) {
            errorMessage = 'Hamilton Portal community not found.';
            return;
        }

        Id networkId = networks[0].Id;

        List<NetworkMember> members = [
            SELECT MemberId FROM NetworkMember
            WHERE NetworkId = :networkId
            AND Member.ContactId = :contactId
            AND Member.IsActive = true
            LIMIT 1
        ];

        if (members.isEmpty()) {
            errorMessage = 'No active Hamilton Portal user found for this contact.';
            return;
        }

        String userId = members[0].MemberId;
        String orgId = UserInfo.getOrganizationId();

        loginUrl = '/servlet/servlet.su?oid=' + orgId
            + '&sunetworkid=' + networkId
            + '&sunetworkuserid=' + userId;
    }
}