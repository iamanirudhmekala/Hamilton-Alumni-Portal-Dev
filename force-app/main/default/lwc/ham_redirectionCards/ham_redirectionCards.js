import { LightningElement, api, track } from 'lwc';
import HAM_ICONS from '@salesforce/resourceUrl/Redirection_Icons';
import siteDefaultImageResource from '@salesforce/resourceUrl/HAM_SiteFallbackImage';
import siteDefaultImageResourceKirkland from '@salesforce/resourceUrl/HAM_SiteFallbackImage_Kirkland';



const DEFAULT_IMAGE_URL = siteDefaultImageResource;
const DEFAULT_IMAGE_URL_Kirkland = siteDefaultImageResourceKirkland;


const CARDS = [
    { id: 'directory', title: 'Directory',                colorClass: 'card-bg-1', imageFile: '/directory-card-bg.png' },
    { id: 'impact',    title: 'My Impact',                colorClass: 'card-bg-2', imageFile: '/my-impact-bg.png' },
    { id: 'news',      title: 'News',                     colorClass: 'card-bg-3', imageFile: '/news-bg.png' },
    { id: 'events',    title: 'Events',                   colorClass: 'card-bg-4', imageFile: '/events-bg.png' },
    { id: 'gallery',   title: 'Gallery',                  colorClass: 'card-bg-5', imageFile: '/gallery-bg.jpg' },
    { id: 'trivia',    title: 'Trivia',                   colorClass: 'card-bg-6', imageFile: '/trivia-bg.png' },
    { id: 'volunteer', title: 'Volunteer Opportunities',  colorClass: 'card-bg-7', imageFile: '/volunteer-bg.png' },
];

const STUDENT_CARD_IDS = new Set(['directory', 'news', 'gallery', 'trivia']);
const VISIBLE_COUNT = 4;

export default class Ham_RedirectionCards extends LightningElement {
    @api isOverride = false;
    @api isStudent  = false;
    @track scrollIndex = 0;

    hamIcons = HAM_ICONS;

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
        return this._isOverride ? DEFAULT_IMAGE_URL_Kirkland : DEFAULT_IMAGE_URL;
    }

    get cards() {
        return this._filteredCards.map(c => {
            const imageUrl = c.imageFile ? `${this.hamIcons}/${c.imageFile}` : this.defaultImageUrl ;
            return {
                ...c,
                cardClass: `redir-card ${c.colorClass}`,
                backgroundStyle: `background-image:url('${imageUrl}');background-size:cover;background-position:center;`,
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

    handleCardClick(event) {
        const sectionId = event.currentTarget.dataset.id;
        this.dispatchEvent(new CustomEvent('scrolltosection', {
            detail: sectionId,
            bubbles: true,
            composed: true
        }));
    }
}