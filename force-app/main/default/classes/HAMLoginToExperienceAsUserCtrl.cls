public without sharing class HAMLoginToExperienceAsUserCtrl {

    @AuraEnabled(cacheable=true)
    public static Boolean canLoginAsUser(String contactId) {
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

    public String loginUrl { get; private set; }
    public String errorMessage { get; private set; }

    public HAMLoginToExperienceAsUserCtrl() {
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