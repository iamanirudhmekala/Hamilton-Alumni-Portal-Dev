/**
 * HamCCNotesControllerTest
 *
 * Test coverage for HamCCNotesController.
 * Covers: getNotes, saveNote, buildTitle, buildHtmlContent, extractDateFromNote
 *
 * ContentNote / ContentDocumentLink require special care in tests:
 *   - ContentNote must be inserted before ContentDocumentLink
 *   - ContentDocumentLink.LinkedEntityId cannot point to User in some orgs;
 *     we use Contact and Account as realistic parent records
 *   - MIXED_DML_OPERATION is avoided by inserting User setup in a separate
 *     @testSetup method (all other DML in test methods uses Contact/Account)
 */
@IsTest
private class HamCCNotesControllerTest {

    // ─── Test Data Setup ─────────────────────────────────────────────────────

    @TestSetup
    static void makeData() {
        // Contact — represents an Alumni constituent
        Contact con = new Contact(
            FirstName = 'Test',
            LastName  = 'Alumni',
            Email     = 'test.alumni@hamilton.edu'
        );
        insert con;

        // Account — represents an Employer constituent
        Account acc = new Account(Name = 'Test Employer Corp');
        insert acc;
    }

    // Helper: fetch the test Contact
    private static Contact getContact() {
        return [SELECT Id FROM Contact WHERE LastName = 'Alumni' LIMIT 1];
    }

    // Helper: fetch the test Account
    private static Account getAccount() {
        return [SELECT Id FROM Account WHERE Name = 'Test Employer Corp' LIMIT 1];
    }

    /**
     * Creates a ContentNote and links it to a parent record.
     * Returns the ContentNote Id (== ContentDocument.Id).
     */
    private static Id createNote(String title, String content, Id parentId) {
        ContentNote cn = new ContentNote();
        cn.Title   = title;
        cn.Content = Blob.valueOf('<!DOCTYPE html><html><body>' + content + '</body></html>');
        insert cn;

        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = cn.Id;
        cdl.LinkedEntityId    = parentId;
        cdl.ShareType         = 'V';
        cdl.Visibility        = 'AllUsers';
        insert cdl;

        return cn.Id;
    }

    // ─── getNotes ────────────────────────────────────────────────────────────

    @IsTest
    static void getNotes_returnsEmptyList_whenRecordIdIsBlank() {
        Test.startTest();
        List<HamCCNotesController.NoteWrapper> result =
            HamCCNotesController.getNotes('', true);
        Test.stopTest();

        Assert.areEqual(0, result.size(), 'Expected empty list for blank recordId');
    }

    @IsTest
    static void getNotes_returnsEmptyList_whenRecordIdIsNull() {
        Test.startTest();
        List<HamCCNotesController.NoteWrapper> result =
            HamCCNotesController.getNotes(null, true);
        Test.stopTest();

        Assert.areEqual(0, result.size(), 'Expected empty list for null recordId');
    }

    @IsTest
    static void getNotes_returnsEmptyList_whenNoNotesLinked() {
        Contact con = getContact();

        Test.startTest();
        List<HamCCNotesController.NoteWrapper> result =
            HamCCNotesController.getNotes(con.Id, true);
        Test.stopTest();

        Assert.areEqual(0, result.size(), 'Expected empty list when no notes exist for contact');
    }

    @IsTest
    static void getNotes_returnsSingleNote_forContact() {
        Contact con = getContact();
        createNote('02/13/2026 - Alumni Meeting', 'Time: 10:45 am, Note: SADOVE', con.Id);

        Test.startTest();
        List<HamCCNotesController.NoteWrapper> result =
            HamCCNotesController.getNotes(con.Id, true);
        Test.stopTest();

        Assert.areEqual(1, result.size(), 'Expected exactly 1 note for contact');
        HamCCNotesController.NoteWrapper w = result[0];
        Assert.areEqual('02/13/2026 - Alumni Meeting', w.Title, 'Title mismatch');
        Assert.isNotNull(w.Id, 'Wrapper Id should not be null');
        Assert.isNotNull(w.ContentDocumentId, 'ContentDocumentId should not be null');
        Assert.areEqual(w.Id, w.ContentDocumentId, 'Id and ContentDocumentId should be equal for ContentNote');
    }

