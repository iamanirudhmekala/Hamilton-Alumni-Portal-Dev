import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { loadScript } from 'lightning/platformResourceLoader';
import getDashboardData from '@salesforce/apex/HamCCVolunteerDashboardController.getDashboardData';

// agf-namespaced static resource (confirmed from org Static Resources)
import CHARTJS from '@salesforce/resourceUrl/agf__chartjs_2_7_3_min_js';

// ── Colour palette (matching reference HTML) ─────────────────────────────────
const BLUE_MID   = '#378ADD';
const BLUE_DARK  = '#185FA5';
const TEAL_MID   = '#1D9E75';
const PURPLE_MID = '#7F77DD';
const CHART_GRID = 'rgba(0,0,0,0.06)';
const CHART_TEXT = '#888780';

export default class HamCCVolunteerDashboard extends NavigationMixin(LightningElement) {

    // ── State ────────────────────────────────────────────────────────────────
    @track isLoading     = true;
    @track hasError      = false;
    @track errorMessage  = '';
    @track showDashboard = false;
    @track data          = null;

    // Calendar year labels for the monthly chart legend
    @track prevCalYear = '';
    @track currCalYear = '';

    _chartJsLoaded   = false;
    _trendChart      = null;
    _classYearChart  = null;

    // ── Wire ─────────────────────────────────────────────────────────────────
    @wire(getDashboardData)
    wiredData({ data, error }) {
        if (data) {
            this._processData(data);
        } else if (error) {
            this.isLoading   = false;
            this.hasError    = true;
            this.errorMessage = error?.body?.message || 'Unexpected error loading dashboard data.';
        }
    }

    // ── Lifecycle ────────────────────────────────────────────────────────────
    connectedCallback() {
        loadScript(this, CHARTJS)
            .then(() => {
                this._chartJsLoaded = true;
                if (this.data) this._renderCharts();
            })
            .catch(err => {
                this.isLoading    = false;
                this.hasError     = true;
                this.errorMessage = 'Failed to load Chart.js: ' + (err?.message || err);
            });
    }

    disconnectedCallback() {
        [this._trendChart, this._classYearChart].forEach(c => {
            if (c) { try { c.destroy(); } catch(e) { /* ignore */ } }
        });
    }

    // ── Data Processing ──────────────────────────────────────────────────────
    _processData(raw) {
        // Compute bar widths + pct labels for byCode
        const totalAll = raw.totalInvolvements || 1;
        const maxCodeTotal = (raw.byCode && raw.byCode.length) ? raw.byCode[0].total : 1;
        const enrichedByCode = (raw.byCode || []).map(row => ({
            ...row,
            pctLabel : Math.round(row.total * 100 / totalAll) + '%',
            barStyle : 'width:' + Math.round(row.total * 100 / maxCodeTotal) + '%'
        }));

        // Compute bar widths + pct labels for activeByCode
        const totalActive = raw.currentCount || 1;
        const maxActiveTotal = (raw.activeByCode && raw.activeByCode.length) ? raw.activeByCode[0].total : 1;
        const enrichedActiveByCode = (raw.activeByCode || []).map(row => ({
            ...row,
            pctLabel : Math.round(row.total * 100 / totalActive) + '%',
            barStyle : 'width:' + Math.round(row.total * 100 / maxActiveTotal) + '%'
        }));

        // Status badge class for top volunteers table
        const enrichedVolunteers = (raw.topVolunteers || []).map(v => ({
            ...v,
            statusClass : v.status === 'Current' ? 'badge badge--current' : 'badge badge--former'
        }));

        // Derive calendar year labels for the monthly legend
        // FY Jul 2025 – Jun 2026: months Jul-Dec belong to 2025, Jan-Jun to 2026
        const months = raw.byMonth || [];
        const years  = [...new Set(months.map(m => m.yr))].sort();
        this.prevCalYear = years.length > 0 ? String(years[0])       : '';
        this.currCalYear = years.length > 1 ? String(years[years.length - 1]) : '';

        this.data = {
            ...raw,
            byCode      : enrichedByCode,
            activeByCode: enrichedActiveByCode,
            topVolunteers: enrichedVolunteers
        };

        this.isLoading    = false;
        this.showDashboard = true;

        if (this._chartJsLoaded) {
            Promise.resolve().then(() => this._renderCharts());
        }
    }

    renderedCallback() {
        if (this._chartJsLoaded && this.data && !this._trendChart) {
            this._renderCharts();
        }
    }

