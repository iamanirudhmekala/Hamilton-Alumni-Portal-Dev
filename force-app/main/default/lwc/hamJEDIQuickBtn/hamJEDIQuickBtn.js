import { LightningElement, api, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class HamJEDIQuickBtn extends LightningElement {
    @api recordId;
    @track isContactReportModalOpen = false;
    @track contactReportFlowInputVariables = [];
    @track isFlowLoading = true;
    contactReportButtonRef = null;

    @track isTaskModalOpen = false;
    @track taskFlowInputVariables = [];
    @track isTaskFlowLoading = true;
    taskButtonRef = null;

    @track isMeetingModalOpen = false;
    @track meetingFlowInputVariables = [];
    @track isMeetingFlowLoading = true;
    meetingButtonRef = null;

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference?.state?.c__recordId) {
            this.recordId = currentPageReference.state.c__recordId;
        }
    }

    // =========================================
    // Asana Form Methods
    // =========================================
    openAsanaForm() {
        window.open('https://form.asana.com/?k=oUFF2adAYc8PRU-hW3NYRQ&d=940410193405385', '_blank');
    }

    // =========================================
    // Contact Report Modal Methods
    // =========================================
    openContactReportModal(event) {
        // Save reference to the button for scrolling back after modal closes
        this.contactReportButtonRef = event.target;

        // Only pass contactId variable if recordId exists, otherwise pass empty array
        // This allows the Flow to show contact selection when no contact is pre-selected
        this.contactReportFlowInputVariables = this.recordId ? [
            {
                name: 'contactId',
                type: 'String',
                value: this.recordId
            }
        ] : [];

        console.log('Contact Report Flow Variables:', this.contactReportFlowInputVariables);
        this.isFlowLoading = true;
        this.isContactReportModalOpen = true;
    }

    closeContactReportModal() {
        this.isContactReportModalOpen = false;
        this.isFlowLoading = true; // Reset for next time

        // Scroll back to the button that opened the modal
        if (this.contactReportButtonRef) {
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => {
                this.contactReportButtonRef.scrollIntoView({ behavior: 'smooth', block: 'center' });
            }, 100);
        }
    }

    handleContactReportFlowStatusChange(event) {
        const status = event.detail.status;

        // Hide spinner and scroll modal into view once flow starts rendering
        if (status === 'STARTED' || status === 'PAUSED') {
            this.isFlowLoading = false;

            const modal = this.template.querySelector('[data-id="contactReportModal"]');
            if (modal) {
                modal.scrollIntoView({ behavior: 'smooth', block: 'start' });
            }
        }

        if (status === 'FINISHED' || status === 'FINISHED_SCREEN') {
            this.closeContactReportModal();

            // Show success toast
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Contact Report created successfully',
                    variant: 'success'
                })
            );
        }
    }

    // =========================================
    // Task Modal Methods
    // =========================================
    openTaskModal(event) {
        // Save reference to the button for scrolling back after modal closes
        this.taskButtonRef = event.target;

        // Only pass contactId variable if recordId exists, otherwise pass empty array
        // This allows the Flow to show contact selection when no contact is pre-selected
        this.taskFlowInputVariables = this.recordId ? [
            {
                name: 'contactId',
                type: 'String',
                value: this.recordId
            }
        ] : [];

        console.log('Task Flow Variables:', this.taskFlowInputVariables);
        this.isTaskFlowLoading = true;
        this.isTaskModalOpen = true;
    }

    closeTaskModal() {
        this.isTaskModalOpen = false;
        this.isTaskFlowLoading = true; // Reset for next time

        // Scroll back to the button that opened the modal
        if (this.taskButtonRef) {
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => {
                this.taskButtonRef.scrollIntoView({ behavior: 'smooth', block: 'center' });
            }, 100);
        }
    }

    handleTaskFlowStatusChange(event) {
        const status = event.detail.status;

        // Hide spinner and scroll modal into view once flow starts rendering
        if (status === 'STARTED' || status === 'PAUSED') {
            this.isTaskFlowLoading = false;

            const modal = this.template.querySelector('[data-id="taskModal"]');
            if (modal) {
                modal.scrollIntoView({ behavior: 'smooth', block: 'start' });
            }
        }

        if (status === 'FINISHED' || status === 'FINISHED_SCREEN') {
            this.closeTaskModal();

            // Show success toast
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Task created successfully',
                    variant: 'success'
                })
            );
        }
    }

    // =========================================
    // Meeting Modal Methods
    // =========================================
    openMeetingModal(event) {
        // Save reference to the button for scrolling back after modal closes
        this.meetingButtonRef = event.target;

        // Only pass contactId variable if recordId exists, otherwise pass empty array
        // This allows the Flow to show contact selection when no contact is pre-selected
        this.meetingFlowInputVariables = this.recordId ? [
            {
                name: 'contactId',
                type: 'String',
                value: this.recordId
            }
        ] : [];

        console.log('Meeting Flow Variables:', this.meetingFlowInputVariables);
        this.isMeetingFlowLoading = true;
        this.isMeetingModalOpen = true;
    }

    closeMeetingModal() {
        this.isMeetingModalOpen = false;
        this.isMeetingFlowLoading = true; // Reset for next time

        // Scroll back to the button that opened the modal
        if (this.meetingButtonRef) {
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => {
                this.meetingButtonRef.scrollIntoView({ behavior: 'smooth', block: 'center' });
            }, 100);
        }
    }

    handleMeetingFlowStatusChange(event) {
        const status = event.detail.status;

        // Hide spinner and scroll modal into view once flow starts rendering
        if (status === 'STARTED' || status === 'PAUSED') {
            this.isMeetingFlowLoading = false;

            const modal = this.template.querySelector('[data-id="meetingModal"]');
            if (modal) {
                modal.scrollIntoView({ behavior: 'smooth', block: 'start' });
            }
        }

        if (status === 'FINISHED' || status === 'FINISHED_SCREEN') {
            this.closeMeetingModal();

            // Show success toast
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Meeting created successfully',
                    variant: 'success'
                })
            );
        }
    }
}