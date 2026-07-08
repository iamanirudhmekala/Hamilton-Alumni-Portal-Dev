import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class HamJEDINavToJedi extends NavigationMixin(LightningElement) {

    handleNavigateToJEDI() {
        // Navigate to Gift Officer Dashboard app in same tab
        this[NavigationMixin.Navigate]({
            type: 'standard__app',
            attributes: {
                appTarget: 'c__Gift_Officer_Dashboard'
            }
        });
    }
}