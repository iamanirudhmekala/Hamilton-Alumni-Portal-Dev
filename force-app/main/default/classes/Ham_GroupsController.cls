@SuppressWarnings('PMD.NoTrailingWhitespace, PMD.ExcessiveClassLength, PME.ExcessivePublicCount, PMD.ApexCRUDViolation, PMD.EmptyIfStmt, PMD.EmptyStatementBlock, PMD.AvoidNonRestrictiveQueries, PMD.CyclomaticComplexity, PMD.CognitiveComplexity, PMD.NcssCount, PMD.NcssTypeCount, PMD.DetectCopyPasteForApex, PMD.LocalVariableNamingConventions, PMD.ExcessiveParameterList, PMD.ApexSOQLInjection, PMD.AvoidDeeplyNestedIfStmts, PMD.AvoidDebugStatements, PMD.StdCyclomaticComplexity, PMD.NcssMethodCount')
public without sharing class Ham_GroupsController {

    // ─── Wrapper Classes ────────────────────────────────────────────────────────

    public class GroupResponse {
        @AuraEnabled public List<GroupWrapper> records;
        @AuraEnabled public Integer totalCount;
    }

    public class GroupWrapper {
        @AuraEnabled public String groupId;
        @AuraEnabled public String name;
        @AuraEnabled public String description;
        @AuraEnabled public String category;
        @AuraEnabled public String bannerUrl;
        @AuraEnabled public Integer memberCount;
        @AuraEnabled public Boolean isAdmin;
        @AuraEnabled public String membershipStatus;
    }

    public class GroupDetailWrapper {
        @AuraEnabled public String groupId;
        @AuraEnabled public String name;
        @AuraEnabled public String about;
        @AuraEnabled public String whatWeOffer;
        @AuraEnabled public String communityGuidelines;
        @AuraEnabled public String bannerUrl;
        @AuraEnabled public String category;
        @AuraEnabled public Integer memberCount;
        @AuraEnabled public String visibility;
        @AuraEnabled public String userRole;
        @AuraEnabled public String userMembershipStatus;
        @AuraEnabled public String userMembershipId;
        @AuraEnabled public Boolean receiveNotifications;
        @AuraEnabled public Boolean notifyOnTagged;
        @AuraEnabled public Boolean notifyOnAmplified;
        @AuraEnabled public AdminWrapper admin;
        @AuraEnabled public List<MemberPreviewWrapper> memberPreviews;
    }

    public class AdminWrapper {
        @AuraEnabled public String name;
        @AuraEnabled public String photoUrl;
        @AuraEnabled public String jobTitle;
        @AuraEnabled public String employer;
    }

    public class MemberPreviewWrapper {
        @AuraEnabled public String contactId;
        @AuraEnabled public String name;
        @AuraEnabled public String photoUrl;
        @AuraEnabled public String title;
    }

    public class MemberWrapper {
        @AuraEnabled public String contactId;
        @AuraEnabled public String name;
        @AuraEnabled public String photoUrl;
        @AuraEnabled public String graduationYear;
        @AuraEnabled public String industry;
        @AuraEnabled public String degree;
        @AuraEnabled public String connectionStatus;
        @AuraEnabled public Boolean isPrivacyMasked;
        @AuraEnabled public Boolean isBookmarked;
    }

    public class MemberPageWrapper {
        @AuraEnabled public List<MemberWrapper> members;
        @AuraEnabled public Integer totalCount;
        @AuraEnabled public Boolean hasMore;
    }

    // Directory-parity Members page: one page of group members served by the Alumni Directory
    // engine (same fuzzy search, filters, card metadata, and privacy rules as the directory).
    // constituentsData is ordered connections-first; primary/secondary connections are the
    // decoration rows the directory LWCs use to derive isConnected/isBookmarked/isRequestSent.
    public class MemberDirectoryPageWrapper {
        @AuraEnabled public List<HAM_AlumniDirectoryController.ConstituentWrapper> constituentsData;
        @AuraEnabled public List<HAM_AlumniDirectoryController.ConnectionWrapper> primaryConnections;
        @AuraEnabled public List<HAM_AlumniDirectoryController.ConnectionWrapper> secondaryConnections;
        @AuraEnabled public Integer totalCount;
        @AuraEnabled public Boolean protalLogedUserPrivacy; // spelling matches the directory response field consumed by the LWCs
    }

    // ─── Platform Cache & Settings Methods ──────────────────────────────

    @AuraEnabled(cacheable=true)
    public static HAM_Group_Setting__mdt getGroupSettings() {
        HAM_Group_Setting__mdt settings = HAM_Group_Setting__mdt.getInstance('Default_Settings');
        if (settings == null) throw new AuraHandledException('Group Metadata Settings missing.');
        return settings;
    }

    @AuraEnabled(cacheable=true)
    public static List<Id> getUserActiveGroupIds(Id contactId) {
        String cacheKey = 'local.HamCommunityPartition.userGroups' + contactId;
        List<Id> activeGroupIds = (List<Id>) Cache.Session.get(cacheKey);
        
        if (activeGroupIds == null) {
            Set<Id> uniqueIds = new Set<Id>();
            // Runs in system mode on purpose. HAM_Group__c is Private to external
            // users and HAM_Group_Member__c is ControlledByParent, so USER_MODE here
            // would hide a portal member's own membership rows and make every feed
            // and post read as unauthorized. This helper only returns the supplied
            // contact's own active group Ids, so there is no cross-user exposure.
            for(HAM_Group_Member__c mbr : [
                SELECT Group__c FROM HAM_Group_Member__c
                WHERE Contact__c = :contactId AND Status__c = 'Active'
            ]) {
                uniqueIds.add(mbr.Group__c);
            }
            
            // Convert Set to List to satisfy @AuraEnabled rules
            activeGroupIds = new List<Id>(uniqueIds);
            
            Integer ttl = (Integer) getGroupSettings().Cache_TTL_Seconds__c;
            Cache.Session.put(cacheKey, activeGroupIds, ttl != null ? ttl : 7200);
        }
        return activeGroupIds;
    }

    // ─── Discovery ──────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<String> getPicklistValues(String objectApiName, String fieldApiName) {
        Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(objectApiName);
        if (sObjectType == null) return new List<String>();
        Schema.SObjectField field = sObjectType.getDescribe().fields.getMap().get(fieldApiName);
        if (field == null) return new List<String>();
        List<String> values = new List<String>();
        for (Schema.PicklistEntry entry : field.getDescribe().getPicklistValues()) {
            if (entry.isActive()) values.add(entry.getValue());
        }
        return values;
    }

    @AuraEnabled(cacheable=true)
    public static GroupResponse getGroups(String contactId, String tabMode, String searchTerm,
                                               String categoryFilter, Integer limitSize, Integer offsetValue) {
        if (limitSize == null || limitSize <= 0) limitSize = 10;
        if (offsetValue == null || offsetValue < 0) offsetValue = 0;

        // OPTIMIZATION: Use the cached active group IDs instead of a new SOQL query
        Set<Id> memberGroupIds = new Set<Id>(getUserActiveGroupIds(contactId));
        Set<Id> adminGroupIds  = new Set<Id>();
        
        for (HAM_Group_Member__c m : [
            SELECT Group__c, Role__c FROM HAM_Group_Member__c
            WHERE Contact__c = :contactId AND Status__c = 'Active'
        ]) {
            memberGroupIds.add(m.Group__c);
            if (m.Role__c == 'Admin') adminGroupIds.add(m.Group__c);
        }

        /*
        String query = 'SELECT Id, Name, About__c, Category__c, Banner_Image_URL__c, Active_Member_Count__c '
                     + 'FROM HAM_Group__c WHERE is_Active__c = true';
        
        if (tabMode == 'MyGroups') {
            query += ' AND Id IN :memberGroupIds';
        } else {
            query += ' AND (Visibility__c = \'Public\' OR Id IN :memberGroupIds)';
        }

        String term = null;
        if (String.isNotBlank(searchTerm)) {
            term   = '%' + String.escapeSingleQuotes(searchTerm.trim()) + '%';
            query += ' AND (Name LIKE :term )';
        }
        if (String.isNotBlank(categoryFilter)) {
            query += ' AND Category__c = :categoryFilter';
        }  
        */

        // Build the shared WHERE clause once so the count and the data query match
        String whereClause = ' WHERE is_Active__c = true';
        if (tabMode == 'MyGroups') {
            whereClause += ' AND Id IN :memberGroupIds';
        } else {
            whereClause += ' AND (Visibility__c = \'Public\' OR Id IN :memberGroupIds)';
        }

        String term = null;
        if (String.isNotBlank(searchTerm)) {
            term = '%' + String.escapeSingleQuotes(searchTerm.trim()) + '%';
            whereClause += ' AND (Name LIKE :term)';
        }
        if (String.isNotBlank(categoryFilter)) {
            whereClause += ' AND Category__c = :categoryFilter';
        }

        // 1) Total count (no LIMIT/OFFSET) — needed for the pagination component
        Integer totalCount = Database.countQuery(
            'SELECT COUNT() FROM HAM_Group__c' + whereClause
        );

        // 2) The page of data
        String dataQuery = 'SELECT Id, Name, About__c, Category__c, Banner_Image_URL__c, Active_Member_Count__c '
                        + 'FROM HAM_Group__c' + whereClause
                        + ' ORDER BY Name LIMIT :limitSize OFFSET :offsetValue';

        List<GroupWrapper> result = new List<GroupWrapper>();
        for (HAM_Group__c g : Database.query(dataQuery)) {
            GroupWrapper gw   = new GroupWrapper();
            gw.groupId        = g.Id;
            gw.name           = g.Name;
            gw.description    = g.About__c;
            gw.category       = g.Category__c;
            gw.bannerUrl      = g.Banner_Image_URL__c;
            gw.memberCount    = g.Active_Member_Count__c != null ? Integer.valueOf(g.Active_Member_Count__c) : 0;
            gw.isAdmin        = adminGroupIds.contains(g.Id);
            gw.membershipStatus = memberGroupIds.contains(g.Id) ? 'Active' : null;
            result.add(gw);
        }

        GroupResponse resp = new GroupResponse();
        resp.records    = result;
        resp.totalCount = totalCount;
        return resp;
        
    }

    // ─── Group Detail ────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static GroupDetailWrapper getGroupDetail(String groupId, String contactId) {
        List<HAM_Group__c> groups = [
            SELECT Id, Name, About__c, What_We_Offer__c, Community_Guidelines__c,
                   Banner_Image_URL__c, Category__c, Active_Member_Count__c, Visibility__c,
                   (SELECT Contact__c, Contact__r.Name, Contact__r.HAM_Profile_Picture_URL__c,
                           Contact__r.Title, Contact__r.Constituent_Employer__r.Name,
                           Role__c, Status__c
                    FROM HAM_Group_Members__r
                    WHERE Status__c = 'Active'
                    LIMIT 10)
            FROM HAM_Group__c
            WHERE Id = :groupId
        ];
        if (groups.isEmpty()) return null;

        HAM_Group__c g          = groups[0];
        GroupDetailWrapper detail = new GroupDetailWrapper();
        detail.groupId            = g.Id;
        detail.name               = g.Name;
        detail.about              = g.About__c;
        detail.whatWeOffer        = g.What_We_Offer__c;
        detail.communityGuidelines = g.Community_Guidelines__c;
        detail.bannerUrl          = g.Banner_Image_URL__c;
        detail.category           = g.Category__c;
        detail.memberCount        = g.Active_Member_Count__c != null ? Integer.valueOf(g.Active_Member_Count__c) : 0;
        detail.visibility         = g.Visibility__c;
        detail.memberPreviews     = new List<MemberPreviewWrapper>();

        for (HAM_Group_Member__c m : g.HAM_Group_Members__r) {
            // Constituent_Employer__c is a Lookup to Account — the field itself holds the
            // Account Id, so the employer *name* only comes off the relationship.
            String employerName = m.Contact__r.Constituent_Employer__r != null
                ? m.Contact__r.Constituent_Employer__r.Name
                : null;

            MemberPreviewWrapper preview = new MemberPreviewWrapper();
            preview.contactId = m.Contact__c;
            preview.name      = m.Contact__r.Name;
            preview.photoUrl  = m.Contact__r.HAM_Profile_Picture_URL__c;
            preview.title     = formatMemberTitle(m.Contact__r.Title, employerName);
            detail.memberPreviews.add(preview);
        }

        // Queried separately from the LIMIT 10 preview list above: Role__c is a
        // picklist whose Setup-defined value order is Member, then Admin, so
        // "ORDER BY Role__c ASC" sorts Member rows first — once a group has 10+
        // active members, that preview query can fill up on Members before ever
        // reaching the Admin row. A dedicated query guarantees the admin card
        // still populates regardless of group size.
        List<HAM_Group_Member__c> adminRows = [
            SELECT Contact__r.Name, Contact__r.HAM_Profile_Picture_URL__c,
                   Contact__r.Title, Contact__r.Constituent_Employer__r.Name
            FROM HAM_Group_Member__c
            WHERE Group__c = :groupId AND Status__c = 'Active' AND Role__c = 'Admin'
            LIMIT 1
        ];
        if (!adminRows.isEmpty()) {
            HAM_Group_Member__c adminRow = adminRows[0];
            AdminWrapper admin = new AdminWrapper();
            admin.name     = adminRow.Contact__r.Name;
            admin.photoUrl = adminRow.Contact__r.HAM_Profile_Picture_URL__c;
            admin.jobTitle = adminRow.Contact__r.Title;
            admin.employer = adminRow.Contact__r.Constituent_Employer__r != null
                ? adminRow.Contact__r.Constituent_Employer__r.Name
                : null;
            detail.admin   = admin;
        }

        // Current user membership
        List<HAM_Group_Member__c> userMembership = [
            SELECT Id, Role__c, Status__c, Receive_Notifications__c,
                   Notify_on_Tagged__c, Notify_on_Amplified__c
            FROM HAM_Group_Member__c
            WHERE Group__c = :groupId AND Contact__c = :contactId
            LIMIT 1
        ];
        if (!userMembership.isEmpty()) {
            detail.userMembershipId     = userMembership[0].Id;
            detail.userRole             = userMembership[0].Role__c;
            detail.userMembershipStatus = userMembership[0].Status__c;
            detail.receiveNotifications = userMembership[0].Receive_Notifications__c;
            detail.notifyOnTagged       = userMembership[0].Notify_on_Tagged__c;
            detail.notifyOnAmplified    = userMembership[0].Notify_on_Amplified__c;
        }

        return detail;
    }

    // "{Title} at {Employer}" for the sidebar member rows, degrading to whichever
    // half exists. Same shape as the admin card's subtitle.
    private static String formatMemberTitle(String jobTitle, String employer) {
        Boolean hasTitle    = String.isNotBlank(jobTitle);
        Boolean hasEmployer = String.isNotBlank(employer);
        if (hasTitle && hasEmployer) return jobTitle + ' at ' + employer;
        if (hasTitle)                return jobTitle;
        if (hasEmployer)             return employer;
        return '';
    }

    // ─── Group Members ───────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static MemberPageWrapper getGroupMembers(String groupId, String contactId,
                                                    Integer pageSize, Integer pageNumber,
                                                    String searchKey, String filtersJson) {
        if (pageSize == null || pageSize <= 0) pageSize = 10;
        if (pageNumber == null || pageNumber <= 0) pageNumber = 1;
        Integer offsetValue = (pageNumber - 1) * pageSize;

        // Parse filter map
        Map<String, Object> filtersMap = new Map<String, Object>();
        if (String.isNotBlank(filtersJson)) {
            filtersMap = (Map<String, Object>) JSON.deserializeUntyped(filtersJson);
        }
        String classYearStr  = (String) filtersMap.get('HAM_Reunion_Year__c');
        String industryFilter = (String) filtersMap.get('HAM_Industry__c');

        // Enforce access via inner-join pattern (TDD security requirement)
        Set<Id> memberContactIds = new Set<Id>();
        for (HAM_Group_Member__c m : [
            SELECT Contact__c FROM HAM_Group_Member__c
            WHERE Group__c = :groupId AND Status__c = 'Active'
        ]) {
            memberContactIds.add(m.Contact__c);
        }
        if (String.isNotBlank(contactId)) memberContactIds.remove(Id.valueOf(contactId));

        Integer totalCount = memberContactIds.size();
        if (memberContactIds.isEmpty()) return buildEmptyPage(totalCount);

        // Build dynamic SOQL — bind vars must be declared before Database.query()
        String searchTerm = null;
        if (String.isNotBlank(searchKey)) {
            searchTerm = '%' + String.escapeSingleQuotes(searchKey.trim()) + '%';
        }
        Decimal classYear = null;
        if (String.isNotBlank(classYearStr)) {
            try { classYear = Decimal.valueOf(classYearStr); } catch (Exception e) {}
        }

        String contactQuery = 'SELECT Id, Name, HAM_Reunion_Year__c, HAM_Industry__c, '
            + 'HAM_Profile_Picture_URL__c, '
            + '(SELECT ucinn_ascendv2__Major_Formula__c '
            + ' FROM ucinn_ascendv2__Degree_Information_Contact__r LIMIT 1) '
            + 'FROM Contact WHERE Id IN :memberContactIds';

        if (searchTerm  != null)                 contactQuery += ' AND Name LIKE :searchTerm';
        if (classYear   != null)                 contactQuery += ' AND HAM_Reunion_Year__c = :classYear';
        if (String.isNotBlank(industryFilter))   contactQuery += ' AND HAM_Industry__c = :industryFilter';
        contactQuery += ' ORDER BY Name LIMIT :pageSize OFFSET :offsetValue';

        List<Contact> contacts = Database.query(contactQuery);

        List<Id> memberIds = new List<Id>();
        for (Contact c : contacts) memberIds.add(c.Id);

        Map<Id, String> connectionStateMap = getConnectionStates(contactId, memberIds);
        Set<Id> privacyMaskedIds           = getPrivacyMaskedContacts(new Set<Id>(memberIds));
        Set<Id> bookmarkedIds              = getBookmarkedContacts(contactId, memberIds);

        List<MemberWrapper> members = new List<MemberWrapper>();
        for (Contact c : contacts) {
            MemberWrapper mw  = new MemberWrapper();
            mw.contactId      = c.Id;
            mw.isPrivacyMasked = privacyMaskedIds.contains(c.Id);

            if (!mw.isPrivacyMasked) {
                mw.name          = c.Name;
                mw.photoUrl      = c.HAM_Profile_Picture_URL__c;
                mw.graduationYear = c.HAM_Reunion_Year__c != null
                    ? String.valueOf(Integer.valueOf(c.HAM_Reunion_Year__c)) : '';
                mw.industry = c.HAM_Industry__c;
                if (c.ucinn_ascendv2__Degree_Information_Contact__r != null
                        && !c.ucinn_ascendv2__Degree_Information_Contact__r.isEmpty()) {
                    mw.degree = c.ucinn_ascendv2__Degree_Information_Contact__r[0]
                                  .ucinn_ascendv2__Major_Formula__c;
                }
            } else {
                mw.name = 'Hidden Member';
            }
            mw.connectionStatus = connectionStateMap.get(c.Id);
            mw.isBookmarked     = bookmarkedIds.contains(c.Id);
            members.add(mw);
        }

        MemberPageWrapper result = new MemberPageWrapper();
        result.members    = members;
        result.totalCount = totalCount;
        result.hasMore    = contacts.size() == pageSize;
        return result;
    }

    /**
     * @description Directory-parity replacement for getGroupMembers (which is retained for backward
     * compatibility but no longer used by ham_groupMembers). Serves one page of the group's Active
     * members through the Alumni Directory engine so search (multi-word + nickname fuzzy match),
     * all directory filters, card fields (HAM_Meta_Data__mdt), and privacy rules behave exactly as
     * on the Search Directory tab. Results are ordered connections-first (each bucket A→Z by name),
     * paginating seamlessly across the bucket boundary.
     * @param groupId Group whose members are listed.
     * @param contactId Logged-in portal user's Contact Id (must be an Active member of the group).
     * @param pageSize Records per page (directory default 9).
     * @param recordsToSkip Zero-based offset of the first record on the requested page.
     * @param searchKey Search bar input (same semantics as the directory search bar).
     * @param selectedFilters Directory filter payload: list of {placeholder, values} maps.
     * @return MemberDirectoryPageWrapper with the page's constituents, decoration connections and total count.
     */
    @AuraEnabled(cacheable=true)
    public static MemberDirectoryPageWrapper getGroupMembersDirectory(String groupId, String contactId,
                                                                      Integer pageSize, Integer recordsToSkip,
                                                                      String searchKey,
                                                                      List<Map<String, Object>> selectedFilters) {
        if (pageSize == null || pageSize <= 0) pageSize = 9;
        if (recordsToSkip == null || recordsToSkip < 0) recordsToSkip = 0;

        MemberDirectoryPageWrapper page = new MemberDirectoryPageWrapper();
        page.constituentsData     = new List<HAM_AlumniDirectoryController.ConstituentWrapper>();
        page.primaryConnections   = new List<HAM_AlumniDirectoryController.ConnectionWrapper>();
        page.secondaryConnections = new List<HAM_AlumniDirectoryController.ConnectionWrapper>();
        page.totalCount           = 0;
        page.protalLogedUserPrivacy = false;

        if (String.isBlank(groupId) || String.isBlank(contactId)) return page;
        Id callerContactId = Id.valueOf(contactId);

        // Access enforcement via inner-join pattern (same as getGroupMembers): the caller must
        // themselves be an Active member. For directory parity the visible population includes the
        // caller's own card — self flows through getDirectoryData exactly like the main directory,
        // and the shared display components render it with the same self-card treatment
        // (Send Request greyed, no bookmark/three-dot menu, View Profile visible).
        Boolean callerIsActiveMember = false;
        Set<Id> memberContactIds = new Set<Id>();
        for (HAM_Group_Member__c m : [
            SELECT Contact__c FROM HAM_Group_Member__c
            WHERE Group__c = :groupId AND Status__c = 'Active'
        ]) {
            if (m.Contact__c == null) continue;
            if (m.Contact__c == callerContactId) {
                callerIsActiveMember = true;
            }
            memberContactIds.add(m.Contact__c);
        }
        if (!callerIsActiveMember || memberContactIds.isEmpty()) return page;

        // Split members into the caller's connections vs the rest. Accepting a connection sets
        // HAM_Is_Connected__c on both orientation rows (HAM_AlumniConnectionService.handleAccept),
        // so the portal-user orientation alone is authoritative and matches the flag decoration
        // the directory display components read.
        Set<Id> connectedIds = new Set<Id>();
        for (HAM_Connection__c conn : [
            SELECT HAM_Linked_Constituent__c FROM HAM_Connection__c
            WHERE HAM_Portal_User__c = :callerContactId
              AND HAM_Is_Connected__c = true AND HAM_Is_Blocked__c = false
              AND HAM_Linked_Constituent__c IN :memberContactIds
        ]) {
            connectedIds.add(conn.HAM_Linked_Constituent__c);
        }
        List<Id> connectedList = new List<Id>(connectedIds);
        List<Id> otherList = new List<Id>();
        for (Id memberId : memberContactIds) {
            if (!connectedIds.contains(memberId)) otherList.add(memberId);
        }

        // BUILD_TAB ('Search Directory') gives the directory's constituent-card semantics and keeps
        // the decoration queries bounded to the page's constituents.
        String directoryTab = HAM_ConstantsUtil.BUILD_TAB;
        List<Map<String, Object>> filters = selectedFilters == null
            ? new List<Map<String, Object>>() : selectedFilters;

        Integer connectedCount = connectedList.isEmpty() ? 0
            : HAM_AlumniDirectoryController.getDirectoryDataCount(
                directoryTab, searchKey, filters, callerContactId, null, null, null, connectedList);
        Integer othersCount = otherList.isEmpty() ? 0
            : HAM_AlumniDirectoryController.getDirectoryDataCount(
                directoryTab, searchKey, filters, callerContactId, null, null, null, otherList);
        page.totalCount = connectedCount + othersCount;

        // Fill the requested window [recordsToSkip, recordsToSkip + pageSize) from the connected
        // bucket first, then top up from the non-connected bucket.
        Integer takenFromConnected = 0;
        if (recordsToSkip < connectedCount) {
            takenFromConnected = Math.min(pageSize, connectedCount - recordsToSkip);
            appendDirectoryPage(page, HAM_AlumniDirectoryController.getDirectoryData(
                directoryTab, takenFromConnected, recordsToSkip, searchKey, filters,
                callerContactId, null, null, null, connectedList));
        }
        Integer remaining = pageSize - takenFromConnected;
        if (remaining > 0 && othersCount > 0) {
            Integer othersSkip = Math.max(0, recordsToSkip - connectedCount);
            if (othersSkip < othersCount) {
                appendDirectoryPage(page, HAM_AlumniDirectoryController.getDirectoryData(
                    directoryTab, remaining, othersSkip, searchKey, filters,
                    callerContactId, null, null, null, otherList));
            }
        }
        return page;
    }

    private static void appendDirectoryPage(MemberDirectoryPageWrapper page,
                                            HAM_AlumniDirectoryController.DirectoryResponse resp) {
        if (resp == null) return;
        if (resp.constituentsData != null) {
            page.constituentsData.addAll(resp.constituentsData);
        }
        if (resp.connectionsData != null && resp.connectionsData.primaryConnections != null) {
            page.primaryConnections.addAll(resp.connectionsData.primaryConnections);
        }
        if (resp.connectionsData != null && resp.connectionsData.secondaryConnections != null) {
            page.secondaryConnections.addAll(resp.connectionsData.secondaryConnections);
        }
        if (resp.protalLogedUserPrivacy != null) {
            page.protalLogedUserPrivacy = resp.protalLogedUserPrivacy;
        }
    }

    // ─── Membership Actions ──────────────────────────────────────────────────────

    @AuraEnabled
    public static String joinGroup(String groupId, String contactId, String message) {
        try {
            List<HAM_Group__c> groups = [SELECT Visibility__c FROM HAM_Group__c WHERE Id = :groupId LIMIT 1];
            if (groups.isEmpty()) return 'Error';

            // Check if membership already exists
            List<HAM_Group_Member__c> existing = [
                SELECT Id, Status__c FROM HAM_Group_Member__c
                WHERE Group__c = :groupId AND Contact__c = :contactId LIMIT 1
            ];

            // Every join request — Public or Private group — goes to Pending so it
            // surfaces in the admin moderation tab for accept/reject; membership only
            // becomes Active once an admin approves it (see approveMember).
            String status = 'Pending';

            if (!existing.isEmpty()) {
                if (existing[0].Status__c == 'Blocked') return 'Blocked';

                // Members who previously left keep their record (see leaveGroup),
                // so rejoining revives that record instead of inserting a duplicate.
                if (existing[0].Status__c != 'Left') return 'Already Member';

                existing[0].Status__c              = status;
                existing[0].Leave_Reason__c         = null;
                existing[0].Leave_Reason_Other__c   = null;
                existing[0].Join_Request_Message__c = message;
                update existing;
                Cache.Session.remove('local.HamCommunityPartition.userGroups' + contactId);
                return 'Success';
            }

            insert new HAM_Group_Member__c(
                Group__c                = groupId,
                Contact__c              = contactId,
                Status__c               = status,
                Role__c                 = 'Member',
                Join_Request_Message__c = message
            );
            // New membership must invalidate the cached active-group list, or feed
            // and post authorization (getUserActiveGroupIds) keeps rejecting the user
            // until the session cache TTL lapses.
            Cache.Session.remove('local.HamCommunityPartition.userGroups' + contactId);
            return 'Success';
        } catch (Exception e) {
            return e.getMessage();
        }
    }

    @AuraEnabled
    public static String leaveGroup(String groupId, String contactId, List<String> leaveReasons, String otherReason) {
        try {
            List<HAM_Group_Member__c> members = [
                SELECT Id, Status__c FROM HAM_Group_Member__c
                WHERE Group__c = :groupId AND Contact__c = :contactId
                  AND Status__c IN ('Active', 'Pending') LIMIT 1
            ];
            if (members.isEmpty()) return 'Success';

            if (members[0].Status__c == 'Pending') {
                // Cancelling a request that was never approved — nothing to retain
                delete members;
            } else {
                // Soft-delete: the record is kept with the exit survey answers so
                // Alumni Relations can report on why members leave. Every consumer
                // (rollup count, feed access, member list) filters on Active, so a
                // 'Left' record is invisible to the portal.
                members[0].Status__c = 'Left';
                members[0].Leave_Reason__c = (leaveReasons != null && !leaveReasons.isEmpty())
                    ? String.join(leaveReasons, ';')
                    : null;
                members[0].Leave_Reason_Other__c = otherReason;
                update members;
            }

            // Drop the cached membership list so group access is revoked immediately
            Cache.Session.remove('local.HamCommunityPartition.userGroups' + contactId);
            return 'Success';
        } catch (Exception e) {
            return e.getMessage();
        }
    }

    // Only these fields may be flipped via updateNotificationPreferences — guards
    // against a caller passing an arbitrary field name into the dynamic put().
    private static final Set<String> NOTIFICATION_PREFERENCE_FIELDS = new Set<String>{
        'Receive_Notifications__c', 'Notify_on_Tagged__c', 'Notify_on_Amplified__c'
    };

    // Switching the master toggle off must also switch these off, rather than leaving
    // them true-but-inert underneath it.
    private static final Set<String> MASTER_DEPENDENT_FIELDS = new Set<String>{
        'Notify_on_Tagged__c', 'Notify_on_Amplified__c'
    };

    /**
     * @description Flips one or more notification-preference checkboxes on the
     *              caller's own membership row in a single DML. Routed through this
     *              without-sharing method (rather than the LWC calling
     *              lightning/uiRecordApi's updateRecord directly) because
     *              HAM_Group_Member__c's sharing model doesn't grant portal users
     *              edit access to their own row under standard sharing — the same
     *              reason every other write in this controller goes through Apex
     *              instead of Lightning Data Service.
     *              Turning the master toggle (Receive_Notifications__c) off also forces
     *              Tagged and Amplified off, so the stored preferences can never say
     *              "notify me when tagged" while the member receives nothing. The LWC
     *              stages the same cascade, but it's re-applied here so the invariant
     *              holds for any caller.
     * @param changes Map of field API name -> new boolean value (e.g. from a
     *                "Save" button batching several toggles at once).
     */
    @AuraEnabled
    public static void updateNotificationPreferences(Id membershipId, Id currentContactId, Map<String, Boolean> changes) {
        if (changes == null || changes.isEmpty()) {
            return;
        }
        for (String fieldApiName : changes.keySet()) {
            if (!NOTIFICATION_PREFERENCE_FIELDS.contains(fieldApiName)) {
                throw new AuraHandledException('Invalid notification preference field: ' + fieldApiName);
            }
        }

        List<HAM_Group_Member__c> members = [
            SELECT Id, Contact__c FROM HAM_Group_Member__c WHERE Id = :membershipId LIMIT 1
        ];
        if (members.isEmpty() || members[0].Contact__c != currentContactId) {
            throw new AuraHandledException('Unauthorized access to membership record.');
        }

        Map<String, Boolean> effectiveChanges = new Map<String, Boolean>(changes);
        if (effectiveChanges.get('Receive_Notifications__c') == false) {
            for (String dependentField : MASTER_DEPENDENT_FIELDS) {
                effectiveChanges.put(dependentField, false);
            }
        }

        HAM_Group_Member__c member = new HAM_Group_Member__c(Id = membershipId);
        for (String fieldApiName : effectiveChanges.keySet()) {
            member.put(fieldApiName, effectiveChanges.get(fieldApiName));
        }

        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.UPDATABLE, new List<HAM_Group_Member__c>{member});
        update decision.getRecords();
    }

    // ─── Private Helpers ─────────────────────────────────────────────────────────

    private static Map<Id, String> getConnectionStates(String portalContactId, List<Id> memberContactIds) {
        Map<Id, String> stateMap = new Map<Id, String>();
        if (memberContactIds.isEmpty()) return stateMap;

        for (Ham_Connection__c conn : [
            SELECT HAM_Portal_User__c, HAM_Linked_Constituent__c,
                   HAM_Connection_Status__c, HAM_Is_Connected__c
            FROM Ham_Connection__c
            WHERE (HAM_Portal_User__c    = :portalContactId AND HAM_Linked_Constituent__c IN :memberContactIds)
               OR (HAM_Linked_Constituent__c = :portalContactId AND HAM_Portal_User__c IN :memberContactIds)
        ]) {
            Id otherId = conn.HAM_Portal_User__c == portalContactId
                ? conn.HAM_Linked_Constituent__c
                : conn.HAM_Portal_User__c;

            if (conn.HAM_Is_Connected__c == true
                    || conn.HAM_Connection_Status__c == HAM_ConstantsUtil.CONNECTED) {
                stateMap.put(otherId, 'Connected');
            } else if (conn.HAM_Connection_Status__c == HAM_ConstantsUtil.REQUEST_SENT
                       && conn.HAM_Portal_User__c == portalContactId) {
                stateMap.put(otherId, 'Request Sent');
            }
        }
        return stateMap;
    }

    private static Set<Id> getPrivacyMaskedContacts(Set<Id> contactIds) {
        Set<Id> masked = new Set<Id>();
        Id siRecordTypeId = Schema.SObjectType.ucinn_ascendv2__Service_Indicator__c
            .getRecordTypeInfosByName()
            .get(HAM_ConstantsUtil.CONTACT_SERVICE_INDICATOR_RECORD_TYPE)
            .getRecordTypeId();

        for (ucinn_ascendv2__Service_Indicator__c si : [
            SELECT ucinn_ascendv2__Contact__c,
                   ucinn_ascendv2__Service_Indicator_Value__r.HAM_Portal_ID__c
            FROM ucinn_ascendv2__Service_Indicator__c
            WHERE RecordTypeId                 = :siRecordTypeId
              AND ucinn_ascendv2__Contact__c   IN :contactIds
              AND ucinn_ascendv2__Is_Active__c = true
        ]) {
            if (HAM_ConstantsUtil.ALUMNI_PRIVCACY_SVID.equals(
                    si.ucinn_ascendv2__Service_Indicator_Value__r.HAM_Portal_ID__c)) {
                masked.add(si.ucinn_ascendv2__Contact__c);
            }
        }
        return masked;
    }

    private static Set<Id> getBookmarkedContacts(String portalContactId, List<Id> memberContactIds) {
        Set<Id> bookmarked = new Set<Id>();
        if (String.isBlank(portalContactId) || memberContactIds.isEmpty()) return bookmarked;
        for (Ham_Connection__c conn : [
            SELECT HAM_Linked_Constituent__c
            FROM Ham_Connection__c
            WHERE HAM_Portal_User__c         = :portalContactId
              AND HAM_Linked_Constituent__c  IN :memberContactIds
              AND HAM_Is_bookmarked__c       = true
        ]) {
            bookmarked.add(conn.HAM_Linked_Constituent__c);
        }
        return bookmarked;
    }

    private static MemberPageWrapper buildEmptyPage(Integer totalCount) {
        MemberPageWrapper empty = new MemberPageWrapper();
        empty.members    = new List<MemberWrapper>();
        empty.totalCount = totalCount;
        empty.hasMore    = false;
        return empty;
    }

    // ─── Comment & Moderation wrappers ──────────────────────────────────────────
    public class CommentWrapper {
        @AuraEnabled public String commentId;
        @AuraEnabled public String postId;
        @AuraEnabled public String body;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public String authorName;
        @AuraEnabled public String authorPhotoUrl;
        @AuraEnabled public String contactId;
    }

    public class ModerationDashboardWrapper {
        @AuraEnabled public Integer totalReports;
        @AuraEnabled public Integer resolvedCount;
        @AuraEnabled public Integer pendingCount;
        @AuraEnabled public List<ReportWrapper> pendingReports;
        @AuraEnabled public List<ReportWrapper> resolvedReports;
    }

    public class ReportWrapper {
        @AuraEnabled public String reportId;
        @AuraEnabled public List<String> reportIds;
        @AuraEnabled public String postId;
        @AuraEnabled public String commentId;
        @AuraEnabled public String reason;
        @AuraEnabled public String status;
        @AuraEnabled public String reportedByDisplay;
        @AuraEnabled public Integer totalReportCount;
        @AuraEnabled public String reportedUserName;
        @AuraEnabled public String contentBody;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public Boolean isUserReport;
    }

    public class PendingMemberWrapper {
        @AuraEnabled public String memberRecordId;
        @AuraEnabled public String contactId;
        @AuraEnabled public String name;
        @AuraEnabled public String photoUrl;
    }

    // ─── NEW: Discussion Feed & Polling Methods ──────────────────────────────

    public class PostWrapper {
        @AuraEnabled public Id id;
        @AuraEnabled public String body;
        @AuraEnabled public String tags;
        @AuraEnabled public String authorName;
        @AuraEnabled public String authorPhotoUrl;
        @AuraEnabled public Boolean isAnonymous;
        @AuraEnabled public Boolean isPinned;
        @AuraEnabled public Boolean isAmplified;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public Integer commentCount;
        @AuraEnabled public Boolean isOwnPost;
        @AuraEnabled public Boolean hasMorePages;
        @AuraEnabled public List<AttachmentWrapper> attachments = new List<AttachmentWrapper>();
    }

    public class AttachmentWrapper {
        @AuraEnabled public Id contentDocumentId;
        @AuraEnabled public Id contentVersionId;
        @AuraEnabled public String title;       // full filename incl. extension
        @AuraEnabled public String fileExtension;
        @AuraEnabled public Boolean isImage;
        @AuraEnabled public String downloadUrl; // Shepherd download link for the latest version
    }

    // Extensions rendered inline as <img> in the feed; everything else shows as a download chip.
    private static final Set<String> IMAGE_EXTENSIONS = new Set<String>{
        'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'bmp', 'svg'
    };

    // Builds postId -> attachments from the ContentDocumentLinks on the given posts,
    // resolving each document's latest ContentVersion for the title/type/download URL.
    private static Map<Id, List<AttachmentWrapper>> getPostAttachments(Set<Id> postIds) {
        Map<Id, List<AttachmentWrapper>> byPost = new Map<Id, List<AttachmentWrapper>>();
        if (postIds == null || postIds.isEmpty()) return byPost;

        // Link rows tie each ContentDocument to its post; keep them to fan back out per post.
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :postIds
        ];
        if (links.isEmpty()) return byPost;

        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink l : links) docIds.add(l.ContentDocumentId);

        Map<Id, ContentVersion> latestByDoc = new Map<Id, ContentVersion>();
        for (ContentVersion cv : [
            SELECT Id, ContentDocumentId, Title, FileExtension
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds AND IsLatest = true
        ]) {
            latestByDoc.put(cv.ContentDocumentId, cv);
        }

        for (ContentDocumentLink l : links) {
            ContentVersion cv = latestByDoc.get(l.ContentDocumentId);
            if (cv == null) continue;

            AttachmentWrapper a = new AttachmentWrapper();
            a.contentDocumentId = l.ContentDocumentId;
            a.contentVersionId  = cv.Id;
            a.title             = cv.Title;
            a.fileExtension     = cv.FileExtension;
            a.isImage           = cv.FileExtension != null
                && IMAGE_EXTENSIONS.contains(cv.FileExtension.toLowerCase());
            a.downloadUrl       = '/sfc/servlet.shepherd/version/download/' + cv.Id;

            if (!byPost.containsKey(l.LinkedEntityId)) {
                byPost.put(l.LinkedEntityId, new List<AttachmentWrapper>());
            }
            byPost.get(l.LinkedEntityId).add(a);
        }
        return byPost;
    }

    public class PostAuthorWrapper {
        @AuraEnabled public Id contactId;
        @AuraEnabled public String name;
        @AuraEnabled public String photoUrl;
    }

    // Backward-compatible overload for direct Apex callers (e.g. tests) that don't need filters.
    // Not @AuraEnabled itself — overload resolution across two @AuraEnabled methods of the same
    // name is unreliable from LWC, so only the filtered version below is exposed to the client.
    public static List<PostWrapper> getGroupFeed(Id groupId, Id currentContactId, Id lastPostId) {
        return getGroupFeed(groupId, currentContactId, lastPostId, null, null, null, null, false, null);
    }

    @AuraEnabled
    public static List<PostWrapper> getGroupFeed(Id groupId, Id currentContactId, Id lastPostId,
                                                  String searchTerm, Datetime startDate, Datetime endDate,
                                                  String authorContactId, Boolean bookmarkedOnly,
                                                  Id targetPostId) {
        Set<Id> allowedGroups = new Set<Id>(getUserActiveGroupIds(currentContactId));
        if(!allowedGroups.contains(groupId)) throw new AuraHandledException('Unauthorized access.');

        Integer limitSize = (Integer) getGroupSettings().Feed_Pagination_Size__c;
        if (limitSize == null || limitSize == 0) limitSize = 20;

        // Short-circuit when the user has no bookmarks at all — nothing else can match
        Set<Id> bookmarkedPostIds = null;
        if (bookmarkedOnly == true) {
            bookmarkedPostIds = new Set<Id>(getBookmarkedPostIds());
            if (bookmarkedPostIds.isEmpty()) return new List<PostWrapper>();
        }

        String likeTerm = null;
        String tagLikeTerm = null;
        if (String.isNotBlank(searchTerm)) {
            String trimmed = searchTerm.trim();
            likeTerm = '%' + String.escapeSingleQuotes(trimmed) + '%';
            String tagOnly = trimmed.startsWith('#') ? trimmed.substring(1).trim() : trimmed;
            tagLikeTerm = '%' + String.escapeSingleQuotes(tagOnly) + '%';
        }

        String baseFields = 'Id, Body__c, Tags__c, Author__c, Author__r.Name, Author__r.HAM_Profile_Picture_URL__c, Is_Anonymous__c, Is_Pinned__c, Is_Amplified__c, Amplified_On__c, CreatedDate';

        // Amplified posts are promoted (and badged) for 7 days from Amplified_On__c,
        // then fall back into their normal chronological position automatically.
        Datetime amplifyCutoff = System.now().addDays(-7);

        // Is_Draft__c = false excludes in-progress posts that are still collecting file uploads.
        // A post the admin has taken action on beyond a warning (e.g. deleted/blocked) is hidden
        // from the feed; null (no action) and 'Warn the user' both leave the post visible.
        String sharedFilter = ' WHERE Group__c = :groupId AND Is_Draft__c = false '
                             + 'AND (Ham_Admin_Action__c = null OR Ham_Admin_Action__c = \'Warn the user\') ';
        if (likeTerm != null) {
            sharedFilter += 'AND (Tags__c LIKE :tagLikeTerm OR (Is_Anonymous__c = false AND Author__r.Name LIKE :likeTerm)) ';
        }
        if (startDate != null) sharedFilter += 'AND CreatedDate >= :startDate ';
        if (endDate != null) sharedFilter += 'AND CreatedDate <= :endDate ';
        if (String.isNotBlank(authorContactId)) {
            if ('ANONYMOUS'.equalsIgnoreCase(authorContactId)) {
                sharedFilter += 'AND Is_Anonymous__c = true ';
            } else {
                sharedFilter += 'AND Is_Anonymous__c = false AND Author__c = :authorContactId ';
            }
        }
        if (bookmarkedPostIds != null) sharedFilter += 'AND Id IN :bookmarkedPostIds ';

        List<HAM_Group_Post__c> dbPosts = new List<HAM_Group_Post__c>();

        // Top of the feed on the initial page load (lastPostId == null) only, so
        // "load more" doesn't re-show or duplicate them — the paginated query below
        // excludes both blocks. Order: actively amplified first, then pinned.
        if (lastPostId == null) {
            // Actively amplified posts (last 7 days) lead the feed, newest
            // amplification first — they sort ABOVE pinned posts.
            String amplifiedQuery = 'SELECT ' + baseFields + ' FROM HAM_Group_Post__c' + sharedFilter
                                + 'AND Is_Pinned__c = false AND Is_Amplified__c = true AND Amplified_On__c >= :amplifyCutoff '
                                + 'ORDER BY Amplified_On__c DESC LIMIT 50';
            dbPosts.addAll((List<HAM_Group_Post__c>) Database.query(amplifiedQuery));

            // Pinned posts follow the amplified block. A post that is both pinned
            // and amplified stays in this pinned bucket (the amplified query above
            // excludes pinned).
            String pinnedQuery = 'SELECT ' + baseFields + ' FROM HAM_Group_Post__c' + sharedFilter
                                + 'AND Is_Pinned__c = true ORDER BY CreatedDate DESC LIMIT 50';
            dbPosts.addAll((List<HAM_Group_Post__c>) Database.query(pinnedQuery));
        }

        String query = 'SELECT ' + baseFields + ' FROM HAM_Group_Post__c' + sharedFilter + 'AND Is_Pinned__c = false ';
        // Exclude actively amplified posts — they already appear in the initial-load
        // block above. Keyset pagination (Id < :lastPostId) stays untouched.
        query += 'AND (Is_Amplified__c = false OR Amplified_On__c = null OR Amplified_On__c < :amplifyCutoff) ';
        if (lastPostId != null) query += 'AND Id < :lastPostId ';
        // Fetch one row past the page size so we can tell whether another page exists
        // without a separate COUNT query, then trim the extra row back off before returning.
        Integer queryLimit = limitSize + 1;
        query += 'ORDER BY Id DESC LIMIT :queryLimit';
        List<HAM_Group_Post__c> paginatedPosts = (List<HAM_Group_Post__c>) Database.query(query);
        Boolean hasMorePages = paginatedPosts.size() > limitSize;
        if (hasMorePages) paginatedPosts.remove(paginatedPosts.size() - 1);
        dbPosts.addAll(paginatedPosts);

        if (String.isNotBlank(searchTerm)) {
            String cleanSearchTerm = searchTerm.trim().toLowerCase();
            String tagSearchTerm = cleanSearchTerm.startsWith('#') ? cleanSearchTerm.substring(1) : cleanSearchTerm;
            List<HAM_Group_Post__c> filteredPosts = new List<HAM_Group_Post__c>();
            for (HAM_Group_Post__c p : dbPosts) {
                Boolean matchesBody = p.Body__c != null && p.Body__c.toLowerCase().contains(cleanSearchTerm);
                Boolean matchesTags = p.Tags__c != null && (p.Tags__c.toLowerCase().contains(cleanSearchTerm) || p.Tags__c.toLowerCase().contains(tagSearchTerm));
                Boolean matchesAuthor = p.Is_Anonymous__c == false && p.Author__r != null && p.Author__r.Name != null && p.Author__r.Name.toLowerCase().contains(cleanSearchTerm);
                if (matchesBody || matchesTags || matchesAuthor) {
                    filteredPosts.add(p);
                }
            }
            dbPosts = filteredPosts;
        }

        // Deep-linked post (amplify notification, or moderation "View Content"): the feed
        // is keyset-paginated, so a post older than the first page never reached the client
        // and the scroll-to-post silently no-opped. Fetch it explicitly and put it at the
        // HEAD of the list — appending would corrupt the client's keyset cursor, which is
        // the Id of the last element. Visibility rules stay identical to the feed queries,
        // so a soft-hidden or foreign-group post still resolves to nothing (the client then
        // tells the user rather than failing silently).
        if (lastPostId == null && targetPostId != null) {
            Boolean alreadyLoaded = false;
            for (HAM_Group_Post__c p : dbPosts) {
                if (p.Id == targetPostId) {
                    alreadyLoaded = true;
                    break;
                }
            }
            if (!alreadyLoaded) {
                List<HAM_Group_Post__c> targetPosts = [
                    SELECT Id, Body__c, Tags__c, Author__c, Author__r.Name,
                           Author__r.HAM_Profile_Picture_URL__c, Is_Anonymous__c, Is_Pinned__c,
                           Is_Amplified__c, Amplified_On__c, CreatedDate
                    FROM HAM_Group_Post__c
                    WHERE Id = :targetPostId
                      AND Group__c = :groupId
                      AND Is_Draft__c = false
                      AND (Ham_Admin_Action__c = null OR Ham_Admin_Action__c = 'Warn the user')
                ];
                if (!targetPosts.isEmpty()) {
                    List<HAM_Group_Post__c> merged = new List<HAM_Group_Post__c>(targetPosts);
                    merged.addAll(dbPosts);
                    dbPosts = merged;
                }
            }
        }

        Set<Id> postIds = new Set<Id>();
        for (HAM_Group_Post__c p : dbPosts) postIds.add(p.Id);

        // Matches the visibility filter in getPostComments — a soft-hidden comment
        // (Ham_Admin_Action__c beyond a warning) must not inflate the reply count
        // shown on the post.
        Map<Id, Integer> commentCountsByPost = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Post__c postId, COUNT(Id) cnt
            FROM HAM_Group_Comment__c
            WHERE Post__c IN :postIds
              AND (Ham_Admin_Action__c = null OR Ham_Admin_Action__c = 'Warn the user')
            GROUP BY Post__c
        ]) {
            commentCountsByPost.put((Id) ar.get('postId'), (Integer) ar.get('cnt'));
        }

        // Attachments (images + files) linked to the posts on this page.
        Map<Id, List<AttachmentWrapper>> attachmentsByPost = getPostAttachments(postIds);

        List<PostWrapper> wrappers = new List<PostWrapper>();
        for (HAM_Group_Post__c p : dbPosts) {
            PostWrapper w   = new PostWrapper();
            w.id            = p.Id;
            w.body          = p.Body__c;
            w.attachments   = attachmentsByPost.containsKey(p.Id)
                ? attachmentsByPost.get(p.Id) : new List<AttachmentWrapper>();
            w.tags          = p.Tags__c;
            w.isAnonymous   = p.Is_Anonymous__c;
            w.isPinned      = p.Is_Pinned__c;
            // "Amplified" (badge + highlight) only while inside the 7-day window,
            // so expired amplifications render as normal posts without a batch job.
            w.isAmplified   = p.Is_Amplified__c == true && p.Amplified_On__c != null && p.Amplified_On__c >= amplifyCutoff;
            w.createdDate   = p.CreatedDate;
            w.commentCount  = commentCountsByPost.containsKey(p.Id) ? commentCountsByPost.get(p.Id) : 0;
            w.isOwnPost     = (p.Author__c != null && p.Author__c == currentContactId);
            w.hasMorePages  = hasMorePages;

            // SERVER-SIDE anonymity masking: identity must never leave the server for
            // anonymous posts. DB retains Author__c for traceability/moderation.
            if (p.Is_Anonymous__c == true) {
                w.authorName     = 'Anonymous';
                w.authorPhotoUrl = null;
            } else {
                w.authorName     = (p.Author__r != null) ? p.Author__r.Name : 'Community Member';
                w.authorPhotoUrl = (p.Author__r != null) ? p.Author__r.HAM_Profile_Picture_URL__c : null;
            }
            wrappers.add(w);
        }
        return wrappers;
    }

    @AuraEnabled
    public static Boolean checkForNewPosts(Id groupId, Long clientLastSyncTime) {
        Long serverLastUpdate = (Long) Cache.Session.get('local.HamCommunityPartition.lastUpdate' + groupId);
        return (serverLastUpdate != null && serverLastUpdate > clientLastSyncTime);
    }

    /**
     * @description Distinct list of non-anonymous authors who have posted in this group,
     *              used to populate the feed's "People" filter dropdown.
     */
    @AuraEnabled(cacheable=true)
    public static List<PostAuthorWrapper> getGroupPostAuthors(Id groupId, Id currentContactId) {
        Set<Id> allowedGroups = new Set<Id>(getUserActiveGroupIds(currentContactId));
        if (!allowedGroups.contains(groupId)) throw new AuraHandledException('Unauthorized access.');

        Set<Id> authorIds = new Set<Id>();
        for (HAM_Group_Post__c p : [
            SELECT Author__c FROM HAM_Group_Post__c
            WHERE Group__c = :groupId AND Is_Draft__c = false
              AND Is_Anonymous__c = false AND Author__c != null
        ]) {
            authorIds.add(p.Author__c);
        }
        if (authorIds.isEmpty()) return new List<PostAuthorWrapper>();

        List<PostAuthorWrapper> results = new List<PostAuthorWrapper>();
        for (Contact c : [
            SELECT Id, Name, HAM_Profile_Picture_URL__c
            FROM Contact WHERE Id IN :authorIds
            ORDER BY Name ASC
        ]) {
            PostAuthorWrapper w = new PostAuthorWrapper();
            w.contactId = c.Id;
            w.name      = c.Name;
            w.photoUrl  = c.HAM_Profile_Picture_URL__c;
            results.add(w);
        }
        return results;
    }

    @AuraEnabled
    public static List<HAM_Group_Post__c> createPosts(List<HAM_Group_Post__c> newPosts, Id currentContactId) {

        // Validate input
        if(newPosts == null || newPosts.isEmpty()) {
            throw new AuraHandledException('Posts cannot be empty.');
        }

        // Fetch all groups current user has access to
        Set<Id> allowedGroups = new Set<Id>(
            getUserActiveGroupIds(currentContactId)
        );

        // Validate each incoming post
        for(HAM_Group_Post__c post : newPosts) {

            if(post == null) {
                throw new AuraHandledException('Post record cannot be null.');
            }

            if(post.Group__c == null) {
                throw new AuraHandledException('Group is required.');
            }

            if(!allowedGroups.contains(post.Group__c)) {
                throw new AuraHandledException(
                    'Unauthorized access to group.'
                );
            }
        }

        // Apply CRUD/FLS security to the client-supplied fields only
        SObjectAccessDecision decision = Security.stripInaccessible(
            AccessType.CREATABLE,
            newPosts
        );

        List<SObject> sanitizedRecords = decision.getRecords();

        // Cast before inserting
        List<HAM_Group_Post__c> postsToInsert =
            (List<HAM_Group_Post__c>)sanitizedRecords;

        // Author__c is trusted, server-computed data (never client-supplied), so it's
        // stamped after the FLS strip — otherwise a portal profile without field-level
        // access to Author__c would silently insert posts with no author.
        for (HAM_Group_Post__c post : postsToInsert) {
            post.Author__c = currentContactId;
            post.Ham_Admin_Action__c = null;
        }

        // Single DML
        insert postsToInsert;

        dispatchPostNotifications(postsToInsert);

        return postsToInsert;
    }

    /**
     * @description Shared post-publish side effects: bump the Session Cache update
     *              timestamp (so adaptive polling detects new posts), publish platform
     *              events, and enqueue the background push-notification Queueable.
     *              Used by both createPosts and publishDraftPost.
     */
    private static void dispatchPostNotifications(List<HAM_Group_Post__c> posts) {
        if (posts == null || posts.isEmpty()) return;

        Long currentTime = System.now().getTime();
        Set<Id> updatedGroups = new Set<Id>();

        for (HAM_Group_Post__c post : posts) {
            updatedGroups.add(post.Group__c);
        }

        // One cache update per unique group
        for (Id grpId : updatedGroups) {
            Cache.Session.put('local.HamCommunityPartition.lastUpdate' + grpId, currentTime);
        }

        // Per the client's 2026-07-21 rule, a plain new post notifies NOBODY — even
        // with the master toggle on. The only notification a post can generate is the
        // "Tagged in a Post" fan-out below, to @mentioned members. The generic
        // "New post in {Group}" fan-out (HAM_NotificationQueueable(postIds)) has been
        // removed accordingly; the HAM_Group_Notification__e platform-event path was
        // already disabled for the same double-notify reasons.

        // "Tagged in a Post" fan-out: a notification to just the @mentioned members —
        // now the sole notification a post produces.
        for (HAM_Group_Post__c post : posts) {
            List<Id> mentionedIds = parseMentionedContactIds(post.Mentioned_Contact_Ids__c);
            if (!mentionedIds.isEmpty()) {
                System.enqueueJob(new HAM_NotificationQueueable(post.Id, mentionedIds, post.Author__c, 'Post'));
            }
        }
    }

    // ─── Draft Post Lifecycle (enables large-file uploads via lightning-file-upload) ──
    //
    // lightning-file-upload needs a real record Id to attach ContentVersions to and
    // streams files server-side (no Apex heap ceiling, unlike base64). So when a user
    // wants to attach files, we first create a hidden draft post, bind the uploader to
    // it, then publish the draft when the user clicks Post. Drafts are filtered out of
    // the feed until published.

    @AuraEnabled
    public static Id createDraftPost(Id groupId, Id currentContactId) {
        if (groupId == null) {
            throw new AuraHandledException('Group is required.');
        }
        Set<Id> allowedGroups = new Set<Id>(getUserActiveGroupIds(currentContactId));
        if (!allowedGroups.contains(groupId)) {
            throw new AuraHandledException('Unauthorized access to group.');
        }

        HAM_Group_Post__c draft = new HAM_Group_Post__c(
            Group__c    = groupId,
            Author__c   = currentContactId,
            Is_Draft__c = true,
            Ham_Admin_Action__c = null
        );
        insert draft;
        return draft.Id;
    }

    @AuraEnabled
    public static HAM_Group_Post__c publishDraftPost(Id postId, String body, String tags,
                                                     Boolean isAnonymous, Id currentContactId,
                                                     String mentionedContactIds) {
        if (postId == null) {
            throw new AuraHandledException('Draft post Id is required.');
        }

        List<HAM_Group_Post__c> drafts = [
            SELECT Id, Group__c, Author__c, Is_Draft__c
            FROM HAM_Group_Post__c
            WHERE Id = :postId LIMIT 1
        ];
        if (drafts.isEmpty()) {
            throw new AuraHandledException('Draft post not found.');
        }

        HAM_Group_Post__c draft = drafts[0];

        // Only the author may publish their own draft, and only into a group they belong to
        if (draft.Author__c != currentContactId) {
            throw new AuraHandledException('You can only publish your own draft.');
        }
        Set<Id> allowedGroups = new Set<Id>(getUserActiveGroupIds(currentContactId));
        if (!allowedGroups.contains(draft.Group__c)) {
            throw new AuraHandledException('Unauthorized access to group.');
        }

        draft.Body__c                  = body;
        draft.Tags__c                  = tags;
        draft.Is_Anonymous__c          = (isAnonymous == true);
        draft.Mentioned_Contact_Ids__c = mentionedContactIds;
        draft.Is_Draft__c              = false;
        update draft;

        dispatchPostNotifications(new List<HAM_Group_Post__c>{ draft });
        return draft;
    }

    @AuraEnabled
    public static void discardDraftPost(Id postId, Id currentContactId) {
        if (postId == null) return;
        List<HAM_Group_Post__c> drafts = [
            SELECT Id, Author__c, Is_Draft__c
            FROM HAM_Group_Post__c
            WHERE Id = :postId AND Author__c = :currentContactId AND Is_Draft__c = true
            LIMIT 1
        ];
        if (!drafts.isEmpty()) {
            delete drafts;
        }
    }

    /**
     * @description Lets the original author edit their own post's content/tags.
     *              Anonymity and pinned/amplified state are left untouched.
     */
    @AuraEnabled
    public static PostWrapper updatePost(Id postId, String body, String tags, Id currentContactId) {
        if (String.isBlank(body)) {
            throw new AuraHandledException('Post content cannot be blank.');
        }
        List<HAM_Group_Post__c> posts = [
            SELECT Id, Author__c, Author__r.Name, Author__r.HAM_Profile_Picture_URL__c,
                   Is_Anonymous__c, Is_Pinned__c, Is_Amplified__c, CreatedDate
            FROM HAM_Group_Post__c
            WHERE Id = :postId LIMIT 1
        ];
        if (posts.isEmpty()) {
            throw new AuraHandledException('Post not found.');
        }

        HAM_Group_Post__c post = posts[0];
        if (post.Author__c != currentContactId) {
            throw new AuraHandledException('You can only edit your own posts.');
        }

        post.Body__c = body;
        post.Tags__c = tags;

        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.UPDATABLE, new List<HAM_Group_Post__c>{ post });
        update decision.getRecords();

        PostWrapper w  = new PostWrapper();
        w.id           = post.Id;
        w.body         = body;
        w.tags         = tags;
        w.isAnonymous  = post.Is_Anonymous__c;
        w.isPinned     = post.Is_Pinned__c;
        w.isAmplified  = post.Is_Amplified__c;
        w.createdDate  = post.CreatedDate;
        w.commentCount = [
            SELECT COUNT() FROM HAM_Group_Comment__c
            WHERE Post__c = :postId
              AND (Ham_Admin_Action__c = null OR Ham_Admin_Action__c = 'Warn the user')
        ];
        w.isOwnPost    = true;

        if (post.Is_Anonymous__c == true) {
            w.authorName     = 'Anonymous';
            w.authorPhotoUrl = null;
        } else {
            w.authorName     = (post.Author__r != null) ? post.Author__r.Name : 'Community Member';
            w.authorPhotoUrl = (post.Author__r != null) ? post.Author__r.HAM_Profile_Picture_URL__c : null;
        }
        return w;
    }

    /**
     * @description Admin-only: toggles a post's pinned state. Pinned posts are
     *              surfaced at the top of the feed by getGroupFeed. Returns the
     *              resulting Is_Pinned__c value.
     */
    @AuraEnabled
    public static Boolean togglePinPost(Id postId, Id currentContactId) {
        List<HAM_Group_Post__c> posts = [
            SELECT Id, Group__c, Is_Pinned__c FROM HAM_Group_Post__c WHERE Id = :postId LIMIT 1
        ];
        if (posts.isEmpty()) {
            throw new AuraHandledException('Post not found.');
        }

        HAM_Group_Post__c post = posts[0];
        checkModerationAccess(post.Group__c, currentContactId);

        post.Is_Pinned__c = !post.Is_Pinned__c;
        update post;
        return post.Is_Pinned__c;
    }

    /**
     * @description Deletes a post. Allowed for the post's own author, or a group
     *              admin/moderator removing someone else's post. When a moderator
     *              deletes another member's post, the author is notified.
     */
    @AuraEnabled
    public static void deletePost(Id postId, Id currentContactId) {
        List<HAM_Group_Post__c> posts = [
            SELECT Id, Group__c, Group__r.Name, Author__c, Body__c
            FROM HAM_Group_Post__c
            WHERE Id = :postId LIMIT 1
        ];
        if (posts.isEmpty()) {
            throw new AuraHandledException('Post not found.');
        }

        HAM_Group_Post__c post = posts[0];
        Boolean isOwnPost = (post.Author__c == currentContactId);
        if (!isOwnPost) {
            checkModerationAccess(post.Group__c, currentContactId);
        }

        delete post;

        // Notify the author only when someone else (a moderator/admin) removed their post.
        if (!isOwnPost && post.Author__c != null) {
            notifyPostDeleted(post, currentContactId);
        }
    }

    /**
     * @description Single-recipient notification sent to a post's author when a
     *              moderator deletes their post. Run synchronously (not queued)
     *              since it's a single insert, not a group-wide fan-out.
     */
    private static void notifyPostDeleted(HAM_Group_Post__c post, Id deletedByContactId) {
        try {
            Id recipientUserId;
            for (User u : [SELECT Id FROM User WHERE ContactId = :post.Author__c AND IsActive = true LIMIT 1]) {
                recipientUserId = u.Id;
            }

            String title = 'Your post was removed from ' + post.Group__r.Name;
            String plainBody = 'A moderator removed your post for violating community guidelines.';
            String actionUrl = '?view=groups&groupId=' + post.Group__c + '&subview=discussion';

            HAM_Notification__c n = new HAM_Notification__c();
            n.HAM_Constituent__c      = post.Author__c;
            n.HAM_Sender_Contact__c   = deletedByContactId;
            n.HAM_Title__c            = title;
            n.HAM_Body__c             = plainBody;
            n.HAM_Source_Object_ID__c = post.Group__c;
            n.HAM_Source_Type__c      = 'Groups';
            n.HAM_Status__c           = HAM_ConstantsUtil.UNREAD_S;
            n.HAM_Expiration_Date__c  = System.today().addDays(30);
            n.HAM_Action_URL__c       = actionUrl;

            SObjectAccessDecision decision = Security.stripInaccessible(AccessType.CREATABLE, new List<HAM_Notification__c>{ n });
            insert decision.getRecords();

            if (recipientUserId != null) {
                List<CustomNotificationType> types = [
                    SELECT Id, DeveloperName FROM CustomNotificationType
                    WHERE DeveloperName IN ('Hamilton_Group_Alert', 'HAM_Portal_General_Notification')
                ];
                Map<String, Id> typeMap = new Map<String, Id>();
                for (CustomNotificationType t : types) typeMap.put(t.DeveloperName, t.Id);
                Id typeId = typeMap.containsKey('Hamilton_Group_Alert')
                    ? typeMap.get('Hamilton_Group_Alert')
                    : (typeMap.containsKey('HAM_Portal_General_Notification') ? typeMap.get('HAM_Portal_General_Notification') : null);

                if (typeId != null) {
                    Messaging.CustomNotification currNotification = new Messaging.CustomNotification();
                    currNotification.setTitle(title);
                    currNotification.setBody(plainBody);
                    currNotification.setNotificationTypeId(typeId);
                    currNotification.setTargetPageRef(HAM_NotificationService.buildTargetPageRef(actionUrl));
                    currNotification.send(new Set<String>{ recipientUserId });
                }
            }
        } catch (Exception e) {
            System.debug('Exception notifying post author of deletion: ' + e.getMessage());
        }
    }

    // ─── Post Comments Methods ──────────────────────────────────────────────────

    @AuraEnabled
    public static List<CommentWrapper> getPostComments(Id postId) {
        List<CommentWrapper> results = new List<CommentWrapper>();
        
        List<HAM_Group_Comment__c> dbComments = [
            SELECT Id, Post__c, Body__c, CreatedDate,
                   HAM_Group_Member__r.Contact__c,
                   HAM_Group_Member__r.Contact__r.Name,
                   HAM_Group_Member__r.Contact__r.HAM_Profile_Picture_URL__c
            FROM HAM_Group_Comment__c
            WHERE Post__c = :postId
              AND (Ham_Admin_Action__c = null OR Ham_Admin_Action__c = 'Warn the user')
            ORDER BY CreatedDate DESC
        ];
        
        for (HAM_Group_Comment__c c : dbComments) {
            CommentWrapper cw = new CommentWrapper();
            cw.commentId = c.Id;
            cw.postId = c.Post__c;
            cw.body = c.Body__c;
            cw.createdDate = c.CreatedDate;
            cw.authorName = c.HAM_Group_Member__r.Contact__r.Name;
            cw.authorPhotoUrl = c.HAM_Group_Member__r.Contact__r.HAM_Profile_Picture_URL__c;
            cw.contactId = c.HAM_Group_Member__r.Contact__c;
            results.add(cw);
        }
        return results;
    }

    @AuraEnabled
    public static CommentWrapper createComment(Id postId, String body, Id currentContactId, String mentionedContactIds) {
        if (String.isBlank(body)) {
            throw new AuraHandledException('Comment body cannot be blank.');
        }

        List<HAM_Group_Post__c> posts = [SELECT Group__c FROM HAM_Group_Post__c WHERE Id = :postId LIMIT 1];
        if (posts.isEmpty()) {
            throw new AuraHandledException('Parent post not found.');
        }
        Id groupId = posts[0].Group__c;

        // Verify membership
        List<HAM_Group_Member__c> members = [
            SELECT Id FROM HAM_Group_Member__c
            WHERE Group__c = :groupId AND Contact__c = :currentContactId AND Status__c = 'Active'
            LIMIT 1
        ];
        if (members.isEmpty()) {
            throw new AuraHandledException('You are not an active member of this group.');
        }

        HAM_Group_Comment__c newComment = new HAM_Group_Comment__c();
        newComment.Post__c = postId;
        newComment.Body__c = body;
        newComment.HAM_Group_Member__c = members[0].Id;
        newComment.Mentioned_Contact_Ids__c = mentionedContactIds;

        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.CREATABLE, new List<HAM_Group_Comment__c>{newComment});
        List<HAM_Group_Comment__c> commentsToInsert = (List<HAM_Group_Comment__c>)decision.getRecords();
        commentsToInsert[0].Ham_Admin_Action__c = null;
        insert commentsToInsert;

        HAM_Group_Comment__c inserted = commentsToInsert[0];

        // "Tagged in a Comment" fan-out: distinct notification to just the @mentioned members
        List<Id> mentionedIds = parseMentionedContactIds(mentionedContactIds);
        if (!mentionedIds.isEmpty()) {
            System.enqueueJob(new HAM_NotificationQueueable(inserted.Id, mentionedIds, currentContactId, 'Comment'));
        }

        // Re-query to get audit fields
        List<CommentWrapper> wraps = getPostComments(postId);
        for (CommentWrapper cw : wraps) {
            if (cw.commentId == inserted.Id) {
                return cw;
            }
        }
        return null;
    }

    /**
     * @description Lets the original commenter edit the text of their own reply.
     */
    @AuraEnabled
    public static CommentWrapper updateComment(Id commentId, String body, Id currentContactId) {
        if (String.isBlank(body)) {
            throw new AuraHandledException('Comment cannot be blank.');
        }

        List<HAM_Group_Comment__c> comments = [
            SELECT Id, Post__c, HAM_Group_Member__r.Contact__c
            FROM HAM_Group_Comment__c
            WHERE Id = :commentId LIMIT 1
        ];
        if (comments.isEmpty()) {
            throw new AuraHandledException('Comment not found.');
        }

        HAM_Group_Comment__c comment = comments[0];
        if (comment.HAM_Group_Member__r.Contact__c != currentContactId) {
            throw new AuraHandledException('You can only edit your own replies.');
        }

        comment.Body__c = body;
        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.UPDATABLE, new List<HAM_Group_Comment__c>{ comment });
        update decision.getRecords();

        List<CommentWrapper> wraps = getPostComments(comment.Post__c);
        for (CommentWrapper cw : wraps) {
            if (cw.commentId == commentId) {
                return cw;
            }
        }
        return null;
    }

    // ─── Bookmarking / Saved Posts Methods ───────────────────────────────────────

    @AuraEnabled
    public static String bookmarkPost(Id postId) {
        try {
            Id userId = UserInfo.getUserId();
            List<HAM_Saved_Post__c> existing = [
                SELECT Id FROM HAM_Saved_Post__c 
                WHERE Post__c = :postId AND User__c = :userId 
                LIMIT 1
            ];
            if (!existing.isEmpty()) {
                return 'Already Bookmarked';
            }

            HAM_Saved_Post__c bookmark = new HAM_Saved_Post__c();
            bookmark.Post__c = postId;
            bookmark.User__c = userId;

            SObjectAccessDecision decision = Security.stripInaccessible(AccessType.CREATABLE, new List<HAM_Saved_Post__c>{bookmark});
            insert decision.getRecords();
            return 'Success';
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static String unbookmarkPost(Id postId) {
        try {
            Id userId = UserInfo.getUserId();
            List<HAM_Saved_Post__c> existing = [
                SELECT Id FROM HAM_Saved_Post__c 
                WHERE Post__c = :postId AND User__c = :userId
            ];
            if (!existing.isEmpty()) {
                delete existing;
            }
            return 'Success';
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Id> getBookmarkedPostIds() {
        Id userId = UserInfo.getUserId();
        List<Id> postIds = new List<Id>();
        for (HAM_Saved_Post__c bookmark : [
            SELECT Post__c FROM HAM_Saved_Post__c 
            WHERE User__c = :userId
        ]) {
            postIds.add(bookmark.Post__c);
        }
        return postIds;
    }

    // ─── Curated Resources Methods ───────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<HAM_Group_Resource__c> getGroupResources(Id groupId) {
        return [
            SELECT Id, Title__c, URL__c, Order__c 
            FROM HAM_Group_Resource__c
            WHERE Group__c = :groupId AND Is_Active__c = true
            ORDER BY Order__c ASC
        ];
    }

    @AuraEnabled
    public static String addResource(Id groupId, String title, String url, Id contactId, String description, String category, String imageUrl) {
        checkModerationAccess(groupId, contactId);

        HAM_Group_Resource__c resource = new HAM_Group_Resource__c();
        resource.Group__c = groupId;
        resource.Title__c = title;
        resource.URL__c = url;
        resource.Description__c = description;
        resource.Category__c = String.isNotBlank(category) ? category : 'General';
        resource.Image_URL__c = imageUrl;
        resource.Is_Active__c = true;
        resource.Order__c = 0;

        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.CREATABLE, new List<HAM_Group_Resource__c>{resource});
        insert decision.getRecords();
        return 'Success';
    }

    public class ResourceCardWrapper {
        @AuraEnabled public Id resourceId;
        @AuraEnabled public String title;
        @AuraEnabled public String url;
        @AuraEnabled public String description;
        @AuraEnabled public String category;
        @AuraEnabled public String imageUrl;
        @AuraEnabled public Boolean isAmplified;
        @AuraEnabled public Boolean isBookmarked;
    }

    /**
     * @description Resources tab payload: active resources for the group decorated
     *              with the running user's bookmark state. Bookmarked cards are
     *              returned first so they land at the top of the tab.
     */
    @AuraEnabled
    public static List<ResourceCardWrapper> getGroupResourceCards(Id groupId) {
        Id userId = UserInfo.getUserId();

        List<HAM_Group_Resource__c> records = [
            SELECT Id, Title__c, URL__c, Description__c, Category__c, Image_URL__c,
                   Is_Amplified__c, Order__c
            FROM HAM_Group_Resource__c
            WHERE Group__c = :groupId AND Is_Active__c = true
            ORDER BY Order__c ASC, CreatedDate DESC
        ];

        Set<Id> bookmarkedIds = new Set<Id>();
        for (HAM_Saved_Resource__c saved : [
            SELECT Resource__c FROM HAM_Saved_Resource__c
            WHERE User__c = :userId AND Resource__c IN :records
        ]) {
            bookmarkedIds.add(saved.Resource__c);
        }

        List<ResourceCardWrapper> bookmarked = new List<ResourceCardWrapper>();
        List<ResourceCardWrapper> everythingElse = new List<ResourceCardWrapper>();

        for (HAM_Group_Resource__c res : records) {
            ResourceCardWrapper card = new ResourceCardWrapper();
            card.resourceId   = res.Id;
            card.title        = res.Title__c;
            card.url          = res.URL__c;
            card.description  = res.Description__c;
            card.category     = res.Category__c;
            card.imageUrl     = res.Image_URL__c;
            card.isAmplified  = res.Is_Amplified__c;
            card.isBookmarked = bookmarkedIds.contains(res.Id);

            if (card.isBookmarked) {
                bookmarked.add(card);
            } else {
                everythingElse.add(card);
            }
        }

        bookmarked.addAll(everythingElse);
        return bookmarked;
    }

    @AuraEnabled
    public static String bookmarkResource(Id resourceId) {
        try {
            Id userId = UserInfo.getUserId();
            List<HAM_Saved_Resource__c> existing = [
                SELECT Id FROM HAM_Saved_Resource__c
                WHERE Resource__c = :resourceId AND User__c = :userId
                LIMIT 1
            ];
            if (!existing.isEmpty()) {
                return 'Already Bookmarked';
            }

            HAM_Saved_Resource__c bookmark = new HAM_Saved_Resource__c();
            bookmark.Resource__c = resourceId;
            bookmark.User__c = userId;

            SObjectAccessDecision decision = Security.stripInaccessible(AccessType.CREATABLE, new List<HAM_Saved_Resource__c>{bookmark});
            insert decision.getRecords();
            return 'Success';
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static String unbookmarkResource(Id resourceId) {
        try {
            Id userId = UserInfo.getUserId();
            List<HAM_Saved_Resource__c> existing = [
                SELECT Id FROM HAM_Saved_Resource__c
                WHERE Resource__c = :resourceId AND User__c = :userId
            ];
            if (!existing.isEmpty()) {
                delete existing;
            }
            return 'Success';
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Admin-only "Amplify": flags the resource as highlighted and kicks
     *              off a background Queueable that alerts every active group member.
     */
    @AuraEnabled
    public static String amplifyResource(Id groupId, Id resourceId, Id contactId) {
        checkModerationAccess(groupId, contactId);

        List<HAM_Group_Resource__c> resources = [
            SELECT Id FROM HAM_Group_Resource__c
            WHERE Id = :resourceId AND Group__c = :groupId LIMIT 1
        ];
        if (resources.isEmpty()) {
            throw new AuraHandledException('Resource not found in this group.');
        }

        resources[0].Is_Amplified__c = true;
        resources[0].Amplified_On__c = System.now();
        update resources;

        // Notification fan-out runs async, same as new-post alerts
        System.enqueueJob(new HAM_NotificationQueueable(resourceId, contactId, 'Resource'));
        return 'Success';
    }

    /**
     * @description Admin-only "Remove Amplification" for a resource — the corrective
     *              path for an accidental amplify, mirroring unamplifyPost. Clears
     *              Is_Amplified__c (removes the badge/highlight), leaves Amplified_On__c
     *              as an audit trail, and sends no notification.
     */
    @AuraEnabled
    public static String unamplifyResource(Id groupId, Id resourceId, Id contactId) {
        checkModerationAccess(groupId, contactId);

        List<HAM_Group_Resource__c> resources = [
            SELECT Id, Is_Amplified__c FROM HAM_Group_Resource__c
            WHERE Id = :resourceId AND Group__c = :groupId LIMIT 1
        ];
        if (resources.isEmpty()) {
            throw new AuraHandledException('Resource not found in this group.');
        }

        resources[0].Is_Amplified__c = false;
        update resources;
        return 'Success';
    }

    /**
     * @description Admin-only "Amplify": flags a post as highlighted and kicks
     *              off a background Queueable that alerts every active group member.
     */
    @AuraEnabled
    public static String amplifyPost(Id groupId, Id postId, Id contactId) {
        checkModerationAccess(groupId, contactId);

        List<HAM_Group_Post__c> posts = [
            SELECT Id FROM HAM_Group_Post__c
            WHERE Id = :postId AND Group__c = :groupId LIMIT 1
        ];
        if (posts.isEmpty()) {
            throw new AuraHandledException('Post not found in this group.');
        }

        posts[0].Is_Amplified__c = true;
        posts[0].Amplified_On__c = System.now();
        update posts;

        // Notification fan-out runs async, same as resource amplify
        System.enqueueJob(new HAM_NotificationQueueable(postId, contactId, 'Post'));
        return 'Success';
    }

    /**
     * @description Admin-only "Remove Amplification": clears the highlight/promotion on
     *              a post that was amplified — the corrective path for an accidental
     *              amplify, so the admin doesn't have to wait out the 7-day window.
     *              Only flips Is_Amplified__c off (which alone drops the post out of the
     *              amplified feed block and hides the badge); Amplified_On__c is left as
     *              an audit trail. Sends NO notification — nothing is dispatched here.
     */
    @AuraEnabled
    public static String unamplifyPost(Id groupId, Id postId, Id contactId) {
        checkModerationAccess(groupId, contactId);

        List<HAM_Group_Post__c> posts = [
            SELECT Id, Is_Amplified__c FROM HAM_Group_Post__c
            WHERE Id = :postId AND Group__c = :groupId LIMIT 1
        ];
        if (posts.isEmpty()) {
            throw new AuraHandledException('Post not found in this group.');
        }

        posts[0].Is_Amplified__c = false;
        update posts;
        return 'Success';
    }

    // ─── Content Moderation (Reporting) Methods ──────────────────────────────────

    @AuraEnabled
    public static String reportContent(Id postId, Id commentId, String reason, Id currentContactId) {
        return submitContentReport(postId, commentId, reason, currentContactId, false);
    }

    // "Report User" shares the same report queue/record as "Report Message" — the only
    // difference is Is_User_Report__c, which drives the Message Report / User Report
    // tag on the admin moderation dashboard.
    @AuraEnabled
    public static String reportUser(Id postId, Id commentId, String reason, Id currentContactId) {
        return submitContentReport(postId, commentId, reason, currentContactId, true);
    }

    private static String submitContentReport(Id postId, Id commentId, String reason, Id currentContactId, Boolean isUserReport) {
        if (postId == null && commentId == null) {
            throw new AuraHandledException('Either post ID or comment ID is required.');
        }

        Id reportedUserId = null;
        // Comment reports carry no postId from the client — derive the parent post here
        // so Reported_Post__c is always populated, for both message and user reports.
        Id parentPostId = postId;
        if (postId != null) {
            List<HAM_Group_Post__c> posts = [SELECT Author__c FROM HAM_Group_Post__c WHERE Id = :postId LIMIT 1];
            if (!posts.isEmpty()) {
                reportedUserId = posts[0].Author__c;
            }
        } else {
            List<HAM_Group_Comment__c> comments = [
                SELECT Post__c, HAM_Group_Member__r.Contact__c
                FROM HAM_Group_Comment__c
                WHERE Id = :commentId
                LIMIT 1
            ];
            if (!comments.isEmpty()) {
                reportedUserId = comments[0].HAM_Group_Member__r.Contact__c;
                parentPostId = comments[0].Post__c;
            }
        }

        HAM_Reported_Content__c report = new HAM_Reported_Content__c();
        report.Reported_Post__c = parentPostId;
        report.Reported_Comment__c = commentId;
        report.Reason__c = reason;
        report.Reported_By__c = currentContactId;
        report.Reported_User__c = reportedUserId;
        report.Status__c = 'Pending';
        report.Is_User_Report__c = isUserReport;

        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.CREATABLE, new List<HAM_Reported_Content__c>{report});
        insert decision.getRecords();
        return 'Success';
    }

    @AuraEnabled
    public static ModerationDashboardWrapper getReportedContent(Id groupId, Id currentContactId) {
        checkModerationAccess(groupId, currentContactId);

        List<HAM_Reported_Content__c> dbReports = [
            SELECT Id, Reported_Post__c, Reported_Post__r.Body__c,
                   Reported_Post__r.Author__r.Name, Reported_Comment__c,
                   Reported_Comment__r.Body__c,
                   Reported_Comment__r.HAM_Group_Member__r.Contact__r.Name,
                   Reason__c, Status__c, Reported_By__r.Name, CreatedDate, Is_User_Report__c
            FROM HAM_Reported_Content__c
            WHERE (Reported_Post__r.Group__c = :groupId)
               OR (Reported_Comment__r.Post__r.Group__c = :groupId)
            ORDER BY CreatedDate DESC
        ];

        List<HAM_Reported_Content__c> pendingRaw = new List<HAM_Reported_Content__c>();
        List<HAM_Reported_Content__c> resolvedRaw = new List<HAM_Reported_Content__c>();
        for (HAM_Reported_Content__c r : dbReports) {
            if (r.Status__c == 'Pending') {
                pendingRaw.add(r);
            } else {
                resolvedRaw.add(r);
            }
        }

        ModerationDashboardWrapper dash = new ModerationDashboardWrapper();
        dash.totalReports = dbReports.size();
        dash.resolvedCount = resolvedRaw.size();
        dash.pendingCount = pendingRaw.size();
        dash.pendingReports = groupReportsByContentAndReason(pendingRaw);
        dash.resolvedReports = groupReportsByContentAndReason(resolvedRaw);
        return dash;
    }

    /**
     * @description Collapses multiple HAM_Reported_Content__c rows filed against the same
     *              post/comment for the same reason into a single card: one report card per
     *              distinct piece of content + reason, carrying the full list of underlying
     *              report Ids (so Dismiss/Take Action/Reopen resolve every duplicate report at
     *              once) plus a "Reported by X and N other(s)" display built from the distinct,
     *              alphabetically-sorted set of reporters.
     */
    private static List<ReportWrapper> groupReportsByContentAndReason(List<HAM_Reported_Content__c> records) {
        Map<String, List<HAM_Reported_Content__c>> groupsByKey = new Map<String, List<HAM_Reported_Content__c>>();
        List<String> orderedKeys = new List<String>();

        for (HAM_Reported_Content__c r : records) {
            // Comment reports now also carry a Reported_Post__c, so branch on the more
            // specific Reported_Comment__c first to keep grouping by the actual reported
            // content (a comment), not its parent post.
            String key = (r.Reported_Comment__c != null ? ('C_' + r.Reported_Comment__c) : ('P_' + r.Reported_Post__c))
                         + '|' + r.Reason__c;
            if (!groupsByKey.containsKey(key)) {
                groupsByKey.put(key, new List<HAM_Reported_Content__c>());
                orderedKeys.add(key);
            }
            groupsByKey.get(key).add(r);
        }

        List<ReportWrapper> result = new List<ReportWrapper>();
        for (String key : orderedKeys) {
            List<HAM_Reported_Content__c> reportsInGroup = groupsByKey.get(key);
            HAM_Reported_Content__c first = reportsInGroup[0];

            Set<String> reporterNameSet = new Set<String>();
            List<String> reportIds = new List<String>();
            for (HAM_Reported_Content__c r : reportsInGroup) {
                reportIds.add(r.Id);
                if (r.Reported_By__r != null && String.isNotBlank(r.Reported_By__r.Name)) {
                    reporterNameSet.add(r.Reported_By__r.Name);
                }
            }
            List<String> reporterNames = new List<String>(reporterNameSet);
            reporterNames.sort();

            ReportWrapper rw = new ReportWrapper();
            rw.reportId = first.Id;
            rw.reportIds = reportIds;
            rw.postId = first.Reported_Post__c;
            rw.commentId = first.Reported_Comment__c;
            rw.reason = first.Reason__c;
            rw.status = first.Status__c;
            rw.totalReportCount = reportsInGroup.size();
            rw.reportedByDisplay = formatReportedByDisplay(reporterNames);
            rw.createdDate = first.CreatedDate;
            rw.isUserReport = first.Is_User_Report__c;

            if (first.Reported_Comment__c != null) {
                rw.reportedUserName = first.Reported_Comment__r.HAM_Group_Member__r.Contact__r.Name;
                rw.contentBody = first.Reported_Comment__r.Body__c;
            } else if (first.Reported_Post__c != null) {
                rw.reportedUserName = first.Reported_Post__r.Author__r.Name;
                rw.contentBody = first.Reported_Post__r.Body__c;
            }

            result.add(rw);
        }
        return result;
    }

    private static String formatReportedByDisplay(List<String> alphabeticalReporterNames) {
        if (alphabeticalReporterNames.isEmpty()) return '';
        if (alphabeticalReporterNames.size() == 1) return alphabeticalReporterNames[0];

        Integer otherCount = alphabeticalReporterNames.size() - 1;
        return alphabeticalReporterNames[0] + ' and ' + otherCount + (otherCount == 1 ? ' other' : ' others');
    }

    @AuraEnabled
    public static String resolveReport(List<Id> reportIds, String actionType, Id currentContactId) {
        if (reportIds == null || reportIds.isEmpty()) {
            throw new AuraHandledException('Report record not found.');
        }

        List<HAM_Reported_Content__c> reports = [
            SELECT Id, Reported_Post__c, Reported_Comment__c, Reported_Post__r.Group__c,
                   Reported_Comment__r.Post__r.Group__c
            FROM HAM_Reported_Content__c
            WHERE Id IN :reportIds
        ];
        if (reports.isEmpty()) {
            throw new AuraHandledException('Report record not found.');
        }

        // Every Id in the list belongs to the same grouped report card (same content +
        // reason), so the first record's content/group references are representative
        // of the whole group.
        HAM_Reported_Content__c first = reports[0];
        Id groupId = first.Reported_Comment__c != null ? first.Reported_Comment__r.Post__r.Group__c : first.Reported_Post__r.Group__c;
        checkModerationAccess(groupId, currentContactId);

        if (actionType == 'Reopen') {
            for (HAM_Reported_Content__c r : reports) {
                r.Status__c = 'Pending';
            }
            update reports;
            return 'Success';
        }

        // Resolve the report rows BEFORE deleting the reported post/comment. Reported_Post__c/
        // Reported_Comment__c reference that content, so deleting it first can cascade-delete
        // or otherwise invalidate these report rows, making the later `update reports` below
        // throw on already-gone records.
        for (HAM_Reported_Content__c r : reports) {
            r.Status__c = 'Resolved';
        }
        update reports;

        if (actionType == 'TakeAction') {
            if (first.Reported_Comment__c != null) {
                List<HAM_Group_Comment__c> comments = [SELECT Id FROM HAM_Group_Comment__c WHERE Id = :first.Reported_Comment__c];
                if (!comments.isEmpty()) {
                    delete comments;
                }
            } else if (first.Reported_Post__c != null) {
                List<HAM_Group_Post__c> posts = [SELECT Id FROM HAM_Group_Post__c WHERE Id = :first.Reported_Post__c];
                if (!posts.isEmpty()) {
                    delete posts;
                }
            }
        }

        return 'Success';
    }

    private static final String MODERATION_EMAIL_SENDER = 'hamily@hamilton.edu';   // Need to update hamily@hamilton.edu after testing
    
    // Flip to true once MODERATION_EMAIL_SENDER is verified under
    // Setup > Organization-Wide Addresses. Until then, moderation emails send
    // via the standard Salesforce default (the running user's address).
    private static final Boolean USE_MODERATION_OWA = true;

    /**
     * @description Handles the three "Take Action" outcomes for a flagged report:
     *              warn (email only), delete (soft-hide the reported content via
     *              Ham_Admin_Action__c + email), or block (soft-hide the reported
     *              content, block the member from the group, and email). The acting
     *              admin is captured via the standard
     *              LastModifiedBy/LastModifiedDate audit fields on the report record.
     */
    @AuraEnabled
    public static String takeReportAction(List<Id> reportIds, String actionType, String message, Id currentContactId) {
        if (reportIds == null || reportIds.isEmpty()) {
            throw new AuraHandledException('Report record not found.');
        }

        List<HAM_Reported_Content__c> reports = [
            SELECT Id, Reported_Post__c, Reported_Post__r.Group__c, Reported_Post__r.Author__c,
                   Reported_Post__r.Author__r.Email,
                   Reported_Comment__c, Reported_Comment__r.Post__r.Group__c,
                   Reported_Comment__r.HAM_Group_Member__r.Contact__c,
                   Reported_Comment__r.HAM_Group_Member__r.Contact__r.Email
            FROM HAM_Reported_Content__c
            WHERE Id IN :reportIds
        ];
        if (reports.isEmpty()) {
            throw new AuraHandledException('Report record not found.');
        }

        // Every Id in the list belongs to the same grouped report card (same content +
        // reason), so the first record's content/target references are representative
        // of the whole group.
        HAM_Reported_Content__c first = reports[0];
        Id groupId = first.Reported_Comment__c != null ? first.Reported_Comment__r.Post__r.Group__c : first.Reported_Post__r.Group__c;
        checkModerationAccess(groupId, currentContactId);

        Id targetContactId;
        String targetEmail;
        if (first.Reported_Comment__c != null) {
            targetContactId = first.Reported_Comment__r.HAM_Group_Member__r.Contact__c;
            targetEmail = first.Reported_Comment__r.HAM_Group_Member__r.Contact__r != null
                ? first.Reported_Comment__r.HAM_Group_Member__r.Contact__r.Email
                : null;
        } else if (first.Reported_Post__c != null) {
            targetContactId = first.Reported_Post__r.Author__c;
            targetEmail = first.Reported_Post__r.Author__r != null ? first.Reported_Post__r.Author__r.Email : null;
        }

        for (HAM_Reported_Content__c r : reports) {
            r.Status__c = 'Resolved';
        }
        update reports;

        // Content is never hard-deleted here — the admin's decision is recorded on
        // Ham_Admin_Action__c instead. Only 'Warn the user' (or blank) stays visible
        // in the discussion feed (see getGroupFeed/getPostComments); the other values
        // soft-hide the post/comment while preserving it for audit purposes.
        Map<String, String> actionTypeToAdminAction = new Map<String, String>{
            'Warn'   => 'Warn the user',
            'Delete' => 'Delete the content',
            'Block'  => 'Remove content & Block user'
        };
        String adminActionValue = actionTypeToAdminAction.get(actionType);

        if (adminActionValue != null) {
            try {
                if (first.Reported_Comment__c != null) {
                    List<HAM_Group_Comment__c> comments = [SELECT Id FROM HAM_Group_Comment__c WHERE Id = :first.Reported_Comment__c];
                    if (!comments.isEmpty()) {
                        comments[0].Ham_Admin_Action__c = adminActionValue;
                        update comments;
                    }
                } else if (first.Reported_Post__c != null) {
                    List<HAM_Group_Post__c> posts = [SELECT Id FROM HAM_Group_Post__c WHERE Id = :first.Reported_Post__c];
                    if (!posts.isEmpty()) {
                        posts[0].Ham_Admin_Action__c = adminActionValue;
                        update posts;
                    }
                }
            } catch (Exception e) {
                throw new AuraHandledException('Could not update the reported content: ' + e.getMessage());
            }
        }

        if (actionType == 'Block' && targetContactId != null) {
            List<HAM_Group_Member__c> members = [
                SELECT Id FROM HAM_Group_Member__c
                WHERE Group__c = :groupId AND Contact__c = :targetContactId
                LIMIT 1
            ];
            if (!members.isEmpty()) {
                members[0].Status__c = 'Blocked';
                update members;
                Cache.Session.remove('local.HamCommunityPartition.userGroups' + targetContactId);
            }
        }

        if (String.isNotBlank(targetEmail) && !isEmailSuppressed(targetContactId)) {
            sendModerationEmail(targetEmail, message);
        }

        return 'Success';
    }

    /**
     * @description Whether outbound email to this contact is suppressed by an active
     * service indicator.
     *
     * INTERIM (2026-08-13): matches the Service Indicator Value by Name, since
     * HAM_Portal_ID__c is unpopulated on it. Pending client confirmation of which
     * indicator governs transactional mail — "No Contact with Hamilton" is the blanket
     * one and may belong here too. Once HQ populates a portal ID, match on that instead. Deliberately does NOT filter on RecordType, unlike
     * getPrivacyMaskedContacts(): for a suppression check the failure modes are not
     * symmetric — over-filtering emails someone who opted out, under-filtering merely
     * skips an email we could have sent. Filtering on the contact lookup already scopes
     * this to contact-level indicators.
     * @param contactId Contact being emailed.
     * @return Boolean true when an active suppressing indicator exists.
     */
    private static Boolean isEmailSuppressed(Id contactId) {
        if (contactId == null) {
            return false;
        }
        return ![
            SELECT Id
            FROM ucinn_ascendv2__Service_Indicator__c
            WHERE ucinn_ascendv2__Contact__c = :contactId
              AND ucinn_ascendv2__Is_Active__c = true
              AND ucinn_ascendv2__Service_Indicator_Value__r.Name = :HAM_ConstantsUtil.NO_CONTACT_MASS_EMAIL_SI
            LIMIT 1
        ].isEmpty();
    }

    private static void sendModerationEmail(String toAddress, String body) {
        system.debug('toAddress -'+toAddress );
        system.debug('body -'+body );
        
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();

        if (USE_MODERATION_OWA) {
            List<OrgWideEmailAddress> owaList = [
                SELECT Id FROM OrgWideEmailAddress WHERE Address = :MODERATION_EMAIL_SENDER LIMIT 1
            ];
            if (owaList.isEmpty()) {
                throw new AuraHandledException(
                    'Could not send the notification email: no verified Organization-Wide Email Address found for ' +
                    MODERATION_EMAIL_SENDER + '. Please configure it under Setup > Organization-Wide Addresses.'
                );
            }
            mail.setOrgWideEmailAddressId(owaList[0].Id);
        }

        mail.setToAddresses(new List<String>{ toAddress });
        mail.setSubject('A Message from the Hamilton Community Team');
        mail.setPlainTextBody(body);
        mail.setSaveAsActivity(false);
        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
    }

    // ─── Private Group Approvals Methods ─────────────────────────────────────────

    @AuraEnabled
    public static List<PendingMemberWrapper> getPendingMembers(Id groupId, Id currentContactId) {
        checkModerationAccess(groupId, currentContactId);

        List<PendingMemberWrapper> results = new List<PendingMemberWrapper>();
        for (HAM_Group_Member__c m : [
            SELECT Id, Contact__c, Contact__r.Name, Contact__r.HAM_Profile_Picture_URL__c
            FROM HAM_Group_Member__c
            WHERE Group__c = :groupId AND Status__c = 'Pending'
            ORDER BY Contact__r.Name ASC
        ]) {
            PendingMemberWrapper w = new PendingMemberWrapper();
            w.memberRecordId = m.Id;
            w.contactId = m.Contact__c;
            w.name = m.Contact__r.Name;
            w.photoUrl = m.Contact__r.HAM_Profile_Picture_URL__c;
            results.add(w);
        }
        return results;
    }

    @AuraEnabled
    public static String approveMember(Id memberId, Id currentContactId) {
        List<HAM_Group_Member__c> mList = [SELECT Id, Group__c, Contact__c FROM HAM_Group_Member__c WHERE Id = :memberId LIMIT 1];
        if (mList.isEmpty()) {
            throw new AuraHandledException('Member record not found.');
        }
        checkModerationAccess(mList[0].Group__c, currentContactId);

        HAM_Group_Member__c m = mList[0];
        m.Status__c = 'Active';
        update m;

        // Invalidate cached group memberships for the approved contact
        String cacheKey = 'local.HamCommunityPartition.userGroups' + m.Contact__c;
        Cache.Session.remove(cacheKey);

        return 'Success';
    }

    @AuraEnabled
    public static String rejectMember(Id memberId, Id currentContactId) {
        List<HAM_Group_Member__c> mList = [SELECT Id, Group__c FROM HAM_Group_Member__c WHERE Id = :memberId LIMIT 1];
        if (mList.isEmpty()) {
            throw new AuraHandledException('Member record not found.');
        }
        checkModerationAccess(mList[0].Group__c, currentContactId);

        delete mList;
        return 'Success';
    }

    // ─── Security Helpers ────────────────────────────────────────────────────────

    private static void checkModerationAccess(Id groupId, Id contactId) {
        if (FeatureManagement.checkPermission('Hamilton_Community_Moderator')) {
            return;
        }
        List<HAM_Group_Member__c> members = [
            SELECT Role__c FROM HAM_Group_Member__c
            WHERE Group__c = :groupId AND Contact__c = :contactId AND Status__c = 'Active' AND Role__c = 'Admin'
            LIMIT 1
        ];
        if (members.isEmpty()) {
            throw new AuraHandledException('Unauthorized: Moderator access required.');
        }
    }

    /**
     * @description Searches for unique tags in existing posts matching the search term.
     * @param searchTerm The search string to query.
     * @return List of matching tags.
     */
    @AuraEnabled(cacheable=true)
    public static List<String> searchTags(String searchTerm) {
        if (String.isBlank(searchTerm)) {
            return new List<String>();
        }
        String likeTerm = '%' + String.escapeSingleQuotes(searchTerm.trim()) + '%';
        Set<String> tagSet = new Set<String>();
        for (HAM_Group_Post__c post : [
            SELECT Tags__c FROM HAM_Group_Post__c 
            WHERE Tags__c LIKE :likeTerm
            LIMIT 100
        ]) {
            if (String.isNotBlank(post.Tags__c)) {
                for (String t : post.Tags__c.split(',')) {
                    String trimmed = t.trim();
                    if (trimmed.toLowerCase().contains(searchTerm.toLowerCase())) {
                        tagSet.add(trimmed);
                    }
                }
            }
        }
        return new List<String>(tagSet);
    }

    /**
     * @description Searches active members of a group by name, for the @mention
     *              picker in the post composer and comment box. Scoped to the group
     *              so users can only tag people who can actually see the content.
     */
    @AuraEnabled(cacheable=true)
    public static List<PostAuthorWrapper> searchGroupMembersForMention(Id groupId, String searchTerm) {
        if (groupId == null || String.isBlank(searchTerm)) {
            return new List<PostAuthorWrapper>();
        }
        String likeTerm = '%' + String.escapeSingleQuotes(searchTerm.trim()) + '%';
        List<PostAuthorWrapper> results = new List<PostAuthorWrapper>();
        for (HAM_Group_Member__c m : [
            SELECT Contact__c, Contact__r.Name, Contact__r.HAM_Profile_Picture_URL__c
            FROM HAM_Group_Member__c
            WHERE Group__c = :groupId AND Status__c = 'Active' AND Contact__r.Name LIKE :likeTerm
            ORDER BY Contact__r.Name ASC
            LIMIT 10
        ]) {
            PostAuthorWrapper w = new PostAuthorWrapper();
            w.contactId = m.Contact__c;
            w.name      = m.Contact__r.Name;
            w.photoUrl  = m.Contact__r.HAM_Profile_Picture_URL__c;
            results.add(w);
        }
        return results;
    }

    /**
     * @description Parses a comma-separated string of Contact Ids (as stored in
     *              Mentioned_Contact_Ids__c) into a clean Id list, skipping blanks
     *              and anything that doesn't parse as a valid Id.
     */
    private static List<Id> parseMentionedContactIds(String csv) {
        List<Id> ids = new List<Id>();
        if (String.isBlank(csv)) {
            return ids;
        }
        for (String token : csv.split(',')) {
            String trimmed = token.trim();
            if (String.isBlank(trimmed)) {
                continue;
            }
            try {
                ids.add((Id) trimmed);
            } catch (Exception e) {
                // Skip malformed tokens rather than failing the whole post/comment
            }
        }
        return ids;
    }

    /**
     * @description Attaches files uploaded as base64 to a specific group post, running
     *              without sharing so it works even though the portal member has no
     *              standard access to the (private) draft post record. This is why the
     *              composer routes attachments here rather than through
     *              lightning-file-upload, which enforces standard record access and so
     *              fails with "Can't upload" when pointed at a HAM_Group_Post__c draft.
     * @param postId The ID of the post to link files to.
     * @param filesJson JSON string containing list of files with name and base64 data.
     * @return The ContentDocumentIds of the attached files, in the same order as the
     *         input, so the composer can display/remove them.
     */
    @AuraEnabled
    public static List<Id> attachFilesToPost(Id postId, String filesJson) {
        if (String.isBlank(filesJson) || postId == null) {
            return new List<Id>();
        }

        List<FileAttachment> files = (List<FileAttachment>) JSON.deserialize(filesJson, List<FileAttachment>.class);
        List<ContentVersion> cvList = new List<ContentVersion>();

        for (FileAttachment fa : files) {
            ContentVersion cv = new ContentVersion();
            cv.Title = fa.fileName;
            cv.PathOnClient = fa.fileName;
            cv.VersionData = EncodingUtil.base64Decode(fa.base64);
            cv.IsMajorVersion = true;
            cvList.add(cv);
        }

        SObjectAccessDecision decisionCV = Security.stripInaccessible(AccessType.CREATABLE, cvList);
        insert decisionCV.getRecords();

        List<Id> cvIds = new List<Id>();
        for (SObject cv : decisionCV.getRecords()) {
            cvIds.add(cv.Id);
        }

        // Preserve input order: map each ContentVersion to its ContentDocumentId, then
        // emit the doc Ids in the same sequence the files were sent in.
        Map<Id, Id> cvToDocId = new Map<Id, Id>();
        List<ContentDocumentLink> cdlList = new List<ContentDocumentLink>();
        for (ContentVersion cv : [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id IN :cvIds]) {
            cvToDocId.put(cv.Id, cv.ContentDocumentId);
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = cv.ContentDocumentId;
            cdl.LinkedEntityId = postId;
            cdl.ShareType = 'V';
            cdl.Visibility = 'AllUsers';
            cdlList.add(cdl);
        }

        SObjectAccessDecision decisionCDL = Security.stripInaccessible(AccessType.CREATABLE, cdlList);
        insert decisionCDL.getRecords();

        List<Id> orderedDocIds = new List<Id>();
        for (Id cvId : cvIds) {
            if (cvToDocId.containsKey(cvId)) orderedDocIds.add(cvToDocId.get(cvId));
        }
        return orderedDocIds;
    }

    private class FileAttachment {
        public String fileName;
        public String base64;
        public String contentType;
    }
}