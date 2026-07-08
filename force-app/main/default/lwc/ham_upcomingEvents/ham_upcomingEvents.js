import { LightningElement, api, track } from 'lwc';
import getHomePageEvents from '@salesforce/apex/Ham_UpcomingEventsController.getHomePageEvents';
import siteDefaultImageResource from '@salesforce/resourceUrl/HAM_SiteFallbackImage';
import ham_homeEventsRegister       from '@salesforce/label/c.ham_homeEventsRegister';
import ham_homeEventsModifyRegister from '@salesforce/label/c.ham_homeEventsModifyRegister';
import siteDefaultImageResourceKirkland from '@salesforce/resourceUrl/HAM_SiteFallbackImage_Kirkland';


const DEFAULT_IMAGE_URL = siteDefaultImageResource;
const DEFAULT_IMAGE_URL_Kirkland = siteDefaultImageResourceKirkland;


const stripHtml = (html) => {
    if (!html) return '';
    return html
        .replace(/<[^>]*>/g, ' ')
        .replace(/&nbsp;/gi, ' ')
        .replace(/&amp;/gi,  '&')
        .replace(/&lt;/gi,   '<')
        .replace(/&gt;/gi,   '>')
        .replace(/&quot;/gi, '"')
        .replace(/&#39;/gi,  "'")
        .replace(/\s+/g,     ' ')
        .trim();
};

export default class Ham_UpcomingEvents extends LightningElement {

    // ── Public API properties ────────────────────────────────────────────────
    /**
     * Contact Id of the logged-in portal user — provided by a parent component.
     * Uses a getter/setter so the imperative Apex call fires automatically the
     * moment the parent sets the value — mirrors the reactivity @wire provided.
     */
    _usercontactId;
    @api
    get usercontactId()      { return this._usercontactId; }
    set usercontactId(value) {
        this._usercontactId = value;
        if (value) { this.loadEvents(); }
    }
    @api label   = {};
    @api images  = {};

    // isOverride uses a manual getter/setter to match the existing pattern
    _isOverride = false;
    @api
    set isOverride(value) { this._isOverride = value; }
    get isOverride()      { return this._isOverride; }

    // ── Internal state ───────────────────────────────────────────────────────
    @track isLoading     = true;
    @track activeFilter  = 'In Person';   // default toggle state
    @track inPersonEvents = [];           // processed In-Person event list
    @track virtualEvents  = [];           // processed Virtual event list
    @track screenWidth   = window.innerWidth;

    placeholders = [1, 2, 3];            // skeleton card count

    // ── Lifecycle hooks ──────────────────────────────────────────────────────
    connectedCallback() {
        window.addEventListener('resize', this.handleResize.bind(this));
    }

    disconnectedCallback() {
        window.removeEventListener('resize', this.handleResize.bind(this));
    }

    handleResize() {
        this.screenWidth = window.innerWidth;
    }

    // ── Imperative Apex call ──────────────────────────────────────────────────
    /**
     * Fetches both In-Person and Virtual events in a single Apex call.
     * Called from the usercontactId setter so it fires as soon as the parent
     * supplies the contactId — same timing as the old @wire reactive call.
     * Non-cacheable so registration status (isRegistered / personalizedLink)
     * is always fresh and never served from a stale client-side wire cache.
     */
    loadEvents() {

        getHomePageEvents({ contactId: this._usercontactId })
            .then(data => {
                this.inPersonEvents = this.processEvents(data.inPersonEvents || []);
                this.virtualEvents  = this.processEvents(data.virtualEvents  || []);
                this.isLoading = false;
            })
            .catch(error => {
                console.error('Ham_UpcomingEvents — error fetching events:', JSON.stringify(error));
                this.inPersonEvents = [];
                this.virtualEvents  = [];
                this.isLoading = false;
            });
    }

    // ── Data processing ──────────────────────────────────────────────────────
    /**
     * Converts raw Apex EventItem records into display-ready objects:
     *  - formats start/end dates into a single dateLine string
     *  - builds locationLine
     *  - trims description to fit the card (length differs by breakpoint)
     *  - ensures a fallback image URL
     */
    processEvents(events) {
        const maxLen = this.screenWidth < 1024 ? 140 : 190;

        return events.map(ev => {
            const formattedStart = this.formatDate(ev.startDate);
            const formattedEnd   = this.formatDate(ev.endDate);

            // Build date line: "Jun 11, 2026" or "Jun 11, 2026 - Jun 14, 2026"
            let dateLine = formattedStart || '';
            if (formattedEnd && formattedEnd !== formattedStart) {
                dateLine += (dateLine ? ` - ${formattedEnd}` : formattedEnd);
            }

            return {
                ...ev,
                title             : stripHtml(ev.title),
                imageUrl          : ev.imageUrl || this.defaultImageUrl,
                dateLine          : dateLine,
                locationLine      : ev.location || '',
                fullDescription   : ev.description || '',
                trimmedDescription: this.smartTrim(stripHtml(ev.description), maxLen),
                // Dynamic button: label and URL depend on whether the user is already registered
                buttonLabel: ev.isRegistered ? ham_homeEventsModifyRegister : ham_homeEventsRegister,
                buttonUrl  : ev.isRegistered
                    ? (ev.personalizedLink || ev.registrationLink || '')   // registered → personalized link, fallback to reg link
                    : (ev.registrationLink || '')                          // unregistered → package registration link
            };
        });
    }

    // ── Computed properties ──────────────────────────────────────────────────

    /**
     * Returns the event list for the active toggle, capped at 3 (desktop) or 1 (mobile).
     * Slicing happens in JS so the Apex query always fetches exactly 3 and caches them.
     */
    get displayedEvents() {
        const source = this.activeFilter === 'In Person'
            ? this.inPersonEvents
            : this.virtualEvents;
        return this.isMobileView ? source.slice(0, 1) : source.slice(0, 3);
    }

    get hasEvents() {
        return this.displayedEvents && this.displayedEvents.length > 0;
    }

    get isDesktopView() { return this.screenWidth >= 1024; }
    get isMobileView()  { return this.screenWidth < 1024; }

    get kirklandOverrideClass() {
        return this._isOverride ? 'kirkland-override' : '';
    }

    // Returns the Kirkland fallback image when in override mode, otherwise the standard one.
    get defaultImageUrl() {
        return this._isOverride ? DEFAULT_IMAGE_URL_Kirkland : DEFAULT_IMAGE_URL;
    }

    // Toggle button CSS classes (active = filled background)
    get inPersonClass() {
        if (this.activeFilter === 'In Person') return 'custom-btn active';
        return this._isOverride ? 'custom-btn kirkland-inactive' : 'custom-btn';
    }
    get virtualClass() {
        if (this.activeFilter === 'Virtual') return 'custom-btn active';
        return this._isOverride ? 'custom-btn kirkland-inactive' : 'custom-btn';
    }

    // Toggle button icons — swap to active variant when selected
    get inPersonImg() {
        return this.activeFilter === 'In Person'
            ? this.images.inpersonActiveImage
            : this.images.inpersonImage;
    }
    get virtualImg() {
        return this.activeFilter === 'Virtual'
            ? this.images.virtualActiveImage
            : this.images.virtualImage;
    }
    get kirklandInPersonImg() {
        return this.activeFilter === 'In Person'
            ? this.images.inpersonActiveImage
            : this.images.inPersonGreen;
    }
    get kirklandVirtualImg() {
        return this.activeFilter === 'Virtual'
            ? this.images.virtualActiveImage
            : this.images.virtualGreen;
    }

    // Mobile view: show the first event's image (or fallback)
    get mobileImageUrl() {
        const source = this.activeFilter === 'In Person'
            ? this.inPersonEvents
            : this.virtualEvents;
        return source && source.length > 0 && source[0].imageUrl
            ? source[0].imageUrl
            : this.defaultImageUrl;
    }
    get mobileImageClass() {
        const source = this.activeFilter === 'In Person'
            ? this.inPersonEvents
            : this.virtualEvents;
        const hasActualImage = source && source.length > 0 && source[0].imageUrl;
        return hasActualImage ? 'img-border' : 'img-border fallback-img-16-9';
    }

    // ── Event handlers ───────────────────────────────────────────────────────

    /** Switches the active filter; displayedEvents getter updates the template. */
    handleFilterChange(event) {
        this.activeFilter = event.target.dataset.filter;
    }

    /** Clicking anywhere on the card opens the registration link. */
    handleCardClick(event) {
        const url = event.currentTarget.dataset.link;
        if (url && url !== '#') {
            window.open(url, '_blank');
        }
    }

    /**
     * The Register button sits inside a card that also has an onclick.
     * stopPropagation prevents the card handler from firing a second time.
     */
    handleRegisterClick(event) {
        event.stopPropagation();
        event.preventDefault();
        const url = event.target.dataset.url;
        if (url) {
            window.open(url, '_blank');
        }
    }

    /** Replaces a broken image src with the site-level fallback. */
    handleImageError(event) {
        event.target.onerror = null;
        event.target.src = this.defaultImageUrl;
    }

    /**
     * Fires the same 'navigateevent' custom event the rest of the homepage
     * components use, so the grandparent can redirect to the full Events page.
     */
    handleNavigateToAll() {
        this.dispatchEvent(new CustomEvent('navigateevent', {
            detail  : this.label.events,
            bubbles : true,
            composed: true
        }));
    }

    // ── Utility helpers ──────────────────────────────────────────────────────

    /**
     * Converts a date string from Apex to 'Jun 11, 2026' display format.
     *
     * Apex serializes Date fields as 'YYYY-MM-DD' and DateTime fields as
     * 'YYYY-MM-DD HH:MM:SS' (space separator, not ISO 'T'). Both formats are
     * normalized here before parsing so the browser never sees an invalid date.
     * Returns '' for null, blank, or '-' placeholder values.
     */
    formatDate(dateStr) {
        if (!dateStr || dateStr === '-') return '';
        // Normalize: replace the space separator Apex uses with 'T' for ISO format
        // e.g. '2026-06-14 00:00:00' → '2026-06-14T00:00:00' (valid ISO, parses correctly)
        const normalized = dateStr.trim().replace(' ', 'T');
        const date = new Date(normalized);
        if (isNaN(date.getTime())) return '';
        return date.toLocaleDateString('en-US', {
            month: 'short', day: 'numeric', year: 'numeric'
        });
    }

    /**
     * Trims text to maxLength characters at the nearest word boundary
     * and appends '...' — prevents mid-word cuts in the description.
     */
    smartTrim(text, maxLength = 190) {
        if (!text || text.length <= maxLength) return text;
        let truncated = text.slice(0, maxLength);
        const lastSpace = truncated.lastIndexOf(' ');
        if (lastSpace > -1) truncated = truncated.slice(0, lastSpace);
        return truncated.trim() + '...';
    }
}