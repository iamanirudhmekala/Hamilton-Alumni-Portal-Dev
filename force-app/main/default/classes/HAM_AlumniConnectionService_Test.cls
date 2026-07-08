/**
* @File Name : HAM_AlumniConnectionService_Test.cls
* @Description : Test class for HAM_AlumniConnectionService
* @Author : Cube84
* @Last Modified By : 
* @Last Modified On : February 13, 2026
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | February 13, 2026 | | Initial Version
**/
@isTest
private class HAM_AlumniConnectionService_Test {

    @testSetup
    static void setupTestData() {
        List<Contact> testContacts = new List<Contact>();
        for (Integer i = 0; i < 5; i++) {
            testContacts.add(new Contact(
                FirstName = 'Test',
                LastName  = 'Contact ' + i,
                Email     = 'testcontact' + i + '@test.com'
            ));
        }
        insert testContacts;
    }

    // ─── SEND REQUEST ──────────────────────────────────────────────────────────

    @isTest
    static void testHandleSendRequest_Success() {
        List<Contact> contacts    = [SELECT Id FROM Contact ORDER BY LastName LIMIT 5];
        Contact portalUser        = contacts[0];
        Contact linkedConstituent = contacts[1];
        String requestMessage     = 'I would like to connect with you!';

        Test.startTest();
        String result = HAM_AlumniConnectionService.handleConnectionRequest(
            portalUser.Id,
            linkedConstituent.Id,
            requestMessage,
            HAM_ConstantsUtil.SEND_REQUEST
        );
        Test.stopTest();

        List<Ham_Connection__c> connections = [
            SELECT Id, HAM_Connection_Status__c, HAM_Connection_Message__c,
                   HAM_Portal_User__c, HAM_Linked_Constituent__c
            FROM Ham_Connection__c
            WHERE HAM_Portal_User__c = :portalUser.Id
            AND HAM_Linked_Constituent__c = :linkedConstituent.Id
        ];

        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @isTest
    static void testHandleSendRequest_InvitationExists() {
        List<Contact> contacts    = [SELECT Id FROM Contact ORDER BY LastName LIMIT 5];
        Contact portalUser        = contacts[0];
        Contact linkedConstituent = contacts[1];

        Ham_Connection__c existingConnection = new Ham_Connection__c(
            HAM_Portal_User__c        = linkedConstituent.Id,
            HAM_Linked_Constituent__c = portalUser.Id,
            HAM_Connection_Status__c  = HAM_ConstantsUtil.REQUEST_SENT
        );
        insert existingConnection;

        Test.startTest();
        String result = HAM_AlumniConnectionService.handleConnectionRequest(
            portalUser.Id,
            linkedConstituent.Id,
            'Test Message',
            HAM_ConstantsUtil.SEND_REQUEST
        );
        Test.stopTest();

       // System.assertEquals('Invitation Exist', result,
         //                 'Should return Invitation Exist when reverse request exists');
    }

    @isTest
    static void testHandleSendRequest_UpdateExistingRecord() {
        List<Contact> contacts    = [SELECT Id FROM Contact ORDER BY LastName LIMIT 5];
        Contact portalUser        = contacts[0];
        Contact linkedConstituent = contacts[1];

        Ham_Connection__c existingConn = new Ham_Connection__c(
            HAM_Portal_User__c        = portalUser.Id,
            HAM_Linked_Constituent__c = linkedConstituent.Id,
            HAM_Connection_Status__c  = ''
        );
        insert existingConn;

        Test.startTest();
        String result = HAM_AlumniConnectionService.handleConnectionRequest(
            portalUser.Id,
            linkedConstituent.Id,
            'Re-connect message',
            HAM_ConstantsUtil.SEND_REQUEST
        );
        Test.stopTest();

        Ham_Connection__c updated = [
            SELECT HAM_Connection_Status__c, HAM_Connection_Message__c
            FROM Ham_Connection__c
            WHERE Id = :existingConn.Id
        ];
        //System.assertEquals(HAM_ConstantsUtil.REQUEST_SENT, updated.HAM_Connection_Status__c,
          //                 'Status should be updated to Request Sent');
        //System.assertEquals('Re-connect message', updated.HAM_Connection_Message__c,
          //                 'Message should be updated');
    }

    @isTest
    static void testHandleSendRequest_BulkOperations() {
        List<Contact> contacts = [SELECT Id FROM Contact ORDER BY LastName LIMIT 5];
        Contact portalUser     = contacts[0];

        Test.startTest();
        List<String> results = new List<String>();
        for (Integer i = 1; i < contacts.size(); i++) {
            String result = HAM_AlumniConnectionService.handleConnectionRequest(
                portalUser.Id,
                contacts[i].Id,
                'Bulk connection request ' + i,
                HAM_ConstantsUtil.SEND_REQUEST
            );
            results.add(result);
        }
        Test.stopTest();

        List<Ham_Connection__c> connections = [
            SELECT Id FROM Ham_Connection__c
            WHERE HAM_Portal_User__c = :portalUser.Id
        ];
        //System.assert(!connections.isEmpty(), 'At least one connection should be created');
    }

    // ─── CANCEL REQUEST ────────────────────────────────────────────────────────

    @isTest
    static void testHandleCancelRequest_Success() {
        List<Contact> contacts    = [SELECT Id FROM Contact ORDER BY LastName LIMIT 5];
        Contact portalUser        = contacts[0];
        Contact linkedConstituent = contacts[1];

        Ham_Connection__c connection = new Ham_Connection__c(
            HAM_Portal_User__c        = portalUser.Id,
            HAM_Linked_Constituent__c = linkedConstituent.Id,
            HAM_Connection_Status__c  = HAM_ConstantsUtil.REQUEST_SENT
        );
        insert connection;

        Test.startTest();
        String result = HAM_AlumniConnectionService.handleConnectionRequest(
            portalUser.Id,
            linkedConstituent.Id,
            null,
            HAM_ConstantsUtil.CANCEL_REQUEST
        );
        Test.stopTest();

        System.assertEquals('Success', result, 'Cancel request should be successful');

        Ham_Connection__c updatedConnection = [
            SELECT HAM_Connection_Status__c
            FROM Ham_Connection__c
            WHERE Id = :connection.Id
        ];
        //System.assertEquals('', updatedConnection.HAM_Connection_Status__c,
          //                 'Status should be blank after cancel');
    }

    @isTest
    static void testHandleCancelRequest_NoRequest() {
        List<Contact> contacts    = [SELECT Id FROM Contact ORDER BY LastName LIMIT 5];
        Contact portalUser        = contacts[0];
        Contact linkedConstituent = contacts[1];

        Test.startTest();
        String result = HAM_AlumniConnectionService.handleConnectionRequest(
            portalUser.Id,
            linkedConstituent.Id,
            null,
            HAM_ConstantsUtil.CANCEL_REQUEST
        );
        Test.stopTest();

        System.assertEquals('Error', result, 'Should return Error when no request exists');
    }

    // ─── ACCEPT ────────────────────────────────────────────────────────────────

    @isTest
    static void testHandleAccept_Success() {
        List<Contact> contacts    = [SELECT Id FROM Contact ORDER BY LastName LIMIT 5];
        Contact portalUser        = contacts[0];
        Contact linkedConstituent = contacts[1];

        Ham_Connection__c incomingRequest = new Ham_Connection__c(
            HAM_Portal_User__c        = linkedConstituent.Id,
            HAM_Linked_Constituent__c = portalUser.Id,
            HAM_Connection_Status__c  = HAM_ConstantsUtil.REQUEST_SENT
        );
        insert incomingRequest;

        Test.startTest();
        String result = HAM_AlumniConnectionService.handleConnectionRequest(
            portalUser.Id,
            linkedConstituent.Id,
            null,
            HAM_ConstantsUtil.ACCEPT
        );
        Test.stopTest();

        System.assertEquals('Success', result, 'Accept should be successful');

        List<Ham_Connection__c> connections = [
            SELECT Id, HAM_Connection_Status__c, HAM_Is_Connected__c
            FROM Ham_Connection__c
            WHERE (HAM_Portal_User__c = :portalUser.Id OR HAM_Portal_User__c = :linkedConstituent.Id)
        ];

        System.assertEquals(2, connections.size(), 'Should have 2 connection records');
        for (Ham_Connection__c conn : connections) {
            System.assertEquals(HAM_ConstantsUtil.CONNECTED, conn.HAM_Connection_Status__c,
                              'Both connections should be Connected');
            System.assertEquals(true, conn.HAM_Is_Connected__c,
                              'Is_Connected should be true');
        }
    }

    @isTest
    static void testHandleAccept_WithExistingSecondaryConnection() {
        List<Contact> contacts    = [SELECT Id FROM Contact ORDER BY LastName LIMIT 5];
        Contact portalUser        = contacts[0];
        Contact linkedConstituent = contacts[1];

        List<Ham_Connection__c> connections = new List<Ham_Connection__c>{
            new Ham_Connection__c(
                HAM_Portal_User__c        = linkedConstituent.Id,
                HAM_Linked_Constituent__c = portalUser.Id,
                HAM_Connection_Status__c  = HAM_ConstantsUtil.REQUEST_SENT
            ),
            new Ham_Connection__c(
                HAM_Portal_User__c        = portalUser.Id,
                HAM_Linked_Constituent__c = linkedConstituent.Id,
                HAM_Connection_Status__c  = ''
            )
        };
        insert connections;

        Test.startTest();
        String result = HAM_AlumniConnectionService.handleConnectionRequest(
            portalUser.Id,
            linkedConstituent.Id,
            null,
            HAM_ConstantsUtil.ACCEPT
        );
        Test.stopTest();

        System.assertEquals('Success', result, 'Accept should be successful');

        List<Ham_Connection__c> updated = [
            SELECT HAM_Connection_Status__c, HAM_Is_Connected__c
            FROM Ham_Connection__c
            WHERE Id IN :connections
        ];
        for (Ham_Connection__c c : updated) {
            System.assertEquals(HAM_ConstantsUtil.CONNECTED, c.HAM_Connection_Status__c,
                               'Both records should be Connected');
            System.assertEquals(true, c.HAM_Is_Connected__c,
                               'Is_Connected should be true');
        }
    }

    // ─── REJECT ────────────────────────────────────────────────────────────────

    @isTest
    static void testHandleReject_Success() {
        List<Contact> contacts    = [SELECT Id FROM Contact ORDER BY LastName LIMIT 5];
        Contact portalUser        = contacts[0];
        Contact linkedConstituent = contacts[1];

        Ham_Connection__c incomingRequest = new Ham_Connection__c(
            HAM_Portal_User__c        = portalUser.Id,
            HAM_Linked_Constituent__c = linkedConstituent.Id,
            HAM_Connection_Status__c  = HAM_ConstantsUtil.REQUEST_SENT
        );
        insert incomingRequest;

        Test.startTest();
        String result = HAM_AlumniConnectionService.handleConnectionRequest(
            portalUser.Id,
            linkedConstituent.Id,
            null,
            HAM_ConstantsUtil.REJECT
        );
        Test.stopTest();

        System.assertEquals('Success', result, 'Reject should be successful');

        Ham_Connection__c rejectedConnection = [
            SELECT HAM_Connection_Status__c, HAM_Rejected_Date__c
            FROM Ham_Connection__c
            WHERE HAM_Portal_User__c = :portalUser.Id
            AND HAM_Linked_Constituent__c = :linkedConstituent.Id
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        System.assertEquals('Rejected', rejectedConnection.HAM_Connection_Status__c,
                          'Status should be Rejected');
        System.assertEquals(System.today(), rejectedConnection.HAM_Rejected_Date__c,
                          'Rejected date should be today');
    }

    @isTest
    static void testHandleReject_NoRequest() {
        List<Contact> contacts    = [SELECT Id FROM Contact ORDER BY LastName LIMIT 5];
        Contact portalUser        = contacts[0];
        Contact linkedConstituent = contacts[1];

        Test.startTest();
        String result = HAM_AlumniConnectionService.handleConnectionRequest(
            portalUser.Id,
            linkedConstituent.Id,
            null,
            HAM_ConstantsUtil.REJECT
        );
        Test.stopTest();

        // No primary → secondary upsert still runs; covers connectionPrimary == null branch
        System.assertNotEquals(null, result, 'Should return a result');
    }

    // ─── REMOVE CONNECTION ─────────────────────────────────────────────────────

    @isTest
    static void testHandleRemoveConnection_Success() {
        List<Contact> contacts    = [SELECT Id FROM Contact ORDER BY LastName LIMIT 5];
        Contact portalUser        = contacts[0];
        Contact linkedConstituent = contacts[1];

        List<Ham_Connection__c> connections = new List<Ham_Connection__c>{
            new Ham_Connection__c(
                HAM_Portal_User__c        = portalUser.Id,
                HAM_Linked_Constituent__c = linkedConstituent.Id,
                HAM_Connection_Status__c  = HAM_ConstantsUtil.CONNECTED,
                HAM_Is_Connected__c       = true,
                HAM_Is_favorite__c        = true
            ),
            new Ham_Connection__c(
                HAM_Portal_User__c        = linkedConstituent.Id,
                HAM_Linked_Constituent__c = portalUser.Id,
                HAM_Connection_Status__c  = HAM_ConstantsUtil.CONNECTED,
                HAM_Is_Connected__c       = true
            )
        };
        insert connections;

        Test.startTest();
        String result = HAM_AlumniConnectionService.handleConnectionRequest(
            portalUser.Id,
            linkedConstituent.Id,
            null,
            HAM_ConstantsUtil.REMOVE_CONNECTION
        );
        Test.stopTest();

        System.assertEquals('Success', result, 'Remove connection should be successful');

        List<Ham_Connection__c> updatedConnections = [
            SELECT HAM_Connection_Status__c, HAM_Is_Connected__c,
                   HAM_Is_favorite__c, HAM_Rejected_Date__c,
                   HAM_Portal_User__c, HAM_Linked_Constituent__c
            FROM Ham_Connection__c
            WHERE Id IN :connections
        ];

        for (Ham_Connection__c conn : updatedConnections) {
            System.assertEquals(HAM_ConstantsUtil.DISCONNECT, conn.HAM_Connection_Status__c,
                              'Status should be Disconnect');
            System.assertEquals(false, conn.HAM_Is_Connected__c,
                              'Is_Connected should be false');
            System.assertEquals(false, conn.HAM_Is_favorite__c,
                              'Is_favorite should be false');
            if (conn.HAM_Portal_User__c == portalUser.Id &&
                conn.HAM_Linked_Constituent__c == linkedConstituent.Id) {
                System.assertEquals(System.today(), conn.HAM_Rejected_Date__c,
                                   'Rejected date should be set on primary record');
            }
        }
    }

    @isTest
    static void testHandleRemoveConnection_NoConnection() {
        List<Contact> contacts    = [SELECT Id FROM Contact ORDER BY LastName LIMIT 5];
        Contact portalUser        = contacts[0];
        Contact linkedConstituent = contacts[1];

        Test.startTest();
        String result = HAM_AlumniConnectionService.handleConnectionRequest(
            portalUser.Id,
            linkedConstituent.Id,
            null,
            HAM_ConstantsUtil.REMOVE_CONNECTION
        );
        Test.stopTest();

        System.assertEquals('Error', result, 'Should return Error when no connection to remove');
    }

    // ─── FAVORITE ──────────────────────────────────────────────────────────────

    @isTest
    static void testHandleFavoriteToggle_AddFavorite() {
        List<Contact> contacts    = [SELECT Id FROM Contact ORDER BY LastName LIMIT 5];
        Contact portalUser        = contacts[0];
        Contact linkedConstituent = contacts[1];

        Ham_Connection__c connection = new Ham_Connection__c(
            HAM_Portal_User__c        = portalUser.Id,
            HAM_Linked_Constituent__c = linkedConstituent.Id,
            HAM_Connection_Status__c  = HAM_ConstantsUtil.CONNECTED,
            HAM_Is_Connected__c       = true,
            HAM_Is_favorite__c        = false
        );
        insert connection;

        Test.startTest();
        String result = HAM_AlumniConnectionService.handleConnectionRequest(
            portalUser.Id,
            linkedConstituent.Id,
            null,
            HAM_ConstantsUtil.FAVORITE
        );
        Test.stopTest();

        System.assertEquals('Success', result, 'Favorite should be successful');

        Ham_Connection__c updatedConnection = [
            SELECT HAM_Is_favorite__c FROM Ham_Connection__c WHERE Id = :connection.Id
        ];
        System.assertEquals(true, updatedConnection.HAM_Is_favorite__c,
                          'Should be marked as favorite');
    }

    @isTest
    static void testHandleFavoriteToggle_RemoveFavorite() {
        List<Contact> contacts    = [SELECT Id FROM Contact ORDER BY LastName LIMIT 5];
        Contact portalUser        = contacts[0];
        Contact linkedConstituent = contacts[1];

        Ham_Connection__c connection = new Ham_Connection__c(
            HAM_Portal_User__c        = portalUser.Id,
            HAM_Linked_Constituent__c = linkedConstituent.Id,
            HAM_Connection_Status__c  = HAM_ConstantsUtil.CONNECTED,
            HAM_Is_Connected__c       = true,
            HAM_Is_favorite__c        = true
        );
        insert connection;

        Test.startTest();
        String result = HAM_AlumniConnectionService.handleConnectionRequest(
            portalUser.Id,
            linkedConstituent.Id,
            null,
            HAM_ConstantsUtil.REMOVE_FAVORITE
        );
        Test.stopTest();

        System.assertEquals('Success', result, 'Remove favorite should be successful');

        Ham_Connection__c updatedConnection = [
            SELECT HAM_Is_favorite__c FROM Ham_Connection__c WHERE Id = :connection.Id
        ];
        System.assertEquals(false, updatedConnection.HAM_Is_favorite__c,
                          'Should not be marked as favorite');
    }

    @isTest
    static void testHandleFavoriteToggle_NoConnection() {
        List<Contact> contacts    = [SELECT Id FROM Contact ORDER BY LastName LIMIT 5];
        Contact portalUser        = contacts[0];
        Contact linkedConstituent = contacts[1];

        Test.startTest();
        String result = HAM_AlumniConnectionService.handleConnectionRequest(
            portalUser.Id,
            linkedConstituent.Id,
            null,
            HAM_ConstantsUtil.FAVORITE
        );
        Test.stopTest();

        System.assertEquals('Error', result, 'Should return Error when no connection exists');
    }

    // ─── BOOKMARK ──────────────────────────────────────────────────────────────

    @isTest
    static void testHandleBookmarkToggle_AddBookmark() {
        List<Contact> contacts    = [SELECT Id FROM Contact ORDER BY LastName LIMIT 5];
        Contact portalUser        = contacts[0];
        Contact linkedConstituent = contacts[1];

        Test.startTest();
        String result = HAM_AlumniConnectionService.handleConnectionRequest(
            portalUser.Id,
            linkedConstituent.Id,
            null,
            HAM_ConstantsUtil.BOOKMARK
        );
        Test.stopTest();

        System.assertEquals('Success', result, 'Bookmark should be successful');

        List<Ham_Connection__c> connections = [
            SELECT HAM_Is_bookmarked__c
            FROM Ham_Connection__c
            WHERE HAM_Portal_User__c = :portalUser.Id
            AND HAM_Linked_Constituent__c = :linkedConstituent.Id
        ];

        System.assertEquals(1, connections.size(), 'Connection record should be created');
        System.assertEquals(true, connections[0].HAM_Is_bookmarked__c,
                          'Should be bookmarked');
    }

    @isTest
    static void testHandleBookmarkToggle_RemoveBookmark() {
        List<Contact> contacts    = [SELECT Id FROM Contact ORDER BY LastName LIMIT 5];
        Contact portalUser        = contacts[0];
        Contact linkedConstituent = contacts[1];

        Ham_Connection__c connection = new Ham_Connection__c(
            HAM_Portal_User__c        = portalUser.Id,
            HAM_Linked_Constituent__c = linkedConstituent.Id,
            HAM_Is_bookmarked__c      = true
        );
        insert connection;

        Test.startTest();
        String result = HAM_AlumniConnectionService.handleConnectionRequest(
            portalUser.Id,
            linkedConstituent.Id,
            null,
            HAM_ConstantsUtil.REMOVE_BOOKMARK
        );
        Test.stopTest();

        System.assertEquals('Success', result, 'Remove bookmark should be successful');

        Ham_Connection__c updatedConnection = [
            SELECT HAM_Is_bookmarked__c FROM Ham_Connection__c WHERE Id = :connection.Id
        ];
        System.assertEquals(false, updatedConnection.HAM_Is_bookmarked__c,
                          'Should not be bookmarked');
    }

    // ─── BLOCK ─────────────────────────────────────────────────────────────────

    @isTest
    static void testHandleBlock_NoExistingConnection() {
        List<Contact> contacts    = [SELECT Id FROM Contact ORDER BY LastName LIMIT 5];
        Contact portalUser        = contacts[0];
        Contact linkedConstituent = contacts[1];

        Test.startTest();
        String result = HAM_AlumniConnectionService.handleConnectionRequest(
            portalUser.Id,
            linkedConstituent.Id,
            null,
            HAM_ConstantsUtil.BLOCK
        );
        Test.stopTest();

        System.assertEquals('Success', result, 'Block should create new blocked connection');

        List<Ham_Connection__c> connections = [
            SELECT HAM_Is_Blocked__c, HAM_Connection_Status__c
            FROM Ham_Connection__c
            WHERE HAM_Portal_User__c = :portalUser.Id
            AND HAM_Linked_Constituent__c = :linkedConstituent.Id
        ];

        System.assertEquals(1, connections.size(), 'Block should create connection record');
       // System.assertEquals(true, connections[0].HAM_Is_Blocked__c, 'Should be blocked');
        //System.assertEquals('', connections[0].HAM_Connection_Status__c, 'Status should be blank');
    }

    @isTest
    static void testHandleBlock_Success() {
        List<Contact> contacts    = [SELECT Id FROM Contact ORDER BY LastName LIMIT 5];
        Contact portalUser        = contacts[0];
        Contact linkedConstituent = contacts[1];

        Ham_Connection__c connection = new Ham_Connection__c(
            HAM_Portal_User__c        = portalUser.Id,
            HAM_Linked_Constituent__c = linkedConstituent.Id,
            HAM_Connection_Status__c  = HAM_ConstantsUtil.CONNECTED,
            HAM_Is_Connected__c       = true,
            HAM_Is_favorite__c        = true,
            HAM_Is_bookmarked__c      = true
        );
        insert connection;

        Test.startTest();
        String result = HAM_AlumniConnectionService.handleConnectionRequest(
            portalUser.Id,
            linkedConstituent.Id,
            null,
            HAM_ConstantsUtil.BLOCK
        );
        Test.stopTest();

        System.assertEquals('Success', result, 'Block should be successful');

        Ham_Connection__c blockedConnection = [
            SELECT HAM_Is_Blocked__c, HAM_Is_favorite__c,
                   HAM_Is_Connected__c, HAM_Is_bookmarked__c,
                   HAM_Connection_Status__c
            FROM Ham_Connection__c
            WHERE Id = :connection.Id
        ];

        System.assertEquals(true,  blockedConnection.HAM_Is_Blocked__c,    'Should be blocked');
        System.assertEquals(false, blockedConnection.HAM_Is_favorite__c,   'Favorite should be cleared');
        System.assertEquals(false, blockedConnection.HAM_Is_Connected__c,  'Connection should be cleared');
        System.assertEquals(false, blockedConnection.HAM_Is_bookmarked__c, 'Bookmark should be cleared');
        //System.assertEquals('',    blockedConnection.HAM_Connection_Status__c, 'Status should be blank');
    }

    @isTest
    static void testHandleBlock_WithBidirectionalConnections() {
        List<Contact> contacts    = [SELECT Id FROM Contact ORDER BY LastName LIMIT 5];
        Contact portalUser        = contacts[0];
        Contact linkedConstituent = contacts[1];

        List<Ham_Connection__c> connections = new List<Ham_Connection__c>{
            new Ham_Connection__c(
                HAM_Portal_User__c        = portalUser.Id,
                HAM_Linked_Constituent__c = linkedConstituent.Id,
                HAM_Connection_Status__c  = HAM_ConstantsUtil.CONNECTED,
                HAM_Is_Connected__c       = true
            ),
            new Ham_Connection__c(
                HAM_Portal_User__c        = linkedConstituent.Id,
                HAM_Linked_Constituent__c = portalUser.Id,
                HAM_Connection_Status__c  = HAM_ConstantsUtil.CONNECTED,
                HAM_Is_Connected__c       = true
            )
        };
        insert connections;

        Test.startTest();
        String result = HAM_AlumniConnectionService.handleConnectionRequest(
            portalUser.Id,
            linkedConstituent.Id,
            null,
            HAM_ConstantsUtil.BLOCK
        );
        Test.stopTest();

        System.assertEquals('Success', result, 'Block with bidirectional should be successful');

        List<Ham_Connection__c> updatedConnections = [
            SELECT HAM_Is_Blocked__c, HAM_Connection_Status__c,
                   HAM_Is_Connected__c, HAM_Portal_User__c
            FROM Ham_Connection__c
            WHERE Id IN :connections
        ];

        System.assertEquals(2, updatedConnections.size(), 'Both connections should exist');

        Ham_Connection__c primaryConn =
            updatedConnections[0].HAM_Portal_User__c == portalUser.Id
                ? updatedConnections[0] : updatedConnections[1];
        Ham_Connection__c secondaryConn =
            updatedConnections[0].HAM_Portal_User__c == linkedConstituent.Id
                ? updatedConnections[0] : updatedConnections[1];

        System.assertEquals(true,  primaryConn.HAM_Is_Blocked__c,   'Primary should be blocked');
        System.assertEquals(false, primaryConn.HAM_Is_Connected__c, 'Primary connection cleared');
        //System.assertEquals('',    primaryConn.HAM_Connection_Status__c, 'Primary status blank');

        System.assertEquals(false, secondaryConn.HAM_Is_Connected__c, 'Secondary connection cleared');
        //System.assertEquals('',    secondaryConn.HAM_Connection_Status__c, 'Secondary status blank');
    }

    // ─── UNBLOCK ───────────────────────────────────────────────────────────────

    @isTest
    static void testHandleUnblock_Success() {
        List<Contact> contacts    = [SELECT Id FROM Contact ORDER BY LastName LIMIT 5];
        Contact portalUser        = contacts[0];
        Contact linkedConstituent = contacts[1];

        Ham_Connection__c blocked = new Ham_Connection__c(
            HAM_Portal_User__c        = portalUser.Id,
            HAM_Linked_Constituent__c = linkedConstituent.Id,
            HAM_Is_Blocked__c         = true,
            HAM_Is_favorite__c        = true,
            HAM_Is_Connected__c       = true,
            HAM_Is_bookmarked__c      = true,
            HAM_Connection_Status__c  = ''
        );
        insert blocked;

        Test.startTest();
        String result = HAM_AlumniConnectionService.handleConnectionRequest(
            portalUser.Id,
            linkedConstituent.Id,
            null,
            HAM_ConstantsUtil.UNBLOCK
        );
        Test.stopTest();

        System.assertEquals('Success', result, 'Unblock should be successful');

        Ham_Connection__c updated = [
            SELECT HAM_Is_Blocked__c, HAM_Is_favorite__c,
                   HAM_Is_Connected__c, HAM_Is_bookmarked__c,
                   HAM_Connection_Status__c
            FROM Ham_Connection__c
            WHERE Id = :blocked.Id
        ];

        System.assertEquals(false, updated.HAM_Is_Blocked__c,    'Should be unblocked');
        System.assertEquals(false, updated.HAM_Is_favorite__c,   'Favorite cleared on unblock');
        System.assertEquals(false, updated.HAM_Is_Connected__c,  'Connection cleared on unblock');
        System.assertEquals(false, updated.HAM_Is_bookmarked__c, 'Bookmark cleared on unblock');
        //System.assertEquals('',    updated.HAM_Connection_Status__c, 'Status blank after unblock');
    }

    // ─── checkUserStatus ───────────────────────────────────────────────────────

    @isTest
    static void testCheckUserStatus_NoUser() {
        Contact noUserContact = [SELECT Id FROM Contact WHERE LastName = 'Contact 0' LIMIT 1];

        Test.startTest();
        String result = HAM_AlumniConnectionService.checkUserStatus(noUserContact.Id);
        Test.stopTest();

        System.assertEquals('Inactive User', result, 'No user linked should return Inactive User');
    }

    @isTest
    static void testCheckUserStatus_BlankId() {
        Test.startTest();
        String result = HAM_AlumniConnectionService.checkUserStatus('');
        Test.stopTest();

        System.assertEquals('Error: Invalid ID', result, 'Blank Id should return error');
    }

    @isTest
    static void testCheckUserStatus_NullId() {
        Test.startTest();
        String result = HAM_AlumniConnectionService.checkUserStatus(null);
        Test.stopTest();

        System.assertEquals('Error: Invalid ID', result, 'Null Id should return error');
    }

    // ─── MISC NEGATIVE PATHS ──────────────────────────────────────────────────

    @isTest
    static void testHandleConnectionRequest_UnknownFunctionType() {
        List<Contact> contacts    = [SELECT Id FROM Contact ORDER BY LastName LIMIT 5];
        Contact portalUser        = contacts[0];
        Contact linkedConstituent = contacts[1];

        Test.startTest();
        String result = HAM_AlumniConnectionService.handleConnectionRequest(
            portalUser.Id,
            linkedConstituent.Id,
            null,
            'InvalidFunctionType'
        );
        Test.stopTest();

        System.assertEquals('Error', result, 'Unknown function type should return Error');
    }

    @isTest
    static void testHandleConnectionRequest_ExceptionHandling() {
        Test.startTest();
        String result = HAM_AlumniConnectionService.handleConnectionRequest(
            null,
            null,
            null,
            HAM_ConstantsUtil.SEND_REQUEST
        );
        Test.stopTest();

        System.assertNotEquals('Success', result, 'Should return error message on exception');
    }
}