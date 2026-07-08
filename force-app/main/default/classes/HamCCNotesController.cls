/**
 * HamCCNotesController
 * 
 * Serves the hamCCNotes LWC.
 * - getNotes  : fetches ContentNote records linked to a Contact or Account
 * - saveNote  : creates a new ContentNote and links it via ContentDocumentLink
 * 
 * Standard Notes in Salesforce are stored as ContentNote (a subtype of
 * ContentDocument). The link between a Note and a record is a
 * ContentDocumentLink where LinkedEntityId = the parent record Id.
 *
 * NoteDate is a custom field pattern: Notes don't natively carry a separate
 * "date" field beyond CreatedDate/LastModifiedDate. We store the user-supplied
 * date in the Note Title prefix OR as a convention. For a cleaner UX we use
 * a custom approach: store date as the first line of Content (structured) and
 * expose it back. Alternatively, if your org has a custom field on
 * ContentNote (ContentNote is not extensible with custom fields in standard
 * Salesforce), we fall back to CreatedDate.
 *
 * RECOMMENDATION: Use CreatedDate as the display date and allow users to
 * embed dates in the Title (e.g., "02/13/2026 - Alumni Meeting") matching
 * the historical format you described. The "Date" picker on the modal sets
 * a date prefix in the Title automatically.
 */