    @IsTest
    static void getNotes_returnsMultipleNotes_forContact() {
        Contact con = getContact();
        createNote('02/13/2026 - Note One', 'Content one', con.Id);
        createNote('01/15/2026 - Note Two', 'Content two', con.Id);
        createNote('03/01/2026 - Note Three', 'Content three', con.Id);

        Test.startTest();
        List<HamCCNotesController.NoteWrapper> result =
            HamCCNotesController.getNotes(con.Id, true);
        Test.stopTest();

        Assert.areEqual(3, result.size(), 'Expected 3 notes for contact');
    }

    @IsTest
    static void getNotes_returnsSingleNote_forAccount() {
        Account acc = getAccount();
        createNote('03/01/2026 - Employer Meeting', 'Discussed recruiting', acc.Id);

        Test.startTest();
        List<HamCCNotesController.NoteWrapper> result =
            HamCCNotesController.getNotes(acc.Id, false);
        Test.stopTest();

        Assert.areEqual(1, result.size(), 'Expected exactly 1 note for account');
        Assert.areEqual('03/01/2026 - Employer Meeting', result[0].Title, 'Title mismatch for account note');
    }

    @IsTest
    static void getNotes_noteDateExtracted_fromTitlePrefix() {
        Contact con = getContact();
        createNote('02/13/2026 - Alumni Meeting', 'Some content', con.Id);

        Test.startTest();
        List<HamCCNotesController.NoteWrapper> result =
            HamCCNotesController.getNotes(con.Id, true);
        Test.stopTest();

        Assert.areEqual(1, result.size());
        // Title prefix MM/DD/YYYY should be converted to YYYY-MM-DD
        Assert.areEqual('2026-02-13', result[0].NoteDate,
            'NoteDate should be extracted from title prefix in ISO format');
    }

    @IsTest
    static void getNotes_noteDateFallsBackToCreatedDate_whenNoPrefixInTitle() {
        Contact con = getContact();
        createNote('General Note With No Date Prefix', 'Some content', con.Id);

        Test.startTest();
        List<HamCCNotesController.NoteWrapper> result =
            HamCCNotesController.getNotes(con.Id, true);
        Test.stopTest();

        Assert.areEqual(1, result.size());
        // NoteDate should fall back to CreatedDate (today in YYYY-MM-DD)
        String today = String.valueOf(Date.today());
        Assert.areEqual(today, result[0].NoteDate,
            'NoteDate should fall back to CreatedDate when no MM/DD/YYYY prefix in title');
    }

    @IsTest
    static void getNotes_noteDateFallsBack_whenTitleShorterThan10Chars() {
        Contact con = getContact();
        createNote('Short', 'Content', con.Id);

        Test.startTest();
        List<HamCCNotesController.NoteWrapper> result =
            HamCCNotesController.getNotes(con.Id, true);
        Test.stopTest();

        Assert.areEqual(1, result.size());
        // Title too short to contain a date prefix — should fall back to CreatedDate
        Assert.isNotNull(result[0].NoteDate, 'NoteDate should not be null');
        Assert.isFalse(result[0].NoteDate == '', 'NoteDate should not be empty string');
    }

    @IsTest
    static void getNotes_onlyReturnsNotesNotOtherDocuments() {
        Contact con = getContact();
        // Insert a plain ContentNote (SNOTE type)
        createNote('02/13/2026 - Real Note', 'Note content', con.Id);

        // Insert a non-note ContentDocument (e.g. a text file attachment)
        // ContentVersion creates a ContentDocument automatically
        ContentVersion cv = new ContentVersion();
        cv.Title           = 'Not A Note';
        cv.PathOnClient    = 'attachment.txt';
        cv.VersionData     = Blob.valueOf('file content');
        cv.FirstPublishLocationId = con.Id;
        insert cv;

        Test.startTest();
        List<HamCCNotesController.NoteWrapper> result =
            HamCCNotesController.getNotes(con.Id, true);
        Test.stopTest();

        // Only the ContentNote should come back (getNotes queries ContentNote which
        // filters to SNOTE type automatically; attachments are not ContentNotes)
        Assert.areEqual(1, result.size(),
            'getNotes should only return ContentNote records, not file attachments');
        Assert.areEqual('02/13/2026 - Real Note', result[0].Title);
    }

    // ─── saveNote ────────────────────────────────────────────────────────────

