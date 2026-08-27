import { LightningElement, api } from 'lwc';

export default class milton_alumniSearchResultsCard extends LightningElement {
    @api value;
    alumniData = [];
    isSuccess = true;
    statusMessage = 'No alumni records found.';

    connectedCallback() {
        console.log('[milton_alumniSearchResultsCard] connectedCallback, current value:', JSON.stringify(this.value));

        const records = this.value?.alumniRecords || [];
        this.alumniData = records.map((alumni) => ({
            ...alumni,
            degreeLabel: alumni.majorDegree ? `Degree: ${alumni.majorDegree}` : 'Degree: -',
            yearLabel: alumni.classOfYear ? `Graduation Year: ${alumni.classOfYear}` : 'Graduation Year: -'
        }));

        this.isSuccess = this.value?.isSuccess !== false;
        this.statusMessage = this.value?.statusMessage || 'No alumni records found.';

        console.log('[milton_alumniSearchResultsCard] alumniData:', JSON.stringify(this.alumniData));
    }

    get hasCards() {
        return this.alumniData.length > 0;
    }

    get statusMessageClass() {
        return this.isSuccess ? 'status-message' : 'status-message error';
    }

    handleViewDetails(event) {
        const contactId = event.currentTarget.dataset.contactId;
        console.log('[milton_alumniSearchResultsCard] View Details clicked, contactId:', contactId);
    }
}