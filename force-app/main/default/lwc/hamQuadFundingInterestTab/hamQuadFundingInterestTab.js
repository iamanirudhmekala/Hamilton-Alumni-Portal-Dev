import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getKpis from '@salesforce/apex/HAM_FundingInterestDashboardCtrl.getKpis';
import getNewByCategory30 from '@salesforce/apex/HAM_FundingInterestDashboardCtrl.getNewByCategory30';
import getAllTimeByCategory from '@salesforce/apex/HAM_FundingInterestDashboardCtrl.getAllTimeByCategory';
import getAllTimeNoCategoryCount from '@salesforce/apex/HAM_FundingInterestDashboardCtrl.getAllTimeNoCategoryCount';
import { loadChartJs, createChart, destroyChart, fmt, HAMILTON } from 'c/hamQuadChartUtils';

export default class HamQuadFundingInterestTab extends LightningElement {
    kpis = { new30: 0, new30WithDataSource: 0, allTimeTotal: 0 };
    kpiTiles = [];
    noCategoryCount = 0;
    errorMessage;
    isLoading = true;

    chartJsReady = false;
    newByCategoryChart;
    allTimeByCategoryChart;

    newByCategoryData;
    allTimeByCategoryData;

    wiredKpisResult;

    connectedCallback() {
        loadChartJs(this)
            .then(() => {
                this.chartJsReady = true;
                this.renderCharts();
            })
            .catch((e) => {
                this.errorMessage = 'Chart.js failed to load: ' + this.reduceError(e);
            });
    }

    disconnectedCallback() {
        destroyChart(this.newByCategoryChart);
        destroyChart(this.allTimeByCategoryChart);
    }

    @wire(getKpis)
    wiredKpis(result) {
        this.wiredKpisResult = result;
        if (result.data) {
            this.kpis = result.data;
            this.buildKpiTiles();
            this.isLoading = false;
        } else if (result.error) {
            this.errorMessage = this.reduceError(result.error);
            this.isLoading = false;
        }
    }

    @wire(getNewByCategory30)
    wiredNewByCategory({ data, error }) {
        if (data) {
            this.newByCategoryData = data;
            this.renderCharts();
        } else if (error) {
            this.errorMessage = this.reduceError(error);
        }
    }

    @wire(getAllTimeByCategory)
    wiredAllTimeByCategory({ data, error }) {
        if (data) {
            this.allTimeByCategoryData = data;
            this.renderCharts();
        } else if (error) {
            this.errorMessage = this.reduceError(error);
        }
    }

    @wire(getAllTimeNoCategoryCount)
    wiredNoCategoryCount({ data, error }) {
        if (data !== undefined) {
            this.noCategoryCount = data;
        } else if (error) {
            this.errorMessage = this.reduceError(error);
        }
    }

    buildKpiTiles() {
        this.kpiTiles = [
            { label: 'New interests (30 days)', value: this.kpis.new30, tone: 'navy', big: true },
            {
                label: 'Data source populated',
                value: this.kpis.new30WithDataSource,
                sub: `of ${this.kpis.new30} new records — flag for review if low`,
                tone: 'warn'
            },
            { label: 'All-time Interest records', value: this.kpis.allTimeTotal, tone: 'slate' }
        ];
    }

    renderCharts() {
        this.renderNewByCategoryChart();
        this.renderAllTimeByCategoryChart();
    }

    renderNewByCategoryChart() {
        if (!this.chartJsReady || !this.newByCategoryData) return;
        const canvas = this.refs?.newByCategoryCanvas;
        if (!canvas) return;
        destroyChart(this.newByCategoryChart);

        this.newByCategoryChart = createChart(canvas, {
            type: 'horizontalBar',
            data: {
                labels: this.newByCategoryData.map((d) => d.name),
                datasets: [
                    {
                        label: 'New (30 days)',
                        data: this.newByCategoryData.map((d) => d.value),
                        backgroundColor: HAMILTON.gold
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

    renderAllTimeByCategoryChart() {
        if (!this.chartJsReady || !this.allTimeByCategoryData) return;
        const canvas = this.refs?.allTimeByCategoryCanvas;
        if (!canvas) return;
        destroyChart(this.allTimeByCategoryChart);

        this.allTimeByCategoryChart = createChart(canvas, {
            type: 'horizontalBar',
            data: {
                labels: this.allTimeByCategoryData.map((d) => d.name),
                datasets: [
                    {
                        label: 'All-time',
                        data: this.allTimeByCategoryData.map((d) => d.value),
                        backgroundColor: HAMILTON.navy
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

    async handleRefresh() {
        this.isLoading = true;
        try {
            await refreshApex(this.wiredKpisResult);
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

    get formattedNoCategoryCount() {
        return fmt(this.noCategoryCount);
    }
}