import { api, LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import { RefreshEvent } from 'lightning/refresh';
import verifyAddress from '@salesforce/apex/HamGoogleAddressVerifyController.verifyAddress';
import confirmAddress from '@salesforce/apex/HamGoogleAddressVerifyController.confirmAddress';

const BASE_COLUMNS = [
    { label: 'Street 1', fieldName: 'addressLine1', type: 'text' },
    { label: 'Street 2', fieldName: 'addressLine2', type: 'text' },
    { label: 'City', fieldName: 'city', type: 'text' },
    { label: 'State', fieldName: 'state', type: 'text' },
    { label: 'County', fieldName: 'county', type: 'text' },
    { label: 'Postal Code', fieldName: 'postalCode', type: 'text' },
    { label: 'Country', fieldName: 'country', type: 'text' },
    { label: 'Match/DPV Code', fieldName: 'dpvMatchCode', type: 'text' },
    { label: 'Vacant', fieldName: 'dpvVacant', type: 'text' },
    { label: 'Verification Status', fieldName: 'verificationStatus', type: 'text' },
    { label: 'Address Precision', fieldName: 'addressPrecision', type: 'text' }
];

const ACTION_COLUMN = {
    type: 'button',
    typeAttributes: {
        label: 'Confirm Address',
        name: 'confirm',
        variant: 'brand',
        disabled: { fieldName: 'isConfirming' }
    },
    cellAttributes: { alignment: 'center' },
    fixedWidth: 170
};

const NOTE_COLUMN = { label: 'Note', fieldName: 'statusNote', type: 'text', wrapText: true };

export default class HamGoogleAddressVerify extends LightningElement {
    @api recordId;

    @track isExpanded = false;
    @track isLoading = false;
    @track isConfirming = false;
    @track results = [];
    @track hasRun = false;
    @track errorMessage = null;

    get accordionIconName() {
        return this.isExpanded ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get hasResult() {
        return this.results && this.results.length > 0;
    }

    get isAmbiguous() {
        return this.results && this.results.length > 1;
    }

    get verifyButtonLabel() {
        return this.hasRun ? 'Verify Again' : 'Verify Address';
    }

    get columns() {
        // Per-row notes only matter when staff are choosing between candidates; with a
        // single result the caveat is shown in the banner above instead.
        return this.isAmbiguous
            ? [...BASE_COLUMNS, NOTE_COLUMN, ACTION_COLUMN]
            : [...BASE_COLUMNS, ACTION_COLUMN];
    }

    get tableData() {
        return (this.results || []).map((r, idx) => ({
            rowKey: `${this.recordId}-${idx}`,
            // Index back into this.results on confirm; reading a primitive off the row
            // proxy is safe, whereas spreading the whole row is not.
            rowIndex: idx,
            isConfirming: this.isConfirming,
            addressLine1: r.addressLine1,
            addressLine2: r.addressLine2,
            city: r.city,
            state: r.state,
            county: r.county,
            postalCode: r.postalCode,
            country: r.country,
            dpvMatchCode: r.dpvMatchCode,
            dpvVacant: r.dpvVacant,
            verificationStatus: r.verificationStatus,
            addressPrecision: r.addressPrecision,
            statusNote: r.statusNote
        }));
    }

    /** Caveat banner, shown only for an unambiguous single match. */
    get statusNote() {
        return !this.isAmbiguous && this.results?.length === 1 ? this.results[0].statusNote : null;
    }

    get ambiguityMessage() {
        return `Google returned ${this.results.length} possible matches. Review them and confirm the correct one.`;
    }

    get sourceLabel() {
        return this.results?.length ? this.results[0].verificationSource : null;
    }

    handleAccordionToggle() {
        // Deliberately does NOT auto-verify: each verify is a billable API call, so it
        // only runs when staff explicitly ask for it.
        this.isExpanded = !this.isExpanded;
    }

    handleVerify() {
        this.isLoading = true;
        this.errorMessage = null;
        verifyAddress({ addressId: this.recordId })
            .then((results) => {
                this.results = results || [];
                this.hasRun = true;
                if (this.results.length === 0) {
                    this.errorMessage = 'Google returned no matches for this address.';
                }
            })
            .catch((error) => {
                this.results = [];
                this.hasRun = true;
                this.errorMessage = error?.body?.message || 'Unable to verify this address.';
                this.showToast('Verification Failed', this.errorMessage, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleRowAction(event) {
        const { action, row } = event.detail;
        if (action.name === 'confirm') {
            this.handleConfirmAddress(row.rowIndex);
        }
    }

    handleConfirmAddress(rowIndex) {
        const r = this.results?.[rowIndex];
        if (!r) {
            this.showToast('Confirm Failed', 'Could not read the selected match. Please verify again.', 'error');
            return;
        }

        this.isConfirming = true;

        // Serialize the whole Apex result rather than hand-listing fields. A manual list
        // silently drops any field added server-side later (that is how the audit fields
        // went missing). JSON.stringify reads correctly through the framework's read-only
        // proxies, whereas spreading the object or passing it as a complex Apex parameter
        // yields all-null fields under Lightning Web Security.
        const verifiedJson = JSON.stringify(r);

        confirmAddress({ addressId: this.recordId, verifiedJson })
            .then(() => {
                this.showToast(
                    'Address Confirmed',
                    `The address has been updated from ${r.verificationSource}.`,
                    'success'
                );
                // notifyRecordUpdateAvailable alone does not reliably repaint the standard
                // Details panel, which makes a successful save look like nothing happened.
                // RefreshEvent asks the record page itself to reload.
                notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
                this.dispatchEvent(new RefreshEvent());
                // Drop the now-stale candidate rows; they describe the pre-save record.
                this.results = [];
                this.hasRun = false;
            })
            .catch((error) => {
                this.showToast(
                    'Confirm Failed',
                    error?.body?.message || 'Unable to save the confirmed address.',
                    'error'
                );
            })
            .finally(() => {
                this.isConfirming = false;
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}