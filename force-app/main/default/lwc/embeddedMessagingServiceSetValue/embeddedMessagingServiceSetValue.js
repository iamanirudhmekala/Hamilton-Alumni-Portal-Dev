import { LightningElement , api , wire } from 'lwc';
import Id from '@salesforce/user/Id';
import Email from '@salesforce/schema/User.Email';
import ContactId from '@salesforce/schema/User.ContactId';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
const fields = [Email , ContactId];
export default class EmbeddedMessagingServiceSetValue extends LightningElement {
    userId = Id;
    user; 
    
    @wire(getRecord, { recordId: '$userId', fields })
    wiredRecord({ error, data }) {
    if (error) {
         let message = "Unknown error";
        if (Array.isArray(error.body)) {
            message = error.body.map((e) => e.message).join(", ");
        } else if (typeof error.body.message === "string") {
            message = error.body.message;
        }
         console.error("Error loading user record:" + message);
        } else if (data) {
          this.user = data;
          console.log('this.user = ' + JSON.stringify(this.user))
          var selectedEvent = new CustomEvent('Current_User_Id',
            {
                detail: {
                    email: getFieldValue(this.user, ContactId)
                },
                bubbles: true,
                composed: true
            });
            // Dispatches the event.
          window.dispatchEvent(selectedEvent);
        }
    }
}