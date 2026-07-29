import { LightningElement, api, track, wire } from 'lwc';
import getGroupFeed from '@salesforce/apex/Ham_GroupsController.getGroupFeed';
import checkForNewPosts from '@salesforce/apex/Ham_GroupsController.checkForNewPosts';
import getPostComments from '@salesforce/apex/Ham_GroupsController.getPostComments';
import createComment from '@salesforce/apex/Ham_GroupsController.createComment';
import updatePost from '@salesforce/apex/Ham_GroupsController.updatePost';
import updateComment from '@salesforce/apex/Ham_GroupsController.updateComment';
import togglePinPost from '@salesforce/apex/Ham_GroupsController.togglePinPost';
import amplifyPost from '@salesforce/apex/Ham_GroupsController.amplifyPost';
import unamplifyPost from '@salesforce/apex/Ham_GroupsController.unamplifyPost';
import deletePost from '@salesforce/apex/Ham_GroupsController.deletePost';
import reportContent from '@salesforce/apex/Ham_GroupsController.reportContent';
import reportUser from '@salesforce/apex/Ham_GroupsController.reportUser';
import bookmarkPost from '@salesforce/apex/Ham_GroupsController.bookmarkPost';
import unbookmarkPost from '@salesforce/apex/Ham_GroupsController.unbookmarkPost';
import getBookmarkedPostIds from '@salesforce/apex/Ham_GroupsController.getBookmarkedPostIds';
import getGroupPostAuthors from '@salesforce/apex/Ham_GroupsController.getGroupPostAuthors';
import searchGroupMembersForMention from '@salesforce/apex/Ham_GroupsController.searchGroupMembersForMention';
import HAM_ICONS from '@salesforce/resourceUrl/HAM_Icons';
// Group-specific icons live in their own resource: HAM_Icons is already over the 5MB
// static-resource cap and can't take new files until its oversized assets are dealt with.
import HAM_GROUP_ICONS from '@salesforce/resourceUrl/HAM_Group_Icons';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
// The site's base path (e.g. "/ex" for this LWR community). Attachment download URLs
// must be prefixed with it — a root-relative "/sfc/servlet.shepherd/..." resolves at the
// domain root, outside the community, and errors out (errorduringprocessing.jsp).
import basePath from '@salesforce/community/basePath';

