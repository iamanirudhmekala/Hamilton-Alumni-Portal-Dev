import { LightningElement, track, wire } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import chartJsResource from '@salesforce/resourceUrl/ucinn_ascendv2__ChartJS';
import getEmployerEngagementData from '@salesforce/apex/HamCCEmployeerPipelineReviewCtr.getEmployerEngagementData';
import getEngagementTrend from '@salesforce/apex/HamCCEmployeerPipelineReviewCtr.getEngagementTrend';
const STAGE_COLORS = {
    'Prospect': {
        color: '#8B5CF6',
        gradient: ['#8B5CF6', '#A78BFA']
    },
    'Engaged': {
        color: '#3B82F6',
        gradient: ['#3B82F6', '#60A5FA']
    },
    'Highly Engaged': {
        color: '#10B981',
        gradient: ['#10B981', '#34D399']
    },
    'Impact': {
        color: '#F59E0B',
        gradient: ['#F59E0B', '#FBBF24']
    }
};

export default class HamCCEmployeerPipelineReview extends LightningElement {
    @track selectedStage = null;
    @track tableData = [];
    @track chartData = [];
    @track trendData = [];
    @track metricsCards = [];
    @track sortedBy;
    @track sortedDirection = 'asc';
    chartDomInitialized = false;
    
    chartInitialized = false;
    counter = 0;
    mainChart;
    trendChart;
    viewType = 'monthly';

    columns = [
        { 
            label: 'Employer Name', 
            fieldName: 'nameUrl',
            type: 'url',
            typeAttributes: {
                label: { fieldName: 'name' },
                target: '_blank'
            },
            sortable: true
        },
        { 
            label: 'Engagement Stage', 
            fieldName: 'stage', 
            type: 'text',
            sortable: true
        },
        { 
            label: 'Last Interaction', 
            fieldName: 'lastContact', 
            type: 'date',
            sortable: true,
            typeAttributes: {
                year: 'numeric',
                month: 'short',
                day: '2-digit'
            }
        },
        { 
            label: 'Open Positions', 
            fieldName: 'openPositions', 
            type: 'number',
            sortable: true,
            cellAttributes: { alignment: 'center' }
        },
        { 
            label: 'Applications', 
            fieldName: 'applications', 
            type: 'number',
            sortable: true,
            cellAttributes: { alignment: 'center' }
        },
        { 
            label: 'Engagement Score', 
            fieldName: 'engagementScore', 
            type: 'number',
            sortable: true,
            typeAttributes: {
                minimumFractionDigits: 0,
                maximumFractionDigits: 0
            }
        },
        { 
            label: 'Account Owner', 
            fieldName: 'owner', 
            type: 'text',
            sortable: true
        },
        {
            type: 'action',
            typeAttributes: {
                rowActions: [
                    { label: 'View Details', name: 'view_details' },
                    { label: 'Send Email', name: 'send_email' },
                    { label: 'Schedule Meeting', name: 'schedule_meeting' }
                ]
            }
        }
    ];
    
    @wire(getEmployerEngagementData)
    wiredEngagementData({ error, data }) {
        if (data) {
            console.log('data----',data);
            this.chartData = data.stages;
            console.log('data--metrics--',data.metrics);
            if(data.metrics){
                this.metricsCards = this.buildMetricsCards(data.metrics);
            }
            this.loadChartJs();
        } else if (error) {
            this.showToast('Error', 'Error loading engagement data', 'error');
            console.error('Error:', error);
        }
    }
    
    @wire(getEngagementTrend)
    wiredTrendData({ error, data }) {
        if (data) {
            console.log('data--Trend--',data);
            this.trendData = data;
            if (this.chartInitialized) {
                this.renderTrendChart();
            }
        } else if (error) {
            console.error('Error loading trend data:', error);
        }
    }

    loadChartJs() {
        console.log('chartInitialized---',this.chartInitialized);
        if (this.chartInitialized) {
            this.renderCharts();
            return;
        }

       loadScript(this, chartJsResource )
            .then(() => {
                this.chartInitialized = true;
                this.renderCharts();
            })
            .catch(error => {
                this.showToast('Error', 'Error loading Chart.js library', 'error');
                console.error('Error loading Chart.js:', error);
            });
    }

    renderCharts() {
        this.renderMainChart();
        this.renderTrendChart();
    }