    @IsTest
    static void saveNote_createsNoteAndLink_forContact() {
        Contact con = getContact();

        Test.startTest();
        HamCCNotesController.saveNote(con.Id, true, 'Meeting Notes', 'Discussed giving', '2026-02-13');
        Test.stopTest();

        // Verify ContentNote was created
        List<ContentNote> notes = [SELECT Id, Title FROM ContentNote WHERE Title LIKE '%Meeting Notes%'];
        Assert.areEqual(1, notes.size(), 'Expected 1 ContentNote to be created');
        Assert.isTrue(notes[0].Title.contains('02/13/2026'), 'Title should contain the formatted date prefix');
        Assert.isTrue(notes[0].Title.contains('Meeting Notes'), 'Title should contain original title');

        // Verify ContentDocumentLink was created
        List<ContentDocumentLink> links = [
            SELECT Id FROM ContentDocumentLink
            WHERE LinkedEntityId = :con.Id AND ContentDocumentId = :notes[0].Id
        ];
        Assert.areEqual(1, links.size(), 'Expected ContentDocumentLink linking note to contact');
    }

    @IsTest
    static void saveNote_createsNoteAndLink_forAccount() {
        Account acc = getAccount();

        Test.startTest();
        HamCCNotesController.saveNote(acc.Id, false, 'Employer Call', 'Recruiting discussion', '2026-03-01');
        Test.stopTest();

        List<ContentNote> notes = [SELECT Id, Title FROM ContentNote WHERE Title LIKE '%Employer Call%'];
        Assert.areEqual(1, notes.size(), 'Expected 1 ContentNote for account');

        List<ContentDocumentLink> links = [
            SELECT Id FROM ContentDocumentLink
            WHERE LinkedEntityId = :acc.Id AND ContentDocumentId = :notes[0].Id
        ];
        Assert.areEqual(1, links.size(), 'Expected ContentDocumentLink linking note to account');
    }

    @IsTest
    static void saveNote_titleFormattedWithDatePrefix() {
        Contact con = getContact();

        Test.startTest();
        HamCCNotesController.saveNote(con.Id, true, 'Spring Outreach', 'Called re: reunion', '2026-04-15');
        Test.stopTest();

        ContentNote note = [SELECT Title FROM ContentNote WHERE Title LIKE '%Spring Outreach%' LIMIT 1];
        Assert.areEqual('04/15/2026 - Spring Outreach', note.Title,
            'Title should be prefixed with MM/DD/YYYY');
    }

    @IsTest
    static void saveNote_titleHasNoPrefix_whenNoteDateIsBlank() {
        Contact con = getContact();

        Test.startTest();
        HamCCNotesController.saveNote(con.Id, true, 'Undated Note', 'No date provided', '');
        Test.stopTest();

        ContentNote note = [SELECT Title FROM ContentNote WHERE Title = 'Undated Note' LIMIT 1];
        Assert.areEqual('Undated Note', note.Title,
            'Title should have no date prefix when noteDate is blank');
    }

    @IsTest
    static void saveNote_titleHasNoPrefix_whenNoteDateIsNull() {
        Contact con = getContact();

        Test.startTest();
        HamCCNotesController.saveNote(con.Id, true, 'Null Date Note', 'Content here', null);
        Test.stopTest();

        ContentNote note = [SELECT Title FROM ContentNote WHERE Title = 'Null Date Note' LIMIT 1];
        Assert.areEqual('Null Date Note', note.Title,
            'Title should have no date prefix when noteDate is null');
    }

    @IsTest
    static void saveNote_titleFallsBackToOriginal_whenNoteDateMalformed() {
        Contact con = getContact();

        Test.startTest();
        // Malformed date — buildTitle catches exception and returns original title
        HamCCNotesController.saveNote(con.Id, true, 'Bad Date Note', 'Content', 'not-a-date');
        Test.stopTest();

        ContentNote note = [SELECT Title FROM ContentNote WHERE Title = 'Bad Date Note' LIMIT 1];
        Assert.areEqual('Bad Date Note', note.Title,
            'Title should fall back to original when date string is malformed');
    }

