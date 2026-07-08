import { api, LightningElement, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getGivingInfo from '@salesforce/apex/HamCCGivingInfoController.getGivingInfo';
import getContactAccountData from '@salesforce/apex/HamCCGivingInfoController.getContactAccountData';
import getContactFullData from '@salesforce/apex/HamCCGivingInfoController.getContactFullData';

// Badge resources
import badge1812 from '@salesforce/resourceUrl/HAMBadgeFor1812';
import badge10to5 from '@salesforce/resourceUrl/HAM10To5';
import alumniCouncil from '@salesforce/resourceUrl/HAMAlumniCouncil';
import chapelBell from '@salesforce/resourceUrl/HAMChapelBell';
import CoperGuild from '@salesforce/resourceUrl/HAMCouperGuild';
import founderCircle from '@salesforce/resourceUrl/HAMFoundersCircle';
import jBABadge from '@salesforce/resourceUrl/HAMJBABadge';
import trusteebadge from '@salesforce/resourceUrl/HAMTrusteeBadge';

export default class HamCCGivingInfo extends LightningElement {
    /* =====================
     * Public API
     * ===================== */
    @api recordId;
    @api isAlumni;

    /* =====================
     * Badge assets
     * ===================== */
    badgeFor1812 = badge1812;
    badgeFor10to5 = badge10to5;
    badgeAC = alumniCouncil;
    badgeCB = chapelBell;
    badgeCG = CoperGuild;
    badgeFC = founderCircle;
    badgeForJBA = jBABadge;
    badgeTrustee = trusteebadge;

    /* =====================
     * Summary values
     * ===================== */
    totalLifetimeGiving = 0;
    largestGift = 0;
    thisYear = 0;
    yearsOfGiving = 0;

    showThisYear = false;
    showYearsOfGiving = false;

    /* =====================
     * Badge flags
     * ===================== */
    showBadge1812 = false;
    showBadge10to5 = false;
    showBadgeAC = false;
    showBadgeCB = false;
    showBadgeCG = false;
    showBadgeFC = false;
    showBadgeJBA = false;
    showBadgeTrustee = false;

    /* =====================
     * Datatable config
     * ===================== */
    columns = [
        { label: 'Fiscal Year', fieldName: 'HAM_Fiscal_Year__c', type: 'text', sortable: true },
        { label: 'Purpose', fieldName: 'HAM_Designation__c', type: 'text', sortable: true },
        {
            label: 'Pledged',
            fieldName: 'HAM_Pledged__c',
            type: 'currency',
            typeAttributes: { currencyCode: 'USD' },
            sortable: true
        },
        {
            label: 'Paid',
            fieldName: 'HAM_Paid__c',
            type: 'currency',
            typeAttributes: { currencyCode: 'USD' },
            sortable: true
        },
        {
            label: 'Created Date',
            fieldName: 'CreatedDate',
            type: 'date',
            typeAttributes: { year: 'numeric', month: '2-digit', day: '2-digit' },
            sortable: true
        }
    ];

    /* =====================
     * Data + Pagination
     * ===================== */
    givingInfoData = [];
    paginatedData = [];

    pageSize = 5;
    currentPage = 1;
    totalPages = 0;

    sortedBy = 'HAM_Fiscal_Year__c';
    sortedDirection = 'desc';

    /* =====================
     * Derived state
     * ===================== */
    get hasData() {
        return this.paginatedData.length > 0;
    }

    get isFirstPage() {
        return this.currentPage === 1;
    }

    get isLastPage() {
        return this.currentPage === this.totalPages || this.totalPages === 0;
    }

    /* =====================
     * Accordion state
     * ===================== */
    isExpanded = true;

    get activeSectionIcon() {
        return this.isExpanded ? 'utility:chevrondown' : 'utility:chevronright';
    }

    handleAccordionToggle = () => {
        this.isExpanded = !this.isExpanded;
    };

    /* =====================
     * Page reference params
     * ===================== */
    @wire(CurrentPageReference)
    getStateParameters(ref) {
        if (ref?.state?.c__recordId && !this.recordId) {
            this.recordId = ref.state.c__recordId;
        }

        if (ref?.state?.c__isAlumni !== undefined) {
            this.isAlumni = ref.state.c__isAlumni === true || ref.state.c__isAlumni === 'true';
        }
    }

    /* =====================
     * Badge contact data
     * ===================== */
    @wire(getContactFullData, { contactId: '$recordId' })
    wiredContactData({ data, error }) {
        if (data) {
            this.processBadgeFlags(data);
        } else if (error) {
            console.error('Contact badge error', error);
        }
    }

    /* =====================
     * Giving table data
     * ===================== */
    @wire(getGivingInfo, { recordId: '$recordId', isAlumni: '$isAlumni' })
    wiredGivingInfo({ data, error }) {
        if (data) {
            this.givingInfoData = data.map(row => ({
                ...row,
                id: row.Id
            }));

            this.currentPage = 1;
            this.sortData(this.sortedBy, this.sortedDirection);
            this.calculatePagination();
        } else if (error) {
            console.error('Giving info error', error);
            this.givingInfoData = [];
            this.paginatedData = [];
            this.totalPages = 0;
        }
    }

    /* =====================
     * Summary data
     * ===================== */
    @wire(getContactAccountData, { recordId: '$recordId', isAlumni: '$isAlumni' })
    wiredSummary({ data, error }) {
        if (data) {
            this.totalLifetimeGiving = data.lifetimeGiving || 0;
            this.largestGift = data.largestGift || 0;
            this.thisYear = data.thisYear || 0;
            this.yearsOfGiving = data.yearsOfGiving || 0;
            if (this.isAlumni) {
                this.showThisYear = true;
                this.showYearsOfGiving = true;
            } else {
                this.thisYear = data.thisYear || 0;
                this.yearsOfGiving = data.yearsOfGiving || 0;
                this.showThisYear = false;
                this.showYearsOfGiving = false;
            }
        } else if (error) {
            console.error('Summary error', error);
        }
    }

    /* =====================
     * Badge logic
     * ===================== */
    processBadgeFlags(c) {
        this.showBadge1812 = !!c.HAM_1812__c;
        this.showBadge10to5 = !!c.HAM_Ten_to_Fifth__c;
        this.showBadgeAC = !!c.HAM_Alumni_Council__c;
        this.showBadgeCB = !!c.HAM_Chapel_Bell__c;
        this.showBadgeCG = !!c.HAM_Couper_Guild__c;
        this.showBadgeFC = !!c.HAM_Founders_Circle__c;
        this.showBadgeJBA = !!c.HAM_JBA__c;
        this.showBadgeTrustee = !!c.HAM_Trustee__c;
    }

    /* =====================
     * Sorting + Pagination
     * ===================== */
    handleSort(event) {
        this.sortedBy = event.detail.fieldName;
        this.sortedDirection = event.detail.sortDirection;
        this.sortData(this.sortedBy, this.sortedDirection);
        this.calculatePagination();
    }

    sortData(field, direction) {
        const data = [...this.givingInfoData];
        data.sort((a, b) => {
            let x = a[field] ?? '';
            let y = b[field] ?? '';

            if (typeof x === 'string') x = x.toLowerCase();
            if (typeof y === 'string') y = y.toLowerCase();

            return direction === 'asc' ? (x > y ? 1 : -1) : (x < y ? 1 : -1);
        });
        this.givingInfoData = data;
    }

    calculatePagination() {
        this.totalPages = Math.ceil(this.givingInfoData.length / this.pageSize);
        this.paginateData();
    }

    paginateData() {
        const start = (this.currentPage - 1) * this.pageSize;
        const end = start + this.pageSize;
        this.paginatedData = this.givingInfoData.slice(start, end);
    }

    handlePrevious() {
        if (!this.isFirstPage) {
            this.currentPage--;
            this.paginateData();
        }
    }

    handleNext() {
        if (!this.isLastPage) {
            this.currentPage++;
            this.paginateData();
        }
    }

    handleFirst() {
        this.currentPage = 1;
        this.paginateData();
    }

    handleLast() {
        this.currentPage = this.totalPages;
        this.paginateData();
    }

    handleRefresh() {
        // Wired methods auto-refresh when params change
        this.currentPage = 1;
    }
}