    renderMainChart() {
        const canvas = this.template.querySelectorAll('canvas[lwc\\:ref="mainChart"]');
        console.log('canvas-main--',canvas);
        console.log('canvas-main--',this.chartData.length);
        if (!canvas || !this.chartData.length) return;
        console.log('Dom Init----',this.chartDomInitialized);
        if(!this.chartDomInitialized) return;
        console.log('Dom Init--Succ--',this.chartDomInitialized);
        const ctx = canvas.getContext('2d');
        if (this.mainChart) {
            this.mainChart.destroy();
        }
        console.log('Chart Data ------',  this.chartData);
        const labels = this.chartData.map(item => item.name);
        const values = this.chartData.map(item => item.value);
        const colors = this.chartData.map((item, index) => {
            const gradient = ctx.createLinearGradient(0, 400, 0, 0);
            gradient.addColorStop(0, STAGE_COLORS[item.name].gradient[0]);
            gradient.addColorStop(1, STAGE_COLORS[item.name].gradient[1]);
            return gradient;
        });

        this.mainChart = new Chart(ctx, {
            type: 'bar',
            data: {
                labels: labels,
                datasets: [{
                    label: 'Number of Employers',
                    data: values,
                    backgroundColor: colors,
                    borderRadius: 8,
                    borderSkipped: false,
                    barThickness: 60,
                    maxBarThickness: 80
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        display: false
                    },
                    tooltip: {
                        backgroundColor: 'rgba(0, 0, 0, 0.8)',
                        padding: 12,
                        titleFont: {
                            size: 14,
                            weight: 'bold'
                        },
                        bodyFont: {
                            size: 13
                        },
                        callbacks: {
                            label: (context) => {
                                return `${context.parsed.y} employers`;
                            },
                            afterLabel: (context) => {
                                const stage = this.chartData[context.dataIndex];
                                return [
                                    `Avg Engagement Score: ${stage.avgScore}`,
                                    `Total Applications: ${stage.totalApplications}`
                                ];
                            }
                        }
                    }
                },
                scales: {
                    x: {
                        beginAtZero: true,
                        grid: {
                            display: true,
                            color: 'rgba(0, 0, 0, 0.05)'
                        },
                        ticks: {
                            font: {
                                size: 12
                            }
                        }
                    },
                    y: {
                        grid: {
                            display: false
                        },
                        ticks: {
                            font: {
                                size: 13,
                                weight: '500'
                            }
                        }
                    }
                },
                onClick: (event, elements) => {
                    if (elements.length > 0) {
                        const index = elements[0].index;
                        this.handleStageClick(index);
                    }
                },
                onHover: (event, elements) => {
                    event.native.target.style.cursor = elements.length > 0 ? 'pointer' : 'default';
                }
            }
        });
        console.log('Chart Data -----',this.mainChart);
    }

