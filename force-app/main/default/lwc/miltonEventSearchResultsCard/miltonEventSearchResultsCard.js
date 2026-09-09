import { LightningElement, api } from 'lwc';

export default class MiltonEventSearchResultsCard extends LightningElement {

    _value;
    eventData = [];
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
        return this.currentIndex >= this.eventData.length - 1;
    }

    processRecords() {
        const records = this._value?.events || [];

        this.eventData = records.map((event) => ({
            ...event,
            dateTimeLabel: this.buildDateTimeLabel(event)
        }));
        this.currentIndex = 0;
    }

    buildDateTimeLabel(event) {
        if (!event.startDate) {
            return '';
        }
        return event.startTime ? `${event.startDate} at ${event.startTime}` : event.startDate;
    }

    handlePrev() {
        this.scrollToIndex(this.currentIndex - 1);
    }

    handleNext() {
        this.scrollToIndex(this.currentIndex + 1);
    }

    scrollToIndex(index) {
        const container = this.template.querySelector('.event-list-container');
        if (!container) {
            return;
        }
        const clampedIndex = Math.max(0, Math.min(index, this.eventData.length - 1));
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