    // ── Computed getters ─────────────────────────────────────────────────────
    get hasActiveInvolvements() {
        return this.data && this.data.activeByCode && this.data.activeByCode.length > 0;
    }

    // ── Chart Rendering ──────────────────────────────────────────────────────
    _renderCharts() {
        if (!this.data || !window.Chart) return;
        this._renderTrendChart();
        this._renderClassYearChart();
    }

    _renderTrendChart() {
        const canvas = this.refs.trendCanvas;
        if (!canvas || this._trendChart) return;

        const months = this.data.byMonth || [];
        const labels = months.map(m => m.label);
        const values = months.map(m => m.total);

        // Two colours: months in the first calendar year = blue, second = teal
        // e.g. FY Jul25-Jun26: Jul–Dec 2025 = blue (#378ADD), Jan–Jun 2026 = teal (#1D9E75)
        const firstYear = months.length > 0 ? months[0].yr : null;
        const colors = months.map(m => m.yr === firstYear ? BLUE_MID : TEAL_MID);

        this._trendChart = new window.Chart(canvas, {
            type: 'bar',
            data: {
                labels,
                datasets: [{
                    data           : values,
                    backgroundColor: colors,
                    borderRadius   : 4
                }]
            },
            options: {
                responsive         : true,
                maintainAspectRatio: false,
                legend  : { display: false },
                tooltips: {
                    mode     : 'index',
                    intersect: false,
                    callbacks: {
                        label: (item) => ' ' + item.yLabel + ' involvements'
                    }
                },
                scales: {
                    xAxes: [{
                        ticks    : { fontColor: CHART_TEXT, fontSize: 11, autoSkip: false, maxRotation: 45 },
                        gridLines: { color: CHART_GRID }
                    }],
                    yAxes: [{
                        ticks: {
                            beginAtZero: true,
                            fontColor  : CHART_TEXT,
                            fontSize   : 11,
                            callback   : (val) => Number.isInteger(val) ? val : null
                        },
                        gridLines: { color: CHART_GRID }
                    }]
                }
            }
        });
    }

    _renderClassYearChart() {
        const canvas = this.refs.classYearCanvas;
        if (!canvas || this._classYearChart) return;

        const classYears = this.data.byClassYear || [];
        // Exclude 'Unknown' from chart — too many bars otherwise, and Unknown is not a class year
        const filtered = classYears.filter(cy => cy.yr !== 'Unknown');
        const labels   = filtered.map(cy => cy.yr);
        const values   = filtered.map(cy => cy.total);

        this._classYearChart = new window.Chart(canvas, {
            type: 'bar',
            data: {
                labels,
                datasets: [{
                    data           : values,
                    backgroundColor: PURPLE_MID,
                    borderRadius   : 4
                }]
            },
            options: {
                responsive         : true,
                maintainAspectRatio: false,
                legend  : { display: false },
                tooltips: {
                    mode     : 'index',
                    intersect: false,
                    callbacks: {
                        title : (items) => 'Class of ' + items[0].label,
                        label : (item)  => ' ' + item.yLabel + ' involvements'
                    }
                },
                scales: {
                    xAxes: [{
                        ticks: {
                            fontColor  : CHART_TEXT,
                            fontSize   : 10,
                            // With ~55 class years the labels would crowd — skip every other one
                            autoSkip   : true,
                            maxTicksLimit: 20,
                            maxRotation: 45
                        },
                        gridLines: { color: CHART_GRID }
                    }],
                    yAxes: [{
                        ticks: {
                            beginAtZero: true,
                            fontColor  : CHART_TEXT,
                            fontSize   : 11,
                            callback   : (val) => Number.isInteger(val) ? val : null
                        },
                        gridLines: { color: CHART_GRID }
                    }]
                }
            }
        });
    }

    // ── Event Handlers ───────────────────────────────────────────────────────
    handleVolunteerClick(event) {
        event.preventDefault();
        const contactId = event.currentTarget.dataset.id;
        if (!contactId) return;
        
        // Force cache refresh by adding timestamp to prevent stale data
        this[NavigationMixin.Navigate]({
            type      : 'standard__navItemPage',
            attributes: { apiName: 'JABBA_Profile' },
            state     : { 
                c__recordId: contactId, 
                c__isAlumni: 'true',
                c__ts: Date.now() // Cache buster to force refresh
            }
        }, true); // Replace current history entry
    }

    handleSearchClick(event) {
        event.preventDefault();
        this[NavigationMixin.Navigate]({
            type      : 'standard__navItemPage',
            attributes: { apiName: 'Jabba_Search' }
        });
    }
}