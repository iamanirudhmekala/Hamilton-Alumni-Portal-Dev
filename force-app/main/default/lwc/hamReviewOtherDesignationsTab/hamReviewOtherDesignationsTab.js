import { LightningElement, api, track } from 'lwc';
import searchOtherDesignations from '@salesforce/apex/HamReviewTransactionController.searchOtherDesignations';

const DEBOUNCE_MS = 300;
const MIN_CHARS = 2;
const PAGE_SIZE = 25;
const MAX_PAGE_BUTTONS = 5;

export default class HamReviewOtherDesignationsTab extends LightningElement {
    _selectedDesignations = [];
    _isMaxReached = false;

    @api
    get selectedDesignations() { return this._selectedDesignations; }
    set selectedDesignations(value) {
        this._selectedDesignations = value || [];
        this._enrich();
    }

    // NEW: re-enrich when cap state changes so buttons update reactively
    @api
    get isMaxReached() { return this._isMaxReached; }
    set isMaxReached(value) {
        this._isMaxReached = value;
        this._enrich();
    }

    @track searchTerm = '';
    @track enrichedDesignations = [];
    @track isLoading = false;
    @track hasSearched = false;
    @track currentPage = 1;

    _designations = [];
    _debounceTimer;

    // ─── Pagination computed properties ───────────────────────────────────────

    get totalResults() {
        return this.enrichedDesignations.length;
    }

    get totalPages() {
        return Math.ceil(this.totalResults / PAGE_SIZE);
    }

    get paginationStart() {
        return this.totalResults === 0 ? 0 : (this.currentPage - 1) * PAGE_SIZE + 1;
    }

    get paginationEnd() {
        return Math.min(this.currentPage * PAGE_SIZE, this.totalResults);
    }

    get pagedDesignations() {
        const start = (this.currentPage - 1) * PAGE_SIZE;
        return this.enrichedDesignations.slice(start, start + PAGE_SIZE);
    }

    get showPagination() {
        return this.totalPages > 1;
    }

    get isFirstPage() {
        return this.currentPage === 1;
    }

    get isLastPage() {
        return this.currentPage === this.totalPages;
    }

    get pageNumbers() {
        const total = this.totalPages;
        const current = this.currentPage;
        const half = Math.floor(MAX_PAGE_BUTTONS / 2);

        let start = Math.max(1, current - half);
        let end = Math.min(total, start + MAX_PAGE_BUTTONS - 1);

        if (end - start < MAX_PAGE_BUTTONS - 1) {
            start = Math.max(1, end - MAX_PAGE_BUTTONS + 1);
        }

        const pages = [];
        for (let i = start; i <= end; i++) {
            pages.push({
                number: i,
                cssClass: i === current
                    ? 'ham-page-btn ham-page-btn-active'
                    : 'ham-page-btn'
            });
        }
        return pages;
    }

    // ─── Existing computed properties ─────────────────────────────────────────

    get hasDesignations() {
        return this.enrichedDesignations && this.enrichedDesignations.length > 0;
    }

    get showEmpty() {
        return this.hasSearched && !this.isLoading && !this.hasDesignations;
    }

    get showHint() {
        return !this.hasSearched && !this.isLoading;
    }

    // ─── Enrich helper ────────────────────────────────────────────────────────

    _enrich() {
        this.enrichedDesignations = this._designations.map(d => {
            const sel = this._selectedDesignations.find(s => s.id === d.id);
            const isSelected = !!sel;

            // Disable Add when max is reached and this fund isn't already chosen
            const isAddDisabled = !isSelected && this._isMaxReached;

            return {
                ...d,
                isSelected,
                selectedAmount: sel ? sel.amount : '0.00',
                isAddDisabled,
                buttonClass: isSelected
                    ? 'ham-card-button ham-card-button-added'
                    : isAddDisabled
                        ? 'ham-card-button ham-card-button-add ham-card-button-disabled'
                        : 'ham-card-button ham-card-button-add',
                buttonLabel: isSelected ? '✓ Added' : '+ Add'
            };
        });
    }

    // ─── Search handlers ──────────────────────────────────────────────────────

    handleSearchInput(event) {
        this.searchTerm = event.target.value;
        clearTimeout(this._debounceTimer);
        if (this.searchTerm.length >= MIN_CHARS) {
            this._debounceTimer = setTimeout(() => {
                this._runSearch();
            }, DEBOUNCE_MS);
        } else {
            this._designations = [];
            this.enrichedDesignations = [];
            this.hasSearched = false;
            this.currentPage = 1;
        }
    }

    _runSearch() {
        this.isLoading = true;
        this.currentPage = 1;
        searchOtherDesignations({ searchString: this.searchTerm })
            .then(results => {
                this._designations = results || [];
                this._enrich();
                this.hasSearched = true;
            })
            .catch(() => {
                this._designations = [];
                this.enrichedDesignations = [];
                this.hasSearched = true;
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // ─── Pagination handlers ──────────────────────────────────────────────────

    handlePrevPage() {
        if (!this.isFirstPage) {
            this.currentPage -= 1;
            this._scrollToTop();
        }
    }

    handleNextPage() {
        if (!this.isLastPage) {
            this.currentPage += 1;
            this._scrollToTop();
        }
    }

    handlePageClick(event) {
        const page = parseInt(event.currentTarget.dataset.page, 10);
        if (page !== this.currentPage) {
            this.currentPage = page;
            this._scrollToTop();
        }
    }

    _scrollToTop() {
        const container = this.template.querySelector('.ham-other-tab');
        if (container) {
            container.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }
    }

    // ─── Card interaction handlers ────────────────────────────────────────────

    handleDesignationClick(event) {
        const designationId = event.currentTarget.dataset.id;
        const enriched = this.enrichedDesignations.find(d => d.id === designationId);

        if (!enriched || enriched.isAddDisabled) return;

        const isCurrentlySelected = this._selectedDesignations.some(s => s.id === designationId);

        // Match the shape grandparent's handleDesignationSelect expects: { designation, isAdding }
        this.dispatchEvent(new CustomEvent('designationselect', {
            detail: {
                designation: { id: enriched.id, name: enriched.name },
                isAdding: !isCurrentlySelected
            }
        }));
    }

    handleAmountInput(event) {
        const designationId = event.currentTarget.dataset.id;
        const amount = event.target.value;
        this.dispatchEvent(new CustomEvent('amountchange', {
            detail: { designationId, amount }
        }));
    }
}