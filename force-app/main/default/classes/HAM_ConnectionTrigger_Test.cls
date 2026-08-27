/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : HAM_ConnectionTrigger_Test
 * Author          : Sachin
 * Created Date    : Jan 15, 2026
 * Last Modified By: Sachin
 * Last Modified On: Jan 15, 2026
 * Description     : This is a test class for HAMConnectionTrigger and its handler class
 *  
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Jan 15, 2026  │ Sachin   │ Initial version
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */
@SuppressWarnings('PMD.NoTrailingWhitespace, PMD.ApexCRUDViolation, PMD.EmptyIfStmt, PMD.EmptyStatementBlock, PMD.AvoidNonRestrictiveQueries, PMD.CyclomaticComplexity, PMD.CognitiveComplexity, PMD.NcssCount, PMD.NcssTypeCount, PMD.DetectCopyPasteForApex, PMD.LocalVariableNamingConventions, PMD.ExcessiveParameterList, PMD.ApexSOQLInjection, PMD.AvoidDeeplyNestedIfStmts, PMD.AvoidDebugStatements, PMD.StdCyclomaticComplexity, PMD.NcssMethodCount')
@isTest
public class HAM_ConnectionTrigger_Test {

    @testSetup
    static void setup() {
        // Create Setup Data (Account, Contacts)
        Account acc = new Account(Name = 'Trigger Test Account');
        insert acc;
        
        // Email is required, not cosmetic: inserting a HAM_Connection__c with
        // Status = 'Request Sent' fires the record-triggered flow
        // 'HAM Connection Request Notification', whose email alert resolves its
        // recipient from the related contact. With no Email the alert resolves to
        // 0 recipients, the flow fails, and the DML is rolled back with
        // CANNOT_EXECUTE_FLOW_TRIGGER before any trigger assertion can run.
        // (HAM_Data_Source__c defaults to 'Portal User', so the flow's second
        // filter is always satisfied in tests even though no test sets it.)
        Contact sender = new Contact(LastName = 'Sender2', AccountId = acc.Id, Email = 'sender2@test.com');
        Contact recipient = new Contact(LastName = 'Recipient2', AccountId = acc.Id, Email = 'recipient2@test.com');
        insert new List<Contact>{sender, recipient};
        
        // Create User for recipient (needed for Push Notification mapping in trigger)
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Partner Community Login User' LIMIT 1];
        User u = new User(
            Alias = 'trigtst', Email='recipient2@test.com', 
            EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US', 
            LocaleSidKey='en_US', ProfileId = p.Id, 
            TimeZoneSidKey='America/Los_Angeles', UserName='triggeruser' + System.currentTimeMillis() + '@test.com',
            ContactId = recipient.Id
        );
    }

    @isTest
    static void testAfterInsert_CreatesNotification() {
        Contact sender = [SELECT Id FROM Contact WHERE LastName = 'Sender2' LIMIT 1];
        Contact recipient = [SELECT Id FROM Contact WHERE LastName = 'Recipient2' LIMIT 1];
        
        Test.startTest();
        // Case: Insert with 'Request Sent'
        HAM_Connection__c conn = new HAM_Connection__c(
            HAM_Portal_User__c = sender.Id,
            HAM_Linked_Constituent__c = recipient.Id,
            HAM_Connection_Status__c = 'Request Sent', 
            HAM_Connection_Message__c = 'Let\'s connect'
        );
        insert conn;
        Test.stopTest();
        
        // Verify Notification Created
        List<HAM_Notification__c> notifs = [SELECT Id, HAM_Title__c FROM HAM_Notification__c WHERE HAM_Source_Object_ID__c = :conn.Id];
        System.assertEquals(1, notifs.size(), 'Notification should be created on Insert of Request Sent');
        System.assertEquals('has sent you a connection request', notifs[0].HAM_Title__c);
    }

    @isTest
    static void testAfterUpdate_CreatesNotification() {
        Contact sender = [SELECT Id FROM Contact WHERE LastName = 'Sender2' LIMIT 1];
        Contact recipient = [SELECT Id FROM Contact WHERE LastName = 'Recipient2' LIMIT 1];
        
        // Setup: Create connection in a 'Draft' state (No notification yet)
        HAM_Connection__c conn = new HAM_Connection__c(
            HAM_Portal_User__c = sender.Id,
            HAM_Linked_Constituent__c = recipient.Id,
            HAM_Connection_Status__c = '' 
        );
        insert conn;

        // Verify NO notification exists yet
        Integer countBefore = [SELECT Count() FROM HAM_Notification__c WHERE HAM_Source_Object_ID__c = :conn.Id];
        System.assertEquals(0, countBefore, 'No notification should exist for Draft status');

        Test.startTest();
        // Action: Update Status to 'Request Sent'
        conn.HAM_Connection_Status__c = 'Request Sent';
        update conn;
        Test.stopTest();

        // Verify Notification Created
        List<HAM_Notification__c> notifs = [SELECT Id FROM HAM_Notification__c WHERE HAM_Source_Object_ID__c = :conn.Id];
        System.assertEquals(1, notifs.size(), 'Notification should be created when Status changes to Request Sent');
    }

    @isTest
    static void testAfterUpdate_DeletesNotification() {
        Contact sender = [SELECT Id FROM Contact WHERE LastName = 'Sender2' LIMIT 1];
        Contact recipient = [SELECT Id FROM Contact WHERE LastName = 'Recipient2' LIMIT 1];
        
        // Setup: Create connection WITH notification
        HAM_Connection__c conn = new HAM_Connection__c(
            HAM_Portal_User__c = sender.Id,
            HAM_Linked_Constituent__c = recipient.Id,
            HAM_Connection_Status__c = 'Request Sent'
        );
        insert conn;

        // Verify notification exists
        Integer countBefore = [SELECT Count() FROM HAM_Notification__c WHERE HAM_Source_Object_ID__c = :conn.Id];
        System.assertEquals(1, countBefore, 'Notification should exist initially');

        Test.startTest();
        // Action: Update Status to NULL (Simulating a withdrawal or reset)
        conn.HAM_Connection_Status__c = null;
        update conn;
        Test.stopTest();

        // Verify Notification Deleted
        Integer countAfter = [SELECT Count() FROM HAM_Notification__c WHERE HAM_Source_Object_ID__c = :conn.Id];
        System.assertEquals(0, countAfter, 'Notification should be deleted when Status changes to null');
    }

    @isTest
    static void testAfterDelete_DeletesNotification() {
        Contact sender = [SELECT Id FROM Contact WHERE LastName = 'Sender2' LIMIT 1];
        Contact recipient = [SELECT Id FROM Contact WHERE LastName = 'Recipient2' LIMIT 1];
        
        // Setup
        HAM_Connection__c conn = new HAM_Connection__c(
            HAM_Portal_User__c = sender.Id,
            HAM_Linked_Constituent__c = recipient.Id,
            HAM_Connection_Status__c = 'Request Sent'
        );
        insert conn;
        
        Test.startTest();
        // Action: Delete the Connection record itself
        delete conn;
        Test.stopTest();
        
        // Verify Notification Deleted
        Integer countAfter = [SELECT Count() FROM HAM_Notification__c WHERE HAM_Source_Object_ID__c = :conn.Id];
        System.assertEquals(0, countAfter, 'Notification should be deleted when parent connection is deleted');
    }
}