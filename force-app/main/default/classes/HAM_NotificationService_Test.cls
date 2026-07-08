/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : HAM_NotificationService_Test
 * Author          : Sachin
 * Created Date    : Jan 15, 2026
 * Last Modified By: Sachin
 * Last Modified On: Jan 15, 2026
 * Description     : Test class for HAM_NotificationService.
 * 					 Validates notification DB creation, HTML cleaning, and graceful error handling
 * 					 for Push Notifications.
 *  
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Jan 15, 2026  │ Sachin   │ Initial version
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */

@isTest
private class HAM_NotificationService_Test {
	private static final String SENDER_NAME = 'SenderUser1';
    private static final String RECIPIENT_NAME = 'RecipientUser1';

    /**
     * @description Setup test data: Account and Contacts.
     */
    @testSetup
    static void setupData() {
        Account acc = new Account(Name = 'Test Notification Account');
        insert acc;

        Contact sender = new Contact(
            LastName = SENDER_NAME, 
            AccountId = acc.Id, 
            Email = 'sender1@test.com'
        );
        Contact recipient = new Contact(
            LastName = RECIPIENT_NAME, 
            AccountId = acc.Id, 
            Email = 'recipient1@test.com'
        );
        insert new List<Contact>{sender, recipient};
    }

    /**
     * @description Tests the main sendNotifications method with valid data.
     * Verifies that:
     * 1. A HAM_Notification__c record is created.
     * 2. HTML tags in the body are stripped.
     * 3. HTML entities are decoded.
     */
    @isTest
    static void testSendNotifications_Success() {
        Contact sender = [SELECT Id FROM Contact WHERE LastName = :SENDER_NAME LIMIT 1];
        Contact recipient = [SELECT Id FROM Contact WHERE LastName = :RECIPIENT_NAME LIMIT 1];

        // Prepare Request with Rich Text to test stripping logic
        HAM_NotificationService.NotificationRequest req = new HAM_NotificationService.NotificationRequest();
        req.recipientContactId = recipient.Id;
        // Use current user for ID (Push requires valid ID format even if it fails later due to config)
        req.recipientUserId = UserInfo.getUserId(); 
        req.senderContactId = sender.Id;
        req.title = 'Test Notification Title';
        req.body = '<p>Test Body with <b>Bold</b> and &amp; symbol</p>';
        req.sourceId = recipient.Id; // Arbitrary valid ID
        req.type = 'Connection';
        req.actionUrl = '/test-url';

        Test.startTest();
        HAM_NotificationService.sendNotifications(new List<HAM_NotificationService.NotificationRequest>{req});
        Test.stopTest();

        // Verify DB Record was created
        List<HAM_Notification__c> createdNotifs = [
            SELECT Id, HAM_Body__c, HAM_Title__c, HAM_Status__c 
            FROM HAM_Notification__c 
            WHERE HAM_Constituent__c = :recipient.Id
        ];
        
        System.assertEquals(1, createdNotifs.size(), 'One notification record should be created');
        System.assertEquals('Test Notification Title', createdNotifs[0].HAM_Title__c, 'Title should match');
        System.assertEquals('Unread', createdNotifs[0].HAM_Status__c, 'Default status should be Unread');
        
        // Verify HTML stripping: <p> and <b> removed, &amp; converted to &
        System.assertEquals('Test Body with Bold and & symbol', createdNotifs[0].HAM_Body__c, 'HTML tags should be stripped and entities decoded');
    }

    /**
     * @description Tests behavior when the Push Notification fails (e.g., Invalid User ID).
     * The service should catch the error and continue to insert the DB record.
     */
    @isTest
    static void testPushNotificationGracefulFailure() {
        Contact recipient = [SELECT Id FROM Contact WHERE LastName = :RECIPIENT_NAME LIMIT 1];

        HAM_NotificationService.NotificationRequest req = new HAM_NotificationService.NotificationRequest();
        req.recipientContactId = recipient.Id;
        req.recipientUserId = 'Invalid_UserString'; // This will cause Messaging.send() to throw/fail
        req.title = 'Fail Push Test';
        req.body = 'Body';

        Test.startTest();
        // Method call should NOT throw an exception to the test context
        HAM_NotificationService.sendNotifications(new List<HAM_NotificationService.NotificationRequest>{req});
        Test.stopTest();

        // Verify DB insert still succeeded
        Integer count = [SELECT Count() FROM HAM_Notification__c WHERE HAM_Title__c = 'Fail Push Test'];
        System.assertEquals(1, count, 'Database record should persist even if Push Notification service fails');
    }

    /**
     * @description Tests bulk processing capabilities.
     * Ensures the service handles a list of multiple requests correctly.
     */
    @isTest
    static void testBulkNotifications() {
        Contact recipient = [SELECT Id FROM Contact WHERE LastName = :RECIPIENT_NAME LIMIT 1];
        List<HAM_NotificationService.NotificationRequest> requests = new List<HAM_NotificationService.NotificationRequest>();

        // Create 20 bulk requests
        for(Integer i=0; i<20; i++) {
            HAM_NotificationService.NotificationRequest req = new HAM_NotificationService.NotificationRequest();
            req.recipientContactId = recipient.Id;
            req.title = 'Bulk Notification ' + i;
            req.body = 'Body text';
            requests.add(req);
        }

        Test.startTest();
        HAM_NotificationService.sendNotifications(requests);
        Test.stopTest();

        Integer count = [SELECT Count() FROM HAM_Notification__c WHERE HAM_Title__c LIKE 'Bulk Notification%'];
        System.assertEquals(20, count, 'All 20 bulk notifications should be inserted into the database');
    }

    /**
     * @description Tests sending a notification request with a blank body.
     * Verifies that the fallback push notification body is used and does not throw an exception.
     */
    @isTest
    static void testSendNotifications_EmptyBody_Success() {
        Contact sender = [SELECT Id FROM Contact WHERE LastName = :SENDER_NAME LIMIT 1];
        Contact recipient = [SELECT Id FROM Contact WHERE LastName = :RECIPIENT_NAME LIMIT 1];

        HAM_NotificationService.NotificationRequest req = new HAM_NotificationService.NotificationRequest();
        req.recipientContactId = recipient.Id;
        req.recipientUserId = UserInfo.getUserId();
        req.senderContactId = sender.Id;
        req.senderName = 'Test Sender';
        req.title = 'has sent you a connection request';
        req.body = ''; // Blank body to trigger the fallback logic
        req.sourceId = recipient.Id;
        req.type = 'Connection';
        req.actionUrl = '/test-url';

        Test.startTest();
        HAM_NotificationService.sendNotifications(new List<HAM_NotificationService.NotificationRequest>{req});
        Test.stopTest();

        // Verify DB Record was created with blank/null body to ensure LWC portal bell behaves correctly
        List<HAM_Notification__c> createdNotifs = [
            SELECT Id, HAM_Body__c, HAM_Title__c
            FROM HAM_Notification__c 
            WHERE HAM_Constituent__c = :recipient.Id
        ];
        
        System.assertEquals(1, createdNotifs.size(), 'One notification record should be created');
        System.assert(String.isBlank(createdNotifs[0].HAM_Body__c), 'DB record body should remain blank/empty');
    }
}