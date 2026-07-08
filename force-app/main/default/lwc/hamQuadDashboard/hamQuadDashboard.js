import { LightningElement, track } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import CHARTJS from '@salesforce/resourceUrl/HAMQuadChartJS';

// Connections
import connGetKpisApex from '@salesforce/apex/HAM_ConnectionsDashboardCtrl.getKpis';
import connGetStatusBreakdownApex from '@salesforce/apex/HAM_ConnectionsDashboardCtrl.getStatusBreakdown';
import connGetDailyTrendApex from '@salesforce/apex/HAM_ConnectionsDashboardCtrl.getDailyTrend';
import connGetAllTimeTotalsApex from '@salesforce/apex/HAM_ConnectionsDashboardCtrl.getAllTimeTotals';

// Login history
import loginGetKpisApex from '@salesforce/apex/HAM_LoginHistoryDashboardCtrl.getKpis';
import loginGetDailyUniqueLoginsApex from '@salesforce/apex/HAM_LoginHistoryDashboardCtrl.getDailyUniqueLogins';
import loginGetWeeklyLoginsApex from '@salesforce/apex/HAM_LoginHistoryDashboardCtrl.getWeeklyLogins';
import loginGetStatusBreakdownApex from '@salesforce/apex/HAM_LoginHistoryDashboardCtrl.getStatusBreakdown';
import loginGetLoginIssuesApex from '@salesforce/apex/HAM_LoginHistoryDashboardCtrl.getLoginIssues';

// Funding interest
import fundGetKpisApex from '@salesforce/apex/HAM_FundingInterestDashboardCtrl.getKpis';
import fundGetNewByCategory30Apex from '@salesforce/apex/HAM_FundingInterestDashboardCtrl.getNewByCategory30';
import fundGetAllTimeByCategoryApex from '@salesforce/apex/HAM_FundingInterestDashboardCtrl.getAllTimeByCategory';
import fundGetAllTimeNoCategoryCountApex from '@salesforce/apex/HAM_FundingInterestDashboardCtrl.getAllTimeNoCategoryCount';

// Service indicator
import svcGetPartnerTotalsApex from '@salesforce/apex/HAM_ServiceIndicatorDashboardCtrl.getPartnerTotals';
import svcGetActivityByIndicatorType30Apex from '@salesforce/apex/HAM_ServiceIndicatorDashboardCtrl.getActivityByIndicatorType30';
import svcGetTopIndicatorsByWeekApex from '@salesforce/apex/HAM_ServiceIndicatorDashboardCtrl.getTopIndicatorsByWeek';
import svcGetLatestActivityApex from '@salesforce/apex/HAM_ServiceIndicatorDashboardCtrl.getLatestActivity';

const TONES = { navy: '#0A2E5C', gold: '#C9A227', slate: '#5B6472', warn: '#B4552C', good: '#2F7A4F' };
const NAVY = '#0A2E5C';
const GOLD = '#C9A227';
const WARN = '#B4552C';
const REFRESH_INTERVAL_MS = 5 * 60 * 1000;

function fmt(n) {
    if (n === null || n === undefined) return '0';
    return Number(n).toLocaleString('en-US');
}

function pct(numerator, denominator) {
    if (!denominator) return '0.0';
    return ((numerator / denominator) * 100).toFixed(1);
}

function makeTile(label, value, opts) {
    const o = opts || {};
    const tone = o.tone || 'navy';
    return {
        label,
        formattedValue: fmt(value),
        sub: o.sub,
        valueClass: o.big ? 'kpi-value kpi-value-big' : 'kpi-value',
        valueStyle: 'color: ' + (TONES[tone] || NAVY) + ';'
    };
}

export default class HamQuadDashboard extends LightningElement {
    // ── Shell ──────────────────────────────────────────────────────────────────
    autoRefreshOn = false;
    intervalHandle;
    lastRefreshedLabel = '';
    @track activeTab = 'connections';

