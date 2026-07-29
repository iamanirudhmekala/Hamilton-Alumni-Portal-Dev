/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : HAMFilePublisherControllerTest
 * Author          : Ameya
 * Created Date    : Jul 15, 2026
 * Last Modified By: Ameya
 * Last Modified On: Jul 15, 2026
 * Description     : Test coverage for HAMFilePublisherController — file/Contact context loading,
 *                   the publish flow (classic public Document creation + Contact field write),
 *                   re-publish behavior, and every guard-rail error path (no linked Contact,
 *                   multiple linked Contacts, non-image file, missing Documents folder).
 *
 *                   NOTE: Folder does not support Apex DML (insert/update/delete), so this class
 *                   cannot create the "HAM HQ Profile Pictures" folder itself. Tests that reach
 *                   the actual Document-creation step (testPublishProfilePicture_Success and
 *                   testPublishProfilePicture_RepublishReusesSameDocument) use SeeAllData=true and
 *                   depend on that folder already existing in whichever org runs these tests —
 *                   consistent with the deployment prerequisite that an admin creates it manually
 *                   before this is deployed. The "missing folder" scenario is instead simulated
 *                   deterministically via the controller's @TestVisible override flag, so it
 *                   doesn't depend on the folder's absence in real org data. The Contact helper
 *                   sets FirstName as well as LastName since a validation rule (from the Ascend
 *                   managed package) requires a First Name on new constituents.
 *
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Jul 15, 2026  │ Ameya        │ Initial version
 *  Jul 15, 2026  │ Ameya        │ Removed Folder insert (not supported via Apex DML); success/
 *                │              │ republish tests now use SeeAllData=true against a real,
 *                │              │ manually-created folder; missing-folder test uses the
 *                │              │ controller's @TestVisible simulation flag instead
 *  Jul 15, 2026  │ Ameya        │ Added FirstName to the Contact test helper to satisfy an
 *                │              │ org validation rule requiring it on new constituents
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */
@isTest
private class HAMFilePublisherControllerTest {

    private static final String FOLDER_NAME = 'HAM HQ Profile Pictures';

    // ─── Test data helpers ─────────────────────────────────────────────

    private static Contact createContact(String lastName) {
        Contact con = new Contact(FirstName = 'Test', LastName = lastName);
        insert con;
        return [SELECT Id, Name FROM Contact WHERE Id = :con.Id];
    }

    private static ContentVersion createFile(String title, String extension) {
        ContentVersion cv = new ContentVersion();
        cv.Title = title;
        cv.PathOnClient = title + '.' + extension;
        cv.VersionData = Blob.valueOf('Fake file bytes for ' + title);
        insert cv;
        return [SELECT Id, ContentDocumentId, Title, FileExtension FROM ContentVersion WHERE Id = :cv.Id];
    }

    private static void linkFileToContact(Id contentDocumentId, Id contactId) {
        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = contentDocumentId;
        cdl.LinkedEntityId = contactId;
        cdl.ShareType = 'V';
        cdl.Visibility = 'AllUsers';
        insert cdl;
    }

    // ─── getFileContext ────────────────────────────────────────────────

    @isTest
    static void testGetFileContext_ImageLinkedToSingleContact() {
        Contact con = createContact('Publisher Test One');
        ContentVersion cv = createFile('Profile Photo', 'jpg');
        linkFileToContact(cv.ContentDocumentId, con.Id);

        Test.startTest();
        HAMFilePublisherController.FileContext ctx = HAMFilePublisherController.getFileContext(cv.ContentDocumentId);
        Test.stopTest();

        System.assertEquals(cv.ContentDocumentId, ctx.contentDocumentId);
        System.assertEquals('Profile Photo', ctx.title);
        System.assertEquals(true, ctx.isImage);
        System.assertEquals(1, ctx.linkedContactCount);
        System.assertEquals(con.Id, ctx.contactId);
        System.assertEquals(con.Name, ctx.contactName);
    }

    @isTest
    static void testGetFileContext_NonImageFileIsFlagged() {
        Contact con = createContact('Publisher Test Two');
        ContentVersion cv = createFile('Resume', 'pdf');
        linkFileToContact(cv.ContentDocumentId, con.Id);

        Test.startTest();
        HAMFilePublisherController.FileContext ctx = HAMFilePublisherController.getFileContext(cv.ContentDocumentId);
        Test.stopTest();

        System.assertEquals(false, ctx.isImage);
    }

    @isTest
    static void testGetFileContext_NoLinkedContact() {
        ContentVersion cv = createFile('Orphan Photo', 'png');

        Test.startTest();
        HAMFilePublisherController.FileContext ctx = HAMFilePublisherController.getFileContext(cv.ContentDocumentId);
        Test.stopTest();

        System.assertEquals(0, ctx.linkedContactCount);
        System.assertEquals(null, ctx.contactId);
    }

    @isTest
    static void testGetFileContext_MultipleLinkedContacts() {
        Contact conA = createContact('Publisher Test Three A');
        Contact conB = createContact('Publisher Test Three B');
        ContentVersion cv = createFile('Shared Photo', 'jpg');
        linkFileToContact(cv.ContentDocumentId, conA.Id);
        linkFileToContact(cv.ContentDocumentId, conB.Id);

        Test.startTest();
        HAMFilePublisherController.FileContext ctx = HAMFilePublisherController.getFileContext(cv.ContentDocumentId);
        Test.stopTest();

        System.assertEquals(2, ctx.linkedContactCount);
        System.assertEquals(null, ctx.contactId);
    }

