import { LightningElement, api, track } from 'lwc';
import getGroupResourceCards from '@salesforce/apex/Ham_GroupsController.getGroupResourceCards';
import bookmarkResource from '@salesforce/apex/Ham_GroupsController.bookmarkResource';
import unbookmarkResource from '@salesforce/apex/Ham_GroupsController.unbookmarkResource';
import amplifyResource from '@salesforce/apex/Ham_GroupsController.amplifyResource';
import unamplifyResource from '@salesforce/apex/Ham_GroupsController.unamplifyResource';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const ALL_CATEGORIES = 'All';

export default class Ham_groupResources extends LightningElement {
    @api groupId;
    @api contactId;
    @api isAdmin = false;
    @api memberCount = 0;

    // When set (dashboard preview card) we cap the grid and hide the toolbar
    @api limitCount;
    @api groupIcons = {};

    _isOverride = false;
    @api
    get isOverride() {
        return this._isOverride;
    }
    set isOverride(value) {
        this._isOverride = (value === true || value === 'true');
    }

    get rootClass() {
        return `resources-root slds-p-around_medium ${this.isOverride ? 'kirkland-override' : ''}`;
    }

    @track resources = [];
    @track isLoading = false;

    // Toolbar filters
    @track searchTerm = '';
    @track categoryFilter = ALL_CATEGORIES;
    @track bookmarkedOnly = false;

    // Amplify confirmation (admins)
    @track amplifyTarget = null;
    @track isAmplifying = false;

    // Deep link from an amplify notification (?...&subview=resources&resourceId=...)
    targetResourceId = null;
    _deepLinkHandled = false;

    connectedCallback() {
        this.parseUrlParameters();
        this.loadResources();
    }

    // The dashboard preview caps the grid, so the deep-linked card may not be in it —
    // let the full Resources tab own the scroll instead of fighting it from the preview.
    parseUrlParameters() {
        if (this.isPreviewMode) return;
        try {
            this.targetResourceId = new URLSearchParams(window.location.search).get('resourceId');
        } catch (e) {
            console.error('Error parsing URL parameters:', e);
        }
    }

    // Scrolling is driven by render rather than a fixed timeout: the cards are painted
    // after the Apex call resolves, and the images are lazy-loaded, so a timer either
    // fires too early (nothing to find) or animates to an offset that later shifts.
    renderedCallback() {
        if (!this.targetResourceId || this._deepLinkHandled) return;

        const card = this.template.querySelector(`[data-resource-id="${this.targetResourceId}"]`);
        if (!card) return; // not rendered yet — retry on the next render

        this._deepLinkHandled = true;
        card.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }

