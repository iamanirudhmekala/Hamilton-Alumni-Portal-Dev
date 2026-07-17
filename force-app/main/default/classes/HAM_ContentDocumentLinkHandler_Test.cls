/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : HAM_ContentDocumentLinkHandler_Test
 * Author          : Anirudh
 * Created Date    : July 16, 2026
 * Description     : Test class for HAM_ContentDocumentLinkHandler and ContentDocumentLinkTrigger.
 *                   The handler's branching logic is asserted by invoking handleBeforeInsert
 *                   directly against in-memory ContentDocumentLink records, which is deterministic
 *                   and avoids the platform's visibility coercion on ContentDocumentLink commit.
 *                   A separate DML-insert test keeps the trigger itself covered.
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
     * @description A non-video file linked to a group post has its in-memory Visibility forced
     *              to 'AllUsers' by the handler.
     */
    @isTest
    static void testPostLinkForcesAllUsersVisibility() {
        HAM_Group_Post__c post = [SELECT Id FROM HAM_Group_Post__c LIMIT 1];
        Id docId = createDocument('handbook.pdf');

        ContentDocumentLink link = new ContentDocumentLink(
            ContentDocumentId = docId,
            LinkedEntityId = post.Id,
            ShareType = 'V',
            Visibility = 'InternalUsers' // handler should overwrite this in memory
        );

        Test.startTest();
        HAM_ContentDocumentLinkHandler.handleBeforeInsert(new List<ContentDocumentLink>{ link });
        Test.stopTest();

        System.assertEquals('AllUsers', link.Visibility,
            'Files on group posts must be forced to AllUsers visibility');
        System.assert(!link.hasErrors(), 'A PDF should not be rejected');
    }

    /**
     * @description A video file linked to a group post is rejected via addError.
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

        Test.startTest();
        HAM_ContentDocumentLinkHandler.handleBeforeInsert(new List<ContentDocumentLink>{ link });
        Test.stopTest();

        System.assert(link.hasErrors(), 'A video file on a group post should be rejected');
        System.assert(link.getErrors()[0].getMessage().contains('Video files cannot be attached'),
            'Error should explain why the video was rejected: ' + link.getErrors()[0].getMessage());
    }

    /**
     * @description A file linked to a non-post entity (a Contact) is ignored: no error, and its
     *              visibility is left as-is. Covers the isPostLink false branch and the early return
     *              when no post-linked documents are present.
     */
    @isTest
    static void testNonPostLinkIgnored() {
        Contact author = [SELECT Id FROM Contact WHERE LastName = 'CDL_Author' LIMIT 1];
        Id docId = createDocument('resume.pdf');

        ContentDocumentLink link = new ContentDocumentLink(
            ContentDocumentId = docId,
            LinkedEntityId = author.Id,
            ShareType = 'V',
            Visibility = 'InternalUsers'
        );

        Test.startTest();
        HAM_ContentDocumentLinkHandler.handleBeforeInsert(new List<ContentDocumentLink>{ link });
        Test.stopTest();

        System.assert(!link.hasErrors(), 'A file on a non-post entity should not be rejected');
        System.assertEquals('InternalUsers', link.Visibility,
            'Visibility of a non-post link should be left untouched');
    }

    /**
     * @description Smoke test: inserts a real ContentDocumentLink on a post so that, where the
     *              platform fires before-insert on ContentDocumentLink, the trigger
     *              (ContentDocumentLinkTrigger -> handleBeforeInsert) is covered. We assert only
     *              that the insert succeeds; the handler's field/error behavior is asserted
     *              deterministically in the direct-call tests above.
     */
    @isTest
    static void testTriggerFiresOnInsert() {
        HAM_Group_Post__c post = [SELECT Id FROM HAM_Group_Post__c LIMIT 1];
        Id docId = createDocument('agenda.pdf');

        ContentDocumentLink link = new ContentDocumentLink(
            ContentDocumentId = docId,
            LinkedEntityId = post.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        Test.startTest();
        insert link;
        Test.stopTest();

        System.assertNotEquals(null, link.Id, 'Link to a post should insert and fire the trigger');
    }

    /**
     * @description Directly exercises the empty-list and null guard clauses.
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