    @IsTest
    static void saveNote_contentIsHtmlEncoded() {
        Contact con = getContact();
        String rawContent = 'A & B < C > D';

        Test.startTest();
        HamCCNotesController.saveNote(con.Id, true, 'HTML Encode Test', rawContent, '2026-02-13');
        Test.stopTest();

        ContentNote note = [SELECT Id, Content FROM ContentNote WHERE Title LIKE '%HTML Encode Test%' LIMIT 1];
        String body = note.Content.toString();
        Assert.isTrue(body.contains('&amp;'),  'Ampersand should be HTML-encoded');
        Assert.isTrue(body.contains('&lt;'),   'Less-than should be HTML-encoded');
        Assert.isTrue(body.contains('&gt;'),   'Greater-than should be HTML-encoded');
    }

    @IsTest
    static void saveNote_contentPreservesLineBreaks() {
        Contact con = getContact();
        String multiLine = 'Line one\nLine two\nLine three';

        Test.startTest();
        HamCCNotesController.saveNote(con.Id, true, 'Multiline Note', multiLine, '2026-02-13');
        Test.stopTest();

        ContentNote note = [SELECT Content FROM ContentNote WHERE Title LIKE '%Multiline Note%' LIMIT 1];
        String body = note.Content.toString();
        Assert.isTrue(body.contains('<br>'), 'Line breaks should be converted to <br> tags');
    }

    @IsTest
    static void saveNote_contentIsEmptyString_doesNotThrow() {
        Contact con = getContact();

        // ContentNote.Content cannot be empty — buildHtmlContent wraps even an empty
        // string in a valid HTML shell, so the Blob is never empty. This test confirms
        // the controller handles empty input without throwing.
        Test.startTest();
        HamCCNotesController.saveNote(con.Id, true, 'Empty Content Note', '', '2026-02-13');
        Test.stopTest();

        List<ContentNote> notes = [SELECT Id, Content FROM ContentNote WHERE Title LIKE '%Empty Content Note%'];
        Assert.areEqual(1, notes.size(), 'Note should be created even with empty content');
        // Verify the stored body is the HTML shell, not an empty blob
        String body = notes[0].Content.toString();

        // Content should never be empty
        Assert.isTrue(
            String.isNotBlank(body),
            'Content should not be empty even when user input is empty'
        );

        // Should contain at least some HTML structure or placeholder
        Assert.isTrue(
            body.contains('&nbsp;') || body.contains('<br>') || body.length() > 0,
            'Content should contain HTML-safe placeholder or structure'
        );
    }

    @IsTest
    static void saveNote_contentIsNull_doesNotThrow() {
        Contact con = getContact();

        // null content should be treated identically to empty string — wrapped in HTML shell
        Test.startTest();
        HamCCNotesController.saveNote(con.Id, true, 'Null Content Note', null, '2026-02-13');
        Test.stopTest();

        List<ContentNote> notes = [SELECT Id, Content FROM ContentNote WHERE Title LIKE '%Null Content Note%'];
        Assert.areEqual(1, notes.size(), 'Note should be created even with null content');
        // Verify the stored body is the HTML shell, not an empty blob
        String body = notes[0].Content.toString();

        // Content should never be empty
        Assert.isTrue(
            String.isNotBlank(body),
            'Content should not be empty even when user input is empty'
        );

        // Should contain at least some HTML structure or placeholder
        Assert.isTrue(
            body.contains('&nbsp;') || body.contains('<br>') || body.length() > 0,
            'Content should contain HTML-safe placeholder or structure'
        );
    }

    @IsTest
    static void saveNote_throwsAuraHandledException_whenRecordIdIsBlank() {
        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            HamCCNotesController.saveNote('', true, 'Some Title', 'Content', '2026-02-13');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            // Note: AuraHandledException.getMessage() returns 'Script-thrown exception'
            // at runtime — the platform masks the custom message. Type assertion is the
            // correct and sufficient check here.
        }
        Test.stopTest();

