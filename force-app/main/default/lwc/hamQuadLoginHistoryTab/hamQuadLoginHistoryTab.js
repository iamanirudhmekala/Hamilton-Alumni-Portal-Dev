import { LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getKpis from '@salesforce/apex/HAM_LoginHistoryDashboardCtrl.getKpis';
import getDailyUniqueLogins from '@salesforce/apex/HAM_LoginHistoryDashboardCtrl.getDailyUniqueLogins';
import getWeeklyLogins from '@salesforce/apex/HAM_LoginHistoryDashboardCtrl.getWeeklyLogins';
import getStatusBreakdown from '@salesforce/apex/HAM_LoginHistoryDashboardCtrl.getStatusBreakdown';
import getLoginIssues from '@salesforce/apex/HAM_LoginHistoryDashboardCtrl.getLoginIssues';
import { loadChartJs, createChart, destroyChart, fmt, pct, HAMILTON } from 'c/hamQuadChartUtils';

const PAGE_SIZE = 10;
const LOOKBACK_DAYS = 14;

export default class HamQuadLoginHistoryTab extends LightningElement {
    kpis = { total30: 0, success30: 0, distinctUsersThisMonth: 0, distinctUsersLastMonth: 0 };
    kpiTiles = [];
    errorMessage;
    isLoading = true;

    chartJsReady = false;
    dailyLineChart;
    weeklyBarChart;
    statusBarChart;

    dailyData;
    weeklyData;
    statusData;

    @track currentPage = 1;
    pageSize = PAGE_SIZE;
    lookbackDays = LOOKBACK_DAYS;
    issuePage = { records: [], totalRecords: 0, totalPages: 1, pageNumber: 1, pageSize: PAGE_SIZE };
    wiredIssuesResult;

    connectedCallback() {
        loadChartJs(this)
            .then(() => {
                this.chartJsReady = true;
                this.renderAllCharts();
            })
            .catch((e) => {
                this.errorMessage = 'Chart.js failed to load: ' + this.reduceError(e);
            });
    }

    disconnectedCallback() {
        destroyChart(this.dailyLineChart);
        destroyChart(this.weeklyBarChart);
        destroyChart(this.statusBarChart);
    }

    @wire(getKpis)
    wiredKpis({ data, error }) {
        if (data) {
            this.kpis = data;
            this.buildKpiTiles();
            this.isLoading = false;
        } else if (error) {
            this.errorMessage = this.reduceError(error);
            this.isLoading = false;
        }
    }

    @wire(getDailyUniqueLogins, { numDays: 31 })
    wiredDaily({ data, error }) {
        if (data) {
            this.dailyData = data;
            this.renderAllCharts();
        } else if (error) {
            this.errorMessage = this.reduceError(error);
        }
    }

    @wire(getWeeklyLogins, { numWeeks: 4 })
    wiredWeekly({ data, error }) {
        if (data) {
            this.weeklyData = data;
            this.renderAllCharts();
        } else if (error) {
            this.errorMessage = this.reduceError(error);
        }
    }

    @wire(getStatusBreakdown)
    wiredStatus({ data, error }) {
        if (data) {
            this.statusData = data;
            this.renderAllCharts();
        } else if (error) {
            this.errorMessage = this.reduceError(error);
        }
    }

    @wire(getLoginIssues, { pageNumber: '$currentPage', pageSize: '$pageSize', lookbackDays: '$lookbackDays' })
    wiredIssues(result) {
        this.wiredIssuesResult = result;
        if (result.data) {
            this.issuePage = {
                ...result.data,
                records: result.data.records.map((r, i) => ({
                    ...r,
                    rowKey: r.loginHistoryId || (r.userId + '_' + i),
                    statusPillClass: this.issueToneClass(r.status)
                }))
            };
        } else if (result.error) {
            this.errorMessage = this.reduceError(result.error);
        }
    }

    buildKpiTiles() {
        this.kpiTiles = [
            { label: 'Total logins (30 days)', value: this.kpis.total30, tone: 'navy', big: true },
            {
                label: 'Successful logins',
                value: this.kpis.success30,
                sub: `${pct(this.kpis.success30, this.kpis.total30)}% success rate`,
                tone: 'good'
            },
            { label: 'Distinct users, this month', value: this.kpis.distinctUsersThisMonth, tone: 'navy' },
            { label: 'Distinct users, last month', value: this.kpis.distinctUsersLastMonth, tone: 'navy' }
        ];
    }

    issueToneClass(status) {
        const s = (status || '').toLowerCase();
        if (s.includes('passwordless') || s.includes('multi-factor')) {
            return 'pill pill-navy';
        }
        if (s.includes('inactive')) {
            return 'pill pill-slate';
        }
        return 'pill pill-warn';
    }

    renderAllCharts() {
        this.renderDailyLineChart();
        this.renderWeeklyBarChart();
        this.renderStatusBarChart();
    }

    renderDailyLineChart() {
        if (!this.chartJsReady || !this.dailyData) return;
        const canvas = this.refs?.dailyCanvas;
        if (!canvas) return;
        destroyChart(this.dailyLineChart);

        this.dailyLineChart = createChart(canvas, {
            type: 'line',
            data: {
                labels: this.dailyData.map((p) => p.label),
                datasets: [
                    {
                        label: 'Distinct users logging in',
                        data: this.dailyData.map((p) => p.distinctUsers),
                        borderColor: HAMILTON.gold,
                        backgroundColor: HAMILTON.gold,
                        borderWidth: 2.5,
                        lineTension: 0.25,
                        pointRadius: 0
                    }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                legend: { display: false },
                scales: { yAxes: [{ ticks: { beginAtZero: true } }] }
            }
        });
    }

    renderWeeklyBarChart() {
        if (!this.chartJsReady || !this.weeklyData) return;
        const canvas = this.refs?.weeklyCanvas;
        if (!canvas) return;
        destroyChart(this.weeklyBarChart);

        this.weeklyBarChart = createChart(canvas, {
            type: 'horizontalBar',
            data: {
                labels: this.weeklyData.map((p) => (p.isPartialWeek ? p.label + '*' : p.label)),
                datasets: [
                    {
                        label: 'Logins',
                        data: this.weeklyData.map((p) => p.count),
                        backgroundColor: HAMILTON.navy
                    }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                legend: { display: false },
                scales: { yAxes: [{ ticks: { beginAtZero: true } }] }
            }
        });
    }

    renderStatusBarChart() {
        if (!this.chartJsReady || !this.statusData) return;
        const canvas = this.refs?.statusCanvas;
        if (!canvas) return;
        destroyChart(this.statusBarChart);

        const nonSuccess = this.statusData.filter((s) => s.name !== 'Success');

        this.statusBarChart = createChart(canvas, {
            type: 'horizontalBar',
            data: {
                labels: nonSuccess.map((s) => s.name),
                datasets: [
                    {
                        label: 'Attempts',
                        data: nonSuccess.map((s) => s.value),
                        backgroundColor: nonSuccess.map((s) => this.statusColor(s.name))
                    }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                legend: { display: false },
                scales: { xAxes: [{ ticks: { beginAtZero: true } }] }
            }
        });
    }

    statusColor(name) {
        const n = (name || '').toLowerCase();
        if (n.includes('passwordless') || n.includes('multi-factor')) {
            return HAMILTON.navy;
        }
        return HAMILTON.warn;
    }

    handlePrevPage() {
        if (this.currentPage > 1) {
            this.currentPage -= 1;
        }
    }

    handleNextPage() {
        if (this.currentPage < this.issuePage.totalPages) {
            this.currentPage += 1;
        }
    }

    async handleRefresh() {
        this.isLoading = true;
        try {
            await refreshApex(this.wiredIssuesResult);
        } finally {
            this.isLoading = false;
        }
    }

    reduceError(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }
        return 'Unknown error';
    }

    get hasError() {
        return !!this.errorMessage;
    }

    get formattedTotal30() {
        return fmt(this.kpis.total30);
    }

    get isPrevDisabled() {
        return this.currentPage <= 1;
    }

    get isNextDisabled() {
        return this.currentPage >= this.issuePage.totalPages;
    }

    get paginationLabel() {
        return `Page ${this.issuePage.pageNumber} of ${this.issuePage.totalPages} · ${fmt(this.issuePage.totalRecords)} rows`;
    }
}