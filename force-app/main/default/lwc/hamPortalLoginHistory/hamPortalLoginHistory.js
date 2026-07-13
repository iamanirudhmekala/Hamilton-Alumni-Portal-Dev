import { LightningElement } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import CHARTJS from '@salesforce/resourceUrl/HAMQuadChartJS';
import searchPortalLogins from '@salesforce/apex/HAM_PortalLoginHistoryController.searchPortalLogins';

const COLUMNS = [
    { label: 'Contact', fieldName: 'contactName', type: 'text' },
    { label: 'Email', fieldName: 'email', type: 'email' },
    { label: 'User', fieldName: 'userName', type: 'text' },
    { label: 'Login Time', fieldName: 'loginTimeDisplay', type: 'text' },
    { label: 'Status', fieldName: 'status', type: 'text' },
    { label: 'Source IP', fieldName: 'sourceIp', type: 'text' },
    { label: 'Application', fieldName: 'application', type: 'text' },
    { label: 'Browser', fieldName: 'browser', type: 'text' },
    { label: 'Platform', fieldName: 'platform', type: 'text' }
];

const PAGE_SIZE = 15;
const SEARCH_DEBOUNCE_MS = 300;
const RESULT_CAP = 5000;
const FILTER_FIELDS = ['status', 'platform', 'application', 'browser'];

function formatLoginTime(value) {
    if (!value) {
        return '';
    }
    const d = new Date(value);
    const mm = String(d.getMonth() + 1).padStart(2, '0');
    const dd = String(d.getDate()).padStart(2, '0');
    const yyyy = d.getFullYear();
    let hours = d.getHours();
    const minutes = String(d.getMinutes()).padStart(2, '0');
    const ampm = hours >= 12 ? 'PM' : 'AM';
    hours %= 12;
    if (hours === 0) {
        hours = 12;
    }
    return `${mm}-${dd}-${yyyy} ${hours}:${minutes} ${ampm}`;
}

export default class HamPortalLoginHistory extends LightningElement {
    columns = COLUMNS;
    days = '180';
    searchTerm = '';
    logins = [];
    error;
    isLoading = false;
    currentPage = 1;

    statusFilter = '';
    platformFilter = '';
    applicationFilter = '';
    browserFilter = '';

    windowOptions = [
        { label: 'Last 30 days', value: '30' },
        { label: 'Last 90 days', value: '90' },
        { label: 'Last 180 days', value: '180' }
    ];

    chartJsLoaded = false;
    chart;
    searchTimeoutId;

    connectedCallback() {
        loadScript(this, CHARTJS)
            .then(() => {
                this.chartJsLoaded = true;
                this.renderChartIfReady();
            })
            .catch(() => {
                this.error = 'Unable to load charting library.';
            });
        // Default view: all portal users' logins combined, no search required
        this.loadLogins();
    }

    renderedCallback() {
        if (this.filteredLogins.length === 0) {
            this.destroyChart();
            return;
        }
        this.renderChartIfReady();
    }

    disconnectedCallback() {
        window.clearTimeout(this.searchTimeoutId);
        this.destroyChart();
    }

    handleSearchInput(event) {
        const value = event.target.value;
        window.clearTimeout(this.searchTimeoutId);
        this.searchTimeoutId = setTimeout(() => {
            this.searchTerm = value.trim();
            this.loadLogins();
        }, SEARCH_DEBOUNCE_MS);
    }

    handleDaysChange(event) {
        this.days = event.detail.value;
        this.loadLogins();
    }

    handleFilterChange(event) {
        const field = event.target.dataset.filter;
        this[`${field}Filter`] = event.detail.value;
        this.currentPage = 1;
    }

    handlePrevPage() {
        if (!this.isFirstPage) {
            this.currentPage -= 1;
        }
    }

    handleNextPage() {
        if (!this.isLastPage) {
            this.currentPage += 1;
        }
    }

