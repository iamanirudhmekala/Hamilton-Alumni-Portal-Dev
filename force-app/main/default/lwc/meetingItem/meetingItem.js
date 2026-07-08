import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

import saveEvent from '@salesforce/apex/HamItineraryController.saveEvent';
import getMeetingStatusOptions from '@salesforce/apex/HamItineraryController.getMeetingStatusOptions';
import getStakeholdersByMeetingId from '@salesforce/apex/HamItineraryController.getStakeholdersByMeetingId';
import deleteAttendee from '@salesforce/apex/HamItineraryController.deleteAttendee';

import meetingItemForm from './meetingItemForm.html';
import meetingItemDisplay from './meetingItemDisplay.html';

export default class MeetingItem extends LightningElement {
    @api
    displayOnly;

    @track
    _meeting = {}

    @track
    attendees = [];

    meetingId;
    inputVariables = [];
    showAttendeeModal = false;
    
    @api
    get meeting() {
        return this._meeting;
    }
    set meeting(value) {
        this._meeting = Object.assign({}, value);
        if (this._meeting && this._meeting.id) {
            this.meetingId = this._meeting.id;
        }
    }

    @wire(getMeetingStatusOptions)
    wiredMeetingStatusOptions({data, error}) {
        if (data) {
            this.statusPicklistValues = data;
        } else if (error) {
            console.error('error', JSON.stringify(error));

        }
    }

    render() {
        if (this.displayOnly == 'true') {
            return meetingItemDisplay;
        } else {
            return meetingItemForm;

        }    
    }

    handleInputChange(event){
        this._meeting[event.currentTarget.name] = event.target.value;
    }

    @api
    async updateForm(tripDetailId) {
        return await saveEvent({
            eventDetail: {
                id: this._meeting.id,
                meetingTitle: this._meeting.title,
                meetingStatus: this._meeting.status,
                startDateTime: this._meeting.startDate,
                endDateTime: this._meeting.endDate,
                type: 'HAM_Meeting',
                tripDetailId: this._meeting.tripDetailId || tripDetailId,
                contactId: this._meeting.contactId,
                address: this.addressText,
                description: this._meeting.talkingPoints,
                contactReport: this._meeting.contactReport,
                attendees: this.attendees.filter(fr => !fr.id)
            }
        })
    }

    @api
    validateForm() {
        const isValidSoFar = [
            ...this.template.querySelectorAll('lightning-input'),
        ].reduce((validSoFar, inputCmp) => {
            inputCmp.reportValidity();
            return validSoFar && inputCmp.checkValidity();
        }, true);

        const startDtTmp = this.template.querySelector(`lightning-input[data-name="startDate"]`);
        const endDtTmp = this.template.querySelector(`lightning-input[data-name="endDate"]`);
        if (startDtTmp?.value && endDtTmp?.value) {
            
            const startDt = new Date(startDtTmp.value);
            const endDt = new Date(endDtTmp.value);
        
            if (startDt > endDt) {
                startDtTmp.setCustomValidity('Start Date must be before End Date');
                startDtTmp.reportValidity();
                return false;
            }
        }

        return isValidSoFar;
    }

    // attendees start
    wiredStakeholdersVar;
    @wire(getStakeholdersByMeetingId, { meetingId: '$meetingId' })
    wiredStakeholders(result) {
        this.wiredStakeholdersVar = result;
        const { data, error } = result;
        if (data) {
            this.attendees = data.map(attendee => {
                return {
                    id: attendee.Id,
                    fundraiser: attendee.ucinn_ascendv2__Fundraiser__c,
                    fundraiserName: attendee.ucinn_ascendv2__Fundraiser__r.Name,
                    fundraiserRole: attendee.ucinn_ascendv2__Fundraiser_Role__c,
                    key: attendee.ucinn_ascendv2__Fundraiser__c + attendee.ucinn_ascendv2__Fundraiser_Role__c,
                }
            });        
        }
    }