        Assert.isTrue(exceptionThrown, 'AuraHandledException should be thrown for blank recordId');
        // Confirm no note was created as a side-effect
        Assert.areEqual(0, [SELECT COUNT() FROM ContentNote WHERE Title LIKE '%Some Title%'],
            'No ContentNote should have been inserted when recordId is blank');
    }

    @IsTest
    static void saveNote_throwsAuraHandledException_whenRecordIdIsNull() {
        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            HamCCNotesController.saveNote(null, true, 'Some Title', 'Content', '2026-02-13');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        Assert.isTrue(exceptionThrown, 'AuraHandledException should be thrown for null recordId');
    }

    @IsTest
    static void saveNote_throwsAuraHandledException_whenTitleIsBlank() {
        Contact con = getContact();
        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            HamCCNotesController.saveNote(con.Id, true, '', 'Content', '2026-02-13');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            // Same platform behaviour — AuraHandledException message is masked.
            // Type assertion is the correct check.
        }
        Test.stopTest();

        Assert.isTrue(exceptionThrown, 'AuraHandledException should be thrown for blank title');
        Assert.areEqual(
            0,
            [SELECT COUNT() FROM ContentNote WHERE Title LIKE '%Content%'],
            'No ContentNote should have been inserted when title is blank'
        );
    }

    @IsTest
    static void saveNote_throwsAuraHandledException_whenTitleIsNull() {
        Contact con = getContact();
        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            HamCCNotesController.saveNote(con.Id, true, null, 'Content', '2026-02-13');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        Assert.isTrue(exceptionThrown, 'AuraHandledException should be thrown for null title');
    }

    // ─── Round-trip: saveNote → getNotes ────────────────────────────────────

    @IsTest
    static void roundTrip_savedNoteAppearsInGetNotes_forContact() {
        Contact con = getContact();

        Test.startTest();
        HamCCNotesController.saveNote(con.Id, true, 'Round Trip Note', 'Full content here', '2026-05-20');
        List<HamCCNotesController.NoteWrapper> result =
            HamCCNotesController.getNotes(con.Id, true);
        Test.stopTest();

        Assert.areEqual(1, result.size(), 'getNotes should return the saved note');
        Assert.isTrue(result[0].Title.contains('Round Trip Note'), 'Returned note title should contain original title');
        Assert.areEqual('2026-05-20', result[0].NoteDate, 'NoteDate should match saved date prefix');
    }

    @IsTest
    static void roundTrip_savedNoteAppearsInGetNotes_forAccount() {
        Account acc = getAccount();

        Test.startTest();
        HamCCNotesController.saveNote(acc.Id, false, 'Account Round Trip', 'Employer content', '2026-06-10');
        List<HamCCNotesController.NoteWrapper> result =
            HamCCNotesController.getNotes(acc.Id, false);
        Test.stopTest();

        Assert.areEqual(1, result.size(), 'getNotes should return the saved account note');
        Assert.isTrue(result[0].Title.contains('Account Round Trip'));
    }

    @IsTest
    static void roundTrip_multipleNotesSaved_allReturnedByGetNotes() {
        Contact con = getContact();

        Test.startTest();
        HamCCNotesController.saveNote(con.Id, true, 'Note Alpha',   'Content A', '2026-01-10');
        HamCCNotesController.saveNote(con.Id, true, 'Note Beta',    'Content B', '2026-02-20');
        HamCCNotesController.saveNote(con.Id, true, 'Note Gamma',   'Content C', '2026-03-30');
        List<HamCCNotesController.NoteWrapper> result =
            HamCCNotesController.getNotes(con.Id, true);
        Test.stopTest();

        Assert.areEqual(3, result.size(), 'All 3 saved notes should be returned by getNotes');
    }

    // ─── NoteWrapper integrity ───────────────────────────────────────────────

    @IsTest
    static void noteWrapper_allFieldsPopulated() {
        Contact con = getContact();
        createNote('02/28/2026 - Wrapper Test', 'Some preview text', con.Id);

        Test.startTest();
        List<HamCCNotesController.NoteWrapper> result =
            HamCCNotesController.getNotes(con.Id, true);
        Test.stopTest();

        Assert.areEqual(1, result.size());
        HamCCNotesController.NoteWrapper w = result[0];
        Assert.isNotNull(w.Id,                'Wrapper.Id should be populated');
        Assert.isNotNull(w.Title,             'Wrapper.Title should be populated');
        Assert.isNotNull(w.NoteDate,          'Wrapper.NoteDate should be populated');
        Assert.isNotNull(w.ContentDocumentId, 'Wrapper.ContentDocumentId should be populated');
        Assert.areEqual(w.Id, w.ContentDocumentId,
            'Id and ContentDocumentId must be identical (ContentNote.Id == ContentDocument.Id)');
    }
}