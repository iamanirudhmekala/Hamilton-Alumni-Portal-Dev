/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : HAMFilePublisherController
 * Author          : Ameya
 * Created Date    : Jul 15, 2026
 * Last Modified By: Ameya
 * Last Modified On: Jul 15, 2026
 * Description     : Supports the "Publish Profile Picture" LWC placed on the ContentDocument
 *                   (File) record page. recordId on that page is the ContentDocument Id, so
 *                   this controller resolves the linked Contact server-side rather than
 *                   trusting a Contact Id passed from the client.
 *
 *                   Flow:
 *                    1. getFileContext(contentDocumentId)      -> file details + the single linked Contact
 *                    2. publishProfilePicture(contentDocumentId) -> copies the File's latest content into a
 *                                                                   classic public Document (015), builds a
 *                                                                   servlet.ImageServer URL from that Document's
 *                                                                   Id + Org Id, and writes it to the linked
 *                                                                   Contact's HAM_Profile_Picture_URL__c.
 *                                                                   HAM_Profile_Picture__c (a formula field)
 *                                                                   recalculates automatically from that URL.
 *
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Jul 15, 2026  │ Ameya        │ Initial version
 *  Jul 15, 2026  │ Ameya        │ Prefer DistributionPublicUrl over ContentDownloadUrl so
 *                │              │ the published link displays inline instead of forcing download
 *  Jul 15, 2026  │ Ameya        │ Replaced ContentDistribution public link with a
 *                │              │ servlet.ImageServer URL (id=ContentVersionId, oid=OrgId), built
 *                │              │ synchronously — no more async polling needed
 *  Jul 15, 2026  │ Ameya        │ Switched id= to a classic public Document (015 prefix), created/
 *                │              │ refreshed from the File's content on each Publish, since the
 *                │              │ ContentVersion Id did not produce a true public (unauthenticated) link
 *  Jul 15, 2026  │ Ameya        │ Renamed target folder to "HAM HQ Profile Pictures"; fixed
 *                │              │ AuraHandledException messages not surfacing (setMessage() quirk);
 *                │              │ added server-side image-type guard in publishProfilePicture
 *  Jul 15, 2026  │ Ameya        │ Added @TestVisible simulateMissingFolderForTests flag — Folder
 *                │              │ doesn't support DML, so tests can't create/delete one to exercise
 *                │              │ the missing-folder path against real data
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */
public with sharing class HAMFilePublisherController {

    // Classic Documents-tab folder that houses the generated public Document records.
    // Must be created in advance under Setup/Documents by an admin.
    private static final String PROFILE_PICTURE_FOLDER_NAME = 'HAM HQ Profile Pictures';
    private static Id cachedFolderId;

    // Folder does not support DML (insert/update/delete) via Apex, so tests can't create one to
    // exercise the "folder missing" path against real data. This flag lets a test force that
    // branch deterministically without depending on the absence of real org data.
    @TestVisible
    private static Boolean simulateMissingFolderForTests = false;

    private static final Set<String> IMAGE_EXTENSIONS = new Set<String>{
        'jpg', 'jpeg', 'png', 'gif', 'bmp'
    };

    public class FileContext {
        @AuraEnabled public String contentDocumentId;
        @AuraEnabled public String contentVersionId;
        @AuraEnabled public String title;
        @AuraEnabled public String fileExtension;
        @AuraEnabled public Boolean isImage;
        @AuraEnabled public String contactId;
        @AuraEnabled public String contactName;
        @AuraEnabled public Integer linkedContactCount;
    }

    @AuraEnabled(cacheable=true)
    public static FileContext getFileContext(Id contentDocumentId) {
        ContentVersion cv = [
            SELECT Id, Title, FileExtension
            FROM ContentVersion
            WHERE ContentDocumentId = :contentDocumentId AND IsLatest = true
            LIMIT 1
        ];

        List<Contact> linkedContacts = getLinkedContacts(contentDocumentId);

        FileContext ctx = new FileContext();
        ctx.contentDocumentId = contentDocumentId;
        ctx.contentVersionId = cv.Id;
        ctx.title = cv.Title;
        ctx.fileExtension = cv.FileExtension;
        ctx.isImage = cv.FileExtension != null
            && IMAGE_EXTENSIONS.contains(cv.FileExtension.toLowerCase());
        ctx.linkedContactCount = linkedContacts.size();
        if (linkedContacts.size() == 1) {
            ctx.contactId = linkedContacts[0].Id;
            ctx.contactName = linkedContacts[0].Name;
        }
        return ctx;
    }

    /**
     * NOTE: HAM_Profile_Picture__c is a FORMULA field
     * (IF(ISBLANK(HAM_Profile_Picture_URL__c), null, HYPERLINK(HAM_Profile_Picture_URL__c,
     *     IMAGE(HAM_Profile_Picture_URL__c, ucinn_ascendv2__Full_Name_Formula__c, 90, -1))))
     * so it is read-only from Apex and recalculates automatically whenever
     * HAM_Profile_Picture_URL__c changes. We only ever need to write the raw URL.
     *
     * The linked Contact is resolved server-side from contentDocumentId rather than
     * accepted as a parameter, so the client can't direct the write to an arbitrary Contact.
     */
    @AuraEnabled
    public static String publishProfilePicture(Id contentDocumentId) {
        List<Contact> linkedContacts = getLinkedContacts(contentDocumentId);
        if (linkedContacts.isEmpty()) {
            throw newAuraException('This file is not linked to any Contact. Attach it to the Contact record before publishing.');
        }
        if (linkedContacts.size() > 1) {
            throw newAuraException('This file is linked to more than one Contact (' + linkedContacts.size()
                + '). Remove the extra relationship(s) before publishing, so the correct Contact is unambiguous.');
        }

        ContentVersion cv = [
            SELECT Id, Title, FileExtension, VersionData
            FROM ContentVersion
            WHERE ContentDocumentId = :contentDocumentId AND IsLatest = true
            LIMIT 1
        ];

        if (cv.FileExtension == null || !IMAGE_EXTENSIONS.contains(cv.FileExtension.toLowerCase())) {
            // Defense-in-depth: the LWC already disables Publish for non-image files, but this
            // method is @AuraEnabled and could be invoked directly, bypassing that UI guard.
            throw newAuraException('This file type is not supported as a profile picture. Please choose an image file (jpg, jpeg, png, gif, or bmp).');
        }

        Id publicDocumentId = upsertPublicDocument(contentDocumentId, cv);
        String publicUrl = buildImageServerUrl(publicDocumentId);

        Contact con = new Contact(Id = linkedContacts[0].Id);
        con.HAM_Profile_Picture_URL__c = publicUrl;
        update con;

        return publicUrl;
    }

    /**
     * Creates (or refreshes) a classic public Document from the File's latest content.
     * A deterministic Name keyed off the ContentDocumentId lets repeat Publish clicks on the
     * same File update the existing Document instead of piling up duplicates.
     */
    private static Id upsertPublicDocument(Id contentDocumentId, ContentVersion cv) {
        Id folderId = getProfilePictureFolderId();
        String docName = buildDocumentName(contentDocumentId, cv.FileExtension);

        List<Document> existing = [
            SELECT Id
            FROM Document
            WHERE Name = :docName AND FolderId = :folderId
            LIMIT 1
        ];

        Document doc = existing.isEmpty() ? new Document() : existing[0];
        doc.Name = docName;
        doc.FolderId = folderId;
        doc.Body = cv.VersionData;
        doc.IsPublic = true;
        doc.Description = 'Auto-generated public copy of File ' + contentDocumentId
            + ' (' + cv.Title + ') for HAM_Profile_Picture_URL__c. Do not edit manually.';

        upsert doc;
        return doc.Id;
    }

    private static String buildDocumentName(Id contentDocumentId, String fileExtension) {
        String ext = String.isNotBlank(fileExtension) ? fileExtension.toLowerCase() : 'jpg';
        // Stable, unique name keyed on the source ContentDocumentId so re-publishing updates
        // the same Document rather than creating a new one each time.
        return 'ham_profile_' + contentDocumentId + '.' + ext;
    }

    private static Id getProfilePictureFolderId() {
        if (cachedFolderId != null) {
            return cachedFolderId;
        }
        if (!simulateMissingFolderForTests) {
            List<Folder> folders = [
                SELECT Id
                FROM Folder
                WHERE Name = :PROFILE_PICTURE_FOLDER_NAME AND Type = 'Document'
                LIMIT 1
            ];
            if (!folders.isEmpty()) {
                cachedFolderId = folders[0].Id;
                return cachedFolderId;
            }
        }
        throw newAuraException('No Document folder named "' + PROFILE_PICTURE_FOLDER_NAME
            + '" was found. Ask an admin to create it under the classic Documents tab before publishing.');
    }

    /**
     * Builds a URL of the form:
     * https://<my domain>/servlet/servlet.ImageServer?id=<DocumentId>&oid=<OrgId>
     */
    private static String buildImageServerUrl(Id documentId) {
        String orgId = UserInfo.getOrganizationId();
        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        return baseUrl + '/servlet/servlet.ImageServer?id=' + documentId + '&oid=' + orgId;
    }

    /**
     * AuraHandledException.getMessage() returns a generic "Script-thrown exception" instead of
     * the constructor argument unless setMessage() is called explicitly — a well-known platform
     * quirk. This helper avoids that so callers (and tests) see the real message.
     */
    private static AuraHandledException newAuraException(String message) {
        AuraHandledException ex = new AuraHandledException(message);
        ex.setMessage(message);
        return ex;
    }

    private static List<Contact> getLinkedContacts(Id contentDocumentId) {
        String contactPrefix = Contact.SObjectType.getDescribe().getKeyPrefix();

        Set<Id> contactIds = new Set<Id>();
        for (ContentDocumentLink cdl : [
            SELECT LinkedEntityId
            FROM ContentDocumentLink
            WHERE ContentDocumentId = :contentDocumentId
        ]) {
            if (String.valueOf(cdl.LinkedEntityId).startsWith(contactPrefix)) {
                contactIds.add(cdl.LinkedEntityId);
            }
        }

        if (contactIds.isEmpty()) {
            return new List<Contact>();
        }

        return [SELECT Id, Name FROM Contact WHERE Id IN :contactIds];
    }
}