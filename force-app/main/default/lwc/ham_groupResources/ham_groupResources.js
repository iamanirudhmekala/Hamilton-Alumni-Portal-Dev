import { LightningElement, api, track } from 'lwc';
import getGroupResourceCards from '@salesforce/apex/Ham_GroupsController.getGroupResourceCards';
import addResource from '@salesforce/apex/Ham_GroupsController.addResource';
import bookmarkResource from '@salesforce/apex/Ham_GroupsController.bookmarkResource';
import unbookmarkResource from '@salesforce/apex/Ham_GroupsController.unbookmarkResource';
import amplifyResource from '@salesforce/apex/Ham_GroupsController.amplifyResource';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const ALL_CATEGORIES = 'All';

export default class Ham_groupResources extends LightningElement {
    @api groupId;
    @api contactId;
    @api isAdmin = false;
    @api memberCount = 0;

    // When set (dashboard preview card) we cap the grid and hide the toolbar
    @api limitCount;

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

    // Add-resource modal (admins)
    @track showAddModal = false;
    @track resourceTitle = '';
    @track resourceUrl = '';
    @track resourceDescription = '';
    @track resourceCategory = 'General';
    @track resourceImageUrl = '';

    // Amplify confirmation (admins)
    @track amplifyTarget = null;
    @track isAmplifying = false;

    connectedCallback() {
        this.loadResources();
    }

    loadResources() {
        this.isLoading = true;
        getGroupResourceCards({ groupId: this.groupId })
            .then(data => {
                // Server already orders bookmarked cards first
                this.resources = (data || []).map(res => ({ ...res, id: res.resourceId }));
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
            cardClass: r.isAmplified ? 'resource-card amplified' : 'resource-card',
            bookmarkBtnClass: r.isBookmarked ? 'card-action-btn bookmark-active' : 'card-action-btn',
            bookmarkTitle: r.isBookmarked ? 'Remove bookmark' : 'Bookmark this resource'
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

    // ── Add Resource Modal ────────────────────────────────────────────────────

    openAddModal() {
        this.resourceTitle = '';
        this.resourceUrl = '';
        this.resourceDescription = '';
        this.resourceCategory = 'General';
        this.resourceImageUrl = '';
        this.showAddModal = true;
    }

    closeAddModal() {
        this.showAddModal = false;
    }

    handleTitleChange(event) {
        this.resourceTitle = event.target.value;
    }

    handleUrlChange(event) {
        this.resourceUrl = event.target.value;
    }

    handleDescriptionChange(event) {
        this.resourceDescription = event.target.value;
    }

    handleCategoryInputChange(event) {
        this.resourceCategory = event.target.value;
    }

    handleImageUrlChange(event) {
        this.resourceImageUrl = event.target.value;
    }

    get resourceCategoryChoices() {
        return ['General', 'Academic', 'Career', 'Events'].map(cat => ({
            value: cat,
            label: cat,
            selected: cat === this.resourceCategory
        }));
    }

    submitResource() {
        const title = this.resourceTitle.trim();
        const url = this.resourceUrl.trim();

        if (!title || !url) {
            this.showToast('Validation Error', 'Title and URL are required fields.', 'error');
            return;
        }

        this.isLoading = true;
        addResource({
            groupId: this.groupId,
            title: title,
            url: url,
            contactId: this.contactId,
            description: this.resourceDescription.trim(),
            category: this.resourceCategory,
            imageUrl: this.resourceImageUrl.trim()
        })
        .then(() => {
            this.showToast('Success', 'Resource has been added successfully.', 'success');
            this.closeAddModal();
            this.loadResources();
        })
        .catch(err => {
            console.error('Error adding resource:', err);
            this.showToast('Error', err.body?.message || 'Could not add resource.', 'error');
        })
        .finally(() => {
            this.isLoading = false;
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant })
        );
    }
}