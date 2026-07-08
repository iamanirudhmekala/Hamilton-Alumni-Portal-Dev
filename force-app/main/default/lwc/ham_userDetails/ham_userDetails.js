import { LightningElement, wire } from 'lwc';
import fetchLoggedInUserInfo from '@salesforce/apex/HAM_MainController.fetchLoggedInUserInfo';

export default class Ham_userDetails extends LightningElement {

    @wire(fetchLoggedInUserInfo)
    wiredContact({ error, data }) {
         
        if (error) {
            let message = 'Unknown error';
            if (Array.isArray(error.body)) {
                message = error.body.map((e) => e.message).join(', ');
            } else if (typeof error.body.message === 'string') {
                message = error.body.message;
            }
            console.error('Error loading contact record: ' + message);
        } else if (data) {
            window.dispatchEvent(new CustomEvent('Current_User_Id', {
                detail: { contactId: data.Id },
                bubbles: true,
                composed: true
            }));
        }
    }
}