import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { loadScript } from 'lightning/platformResourceLoader';
import getVolunteerDashboardData from '@salesforce/apex/HamCCVolunteerDashboardController.getVolunteerDashboardData';
import getEmployerDashboardData  from '@salesforce/apex/HamCCVolunteerDashboardController.getEmployerDashboardData';

// Static resource — confirmed name from FullQA org (agf namespace, Chart.js 2.7.3)
import CHARTJS from '@salesforce/resourceUrl/agf__chartjs_2_7_3_min_js';

// ── Colour palette ────────────────────────────────────────────────────────────
const BLUE_DARK   = '#185FA5';
const BLUE_MID    = '#378ADD';
const TEAL_MID    = '#1D9E75';
const PURPLE_MID  = '#7F77DD';
const ORANGE_MID  = '#E8750A';
const CHART_GRID  = 'rgba(0,0,0,0.06)';
const CHART_TEXT  = '#5F5E5A';

export default class HamccnewDashboard extends NavigationMixin(LightningElement) {

    // ── State ─────────────────────────────────────────────────────────────────
    @track isLoading     = true;
    @track hasError      = false;
    @track errorMessage  = '';
    @track showDashboard = false;

    // Alumni / Parents tab
    @track data          = null;

    // Employer Engagement tab
    @track employerData  = {
        hasData              : false,
        totalInvolvements    : 0,
        uniqueEmployers      : 0,
        currentCount         : 0,
        multiEngagementCount : 0,
        byCode               : [],
        byMonth              : [],
        topVolunteers        : []
    };

    @track activeTab = 'alumni';

    _chartJsLoaded  = false;
    _trendChart     = null;
    _classYearChart = null;
    _employerTrendChart = null;

    // Track whether each call has settled so we know when to flip showDashboard
    _volunteerDone  = false;
    _employerDone   = false;

    // ── Lifecycle ─────────────────────────────────────────────────────────────
    connectedCallback() {
        // Load Chart.js and both Apex methods in parallel.
        // Charts are rendered once all three are ready.
        Promise.all([
            loadScript(this, CHARTJS),
            this._loadVolunteerData(),
            this._loadEmployerData()
        ])
        .catch(() => {
            // Individual promise errors are handled inside each method;
        // Promise.all failure is surfaced only if Chart.js itself fails.
        })
        .finally(() => {
            // Chart.js is loaded; render charts if data arrived first
            this._chartJsLoaded = true;
            if (this.showDashboard) {
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                setTimeout(() => this._renderAllCharts(), 50);
            }
        });
    }

    disconnectedCallback() {
        [this._trendChart, this._classYearChart, this._employerTrendChart].forEach(c => {
            if (c) { try { c.destroy(); } catch(e) { /* ignore */ } }
        });
    }

    // ── Data loading ──────────────────────────────────────────────────────────

    _loadVolunteerData() {
        return getVolunteerDashboardData()
            .then(raw => {
                this.data = this._processVolunteerData(raw);
            })
            .catch(err => {
                this.hasError     = true;
                this.errorMessage = err?.body?.message || 'Error loading volunteer data.';
            })
            .finally(() => {
                this._volunteerDone = true;
                this._checkBothDone();
            });
    }

    _loadEmployerData() {
        return getEmployerDashboardData()
            .then(raw => {
                this.employerData = this._processEmployerData(raw);
            })
            .catch(err => {
                // Don't overwrite a volunteer error — append if needed
                if (!this.hasError) {
                    this.hasError     = true;
                    this.errorMessage = err?.body?.message || 'Error loading employer data.';
                }
            })
            .finally(() => {
                this._employerDone = true;
                this._checkBothDone();
            });
    }