    // ── Connections ───────────────────────────────────────────────────────────
    @track connKpiTiles = [];
    @track connStatusBreakdown = [];
    @track connAllTimeTotals = { total: 0, bookmarked: 0, favorited: 0, blocked: 0 };
    @track connErrorMessage;
    @track connIsLoading = true;
    connDailyTrendData;
    connDailyChart;

    // ── Login history ─────────────────────────────────────────────────────────
    @track loginKpiTiles = [];
    @track loginIssuePage = { records: [], totalRecords: 0, totalPages: 1, pageNumber: 1, pageSize: 10 };
    @track loginErrorMessage;
    @track loginIsLoading = true;
    loginKpis = { total30: 0, success30: 0 };
    loginDailyData;
    loginWeeklyData;
    loginStatusData;
    loginDailyLineChart;
    loginWeeklyBarChart;
    loginStatusBarChart;
    loginCurrentPage = 1;
    loginPageSize = 10;
    loginLookbackDays = 14;

    // ── Funding interest ──────────────────────────────────────────────────────
    @track fundKpiTiles = [];
    @track fundErrorMessage;
    @track fundIsLoading = true;
    @track fundNoCategoryCount = 0;
    fundNewByCategoryData;
    fundAllTimeByCategoryData;
    fundNewByCategoryChart;
    fundAllTimeByCategoryChart;

    // ── Service indicator ─────────────────────────────────────────────────────
    @track svcKpiTiles = [];
    @track svcWeeklyTopIndicators = [];
    @track svcLatestActivity = [];
    @track svcErrorMessage;
    @track svcIsLoading = true;
    svcTotals = { created30: 0, modified30: 0 };
    svcActivityData;
    svcActivityChart;

    // ── Getters ────────────────────────────────────────────────────────────────
    get connHasError() { return !!this.connErrorMessage; }
    get connFormattedAllTimeTotal() { return fmt(this.connAllTimeTotals.total); }
    get connFormattedBookmarked() { return fmt(this.connAllTimeTotals.bookmarked); }
    get connFormattedFavorited() { return fmt(this.connAllTimeTotals.favorited); }
    get connFormattedBlocked() { return fmt(this.connAllTimeTotals.blocked); }

    get loginHasError() { return !!this.loginErrorMessage; }
    get loginFormattedTotal30() { return fmt(this.loginKpis.total30); }
    get loginIsPrevDisabled() { return this.loginCurrentPage <= 1; }
    get loginIsNextDisabled() { return this.loginCurrentPage >= this.loginIssuePage.totalPages; }
    get loginPaginationLabel() {
        return 'Page ' + this.loginIssuePage.pageNumber + ' of ' + this.loginIssuePage.totalPages + ' · ' + fmt(this.loginIssuePage.totalRecords) + ' rows';
    }

    get fundHasError() { return !!this.fundErrorMessage; }
    get fundFormattedNoCategoryCount() { return fmt(this.fundNoCategoryCount); }
    get svcHasError() { return !!this.svcErrorMessage; }

    // ── Tab CSS class getters ──────────────────────────────────────────────────
    get connTabBtnClass() { return 'tab-btn' + (this.activeTab === 'connections' ? ' tab-btn-active' : ''); }
    get loginTabBtnClass() { return 'tab-btn' + (this.activeTab === 'login' ? ' tab-btn-active' : ''); }
    get fundTabBtnClass() { return 'tab-btn' + (this.activeTab === 'funding' ? ' tab-btn-active' : ''); }
    get svcTabBtnClass() { return 'tab-btn' + (this.activeTab === 'service' ? ' tab-btn-active' : ''); }

    get connPanelClass() { return 'tab-panel' + (this.activeTab === 'connections' ? ' tab-panel-active' : ''); }
    get loginPanelClass() { return 'tab-panel' + (this.activeTab === 'login' ? ' tab-panel-active' : ''); }
    get fundPanelClass() { return 'tab-panel' + (this.activeTab === 'funding' ? ' tab-panel-active' : ''); }
    get svcPanelClass() { return 'tab-panel' + (this.activeTab === 'service' ? ' tab-panel-active' : ''); }

