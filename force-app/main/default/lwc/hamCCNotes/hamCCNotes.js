import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CurrentPageReference } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getNotes from '@salesforce/apex/HamCCNotesController.getNotes';
import saveNote from '@salesforce/apex/HamCCNotesController.saveNote';

export default class HamCCNotes extends LightningElement {
    @api recordId;
    @api isAlumni;

    // Wire result reference for refreshApex
    _wiredNotesResult;

    // Data state
    @track allNotes = [];
    @track originalNotes = [];
    @track pagedNotes = [];
    @track recordsCount = 0;
    @track currentPage = 1;
    pageSize = 10;

    // Sort state
    @track sortedBy = 'NoteDate';
    @track sortedDirection = 'desc';

    // Accordion
    @track isExpanded = true;

    // Filters
    @track showFilters = false;
    @track filterSearchText = '';
    @track filterStartDate = '';
    @track filterEndDate = '';

    // New Note Form
    @track showForm = false;
    @track newNoteTitle = '';
    @track newNoteContent = '';
    @track newNoteDate = new Date().toISOString().split('T')[0];
    @track modalError = '';
    @track isSaving = false;

    // ── NEW: Mobile responsive flag ───────────────────────────────────────────
    @track isMobile = false;

    // ── NEW: Show-more/less tracking for mobile cards ─────────────────────────
    _expandedIds = new Set();

    // =========================================================================
    // Lifecycle
    // =========================================================================
    connectedCallback() {
        this.checkScreen();
        this._resizeHandler = this.checkScreen.bind(this);
        window.addEventListener('resize', this._resizeHandler);
    }

    disconnectedCallback() {
        window.removeEventListener('resize', this._resizeHandler);
    }

    checkScreen() {
        this.isMobile = window.innerWidth <= 768;
    }

    // =========================================================================
    // Columns (desktop only)
    // =========================================================================
    columns = [
        {
            label: 'Title',
            fieldName: 'TitleLink',
            type: 'url',
            typeAttributes: {
                label: { fieldName: 'Title' },
                target: '_blank'
            },
            sortable: true
        },
        {
            label: 'Content',
            fieldName: 'TextPreview',
            type: 'text',
            sortable: true,
            cellAttributes: { wrapText: true }
        },
        {
            label: 'Date',
            fieldName: 'NoteDate',
            type: 'date',
            typeAttributes: {
                year: 'numeric',
                month: '2-digit',
                day: '2-digit'
            },
            sortable: true
        }
    ];