    /** Flip showDashboard and render charts only when BOTH calls have settled. */
    _checkBothDone() {
        if (!this._volunteerDone || !this._employerDone) return;
        this.isLoading    = false;
        this.showDashboard = !this.hasError;
        if (this.showDashboard && this._chartJsLoaded) {
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => this._renderAllCharts(), 50);
        }
    }

    // ── Tab Handling ──────────────────────────────────────────────────────────
    // No lazy loading needed — both tabs are pre-populated.
    // Handler kept for activeTab tracking and any future use.
    handleTabSelect(event) {
        this.activeTab = event.detail.value;
    }

    // ── Data Processing ───────────────────────────────────────────────────────

    _processVolunteerData(raw) {
        if (!raw) return null;
        const byCode = (raw.byCode || []).map(row => ({
            ...row,
            barStyle: `width:${row.pct}%; background: linear-gradient(90deg, ${BLUE_DARK}, ${BLUE_MID});`
        }));
        const activeByCode = (raw.activeByCode || []).map(row => ({
            ...row,
            barStyle: `width:${row.pct}%; background: linear-gradient(90deg, ${TEAL_MID}, #28c98f);`
        }));
        const topVolunteers = (raw.topVolunteers || []).map(v => ({
            ...v,
            rowClass        : v.rank === 1 ? 'vol-row vol-row-top' : 'vol-row',
            statusBadgeClass: v.status === 'Current' ? 'status-badge status-current' : 'status-badge status-former',
            contactUrl      : `/lightning/r/Contact/${v.contactId}/view`
        }));
        return { ...raw, byCode, activeByCode, topVolunteers };
    }

    _processEmployerData(raw) {
        if (!raw) return this.employerData; // keep default empty shape
        const hasData = (raw.totalInvolvements || 0) > 0;
        const byCode  = (raw.byCode || []).map(row => ({
            ...row,
            barStyle: `width:${row.pct}%; background: linear-gradient(90deg, ${ORANGE_MID}, #f59e0b);`
        }));
        // topVolunteers from Apex carries accountId in contactId and accountName in contactName.
        // Remap contactUrl to Account view so the link navigates correctly.
        const topVolunteers = (raw.topVolunteers || []).map(v => ({
            ...v,
            rowClass        : v.rank === 1 ? 'vol-row vol-row-top' : 'vol-row',
            statusBadgeClass: v.status === 'Current' ? 'status-badge status-current' : 'status-badge status-former',
            contactUrl      : `/lightning/r/Account/${v.contactId}/view`
        }));
        return {
            ...raw,
            hasData,
            byCode,
            topVolunteers
        };
    }

    // ── Chart Rendering ───────────────────────────────────────────────────────

    /** Called once both data and Chart.js are ready — renders all three charts. */
    _renderAllCharts() {
        if (!window.Chart) return;
        this._renderTrendChart();
        this._renderClassYearChart();
        this._renderEmployerTrendChart();
    }

    _renderTrendChart() {
        const canvas = this.template.querySelector('.trend-chart-canvas');
        if (!canvas || !this.data) return;
        if (this._trendChart) { this._trendChart.destroy(); this._trendChart = null; }
        const months = (this.data.byMonth || []).map(m => m.label);
        const counts = (this.data.byMonth || []).map(m => m.total);
        // eslint-disable-next-line no-undef
        this._trendChart = new Chart(canvas.getContext('2d'), {
            type: 'bar',
            data: {
                labels: months,
                datasets: [{ label: 'Involvements', data: counts,
                    backgroundColor: BLUE_MID, borderColor: BLUE_DARK,
                    borderWidth: 1, borderRadius: 4 }]
            },
            options: {
                responsive: true, maintainAspectRatio: false,
                legend: { display: false },
                scales: {
                    xAxes: [{ gridLines: { color: CHART_GRID }, ticks: { fontColor: CHART_TEXT } }],
                    yAxes: [{ gridLines: { color: CHART_GRID }, ticks: { fontColor: CHART_TEXT, beginAtZero: true, precision: 0 } }]
                }
            }
        });
    }

    _renderClassYearChart() {
        const canvas = this.template.querySelector('.class-year-chart-canvas');
        if (!canvas || !this.data) return;
        if (this._classYearChart) { this._classYearChart.destroy(); this._classYearChart = null; }
        const years  = (this.data.byClassYear || []).map(c => c.yr);
        const counts = (this.data.byClassYear || []).map(c => c.total);
        // eslint-disable-next-line no-undef
        this._classYearChart = new Chart(canvas.getContext('2d'), {
            type: 'bar',
            data: {
                labels: years,
                datasets: [{ label: 'Involvements', data: counts,
                    backgroundColor: PURPLE_MID, borderColor: '#5a54b0',
                    borderWidth: 1, borderRadius: 4 }]
            },
            options: {
                responsive: true, maintainAspectRatio: false,
                legend: { display: false },
                scales: {
                    xAxes: [{ gridLines: { color: CHART_GRID }, ticks: { fontColor: CHART_TEXT } }],
                    yAxes: [{ gridLines: { color: CHART_GRID }, ticks: { fontColor: CHART_TEXT, beginAtZero: true, precision: 0 } }]
                }
            }
        });
    }

    _renderEmployerTrendChart() {
        const canvas = this.template.querySelector('.employer-trend-canvas');
        if (!canvas || !this.employerData?.hasData) return;
        if (this._employerTrendChart) { this._employerTrendChart.destroy(); this._employerTrendChart = null; }
        const months = (this.employerData.byMonth || []).map(m => m.label);
        const counts = (this.employerData.byMonth || []).map(m => m.total);
        // eslint-disable-next-line no-undef
        this._employerTrendChart = new Chart(canvas.getContext('2d'), {
            type: 'bar',
            data: {
                labels: months,
                datasets: [{ label: 'Employer Engagements', data: counts,
                    backgroundColor: ORANGE_MID, borderColor: '#c45c00',
                    borderWidth: 1, borderRadius: 4 }]
            },
            options: {
                responsive: true, maintainAspectRatio: false,
                legend: { display: false },
                scales: {
                    xAxes: [{ gridLines: { color: CHART_GRID }, ticks: { fontColor: CHART_TEXT } }],
                    yAxes: [{ gridLines: { color: CHART_GRID }, ticks: { fontColor: CHART_TEXT, beginAtZero: true, precision: 0 } }]
                }
            }
        });
    }

    // ── Navigation ────────────────────────────────────────────────────────────
    handleVolunteerClick(event) {
        event.preventDefault();
        const id = event.currentTarget.dataset.id;
        // contactId on alumni rows = Contact Id; on employer rows = Account Id
        // The row's contactUrl already points to the correct object via _processEmployerData
        this[NavigationMixin.Navigate]({
            type      : 'standard__recordPage',
            attributes: { recordId: id, actionName: 'view' }
        });
    }

    handleSearchClick(event) {
        event.preventDefault();
        this[NavigationMixin.Navigate]({
            type      : 'standard__navItemPage',
            attributes: { apiName: 'Jabba_Search' }
        });
    }
}