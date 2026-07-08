import { LightningElement, api, track, wire } from 'lwc';
import getEventsDetail from '@salesforce/apex/HAMJediEventController.getEventsDetail';
import { CurrentPageReference } from 'lightning/navigation';

export default class HamJediEvents extends LightningElement {
    // =========================================
    // Responsive flag
    // =========================================
    @track isMobile = false;

    connectedCallback() {
        this.checkScreen();
        this._resizeHandler = this.checkScreen.bind(this);
        window.addEventListener('resize', this._resizeHandler);
    }

    disconnectedCallback() {
        window.removeEventListener('resize', this._resizeHandler);
    }

    checkScreen() {
        const mobile = window.innerWidth <= 768;
        if (this.isMobile !== mobile) {
            this.isMobile = mobile;
            this.pageSize = mobile ? 3 : 10;
            this.pageNumber = 1;
            this.derivePage();
        }
    }

    // =========================================
    // Accordion / Context
    // =========================================
    @track activeEventSection = 'Events';
    @api recordId;
    @track loading = false;

    // =========================================
    // Data model
    // =========================================
    @track allEvents = [];
    @track pageEvents = [];

    // =========================================
    // Sorting state
    // =========================================
    @track sortedBy = 'eventEndDate';
    @track sortedDirection = 'desc';

    // =========================================
    // Pagination
    // =========================================
    @track pageSize = 10;
    @track pageNumber = 1;
    @track totalRecords = 0;

    get totalPages() {
        return Math.max(1, Math.ceil(this.totalRecords / this.pageSize));
    }
    get isFirstPage() {
        return this.pageNumber <= 1;
    }
    get isLastPage() {
        return this.pageNumber >= this.totalPages || this.totalRecords === 0;
    }

    derivePage() {
        const start = (this.pageNumber - 1) * this.pageSize;
        const end = start + this.pageSize;
        this.pageEvents = this.allEvents.slice(start, end);
    }

    nextPage() {
        if (!this.isLastPage) {
            this.pageNumber += 1;
            this.derivePage();
        }
    }
    prevPage() {
        if (!this.isFirstPage) {
            this.pageNumber -= 1;
            this.derivePage();
        }
    }

    // =========================================
    // Datatable columns
    // =========================================
    @track eventsColumns = [
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
        {
            label: 'Event Name',
            fieldName: 'eventTitle',
            type: 'text',
            sortable: true
        },
        {
            label: 'Event Date',
            fieldName: 'eventEndDate',
            type: 'date',
            typeAttributes: {
                year: 'numeric',
                month: 'short',
                day: '2-digit',
                hour: '2-digit',
                minute: '2-digit'
            },
            sortable: true
        },
        {
            label: 'Status',
            fieldName: 'CventEvents__Status__c',
            type: 'text',
            sortable: true
        }
    ];

    // =========================================
    // Read recordId from URL and load data
    // =========================================
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference?.state?.c__recordId) {
            this.recordId = currentPageReference.state.c__recordId;
            this.loading = true;

            getEventsDetail({ contactId: this.recordId })
                .then(result => {
                    const rows = result || [];

                    // Flatten relationship fields into top-level keys for datatable binding
                    this.allEvents = rows.map(r => ({
                        ...r,
                        recordLink: `/lightning/r/${r.Id}/view`,
                        eventTitle:   r.CventEvents__Event__r?.CventEvents__pkg_Title__c   || '',
                        eventEndDate: r.CventEvents__Event__r?.CventEvents__pkg_EndDate__c  || null
                    }));

                    this.totalRecords = this.allEvents.length;

                    this.sortEventData(this.sortedBy, this.sortedDirection);

                    this.pageNumber = 1;
                    this.derivePage();

                    this.activeEventSection = 'Events';
                })
                .catch(error => {
                    console.error('Error fetching Events:', error);
                    this.allEvents = [];
                    this.pageEvents = [];
                    this.totalRecords = 0;
                    this.pageNumber = 1;
                })
                .finally(() => {
                    this.loading = false;
                });
        }
    }

    // =========================================
    // Accordion toggle handler
    // =========================================
    handleEventSectionToggle(event) {
        const openedSections = event.detail.openSections;
        if (Array.isArray(openedSections)) {
            this.activeEventSection = openedSections.includes('Events') ? 'Events' : '';
        } else {
            this.activeEventSection = openedSections === 'Events' ? 'Events' : '';
        }
    }

    // =========================================
    // Datatable sort handler
    // =========================================
    handleEventSort(event) {
        const { fieldName: sortedBy, sortDirection } = event.detail;
        this.sortedBy = sortedBy;
        this.sortedDirection = sortDirection;

        this.sortEventData(sortedBy, sortDirection);

        this.pageNumber = 1;
        this.derivePage();
    }

    sortEventData(field, direction) {
        const key = field === 'recordLink' ? 'Name' : field;
        const dir = direction === 'desc' ? -1 : 1;

        this.allEvents = [...this.allEvents].sort((a, b) => {
            let va = a[key] ?? '';
            let vb = b[key] ?? '';

            if (field === 'eventEndDate') {
                va = va ? new Date(va) : new Date(0);
                vb = vb ? new Date(vb) : new Date(0);
            } else {
                va = va.toString().toLowerCase();
                vb = vb.toString().toLowerCase();
            }

            if (va === vb) return 0;
            return va > vb ? dir : -dir;
        });
    }

    // =========================================
    // Mobile Sort
    // =========================================
    get mobileSortOptions() {
        return [
            { label: 'Event Date', value: 'eventEndDate' },
            { label: 'Name', value: 'Name' },
            { label: 'Event Name', value: 'eventTitle' },
            { label: 'Status', value: 'CventEvents__Status__c' }
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
        this.sortEventData(this.sortedBy, this.sortedDirection);
        this.pageNumber = 1;
        this.derivePage();
    }

    toggleMobileSortDirection() {
        this.sortedDirection = this.sortedDirection === 'asc' ? 'desc' : 'asc';
        this.sortEventData(this.sortedBy, this.sortedDirection);
        this.pageNumber = 1;
        this.derivePage();
    }

    // =========================================
    // Mobile card view data
    // =========================================
    get mobilePageEvents() {
        return this.pageEvents.map(r => {
            const rawDate = r.eventEndDate;
            let formattedDate = rawDate || '';
            if (rawDate) {
                const d = new Date(rawDate);
                formattedDate = d.toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' });
            }
            return {
                ...r,
                formattedDate
            };
        });
    }
}