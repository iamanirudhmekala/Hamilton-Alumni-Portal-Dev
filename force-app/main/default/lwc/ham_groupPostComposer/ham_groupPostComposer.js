import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { deleteRecord } from 'lightning/uiRecordApi';
import createPosts from '@salesforce/apex/Ham_GroupsController.createPosts';
import searchTags from '@salesforce/apex/Ham_GroupsController.searchTags';
import searchGroupMembersForMention from '@salesforce/apex/Ham_GroupsController.searchGroupMembersForMention';
import createDraftPost from '@salesforce/apex/Ham_GroupsController.createDraftPost';
import publishDraftPost from '@salesforce/apex/Ham_GroupsController.publishDraftPost';
import discardDraftPost from '@salesforce/apex/Ham_GroupsController.discardDraftPost';

const DEBOUNCE_MS = 300;
const MENTION_TRIGGER_REGEX = /@([\w' -]{0,40})$/;

// Document/image formats accepted by the post uploader. Video formats are deliberately
// excluded (here and as a server-side backstop in HAM_ContentDocumentLinkHandler) so
// large video files don't consume org file storage â€” members embed YouTube/Vimeo links.
const DOC_FORMATS = ['.pdf', '.doc', '.docx', '.ppt', '.pptx', '.xls', '.xlsx', '.csv',
    '.txt', '.rtf', '.zip', '.jpg', '.jpeg', '.png', '.gif', '.webp', '.heic'];
const IMAGE_FORMATS = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.heic'];
const IMAGE_EXT = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic'];
 

export default class Ham_groupPostComposer extends LightningElement {

      // Parent HAM_Group__c Id. Settable in Experience Builder, or falls back to
    // recordId when the component sits on a Group record page.
    @api groupId;
    @api userContactId;
    @api recordId;
    @api placeholder = 'Share something with the group...';
    @api hideHeader = false;
    @api groupIcons = {};

    _isOverride = false;
    @api
    get isOverride() {
        return this._isOverride;
    }
    set isOverride(value) {
        this._isOverride = (value === true || value === 'true');
    }

    _isdiscussiontab = false;
    @api
    get isdiscussiontab() {
        return this._isdiscussiontab;
    }
    set isdiscussiontab(value) {
        this._isdiscussiontab = (value === true || value === 'true');
    }
 
    @track tags = [];
    @track tagSuggestions = [];
    @track files = [];          // uploaded files: { name, documentId, isImage }
    @track mentionSuggestions = [];
    @track pendingMentions = []; // [{contactId, name}] — people @mentioned in the body

    // Draft post backing large-file uploads. Created lazily the first time the user
    // attaches a file, published (Is_Draft__c = false) when the post is submitted.
    draftPostId = null;
    isPreparingUpload = false;
    showUploader = false;
    uploaderAccept = DOC_FORMATS;

    body = '';
    isAnonymous = false;
    isPosting = false;

    showTagInput = false;
    showLinkInput = false;
    tagSearchTerm = '';
    linkUrl = '';
 
    statusMessage = '';
    statusVariant = ''; // 'success' | 'error'

    _debounceTimer;
    _statusTimer;
 
    // ---- derived ----
    get effectiveGroupId() {
        return this.groupId || this.recordId;
    }
    get showHeader() {
        return !this.hideHeader;
    }
    get rootClass() {
        return `composer ${this.isOverride ? 'kirkland-override' : ''} ${this.isdiscussiontab ? 'composer--wide' : ''}`;
    }
    get hasTags() {
        return this.tags.length > 0;
    }
    get hasFiles() {
        return this.files.length > 0;
    }
    get hasSuggestions() {
        return this.tagSuggestions.length > 0;
    }
    get tagsString() {
        return this.tags.join(',');
    }
    get hasMentionSuggestions() {
        return this.mentionSuggestions.length > 0;
    }
    get mentionedContactIdsString() {
        return this.pendingMentions.map((m) => m.contactId).join(',');
    }
    get canPost() {
        return !this.isPosting && (this.body.trim() !== '' || this.files.length > 0);
    }
    get postLabel() {
        return this.isPosting ? 'Postingâ€¦' : 'Post';
    }
    get statusClass() {
        return `composer__status composer__status--${this.statusVariant}`;
    }
 
    // ---- body ----
    handleBodyInput(event) {
        this.body = event.target.value;
        this.detectMentionTrigger(event.target);
    }

    // ---- @mentions (inline, detected while typing in the body) ----
    detectMentionTrigger(textareaEl) {
        const cursorPos = textareaEl.selectionStart;
        const match = this.body.substring(0, cursorPos).match(MENTION_TRIGGER_REGEX);

        if (!match) {
            this.mentionSuggestions = [];
            return;
        }
        this._mentionTriggerStart = cursorPos - match[0].length;
        this._mentionTriggerEnd = cursorPos;

        const term = match[1].trim();
        if (term === '') {
            this.mentionSuggestions = [];
            return;
        }

        clearTimeout(this._mentionDebounceTimer);
        const queryToken = (this._mentionQueryToken || 0) + 1;
        this._mentionQueryToken = queryToken;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._mentionDebounceTimer = setTimeout(() => {
            searchGroupMembersForMention({ groupId: this.effectiveGroupId, searchTerm: term })
                .then((res) => {
                    if (queryToken !== this._mentionQueryToken) return; // stale response
                    const already = new Set(this.pendingMentions.map((m) => m.contactId));
                    this.mentionSuggestions = (res || []).filter((s) => !already.has(s.contactId));
                })
                .catch(() => {
                    this.mentionSuggestions = [];
                });
        }, DEBOUNCE_MS);
    }

    handleSelectMentionSuggestion(event) {
        const contactId = event.currentTarget.dataset.contactId;
        const name = event.currentTarget.dataset.name;

        const before = this.body.substring(0, this._mentionTriggerStart);
        const after = this.body.substring(this._mentionTriggerEnd);
        const insertion = `@${name} `;
        const newBody = `${before}${insertion}${after}`;
        this.body = newBody;
        this.mentionSuggestions = [];
        if (!this.pendingMentions.some((m) => m.contactId === contactId)) {
            this.pendingMentions = [...this.pendingMentions, { contactId, name }];
        }

        const newCursorPos = before.length + insertion.length;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            const textarea = this.template.querySelector('.composer__textarea');
            if (textarea) {
                // The value={body} binding doesn't repaint a native textarea once the
                // user has typed in it (same reason resetForm clears it imperatively),
                // so write the DOM value directly before restoring the cursor.
                textarea.value = newBody;
                textarea.focus();
                textarea.setSelectionRange(newCursorPos, newCursorPos);
            }
        }, 0);
    }

    // ---- header pop-out ----
    handleExpand() {
        // Lets a parent open the full discussion thread / a modal feed.
        this.dispatchEvent(
            new CustomEvent('expand', { bubbles: true, composed: true })
        );
    }
 
    // ---- toolbar toggles ----
    toggleTagInput() {
        this.showTagInput = !this.showTagInput;
        if (this.showTagInput) {
            this.showLinkInput = false;
            // focus the tag input on next tick
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => {
                const el = this.template.querySelector('.tagbox__input');
                if (el) {
                    el.focus();
                }
            }, 0);
        }
    }
    toggleLinkInput() {
        this.showLinkInput = !this.showLinkInput;
        if (this.showLinkInput) {
            this.showTagInput = false;
        }
    }
 
    // ---- tags ----
    handleTagInput(event) {
        this.tagSearchTerm = event.target.value;
        const term = this.tagSearchTerm.trim();
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        clearTimeout(this._debounceTimer);
        if (term === '') {
            this.tagSuggestions = [];
            return;
        }
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._debounceTimer = setTimeout(() => {
            searchTags({ searchTerm: term })
                .then((res) => {
                    // hide tags already chosen
                    const chosen = new Set(this.tags.map((t) => t.toLowerCase()));
                    this.tagSuggestions = (res || []).filter(
                        (s) => !chosen.has(s.toLowerCase())
                    );
                })
                .catch(() => {
                    this.tagSuggestions = [];
                });
        }, DEBOUNCE_MS);
    }
 
    handleTagKeydown(event) {
        if (event.key === 'Enter') {
            event.preventDefault();
            this.addTag(this.tagSearchTerm);
        } else if (event.key === 'Backspace' && this.tagSearchTerm === '' && this.hasTags) {
            // remove last chip on backspace in empty input
            this.tags = this.tags.slice(0, -1);
        }
    }
 
    handleSelectSuggestion(event) {
        this.addTag(event.currentTarget.dataset.tag);
    }
 
    addTag(value) {
        const v = (value || '').trim();
        if (v === '') {
            return;
        }
        const exists = this.tags.some((t) => t.toLowerCase() === v.toLowerCase());
        if (!exists) {
            this.tags = [...this.tags, v];
        }
        this.tagSearchTerm = '';
        this.tagSuggestions = [];
    }
 
    handleRemoveTag(event) {
        const tag = event.currentTarget.dataset.tag;
        this.tags = this.tags.filter((t) => t !== tag);
    }
 
    // ---- links ----
    handleLinkInput(event) {
        this.linkUrl = event.target.value;
    }
    handleInsertLink() {
        const url = this.linkUrl.trim();
        if (url === '') {
            return;
        }
        const prefix = this.body && !this.body.endsWith('\n') && this.body !== '' ? '\n' : '';
        this.body = `${this.body}${prefix}${url}`;
        this.linkUrl = '';
        this.showLinkInput = false;
    }
 
    // ---- files (lightning-file-upload via lazy draft post) ----
    get acceptedFormats() {
        return this.uploaderAccept;
    }

    handleAttachClick() {
        this.uploaderAccept = DOC_FORMATS;
        this.revealUploader();
    }

    handleImageClick() {
        this.uploaderAccept = IMAGE_FORMATS;
        this.revealUploader();
    }

    // A draft post must exist before lightning-file-upload can attach ContentVersions
    // to it. Create it lazily on first attach so we don't leave orphan drafts for users
    // who open the composer but never attach anything.
    revealUploader() {
        if (this.draftPostId) {
            this.showUploader = true;
            return;
        }
        if (this.isPreparingUpload) {
            return;
        }
        this.isPreparingUpload = true;
        createDraftPost({ groupId: this.effectiveGroupId, currentContactId: this.userContactId })
            .then((draftId) => {
                this.draftPostId = draftId;
                this.showUploader = true;
            })
            .catch((error) => {
                this.setStatus(this.reduceError(error), 'error');
            })
            .finally(() => {
                this.isPreparingUpload = false;
            });
    }
 
    handleUploadFinished(event) {
        const uploaded = event.detail.files || [];
        const added = uploaded.map((f) => ({
            name: f.name,
            documentId: f.documentId,
            isImage: IMAGE_EXT.includes((f.name.split('.').pop() || '').toLowerCase())
        }));
        this.files = [...this.files, ...added];
        this.showUploader = false;
    }

    handleRemoveFile(event) {
        const documentId = event.currentTarget.dataset.id;
        if (!documentId) {
            return;
        }
        // Remove the underlying file so abandoned attachments don't linger in storage
        deleteRecord(documentId)
            .then(() => {
                this.files = this.files.filter((f) => f.documentId !== documentId);
            })
            .catch((error) => {
                this.setStatus(this.reduceError(error), 'error');
            });
    }
 
    // ---- anonymous ----
    handleAnonChange(event) {
        this.isAnonymous = event.target.checked;
    }
 
    // ---- submit ----
    handlePost() {
        if (!this.canPost) {
            if (this.body.trim() === '' && this.files.length === 0) {
                this.setStatus('Add some text or an attachment before posting.', 'error');
            }
            return;
        }
        this.isPosting = true;
        this.statusMessage = '';

        // Two paths: if files were attached, a draft post already holds them — just
        // publish it. Otherwise create a fresh text-only post.
        const submission = this.draftPostId
            ? publishDraftPost({
                  postId: this.draftPostId,
                  body: this.body,
                  tags: this.tagsString,
                  isAnonymous: this.isAnonymous,
                  currentContactId: this.userContactId,
                  mentionedContactIds: this.mentionedContactIdsString
              }).then((post) => post.Id)
            : createPosts({
                  newPosts: [{
                      Body__c: this.body,
                      Tags__c: this.tagsString,
                      Is_Anonymous__c: this.isAnonymous,
                      Group__c: this.effectiveGroupId,
                      Mentioned_Contact_Ids__c: this.mentionedContactIdsString
                  }],
                  currentContactId: this.userContactId
              }).then((results) => {
                  if (!results || results.length === 0) {
                      throw new Error('Post creation failed on server.');
                  }
                  return results[0].Id;
              });

        submission
            .then((postId) => {
                this.draftPostId = null; // draft is now a published post
                this.notify('Success', 'Your post has been published.', 'success');
                this.setStatus('Your post has been published.', 'success');
                this.dispatchEvent(
                    new CustomEvent('postcreated', {
                        detail: { postId },
                        bubbles: true,
                        composed: true
                    })
                );
                this.resetForm();
            })
            .catch((error) => {
                const msg = this.reduceError(error);
                this.notify('Could not post', msg, 'error');
                this.setStatus(msg, 'error');
            })
            .finally(() => {
                this.isPosting = false;
            });
    }

    resetForm() {
        this.body = '';
        this.tags = [];
        this.files = [];
        this.pendingMentions = [];
        this.mentionSuggestions = [];
        this.isAnonymous = false;
        this.tagSearchTerm = '';
        this.tagSuggestions = [];
        this.showTagInput = false;
        this.showLinkInput = false;
        this.showUploader = false;
        const textarea = this.template.querySelector('.composer__textarea');
        if (textarea) {
            textarea.value = '';
        }
    }

    // Clean up an unpublished draft (and its uploaded files cascade) if the user
    // navigates away after attaching files but without posting.
    disconnectedCallback() {
        if (this.draftPostId) {
            discardDraftPost({ postId: this.draftPostId, currentContactId: this.userContactId })
                .catch(() => { /* best-effort cleanup */ });
        }
    }
 
    setStatus(message, variant) {
        this.statusMessage = message;
        this.statusVariant = variant;

        // Clear any pending auto-dismiss from a previous message
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        clearTimeout(this._statusTimer);

        // Success confirmations disappear on their own after a few seconds; errors
        // stay put so the user can actually read them (they can still close manually).
        if (variant === 'success') {
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            this._statusTimer = setTimeout(() => {
                this.dismissStatus();
            }, 4000);
        }
    }

    // Manual close for the status banner (× button)
    dismissStatus() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        clearTimeout(this._statusTimer);
        this.statusMessage = '';
        this.statusVariant = '';
    }
 
    notify(title, message, variant) {
        // Works on standard Lightning pages; harmless in LWR (status banner is the
        // reliable in-site fallback).
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant })
        );
    }
 
    reduceError(error) {
        if (Array.isArray(error?.body)) {
            return error.body.map((e) => e.message).join(', ');
        }
        if (error?.body?.message) {
            return error.body.message;
        }
        return error?.message || 'Unexpected error. Please try again.';
    }
}