    // ── Tab click handlers ─────────────────────────────────────────────────────
    handleConnTab() { this.activeTab = 'connections'; }
    handleLoginTab() { this.activeTab = 'login'; }
    handleFundTab() { this.activeTab = 'funding'; }
    handleSvcTab() { this.activeTab = 'service'; }

    // ── Lifecycle ─────────────────────────────────────────────────────────────
    connectedCallback() {
        this.stampRefreshTime();
        Promise.all([
            loadScript(this, CHARTJS).catch((e) => {
                const msg = 'Chart.js failed to load: ' + this._reduceError(e);
                this.connErrorMessage = msg;
                this.loginErrorMessage = msg;
                this.fundErrorMessage = msg;
                this.svcErrorMessage = msg;
            }),
            this._loadConnData(),
            this._loadLoginData(),
            this._loadFundData(),
            this._loadSvcData()
        ]).then(() => {
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => this._renderAllCharts(), 50);
        });
    }

    disconnectedCallback() {
        this.clearAutoRefresh();
        this._destroyAllCharts();
    }

    // ── Dashboard controls ────────────────────────────────────────────────────
    handleManualRefresh() {
        this.stampRefreshTime();
        this._destroyAllCharts();
        Promise.all([
            this._loadConnData(),
            this._loadLoginData(),
            this._loadFundData(),
            this._loadSvcData()
        ]).then(() => {
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => this._renderAllCharts(), 50);
        });
    }

    handleAutoRefreshToggle(event) {
        this.autoRefreshOn = event.target.checked;
        if (this.autoRefreshOn) this.startAutoRefresh();
        else this.clearAutoRefresh();
    }

    startAutoRefresh() {
        this.clearAutoRefresh();
        this.intervalHandle = setInterval(() => this.handleManualRefresh(), REFRESH_INTERVAL_MS);
    }

    clearAutoRefresh() {
        if (this.intervalHandle) { clearInterval(this.intervalHandle); this.intervalHandle = undefined; }
    }

    stampRefreshTime() {
        const now = new Date();
        this.lastRefreshedLabel = now.toLocaleString('en-US', { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' });
    }

    // ── Connections data ──────────────────────────────────────────────────────
    _loadConnData() {
        this.connIsLoading = true;
        this.connErrorMessage = undefined;
        return Promise.all([
            connGetKpisApex()
                .then((d) => { this.connKpiTiles = this._buildConnTiles(d); })
                .catch((e) => { this.connErrorMessage = this._reduceError(e); }),
            connGetStatusBreakdownApex()
                .then((d) => {
                    const max = Math.max(1, ...d.map((r) => r.value));
                    this.connStatusBreakdown = d.map((r) => ({
                        ...r,
                        formattedValue: fmt(r.value),
                        barWidth: 'width:' + Math.round((r.value / max) * 100) + '%'
                    }));
                })
                .catch((e) => { this.connErrorMessage = this._reduceError(e); }),
            connGetDailyTrendApex({ numDays: 14 })
                .then((d) => { this.connDailyTrendData = d; })
                .catch((e) => { this.connErrorMessage = this._reduceError(e); }),
            connGetAllTimeTotalsApex()
                .then((d) => { this.connAllTimeTotals = d; })
                .catch((e) => { this.connErrorMessage = this._reduceError(e); })
        ]).finally(() => { this.connIsLoading = false; });
    }

    _buildConnTiles(kpis) {
        return [
            makeTile('New connections', kpis.newConnections, { sub: 'Connected, last 30 days · Portal User source', tone: 'good' }),
            makeTile('New bookmarks', kpis.newBookmarks, { sub: 'Bookmarked, last 30 days · Portal User source', tone: 'navy' }),
            makeTile('New favorites', kpis.newFavorites, { sub: 'Favorited, last 30 days · Portal User source', tone: 'slate' }),
            makeTile('New blocked users', kpis.newBlocked, { sub: 'Blocked, last 30 days · Portal User source', tone: 'warn' })
        ];
    }

    _renderConnDailyChart() {
        if (!window.Chart || !this.connDailyTrendData) return;
        const canvas = this.template.querySelector('.conn-daily-canvas');
        if (!canvas) return;
        if (this.connDailyChart) { this.connDailyChart.destroy(); }
        // eslint-disable-next-line no-undef
        this.connDailyChart = new Chart(canvas.getContext('2d'), {
            type: 'horizontalBar',
            data: {
                labels: this.connDailyTrendData.map((p) => p.label),
                datasets: [{ label: 'New connection records', data: this.connDailyTrendData.map((p) => p.count), backgroundColor: NAVY }]
            },
            options: { responsive: true, maintainAspectRatio: false, legend: { display: false }, scales: { xAxes: [{ ticks: { beginAtZero: true } }] } }
        });
    }

    handleConnRefresh() {
        this._destroyChart('connDailyChart');
        this._loadConnData().then(() => {
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => this._renderConnDailyChart(), 50);
        });
    }

    // ── Login data ────────────────────────────────────────────────────────────
    _loadLoginData() {
        this.loginIsLoading = true;
        this.loginErrorMessage = undefined;
        return Promise.all([
            loginGetKpisApex()
                .then((d) => { this.loginKpis = d; this.loginKpiTiles = this._buildLoginTiles(d); })
                .catch((e) => { this.loginErrorMessage = this._reduceError(e); }),
            loginGetDailyUniqueLoginsApex({ numDays: 31 })
                .then((d) => { this.loginDailyData = d; })
                .catch((e) => { this.loginErrorMessage = this._reduceError(e); }),
            loginGetWeeklyLoginsApex({ numWeeks: 4 })
                .then((d) => { this.loginWeeklyData = d; })
                .catch((e) => { this.loginErrorMessage = this._reduceError(e); }),
            loginGetStatusBreakdownApex()
                .then((d) => { this.loginStatusData = d; })
                .catch((e) => { this.loginErrorMessage = this._reduceError(e); }),
            this._loadLoginIssues()
        ]).finally(() => { this.loginIsLoading = false; });
    }

    _loadLoginIssues() {
        return loginGetLoginIssuesApex({
            pageNumber: this.loginCurrentPage,
            pageSize: this.loginPageSize,
            lookbackDays: this.loginLookbackDays
        }).then((d) => {
            this.loginIssuePage = {
                ...d,
                records: d.records.map((r, i) => ({
                    ...r,
                    rowKey: r.loginHistoryId || (r.userId + '_' + i),
                    statusPillClass: this._loginToneClass(r.status)
                }))
            };
        }).catch((e) => { this.loginErrorMessage = this._reduceError(e); });
    }

    _buildLoginTiles(kpis) {
        return [
            makeTile('Total logins (30 days)', kpis.total30, { tone: 'navy', big: true }),
            makeTile('Successful logins', kpis.success30, { sub: pct(kpis.success30, kpis.total30) + '% success rate', tone: 'good' }),
            makeTile('Distinct users, this month', kpis.distinctUsersThisMonth, { tone: 'navy' }),
            makeTile('Distinct users, last month', kpis.distinctUsersLastMonth, { tone: 'navy' })
        ];
    }

    _loginToneClass(status) {
        const s = (status || '').toLowerCase();
        if (s.includes('passwordless') || s.includes('multi-factor')) return 'pill pill-navy';
        if (s.includes('inactive')) return 'pill pill-slate';
        return 'pill pill-warn';
    }

    _renderLoginDailyChart() {
        if (!window.Chart || !this.loginDailyData) return;
        const canvas = this.template.querySelector('.login-daily-canvas');
        if (!canvas) return;
        if (this.loginDailyLineChart) { this.loginDailyLineChart.destroy(); }
        // eslint-disable-next-line no-undef
        this.loginDailyLineChart = new Chart(canvas.getContext('2d'), {
            type: 'line',
            data: {
                labels: this.loginDailyData.map((p) => p.label),
                datasets: [{
                    label: 'Distinct users',
                    data: this.loginDailyData.map((p) => p.distinctUsers),
                    borderColor: GOLD, backgroundColor: GOLD, borderWidth: 2.5, lineTension: 0.25, pointRadius: 0
                }]
            },
            options: { responsive: true, maintainAspectRatio: false, legend: { display: false }, scales: { yAxes: [{ ticks: { beginAtZero: true } }] } }
        });
    }

    _renderLoginWeeklyChart() {
        if (!window.Chart || !this.loginWeeklyData) return;
        const canvas = this.template.querySelector('.login-weekly-canvas');
        if (!canvas) return;
        if (this.loginWeeklyBarChart) { this.loginWeeklyBarChart.destroy(); }
        // eslint-disable-next-line no-undef
        this.loginWeeklyBarChart = new Chart(canvas.getContext('2d'), {
            type: 'horizontalBar',
            data: {
                labels: this.loginWeeklyData.map((p) => (p.isPartialWeek ? p.label + '*' : p.label)),
                datasets: [{ label: 'Logins', data: this.loginWeeklyData.map((p) => p.count), backgroundColor: NAVY }]
            },
            options: { responsive: true, maintainAspectRatio: false, legend: { display: false }, scales: { yAxes: [{ ticks: { beginAtZero: true } }] } }
        });
    }

    _renderLoginStatusChart() {
        if (!window.Chart || !this.loginStatusData) return;
        const canvas = this.template.querySelector('.login-status-canvas');
        if (!canvas) return;
        if (this.loginStatusBarChart) { this.loginStatusBarChart.destroy(); }
        const nonSuccess = this.loginStatusData.filter((s) => s.name !== 'Success');
        // eslint-disable-next-line no-undef
        this.loginStatusBarChart = new Chart(canvas.getContext('2d'), {
            type: 'horizontalBar',
            data: {
                labels: nonSuccess.map((s) => s.name),
                datasets: [{
                    label: 'Attempts',
                    data: nonSuccess.map((s) => s.value),
                    backgroundColor: nonSuccess.map((s) => {
                        const n = (s.name || '').toLowerCase();
                        return (n.includes('passwordless') || n.includes('multi-factor')) ? NAVY : WARN;
                    })
                }]
            },
            options: { responsive: true, maintainAspectRatio: false, legend: { display: false }, scales: { xAxes: [{ ticks: { beginAtZero: true } }] } }
        });
    }

    handleLoginPrevPage() {
        if (this.loginCurrentPage > 1) { this.loginCurrentPage -= 1; this._loadLoginIssues(); }
    }

    handleLoginNextPage() {
        if (this.loginCurrentPage < this.loginIssuePage.totalPages) { this.loginCurrentPage += 1; this._loadLoginIssues(); }
    }

    handleLoginRefresh() {
        this._destroyChart('loginDailyLineChart');
        this._destroyChart('loginWeeklyBarChart');
        this._destroyChart('loginStatusBarChart');
        this._loadLoginData().then(() => {
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => {
                this._renderLoginDailyChart();
                this._renderLoginWeeklyChart();
                this._renderLoginStatusChart();
            }, 50);
        });
    }

    // ── Funding interest data ─────────────────────────────────────────────────
    _loadFundData() {
        this.fundIsLoading = true;
        this.fundErrorMessage = undefined;
        return Promise.all([
            fundGetKpisApex()
                .then((d) => { this.fundKpiTiles = this._buildFundTiles(d); })
                .catch((e) => { this.fundErrorMessage = this._reduceError(e); }),
            fundGetNewByCategory30Apex()
                .then((d) => { this.fundNewByCategoryData = d; })
                .catch((e) => { this.fundErrorMessage = this._reduceError(e); }),
            fundGetAllTimeByCategoryApex()
                .then((d) => { this.fundAllTimeByCategoryData = d; })
                .catch((e) => { this.fundErrorMessage = this._reduceError(e); }),
            fundGetAllTimeNoCategoryCountApex()
                .then((d) => { if (d !== undefined) this.fundNoCategoryCount = d; })
                .catch((e) => { this.fundErrorMessage = this._reduceError(e); })
        ]).finally(() => { this.fundIsLoading = false; });
    }

    _buildFundTiles(kpis) {
        return [
            makeTile('New interests (30 days)', kpis.new30, { tone: 'navy', big: true }),
            makeTile('Data source populated', kpis.new30WithDataSource, { sub: 'of ' + kpis.new30 + ' new records — flag for review if low', tone: 'warn' }),
            makeTile('All-time Interest records', kpis.allTimeTotal, { tone: 'slate' })
        ];
    }

    _renderFundNewByCatChart() {
        if (!window.Chart || !this.fundNewByCategoryData) return;
        const canvas = this.template.querySelector('.fund-new-by-cat-canvas');
        if (!canvas) return;
        if (this.fundNewByCategoryChart) { this.fundNewByCategoryChart.destroy(); }
        // eslint-disable-next-line no-undef
        this.fundNewByCategoryChart = new Chart(canvas.getContext('2d'), {
            type: 'horizontalBar',
            data: {
                labels: this.fundNewByCategoryData.map((d) => d.name),
                datasets: [{ label: 'New (30 days)', data: this.fundNewByCategoryData.map((d) => d.value), backgroundColor: GOLD }]
            },
            options: { responsive: true, maintainAspectRatio: false, legend: { display: false }, scales: { yAxes: [{ ticks: { beginAtZero: true } }] } }
        });
    }

    _renderFundAllTimeByCatChart() {
        if (!window.Chart || !this.fundAllTimeByCategoryData) return;
        const canvas = this.template.querySelector('.fund-all-time-by-cat-canvas');
        if (!canvas) return;
        if (this.fundAllTimeByCategoryChart) { this.fundAllTimeByCategoryChart.destroy(); }
        // eslint-disable-next-line no-undef
        this.fundAllTimeByCategoryChart = new Chart(canvas.getContext('2d'), {
            type: 'horizontalBar',
            data: {
                labels: this.fundAllTimeByCategoryData.map((d) => d.name),
                datasets: [{ label: 'All-time', data: this.fundAllTimeByCategoryData.map((d) => d.value), backgroundColor: NAVY }]
            },
            options: { responsive: true, maintainAspectRatio: false, legend: { display: false }, scales: { xAxes: [{ ticks: { beginAtZero: true } }] } }
        });
    }

    handleFundRefresh() {
        this._destroyChart('fundNewByCategoryChart');
        this._destroyChart('fundAllTimeByCategoryChart');
        this._loadFundData().then(() => {
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => {
                this._renderFundNewByCatChart();
                this._renderFundAllTimeByCatChart();
            }, 50);
        });
    }

    // ── Service indicator data ────────────────────────────────────────────────
    _loadSvcData() {
        this.svcIsLoading = true;
        this.svcErrorMessage = undefined;
        return Promise.all([
            svcGetPartnerTotalsApex()
                .then((d) => { this.svcTotals = d; this._buildSvcTiles(); })
                .catch((e) => { this.svcErrorMessage = this._reduceError(e); }),
            svcGetActivityByIndicatorType30Apex()
                .then((d) => { this.svcActivityData = [...d].sort((a, b) => b.total - a.total); this._buildSvcTiles(); })
                .catch((e) => { this.svcErrorMessage = this._reduceError(e); }),
            svcGetTopIndicatorsByWeekApex({ numWeeks: 4 })
                .then((d) => {
                    this.svcWeeklyTopIndicators = d.map((week, wIdx) => ({
                        key: wIdx + '-' + week.weekLabel,
                        weekLabel: week.isPartialWeek ? week.weekLabel + ' (partial)' : week.weekLabel,
                        topIndicators: week.topIndicators.map((ind, idx) => ({
                            key: wIdx + '-' + idx,
                            rank: idx + 1,
                            name: ind.name,
                            created: fmt(ind.created),
                            modified: fmt(ind.modified),
                            total: fmt(ind.total)
                        }))
                    }));
                })
                .catch((e) => { this.svcErrorMessage = this._reduceError(e); }),
            svcGetLatestActivityApex({ limitCount: 10 })
                .then((d) => {
                    this.svcLatestActivity = d.map((row, idx) => ({
                        key: idx, ...row,
                        actionPillClass: row.action === 'Created' ? 'pill pill-navy' : 'pill pill-slate'
                    }));
                })
                .catch((e) => { this.svcErrorMessage = this._reduceError(e); })
        ]).finally(() => { this.svcIsLoading = false; });
    }

    _buildSvcTiles() {
        const totalTouches = (this.svcTotals.created30 || 0) + (this.svcTotals.modified30 || 0);
        const distinctCount = this.svcActivityData ? this.svcActivityData.length : 0;
        this.svcKpiTiles = [
            makeTile('Created by partner users (30 days)', this.svcTotals.created30, { tone: 'navy', big: true }),
            makeTile('Modified by partner users (30 days)', this.svcTotals.modified30, { tone: 'navy', big: true }),
            makeTile('Total partner touches', totalTouches, { tone: 'gold' }),
            makeTile('Distinct indicator types touched', distinctCount, { tone: 'slate' })
        ];
    }

    _renderSvcActivityChart() {
        if (!window.Chart || !this.svcActivityData) return;
        const canvas = this.template.querySelector('.svc-activity-canvas');
        if (!canvas) return;
        if (this.svcActivityChart) { this.svcActivityChart.destroy(); }
        // eslint-disable-next-line no-undef
        this.svcActivityChart = new Chart(canvas.getContext('2d'), {
            type: 'horizontalBar',
            data: {
                labels: this.svcActivityData.map((d) => d.name),
                datasets: [
                    { label: 'Created', data: this.svcActivityData.map((d) => d.created), backgroundColor: GOLD },
                    { label: 'Modified', data: this.svcActivityData.map((d) => d.modified), backgroundColor: NAVY }
                ]
            },
            options: {
                responsive: true, maintainAspectRatio: false,
                legend: { display: true, position: 'top', labels: { boxWidth: 12, fontSize: 11 } },
                scales: { xAxes: [{ ticks: { beginAtZero: true } }] }
            }
        });
    }

    handleSvcRefresh() {
        this._destroyChart('svcActivityChart');
        this._loadSvcData().then(() => {
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => this._renderSvcActivityChart(), 50);
        });
    }

    // ── Render / destroy helpers ──────────────────────────────────────────────
    _renderAllCharts() {
        if (!window.Chart) return;
        this._renderConnDailyChart();
        this._renderLoginDailyChart();
        this._renderLoginWeeklyChart();
        this._renderLoginStatusChart();
        this._renderFundNewByCatChart();
        this._renderFundAllTimeByCatChart();
        this._renderSvcActivityChart();
    }

    _destroyChart(name) {
        if (this[name]) { try { this[name].destroy(); } catch (e) { /* ignore */ } this[name] = null; }
    }

    _destroyAllCharts() {
        ['connDailyChart', 'loginDailyLineChart', 'loginWeeklyBarChart', 'loginStatusBarChart',
         'fundNewByCategoryChart', 'fundAllTimeByCategoryChart', 'svcActivityChart']
            .forEach((n) => this._destroyChart(n));
    }

    // ── Utilities ─────────────────────────────────────────────────────────────
    _reduceError(error) {
        if (error && error.body && error.body.message) return error.body.message;
        return 'Unknown error';
    }
}