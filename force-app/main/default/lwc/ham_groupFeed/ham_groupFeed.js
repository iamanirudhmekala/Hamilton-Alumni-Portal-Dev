import { LightningElement, api, track, wire } from 'lwc';
import getGroupFeed from '@salesforce/apex/Ham_GroupsController.getGroupFeed';
import checkForNewPosts from '@salesforce/apex/Ham_GroupsController.checkForNewPosts';
import getPostComments from '@salesforce/apex/Ham_GroupsController.getPostComments';
import createComment from '@salesforce/apex/Ham_GroupsController.createComment';
import updatePost from '@salesforce/apex/Ham_GroupsController.updatePost';
import updateComment from '@salesforce/apex/Ham_GroupsController.updateComment';
import togglePinPost from '@salesforce/apex/Ham_GroupsController.togglePinPost';
import amplifyPost from '@salesforce/apex/Ham_GroupsController.amplifyPost';
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
    @api images = {};

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
    @track reportReason = 'Inappropriate Message';

    // Report User modal state
    @track showReportUserModal = false;
    reportUserPostId = null;
    reportUserCommentId = null;
    @track reportUserReason = 'Inappropriate Message';

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
    authorsLoaded = false;

    get hasPostAuthors() {
        return this.postAuthors && this.postAuthors.length > 0;
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
        return this.filterAuthorName || 'People';
    }

    get hasActiveFilters() {
        return !!(this.appliedSearchTerm || this.filterStartDate || this.filterEndDate
            || this.filterAuthorId || this.filterBookmarkedOnly);
    }

    get showEmptyState() {
        return !this.isLoading && this.posts.length === 0;
    }

    // Polling parameters
    clientLastSyncTime = null;
    currentInterval = INITIAL_INTERVAL;
    pollingTimeoutId = null;
    isComponentActive = true;

    // Deep link parameters from URL query string
    targetPostId = null;
    targetCommentId = null;
    isModeratorMode = false;

    get reportReasons() {
        return [
            { label: 'Inappropriate Message', value: 'Inappropriate Message' },
            { label: 'Aggressive Tone', value: 'Aggressive Tone' },
            { label: 'Spam', value: 'Spam' }
        ];
    }

    get reportUserReasons() {
        return [
            { label: 'Inappropriate Message', value: 'Inappropriate Message' },
            { label: 'Harassment', value: 'Harassment' },
            { label: 'Bullying', value: 'Bullying' },
            { label: 'Aggressive Tone', value: 'Aggressive Tone' },
            { label: 'Spam', value: 'Spam' },
            { label: 'Other', value: 'Other' }
        ];
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
            bookmarkedOnly: this.filterBookmarkedOnly
        })
        .then(data => {
            let parsedPosts = (data || []).map(p => this.formatPost(p));

            // Compact preview mode isn't paginated — trim to the requested count and
            // let the "See more" link hand off to the full discussion tab instead.
            if (this.isCompactView && isInitial) {
                parsedPosts = parsedPosts.slice(0, parseInt(this.limitCount, 10));
            }

            if (isInitial) {
                this.posts = parsedPosts;
                this.clientLastSyncTime = Date.now();

                // If there's a deep-linked post, handle auto-scroll and drawer expansion
                if (this.targetPostId) {
                    // eslint-disable-next-line @lwc/lwc/no-async-operation
                    setTimeout(() => {
                        this.handleDeepLinkRouting();
                    }, 500);
                }
            } else {
                this.posts = [...this.posts, ...parsedPosts];
            }

            this.hasMore = this.isCompactView ? false : parsedPosts.length > 0;
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

        return {
            id: p.id,
            body: p.body,
            tags: p.tags ? p.tags.split(',').map(t => t.trim()).filter(Boolean) : [],
            authorName: p.authorName,
            authorPhotoUrl: p.authorPhotoUrl,
            createdDate: p.createdDate,
            relativeTime: this.formatRelativeTime(p.createdDate),
            isPinned: p.isPinned,
            pinLabel: p.isPinned ? 'Unpin Post' : 'Pin Post',
            isAmplified: p.isAmplified,
            isOwnPost: !!p.isOwnPost,
            canDelete: !!(p.isOwnPost || this.isAdmin),
            isBookmarked: this.bookmarkedIds.has(p.id),
            bookmarkIcon: this.bookmarkedIds.has(p.id) ? 'utility:bookmark' : 'utility:bookmark_alt',
            bookmarkClass: this.bookmarkedIds.has(p.id) ? 'bookmark-active' : '',
            bookmarkIconUrl: this.resolveBookmarkIconUrl(this.bookmarkedIds.has(p.id)),
            bookmarkAlt: this.bookmarkedIds.has(p.id) ? 'Bookmarked' : 'Bookmark',
            bodySegments: this.parseBody(p.body),
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
        const then = new Date(dateValue).getTime();
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
        
        const ytRegex = /(?:https?:\/\/)?(?:www\.)?(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/)([a-zA-Z0-9_-]{11})/gi;
        const vimeoRegex = /(?:https?:\/\/)?(?:www\.)?(?:vimeo\.c(?:om)?\/)(?:channels\/[a-zA-Z0-9]+\/)?(?:groups\/[a-zA-Z0-9]+\/videos\/)?([0-9]+)/gi;

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
                segments.push({
                    isText: true,
                    content: body.substring(lastIndex, m.index)
                });
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
            segments.push({
                isText: true,
                content: body.substring(lastIndex)
            });
        }
        
        return segments.length > 0 ? segments : [{ isText: true, content: body }];
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
                
                if (this.targetCommentId) {
                    // eslint-disable-next-line @lwc/lwc/no-async-operation
                    setTimeout(() => {
                        this.scrollToComment(this.targetCommentId);
                    }, 300);
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
        if (this.isPeoplePopoverOpen && !this.authorsLoaded) {
            this.loadPostAuthors();
        }
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
                            body: updated.body,
                            tags: updated.tags ? updated.tags.split(',').map(t => t.trim()).filter(Boolean) : [],
                            bodySegments: this.parseBody(updated.body)
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

    handleAmplifyPost(event) {
        event.stopPropagation();
        const postId = event.currentTarget.dataset.postId;
        this.closeAllActionMenus();

        amplifyPost({ groupId: this.groupId, postId, contactId: this.userContactId })
            .then(() => {
                this.showToast('Amplified', 'Post amplified and group members notified.', 'success');
                this.posts = this.posts.map(post =>
                    post.id === postId ? { ...post, isAmplified: true } : post
                );
            })
            .catch(err => {
                console.error('Error amplifying post:', err);
                this.showToast('Error', 'Could not amplify this post.', 'error');
            });
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
        this.reportReason = 'Inappropriate Message';
        this.showReportModal = true;
        this.closeAllActionMenus();
    }

    openReportCommentModal(event) {
        event.stopPropagation();
        this.reportingPostId = null;
        this.reportingCommentId = event.currentTarget.dataset.commentId;
        this.reportReason = 'Inappropriate Message';
        this.showReportModal = true;
        this.closeAllActionMenus();
    }

    closeReportModal() {
        this.showReportModal = false;
        this.reportingPostId = null;
        this.reportingCommentId = null;
    }

    handleSelectReportReason(event) {
        this.reportReason = event.currentTarget.dataset.reason;
        this.submitReport();
    }

    submitReport() {
        reportContent({
            postId: this.reportingPostId,
            commentId: this.reportingCommentId,
            reason: this.reportReason,
            currentContactId: this.userContactId
        })
        .then(() => {
            this.showToast('Reported', 'Content has been flagged for administrator review.', 'success');
            this.closeReportModal();
        })
        .catch(err => {
            console.error('Error reporting content:', err);
            this.showToast('Error', 'Could not submit report.', 'error');
        });
    }

    // ─── Report User ──────────────────────────────────────────────────────────

    openReportUserModal(event) {
        event.stopPropagation();
        this.reportUserPostId = event.currentTarget.dataset.postId;
        this.reportUserCommentId = null;
        this.reportUserReason = 'Inappropriate Message';
        this.showReportUserModal = true;
        this.closeAllActionMenus();
    }

    openReportUserModalForComment(event) {
        event.stopPropagation();
        this.reportUserPostId = null;
        this.reportUserCommentId = event.currentTarget.dataset.commentId;
        this.reportUserReason = 'Inappropriate Message';
        this.showReportUserModal = true;
        this.closeAllActionMenus();
    }

    closeReportUserModal() {
        this.showReportUserModal = false;
        this.reportUserPostId = null;
        this.reportUserCommentId = null;
    }

    handleSelectUserReportReason(event) {
        this.reportUserReason = event.currentTarget.dataset.reason;
        this.submitUserReport();
    }

    submitUserReport() {
        reportUser({
            postId: this.reportUserPostId,
            commentId: this.reportUserCommentId,
            reason: this.reportUserReason,
            currentContactId: this.userContactId
        })
        .then(() => {
            this.showToast('Reported', 'User has been reported to administrators.', 'success');
            this.closeReportUserModal();
        })
        .catch(err => {
            console.error('Error reporting user:', err);
            this.showToast('Error', 'Could not submit report.', 'error');
        });
    }

    // ─── Routing Deep Linking Helpers ────────────────────────────────────────

    handleDeepLinkRouting() {
        const container = this.template.querySelector(`[data-id="${this.targetPostId}"]`);
        if (container) {
            container.scrollIntoView({ behavior: 'smooth', block: 'center' });
            
            // Expand comments automatically if target post is loaded
            this.posts = this.posts.map(post => {
                if (post.id === this.targetPostId) {
                    return { ...post, isCommentsOpen: true };
                }
                return post;
            });
            this.loadComments(this.targetPostId);
        }
    }

    scrollToComment(commentId) {
        const commentEl = this.template.querySelector(`[data-comment-id="${commentId}"]`);
        if (commentEl) {
            commentEl.scrollIntoView({ behavior: 'smooth', block: 'center' });
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