const INITIAL_INTERVAL = 15000; // 15s
const MAX_INTERVAL = 300000;    // 5m
const MENTION_DEBOUNCE_MS = 300;
const MENTION_TRIGGER_REGEX = /@([\w' -]{0,40})$/;

export default class Ham_groupFeed extends LightningElement {
    @api groupId;
    @api userContactId;
    @api showFilter;
    @api isdiscussiontab;
    @api limitCount;
    @api memberCount;   // active member count, shown in the Amplify confirmation banner
    @api images = {};
    @api groupIcons = {};

    // Compact preview mode (embedded on the group dashboard landing page): caps the
    // visible posts to limitCount, scrolls internally instead of paginating, and
    // swaps the "Show More Activity" pager for a static "See more" nav button.
    get isCompactView() {
        return !!this.limitCount;
    }

    get postsListClass() {
        return `feed-posts-list ${this.isCompactView ? 'feed-posts-list-compact' : ''}`;
    }

    _isAdmin = false;
    @api
    get isAdmin() {
        return this._isAdmin;
    }
    set isAdmin(value) {
        this._isAdmin = (value === true || value === 'true');
    }

    _isOverride = false;
    @api
    get isOverride() {
        return this._isOverride;
    }
    set isOverride(value) {
        this._isOverride = (value === true || value === 'true');
    }

    // Applied to the wrapper around the popups, which render outside .feed-root — so the
    // Kirkland (green) theme overrides can still reach modal buttons/inputs.
    get themeClass() {
        return this.isOverride ? 'kirkland-override' : '';
    }

    get feedRootClass() {
        return `feed-root ${this.isOverride ? 'kirkland-override' : ''}`;
    }

    @track posts = [];
    @track isLoading = false;
    @track hasMore = true;
    @track bookmarkedIds = new Set();

    // Report modal state
    @track showReportModal = false;
    reportingPostId = null;
    reportingCommentId = null;
    @track reportReason = '';
    @track isSubmittingReport = false;
    @track reportSubmitted = false;

    // Report User modal state
    @track showReportUserModal = false;
    reportUserPostId = null;
    reportUserCommentId = null;
    @track reportUserReason = '';
    @track isSubmittingUserReport = false;
    @track reportUserSubmitted = false;

    // Edit Post/Reply modal state
    @track showEditModal = false;
    @track editTarget = null; // 'post' | 'comment'
    @track editBody = '';
    @track editTags = '';
    @track isSavingEdit = false;
    editingId = null;
    editingPostId = null; // parent post of the comment being edited, for refreshing its list

    get isEditingPost() {
        return this.editTarget === 'post';
    }

    get editModalTitle() {
        return this.isEditingPost ? 'Edit Post' : 'Edit Reply';
    }

    // Delete Post confirmation modal state
    @track showDeleteConfirm = false;
    deletingPostId = null;

    // Image lightbox state — clicking an inline attachment image previews it enlarged
    // rather than downloading it.
    @track showImagePreview = false;
    @track previewImageUrl = null;
    @track previewImageAlt = '';

    // Amplify Post confirmation modal state — amplifying notifies every member, so
    // (unlike Pin) it goes through a confirmation step first. Un-amplify has no modal.
    @track showAmplifyConfirm = false;
    @track amplifyingPostId = null;
    @track isAmplifying = false;

    get saveEditLabel() {
        return this.isSavingEdit ? 'Saving...' : 'Save Changes';
    }

    // ─── Search & Filter Bar State ───────────────────────────────────────────
    @track searchTerm = '';
    @track appliedSearchTerm = '';
    @track filterStartDate = null;
    @track filterEndDate = null;
    @track filterAuthorId = null;
    @track filterAuthorName = null;
    @track filterBookmarkedOnly = false;

    @track isDatePopoverOpen = false;
    @track isPeoplePopoverOpen = false;
    @track draftStartDate = null;
    @track draftEndDate = null;

    @track postAuthors = [];
    @track peopleSearchTerm = '';
    authorsLoaded = false;

    get hasPostAuthors() {
        return this.postAuthors && this.postAuthors.length > 0;
    }

    get filteredPostAuthors() {
        const term = this.peopleSearchTerm.trim().toLowerCase();
        if (!term) {
            return this.postAuthors;
        }
        return this.postAuthors.filter((author) => author.name.toLowerCase().includes(term));
    }

    get hasFilteredPostAuthors() {
        return this.filteredPostAuthors.length > 0;
    }

    get dateFilterButtonClass() {
        return `filter-btn${this.filterStartDate || this.filterEndDate ? ' filter-btn-active' : ''}`;
    }

    get peopleFilterButtonClass() {
        return `filter-btn${this.filterAuthorId ? ' filter-btn-active' : ''}`;
    }

    get bookmarkFilterButtonClass() {
        return `filter-btn${this.filterBookmarkedOnly ? ' filter-btn-active' : ''}`;
    }

    get dateRangeLabel() {
        if (this.filterStartDate && this.filterEndDate) return `${this.filterStartDate} - ${this.filterEndDate}`;
        if (this.filterStartDate) return `From ${this.filterStartDate}`;
        if (this.filterEndDate) return `Until ${this.filterEndDate}`;
        return 'Date';
    }

    get peopleLabel() {
        if (this.filterAuthorId === 'ANONYMOUS') {
            return 'Anonymous Posts';
        }
        return this.filterAuthorName || 'People';
    }

    get hasActiveFilters() {
        return !!(this.appliedSearchTerm || this.filterStartDate || this.filterEndDate
            || this.filterAuthorId || this.filterBookmarkedOnly);
    }

    get showEmptyState() {
        return !this.isLoading && this.posts.length === 0;
    }

    // "No posts yet" is only true for an untouched feed — with a filter applied the
    // group may well have posts, just none matching, so say which case it is.
    get emptyStateMessage() {
        if (this.filterBookmarkedOnly) return 'No bookmarked posts yet.';
        if (this.hasActiveFilters) return 'No posts match your filters.';
        return 'No posts yet.';
    }

    // Polling parameters
    clientLastSyncTime = null;
    currentInterval = INITIAL_INTERVAL;
    pollingTimeoutId = null;
    isComponentActive = true;

    // Deep link parameters from URL query string
    targetPostId = null;
    targetCommentId = null;
    _deepLinkHandled = false;
    _pendingCommentScroll = false;
    isModeratorMode = false;

    get reportReasons() {
        return [
            { label: 'Inappropriate Message', value: 'Inappropriate Message' },
            { label: 'Harassment', value: 'Harassment' },
            { label: 'Bullying', value: 'Bullying' },
            { label: 'Aggressive Tone', value: 'Aggressive Tone' },
            { label: 'Bad Behavior (In Group)', value: 'Bad Behavior (In Group)' },
            { label: 'Bad Behavior (Outside Group)', value: 'Bad Behavior (Outside Group)' },
            { label: 'Other', value: 'Other' }
        ];
    }

    get reportUserReasons() {
        return [
            { label: 'Inappropriate Message', value: 'Inappropriate Message' },
            { label: 'Harassment', value: 'Harassment' },
            { label: 'Bullying', value: 'Bullying' },
            { label: 'Aggressive Tone', value: 'Aggressive Tone' },
            { label: 'Bad Behavior (In Group)', value: 'Bad Behavior (In Group)' },
            { label: 'Bad Behavior (Outside Group)', value: 'Bad Behavior (Outside Group)' },
            { label: 'Other', value: 'Other' }
        ];
    }

    // Native <select> doesn't support binding `value` as a template attribute in LWC,
    // so the selected option is driven by an explicit `selected` flag per option instead.
    get reportReasonOptions() {
        return [
            { value: '', label: 'Select a reason...', isSelected: !this.reportReason },
            ...this.reportReasons.map(r => ({ ...r, isSelected: r.value === this.reportReason }))
        ];
    }

    // The placeholder option is greyed out like real placeholder text until a reason is chosen.
    get reportSelectClass() {
        return `report-select${this.reportReason ? '' : ' report-select--placeholder'}`;
    }

    get canSubmitReport() {
        return !!this.reportReason;
    }

    get submitReportLabel() {
        return this.isSubmittingReport ? 'Submitting...' : 'Report Message';
    }

    get reportUserReasonOptions() {
        return [
            { value: '', label: 'Select a reason...', isSelected: !this.reportUserReason },
            ...this.reportUserReasons.map(r => ({ ...r, isSelected: r.value === this.reportUserReason }))
        ];
    }

    get reportUserSelectClass() {
        return `report-select${this.reportUserReason ? '' : ' report-select--placeholder'}`;
    }

    get canSubmitUserReport() {
        return !!this.reportUserReason;
    }

    get submitUserReportLabel() {
        return this.isSubmittingUserReport ? 'Submitting...' : 'Report User';
    }

    connectedCallback() {
        this.parseUrlParameters();
        this.fetchBookmarks();
        this.loadFeed(true);
        this.setupPolling();
        this.setupVisibilityListener();
        this.handleWindowClick = this.handleWindowClick.bind(this);
        window.addEventListener('click', this.handleWindowClick);
    }

    renderedCallback() {
        this.handleDeepLinkRouting();
    }

    disconnectedCallback() {
        this.isComponentActive = false;
        this.clearPolling();
        window.removeEventListener('click', this.handleWindowClick);
    }

    // Prevents clicks inside an open popover (date inputs, Apply/Clear, people list)
    // from bubbling to the window listener and closing the popover before the user
    // can interact with it (e.g. the native date picker).
    handlePopoverClick(event) {
        event.stopPropagation();
    }

    handleWindowClick() {
        this.closeAllActionMenus();
        this.isDatePopoverOpen = false;
        this.isPeoplePopoverOpen = false;
    }

    parseUrlParameters() {
        // The dashboard preview trims the feed to limitCount, so the deep-linked post
        // may not survive into it — leave the scroll to the full Discussion tab rather
        // than having two mounted feeds race to claim it.
        if (this.isCompactView) return;
        try {
            const urlParams = new URLSearchParams(window.location.search);
            this.targetPostId = urlParams.get('postId');
            this.targetCommentId = urlParams.get('commentId');
            this.isModeratorMode = urlParams.get('mode') === 'moderator';
        } catch (e) {
            console.error('Error parsing URL parameters:', e);
        }
    }

    fetchBookmarks() {
        getBookmarkedPostIds()
            .then(ids => {
                this.bookmarkedIds = new Set(ids);
                this.updatePostBookmarkStates();
            })
            .catch(err => {
                console.error('Error fetching bookmarks:', err);
            });
    }

    // ─── Feed Loading & Keyset Pagination ────────────────────────────────────

    loadFeed(isInitial = false) {
        if (this.isLoading) return;
        this.isLoading = true;

        const lastPostId = (!isInitial && this.posts.length > 0)
            ? this.posts[this.posts.length - 1].id
            : null;

        const startDate = this.filterStartDate ? `${this.filterStartDate}T00:00:00.000Z` : null;
        const endDate = this.filterEndDate ? `${this.filterEndDate}T23:59:59.999Z` : null;

        getGroupFeed({
            groupId: this.groupId,
            currentContactId: this.userContactId,
            lastPostId: lastPostId,
            searchTerm: this.appliedSearchTerm || null,
            startDate: startDate,
            endDate: endDate,
            authorContactId: this.filterAuthorId || null,
            bookmarkedOnly: this.filterBookmarkedOnly,
            // Only on the first page: the server unions this post in regardless of age,
            // so a deep link to an old post isn't lost past the pagination boundary.
            targetPostId: isInitial ? this.targetPostId : null
        })
        .then(data => {
            const rawPosts = data || [];
            let parsedPosts = rawPosts.map(p => this.formatPost(p));

            // Compact preview mode isn't paginated — trim to the requested count and
            // let the "See more" link hand off to the full discussion tab instead.
            if (this.isCompactView && isInitial) {
                parsedPosts = parsedPosts.slice(0, parseInt(this.limitCount, 10));
            }

            if (isInitial) {
                this.posts = parsedPosts;
                this.clientLastSyncTime = Date.now();

                // Auto-scroll and drawer expansion are driven by renderedCallback once the
                // target actually exists in the DOM. If it isn't in the payload at all the
                // post is gone (deleted, or moderated out) — say so instead of no-opping.
                if (this.targetPostId
                    && !this.posts.some(p => String(p.id) === String(this.targetPostId))) {
                    this.targetPostId = null;
                    this.targetCommentId = null;
                    this.showToast('Not available', 'That post is no longer available in this group.', 'warning');
                }
            } else {
                this.posts = [...this.posts, ...parsedPosts];
            }

            // hasMorePages reflects whether the paginated query (excluding the amplified/pinned
            // buckets, which are fetched in full up front) had another row past this page —
            // a plain "did we get any posts back" check stays true forever once the feed is
            // smaller than one page.
            this.hasMore = this.isCompactView ? false
                : (rawPosts.length > 0 && !!rawPosts[rawPosts.length - 1].hasMorePages);
            this.updatePostBookmarkStates();
        })
        .catch(err => {
            console.error('Error loading feed:', err);
            this.showToast('Error', 'Could not load group feed.', 'error');
        })
        .finally(() => {
            this.isLoading = false;
        });
    }

    handleLoadMore() {
        this.loadFeed(false);
    }

    // Compact preview's footer link — hands off to the parent (e.g. the group
    // dashboard) to route into the full, searchable discussion tab.
    handleSeeMore() {
        this.dispatchEvent(new CustomEvent('seemore'));
    }

    formatPost(p) {
        // Author identity is masked server-side for anonymous posts (getGroupFeed),
        // so authorName/authorPhotoUrl are used as-is here.
        const isTargeted = this.targetPostId && String(p.id) === String(this.targetPostId);

        const commentCount = p.commentCount || 0;
        const decodedBody = this.decodeEntities(p.body);
        const attachments = (p.attachments || []).map(a => ({
            ...a,
            key: a.contentDocumentId,
            isFile: !a.isImage,
            // Rebuild the Shepherd URL with the community base path so it resolves inside
            // the site (the Apex value is root-relative and 404s/errors outside "/ex").
            downloadUrl: `${basePath}/sfc/servlet.shepherd/version/download/${a.contentVersionId}`
        }));

        return {
            id: p.id,
            body: decodedBody,
            attachments,
            tags: p.tags ? p.tags.split(',').map(t => t.trim()).filter(Boolean) : [],
            authorName: p.authorName,
            authorPhotoUrl: p.authorPhotoUrl,
            createdDate: p.createdDate,
            relativeTime: this.formatRelativeTime(p.createdDate),
            isPinned: p.isPinned,
            pinLabel: p.isPinned ? 'Unpin Post' : 'Pin Post',
            isAmplified: p.isAmplified,
            amplifyLabel: p.isAmplified ? 'De-amplify Post' : 'Amplify Post',
            isOwnPost: !!p.isOwnPost,
            canDelete: !!(p.isOwnPost || this.isAdmin),
            isBookmarked: this.bookmarkedIds.has(p.id),
            bookmarkIcon: this.bookmarkedIds.has(p.id) ? 'utility:bookmark' : 'utility:bookmark_alt',
            bookmarkClass: this.bookmarkedIds.has(p.id) ? 'bookmark-active' : '',
            bookmarkIconUrl: this.resolveBookmarkIconUrl(this.bookmarkedIds.has(p.id)),
            bookmarkAlt: this.bookmarkedIds.has(p.id) ? 'Bookmarked' : 'Bookmark',
            bodySegments: this.parseBody(decodedBody),
            cssClass: `post-card ${isTargeted ? 'post-card--highlighted' : ''} ${p.isPinned ? 'post-card--pinned' : ''} ${p.isAmplified ? 'post-card--amplified' : ''} ${isTargeted && this.isModeratorMode ? 'post-card--moderator-flagged' : ''}`,
            isCommentsOpen: false,
            isCommentsLoading: false,
            comments: [],
            commentCount: commentCount,
            replyLabel: this.formatReplyLabel(commentCount),
            isMenuOpen: false,
            showMentionPopover: false,
            mentionSuggestions: [],
            pendingMentions: []
        };
    }

    // Bookmark icon is resolved off the HAM_Icons static resource rather than the
    // parent-supplied `images` map, because the dashboard's preview feed isn't passed
    // one. Four variants exist: fill/outline × default/Kirkland.
    resolveBookmarkIconUrl(isBookmarked) {
        const state = isBookmarked ? 'fill' : 'outline';
        const theme = this.isOverride ? '-green' : '';
        return `${HAM_ICONS}/bookmark-${state}${theme}.png`;
    }

    // Banner icons depend only on the theme, not on per-post state, so they're plain
    // getters rather than fields stamped onto each post.
    get pinnedIconUrl() {
        return `${HAM_GROUP_ICONS}/groups-pinned${this.isOverride ? '-green' : ''}.png`;
    }

    get amplifiedIconUrl() {
        return `${HAM_GROUP_ICONS}/groups-amplifier${this.isOverride ? '-green' : ''}.png`;
    }

    // No -green variant: the comments button stays grey in both themes (Kirkland only
    // restyles its hover state).
    get commentsIconUrl() {
        return `${HAM_GROUP_ICONS}/groups-comments.png`;
    }

    formatReplyLabel(count) {
        return `${count} ${count === 1 ? 'reply' : 'replies'}`;
    }

    formatRelativeTime(dateValue) {
        const thenDate = new Date(dateValue);
        const then = thenDate.getTime();
        const now = new Date();

        // Posts from today show the clock time ("Today at 3:45 PM") rather than a
        // relative "x hours ago", per QA.
        if (thenDate.getFullYear() === now.getFullYear()
            && thenDate.getMonth() === now.getMonth()
            && thenDate.getDate() === now.getDate()) {
            return `Today at ${this.formatClockTime(thenDate)}`;
        }

        const seconds = Math.max(0, Math.floor((Date.now() - then) / 1000));

        if (seconds < 60) return 'Just now';

        const minutes = Math.floor(seconds / 60);
        if (minutes < 60) return `${minutes} minute${minutes === 1 ? '' : 's'} ago`;

        const hours = Math.floor(minutes / 60);
        if (hours < 24) return `${hours} hour${hours === 1 ? '' : 's'} ago`;

        const days = Math.floor(hours / 24);
        if (days < 7) return `${days} day${days === 1 ? '' : 's'} ago`;

        const weeks = Math.floor(days / 7);
        if (weeks < 4) return `${weeks} week${weeks === 1 ? '' : 's'} ago`;

        const months = Math.floor(days / 30);
        if (months < 12) return `${months} month${months === 1 ? '' : 's'} ago`;

        const years = Math.floor(days / 365);
        return `${years} year${years === 1 ? '' : 's'} ago`;
    }

    // "3:45 PM" — 12-hour clock with zero-padded minutes.
    formatClockTime(date) {
        let hours = date.getHours();
        const minutes = date.getMinutes().toString().padStart(2, '0');
        const meridiem = hours >= 12 ? 'PM' : 'AM';
        hours = hours % 12;
        if (hours === 0) hours = 12;
        return `${hours}:${minutes} ${meridiem}`;
    }

    // Post/comment bodies live in Rich Text (Html) fields, so Salesforce stores emoji and
    // other non-ASCII characters as numeric HTML entities (e.g. "&#128517;"). These are
    // plain-text bodies (composer/comment box are plain textareas), so decode the entities
    // back to characters for display — otherwise the raw "&#128517;" shows on screen.
    decodeEntities(text) {
        if (!text) return text;
        return text
            .replace(/&#x([0-9a-fA-F]+);/g, (m, hex) => this.fromCodePointSafe(parseInt(hex, 16)))
            .replace(/&#(\d+);/g, (m, dec) => this.fromCodePointSafe(parseInt(dec, 10)))
            .replace(/&quot;/g, '"')
            .replace(/&#39;/g, "'")
            .replace(/&apos;/g, "'")
            .replace(/&nbsp;/g, ' ')
            .replace(/&lt;/g, '<')
            .replace(/&gt;/g, '>')
            .replace(/&amp;/g, '&');
    }

    fromCodePointSafe(code) {
        try {
            return String.fromCodePoint(code);
        } catch (e) {
            return '';
        }
    }

    updatePostBookmarkStates() {
        this.posts = this.posts.map(post => {
            return {
                ...post,
                isBookmarked: this.bookmarkedIds.has(post.id),
                bookmarkIcon: this.bookmarkedIds.has(post.id) ? 'utility:bookmark' : 'utility:bookmark_alt',
                bookmarkClass: this.bookmarkedIds.has(post.id) ? 'bookmark-active' : '',
                bookmarkIconUrl: this.resolveBookmarkIconUrl(this.bookmarkedIds.has(post.id)),
                bookmarkAlt: this.bookmarkedIds.has(post.id) ? 'Bookmarked' : 'Bookmark'
            };
        });
    }

    // ─── YouTube/Vimeo Inline Embedding Regex Parser ─────────────────────────

    parseBody(body) {
        if (!body) return [];
        
        // The trailing (?:[?&#][^\s]*)? swallows any share/query params that follow the
        // video id (e.g. youtu.be/<id>?si=... , watch?v=<id>&t=30s) so they aren't left
        // dangling as stray text under the embedded player.
        const ytRegex = /(?:https?:\/\/)?(?:www\.)?(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/)([a-zA-Z0-9_-]{11})(?:[?&#][^\s]*)?/gi;
        const vimeoRegex = /(?:https?:\/\/)?(?:www\.)?(?:vimeo\.c(?:om)?\/)(?:channels\/[a-zA-Z0-9]+\/)?(?:groups\/[a-zA-Z0-9]+\/videos\/)?([0-9]+)(?:[?&#][^\s]*)?/gi;

        let segments = [];
        let lastIndex = 0;
        let match;
        
        const allMatches = [];
        while ((match = ytRegex.exec(body)) !== null) {
            allMatches.push({
                index: match.index,
                length: match[0].length,
                type: 'youtube',
                embedUrl: `https://www.youtube.com/embed/${match[1]}`,
                url: match[0]
            });
        }
        ytRegex.lastIndex = 0;
        
        while ((match = vimeoRegex.exec(body)) !== null) {
            allMatches.push({
                index: match.index,
                length: match[0].length,
                type: 'vimeo',
                embedUrl: `https://player.vimeo.com/video/${match[1]}`,
                url: match[0]
            });
        }
        vimeoRegex.lastIndex = 0;
        
        allMatches.sort((a, b) => a.index - b.index);
        
        for (const m of allMatches) {
            if (m.index > lastIndex) {
                const subText = body.substring(lastIndex, m.index);
                segments.push(...this.parseTextLinks(subText));
            }
            segments.push({
                isVideo: true,
                type: m.type,
                embedUrl: m.embedUrl,
                url: m.url
            });
            lastIndex = m.index + m.length;
        }
        
        if (lastIndex < body.length) {
            const subText = body.substring(lastIndex);
            segments.push(...this.parseTextLinks(subText));
        }
        
        return segments.length > 0 ? segments : this.parseTextLinks(body);
    }

    parseTextLinks(text) {
        if (!text) return [];
        const urlRegex = /(https?:\/\/[^\s]+|www\.[^\s]+)/gi;
        const result = [];
        let lastIdx = 0;
        let match;
        while ((match = urlRegex.exec(text)) !== null) {
            if (match.index > lastIdx) {
                result.push({ isText: true, content: text.substring(lastIdx, match.index) });
            }
            const rawUrl = match[0];
            const href = rawUrl.toLowerCase().startsWith('www.') ? `https://${rawUrl}` : rawUrl;
            result.push({ isLink: true, url: href, text: rawUrl });
            lastIdx = match.index + rawUrl.length;
        }
        if (lastIdx < text.length) {
            result.push({ isText: true, content: text.substring(lastIdx) });
        }
        return result.length > 0 ? result : [{ isText: true, content: text }];
    }

    // ─── Decaying Polling Mechanism ──────────────────────────────────────────

    setupPolling() {
        this.clearPolling();
        if (!this.isComponentActive) return;

        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.pollingTimeoutId = setTimeout(() => {
            this.pollNewPosts();
        }, this.currentInterval);
    }

    clearPolling() {
        if (this.pollingTimeoutId) {
            clearTimeout(this.pollingTimeoutId);
            this.pollingTimeoutId = null;
        }
    }

    pollNewPosts() {
        if (!this.isComponentActive || document.hidden) {
            this.setupPolling(); // queue up again
            return;
        }

        checkForNewPosts({ groupId: this.groupId, clientLastSyncTime: this.clientLastSyncTime })
            .then(hasUpdates => {
                if (hasUpdates) {
                    // Sync new feed additions to front of list
                    this.currentInterval = INITIAL_INTERVAL; // reset to fast interval
                    this.loadFeed(true);
                } else {
                    // Decay interval slowly
                    this.currentInterval = Math.min(this.currentInterval * 1.5, MAX_INTERVAL);
                }
            })
            .catch(err => {
                console.error('Error checking for new posts:', err);
            })
            .finally(() => {
                this.setupPolling();
            });
    }

    setupVisibilityListener() {
        document.addEventListener('visibilitychange', () => {
            if (document.hidden) {
                this.clearPolling();
            } else {
                this.currentInterval = INITIAL_INTERVAL;
                this.pollNewPosts();
            }
        });
    }

    // ─── Comments/Replies Drawer ─────────────────────────────────────────────

    toggleComments(event) {
        const postId = event.currentTarget.dataset.postId;
        let targetOpen = false;

        this.posts = this.posts.map(post => {
            if (post.id === postId) {
                targetOpen = !post.isCommentsOpen;
                return {
                    ...post,
                    isCommentsOpen: targetOpen
                };
            }
            return post;
        });

        if (targetOpen) {
            this.loadComments(postId);
        }
    }

    loadComments(postId) {
        this.posts = this.posts.map(post => {
            if (post.id === postId) {
                return { ...post, isCommentsLoading: true };
            }
            return post;
        });

        getPostComments({ postId })
            .then(data => {
                const formattedComments = (data || []).map(c => ({
                    ...c,
                    body: this.decodeEntities(c.body),
                    isOwnComment: !!(c.contactId && this.userContactId && String(c.contactId) === String(this.userContactId)),
                    cssClass: `comment-row ${this.targetCommentId && String(c.commentId) === String(this.targetCommentId) ? 'comment-row--highlighted' : ''} ${this.targetCommentId && String(c.commentId) === String(this.targetCommentId) && this.isModeratorMode ? 'comment-row--moderator-flagged' : ''}`,
                    isMenuOpen: false
                }));

                this.posts = this.posts.map(post => {
                    if (post.id === postId) {
                        return {
                            ...post,
                            isCommentsLoading: false,
                            comments: formattedComments
                        };
                    }
                    return post;
                });
                
                // Hand off to renderedCallback, which scrolls once the comment row is
                // actually in the DOM rather than guessing at how long that takes.
                if (this.targetCommentId && String(postId) === String(this.targetPostId)) {
                    const targetLoaded = formattedComments.some(
                        c => String(c.commentId) === String(this.targetCommentId)
                    );
                    this._pendingCommentScroll = targetLoaded;
                    if (!targetLoaded) {
                        // Comment is gone (deleted or moderated out). The post scroll was
                        // skipped in favour of this one, so land on the post rather than
                        // leaving the user wherever the page happened to be.
                        const container = this.template.querySelector(`article[data-id="${this.targetPostId}"]`);
                        if (container) {
                            container.scrollIntoView({ behavior: 'smooth', block: 'center' });
                        }
                        this.showToast('Not available', 'That comment is no longer available.', 'warning');
                    }
                }
            })
            .catch(err => {
                console.error('Error fetching comments:', err);
                this.showToast('Error', 'Could not load comments.', 'error');
                this.posts = this.posts.map(post => {
                    if (post.id === postId) {
                        return { ...post, isCommentsLoading: false };
                    }
                    return post;
                });
            });
    }

    // ─── @Mention picker (comment box) ───────────────────────────────────────
    // Detects an "@word" being typed in a comment textarea and shows a popover of
    // matching group members, mirroring the composer's inline-insertion approach.

    handleCommentInput(event) {
        const postId = event.currentTarget.dataset.postId;
        const textarea = event.target;
        const cursorPos = textarea.selectionStart;
        const match = textarea.value.substring(0, cursorPos).match(MENTION_TRIGGER_REGEX);

        if (!match) {
            this.setCommentMentionState(postId, { showMentionPopover: false, mentionSuggestions: [] });
            return;
        }

        this._commentMentionTriggerStart = cursorPos - match[0].length;
        this._commentMentionTriggerEnd = cursorPos;

        const term = match[1].trim();
        if (term === '') {
            this.setCommentMentionState(postId, { showMentionPopover: true, mentionSuggestions: [] });
            return;
        }

        clearTimeout(this._commentMentionDebounceTimer);
        const queryToken = (this._commentMentionQueryToken || 0) + 1;
        this._commentMentionQueryToken = queryToken;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._commentMentionDebounceTimer = setTimeout(() => {
            searchGroupMembersForMention({ groupId: this.groupId, searchTerm: term })
                .then(res => {
                    if (queryToken !== this._commentMentionQueryToken) {
                        return; // stale response
                    }
                    const post = this.posts.find(p => p.id === postId);
                    const already = new Set((post?.pendingMentions || []).map(m => m.contactId));
                    const suggestions = (res || []).filter(s => !already.has(s.contactId));
                    this.setCommentMentionState(postId, { showMentionPopover: true, mentionSuggestions: suggestions });
                })
                .catch(error => {
                    console.error('Error searching group members for mention:', error);
                    this.setCommentMentionState(postId, { showMentionPopover: true, mentionSuggestions: [] });
                });
        }, MENTION_DEBOUNCE_MS);
    }

    setCommentMentionState(postId, patch) {
        this.posts = this.posts.map(post =>
            post.id === postId ? { ...post, ...patch } : post
        );
    }

    handleSelectCommentMentionSuggestion(event) {
        const postId = event.currentTarget.dataset.postId;
        const contactId = event.currentTarget.dataset.contactId;
        const name = event.currentTarget.dataset.name;
        this.applyCommentMention(postId, contactId, name);
    }

    applyCommentMention(postId, contactId, name) {
        const textarea = this.template.querySelector(`textarea[data-post-id="${postId}"]`);
        if (!textarea) return;

        const before = textarea.value.substring(0, this._commentMentionTriggerStart);
        const after = textarea.value.substring(this._commentMentionTriggerEnd);
        const insertion = `@${name} `;
        textarea.value = `${before}${insertion}${after}`;

        const post = this.posts.find(p => p.id === postId);
        const existing = post?.pendingMentions || [];
        const pendingMentions = existing.some(m => m.contactId === contactId)
            ? existing
            : [...existing, { contactId, name }];
        this.setCommentMentionState(postId, { showMentionPopover: false, mentionSuggestions: [], pendingMentions });

        const newCursorPos = before.length + insertion.length;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            textarea.focus();
            textarea.setSelectionRange(newCursorPos, newCursorPos);
        }, 0);
    }

    handleAddComment(event) {
        if (event.key === 'Enter' && !event.shiftKey) {
            event.preventDefault();
            const postId = event.currentTarget.dataset.postId;
            const post = this.posts.find(p => p.id === postId);

            // While the mention popover is open, Enter selects the top suggestion
            // instead of submitting the comment.
            if (post?.showMentionPopover && post.mentionSuggestions.length > 0) {
                const top = post.mentionSuggestions[0];
                this.applyCommentMention(postId, top.contactId, top.name);
                return;
            }

            this.submitComment(postId);
        }
    }

    // Send-button click: same submit path as pressing Enter in the reply box.
    handleSendComment(event) {
        const postId = event.currentTarget.dataset.postId;
        this.submitComment(postId);
    }

    // Shared reply submit used by both the Enter key and the send button.
    submitComment(postId) {
        const post = this.posts.find(p => p.id === postId);
        const textarea = this.template.querySelector(`textarea[data-post-id="${postId}"]`);
        if (!textarea) return;

        const body = textarea.value.trim();
        if (!body) return;

        textarea.disabled = true;

        const mentionedContactIds = (post?.pendingMentions || []).map(m => m.contactId).join(',');

        createComment({ postId, body, currentContactId: this.userContactId, mentionedContactIds })
            .then(() => {
                textarea.value = '';
                this.loadComments(postId);
                this.posts = this.posts.map(p => {
                    if (p.id === postId) {
                        const commentCount = p.commentCount + 1;
                        return { ...p, commentCount, replyLabel: this.formatReplyLabel(commentCount), pendingMentions: [] };
                    }
                    return p;
                });
            })
            .catch(err => {
                console.error('Error adding comment:', err);
                this.showToast('Error', 'Could not post comment.', 'error');
            })
            .finally(() => {
                textarea.disabled = false;
                textarea.focus();
            });
    }

    // ─── Bookmarking / Saving Posts ──────────────────────────────────────────

    toggleBookmark(event) {
        const postId = event.currentTarget.dataset.postId;
        const isBookmarked = this.bookmarkedIds.has(postId);

        if (isBookmarked) {
            unbookmarkPost({ postId })
                .then(() => {
                    this.bookmarkedIds.delete(postId);
                    this.updatePostBookmarkStates();
                    this.showToast('Saved', 'Post removed from bookmarks.', 'success');
                })
                .catch(err => {
                    console.error('Error unbookmarking post:', err);
                });
        } else {
            bookmarkPost({ postId })
                .then(() => {
                    this.bookmarkedIds.add(postId);
                    this.updatePostBookmarkStates();
                    this.showToast('Saved', 'Post added to bookmarks.', 'success');
                })
                .catch(err => {
                    console.error('Error bookmarking post:', err);
                });
        }
    }

    // ─── Search & Filter Bar ──────────────────────────────────────────────────

    applyFilters() {
        this.posts = [];
        this.hasMore = true;
        this.loadFeed(true);
    }

    handleSearchInput(event) {
        this.searchTerm = event.target.value;
        if (!this.searchTerm.trim() && this.appliedSearchTerm) {
            this.appliedSearchTerm = '';
            this.applyFilters();
        }
    }

    handleSearchKeydown(event) {
        if (event.key === 'Enter') {
            event.preventDefault();
            this.handleSearchClick();
        }
    }

    handleSearchClick() {
        this.appliedSearchTerm = this.searchTerm ? this.searchTerm.trim() : '';
        this.applyFilters();
    }

    handleTagClick(event) {
        event.stopPropagation();
        const tag = event.currentTarget.dataset.tag;
        if (tag) {
            this.searchTerm = `#${tag}`;
            this.appliedSearchTerm = `#${tag}`;
            this.applyFilters();
        }
    }

    toggleDatePopover(event) {
        event.stopPropagation();
        this.isPeoplePopoverOpen = false;
        this.isDatePopoverOpen = !this.isDatePopoverOpen;
        if (this.isDatePopoverOpen) {
            this.draftStartDate = this.filterStartDate;
            this.draftEndDate = this.filterEndDate;
        }
    }

    handleDraftStartDateChange(event) {
        this.draftStartDate = event.target.value;
    }

    handleDraftEndDateChange(event) {
        this.draftEndDate = event.target.value;
    }

    applyDateFilter() {
        this.filterStartDate = this.draftStartDate || null;
        this.filterEndDate = this.draftEndDate || null;
        this.isDatePopoverOpen = false;
        this.applyFilters();
    }

    clearDateFilter() {
        this.filterStartDate = null;
        this.filterEndDate = null;
        this.draftStartDate = null;
        this.draftEndDate = null;
        this.isDatePopoverOpen = false;
        this.applyFilters();
    }

    togglePeoplePopover(event) {
        event.stopPropagation();
        this.isDatePopoverOpen = false;
        this.isPeoplePopoverOpen = !this.isPeoplePopoverOpen;
        this.peopleSearchTerm = '';
        if (this.isPeoplePopoverOpen && !this.authorsLoaded) {
            this.loadPostAuthors();
        }
    }

    handlePeopleSearchInput(event) {
        this.peopleSearchTerm = event.target.value;
    }

    loadPostAuthors() {
        getGroupPostAuthors({ groupId: this.groupId, currentContactId: this.userContactId })
            .then(data => {
                this.postAuthors = data || [];
                this.authorsLoaded = true;
            })
            .catch(err => {
                console.error('Error loading post authors:', err);
            });
    }

    handleSelectAuthor(event) {
        const contactId = event.currentTarget.dataset.id;
        const name = event.currentTarget.dataset.name;
        this.filterAuthorId = contactId || null;
        this.filterAuthorName = contactId ? name : null;
        this.isPeoplePopoverOpen = false;
        this.applyFilters();
    }

    toggleBookmarkFilter() {
        this.filterBookmarkedOnly = !this.filterBookmarkedOnly;
        this.applyFilters();
    }

    clearAllFilters() {
        this.searchTerm = '';
        this.appliedSearchTerm = '';
        this.filterStartDate = null;
        this.filterEndDate = null;
        this.draftStartDate = null;
        this.draftEndDate = null;
        this.filterAuthorId = null;
        this.filterAuthorName = null;
        this.filterBookmarkedOnly = false;
        this.applyFilters();
    }

    // ─── Post Actions Menu (three-dot kebab) ─────────────────────────────────

    toggleActionMenu(event) {
        event.stopPropagation();
        const postId = event.currentTarget.dataset.postId;
        this.posts = this.posts.map(post => ({
            ...post,
            isMenuOpen: post.id === postId ? !post.isMenuOpen : false,
            comments: (post.comments || []).map(c => ({ ...c, isMenuOpen: false }))
        }));
    }

    closeAllActionMenus() {
        this.posts = this.posts.map(post => {
            const hasOpenComment = (post.comments || []).some(c => c.isMenuOpen);
            if (!post.isMenuOpen && !hasOpenComment) return post;
            return {
                ...post,
                isMenuOpen: false,
                comments: hasOpenComment ? post.comments.map(c => ({ ...c, isMenuOpen: false })) : post.comments
            };
        });
    }

    // ─── Comment Actions Menu (three-dot kebab) ──────────────────────────────

    toggleCommentActionMenu(event) {
        event.stopPropagation();
        const commentId = event.currentTarget.dataset.commentId;
        const postId = event.currentTarget.dataset.postId;
        this.posts = this.posts.map(post => {
            if (post.id !== postId) {
                const hasOpenComment = (post.comments || []).some(c => c.isMenuOpen);
                return hasOpenComment ? { ...post, comments: post.comments.map(c => ({ ...c, isMenuOpen: false })) } : post;
            }
            return {
                ...post,
                isMenuOpen: false,
                comments: post.comments.map(c => ({
                    ...c,
                    isMenuOpen: c.commentId === commentId ? !c.isMenuOpen : false
                }))
            };
        });
    }

    // ─── Edit Post / Edit Reply ───────────────────────────────────────────────

    handleEditPost(event) {
        event.stopPropagation();
        const postId = event.currentTarget.dataset.postId;
        const post = this.posts.find(p => p.id === postId);
        if (!post) return;

        this.editTarget = 'post';
        this.editingId = postId;
        this.editingPostId = null;
        this.editBody = post.body || '';
        this.editTags = (post.tags || []).join(', ');
        this.showEditModal = true;
        this.closeAllActionMenus();
    }

    handleEditComment(event) {
        event.stopPropagation();
        const commentId = event.currentTarget.dataset.commentId;
        const postId = event.currentTarget.dataset.postId;
        const post = this.posts.find(p => p.id === postId);
        const comment = post ? post.comments.find(c => c.commentId === commentId) : null;
        if (!comment) return;

        this.editTarget = 'comment';
        this.editingId = commentId;
        this.editingPostId = postId;
        this.editBody = comment.body || '';
        this.editTags = '';
        this.showEditModal = true;
        this.closeAllActionMenus();
    }

    handleEditBodyChange(event) {
        this.editBody = event.target.value;
    }

    handleEditTagsChange(event) {
        this.editTags = event.target.value;
    }

    closeEditModal() {
        this.showEditModal = false;
        this.editTarget = null;
        this.editingId = null;
        this.editingPostId = null;
        this.editBody = '';
        this.editTags = '';
    }

    saveEdit() {
        const body = (this.editBody || '').trim();
        if (!body) {
            this.showToast('Error', 'Content cannot be blank.', 'error');
            return;
        }

        this.isSavingEdit = true;

        if (this.isEditingPost) {
            updatePost({ postId: this.editingId, body, tags: this.editTags, currentContactId: this.userContactId })
                .then(updated => {
                    this.posts = this.posts.map(p => p.id === this.editingId
                        ? {
                            ...p,
                            body: this.decodeEntities(updated.body),
                            tags: updated.tags ? updated.tags.split(',').map(t => t.trim()).filter(Boolean) : [],
                            bodySegments: this.parseBody(this.decodeEntities(updated.body))
                        }
                        : p);
                    this.showToast('Saved', 'Post updated.', 'success');
                    this.closeEditModal();
                })
                .catch(err => {
                    console.error('Error updating post:', err);
                    this.showToast('Error', 'Could not update post.', 'error');
                })
                .finally(() => {
                    this.isSavingEdit = false;
                });
        } else {
            updateComment({ commentId: this.editingId, body, currentContactId: this.userContactId })
                .then(() => {
                    this.loadComments(this.editingPostId);
                    this.showToast('Saved', 'Reply updated.', 'success');
                    this.closeEditModal();
                })
                .catch(err => {
                    console.error('Error updating comment:', err);
                    this.showToast('Error', 'Could not update reply.', 'error');
                })
                .finally(() => {
                    this.isSavingEdit = false;
                });
        }
    }

    handlePinPost(event) {
        event.stopPropagation();
        const postId = event.currentTarget.dataset.postId;
        const post = this.posts.find(p => p.id === postId);
        if (!post) return;

        this.closeAllActionMenus();
        const wasPinned = post.isPinned;

        togglePinPost({ postId, currentContactId: this.userContactId })
            .then(() => {
                this.showToast('Saved', wasPinned ? 'Post unpinned.' : 'Post pinned to the top.', 'success');
                // Pinned state changes ordering (pinned posts surface at the top),
                // so re-fetch the feed from scratch rather than patching local state.
                this.posts = [];
                this.loadFeed(true);
            })
            .catch(err => {
                console.error('Error toggling pin state:', err);
                this.showToast('Error', 'Could not update pin status.', 'error');
            });
    }

    // Amplify notifies every member, so — unlike Pin — it opens a confirmation modal
    // first. The actual amplify runs from confirmAmplifyPost().
    handleAmplifyPost(event) {
        event.stopPropagation();
        this.amplifyingPostId = event.currentTarget.dataset.postId;
        this.showAmplifyConfirm = true;
        this.closeAllActionMenus();
    }

    closeAmplifyConfirm() {
        if (this.isAmplifying) return;
        this.showAmplifyConfirm = false;
        this.amplifyingPostId = null;
    }

    // The post whose body/preview the confirmation modal shows.
    get amplifyingPost() {
        return this.posts.find(p => p.id === this.amplifyingPostId) || null;
    }

    // "All N group members will be notified" banner copy.
    get amplifyNotifyLabel() {
        const count = this.memberCount != null ? this.memberCount : 0;
        return `All ${count} group member${count === 1 ? '' : 's'} will be notified`;
    }

    get amplifyConfirmLabel() {
        return this.isAmplifying ? 'Amplifying...' : 'Amplify & Notify';
    }

    confirmAmplifyPost() {
        const postId = this.amplifyingPostId;
        if (!postId || this.isAmplifying) return;

        this.isAmplifying = true;
        amplifyPost({ groupId: this.groupId, postId, contactId: this.userContactId })
            .then(() => {
                this.showToast('Amplified', 'Post amplified and group members notified.', 'success');
                this.showAmplifyConfirm = false;
                this.amplifyingPostId = null;
                // Amplified posts lead the feed, so re-fetch from scratch to reflect the
                // new ordering + badge (same approach as pin/unpin).
                this.posts = [];
                this.loadFeed(true);
            })
            .catch(err => {
                console.error('Error amplifying post:', err);
                this.showToast('Error', 'Could not amplify this post.', 'error');
            })
            .finally(() => {
                this.isAmplifying = false;
            });
    }

    // Un-amplify is the corrective action for an accidental amplify — direct (no modal,
    // no notification), mirroring Unpin.
    handleUnamplifyPost(event) {
        event.stopPropagation();
        const postId = event.currentTarget.dataset.postId;
        this.closeAllActionMenus();

        unamplifyPost({ groupId: this.groupId, postId, contactId: this.userContactId })
            .then(() => {
                this.showToast('Removed', 'Amplification removed from this post.', 'success');
                // Post drops out of the amplified block, so re-fetch (same as unpin).
                this.posts = [];
                this.loadFeed(true);
            })
            .catch(err => {
                console.error('Error removing amplification:', err);
                this.showToast('Error', 'Could not remove amplification.', 'error');
            });
    }

    // ─── Image Lightbox ──────────────────────────────────────────────────────

    handleImagePreview(event) {
        event.stopPropagation();
        this.previewImageUrl = event.currentTarget.dataset.url;
        this.previewImageAlt = event.currentTarget.dataset.alt || '';
        this.showImagePreview = true;
    }

    closeImagePreview() {
        this.showImagePreview = false;
        this.previewImageUrl = null;
        this.previewImageAlt = '';
    }

    // Clicks on the image/download link inside the overlay must not bubble to the
    // backdrop's close handler.
    stopPreviewPropagation(event) {
        event.stopPropagation();
    }

    handleDeletePost(event) {
        event.stopPropagation();
        this.deletingPostId = event.currentTarget.dataset.postId;
        this.showDeleteConfirm = true;
        this.closeAllActionMenus();
    }

    closeDeleteConfirm() {
        this.showDeleteConfirm = false;
        this.deletingPostId = null;
    }

    confirmDeletePost() {
        const postId = this.deletingPostId;
        if (!postId) return;

        deletePost({ postId, currentContactId: this.userContactId })
            .then(() => {
                this.posts = this.posts.filter(p => p.id !== postId);
                this.showToast('Deleted', 'Post has been deleted.', 'success');
                this.closeDeleteConfirm();
            })
            .catch(err => {
                console.error('Error deleting post:', err);
                this.showToast('Error', 'Could not delete post.', 'error');
            });
    }

    // ─── Content Moderation Flag Reporting ───────────────────────────────────

    openReportPostModal(event) {
        event.stopPropagation();
        this.reportingPostId = event.currentTarget.dataset.postId;
        this.reportingCommentId = null;
        this.reportReason = '';
        this.reportSubmitted = false;
        this.showReportModal = true;
        this.closeAllActionMenus();
    }

    openReportCommentModal(event) {
        event.stopPropagation();
        this.reportingPostId = null;
        this.reportingCommentId = event.currentTarget.dataset.commentId;
        this.reportReason = '';
        this.reportSubmitted = false;
        this.showReportModal = true;
        this.closeAllActionMenus();
    }

    closeReportModal() {
        this.showReportModal = false;
        this.reportingPostId = null;
        this.reportingCommentId = null;
        this.reportReason = '';
        this.reportSubmitted = false;
    }

    handleReportReasonChange(event) {
        this.reportReason = event.target.value;
    }

    handleSubmitReport() {
        if (!this.canSubmitReport || this.isSubmittingReport) return;

        this.isSubmittingReport = true;

        reportContent({
            postId: this.reportingPostId,
            commentId: this.reportingCommentId,
            reason: this.reportReason,
            currentContactId: this.userContactId
        })
        .then(() => {
            // Stay in the modal and show an acknowledgment instead of closing outright,
            // so the reporter has confirmation the report actually went through.
            this.reportSubmitted = true;
            this.dispatchEvent(new CustomEvent('reportsubmitted'));
        })
        .catch(err => {
            console.error('Error reporting content:', err);
            this.showToast('Error', 'Could not submit report.', 'error');
        })
        .finally(() => {
            this.isSubmittingReport = false;
        });
    }

    // ─── Report User ──────────────────────────────────────────────────────────

    openReportUserModal(event) {
        event.stopPropagation();
        this.reportUserPostId = event.currentTarget.dataset.postId;
        this.reportUserCommentId = null;
        this.reportUserReason = '';
        this.reportUserSubmitted = false;
        this.showReportUserModal = true;
        this.closeAllActionMenus();
    }

    openReportUserModalForComment(event) {
        event.stopPropagation();
        this.reportUserPostId = null;
        this.reportUserCommentId = event.currentTarget.dataset.commentId;
        this.reportUserReason = '';
        this.reportUserSubmitted = false;
        this.showReportUserModal = true;
        this.closeAllActionMenus();
    }

    closeReportUserModal() {
        this.showReportUserModal = false;
        this.reportUserPostId = null;
        this.reportUserCommentId = null;
        this.reportUserReason = '';
        this.reportUserSubmitted = false;
    }

    handleUserReportReasonChange(event) {
        this.reportUserReason = event.target.value;
    }

    handleSubmitUserReport() {
        if (!this.canSubmitUserReport || this.isSubmittingUserReport) return;

        this.isSubmittingUserReport = true;

        reportUser({
            postId: this.reportUserPostId,
            commentId: this.reportUserCommentId,
            reason: this.reportUserReason,
            currentContactId: this.userContactId
        })
        .then(() => {
            this.reportUserSubmitted = true;
            this.dispatchEvent(new CustomEvent('reportsubmitted'));
        })
        .catch(err => {
            console.error('Error reporting user:', err);
            this.showToast('Error', 'Could not submit report.', 'error');
        })
        .finally(() => {
            this.isSubmittingUserReport = false;
        });
    }

    // ─── Routing Deep Linking Helpers ────────────────────────────────────────

    // Driven by render rather than a timer: the posts paint after Apex resolves and
    // avatars/attachments load lazily, so a fixed delay either fires before the target
    // exists or animates toward an offset that later content shifts out from under it.
    handleDeepLinkRouting() {
        if (this.targetPostId && !this._deepLinkHandled) {
            // Scoped to article so the author-filter popover, which also uses data-id
            // (with contact Ids) and precedes the feed in document order, can't win.
            const container = this.template.querySelector(`article[data-id="${this.targetPostId}"]`);
            if (!container) return; // not rendered yet — retry on the next render

            this._deepLinkHandled = true;

            // With a comment target, opening the drawer changes page height mid-animation,
            // so the post scroll would settle on a stale offset. Let the comment scroll
            // below be the only one; otherwise scroll to the post itself.
            if (!this.targetCommentId) {
                container.scrollIntoView({ behavior: 'smooth', block: 'center' });
            }

            this.posts = this.posts.map(post => {
                return post.id === this.targetPostId ? { ...post, isCommentsOpen: true } : post;
            });
            this.loadComments(this.targetPostId);
        }

        if (this._pendingCommentScroll) {
            const commentEl = this.template.querySelector(`[data-comment-id="${this.targetCommentId}"]`);
            if (commentEl) {
                this._pendingCommentScroll = false;
                commentEl.scrollIntoView({ behavior: 'smooth', block: 'center' });
            }
        }
    }

    // Public API to refresh feed (e.g. from parent composer)
    @api
    refresh() {
        this.posts = [];
        this.loadFeed(true);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant })
        );
    }
}