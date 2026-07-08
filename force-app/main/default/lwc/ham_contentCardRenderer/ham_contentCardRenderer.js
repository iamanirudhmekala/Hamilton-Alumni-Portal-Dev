import { LightningElement, api } from 'lwc';
import siteDefaultImageResource from '@salesforce/resourceUrl/HAM_SiteFallbackImage';
import siteDefaultImageResourceKirkland from '@salesforce/resourceUrl/HAM_SiteFallbackImage_Kirkland';


const DEFAULT_IMAGE_URL = siteDefaultImageResource;
const DEFAULT_IMAGE_URL_Kirkland = siteDefaultImageResourceKirkland;


export default class Ham_contentCardRenderer extends LightningElement {
    @api records = [];
    @api viewMode = 'grid';
    @api contentType = 'news';
    @api isOverride = false;

    get wrapperClass() {
        return this.isOverride ? 'card-renderer-wrapper kirkland-override' : 'card-renderer-wrapper';
    }

    get isGridView() {
        return this.viewMode !== 'list';
    }

    get isListView() {
        return this.viewMode === 'list';
    }

    // Returns the Kirkland fallback image when in override mode, otherwise the standard one.
    get defaultImageUrl() {
        return this.isOverride ? DEFAULT_IMAGE_URL_Kirkland : DEFAULT_IMAGE_URL;
    }

    handleImageError(event) {
        event.target.onerror = null;
        event.target.src = this.defaultImageUrl;
    }

    handleReadMore(event) {
        const linkUrl = event.currentTarget.dataset.link;
        if (linkUrl && linkUrl !== '#') {
            window.open(linkUrl, '_blank');
        }
    }

    get buttonLabel() {
        switch(this.contentType) {
            case 'resource':
                return 'Click Here';
            case 'news':
                return 'Read More';
            default:
                return 'View';
        }
    }

    get footerClass() {
        return this.contentType === 'resource'
        ? this.viewMode === 'list'
            ? ''
            : 'card-footer'
        : this.viewMode === 'list'
            ? 'list-footer'
            : 'card-footer';
    }
}