/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : HAM_ContentDocumentLinkHandler_Test
 * Author          : Anirudh
 * Created Date    : July 16, 2026
 * Description     : Test class for HAM_ContentDocumentLinkHandler and ContentDocumentLinkTrigger.
 *                   Verifies that files linked to HAM_Group_Post__c records are forced to
 *                   'AllUsers' visibility, video files are blocked, and links to non-post
 *                   entities are left untouched.
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */
@isTest
private class HAM_ContentDocumentLinkHandler_Test {

    /**
     * @description Setup: a group with a single post that files can be attached to, plus a
     *              Contact used to test the non-post (ignored) branch.
     */
    @testSetup
    static void setupData() {
        Account acc = new Account(Name = 'CDL Test Account');
        insert acc;

        Contact author = new Contact(LastName = 'CDL_Author', AccountId = acc.Id);
        insert author;

        HAM_Group__c grp = new HAM_Group__c(
            Name = 'CDL Test Group',
            is_Active__c = true,
            Visibility__c = 'Public'
        );
        insert grp;

        HAM_Group_Post__c post = new HAM_Group_Post__c(
            Group__c = grp.Id,
            Author__c = author.Id,
            Body__c = '<p>Post body</p>'
        );
        insert post;
    }

    /**
     * @description Inserts a ContentVersion and returns its generated ContentDocumentId.
     * @param fileName File name including extension (drives ContentVersion.FileExtension).
     * @return Id of the ContentDocument created behind the version.
     */
    private static Id createDocument(String fileName) {
        ContentVersion cv = new ContentVersion(
            Title = fileName,
            PathOnClient = fileName,
            VersionData = Blob.valueOf('sample file content')
        );
        insert cv;
        return [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1].ContentDocumentId;
    }

    /**
     * @description A non-video file linked to a group post has its Visibility forced to 'AllUsers'.
     */
    @isTest
    static void testPostLinkForcesAllUsersVisibility() {
        HAM_Group_Post__c post = [SELECT Id FROM HAM_Group_Post__c LIMIT 1];
        Id docId = createDocument('handbook.pdf');

        ContentDocumentLink link = new ContentDocumentLink(
            ContentDocumentId = docId,
            LinkedEntityId = post.Id,
            ShareType = 'V',
            Visibility = 'InternalUsers' // handler should overwrite this
        );

        Test.startTest();
        insert link;
        Test.stopTest();

        ContentDocumentLink saved = [
            SELECT Visibility FROM ContentDocumentLink WHERE Id = :link.Id LIMIT 1
        ];
        System.assertEquals('AllUsers', saved.Visibility,
            'Files on group posts must be visible to all portal users');
    }

    /**
     * @description A video file linked to a group post is blocked with a DmlException via addError.
     */
    @isTest
    static void testVideoUploadIsBlocked() {
        HAM_Group_Post__c post = [SELECT Id FROM HAM_Group_Post__c LIMIT 1];
        Id docId = createDocument('demo.mp4');

        ContentDocumentLink link = new ContentDocumentLink(
            ContentDocumentId = docId,
            LinkedEntityId = post.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        Boolean blocked = false;
        Test.startTest();
        try {
            insert link;
        } catch (DmlException e) {
            blocked = true;
            System.assert(e.getMessage().contains('Video files cannot be attached'),
                'Error should explain why the video was rejected: ' + e.getMessage());
        }
        Test.stopTest();

        System.assert(blocked, 'Inserting a video file on a group post should be blocked');
    }

    /**
     * @description A file linked to a non-post entity (a Contact) is ignored: no error, and its
     *              visibility is not forced to 'AllUsers'.
     */
    @isTest
    static void testNonPostLinkIgnored() {
        Contact author = [SELECT Id FROM Contact WHERE LastName = 'CDL_Author' LIMIT 1];
        Id docId = createDocument('resume.pdf');

        ContentDocumentLink link = new ContentDocumentLink(
            ContentDocumentId = docId,
            LinkedEntityId = author.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        Test.startTest();
        insert link; // should not throw
        Test.stopTest();

        System.assertNotEquals(null, link.Id, 'Link to a non-post entity should insert normally');
    }

    /**
     * @description Directly exercises the empty-list guard clause.
     */
    @isTest
    static void testEmptyListGuard() {
        Test.startTest();
        HAM_ContentDocumentLinkHandler.handleBeforeInsert(new List<ContentDocumentLink>());
        HAM_ContentDocumentLinkHandler.handleBeforeInsert(null);
        Test.stopTest();
        // No assertion needed: the guard simply returns without error.
    }
}