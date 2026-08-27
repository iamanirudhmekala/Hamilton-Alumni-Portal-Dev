import { LightningElement, api } from 'lwc';

const DATE_FORMAT_OPTIONS = { year: 'numeric', month: 'short', day: 'numeric' };

export default class MiltonVolunteerServicesSearchResultsCard extends LightningElement {

    _value;
    serviceData = [];
    currentIndex = 0;

    @api
    get value() {
        return this._value;
    }

    set value(val) {
        this._value = val;
        this.processRecords();
    }

    get isFirstCard() {
        return this.currentIndex === 0;
    }

    get isLastCard() {
        return this.currentIndex >= this.serviceData.length - 1;
    }

    processRecords() {
        const records = this._value?.activities || [];

        this.serviceData = records.map((activity) => ({
            ...activity,
            dateRange: this.formatDateRange(activity)
        }));
        this.currentIndex = 0;
    }

    formatDateRange(activity) {
        const start = activity.startDate ? new Date(activity.startDate) : null;
        const end = activity.endDate ? new Date(activity.endDate) : null;
        const startStr = start ? start.toLocaleDateString('en-US', DATE_FORMAT_OPTIONS) : '';
        const endStr = end ? end.toLocaleDateString('en-US', DATE_FORMAT_OPTIONS) : '';

        let dateRange = startStr;
        if (endStr) {
            dateRange += ` - ${endStr}`;
        } else if (startStr && activity.computedTab === 'Current') {
            dateRange += ' - Present';
        }
        return dateRange;
    }

    handlePrev() {
        this.scrollToIndex(this.currentIndex - 1);
    }

    handleNext() {
        this.scrollToIndex(this.currentIndex + 1);
    }

    scrollToIndex(index) {
        const container = this.template.querySelector('.service-list-container');
        if (!container) {
            return;
        }
        const clampedIndex = Math.max(0, Math.min(index, this.serviceData.length - 1));
        container.scrollTo({ left: clampedIndex * container.clientWidth, behavior: 'smooth' });
        this.currentIndex = clampedIndex;
    }

    handleScroll(event) {
        const container = event.target;
        if (!container.clientWidth) {
            return;
        }
        this.currentIndex = Math.round(container.scrollLeft / container.clientWidth);
    }
}