    handleStatusChange(event) {
        if (event.detail.status === 'FINISHED') {
            this.showAttendeeModal = false;

            const attendeesCollection = event.detail.outputVariables.filter(item => item.name == 'attendeesCollection')[0];

            let dupRole = [];
            for (let index = 0; index < attendeesCollection.value.length; index++) {
                const attendeeVal = attendeesCollection.value[index];

                const existingoleIdx = this.attendees.findIndex(f => f.fundraiserRole === attendeeVal.fundraiserRole);
                if (existingoleIdx === -1 || attendeeVal.fundraiserRole != 'Primary Fundraiser') {
                    this.attendees.push({ 
                        fundraiser: attendeeVal.fundraiser,
                        fundraiserRole: attendeeVal.fundraiserRole,
                        fundraiserName: attendeeVal.fundraiserName,
                        key: attendeeVal.fundraiser + attendeeVal.fundraiserRole,
                    });
                } else {
                    dupRole.push(attendeeVal.fundraiserRole);
                }
            }

            if (dupRole.length > 0) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Unable to add attendee',
                    message: `You cannot have more than 1 Primary Fundraiser on a contact report.`,
                    variant: 'warning'
                }));
            }
        }
    }

    handleRemoveAttendee(event){
        const contactReportRelationId = event.currentTarget.dataset.fundraiserId;
        const fundraiserIdx = event.currentTarget.dataset.fundraiserIdx;

        let isDeleted = true;
        if (contactReportRelationId) {
            this.dispatchEvent(new CustomEvent('deleteattendee'));
            deleteAttendee({ attendeeId: contactReportRelationId })
                .then(result => {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Attendee deleted',
                        message: `Attendee has been deleted`,
                        variant: 'success'
                    }));
                    this.dispatchEvent(new CustomEvent('deleteattendee', {
                        detail: true
                    }));
                }).catch(error => {
                    isDeleted = false;
                    console.log('@@error', JSON.stringify(error));
                    this.dispatchEvent(new CustomEvent('deleteattendee', {
                        detail: false
                    }));
                }).finally(() => {
                  
                });
        }

        if (isDeleted) {
            this.attendees.splice(fundraiserIdx, 1);
        }

    }

    showAddAttendeeModal(event){
        this.showAttendeeModal = true;
    }

    handleCloseAddAttendee() {
        this.showAttendeeModal = false;
    }

    @api
    refreshAttendees() {
        if (this.wiredStakeholdersVar) {
            refreshApex(this.wiredStakeholdersVar);
        }
    }

    get statusOptions() {
        return [
            { label: 'Planned', value: 'Planned' },
            { label: 'Scheduled', value: 'Scheduled' },
            { label: 'Rescheduled', value: 'Rescheduled' },
            { label: 'Cancelled', value: 'Cancelled' },
        ]
    }

    get addressText() {
        if (!this._meeting.address) {
            return this._meeting.hamAddress;
        }

        const addressElems = [this._meeting?.address?.Street, this._meeting?.address?.City, this._meeting?.address?.State, this._meeting?.address?.PostalCode, this._meeting?.address?.Country];
        return addressElems.filter(elem => elem).join(', ');
    }

    get city() {
        return this._meeting?.address?.City;
    }

    get country() {
        return this._meeting?.address?.Country;
    }

    get state() {
        return this._meeting?.address?.State;
    }

    get street() {
        return this._meeting?.address?.Street;
    }

    get postalCode() {
        return this._meeting?.address?.PostalCode;
    }

    get name() {
        return this._meeting.name;
    }

    get title(){
        return this._meeting.title;
    }

    get startDate(){
        return this._meeting.startDate;
    }

    get endDate(){
        return this._meeting.endDate;
    }

    get status(){
        return this._meeting.status;
    }

    get street() {
        return this._meeting.Street;
    }

    get city() {
        return this._meeting.City;
    }

    get country() {
        return this._meeting.Country;
    }

    get postalCode() {
        return this._meeting.PostalCode;
    }

    get province() {
        return this._meeting.State;
    }

    get talkingPoints() {
        return this._meeting.talkingPoints;
    }
}