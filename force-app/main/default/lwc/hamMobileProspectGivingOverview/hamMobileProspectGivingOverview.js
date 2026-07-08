// =====================================================================
// hamMobileProspectGivingOverview.js
// v2.0 — Mobile-first card UI replacing lightning-datatables
// Aligned with hamJediContactReports card layout conventions
// =====================================================================
import { LightningElement, api, track, wire } from 'lwc';
import searchProspectGivingDetails      from '@salesforce/apex/HAMProspectOverviewApexController.searchProspectGivingDetails';
import { CurrentPageReference }          from 'lightning/navigation';
import { NavigationMixin }               from 'lightning/navigation';
import getCampaignDetail                 from '@salesforce/apex/HAMJEDIPledgeBalanceController.getCampaignDetail';
import getGivingByPurposeDetail          from '@salesforce/apex/HAMJEDIPledgeBalanceController.getGivingByPurposeDetail';
import { ShowToastEvent }                from 'lightning/platformShowToastEvent';
import badge1812        from '@salesforce/resourceUrl/HAMBadgeFor1812';
import badge10to5       from '@salesforce/resourceUrl/HAM10To5';
import alumniCouncil    from '@salesforce/resourceUrl/HAMAlumniCouncil';
import chapelBell       from '@salesforce/resourceUrl/HAMChapelBell';
import CoperGuild       from '@salesforce/resourceUrl/HAMCouperGuild';
import founderCircle    from '@salesforce/resourceUrl/HAMFoundersCircle';
import jBABadge         from '@salesforce/resourceUrl/HAMJBABadge';
import trusteebadge     from '@salesforce/resourceUrl/HAMTrusteeBadge';
import formURL          from '@salesforce/label/c.HAM_JEDI_Feedback_Link';
import canLoginAsUser   from '@salesforce/apex/HAMJediLoginToExperienceAsUserCtrl.canLoginAsUser';

export default class HamMobileProspectGivingOverview extends NavigationMixin(LightningElement) {

    // =========================================
    // Public / tracked properties
    // =========================================
    @api  contactgivingrecord;
    @api  recordId;
    @track activeGivingSectionBio = ['Giving Summary'];
    @track contactDetails;
    @track designationDetails = [];
    @track loading = false;

    // Badge URLs
    @track badgeFor1812   = badge1812;
    @track badgeFor10to5  = badge10to5;
    @track badgeAC        = alumniCouncil;
    @track badgeCB        = chapelBell;
    @track badgeCG        = CoperGuild;
    @track badgeFC        = founderCircle;
    @track badgeForJBA    = jBABadge;
    @track badgeTrustee   = trusteebadge;

    // Login-as button
    @track showLoginAsButton = false;

    // Modal state — Contact Report
    @track isContactReportModalOpen = false;
    @track contactReportFlowInputVariables = [];
    contactReportButtonRef = null;

    // Modal state — Ask Pipeline
    @track isAskPipelineModalOpen = false;
    @track askPipelineFlowInputVariables = [];
    @track isFlowLoading = true;
    askPipelineButtonRef = null;

    // =========================================
    // Giving by Designation — data & pagination
    // =========================================
    @track allGivingDetails    = [];
    @track pageGivingDetails   = [];
    @track givingPageSize      = 3;
    @track givingPageNumber    = 1;
    @track givingTotalRecords  = 0;
    @track givingSortedBy      = 'HAM_Pledged__c';
    @track givingSortedDirection = 'desc';

    get givingTotalPages()  { return Math.max(1, Math.ceil(this.givingTotalRecords / this.givingPageSize)); }
    get isGivingFirstPage() { return this.givingPageNumber <= 1; }
    get isGivingLastPage()  { return this.givingPageNumber >= this.givingTotalPages || this.givingTotalRecords === 0; }
    get showGivingPagination() { return this.givingTotalRecords > this.givingPageSize; }
    get hasGivingDetails()  { return this.pageGivingDetails && this.pageGivingDetails.length > 0; }

    // Sort button CSS helpers — active button gets highlighted
    get givingDesignationSortAmountClass() {
        return this.givingSortedBy === 'HAM_Pledged__c' ? 'sort-btn sort-btn--active' : 'sort-btn';
    }
    get givingDesignationSortPaidClass() {
        return this.givingSortedBy === 'HAM_Paid__c' ? 'sort-btn sort-btn--active' : 'sort-btn';
    }

    sortGivingByCommitted() { this._toggleGivingSort('HAM_Pledged__c'); }
    sortGivingByPaid()      { this._toggleGivingSort('HAM_Paid__c'); }

    _toggleGivingSort(field) {
        if (this.givingSortedBy === field) {
            this.givingSortedDirection = this.givingSortedDirection === 'desc' ? 'asc' : 'desc';
        } else {
            this.givingSortedBy = field;
            this.givingSortedDirection = 'desc';
        }
        this.sortGivingData(this.givingSortedBy, this.givingSortedDirection);
        this.givingPageNumber = 1;
        this.deriveGivingPage();
    }