    // ─── publishProfilePicture: success paths ──────────────────────────
    // These rely on the real "HAM HQ Profile Pictures" folder already existing in the org
    // (created manually per the deployment notes), since Folder can't be created via Apex DML.

    @isTest(SeeAllData=true)
    static void testPublishProfilePicture_Success() {
        Contact con = createContact('Publisher Test Four');
        ContentVersion cv = createFile('Headshot', 'jpg');
        linkFileToContact(cv.ContentDocumentId, con.Id);

        Test.startTest();
        String publicUrl = HAMFilePublisherController.publishProfilePicture(cv.ContentDocumentId);
        Test.stopTest();

        System.assert(publicUrl.contains('/servlet/servlet.ImageServer?id='), 'URL should use the ImageServer servlet format');
        System.assert(publicUrl.contains('&oid=' + UserInfo.getOrganizationId()), 'URL should include the org id');

        Contact updated = [SELECT Id, HAM_Profile_Picture_URL__c FROM Contact WHERE Id = :con.Id];
        System.assertEquals(publicUrl, updated.HAM_Profile_Picture_URL__c);

        String expectedDocName = 'ham_profile_' + cv.ContentDocumentId + '.jpg';
        List<Document> docs = [SELECT Id, Name, IsPublic FROM Document WHERE Name = :expectedDocName];
        System.assertEquals(1, docs.size(), 'Exactly one public Document should be created');
        System.assertEquals(true, docs[0].IsPublic);
    }

    @isTest(SeeAllData=true)
    static void testPublishProfilePicture_RepublishReusesSameDocument() {
        Contact con = createContact('Publisher Test Five');
        ContentVersion cv = createFile('Headshot Repeat', 'jpg');
        linkFileToContact(cv.ContentDocumentId, con.Id);

        Test.startTest();
        String firstUrl = HAMFilePublisherController.publishProfilePicture(cv.ContentDocumentId);
        String secondUrl = HAMFilePublisherController.publishProfilePicture(cv.ContentDocumentId);
        Test.stopTest();

        System.assertEquals(firstUrl, secondUrl, 'Re-publishing the same file should produce the same URL');

        String expectedDocName = 'ham_profile_' + cv.ContentDocumentId + '.jpg';
        List<Document> docs = [SELECT Id FROM Document WHERE Name = :expectedDocName];
        System.assertEquals(1, docs.size(), 'Re-publishing should update the existing Document, not create a duplicate');
    }

    // ─── publishProfilePicture: guard-rail error paths ─────────────────
    // These short-circuit before the folder lookup, so they don't need SeeAllData or the flag.

    @isTest
    static void testPublishProfilePicture_NoLinkedContact_Throws() {
        ContentVersion cv = createFile('No Contact Photo', 'jpg');

        Test.startTest();
        try {
            HAMFilePublisherController.publishProfilePicture(cv.ContentDocumentId);
            System.assert(false, 'Expected an AuraHandledException for a file with no linked Contact');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('not linked to any Contact'), 'Actual message: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testPublishProfilePicture_MultipleLinkedContacts_Throws() {
        Contact conA = createContact('Publisher Test Six A');
        Contact conB = createContact('Publisher Test Six B');
        ContentVersion cv = createFile('Shared Photo Two', 'jpg');
        linkFileToContact(cv.ContentDocumentId, conA.Id);
        linkFileToContact(cv.ContentDocumentId, conB.Id);

        Test.startTest();
        try {
            HAMFilePublisherController.publishProfilePicture(cv.ContentDocumentId);
            System.assert(false, 'Expected an AuraHandledException for a file linked to multiple Contacts');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('more than one Contact'), 'Actual message: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testPublishProfilePicture_NonImageFile_Throws() {
        Contact con = createContact('Publisher Test Seven');
        ContentVersion cv = createFile('Resume File', 'pdf');
        linkFileToContact(cv.ContentDocumentId, con.Id);

        Test.startTest();
        try {
            HAMFilePublisherController.publishProfilePicture(cv.ContentDocumentId);
            System.assert(false, 'Expected an AuraHandledException for a non-image file');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('not supported as a profile picture'), 'Actual message: ' + e.getMessage());
        }
        Test.stopTest();
    }

    // Simulates the missing-folder branch deterministically via the controller's @TestVisible
    // flag, since Folder can't be created (or reliably guaranteed absent) via Apex DML.
    @isTest
    static void testPublishProfilePicture_MissingFolder_Throws() {
        Contact con = createContact('Publisher Test Eight');
        ContentVersion cv = createFile('Headshot No Folder', 'jpg');
        linkFileToContact(cv.ContentDocumentId, con.Id);

        HAMFilePublisherController.simulateMissingFolderForTests = true;

        Test.startTest();
        try {
            HAMFilePublisherController.publishProfilePicture(cv.ContentDocumentId);
            System.assert(false, 'Expected an AuraHandledException about the missing folder');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains(FOLDER_NAME), 'Actual message: ' + e.getMessage());
        } finally {
            HAMFilePublisherController.simulateMissingFolderForTests = false;
        }
        Test.stopTest();
    }
}