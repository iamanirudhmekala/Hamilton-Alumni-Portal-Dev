import { LightningElement, api, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { subscribe, unsubscribe, MessageContext } from 'lightning/messageService';
import getRedirectionCardImages from '@salesforce/apex/HAM_HomePageController.getRedirectionCardImages';
import THUMBNAIL_REFRESH_CHANNEL from '@salesforce/messageChannel/ham_HomeThumbnailRefresh__c';
import VOLUNTEER_SYNC_CHANNEL from '@salesforce/messageChannel/VolunteerOpportunitySync__c';
import HAM_ICONS from '@salesforce/resourceUrl/Redirection_Icons';
import siteDefaultImageResource from '@salesforce/resourceUrl/HAM_SiteFallbackImage';
import siteDefaultImageResourceKirkland from '@salesforce/resourceUrl/HAM_SiteFallbackImage_Kirkland';



const DEFAULT_IMAGE_URL = siteDefaultImageResource;
const DEFAULT_IMAGE_URL_Kirkland = siteDefaultImageResourceKirkland;


// imageFile is the production thumbnail — kept as the fallback for every card whose
// dynamic image does not resolve. Webcam has no file in the static resource yet, so it
// falls back to the site default image until one is added.
const CARDS = [
    { id: 'directory', title: 'Directory',                colorClass: 'card-bg-1', imageFile: '/directory-card-bg.png' },
    { id: 'impact',    title: 'My Impact',                colorClass: 'card-bg-2', imageFile: '/my-impact-bg.png' },
    { id: 'news',      title: 'News',                     colorClass: 'card-bg-3', imageFile: '/news-bg.png' },
    { id: 'events',    title: 'Events',                   colorClass: 'card-bg-4', imageFile: '/events-bg.png' },
    { id: 'gallery',   title: 'Gallery',                  colorClass: 'card-bg-5', imageFile: '/gallery-bg.jpg' },
    { id: 'trivia',    title: 'Trivia',                   colorClass: 'card-bg-6', imageFile: '/trivia-bg.png' },
    { id: 'volunteer', title: 'Volunteer Opportunities',  colorClass: 'card-bg-7', imageFile: '/volunteer-bg.png' },
    { id: 'webcam',    title: 'Webcam',                   colorClass: 'card-bg-8', imageFile: null },
];

const STUDENT_CARD_IDS = new Set(['directory', 'news', 'gallery', 'trivia']);
const VISIBLE_COUNT = 4;

export default class Ham_RedirectionCards extends LightningElement {
    @api isOverride = false;
    @api isStudent  = false;
    @api usercontactId;
    @track scrollIndex = 0;

    // Card id → { imageUrl, linkUrl } resolved in Apex. Empty until the wire returns,
    // so the strip renders its production images first and never flashes blank.
    @track cardImages = {};

    hamIcons = HAM_ICONS;

    wiredImagesResult;
    subscriptions = [];

    @wire(MessageContext) messageContext;

    @wire(getRedirectionCardImages, { contactId: '$usercontactId' })
    wiredCardImages(result) {
        this.wiredImagesResult = result;
        const { data, error } = result;
        if (data) {
            this.cardImages = data;
        }
        if (error) {
            // A failure here is not fatal — every card keeps its production image.
            console.log('Error getting redirection card images:', error);
            this.cardImages = {};
        }
    }

    connectedCallback() {
        this.subscribeToRefreshChannels();
    }

    disconnectedCallback() {
        this.unsubscribeFromRefreshChannels();
    }

    /**
     * Thumbnails have to keep up with what the user does on the page — making a
     * connection, showing interest in an opportunity — without a page reload.
     * Volunteer changes already broadcast on VolunteerOpportunitySync; connection
     * changes broadcast on ham_HomeThumbnailRefresh.
     */
    subscribeToRefreshChannels() {
        if (!this.messageContext || this.subscriptions.length) {
            return;
        }
        this.subscriptions = [
            subscribe(this.messageContext, THUMBNAIL_REFRESH_CHANNEL, () => this.refreshThumbnails()),
            subscribe(this.messageContext, VOLUNTEER_SYNC_CHANNEL,    () => this.refreshThumbnails())
        ];
    }

    unsubscribeFromRefreshChannels() {
        this.subscriptions.forEach(sub => unsubscribe(sub));
        this.subscriptions = [];
    }

    /** Re-resolves every thumbnail. Also callable by the parent when the home view returns. */
    @api
    refreshThumbnails() {
        if (this.wiredImagesResult) {
            refreshApex(this.wiredImagesResult);
        }
    }

    get arrowLeftIcon()  { return this.isOverride ? this.hamIcons + '/arro-left-green.png' : this.hamIcons + '/arro-left.png'; }
    get arrowRightIcon() { return this.isOverride ? this.hamIcons + '/arrow-right-green.png' : this.hamIcons + '/arrow-right.png'; }

    get sectionClass() {
        return this.isOverride ? 'redir-section kirkland-override' : 'redir-section';
    }

    get _filteredCards() {
        return this.isStudent ? CARDS.filter(c => STUDENT_CARD_IDS.has(c.id)) : CARDS;
    }

    get maxScroll() {
        return Math.max(0, this._filteredCards.length - VISIBLE_COUNT);
    }

     // Returns the Kirkland fallback image when in override mode, otherwise the standard one.
    get defaultImageUrl() {
        return this.isOverride ? DEFAULT_IMAGE_URL_Kirkland : DEFAULT_IMAGE_URL;
    }

    get cards() {
        return this._filteredCards.map(c => {
            // Production image for this card — also the fallback when a dynamic URL is
            // missing or fails to load.
            const staticImageUrl = c.imageFile ? `${this.hamIcons}/${c.imageFile}` : this.defaultImageUrl;
            const dynamicCard    = this.cardImages ? this.cardImages[c.id] : null;

            return {
                ...c,
                imageUrl: (dynamicCard && dynamicCard.imageUrl) ? dynamicCard.imageUrl : staticImageUrl,
                fallbackUrl: staticImageUrl,
                // Only Webcam carries a link; the rest scroll to their section on the page.
                linkUrl: (dynamicCard && dynamicCard.linkUrl) ? dynamicCard.linkUrl : '',
                cardClass: `redir-card ${c.colorClass}`
            };
        });
    }

    get isLeftDisabled()  { return this.scrollIndex === 0; }
    get isRightDisabled() { return this.scrollIndex >= this.maxScroll; }

    get leftBtnClass()  { return `arrow-btn${this.isLeftDisabled  ? ' arrow-disabled' : ''}`; }
    get rightBtnClass() { return `arrow-btn${this.isRightDisabled ? ' arrow-disabled' : ''}`; }

    handlePrev() {
        if (!this.isLeftDisabled) {
            this.scrollIndex--;
            this._scrollTrack();
        }
    }

    handleNext() {
        if (!this.isRightDisabled) {
            this.scrollIndex++;
            this._scrollTrack();
        }
    }

    _scrollTrack() {
        const wrapper = this.template.querySelector('.card-track-wrapper');
        const card    = this.template.querySelector('.redir-card');
        if (wrapper && card) {
            const step = card.getBoundingClientRect().width + 16;
            wrapper.scrollTo({ left: this.scrollIndex * step, behavior: 'smooth' });
        }
    }

    /**
     * Dynamic thumbnails are external URLs, so a dead link has to degrade to the
     * production image. Clearing onerror first stops a broken fallback looping.
     */
    handleImageError(event) {
        const fallbackUrl = event.target.dataset.fallback;
        event.target.onerror = null;
        if (fallbackUrl && event.target.src !== fallbackUrl) {
            event.target.src = fallbackUrl;
        }
    }

    handleCardClick(event) {
        const linkUrl = event.currentTarget.dataset.link;

        // Webcam points at an external resource, matching the Resources tab behaviour.
        if (linkUrl) {
            window.open(linkUrl, '_blank');
            return;
        }

        const sectionId = event.currentTarget.dataset.id;
        this.dispatchEvent(new CustomEvent('scrolltosection', {
            detail: sectionId,
            bubbles: true,
            composed: true
        }));
    }
}