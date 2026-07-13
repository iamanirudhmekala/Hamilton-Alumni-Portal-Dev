import { LightningElement, api, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getGroupMembersDirectory   from '@salesforce/apex/Ham_GroupsController.getGroupMembersDirectory';
import getFilterMetadataAndValues from '@salesforce/apex/HAM_AlumniDirectoryController.getFilterMetadataAndValues';
import HAM_ICONS                  from '@salesforce/resourceUrl/HAM_Icons';

// Tab label constant — 'Search Directory'. Drives the directory display components'
// Build-tab card semantics (Send Request / Bookmark / cooldown handling).
import BuildCommunity from '@salesforce/label/c.HAM_Build_Community';

const PAGE_SIZE = 9; // directory parity (ham_alumniDisplayCmp.pageSizeForChild)

export default class Ham_groupMembers extends LightningElement {
    @api groupId;
    @api contactId;

    _isOverride = false;
    @api
    get isOverride() {
        return this._isOverride;
    }
    set isOverride(value) {
        this._isOverride = (value === true || value === 'true');
    }

    get rootClass() {
        return `members-root ${this.isOverride ? 'kirkland-override' : ''}`;
    }

    // ── Directory-parity state ──────────────────────────────────────────────
    directoryTabName = BuildCommunity;   // 'Search Directory'
    pageSizeForChild = PAGE_SIZE;

    @track filters = [];                 // raw filter metadata for c-ham_alumni-search-filter-cmp
    @track savedFilters = [];            // applied filter payload sent to Apex
    filterTrack = [];                    // latest filters from the child (applied on search click too)
    @track searchKey = '';
    searchKeyToApex = '';
    view = 'list';
    currentPage = 1;
    recordsToSkip = 0;
    totalRecordsForChild = null;
    @track filteredData = [];
    @track isLoading = false;
    _protalLogedUserPrivacy = false;
    _wiredMembersPage;

    // Mobile composition (mirrors ham_alumniDisplayCmp): under 1024px the filter component
    // renders itself as a full-screen panel, so it must live behind a FAB-toggled overlay
    // instead of inline — otherwise it covers the members page on load.
    @track screenWidth = window.innerWidth;
    @track isMobileFilterOpen = false;
    _boundResize = () => { this.screenWidth = window.innerWidth; };

    icons = {
        listViewIcon: `${HAM_ICONS}/list-view.png`,
        gridViewIcon: `${HAM_ICONS}/grid-dark.png`,
        viewCheckIcon: `${HAM_ICONS}/view-check.png`,
        filter: `${HAM_ICONS}/filter.png`
    };

    connectedCallback() {
        this.loadFilters();
        window.addEventListener('resize', this._boundResize);
    }

    disconnectedCallback() {
        window.removeEventListener('resize', this._boundResize);
    }

    // Same 1024px breakpoint the filter component uses internally
    get isMobileScreen() { return this.screenWidth < 1024; }
    get isDesktopScreen() { return this.screenWidth >= 1024; }

    get mobileFilterContainerClass() {
        return this.isMobileFilterOpen ? 'mobile-filter-visible' : 'mobile-filter-hidden';
    }

    handleFilterFabClick() { this.isMobileFilterOpen = true; }
    handleCloseMobileFilters() { this.isMobileFilterOpen = false; }

    // ── Filter metadata (same source as the directory) ─────────────────────
    loadFilters() {
        getFilterMetadataAndValues()
            .then(result => { this.filters = result; })
            .catch(error => { console.error('Load Filters error: ', error); });
    }

    // ── Wire: group members served by the directory engine ─────────────────
    @wire(getGroupMembersDirectory, {
        groupId: '$groupId', contactId: '$contactId',
        pageSize: '$pageSizeForChild', recordsToSkip: '$recordsToSkip',
        searchKey: '$searchKeyToApex', selectedFilters: '$savedFilters'
    })
    wiredMembersPage(result) {
        this._wiredMembersPage = result;
        const { data, error } = result;
        if (data) {
            this._protalLogedUserPrivacy = data.protalLogedUserPrivacy === true;
            this.totalRecordsForChild = data.totalCount > 0 ? data.totalCount : null;
            this.filteredData = this._decorateConstituents(data);
            this.isLoading = false;
        } else if (error) {
            this._protalLogedUserPrivacy = false;
            this.filteredData = [];
            this.totalRecordsForChild = null;
            this.isLoading = false;
            console.error('Group members load error: ', error);
        }
    }

    /**
     * Mirrors ham_alumniDisplayCmp's Search Directory ("Build") merge: constituents are the
     * cards; primary/secondary connection rows only decorate them with connection state.
     */
    _decorateConstituents(data) {
        const primaryConns = data.primaryConnections || [];
        const secondaryConns = data.secondaryConnections || [];
        const constituents = data.constituentsData || [];

        const primaryConnectionMap = new Map();
        primaryConns.forEach(conn => primaryConnectionMap.set(conn.linkedUserId, conn));

        const secondaryConnectionMap = new Map();
        secondaryConns.forEach(conn => {
            if (!secondaryConnectionMap.has(conn.portalUserId)) {
                secondaryConnectionMap.set(conn.portalUserId, []);
            }
            secondaryConnectionMap.get(conn.portalUserId).push(conn);
        });

        return constituents.map(constituent => {
            const primaryConn = primaryConnectionMap.get(constituent.id);
            const secondaries = secondaryConnectionMap.get(constituent.id) || [];

            let isCoolDown = false;
            for (const secConn of secondaries) {
                if (secConn.linkedUserId === this.contactId &&
                    (secConn.status === 'Disconnect' || secConn.status === 'Rejected') &&
                    this._isWithinCooldownPeriod(secConn.rejectedDate)) {
                    isCoolDown = true;
                    break;
                }
            }

            return {
                ...constituent,
                portalUserId: constituent.id,
                isBookmarked: primaryConn?.flags?.isBookmarked === true,
                isConnected: primaryConn?.flags?.isConnected === true,
                isRequestSent: primaryConn?.status === 'Request Sent',
                isCoolDown
            };
        });
    }

    _isWithinCooldownPeriod(dateString) {
        if (!dateString) return false;
        const date = new Date(dateString);
        const now = new Date();
        const thirtyDaysAgo = new Date(now.getTime() - (30 * 24 * 60 * 60 * 1000));
        return date >= thirtyDaysAgo && date <= now;
    }

    // ── Search (same guards as the directory's _executeSearch) ─────────────
    handleSearchInput(event) { this.searchKey = event.target.value; }
    handleSearchKeydown(event) { if (event.key === 'Enter') this.handleSearchClick(); }

    handleSearchClick() {
        const newSearchKey = (this.searchKey || '').trim();
        const newSavedFilters = this.filterTrack ? [...this.filterTrack] : [];

        const searchKeyUnchanged = newSearchKey === (this.searchKeyToApex || '');
        const filtersUnchanged = JSON.stringify(newSavedFilters) === JSON.stringify(this.savedFilters);

        // Both key and filters identical → the @wire will not re-fire; force a refresh
        // so the spinner always resolves.
        if (searchKeyUnchanged && filtersUnchanged) {
            this.isLoading = true;
            refreshApex(this._wiredMembersPage)
                .catch(error => console.error('Search refresh error:', error))
                .finally(() => { this.isLoading = false; });
            return;
        }

        this.isLoading = true;
        this.currentPage = 1;
        this.recordsToSkip = 0;
        this.searchKeyToApex = newSearchKey;
        this.savedFilters = newSavedFilters;

        // Wait for the new parameters to provision, then force refresh to bypass stale cache
        // (same pattern as the directory's _executeSearch)
        setTimeout(() => {
            refreshApex(this._wiredMembersPage)
                .catch(error => console.error('Search refresh error:', error));
        }, 0);
    }

    // ── Filters (payload contract shared with the directory) ───────────────
    handleFilterChange(event) {
        const { filters = [] } = event.detail || {};
        this.isLoading = true;
        this.currentPage = 1;
        this.recordsToSkip = 0;
        this.filterTrack = [...filters];
        this.savedFilters = [...filters];

        if (event.detail.clearSearchKey) {
            this.searchKey = '';
            this.searchKeyToApex = '';
        }

        // Force refresh so an unchanged wire (e.g. re-applying the same filters) still resolves
        setTimeout(() => {
            refreshApex(this._wiredMembersPage)
                .catch(error => console.error('Filter refresh error:', error))
                .finally(() => { this.isLoading = false; });
        }, 0);
    }

    get desktopFilterBadges() {
        const badges = [];
        (this.savedFilters || []).forEach(filter => {
            (filter.values || []).forEach((value, index) => {
                badges.push({
                    uniqueId: `${filter.placeholder}-${index}`,
                    category: filter.placeholder,
                    value
                });
            });
        });
        return badges;
    }

    handleRemoveFilterPill(event) {
        event.stopPropagation();
        const placeholderToRemove = event.currentTarget.dataset.placeholder;
        if (!placeholderToRemove) return;

        const updatedFilters = (this.filterTrack || [])
            .filter(f => f.placeholder !== placeholderToRemove);

        this.isLoading = true;
        this.currentPage = 1;
        this.recordsToSkip = 0;
        this.filterTrack = [...updatedFilters];
        this.savedFilters = [...updatedFilters];

        // Sync the child filter component so its pills/checkboxes update too
        const filterCmps = this.template.querySelectorAll('c-ham_alumni-search-filter-cmp');
        filterCmps.forEach(cmp => {
            if (updatedFilters.length > 0) {
                cmp.savedFilters = [...updatedFilters];
            } else if (typeof cmp.clearAllFiltersOnTabSwitch === 'function') {
                cmp.clearAllFiltersOnTabSwitch();
            }
        });

        setTimeout(() => {
            refreshApex(this._wiredMembersPage)
                .catch(error => console.error('Error removing filter pill:', error))
                .finally(() => { this.isLoading = false; });
        }, 0);
    }

    // ── View toggle ─────────────────────────────────────────────────────────
    get isListView() { return this.view === 'list'; }
    get isGridView() { return this.view === 'grid'; }
    get listViewClass() { return this.isListView ? 'active' : ''; }
    get gridViewClass() { return this.isGridView ? 'active' : ''; }

    // Directory mobile convention: grid cards only, no list/grid toggle
    get showListDisplay() { return this.isListView && this.isDesktopScreen; }
    get showGridDisplay() { return this.isGridView || this.isMobileScreen; }

    handleViewToggle(event) {
        this.view = event.currentTarget.dataset.view;
    }

    // ── Pagination (directory contract: pagechange → currentPage/recordsToSkip) ─
    handlePageChange(event) {
        this.isLoading = true;
        this.currentPage = event.detail.currentPage;
        this.recordsToSkip = event.detail.recordsToSkip;
    }

    // ── Child display component events ──────────────────────────────────────
    handleChildRefresh() {
        refreshApex(this._wiredMembersPage)
            .catch(error => console.error('Error refreshing members:', error))
            .finally(() => { this.isLoading = false; });
    }

    // Preserve this component's existing outbound contract with the group dashboard
    handleProfileSelect(event) {
        event.stopPropagation();
        const selectedContactId = event.detail?.selectedContactId ?? event.detail;
        this.dispatchEvent(new CustomEvent('profileoverview', {
            detail: { selectedContactId },
            bubbles: true,
            composed: true
        }));
    }
}