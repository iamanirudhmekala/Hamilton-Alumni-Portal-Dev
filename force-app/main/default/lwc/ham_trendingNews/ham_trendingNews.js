import { LightningElement, wire, track,api } from 'lwc';
import getNewsConfig from '@salesforce/apex/HAM_HomePageController.getNewsConfig';

export default class Ham_TrendingNews extends LightningElement {
    NEWS_KEY = 'NewsFeedLWC';
    
    @track configData;
    @track error;
    @api label={};
    @api images = {};
    @api isOverride

    // Use @wire to fetch data efficiently and cache results
    @wire(getNewsConfig, { componentKey: '$NEWS_KEY' })
    wiredgetNewsConfig({ error, data }) {
        if (data) {
            this.configData = data;
            //console.log('@@NEws ',JSON.stringify(this.configData));
            this.error = undefined;
            this.error = undefined;
        } else if (error) {
            console.error('Error fetching News data:', error);
            this.configData = null; // Pass null to trigger no-data state in child
            this.error = error;
        }
    }
}