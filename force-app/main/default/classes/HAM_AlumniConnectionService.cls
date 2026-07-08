/**
* @File Name : HAM_AlumniConnectionService.cls
* @Description : 
* @Author : Cube84 - Asheesh
* @Last Modified By : Asheesh
* @Last Modified On : August 28, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | January 19, 2025 |  Asheesh | Initial Version
**/
public without sharing class HAM_AlumniConnectionService {
    
    /**
* @description Handles alumni connection-related actions such as Send Request, Cancel Request,
* Accept, Reject, Favorite, Bookmark, Block, and Remove Connection based on the provided function type.
* Routes the request to the appropriate helper method and returns the operation status.
*
* @param {String} portalId - Contact Id of the currently logged-in user (portal user).
* @param {String} linkedConstituentId - Contact Id of the selected alumni/profile user.
* @param {String} requestMessage - Optional personalized message sent with the connection request.
* @param {String} functionType - Action type (e.g., Send Request, Cancel Request, Accept, Reject, Favorite, Bookmark).
*
* @return {String} Status of the operation (Success, Invitation Exist, or Error).
*/
    @AuraEnabled
    public static String handleConnectionRequest(String portalId, String linkedConstituentId, String requestMessage, String functionType)
    {
        try {
            if (functionType == HAM_ConstantsUtil.SEND_REQUEST) {
                return handleSendRequest(portalId, linkedConstituentId, requestMessage);
            }
            else if (functionType == HAM_ConstantsUtil.CANCEL_REQUEST) {
                return handleCancelRequest(portalId, linkedConstituentId);
            }
            else if (functionType == HAM_ConstantsUtil.REMOVE_CONNECTION) {
                return handleRemoveConnection(portalId, linkedConstituentId);
            }
            else if (
                functionType == HAM_ConstantsUtil.FAVORITE ||
                functionType == HAM_ConstantsUtil.REMOVE_FAVORITE
            ) {
                return handleFavoriteToggle(portalId, linkedConstituentId, functionType);
            }
            else if (
                functionType == HAM_ConstantsUtil.BOOKMARK ||
                functionType == HAM_ConstantsUtil.REMOVE_BOOKMARK
            ) {
                return handleBookmarkToggle(portalId, linkedConstituentId, functionType);
            }
            else if (functionType == HAM_ConstantsUtil.BLOCK) {
                return handleBlock(portalId, linkedConstituentId);
            }
            else if (functionType == HAM_ConstantsUtil.UNBLOCK) {
                return handleUnblock(portalId, linkedConstituentId);
            }
            else if (functionType == HAM_ConstantsUtil.ACCEPT) {
                return handleAccept(portalId, linkedConstituentId);
            }
            else if (functionType == HAM_ConstantsUtil.REJECT) {
                return handleReject(portalId, linkedConstituentId);
            }
            return 'Error';
        } catch (Exception ex) {
            System.debug('Error in updating connections: ' + ex.getMessage());
            return ex.getMessage();
        }
    }
    
    /**
* @description Retrieves the most recent Ham_Connection__c record between the portal user
* and the linked constituent. Optionally filters by connection status.
*
* @param {String} portalId - Contact Id of the currently logged-in (portal) user.
* @param {String} linkedConstituentId - Contact Id of the selected alumni/profile user.
* @param {String} status - Optional connection status to filter (e.g., Request Sent, Accepted).
*
* @return {Ham_Connection__c} Latest matching connection record or null if none found.
*/
    private static Ham_Connection__c getConnectionRecord(String portalId, String linkedConstituentId, String status) {
        String query = 'SELECT Id, HAM_Portal_User__c, HAM_Linked_Constituent__c, ' +
            'HAM_Connection_Status__c, HAM_Is_favorite__c, HAM_Is_bookmarked__c ' +
            'FROM Ham_Connection__c ' +
            'WHERE HAM_Portal_User__c = :portalId ' +
            'AND HAM_Linked_Constituent__c = :linkedConstituentId';
        
        // Add status condition only if status is not null or blank
        if (String.isNotBlank(status)) {
            query += ' AND HAM_Connection_Status__c = :status';
        }
        
        query += ' ORDER BY CreatedDate DESC LIMIT 1';
        
        List<Ham_Connection__c> connections = Database.query(query);
        return connections.isEmpty() ? null : connections[0];
    }
    
    /**
* @description Sends a connection request from the portal user to the linked constituent.
* Creates or updates a Ham_Connection__c record and sets status to "Request Sent".
* Prevents duplicate invitations if a pending request already exists.
*
* @param {String} portalId - Contact Id of the currently logged-in (portal) user.
* @param {String} linkedConstituentId - Contact Id of the selected alumni/profile user.
* @param {String} requestMessage - Optional personalized message for the connection request.
*
* @return {String} Operation status: 'Success', 'Invitation Exist', or 'Error'.
*/
    private static String handleSendRequest(String portalId, String linkedConstituentId, String requestMessage)
    {
        List<User> constituentUser = [SELECT ID,IsActive FROM USER WHERE ContactId = :linkedConstituentId LIMIT 1];
        if(constituentUser != null && !constituentUser[0].IsActive) return 'Inactive User';
        
        List<Ham_Connection__c> existingRequest = [SELECT ID,HAM_Portal_User__c,HAM_Linked_Constituent__c,HAM_Connection_Status__c 
                                                   FROM HAM_Connection__c
                                                   WHERE HAM_Portal_User__c = :linkedConstituentId
                                                   AND HAM_Linked_Constituent__c = :portalId
                                                   AND HAM_Connection_Status__c = :HAM_ConstantsUtil.REQUEST_SENT
                                                   LIMIT 1];
        if(!existingRequest.isEmpty() && existingRequest != null){
            return 'Invitation Exist';
        }
        Ham_Connection__c connection = getConnectionRecord(portalId, linkedConstituentId, null);
        system.debug(connection);
        if (connection == null) {
            connection = new Ham_Connection__c(
                HAM_Portal_User__c = portalId,
                HAM_Linked_Constituent__c = linkedConstituentId
            );
        }
        
        connection.HAM_Connection_Message__c = requestMessage;
        connection.HAM_Connection_Status__c = HAM_ConstantsUtil.REQUEST_SENT;
        
        Database.UpsertResult result = Database.upsert(connection);
        return result.isSuccess() ? 'Success' : 'Error';
    }
    
    /**
* @description Cancels an existing pending connection request by clearing
* the "Request Sent" status on the Ham_Connection__c record.
*
* @param {String} portalId - Contact Id of the currently logged-in (portal) user.
* @param {String} linkedConstituentId - Contact Id of the selected alumni/profile user.
*
* @return {String} Operation status: 'Success' if updated, otherwise 'Error'.
*/
    private static String handleCancelRequest(String portalId, String linkedConstituentId) {
        Ham_Connection__c connection = getConnectionRecord(portalId, linkedConstituentId, HAM_ConstantsUtil.REQUEST_SENT);
        
        if (connection != null) {
            connection.HAM_Connection_Status__c = '';
            Database.SaveResult result = Database.update(connection);
            return result.isSuccess() ? 'Success' : 'Error';
        }
        return 'Error';
    }
    
    /**
* @description Disconnects two connected users by updating related Ham_Connection__c
* records, clearing favorite status and marking the connection as disconnected.
*
* @param {String} portalId - Contact Id of the currently logged-in (portal) user.
* @param {String} linkedConstituentId - Contact Id of the connected alumni/profile user.
*
* @return {String} Operation status: 'Success' if records updated, otherwise 'Error'.
*/
    private static String handleRemoveConnection(String portalId, String linkedConstituentId) {
        List<Ham_Connection__c> connections = [
            SELECT Id,HAM_Portal_User__c,HAM_Linked_Constituent__c,HAM_Connection_Status__c,HAM_Is_favorite__c,HAM_Is_Connected__c
            FROM Ham_Connection__c
            WHERE HAM_Connection_Status__c = :HAM_ConstantsUtil.CONNECTED
            AND (HAM_Portal_User__c = :portalId OR HAM_Linked_Constituent__c = :portalId)
            AND (HAM_Portal_User__c = :linkedConstituentId OR HAM_Linked_Constituent__c = :linkedConstituentId)
            ORDER BY CreatedDate DESC
            LIMIT 2
        ];
        
        if (!connections.isEmpty()) {
            for (Ham_Connection__c conn : connections) {
                conn.HAM_Is_Connected__c = false;
                conn.HAM_Is_favorite__c = false;
                conn.HAM_Connection_Status__c = HAM_ConstantsUtil.DISCONNECT;
                if(conn.HAM_Portal_User__c == portalId && conn.HAM_Linked_Constituent__c == linkedConstituentId){
                    conn.HAM_Rejected_Date__c = system.today();
                }
            }
            
            List<Database.SaveResult> results = Database.update(connections);
            Boolean allSuccess = true;
            for (Database.SaveResult result : results) {
                if (!result.isSuccess()) {
                    allSuccess = false;
                    break;
                }
            }
            return allSuccess ? 'Success' : 'Error';
        }
        return 'Error';
    }
    
    /**
* @description Toggles favorite status for an active connection based on action type.
*
* @param {String} portalId - Contact Id of the currently logged-in (portal) user.
* @param {String} linkedConstituentId - Contact Id of the connected alumni/profile user.
* @param {String} functionType - Action type ('Favorite' or 'Remove Favorite').
*
* @return {String} Operation status: 'Success' if updated, otherwise 'Error'.
*/
    private static String handleFavoriteToggle(String portalId, String linkedConstituentId, String functionType) 
    {
        Ham_Connection__c connection = getConnectionRecord(portalId, linkedConstituentId, HAM_ConstantsUtil.CONNECTED);
        if (connection != null) {
            connection.HAM_Is_favorite__c = (functionType == HAM_ConstantsUtil.FAVORITE);
            Database.SaveResult result = Database.update(connection);
            return result.isSuccess() ? 'Success' : 'Error';
        }
        return 'Error';
    }
    
    /**
* @description Toggles bookmark status for a connection. Creates a new connection
* record if none exists and the action is Bookmark.
*
* @param {String} portalId - Contact Id of the currently logged-in (portal) user.
* @param {String} linkedConstituentId - Contact Id of the alumni/profile user.
* @param {String} functionType - Action type ('Bookmark' or 'Remove Bookmark').
*
* @return {String} Operation status: 'Success' if upsert succeeds, otherwise 'Error'.
*/
    private static String handleBookmarkToggle(String portalId, String linkedConstituentId, String functionType) 
    {
        Ham_Connection__c connection = getConnectionRecord(portalId, linkedConstituentId, null);
        
        Boolean isBookmark = functionType == HAM_ConstantsUtil.BOOKMARK;
        
        if (connection == null && isBookmark) {
            connection = new Ham_Connection__c(
                HAM_Portal_User__c = portalId,
                HAM_Linked_Constituent__c = linkedConstituentId
            );
        }
        
        if (connection != null) {
            connection.HAM_Is_bookmarked__c = isBookmark;
            Database.UpsertResult result = Database.upsert(connection);
            return result.isSuccess() ? 'Success' : 'Error';
        }
        return 'Error';
    }
    
    /**
* @description Blocks a user by updating the primary connection record and
* clearing any existing reverse connection. Also resets favorite, bookmark,
* and connection flags.
*
* @param {String} portalId - Contact Id of the currently logged-in (portal) user.
* @param {String} linkedConstituentId - Contact Id of the alumni/profile user to block.
*
* @return {String} Operation status: 'Success' if all records are updated,
* otherwise 'Error'.
*/
    private static String handleBlock(String portalId, String linkedConstituentId) {
        // Step 1: Get primary connection (portalId -> linkedConstituentId)
        Ham_Connection__c primaryConnection = getConnectionRecord(portalId, linkedConstituentId, null);
        
        if (primaryConnection == null) {
            primaryConnection = new Ham_Connection__c(
                HAM_Portal_User__c = portalId,
                HAM_Linked_Constituent__c = linkedConstituentId
            );
        }
        
        // Set blocking flags on primary connection
        primaryConnection.HAM_Is_Blocked__c = true;
        primaryConnection.HAM_Is_favorite__c = false;
        primaryConnection.HAM_Is_Connected__c = false;
        primaryConnection.HAM_Is_bookmarked__c = false;
        primaryConnection.HAM_Connection_Status__c = ''; // Set status to blank
        
        List<Ham_Connection__c> connectionsToUpdate = new List<Ham_Connection__c>();
        connectionsToUpdate.add(primaryConnection);
        
        // Step 2: Check for secondary connection (linkedConstituentId -> portalId)
        Ham_Connection__c secondaryConnection = getConnectionRecord(linkedConstituentId, portalId, null);
        
        if (secondaryConnection != null) {
            // Update secondary connection status to blank
            secondaryConnection.HAM_Connection_Status__c = '';
            secondaryConnection.HAM_Is_Connected__c = false;
            connectionsToUpdate.add(secondaryConnection);
        }
        
        // Step 3: Upsert both connections
        List<Database.UpsertResult> results = Database.upsert(connectionsToUpdate);
        
        // Check if all operations were successful
        Boolean allSuccess = true;
        for (Database.UpsertResult result : results) {
            if (!result.isSuccess()) {
                allSuccess = false;
                break;
            }
        }
        
        return allSuccess ? 'Success' : 'Error';
    }

     /**
* @description Unblocks an user by updating the primary connection's HAM_Is_Blocked__c flag.
*
* @param {String} portalId - Contact Id of the currently logged-in (portal) user.
* @param {String} linkedConstituentId - Contact Id of the alumni/profile user to block.
*
* @return {String} Operation status: 'Success' if all records are updated,
* otherwise 'Error'.
*/
    private static String handleUnblock(String portalId, String linkedConstituentId) {
        // Step 1: Get primary connection (portalId -> linkedConstituentId)
        Ham_Connection__c primaryConnection = getConnectionRecord(portalId, linkedConstituentId, null);
        
        // Set flags on primary connection
        primaryConnection.HAM_Is_Blocked__c = false;
        primaryConnection.HAM_Is_favorite__c = false;
        primaryConnection.HAM_Is_Connected__c = false;
        primaryConnection.HAM_Is_bookmarked__c = false;
        primaryConnection.HAM_Connection_Status__c = ''; // Set status to blank
        
        List<Ham_Connection__c> connectionsToUpdate = new List<Ham_Connection__c>();
        connectionsToUpdate.add(primaryConnection);
        
        Boolean allSuccess = true;

        try{
            update connectionsToUpdate;
        }catch(Exception e){
            allSuccess = false; 
            System.debug('Error: ' + e.getMessage()+ 'at line ' + e.getLineNumber());
        }
        
        return allSuccess ? 'Success' : 'Error';
    }

    
    /**
* @description Accepts a pending connection request by marking both primary
* and secondary connection records as Connected. Creates the reverse
* connection if it does not already exist.
*
* @param {String} portalId - Contact Id of the currently logged-in (portal) user.
* @param {String} linkedConstituentId - Contact Id of the requesting user.
*
* @return {String} Operation status: 'Success' if both records are upserted
* successfully, otherwise 'Error'.
*/
    public static String handleAccept(String portalId, String linkedConstituentId) {
        // Query for the INCOMING request where portalId is the RECEIVER
        Ham_Connection__c connectionPrimary = getConnectionRecord(linkedConstituentId, portalId, HAM_ConstantsUtil.REQUEST_SENT);
        
        // Query for any existing reverse connection
        Ham_Connection__c connectionSecondary = getConnectionRecord(portalId, linkedConstituentId, null);
        
        List<Ham_Connection__c> connListToUpsert = new List<HAM_Connection__c>();
        
        if(connectionPrimary != null){
            Ham_Connection__c primaryCon = new Ham_Connection__c();
            primaryCon.Id = connectionPrimary.Id;
            primaryCon.HAM_Connection_Status__c = HAM_ConstantsUtil.CONNECTED;
            primaryCon.HAM_Is_Connected__c = true;
            primaryCon.HAM_Rejected_Date__c = null;
            
            connListToUpsert.add(primaryCon);
        }
        
        Ham_Connection__c secondaryCon = new Ham_Connection__c();
        
        if (connectionSecondary == null) {
            secondaryCon.HAM_Portal_User__c = portalId;
            secondaryCon.HAM_Linked_Constituent__c = linkedConstituentId;
        } else {
            secondaryCon.Id = connectionSecondary.Id;
        }
        
        secondaryCon.HAM_Connection_Status__c = HAM_ConstantsUtil.CONNECTED;
        secondaryCon.HAM_Is_Connected__c = true;
        secondaryCon.HAM_Rejected_Date__c = null;
        
        connListToUpsert.add(secondaryCon);
        
        List<Database.UpsertResult> results = Database.upsert(connListToUpsert);
        Boolean allSuccess = true;
        String errorMessage = '';
        
        for (Database.UpsertResult result : results) {
            if (!result.isSuccess()) {
                allSuccess = false;
                errorMessage = String.valueOf(result.getErrors());
                break;
            }
        }
        
        if(connectionPrimary != null){
            // Dismiss ONLY current user's notification
            List<HAM_Notification__c> notifs = [
                SELECT Id
                FROM HAM_Notification__c
                WHERE HAM_Source_Object_Id__c = :connectionPrimary.Id
                AND HAM_Constituent__c = :portalId
            ];
            
            for (HAM_Notification__c n : notifs) {
                n.HAM_Status__c = HAM_ConstantsUtil.ACTIONED;
                n.HAM_Is_Dismissed__c = TRUE;
            }
            update notifs;
            
            String acceptorName = '';
            List<Contact> contacts = [SELECT Name FROM Contact WHERE Id = :connectionPrimary.HAM_Linked_Constituent__c LIMIT 1];
            if (!contacts.isEmpty()) {
                acceptorName = contacts[0].Name;
            }

            HAM_NotificationService.NotificationRequest req =
                new HAM_NotificationService.NotificationRequest();
            
            req.recipientContactId = connectionPrimary.HAM_Portal_User__c;   // requester
            req.senderContactId    = connectionPrimary.HAM_Linked_Constituent__c; // acceptor
            req.senderName         = acceptorName;
            req.title              = HAM_ConstantsUtil.HAS_ACCEPTED_YOUR_REQUEST;
            req.body               = '';
            req.status             = HAM_ConstantsUtil.ACTIONED;
            req.sourceId            = connectionPrimary.Id;
            req.type                = HAM_ConstantsUtil.CONNECTION;
            req.actionUrl           = '?view=directory&tab=Manage%20Invitations';
            
            HAM_NotificationService.sendNotifications(
                new List<HAM_NotificationService.NotificationRequest>{ req }
            );
        }
        
        
        return allSuccess ? 'Success' : errorMessage;
    }
    
    
    /**
* @description Rejects a pending connection request by updating the connection
* status to Rejected and storing the rejection date.
*
* @param {String} portalId - Contact Id of the currently logged-in (portal) user.
* @param {String} linkedConstituentId - Contact Id of the requesting user.
*
* @return {String} Operation status: 'Success' if update succeeds,
* otherwise 'Error'.
*/
    public static String handleReject(String portalId, String linkedConstituentId) 
    {
        // Query for the INCOMING request where portalId is the RECEIVER
        Ham_Connection__c connectionPrimary = getConnectionRecord(linkedConstituentId, portalId, HAM_ConstantsUtil.REQUEST_SENT);
        system.debug('primary con '+connectionPrimary);
        // Query for any existing reverse connection
        Ham_Connection__c connectionSecondary = getConnectionRecord(portalId, linkedConstituentId, null);
        system.debug('primary con '+connectionSecondary);
        List<Ham_Connection__c> connListToUpsert = new List<HAM_Connection__c>();
        
        if(connectionPrimary != null){
            Ham_Connection__c primaryCon = new Ham_Connection__c();
            primaryCon.Id = connectionPrimary.Id;
            primaryCon.HAM_Connection_Status__c = '';
            primaryCon.HAM_Rejected_Date__c = null;
            
            connListToUpsert.add(primaryCon);
        }
        
        Ham_Connection__c secondaryCon = new Ham_Connection__c();
        
        if (connectionSecondary == null) {
            secondaryCon.HAM_Portal_User__c = portalId;
            secondaryCon.HAM_Linked_Constituent__c = linkedConstituentId;
        } else {
            secondaryCon.Id = connectionSecondary.Id;
        }
        
        secondaryCon.HAM_Connection_Status__c = 'Rejected';
        secondaryCon.HAM_Rejected_Date__c = System.today();
        
        connListToUpsert.add(secondaryCon);
        
        List<Database.UpsertResult> results = Database.upsert(connListToUpsert);
        Boolean allSuccess = true;
        String errorMessage = '';
        
        for (Database.UpsertResult result : results) {
            if (!result.isSuccess()) {
                allSuccess = false;
                errorMessage = String.valueOf(result.getErrors());
                break;
            }
        }
        
        if(connectionPrimary != null){
            // Dismiss ONLY current user's notification
            List<HAM_Notification__c> notifs = [
                SELECT Id
                FROM HAM_Notification__c
                WHERE HAM_Source_Object_Id__c = :connectionPrimary.Id
                AND HAM_Constituent__c = :portalId
            ];
            
            for (HAM_Notification__c n : notifs) {
                n.HAM_Status__c = HAM_ConstantsUtil.ACTIONED;
                n.HAM_Is_Dismissed__c = TRUE;
            }
            update notifs;
        }
        return allSuccess ? 'Success' : errorMessage;
    }
    
    /**
    * @description Checks if the User associated with the given ContactId is active.
    * @param {String} linkedConstituentId - Contact Id of the alumni/profile user.
    * @return {String} "Active User" if active, "Inactive User" if inactive or not found.
    */
    @AuraEnabled(cacheable=true)
    public static String checkUserStatus(String linkedConstituentId) {
        if (String.isBlank(linkedConstituentId)) {
            return 'Error: Invalid ID';
        }
    
        List<User> userList = [
            SELECT Id, IsActive 
            FROM User 
            WHERE ContactId = :linkedConstituentId 
            LIMIT 1
        ];
    
        if (userList.isEmpty() || !userList[0].IsActive) {
            return 'Inactive User';
        }
    
        return 'Active User';
    }
}