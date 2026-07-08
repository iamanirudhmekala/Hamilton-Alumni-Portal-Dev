import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getPartnerTotals from '@salesforce/apex/HAM_ServiceIndicatorDashboardCtrl.getPartnerTotals';
import getActivityByIndicatorType30 from '@salesforce/apex/HAM_ServiceIndicatorDashboardCtrl.getActivityByIndicatorType30';
import getTopIndicatorsByWeek from '@salesforce/apex/HAM_ServiceIndicatorDashboardCtrl.getTopIndicatorsByWeek';
import getLatestActivity from '@salesforce/apex/HAM_ServiceIndicatorDashboardCtrl.getLatestActivity';
import { loadChartJs, createChart, destroyChart, fmt, HAMILTON } from 'c/hamQuadChartUtils';

export default class HamQuadServiceIndicatorTab extends LightningElement {
    totals = { created30: 0, modified30: 0 };
    kpiTiles = [];
    errorMessage;
    isLoading = true;

    chartJsReady = false;
    activityChart;
    activityData;

    weeklyTopIndicators = [];
    latestActivity = [];

    wiredTotalsResult;

    connectedCallback() {
        loadChartJs(this)
            .then(() => {
                this.chartJsReady = true;
                this.renderActivityChart();
            })
            .catch((e) => {
                this.errorMessage = 'Chart.js failed to load: ' + this.reduceError(e);
            });
    }

    disconnectedCallback() {
        destroyChart(this.activityChart);
    }

    @wire(getPartnerTotals)
    wiredTotals(result) {
        this.wiredTotalsResult = result;
        if (result.data) {
            this.totals = result.data;
            this.buildKpiTiles();
            this.isLoading = false;
        } else if (result.error) {
            this.errorMessage = this.reduceError(result.error);
            this.isLoading = false;
        }
    }

    @wire(getActivityByIndicatorType30)
    wiredActivity({ data, error }) {
        if (data) {
            this.activityData = [...data].sort((a, b) => b.total - a.total);
            this.renderActivityChart();
        } else if (error) {
            this.errorMessage = this.reduceError(error);
        }
    }

    @wire(getTopIndicatorsByWeek, { numWeeks: 4 })
    wiredWeekly({ data, error }) {
        if (data) {
            this.weeklyTopIndicators = data.map((week, wIdx) => ({
                key: `${wIdx}-${week.weekLabel}`,
                weekLabel: week.isPartialWeek ? week.weekLabel + ' (partial)' : week.weekLabel,
                topIndicators: week.topIndicators.map((ind, idx) => ({
                    key: `${wIdx}-${idx}`,
                    rank: idx + 1,
                    name: ind.name,
                    created: fmt(ind.created),
                    modified: fmt(ind.modified),
                    total: fmt(ind.total)
                }))
            }));
        } else if (error) {
            this.errorMessage = this.reduceError(error);
        }
    }

    @wire(getLatestActivity, { limitCount: 10 })
    wiredLatest({ data, error }) {
        if (data) {
            this.latestActivity = data.map((row, idx) => ({
                key: idx,
                ...row,
                actionPillClass: row.action === 'Created' ? 'pill pill-navy' : 'pill pill-slate'
            }));
        } else if (error) {
            this.errorMessage = this.reduceError(error);
        }
    }

    buildKpiTiles() {
        const totalTouches = (this.totals.created30 || 0) + (this.totals.modified30 || 0);
        this.kpiTiles = [
            { label: 'Created by partner users (30 days)', value: this.totals.created30, tone: 'navy', big: true },
            { label: 'Modified by partner users (30 days)', value: this.totals.modified30, tone: 'navy', big: true },
            { label: 'Total partner touches', value: totalTouches, tone: 'gold' }
        ];
    }

    renderActivityChart() {
        if (!this.chartJsReady || !this.activityData) return;
        const canvas = this.refs?.activityCanvas;
        if (!canvas) return;
        destroyChart(this.activityChart);

        this.activityChart = createChart(canvas, {
            type: 'horizontalBar',
            data: {
                labels: this.activityData.map((d) => d.name),
                datasets: [
                    { label: 'Created', data: this.activityData.map((d) => d.created), backgroundColor: HAMILTON.gold },
                    { label: 'Modified', data: this.activityData.map((d) => d.modified), backgroundColor: HAMILTON.navy }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                legend: { display: true, position: 'top', labels: { boxWidth: 12, fontSize: 11 } },
                scales: { xAxes: [{ ticks: { beginAtZero: true } }] }
            }
        });
    }

    async handleRefresh() {
        this.isLoading = true;
        try {
            await refreshApex(this.wiredTotalsResult);
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

    get distinctIndicatorCount() {
        return this.activityData ? this.activityData.length : 0;
    }
}