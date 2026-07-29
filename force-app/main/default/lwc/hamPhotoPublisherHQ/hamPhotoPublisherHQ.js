import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getFileContext from '@salesforce/apex/HAMFilePublisherController.getFileContext';
import publishProfilePicture from '@salesforce/apex/HAMFilePublisherController.publishProfilePicture';

export default class HamPhotoPublisherHQ extends LightningElement {
    @api recordId; // ContentDocument Id, injected automatically on the File record page
 
    fileContext;
    wiredContextResult;
    isPublishing = false;
    loadError;
 
    @wire(getFileContext, { contentDocumentId: '$recordId' })
    wiredContext(result) {
        this.wiredContextResult = result;
        if (result.data) {
            this.fileContext = result.data;
            this.loadError = undefined;
        } else if (result.error) {
            this.loadError = this.reduceError(result.error);
        }
    }
 
    get hasContext() {
        return !!this.fileContext;
    }
 
    get hasSingleContact() {
        return this.fileContext && this.fileContext.linkedContactCount === 1;
    }
 
    get noContactMessage() {
        if (!this.fileContext) return '';
        if (this.fileContext.linkedContactCount === 0) {
            return 'This file is not linked to any Contact yet.';
        }
        if (this.fileContext.linkedContactCount > 1) {
            return `This file is linked to ${this.fileContext.linkedContactCount} Contacts. Remove the extra relationship(s) before publishing.`;
        }
        return '';
    }
 
    get notImageMessage() {
        return this.fileContext && !this.fileContext.isImage
            ? 'This file type is not an image, so it cannot be published as a profile picture.'
            : '';
    }
 
    get canPublish() {
        return this.hasSingleContact && this.fileContext.isImage && !this.isPublishing;
    }
 
    get publishDisabled() {
        return !this.canPublish;
    }
 
    get buttonLabel() {
        return this.isPublishing ? 'Publishing…' : 'Publish';
    }
 
    handlePublish() {
        this.isPublishing = true;
 
        publishProfilePicture({ contentDocumentId: this.recordId })
            .then(() => {
                this.isPublishing = false;
                this.showToast(
                    'Success',
                    `Profile picture published to ${this.fileContext.contactName}.`,
                    'success'
                );
                return refreshApex(this.wiredContextResult);
            })
            .catch((error) => {
                this.isPublishing = false;
                this.showToast('Error publishing profile picture', this.reduceError(error), 'error');
            });
    }
 
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
 
    reduceError(error) {
        if (error?.body?.message) return error.body.message;
        if (error?.message) return error.message;
        return 'Unknown error';
    }
}