    // =========================================================================
    // Wire
    // =========================================================================
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference?.state?.c__recordId && !this.recordId) {
            this.recordId = currentPageReference.state.c__recordId;
        }
        if (currentPageReference?.state) {
            const param = currentPageReference.state.c__isAlumni;
            if (param !== undefined) {
                this.isAlumni = param === 'true' || param === true;
            } else if (this.isAlumni === undefined) {
                this.isAlumni = true;
            }
        }
    }

    @wire(getNotes, { recordId: '$recordId', isAlumni: '$isAlumni' })
    wiredNotes(result) {
        this._wiredNotesResult = result;
        const { data, error } = result;
        if (data) {
            const processed = data.map(note => ({
                ...note,
                TitleLink: note.Id ? `/lightning/r/Note/${note.Id}/view` : null
            }));
            this.originalNotes = [...processed];
            this.allNotes = [...processed];
            this.recordsCount = processed.length;
            this.currentPage = 1;
            this._applySort();
            this.updatePaginationInfo();
        } else if (error) {
            this.originalNotes = [];
            this.allNotes = [];
            this.recordsCount = 0;
            this.pagedNotes = [];
            this.showToast('Error', 'Failed to load notes: ' + (error.body?.message || error.message), 'error');
        }
    }

    // =========================================================================
    // Getters
    // =========================================================================
    get accordionIconName() {
        return this.isExpanded ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get filtersButtonLabel() {
        return this.showFilters ? 'Hide Filters' : 'Filters';
    }

    get newNoteButtonLabel() {
        return this.showForm ? 'Close' : 'New Note';
    }

    get hasData()         { return this.recordsCount > 0; }
    get totalPages()      { return Math.ceil(this.recordsCount / this.pageSize) || 1; }
    get showPagination()  { return this.recordsCount > this.pageSize; }
    get previousDisabled(){ return this.currentPage === 1; }
    get nextDisabled()    { return this.currentPage >= this.totalPages; }

    get paginationInfo() {
        const start = (this.currentPage - 1) * this.pageSize;
        return {
            startIndex: start + 1,
            endIndex: Math.min(start + this.pageSize, this.recordsCount)
        };
    }

    // =========================================================================
    // Mobile sort helpers
    // =========================================================================
    get mobileSortOptions() {
        return [
            { label: 'Date',    value: 'NoteDate' },
            { label: 'Title',   value: 'Title' },
            { label: 'Content', value: 'TextPreview' }
        ];
    }

    get mobileSortDirectionIcon() {
        return this.sortedDirection === 'asc' ? 'utility:arrowup' : 'utility:arrowdown';
    }

    get mobileSortDirectionLabel() {
        return this.sortedDirection === 'asc' ? 'Ascending' : 'Descending';
    }

    get newNoteIconName() {
        return this.showForm ? 'utility:close' : 'utility:add';
    }

    handleMobileSortChange(event) {
        this.sortedBy = event.detail.value;
        this._applySort();
        this.currentPage = 1;
        this.updatePaginationInfo();
    }

    toggleMobileSortDirection() {
        this.sortedDirection = this.sortedDirection === 'asc' ? 'desc' : 'asc';
        this._applySort();
        this.currentPage = 1;
        this.updatePaginationInfo();
    }

    // =========================================================================
    // Mobile card show-more / show-less
    // =========================================================================
    toggleShowMore(event) {
        const noteId = event.currentTarget.dataset.id;
        if (this._expandedIds.has(noteId)) {
            this._expandedIds.delete(noteId);
        } else {
            this._expandedIds.add(noteId);
        }
        // Trigger re-render by re-slicing
        this.updatePaginationInfo();
    }

    /**
     * Computed list consumed by the mobile card template.
     * Adds formattedDate, displayContent, showMoreLabel, needsTruncation.
     */
    get mobilePageNotes() {
        const maxLen = 120;
        return this.pagedNotes.map(n => {
            const content     = n.TextPreview || '';
            const isExpanded  = this._expandedIds.has(n.Id);
            const needsTruncation = content.length > maxLen;

            const rawDate = n.NoteDate;
            let formattedDate = rawDate || '';
            if (rawDate) {
                const d = new Date(rawDate + 'T00:00:00');
                formattedDate = d.toLocaleDateString('en-US', {
                    year: 'numeric', month: 'short', day: 'numeric'
                });
            }

            return {
                ...n,
                displayContent: isExpanded || !needsTruncation
                    ? content
                    : content.substring(0, maxLen) + '...',
                showMoreLabel: isExpanded ? 'Show Less' : 'Show More',
                needsTruncation,
                formattedDate
            };
        });
    }

    // =========================================================================
    // Accordion
    // =========================================================================
    handleAccordionToggle() {
        this.isExpanded = !this.isExpanded;
    }

    // =========================================================================
    // Filter handlers
    // =========================================================================
    handleFiltersToggle()          { this.showFilters = !this.showFilters; }
    handleSearchTextChange(event)  { this.filterSearchText = event.target.value; }
    handleStartDateChange(event)   { this.filterStartDate  = event.target.value; }
    handleEndDateChange(event)     { this.filterEndDate    = event.target.value; }
    handleSearchKeyDown(event)     { if (event.key === 'Enter') this.handleSearchFilters(); }

    handleSearchFilters() {
        let filtered = [...this.originalNotes];

        if (this.filterSearchText) {
            const kw = this.filterSearchText.toLowerCase();
            filtered = filtered.filter(n =>
                (n.Title       || '').toLowerCase().includes(kw) ||
                (n.TextPreview || '').toLowerCase().includes(kw)
            );
        }

        if (this.filterStartDate || this.filterEndDate) {
            filtered = filtered.filter(n => {
                const d = n.NoteDate;
                if (!d) return false;
                if (this.filterStartDate && !this.filterEndDate) return d >= this.filterStartDate;
                if (!this.filterStartDate && this.filterEndDate) return d <= this.filterEndDate;
                return d >= this.filterStartDate && d <= this.filterEndDate;
            });
        }

        this.allNotes     = filtered;
        this.recordsCount = filtered.length;
        this.currentPage  = 1;
        this._applySort();
        this.updatePaginationInfo();
    }

    handleClearFilters() {
        this.filterSearchText = '';
        this.filterStartDate  = '';
        this.filterEndDate    = '';
        this.allNotes         = [...this.originalNotes];
        this.recordsCount     = this.allNotes.length;
        this.currentPage      = 1;
        this._applySort();
        this.updatePaginationInfo();
    }

    // =========================================================================
    // Sort
    // =========================================================================
    handleSort(event) {
        const { fieldName, sortDirection } = event.detail;
        this.sortedBy        = fieldName === 'TitleLink' ? 'Title' : fieldName;
        this.sortedDirection = sortDirection;
        this.currentPage     = 1;
        this._applySort();
        this.updatePaginationInfo();
    }

    _applySort() {
        const dir   = this.sortedDirection === 'asc' ? 1 : -1;
        const field = this.sortedBy;
        this.allNotes = [...this.allNotes].sort((a, b) => {
            const va = (a[field] ?? '').toString().toLowerCase();
            const vb = (b[field] ?? '').toString().toLowerCase();
            if (va === vb) return 0;
            return va > vb ? dir : -dir;
        });
    }

    // =========================================================================
    // Pagination
    // =========================================================================
    updatePaginationInfo() {
        const start = (this.currentPage - 1) * this.pageSize;
        this.pagedNotes = this.allNotes.slice(start, start + this.pageSize);
    }

    handlePrevious() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.updatePaginationInfo();
        }
    }

    handleNext() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            this.updatePaginationInfo();
        }
    }

    // =========================================================================
    // New Note Form
    // =========================================================================
    handleAddClick() {
        if (this.showForm) {
            this.showForm = false;
        } else {
            this._resetForm();
            this.isExpanded = true;
            this.showForm = true;
        }
    }

    handleCancel() {
        this._resetForm();
        this.showForm = false;
    }

    handleTitleChange(event)      { this.newNoteTitle   = event.target.value; }
    handleContentChange(event)    { this.newNoteContent = event.target.value; }
    handleNoteDateChange(event)   { this.newNoteDate    = event.target.value; }

    handleSaveNote() {
        if (!this.newNoteTitle?.trim()) {
            this.modalError = 'Title is required.';
            return;
        }
        if (!this.newNoteDate) {
            this.modalError = 'Date is required.';
            return;
        }

        this.modalError = '';
        this.isSaving   = true;

        saveNote({
            recordId: this.recordId,
            isAlumni: this.isAlumni,
            title:    this.newNoteTitle.trim(),
            content:  this.newNoteContent || '',
            noteDate: this.newNoteDate
        })
            .then(() => {
                this.isSaving  = false;
                this.showForm  = false;
                this.showToast('Success', 'Note saved successfully.', 'success');
                return refreshApex(this._wiredNotesResult);
            })
            .catch(error => {
                this.isSaving   = false;
                this.modalError = error.body?.message || 'An error occurred while saving.';
            });
    }

    // =========================================================================
    // Utility
    // =========================================================================
    _resetForm() {
        this.newNoteTitle   = '';
        this.newNoteContent = '';
        this.newNoteDate    = new Date().toISOString().split('T')[0];
        this.modalError     = '';
        this.isSaving       = false;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}