    deriveGivingPage() {
        const start = (this.givingPageNumber - 1) * this.givingPageSize;
        this.pageGivingDetails = this.allGivingDetails.slice(start, start + this.givingPageSize);
    }

    nextGivingPage() {
        if (!this.isGivingLastPage) { this.givingPageNumber += 1; this.deriveGivingPage(); }
    }
    prevGivingPage() {
        if (!this.isGivingFirstPage) { this.givingPageNumber -= 1; this.deriveGivingPage(); }
    }

    sortGivingData(field, direction) {
        const dir = direction === 'desc' ? -1 : 1;
        this.allGivingDetails = [...this.allGivingDetails].sort((a, b) => {
            let va = parseFloat(a[field]) || 0;
            let vb = parseFloat(b[field]) || 0;
            return va === vb ? 0 : (va > vb ? dir : -dir);
        });
    }

    // =========================================
    // Giving by Campaign — data & pagination
    // =========================================
    @track allCampaignDetails    = [];
    @track pageCampaignDetails   = [];
    @track campaignPageSize      = 3;
    @track campaignPageNumber    = 1;
    @track campaignTotalRecords  = 0;
    @track campaignSortedBy      = 'HAM_Pledged__c';
    @track campaignSortedDirection = 'desc';

    get campaignTotalPages()  { return Math.max(1, Math.ceil(this.campaignTotalRecords / this.campaignPageSize)); }
    get isCampaignFirstPage() { return this.campaignPageNumber <= 1; }
    get isCampaignLastPage()  { return this.campaignPageNumber >= this.campaignTotalPages || this.campaignTotalRecords === 0; }
    get showCampaignPagination() { return this.campaignTotalRecords > this.campaignPageSize; }
    get hasCampaignDetails()  { return this.pageCampaignDetails && this.pageCampaignDetails.length > 0; }

    // Sort button CSS helpers
    get campaignSortAmountClass() {
        return this.campaignSortedBy === 'HAM_Pledged__c' ? 'sort-btn sort-btn--active' : 'sort-btn';
    }
    get campaignSortPaidClass() {
        return this.campaignSortedBy === 'HAM_Paid__c' ? 'sort-btn sort-btn--active' : 'sort-btn';
    }

    sortCampaignByCommitted() { this._toggleCampaignSort('HAM_Pledged__c'); }
    sortCampaignByPaid()      { this._toggleCampaignSort('HAM_Paid__c'); }

    _toggleCampaignSort(field) {
        if (this.campaignSortedBy === field) {
            this.campaignSortedDirection = this.campaignSortedDirection === 'desc' ? 'asc' : 'desc';
        } else {
            this.campaignSortedBy = field;
            this.campaignSortedDirection = 'desc';
        }
        this.sortCampaignData(this.campaignSortedBy, this.campaignSortedDirection);
        this.campaignPageNumber = 1;
        this.deriveCampaignPage();
    }

    deriveCampaignPage() {
        const start = (this.campaignPageNumber - 1) * this.campaignPageSize;
        this.pageCampaignDetails = this.allCampaignDetails.slice(start, start + this.campaignPageSize);
    }

    nextCampaignPage() {
        if (!this.isCampaignLastPage) { this.campaignPageNumber += 1; this.deriveCampaignPage(); }
    }
    prevCampaignPage() {
        if (!this.isCampaignFirstPage) { this.campaignPageNumber -= 1; this.deriveCampaignPage(); }
    }

    sortCampaignData(field, direction) {
        const dir = direction === 'desc' ? -1 : 1;
        this.allCampaignDetails = [...this.allCampaignDetails].sort((a, b) => {
            let va = parseFloat(a[field]) || 0;
            let vb = parseFloat(b[field]) || 0;
            return va === vb ? 0 : (va > vb ? dir : -dir);
        });
    }

    // =========================================
    // Named Funds helper
    // =========================================
    get hasDesignations() {
        return this.designationDetails && this.designationDetails.length > 0;
    }

