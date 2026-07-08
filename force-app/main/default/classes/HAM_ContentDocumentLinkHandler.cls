/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : HAM_ContentDocumentLinkHandler
 * Author          : Sachin Kumar Sharma
 * Created Date    : June 8, 2026
 * Description     : Handler class for ContentDocumentLinkTrigger. Sets Visibility to
 *                   'AllUsers' for attachments linked to HAM_Group_Post__c records, and
 *                   blocks video uploads on those posts to protect org file storage.
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */
public with sharing class HAM_ContentDocumentLinkHandler {

    // Video extensions are blocked on group posts to protect org file storage limits.
    // Members embed YouTube/Vimeo links instead of uploading video files.
    private static final Set<String> BLOCKED_VIDEO_EXTENSIONS = new Set<String>{
        'mp4', 'mov', 'avi', 'wmv', 'flv', 'mkv', 'webm', 'm4v', '3gp', 'mpeg', 'mpg'
    };

    /**
     * @description Executed before insert on ContentDocumentLink. For attachments linked
     *              to HAM_Group_Post__c records: (1) enforces public visibility so all
     *              portal constituents can view them, and (2) blocks video uploads as a
     *              hard server-side backstop regardless of the client-side accept filter.
     * @param links Trigger.new list of ContentDocumentLink.
     */
    public static void handleBeforeInsert(List<ContentDocumentLink> links) {
        if (links == null || links.isEmpty()) {
            return;
        }

        String postPrefix = HAM_Group_Post__c.SObjectType.getDescribe().getKeyPrefix();

        // Collect post-linked document Ids so we can inspect their file types in one query
        Set<Id> postDocumentIds = new Set<Id>();
        for (ContentDocumentLink link : links) {
            if (isPostLink(link, postPrefix)) {
                link.Visibility = 'AllUsers';
                postDocumentIds.add(link.ContentDocumentId);
            }
        }

        if (postDocumentIds.isEmpty()) {
            return;
        }

        // Map each post-linked document to its latest file extension
        Map<Id, String> docExtension = new Map<Id, String>();
        for (ContentVersion cv : [
            SELECT ContentDocumentId, FileExtension
            FROM ContentVersion
            WHERE ContentDocumentId IN :postDocumentIds AND IsLatest = true
        ]) {
            docExtension.put(cv.ContentDocumentId, cv.FileExtension);
        }

        for (ContentDocumentLink link : links) {
            if (!isPostLink(link, postPrefix)) {
                continue;
            }
            String ext = docExtension.get(link.ContentDocumentId);
            if (ext != null && BLOCKED_VIDEO_EXTENSIONS.contains(ext.toLowerCase())) {
                link.addError('Video files cannot be attached to group posts. ' +
                              'Please paste a YouTube or Vimeo link instead.');
            }
        }
    }

    private static Boolean isPostLink(ContentDocumentLink link, String postPrefix) {
        return link.LinkedEntityId != null
            && String.valueOf(link.LinkedEntityId).startsWith(postPrefix);
    }
}