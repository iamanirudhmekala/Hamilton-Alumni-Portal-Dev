import { api, LightningElement, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { CurrentPageReference } from 'lightning/navigation';
import getContactReports from '@salesforce/apex/HamCCContactReportController.getContactReports';
import saveContactReport from '@salesforce/apex/HamCCContactReportController.saveContactReport';
import amplifyContactReport from '@salesforce/apex/HamCCContactReportController.amplifyContactReport';

export default class HamCCContactReport extends LightningElement {
    @api recordId;
    @api isAlumni;

    @track allContactReports = [];
    @track originalContactReports = [];
    @track pagedContactReports = [];
    @track recordsCount = 0;
    @track currentPage = 1;
    pageSize = 10;
    @track sortedBy = 'ucinn_ascendv2__Date__c';
    @track sortedDirection = 'desc';

    @track isExpanded = true;

    @track showFilters = false;
    @track filterStartDate = '';
    @track filterEndDate = '';
    @track filterPublishToListserv = '';
    @track filterIsCareerCenterSpecific = '';
    @track filterSearchText = '';

    @track amplifyingRowId = null;

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
    // Columns (desktop datatable)
    // =========================================================================
    get columns() {
        return [
            {
                label: 'Name',
                fieldName: 'recordLink',
                type: 'url',
                typeAttributes: {
                    label: { fieldName: 'Name' },
                    target: '_blank'
                },
                sortable: true
            },
            { label: 'Summary',               fieldName: 'ucinn_ascendv2__Description__c',         type: 'text', sortable: true },
            { label: 'Key Point/Description', fieldName: 'ucinn_ascendv2__Contact_Report_Body__c',  type: 'text', sortable: true },
            { label: 'Date',                  fieldName: 'ucinn_ascendv2__Date__c',                 type: 'date', sortable: true },
            { label: 'PRM at the time of Meeting', fieldName: 'HAM_PRM_at_Time_of_Meeting__c',      type: 'text', sortable: true },
            { label: 'Publish to listserv',   fieldName: 'HAM_Publish_to_Listserv__c',             type: 'text', sortable: true },
            { label: 'Submitted By',          fieldName: 'LastModifiedByName',                      type: 'text', sortable: true },
            {
                label: 'Actions',
                type: 'button',
                typeAttributes: {
                    label: 'Amplify',
                    name: 'amplify',
                    title: 'Send this contact report to the amplify group',
                    variant: 'brand',
                    iconName: 'utility:broadcast',
                    iconPosition: 'left',
                    disabled: { fieldName: 'isAmplifying' }
                },
                cellAttributes: { alignment: 'center' },
                fixedWidth: 155
            }
        ];
    }

    isLoading = false;
    isFlowModalOpen = false;
    flowInputVariables = [];
    createReportButtonRef = null;

    // =========================================================================
    // Computed helpers
    // =========================================================================
    get accordionIconName() {
        return this.isExpanded ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get hasData()         { return this.recordsCount > 0; }
    get totalPages()      { return Math.ceil(this.recordsCount / this.pageSize); }
    get showPagination()  { return this.recordsCount > this.pageSize; }
    get previousDisabled(){ return this.currentPage === 1; }
    get nextDisabled()    { return this.currentPage === this.totalPages; }

    get paginationInfo() {
        const start = (this.currentPage - 1) * this.pageSize;
        const end   = start + this.pageSize;
        return {
            startIndex: start + 1,
            endIndex: Math.min(end, this.recordsCount)
        };
    }

    get publishToListservOptions() {
        return [
            { label: '--None--', value: '' },
            { label: 'Yes',      value: 'Yes' },
            { label: 'No',       value: 'No' }
        ];
    }

    get isCareerCenterSpecificOptions() {
        return [
            { label: '--None--', value: '' },
            { label: 'Yes',      value: 'true' },
            { label: 'No',       value: 'false' }
        ];
    }

    get filtersButtonLabel() { return this.showFilters ? 'Hide Filters' : 'Filters'; }

    // =========================================================================
    // Mobile sort helpers
    // =========================================================================
    get mobileSortOptions() {
        return [
            { label: 'Date',           value: 'ucinn_ascendv2__Date__c' },
            { label: 'Name',           value: 'Name' },
            { label: 'Summary',        value: 'ucinn_ascendv2__Description__c' },
            { label: 'Submitted By',   value: 'LastModifiedByName' },
            { label: 'Publish to Listserv', value: 'HAM_Publish_to_Listserv__c' }
        ];
    }

    get mobileSortDirectionIcon() {
        return this.sortedDirection === 'asc' ? 'utility:arrowup' : 'utility:arrowdown';
    }

    get mobileSortDirectionLabel() {
        return this.sortedDirection === 'asc' ? 'Ascending' : 'Descending';
    }

    handleMobileSortChange(event) {
        this.sortedBy = event.detail.value;
        this.sortContactReportData(this.sortedBy, this.sortedDirection);
        this.currentPage = 1;
        this.updatePaginationInfo();
    }

    toggleMobileSortDirection() {
        this.sortedDirection = this.sortedDirection === 'asc' ? 'desc' : 'asc';
        this.sortContactReportData(this.sortedBy, this.sortedDirection);
        this.currentPage = 1;
        this.updatePaginationInfo();
    }

    // =========================================================================
    // Mobile card row actions — mirrors datatable's rowActions list
    // =========================================================================
    get rowActions() {
        return [
            { label: 'Amplify', name: 'amplify' }
        ];
    }

    /**
     * Fired by lightning-button-menu onselect in a mobile card.
     * Synthesises the same event shape lightning-datatable fires for onrowaction
     * so handleRowAction can be reused without duplication.
     */
    handleCardAction(event) {
        const actionName = event.detail.value;
        const recordId   = event.currentTarget.dataset.recordId;
        const row        = this.pagedContactReports.find(r => r.Id === recordId);
        if (!row) return;

        this.handleRowAction({
            detail: {
                action: { name: actionName },
                row
            }
        });
    }

    // =========================================================================
    // Mobile card show-more / show-less
    // =========================================================================
    toggleShowMore(event) {
        const reportId = event.currentTarget.dataset.id;
        if (this._expandedIds.has(reportId)) {
            this._expandedIds.delete(reportId);
        } else {
            this._expandedIds.add(reportId);
        }
        // Force re-render of the computed getter by re-slicing
        this.updatePaginationInfo();
    }

    /**
     * Computed list consumed by the mobile card template.
     * Mirrors mobilePageReports in file 4, adapted to file 3's field names.
     */
    get mobilePageReports() {
        const maxLen = 100;
        return this.pagedContactReports.map(r => {
            const body        = r.ucinn_ascendv2__Contact_Report_Body__c || '';
            const isExpanded  = this._expandedIds.has(r.Id);
            const needsTruncation = body.length > maxLen;

            const rawDate = r.ucinn_ascendv2__Date__c;
            let formattedDate = rawDate || '';
            if (rawDate) {
                const d = new Date(rawDate + 'T00:00:00');
                formattedDate = d.toLocaleDateString('en-US', {
                    year: 'numeric', month: 'short', day: 'numeric'
                });
            }

            return {
                ...r,
                displayBody:   isExpanded || !needsTruncation ? body : body.substring(0, maxLen) + '...',
                showMoreLabel: isExpanded ? 'Show Less' : 'Show More',
                needsTruncation,
                formattedDate
            };
        });
    }

    // =========================================================================
    // Wire + data loading
    // =========================================================================
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference?.state?.c__recordId && !this.recordId) {
            this.recordId = currentPageReference.state.c__recordId;
        }
        if (currentPageReference && currentPageReference.state) {
            let param = currentPageReference.state.c__isAlumni;
            if (param !== undefined) {
                this.isAlumni = param === 'true' || param === true;
            } else if (this.isAlumni === undefined) {
                this.isAlumni = true;
            }
        }
    }

    @wire(getContactReports, { recordId: '$recordId', isAlumni: '$isAlumni' })
    wiredContactReports({ error, data }) {
        if (data) {
            const processedData = data.map(report => ({
                ...report,
                recordLink: report.Id ? `/lightning/r/${report.Id}/view` : null,
                LastModifiedByName: report.LastModifiedBy?.Name || '',
                isAmplifying: false
            }));
            this.allContactReports      = processedData;
            this.originalContactReports = [...processedData];
            this.recordsCount           = this.allContactReports.length;
            this.currentPage            = 1;
            this.updatePaginationInfo();
        } else if (error) {
            this.allContactReports      = [];
            this.originalContactReports = [];
            this.recordsCount           = 0;
            this.pagedContactReports    = [];
        }
    }

    // =========================================================================
    // Filters
    // =========================================================================
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    handleFiltersToggle()               { this.showFilters = !this.showFilters; }
    handleStartDateChange(event)        { this.filterStartDate = event.target.value; }
    handleEndDateChange(event)          { this.filterEndDate   = event.target.value; }
    handlePublishToListservChange(e)    { this.filterPublishToListserv       = e.detail.value; }
    handleIsCareerCenterSpecificChange(e){ this.filterIsCareerCenterSpecific = e.detail.value; }
    handleSearchTextChange(event)       { this.filterSearchText = event.target.value; }
    handleSearchKeyDown(event)          { if (event.key === 'Enter') this.handleSearchFilters(); }

    handleSearchFilters() {
        let filtered = [...this.originalContactReports];

        if (this.filterStartDate || this.filterEndDate) {
            filtered = filtered.filter(r => {
                const d = r.ucinn_ascendv2__Date__c;
                if (!d) return false;
                if (this.filterStartDate && !this.filterEndDate) return d >= this.filterStartDate;
                if (!this.filterStartDate && this.filterEndDate) return d <= this.filterEndDate;
                return d >= this.filterStartDate && d <= this.filterEndDate;
            });
        }

        if (this.filterSearchText) {
            const kw = this.filterSearchText.toLowerCase();
            filtered = filtered.filter(r =>
                (r.ucinn_ascendv2__Description__c         || '').toLowerCase().includes(kw) ||
                (r.ucinn_ascendv2__Contact_Report_Body__c || '').toLowerCase().includes(kw)
            );
        }

        if (this.filterPublishToListserv) {
            filtered = filtered.filter(r => r.HAM_Publish_to_Listserv__c === this.filterPublishToListserv);
        }

        if (this.filterIsCareerCenterSpecific) {
            const bool = this.filterIsCareerCenterSpecific === 'true';
            filtered = filtered.filter(r => r.HAM_Is_Career_Center_Specific_CR__c === bool);
        }

        this.allContactReports = [...filtered];
        this.recordsCount      = this.allContactReports.length;
        this.sortContactReportData(this.sortedBy, this.sortedDirection);
        this.currentPage = 1;
        this.updatePaginationInfo();
    }

    handleClearFilters() {
        this.filterStartDate              = '';
        this.filterEndDate                = '';
        this.filterPublishToListserv      = '';
        this.filterIsCareerCenterSpecific = '';
        this.filterSearchText             = '';

        this.allContactReports = [...this.originalContactReports];
        this.recordsCount      = this.allContactReports.length;
        this.sortContactReportData(this.sortedBy, this.sortedDirection);
        this.currentPage = 1;
        this.updatePaginationInfo();
    }

    // =========================================================================
    // Flow modal
    // =========================================================================
    handleRefresh() {
        this.isLoading  = true;
        this.currentPage = 1;
        this.updatePaginationInfo();
        setTimeout(() => { this.isLoading = false; }, 300);
    }

    openFlowModal(event) {
        this.createReportButtonRef = event?.target || null;
        this.flowInputVariables = [{ name: 'contactId', type: 'String', value: this.recordId }];
        this.isFlowModalOpen = true;
    }

    closeFlowModal() {
        this.isFlowModalOpen = false;
        this.handleRefresh();
    }

    handleFlowStatusChange(event) {
        if (event.detail.status === 'FINISHED' || event.detail.status === 'FINISHED_SCREEN') {
            this.closeFlowModal();
        }
    }

    handleSaveReport(event) {
        const report = event.detail.report;
        this.isLoading = true;
        saveContactReport({ report })
            .then(() => {
                this.showToast('Success', 'Contact report saved successfully', 'success');
                this.handleRefresh();
            })
            .catch(error => {
                this.showToast('Error', 'Failed to save contact report: ' + error.body.message, 'error');
                this.isLoading = false;
            });
    }

    // =========================================================================
    // Amplify
    // =========================================================================
    handleRowAction(event) {
        const { action, row } = event.detail;
        if (action.name === 'amplify') {
            this.handleAmplify(row.Id);
        }
    }

    handleAmplify(reportId) {
        this.setRowAmplifying(reportId, true);

        amplifyContactReport({ reportId })
            .then(sentCount => {
                this.showToast(
                    'Email Amplified',
                    `Contact report successfully sent to ${sentCount} recipient${sentCount !== 1 ? 's' : ''}.`,
                    'success'
                );
            })
            .catch(error => {
                const msg = error?.body?.message || 'An unexpected error occurred while amplifying the contact report.';
                this.showToast('Amplify Failed', msg, 'error');
            })
            .finally(() => {
                this.setRowAmplifying(reportId, false);
            });
    }

    setRowAmplifying(reportId, value) {
        const toggle = arr => arr.map(r => r.Id === reportId ? { ...r, isAmplifying: value } : r);
        this.allContactReports      = toggle(this.allContactReports);
        this.originalContactReports = toggle(this.originalContactReports);
        this.updatePaginationInfo();
    }

    // =========================================================================
    // Sorting + Pagination
    // =========================================================================
    updatePaginationInfo() {
        const start = (this.currentPage - 1) * this.pageSize;
        const end   = start + this.pageSize;

        let sorted = [...this.allContactReports];
        if (this.sortedBy && this.sortedDirection) {
            sorted = sorted.sort((a, b) => {
                let av = a[this.sortedBy] ?? '';
                let bv = b[this.sortedBy] ?? '';
                if (typeof av === 'string') { av = av.toLowerCase(); bv = bv.toLowerCase(); }
                return this.sortedDirection === 'asc' ? (av > bv ? 1 : -1) : (av < bv ? 1 : -1);
            });
        }
        this.pagedContactReports = sorted.slice(start, end);
    }

    sortContactReportData(field, direction) {
        const key = field === 'recordLink' ? 'Name' : field;
        const dir = direction === 'desc' ? -1 : 1;
        this.allContactReports = [...this.allContactReports].sort((a, b) => {
            const va = (a[key] ?? '').toString().toLowerCase();
            const vb = (b[key] ?? '').toString().toLowerCase();
            return va === vb ? 0 : (va > vb ? dir : -dir);
        });
    }

    handleSort(event) {
        const { fieldName, sortDirection } = event.detail;
        this.sortedBy        = fieldName;
        this.sortedDirection = sortDirection;
        this.currentPage     = 1;
        this.updatePaginationInfo();
    }

    handlePrevious() {
        if (this.currentPage > 1) { this.currentPage--; this.updatePaginationInfo(); }
    }

    handleNext() {
        if (this.currentPage < this.totalPages) { this.currentPage++; this.updatePaginationInfo(); }
    }

    handleAccordionToggle() { this.isExpanded = !this.isExpanded; }
}