    // =========================================
    // Data Loading — wired page reference
    // =========================================
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference?.state?.c__recordId) {
            this.recordId = currentPageReference.state.c__recordId;

            canLoginAsUser({ contactId: this.recordId })
                .then(result => { this.showLoginAsButton = result; })
                .catch(() => { this.showLoginAsButton = false; });

            this.loading = true;

            // Load prospect summary first (fast path)
            searchProspectGivingDetails({ contactId: this.recordId })
                .then(result => {
                    this._processProspectResult(result);
                })
                .catch(error => {
                    console.error('Error fetching Prospect:', error);
                })
                .finally(() => {
                    this.loading = false;
                });

            // Load giving detail tables in parallel
            Promise.all([
                getGivingByPurposeDetail({ contactId: this.recordId }),
                getCampaignDetail({ contactId: this.recordId })
            ])
            .then(([givingResult, campaignResult]) => {
                this._processGivingResult(givingResult);
                this._processCampaignResult(campaignResult);
            })
            .catch(error => {
                console.error('Error fetching giving/campaign data:', error);
            });
        }
    }

    // =========================================
    // Private helpers — data processors
    // =========================================
    _processProspectResult(result) {
        this.contactgivingrecord = result;
        this.contactDetails      = result.objRecord;
        this.designationDetails  = (result.designations || []).map(fund => ({
            ...fund,
            recordLink: `/lightning/r/${fund.Id}/view`
        }));
    }

    _processGivingResult(givingResult) {
        this.allGivingDetails   = givingResult || [];
        this.givingTotalRecords = this.allGivingDetails.length;
        this.sortGivingData(this.givingSortedBy, this.givingSortedDirection);
        this.givingPageNumber = 1;
        this.deriveGivingPage();
    }

    _processCampaignResult(campaignResult) {
        this.allCampaignDetails   = campaignResult || [];
        this.campaignTotalRecords = this.allCampaignDetails.length;
        this.sortCampaignData(this.campaignSortedBy, this.campaignSortedDirection);
        this.campaignPageNumber = 1;
        this.deriveCampaignPage();
    }

    // =========================================
    // Accordion toggle
    // =========================================
    handleGivingSectionToggle(event) {
        this.activeGivingSectionBio = event.detail.openSections;
    }

    // =========================================
    // Navigation helpers
    // =========================================
    loginAsExperienceUser() {
        window.open('/apex/HAMLoginToExperienceAsUser?contactId=' + this.recordId, '_blank');
    }

    navigateToHelp() {
        window.open(formURL, '_blank');
    }

    navigateToPresidentialBriefing() {
        const baseUrl = window.location.origin;
        window.open(`${baseUrl}/lightning/cmp/c__digitalBriefingPdfCmp?c__recordId=${this.recordId}`, '_blank');
    }

    // =========================================
    // Contact Report Modal
    // =========================================
    openContactReportModal(event) {
        this.contactReportButtonRef = event.target;
        this.contactReportFlowInputVariables = [{ name: 'contactId', type: 'String', value: this.recordId }];
        this.isContactReportModalOpen = true;
    }

    closeContactReportModal() {
        this.isContactReportModalOpen = false;
        if (this.contactReportButtonRef) {
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => {
                this.contactReportButtonRef.scrollIntoView({ behavior: 'smooth', block: 'center' });
            }, 100);
        }
    }

    handleContactReportFlowStatusChange(event) {
        const status = event.detail.status;
        if (status === 'STARTED' || status === 'PAUSED') {
            const modal = this.template.querySelector('[data-id="contactReportModal"]');
            if (modal) modal.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }
        if (status === 'FINISHED' || status === 'FINISHED_SCREEN') {
            this.closeContactReportModal();
            this.dispatchEvent(new ShowToastEvent({ title: 'Success', message: 'Contact Report created successfully', variant: 'success' }));
            this.refreshAllData();
        }
    }

    // =========================================
    // Ask Pipeline Modal
    // =========================================
    openAskPipelineModal(event) {
        const accountId = this.contactDetails?.AccountId;
        if (!accountId) { console.error('No Account ID found for this contact'); return; }
        this.askPipelineButtonRef = event.target;
        this.askPipelineFlowInputVariables = [{ name: 'recordId', type: 'String', value: accountId }];
        this.isFlowLoading = true;
        this.isAskPipelineModalOpen = true;
    }

    closeAskPipelineModal() {
        this.isAskPipelineModalOpen = false;
        this.isFlowLoading = true;
        if (this.askPipelineButtonRef) {
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => {
                this.askPipelineButtonRef.scrollIntoView({ behavior: 'smooth', block: 'center' });
            }, 100);
        }
    }

    handleAskPipelineFlowStatusChange(event) {
        const status = event.detail.status;
        if (status === 'STARTED' || status === 'PAUSED') {
            this.isFlowLoading = false;
            const modal = this.template.querySelector('[data-id="askPipelineModal"]');
            if (modal) modal.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }
        if (status === 'FINISHED' || status === 'FINISHED_SCREEN') {
            this.closeAskPipelineModal();
            this.dispatchEvent(new ShowToastEvent({ title: 'Success', message: 'Ask Pipeline Form submitted successfully', variant: 'success' }));
            this.refreshAllData();
        }
    }

    // =========================================
    // Full refresh (post-modal)
    // =========================================
    refreshAllData() {
        if (!this.recordId) return;
        this.loading = true;
        Promise.all([
            searchProspectGivingDetails({ contactId: this.recordId }),
            getGivingByPurposeDetail({ contactId: this.recordId }),
            getCampaignDetail({ contactId: this.recordId })
        ])
        .then(([prospectResult, givingResult, campaignResult]) => {
            this._processProspectResult(prospectResult);
            this._processGivingResult(givingResult);
            this._processCampaignResult(campaignResult);
        })
        .catch(error => {
            console.error('Error refreshing all data:', error);
        })
        .finally(() => {
            this.loading = false;
        });
    }
}