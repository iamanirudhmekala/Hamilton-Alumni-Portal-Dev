import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getKpis from '@salesforce/apex/HAM_ConnectionsDashboardCtrl.getKpis';
import getStatusBreakdown from '@salesforce/apex/HAM_ConnectionsDashboardCtrl.getStatusBreakdown';
import getDailyTrend from '@salesforce/apex/HAM_ConnectionsDashboardCtrl.getDailyTrend';
import getAllTimeTotals from '@salesforce/apex/HAM_ConnectionsDashboardCtrl.getAllTimeTotals';
import { loadChartJs, createChart, destroyChart, fmt, HAMILTON } from 'c/hamQuadChartUtils';

export default class HamQuadConnectionsTab extends LightningElement {
    kpis = { newConnections: 0, newBookmarks: 0, newFavorites: 0, newBlocked: 0 };
    statusBreakdown = [];
    allTimeTotals = { total: 0, bookmarked: 0, favorited: 0, blocked: 0, plain: 0 };
    isLoading = true;
    errorMessage;

    chartJsReady = false;
    dailyChart;
    wiredDailyTrend;

    kpiTiles = [];

    connectedCallback() {
        loadChartJs(this)
            .then(() => {
                this.chartJsReady = true;
                this.renderDailyChart();
            })
            .catch((e) => {
                this.errorMessage = 'Chart.js failed to load: ' + this.reduceError(e);
            });
    }

    disconnectedCallback() {
        destroyChart(this.dailyChart);
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

    @wire(getStatusBreakdown)
    wiredStatusBreakdown({ data, error }) {
        if (data) {
            const maxVal = Math.max(1, ...data.map((d) => d.value));
            this.statusBreakdown = data.map((d) => ({
                ...d,
                formattedValue: fmt(d.value),
                barWidth: `width:${Math.round((d.value / maxVal) * 100)}%`
            }));
        } else if (error) {
            this.errorMessage = this.reduceError(error);
        }
    }

    @wire(getDailyTrend, { numDays: 14 })
    wiredDailyTrendHandler(result) {
        this.wiredDailyTrend = result;
        if (result.data) {
            this.dailyTrendData = result.data;
            this.renderDailyChart();
        } else if (result.error) {
            this.errorMessage = this.reduceError(result.error);
        }
    }

    @wire(getAllTimeTotals)
    wiredAllTimeTotals({ data, error }) {
        if (data) {
            this.allTimeTotals = data;
        } else if (error) {
            this.errorMessage = this.reduceError(error);
        }
    }

    buildKpiTiles() {
        this.kpiTiles = [
            { label: 'New connections', value: this.kpis.newConnections, sub: 'Connected, last 30 days · Portal User source', tone: 'good' },
            { label: 'New bookmarks', value: this.kpis.newBookmarks, sub: 'Bookmarked, last 30 days · Portal User source', tone: 'navy' },
            { label: 'New favorites', value: this.kpis.newFavorites, sub: 'Favorited, last 30 days · Portal User source', tone: 'slate' },
            { label: 'New blocked users', value: this.kpis.newBlocked, sub: 'Blocked, last 30 days · Portal User source', tone: 'warn' }
        ];
    }

    renderDailyChart() {
        if (!this.chartJsReady || !this.dailyTrendData) {
            return;
        }
        const canvas = this.refs?.dailyCanvas;
        if (!canvas) {
            return;
        }
        destroyChart(this.dailyChart);

        this.dailyChart = createChart(canvas, {
            type: 'horizontalBar',
            data: {
                labels: this.dailyTrendData.map((p) => p.label),
                datasets: [
                    {
                        label: 'New connection records',
                        data: this.dailyTrendData.map((p) => p.count),
                        backgroundColor: HAMILTON.navy
                    }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                legend: { display: false },
                scales: {
                    xAxes: [{ ticks: { beginAtZero: true } }]
                }
            }
        });
    }

    async handleRefresh() {
        this.isLoading = true;
        try {
            await Promise.all([
                refreshApex(this.wiredDailyTrend)
            ]);
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

    get formattedAllTimeTotal() {
        return fmt(this.allTimeTotals.total);
    }
    get formattedBookmarked() {
        return fmt(this.allTimeTotals.bookmarked);
    }
    get formattedFavorited() {
        return fmt(this.allTimeTotals.favorited);
    }
    get formattedBlocked() {
        return fmt(this.allTimeTotals.blocked);
    }
}