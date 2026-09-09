/**
 * @description Test class for miltonAlumniConnectionAction. Covers getConnectionFlags
 * (self, connected, request-sent, bookmarked and empty/null-input branches), updateConnection
 * (allowed vs. disallowed function types) and the checkUserStatus passthrough.
 */
@IsTest
private class miltonAlumniConnectionAction_Test {

    @TestSetup
    static void setup() {
        insert new List<Contact>{
            new Contact(FirstName = 'Milton', LastName = 'ViewerConn', Email = 'viewerconn@miltontest.com'),
            new Contact(FirstName = 'Milton', LastName = 'ConnectedAsPortal', Email = 'connportal@miltontest.com'),
            new Contact(FirstName = 'Milton', LastName = 'ConnectedAsLinked', Email = 'connlinked@miltontest.com'),
            new Contact(FirstName = 'Milton', LastName = 'RequestSentTarget', Email = 'reqsent@miltontest.com'),
            new Contact(FirstName = 'Milton', LastName = 'BookmarkedTarget', Email = 'bookmarked@miltontest.com'),
            new Contact(FirstName = 'Milton', LastName = 'NoRelation', Email = 'norelation@miltontest.com')
        };
    }

    private static Contact getContact(String lastName) {
        return [SELECT Id FROM Contact WHERE LastName = :lastName LIMIT 1];
    }

    @IsTest
    static void testGetConnectionFlags_NullViewerOrEmptyIds() {
        Contact target = getContact('NoRelation');

        Test.startTest();
        Map<Id, miltonAlumniConnectionAction.ConnectionFlags> withNullViewer =
            miltonAlumniConnectionAction.getConnectionFlags(null, new List<Id>{ target.Id });
        Map<Id, miltonAlumniConnectionAction.ConnectionFlags> withEmptyIds =
            miltonAlumniConnectionAction.getConnectionFlags(getContact('ViewerConn').Id, new List<Id>());
        Test.stopTest();

        Assert.isTrue(withNullViewer.containsKey(target.Id), 'A default flags entry is still returned per input id');
        Assert.isFalse(withNullViewer.get(target.Id).isConnected, 'Default flags should all be false');
        Assert.isTrue(withEmptyIds.isEmpty(), 'No ids in, nothing out');
    }

    @IsTest
    static void testGetConnectionFlags_SelfConnectedRequestSentAndBookmarked() {
        Contact viewer = getContact('ViewerConn');
        Contact connectedAsPortal = getContact('ConnectedAsPortal');
        Contact connectedAsLinked = getContact('ConnectedAsLinked');
        Contact requestSentTarget = getContact('RequestSentTarget');
        Contact bookmarkedTarget = getContact('BookmarkedTarget');

        insert new List<HAM_Connection__c>{
            // viewer is the portal user side - connected, and this row also carries the bookmark flag
            new HAM_Connection__c(
                HAM_Portal_User__c = viewer.Id,
                HAM_Linked_Constituent__c = connectedAsPortal.Id,
                HAM_Connection_Status__c = HAM_ConstantsUtil.CONNECTED,
                HAM_Is_bookmarked__c = false
            ),
            // viewer is the linked-constituent side - connected, but request-sent/bookmark only
            // apply from the portal-user perspective so those must stay false for this row
            new HAM_Connection__c(
                HAM_Portal_User__c = connectedAsLinked.Id,
                HAM_Linked_Constituent__c = viewer.Id,
                HAM_Connection_Status__c = HAM_ConstantsUtil.CONNECTED
            ),
            // viewer sent a request that is still pending
            new HAM_Connection__c(
                HAM_Portal_User__c = viewer.Id,
                HAM_Linked_Constituent__c = requestSentTarget.Id,
                HAM_Connection_Status__c = HAM_ConstantsUtil.REQUEST_SENT
            ),
            // viewer bookmarked this contact without yet being connected
            new HAM_Connection__c(
                HAM_Portal_User__c = viewer.Id,
                HAM_Linked_Constituent__c = bookmarkedTarget.Id,
                HAM_Is_bookmarked__c = true
            )
        };

        List<Id> alumniIds = new List<Id>{
            viewer.Id, connectedAsPortal.Id, connectedAsLinked.Id, requestSentTarget.Id, bookmarkedTarget.Id
        };

        Test.startTest();
        Map<Id, miltonAlumniConnectionAction.ConnectionFlags> flags =
            miltonAlumniConnectionAction.getConnectionFlags(viewer.Id, alumniIds);
        Test.stopTest();

        Assert.isTrue(flags.get(viewer.Id).isSelf, 'Viewer included in the id list must be flagged as self');
        Assert.isTrue(flags.get(connectedAsPortal.Id).isConnected, 'Connected (viewer as portal user) must be true');
        Assert.isTrue(flags.get(connectedAsLinked.Id).isConnected, 'Connected (viewer as linked constituent) must be true');
        Assert.isFalse(flags.get(connectedAsLinked.Id).isRequestSent, 'Request-sent only applies from the portal-user side');
        Assert.isTrue(flags.get(requestSentTarget.Id).isRequestSent, 'Pending outbound request must be flagged');
        Assert.isTrue(flags.get(bookmarkedTarget.Id).isBookmarked, 'Bookmark flag must be surfaced');
    }

    @IsTest
    static void testUpdateConnection_DisallowedFunctionType() {
        Contact viewer = getContact('ViewerConn');
        Contact target = getContact('NoRelation');

        Test.startTest();
        String result = miltonAlumniConnectionAction.updateConnection(viewer.Id, target.Id, 'Accept');
        Test.stopTest();

        Assert.areEqual('Error', result, 'Function types outside the allow-list must be rejected');
    }

    @IsTest
    static void testUpdateConnection_AllowedFunctionTypeDelegatesToService() {
        Contact viewer = getContact('ViewerConn');
        Contact target = getContact('NoRelation');

        Test.startTest();
        String result = miltonAlumniConnectionAction.updateConnection(viewer.Id, target.Id, HAM_ConstantsUtil.SEND_REQUEST);
        Test.stopTest();

        Assert.isNotNull(result, 'Allowed function types must delegate to HAM_AlumniConnectionService and return its result');
    }

    @IsTest
    static void testCheckUserStatus_NoRelatedUser() {
        Contact target = getContact('NoRelation');

        Test.startTest();
        String status = miltonAlumniConnectionAction.checkUserStatus(target.Id);
        Test.stopTest();

        Assert.areEqual('Inactive User', status, 'A contact with no related User must report Inactive User');
    }
}