    loadResources() {
        this.isLoading = true;
        getGroupResourceCards({ groupId: this.groupId })
            .then(data => {
                // Server already orders bookmarked cards first
                this.resources = (data || []).map(res => ({ ...res, id: res.resourceId }));

                // Tell the user rather than silently doing nothing if the notification
                // outlived the resource (deleted, or moved to another group).
                if (this.targetResourceId
                    && !this.resources.some(r => String(r.id) === String(this.targetResourceId))) {
                    this.targetResourceId = null;
                    this.showToast('Not available', 'That resource is no longer in this group.', 'warning');
                }
            })
            .catch(err => {
                console.error('Error fetching resources:', err);
                this.showToast('Error', 'Could not load group resources.', 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // ── Display Getters ───────────────────────────────────────────────────────

    get isPreviewMode() {
        return !!this.limitCount;
    }

    get displayResources() {
        let list = [...this.resources];

        const term = this.searchTerm.trim().toLowerCase();
        if (term) {
            list = list.filter(r => (r.title || '').toLowerCase().includes(term));
        }
        if (this.categoryFilter !== ALL_CATEGORIES) {
            list = list.filter(r => r.category === this.categoryFilter);
        }
        if (this.bookmarkedOnly) {
            list = list.filter(r => r.isBookmarked);
        }
        if (this.limitCount) {
            list = list.slice(0, parseInt(this.limitCount, 10));
        }

        return list.map(r => ({
            ...r,
            cardClass: `resource-card${r.isAmplified ? ' amplified' : ''}`
                + (this.targetResourceId && String(r.id) === String(this.targetResourceId)
                    ? ' resource-card--highlighted' : ''),
            bookmarkBtnClass: r.isBookmarked ? 'card-action-btn bookmark-active' : 'card-action-btn',
            bookmarkTitle: r.isBookmarked ? 'Remove bookmark' : 'Bookmark this resource',
            // aria-pressed must serialise to the strings "true"/"false"
            bookmarkPressed: r.isBookmarked ? 'true' : 'false',
            amplifyBtnClass: r.isAmplified ? 'card-action-btn amplify-active' : 'card-action-btn',
            amplifyTitle: r.isAmplified ? 'Remove amplification' : 'Amplify this resource'
        }));
    }

    get hasResources() {
        return this.resources.length > 0;
    }

    get hasResults() {
        return this.displayResources.length > 0;
    }

    get categoryOptions() {
        const found = new Set();
        this.resources.forEach(r => {
            if (r.category) found.add(r.category);
        });
        const options = [{ value: ALL_CATEGORIES, label: 'All Categories' }];
        [...found].sort().forEach(cat => options.push({ value: cat, label: cat }));
        return options.map(opt => ({ ...opt, selected: opt.value === this.categoryFilter }));
    }

    get bookmarkFilterClass() {
        return this.bookmarkedOnly ? 'btn-bookmark-filter active' : 'btn-bookmark-filter';
    }

    get amplifyMemberWarning() {
        const count = this.memberCount || 0;
        return `All ${count} group member${count === 1 ? '' : 's'} will be notified`;
    }

    // ── Toolbar Handlers ──────────────────────────────────────────────────────

    handleSearchChange(event) {
        this.searchTerm = event.target.value;
    }

    handleCategoryChange(event) {
        this.categoryFilter = event.target.value;
    }

    toggleBookmarkFilter() {
        this.bookmarkedOnly = !this.bookmarkedOnly;
    }

    // ── Bookmarking ───────────────────────────────────────────────────────────

    handleBookmarkClick(event) {
        // The button sits on top of the card link — don't trigger navigation
        event.preventDefault();
        event.stopPropagation();

        const resourceId = event.currentTarget.dataset.id;
        const target = this.resources.find(r => r.id === resourceId);
        if (!target) return;

        const action = target.isBookmarked ? unbookmarkResource : bookmarkResource;

        // Flip locally right away so the icon feels responsive
        this.resources = this.resources.map(r =>
            r.id === resourceId ? { ...r, isBookmarked: !r.isBookmarked } : r
        );

        action({ resourceId })
            .then(() => this.loadResources())
            .catch(err => {
                console.error('Bookmark error:', err);
                this.showToast('Error', 'Could not update bookmark.', 'error');
                this.loadResources();
            });
    }

    // ── Amplify (admins only) ─────────────────────────────────────────────────

    handleAmplifyClick(event) {
        event.preventDefault();
        event.stopPropagation();
        const resourceId = event.currentTarget.dataset.id;
        this.amplifyTarget = this.resources.find(r => r.id === resourceId) || null;
    }

    closeAmplifyModal() {
        this.amplifyTarget = null;
    }

    // Un-amplify is the corrective action for an accidental amplify — direct (no modal,
    // no notification), mirroring the post feed's Remove Amplification.
    handleUnamplifyClick(event) {
        event.preventDefault();
        event.stopPropagation();
        const resourceId = event.currentTarget.dataset.id;

        unamplifyResource({ groupId: this.groupId, resourceId, contactId: this.contactId })
            .then(() => {
                this.showToast('Removed', 'Amplification removed from this resource.', 'success');
                this.loadResources();
            })
            .catch(err => {
                console.error('Un-amplify error:', err);
                this.showToast('Error', err.body?.message || 'Could not remove amplification.', 'error');
            });
    }

    confirmAmplify() {
        if (!this.amplifyTarget || this.isAmplifying) return;
        this.isAmplifying = true;

        amplifyResource({
            groupId: this.groupId,
            resourceId: this.amplifyTarget.id,
            contactId: this.contactId
        })
            .then(() => {
                this.showToast('Success', 'Resource amplified. Group members have been notified.', 'success');
                this.amplifyTarget = null;
                this.loadResources();
            })
            .catch(err => {
                console.error('Amplify error:', err);
                this.showToast('Error', err.body?.message || 'Could not amplify resource.', 'error');
            })
            .finally(() => {
                this.isAmplifying = false;
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant })
        );
    }
}