    renderTrendChart() {
        const canvas = this.template.querySelector('canvas[lwc\\:ref="trendChart"]');
        if (!canvas || !this.trendData.length) return;
        if(!this.chartDomInitialized) return;
        const ctx = canvas.getContext('2d');
        if (this.trendChart) {
            this.trendChart.destroy();
        }

        const labels = this.trendData.map(item => item.month);
        const datasets = [
            {
                label: 'Prospect',
                data: this.trendData.map(item => item.initialContact),
                borderColor: STAGE_COLORS['Prospect'].color,
                backgroundColor: STAGE_COLORS['Prospect'].color + '20',
                fill: true,
                tension: 0.4
            },
            {
                label: 'Engaged',
                data: this.trendData.map(item => item.engaged),
                borderColor: STAGE_COLORS['Engaged'].color,
                backgroundColor: STAGE_COLORS['Engaged'].color + '20',
                fill: true,
                tension: 0.4
            },
            {
                label: 'Highly Engaged',
                data: this.trendData.map(item => item.activePartnership),
                borderColor: STAGE_COLORS['Highly Engaged'].color,
                backgroundColor: STAGE_COLORS['Highly Engaged'].color + '20',
                fill: true,
                tension: 0.4
            },
            {
                label: 'Impact',
                data: this.trendData.map(item => item.strategicPartner),
                borderColor: STAGE_COLORS['Impact'].color,
                backgroundColor: STAGE_COLORS['Impact'].color + '20',
                fill: true,
                tension: 0.4
            }
        ];

        this.trendChart = new Chart(ctx, {
            type: 'line',
            data: {
                labels: labels,
                datasets: datasets
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                interaction: {
                    mode: 'index',
                    intersect: false
                },
                plugins: {
                    legend: {
                        position: 'bottom',
                        labels: {
                            usePointStyle: true,
                            padding: 15,
                            font: {
                                size: 12
                            }
                        }
                    },
                    tooltip: {
                        backgroundColor: 'rgba(0, 0, 0, 0.8)',
                        padding: 12
                    }
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        grid: {
                            color: 'rgba(0, 0, 0, 0.05)'
                        }
                    },
                    x: {
                        grid: {
                            display: false
                        }
                    }
                }
            }
        });
    }

    buildMetricsCards(metrics) {
        return [
            {
                id: '1',
                label: 'Total Employers',
                value:1,
                percentage: metrics.employerGrowth,
                trendIcon: metrics.employerGrowth >= 0 ? 'utility:arrowup' : 'utility:arrowdown',
                trendClass: metrics.employerGrowth >= 0 ? 'trend-up' : 'trend-down',
                trendText: 'vs last period',
                icon: 'standard:account',
                iconContainerClass: 'slds-icon_container slds-icon-standard-account',
                cardClass: 'metric-card metric-card-purple'
            },
            {
                id: '2',
                label: 'Active Positions',
                value:2,
                percentage: metrics.positionsGrowth,
                trendIcon: metrics.positionsGrowth >= 0 ? 'utility:arrowup' : 'utility:arrowdown',
                trendClass: metrics.positionsGrowth >= 0 ? 'trend-up' : 'trend-down',
                trendText: 'vs last period',
                icon: 'standard:work_order',
                iconContainerClass: 'slds-icon_container slds-icon-standard-work-order',
                cardClass: 'metric-card metric-card-blue'
            },
            {
                id: '3',
                label: 'Total Applications',
                value: 3,
                percentage: metrics.applicationsGrowth,
                trendIcon: metrics.applicationsGrowth >= 0 ? 'utility:arrowup' : 'utility:arrowdown',
                trendClass: metrics.applicationsGrowth >= 0 ? 'trend-up' : 'trend-down',
                trendText: 'vs last period',
                icon: 'standard:orders',
                iconContainerClass: 'slds-icon_container slds-icon-standard-orders',
                cardClass: 'metric-card metric-card-green'
            },
            {
                id: '4',
                label: 'Avg Engagement Score',
                value: 4,
                percentage: metrics.scoreGrowth,
                trendIcon: metrics.scoreGrowth >= 0 ? 'utility:arrowup' : 'utility:arrowdown',
                trendClass: metrics.scoreGrowth >= 0 ? 'trend-up' : 'trend-down',
                trendText: 'vs last period',
                icon: 'standard:performance',
                iconContainerClass: 'slds-icon_container slds-icon-standard-performance',
                cardClass: 'metric-card metric-card-amber'
            }
        ];
    }

    handleStageClick(index) {
        this.selectedStage = this.chartData[index];
        this.tableData = this.selectedStage.records.slice(0, 10).map(record => ({
            ...record,
            nameUrl: `/lightning/r/Account/${record.id}/view`
        }));
    }

    handleSort(event) {
        this.sortedBy = event.detail.fieldName;
        this.sortedDirection = event.detail.sortDirection;
        this.sortData(this.sortedBy, this.sortedDirection);
    }

    sortData(fieldName, direction) {
        let parseData = JSON.parse(JSON.stringify(this.tableData));
        let keyValue = (a) => a[fieldName];
        let isReverse = direction === 'asc' ? 1: -1;
        parseData.sort((x, y) => {
            x = keyValue(x) ? keyValue(x) : '';
            y = keyValue(y) ? keyValue(y) : '';
            return isReverse * ((x > y) - (y > x));
        });
        this.tableData = parseData;
    }

    handleRowAction(event) {
        const action = event.detail.action;
        const row = event.detail.row;
        
        switch (action.name) {
            case 'view_details':
                window.open(`/lightning/r/Account/${row.id}/view`, '_blank');
                break;
            case 'send_email':
                // Implement email functionality
                this.showToast('Info', 'Email functionality to be implemented', 'info');
                break;
            case 'schedule_meeting':
                // Implement meeting scheduling
                this.showToast('Info', 'Meeting scheduling to be implemented', 'info');
                break;
        }
    }

    handleClearSelection() {
        this.selectedStage = null;
        this.tableData = [];
    }

    handleRefresh() {
        window.location.reload();
    }

    handleExport() {
        this.showToast('Info', 'Export functionality to be implemented', 'info');
    }

    handleMonthlyView() {
        this.viewType = 'monthly';
    }

    handleQuarterlyView() {
        this.viewType = 'quarterly';
    }

    handleViewAll() {
        this.showToast('Info', 'View all functionality to be implemented', 'info');
    }

    get showTable() {
        return this.selectedStage && this.tableData.length > 0;
    }

    get displayedRecordsCount() {
        return this.tableData.length;
    }

    get hasMoreRecords() {
        return this.selectedStage && this.selectedStage.value > 10;
    }

    get totalRecords() {
        return this.selectedStage ? this.selectedStage.value : 0;
    }

    get isMonthlyView() {
        return this.viewType === 'monthly' ? 'brand' : 'neutral';
    }

    get isQuarterlyView() {
        return this.viewType === 'quarterly' ? 'brand' : 'neutral';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    connectedCallback(){
        console.log('Refs-------',this.template);
        console.log('Canvas---ID----',this.template.querySelector('canvas[id="mainChartId"]'));
        //console.log('Canvas---ID---old-',this.template.querySelector('canvas[lwc\:id="mainChartId"]'));
        this.loadChartJs();
        console.log('Dom Initialized----', this.chartDomInitialized );
    }
    renderedCallback() {
        console.log('RenderCallback-------',this.template);
        
        if (!this.chartInitialized && this.chartData.length > 0) {
            console.log('Reloading---------', this.chartInitialized);
            this.chartInitialized = true;
            this.chartDomInitialized = true;
            this.renderCharts();
        }else if(this.counter && this.chartData.length > 0){
            console.log('Reloading---------', this.chartInitialized);
            this.chartInitialized = true;
            this.chartDomInitialized = true;
            this.renderCharts();
            
        }
        this.counter++;
    }
}