    loadLogins() {
        this.isLoading = true;
        searchPortalLogins({ searchTerm: this.searchTerm, days: parseInt(this.days, 10) })
            .then((data) => {
                this.logins = data.map((row) => ({
                    ...row,
                    loginTimeDisplay: formatLoginTime(row.loginTime)
                }));
                this.currentPage = 1;
                this.statusFilter = '';
                this.platformFilter = '';
                this.applicationFilter = '';
                this.browserFilter = '';
                this.error = undefined;
                if (this.logins.length === 0) {
                    this.destroyChart();
                }
            })
            .catch((err) => {
                this.error = err;
                this.logins = [];
                this.destroyChart();
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    get hasData() {
        return this.logins.length > 0;
    }

    get showNoResults() {
        return !this.isLoading && !this.hasData && !this.error;
    }

    get isTruncated() {
        return this.logins.length >= RESULT_CAP;
    }

    get filteredLogins() {
        return this.logins.filter((row) =>
            (!this.statusFilter || row.status === this.statusFilter) &&
            (!this.platformFilter || row.platform === this.platformFilter) &&
            (!this.applicationFilter || row.application === this.applicationFilter) &&
            (!this.browserFilter || row.browser === this.browserFilter)
        );
    }

    get showNoFilterMatches() {
        return this.hasData && this.filteredLogins.length === 0;
    }

    buildFilterOptions(field) {
        const values = new Set();
        this.logins.forEach((row) => {
            if (row[field]) {
                values.add(row[field]);
            }
        });
        return [{ label: 'All', value: '' }, ...Array.from(values).sort().map((v) => ({ label: v, value: v }))];
    }

    get statusOptions() {
        return this.buildFilterOptions('status');
    }

    get platformOptions() {
        return this.buildFilterOptions('platform');
    }

    get applicationOptions() {
        return this.buildFilterOptions('application');
    }

    get browserOptions() {
        return this.buildFilterOptions('browser');
    }

    get chartScopeLabel() {
        const scope = this.searchTerm ? `"${this.searchTerm}"` : 'all portal users';
        const activeFilters = FILTER_FIELDS
            .filter((field) => this[`${field}Filter`])
            .map((field) => `${field}: ${this[`${field}Filter`]}`);
        const suffix = activeFilters.length ? ` (${activeFilters.join(', ')})` : '';
        return `Logins per day — ${scope}${suffix}`;
    }

    get totalPages() {
        return Math.max(1, Math.ceil(this.filteredLogins.length / PAGE_SIZE));
    }

    get pagedLogins() {
        const start = (this.currentPage - 1) * PAGE_SIZE;
        return this.filteredLogins.slice(start, start + PAGE_SIZE);
    }

    get isFirstPage() {
        return this.currentPage <= 1;
    }

    get isLastPage() {
        return this.currentPage >= this.totalPages;
    }

    get pageLabel() {
        return `Page ${this.currentPage} of ${this.totalPages} (${this.filteredLogins.length} logins)`;
    }

    get chartData() {
        const countsByDay = new Map();
        this.filteredLogins.forEach((row) => {
            const day = new Date(row.loginTime).toISOString().slice(0, 10);
            countsByDay.set(day, (countsByDay.get(day) || 0) + 1);
        });
        const sortedDays = Array.from(countsByDay.keys()).sort();
        return {
            labels: sortedDays,
            counts: sortedDays.map((day) => countsByDay.get(day))
        };
    }

    renderChartIfReady() {
        const canvas = this.template.querySelector('canvas.login-chart');
        if (!this.chartJsLoaded || !canvas) {
            return;
        }
        const { labels, counts } = this.chartData;

        if (this.chart) {
            this.chart.data.labels = labels;
            this.chart.data.datasets[0].data = counts;
            this.chart.data.datasets[0].label = this.chartScopeLabel;
            this.chart.update();
            return;
        }

        // eslint-disable-next-line no-undef
        this.chart = new Chart(canvas.getContext('2d'), {
            type: 'line',
            data: {
                labels,
                datasets: [{
                    label: this.chartScopeLabel,
                    data: counts,
                    borderColor: '#1589EE',
                    backgroundColor: 'rgba(21, 137, 238, 0.1)',
                    fill: true,
                    tension: 0.1
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                scales: {
                    xAxes: [{ scaleLabel: { display: true, labelString: 'Date' } }],
                    yAxes: [{ ticks: { beginAtZero: true, precision: 0 }, scaleLabel: { display: true, labelString: 'Logins' } }]
                }
            }
        });
    }

    destroyChart() {
        if (this.chart) {
            this.chart.destroy();
            this.chart = undefined;
        }
    }
}