public without sharing class HamCCNotesController {

    // ─── Data Transfer Object ────────────────────────────────────────────────

    public class NoteWrapper {
        @AuraEnabled public String Id;
        @AuraEnabled public String Title;
        @AuraEnabled public String TextPreview;   // First 255 chars, plain text
        @AuraEnabled public String NoteDate;      // ISO date string YYYY-MM-DD
        @AuraEnabled public String ContentDocumentId;
    }

    // ─── getNotes ────────────────────────────────────────────────────────────

    /**
     * Retrieves all Notes linked to the given record.
     * @param recordId  Contact Id (isAlumni=true) or Account Id (isAlumni=false)
     * @param isAlumni  Determines whether the record is a Contact or Account
     */
    @AuraEnabled(cacheable=true)
    public static List<NoteWrapper> getNotes(String recordId, Boolean isAlumni) {
        if (String.isBlank(recordId)) return new List<NoteWrapper>();

        // Step 1: Get all ContentDocumentIds linked to this record
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId
            ORDER BY SystemModstamp DESC
        ];

        if (links.isEmpty()) return new List<NoteWrapper>();

        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink cdl : links) {
            docIds.add(cdl.ContentDocumentId);
        }

        // Step 2: Query ContentNote (FileType = 'SNOTE') for those IDs
        // ContentNote.Id = ContentDocument.Id (same record, different object view)
        List<ContentNote> notes = [
            SELECT Id, Title, TextPreview, CreatedDate, LastModifiedDate
            FROM ContentNote
            WHERE Id IN :docIds
            ORDER BY CreatedDate DESC
        ];

        // Step 3: Map to wrapper
        List<NoteWrapper> wrappers = new List<NoteWrapper>();
        for (ContentNote cn : notes) {
            NoteWrapper w = new NoteWrapper();
            w.Id                = cn.Id;
            w.Title             = cn.Title;
            w.TextPreview       = cn.TextPreview;
            w.ContentDocumentId = cn.Id; // ContentNote.Id IS the ContentDocument.Id
            // Extract date from Title if prefixed (format: MM/DD/YYYY - ...) else use CreatedDate
            w.NoteDate          = extractDateFromNote(cn.Title, cn.CreatedDate);
            wrappers.add(w);
        }

        return wrappers;
    }

    // ─── saveNote ────────────────────────────────────────────────────────────

    /**
     * Creates a new ContentNote and links it to the given record.
     * The user-supplied date is embedded as a prefix in the title and
     * as the first line of the note content to support historical format.
     *
     * @param recordId  Contact or Account Id
     * @param isAlumni  Determines record type (used for validation/logging)
     * @param title     Note title entered by the user
     * @param content   Note body text
     * @param noteDate  ISO date string (YYYY-MM-DD) from the date picker
     */
    @AuraEnabled
    public static void saveNote(
        String recordId,
        Boolean isAlumni,
        String title,
        String content,
        String noteDate
    ) {
        if (String.isBlank(recordId)) {
            throw new AuraHandledException('Record Id is required.');
        }
        if (String.isBlank(title)) {
            throw new AuraHandledException('Title is required.');
        }

        // Format the date prefix for the title (MM/DD/YYYY)
        String datePrefixedTitle = buildTitle(title, noteDate);
        /*
        // Encode content as HTML (ContentNote body must be HTML-encoded)
        String htmlContent = buildHtmlContent(content, noteDate, title);

        // Create the ContentNote
        ContentNote cn = new ContentNote();
        cn.Title   = datePrefixedTitle;
        cn.Content = Blob.valueOf(htmlContent);
        insert cn;
*/
        String htmlContent = buildHtmlContent(content, noteDate, title);

        // FINAL SAFETY NET — guarantees VersionData is never empty
        if (String.isBlank(htmlContent)) {
            htmlContent = '<!DOCTYPE html><html><body>&nbsp;</body></html>';
        }

        Blob noteBlob = Blob.valueOf(htmlContent);

        // Extra guard (defensive, but deployment-safe)
        if (noteBlob == null || noteBlob.size() == 0) {
            noteBlob = Blob.valueOf('<!DOCTYPE html><html><body>&nbsp;</body></html>');
        }

        ContentNote cn = new ContentNote();
        cn.Title   = datePrefixedTitle;
        cn.Content = noteBlob;
        insert cn;

        // Link the note to the parent record
        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = cn.Id;
        cdl.LinkedEntityId    = recordId;
        cdl.ShareType         = 'V'; // Viewer access — standard for notes
        cdl.Visibility        = 'AllUsers';
        insert cdl;
    }

    // ─── Private Helpers ─────────────────────────────────────────────────────

    /**
     * Builds a prefixed title: "MM/DD/YYYY - <user title>"
     * Falls back gracefully if date is blank.
     */
    private static String buildTitle(String title, String noteDate) {
        if (String.isBlank(noteDate)) return title;
        try {
            Date d = Date.valueOf(noteDate); // YYYY-MM-DD → Date
            String formatted = String.valueOf(d.month()).leftPad(2, '0')
                + '/' + String.valueOf(d.day()).leftPad(2, '0')
                + '/' + String.valueOf(d.year());
            return formatted + ' - ' + title;
        } catch (Exception e) {
            return title;
        }
    }

    /**
     * Wraps content in minimal HTML that ContentNote requires.
     * Preserves line breaks by converting \n to <br>.
     */
    private static String buildHtmlContent(String content, String noteDate, String title) {
        String body =  String.isBlank(content) ? '&nbsp;' : content;
        // Escape HTML special chars
        body = body.replace('&', '&amp;')
                   .replace('<', '&lt;')
                   .replace('>', '&gt;')
                   .replace('\n', '<br>');
        return '<!DOCTYPE html><html><body>' + body + '</body></html>';
    }

    /**
     * Attempts to extract a date from the Title prefix (MM/DD/YYYY - ...).
     * Falls back to CreatedDate.
     */
    private static String extractDateFromNote(String title, DateTime createdDate) {
        if (String.isNotBlank(title) && title.length() >= 10) {
            // Try to match MM/DD/YYYY at the start
            String candidate = title.substring(0, 10);
            if (Pattern.matches('\\d{2}/\\d{2}/\\d{4}', candidate)) {
                try {
                    // Convert MM/DD/YYYY → YYYY-MM-DD for consistent ISO sorting
                    List<String> parts = candidate.split('/');
                    return parts[2] + '-' + parts[0] + '-' + parts[1];
                } catch (Exception e) {
                    // Fall through to createdDate
                }
            }
        }
        // Default: use CreatedDate formatted as YYYY-MM-DD
        return createdDate != null
            ? String.valueOf(createdDate.dateGmt())
            : '';
    }
}