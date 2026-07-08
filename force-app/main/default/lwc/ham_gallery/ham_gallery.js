/**
 * @file ham_Gallery.js
 * @description Gallery carousel component that displays images and videos in a responsive
 *              slideshow format. Supports both desktop (3-slide view) and mobile (single-slide)
 *              layouts with auto-sliding, touch/swipe gestures, and modal video playback.
 * 
 * @component ham_Gallery
 * @author [Your Name]
 * @date [Current Date]
 * 
 * @features
 * - Responsive design (desktop carousel vs mobile slider)
 * - Auto-sliding with configurable delay
 * - Touch/swipe support for mobile navigation
 * - YouTube video integration with thumbnail generation
 * - MP4 video support with inline playback
 * - Modal view for mobile media playback
 * - Dynamic landscape/portrait detection for images
 */

import { LightningElement, wire, track, api } from 'lwc';
import getGallery from '@salesforce/apex/HAM_HomePageController.getGalleryConfig';

// ============================================================
// Static Resources
// ============================================================
import VIDEO_ICON from '@salesforce/resourceUrl/ham_GalleryVideoIcon';
import NO_GALLERY from '@salesforce/resourceUrl/ham_noGallery';

// ============================================================
// Custom Labels
// ============================================================
import AUTO_SLIDE_DELAY from '@salesforce/label/c.ham_gallerySlideDelay';
import GALLERY from '@salesforce/label/c.ham_gallery';

export default class Ham_Gallery extends LightningElement {

    // ============================================================
    // Constants & Configuration
    // ============================================================
    
    /** @type {string} Component key for fetching gallery configuration from metadata */
    GALLERY_KEY = 'GalleryGridLWC';

    /** @type {string} Custom label for fetching gallery heading */
    gallery = GALLERY;
    
    /** @type {number} Auto-slide interval duration in milliseconds (from custom label) */
    slideDelay = Number(AUTO_SLIDE_DELAY);
    
    /** @type {string} Static resource URL for video play icon overlay */
    videoIcon = VIDEO_ICON;
    
    /** @type {string} Static resource URL for empty gallery placeholder image */
    noGallery = NO_GALLERY;

    // ============================================================
    // Tracked Properties (Reactive)
    // ============================================================
    
    /** @type {Array} Gallery items with processed media metadata */
    @track items = [];
    
    /** @type {number} Currently active slide index */
    @track currentIndex = 0;
    
    /** @type {boolean} Flag indicating mobile viewport (<=1024px) */
    @track isMobile = false;
    
    /** @type {boolean} Controls visibility of mobile media modal */
    @track showModal = false;
    
    /** @type {Object} Currently selected media item for modal display */
    @track activeMedia;
    
    /** @type {boolean} Flag indicating if gallery has items to display */
    @track galleryAvailable;

    // ============================================================
    // Private Properties (Non-reactive)
    // ============================================================
    
    /** @type {number|null} Interval ID for auto-slide timer */
    autoSlideInterval;
    
    /** @type {number} X-coordinate where touch gesture started */
    touchStartX = 0;
    
    /** @type {number} X-coordinate where touch gesture ended */
    touchEndX = 0;
    
    /** @type {boolean} Flag to disable swipe during video playback */
    swipeDisabled = false;
    
    /** @type {boolean} Flag indicating if touch movement occurred (vs tap) */
    touchMoved = false;

    @api isOverride = false;

    // ============================================================
    // Lifecycle Hooks
    // ============================================================

    /**
     * @description Initializes component when inserted into DOM.
     *              Sets up viewport detection, resize listener, and auto-slide.
     */
    connectedCallback() {
        this.checkViewport();
        window.addEventListener('resize', this.handleResize.bind(this));
        this.startAutoSlide();
    }

    /**
     * @description Cleanup when component is removed from DOM.
     *              Removes event listeners and clears intervals to prevent memory leaks.
     */
    disconnectedCallback() {
        window.removeEventListener('resize', this.handleResize.bind(this));
        this.stopAutoSlide();
    }

    // ============================================================
    // Viewport & Responsive Handlers
    // ============================================================

    /**
     * @description Debounce handler for window resize events.
     *              Re-evaluates viewport size for responsive layout switching.
     */
    handleResize() {
        this.checkViewport();
    }

    /**
     * @description Determines if current viewport is mobile/tablet.
     *              Breakpoint: 1024px (matches CSS media queries).
     */
    checkViewport() {
        this.isMobile = window.innerWidth <= 1024;
    }

    // ============================================================
    // Wire Adapter - Data Fetching
    // ============================================================

    /**
     * @description Fetches gallery configuration and records from Apex controller.
     *              Processes each record to determine media type and generate
     *              appropriate URLs for thumbnails and embeds.
     * 
     * @param {Object} result - Wire adapter result containing data/error
     * @param {Object} result.data - ComponentConfigData from Apex
     */
    @wire(getGallery, { componentKey: '$GALLERY_KEY' })
    wiredGallery({ data }) {
        if (!data) return;
        
        if (data.records.length > 0) {
            this.galleryAvailable = true;
            
            // Transform raw records into display-ready items with media metadata
            this.items = data.records.map((rec, index) => {
                const mediaUrl = rec.HAM_Image_URL__c;
                
                // Determine video type (YouTube vs MP4 vs Image)
                const isYouTube = rec.HAM_Is_Video_Content__c && this.isYouTubeVideo(mediaUrl);
                const isMp4 = rec.HAM_Is_Video_Content__c && this.isMp4Video(mediaUrl);
                
                // Extract YouTube video ID for thumbnail and embed generation
                const ytId = isYouTube ? this.getYouTubeId(mediaUrl) : null;
                
                return {
                    ...rec,
                    index,
                    // Videos default to landscape; images detected on load
                    isLandscape: rec.HAM_Is_Video_Content__c,
                    isYouTube,
                    isMp4,
                    // YouTube high-quality thumbnail URL
                    youtubethumbnail: isYouTube
                        ? `https://img.youtube.com/vi/${ytId}/hqdefault.jpg`
                        : null,
                    // YouTube embed URL with autoplay enabled
                    embedUrl: isYouTube
                        ? `https://www.youtube.com/embed/${ytId}?autoplay=1&mute=0&controls=1&playsinline=1`
                        : null,
                    // Direct MP4 video URL
                    videoUrl: isMp4 ? mediaUrl : null,
                    // Fallback thumbnail for MP4 videos
                    videoThumbnail: isMp4 ? this.videoIcon : null,
                    // Tracks if video is currently playing
                    isPlaying: false
                };
            });
        } else {
            this.galleryAvailable = false;
        }
    }

    // ============================================================
    // Getters - Computed Properties for Template
    // ============================================================

    /**
     * @description Generates CSS transform for mobile carousel track.
     *              Uses translate3d for GPU-accelerated smooth sliding.
     * @returns {string} Inline style string for transform property
     */
    get mobileTrackStyle() {
        return `transform: translate3d(-${this.currentIndex * 100}%, 0, 0);`;
    }

    /**
     * @description Checks if the currently centered slide is landscape orientation.
     *              Used for CSS class application and spacing adjustments.
     * @returns {boolean} True if center slide is landscape
     */
    get centerIsLandscape() {
        if (!this.items.length) return false;
        return this.items[this.currentIndex].isLandscape;
    }

    /**
     * @description Generates desktop stage container class based on center slide orientation.
     *              Applies different styling for landscape vs portrait center slides.
     * @returns {string} CSS class string for desktop stage
     */
    get desktopStageClass() {
        return this.centerIsLandscape 
            ? 'desktop-stage center-landscape' 
            : 'desktop-stage center-portrait';
    }

    /**
     * @description Generates slide items with position classes for 3-slide desktop carousel.
     *              Calculates left, center, right positions using modular arithmetic
     *              for infinite loop effect.
     * 
     * @returns {Array} Items array with added positionClass property
     * 
     * Position Layout:
     * [LEFT] [CENTER] [RIGHT]
     *   ↑       ↑        ↑
     *  prev   current   next
     */
    get slidesWithPosition() {
        if (!this.items.length) return [];
        
        const len = this.items.length;
        
        return this.items.map((item, index) => {
            let positionClass = 'hidden-slide';
            
            // Calculate adjacent slide indices with wraparound
            const leftIndex = (this.currentIndex - 1 + len) % len;
            const rightIndex = (this.currentIndex + 1) % len;
            
            // Assign position based on relationship to current index
            if (index === this.currentIndex) {
                positionClass = 'center';
            } else if (index === leftIndex) {
                positionClass = 'left';
            } else if (index === rightIndex) {
                positionClass = 'right';
            }
            
            // Add orientation class for aspect ratio styling
            const landscapeClass = item.isLandscape ? 'landscape' : 'portrait';
            
            return {
                ...item,
                positionClass: `slide ${positionClass} ${landscapeClass}`
            };
        });
    }

    /**
     * @description Generates dot indicator items with active state styling.
     *              Used for carousel pagination/navigation dots.
     * @returns {Array} Items array with added dotClass property
     */
    get dotItems() {
        return this.items.map((item, index) => ({
            ...item,
            dotClass: index === this.currentIndex ? 'dot active-dot' : 'dot'
        }));
    }

    get wrapperClass() {
        return this.isOverride
            ? 'slds-p-around_medium mobile-view kirkland-override'
            : 'slds-p-around_medium mobile-view';
    }

    // ============================================================
    // Auto-Slide Controls
    // ============================================================

    /**
     * @description Initiates automatic slide advancement at configured interval.
     *              Skips advancement during video playback or modal display.
     *              Prevents multiple intervals from being created.
     */
    startAutoSlide() {
        // Guard against duplicate intervals
        if (this.autoSlideInterval) return;
        
        this.autoSlideInterval = setInterval(() => {
            // Only advance if not interacting with video or modal
            if (!this.swipeDisabled && !this.showModal) {
                this.nextSlide();
            }
        }, this.slideDelay);
    }

    /**
     * @description Stops automatic slide advancement.
     *              Called during user interaction and component cleanup.
     */
    stopAutoSlide() {
        clearInterval(this.autoSlideInterval);
        this.autoSlideInterval = null;
    }

    // ============================================================
    // Navigation Methods
    // ============================================================

    /**
     * @description Advances to the next slide with wraparound to beginning.
     *              Resets any playing video state.
     */
    nextSlide() {
        this.currentIndex = (this.currentIndex + 1) % this.items.length;
        this.resetPlayingState();
    }

    /**
     * @description Returns to the previous slide with wraparound to end.
     *              Resets any playing video state.
     */
    prevSlide() {
        this.currentIndex = (this.currentIndex - 1 + this.items.length) % this.items.length;
        this.resetPlayingState();
    }

    /**
     * @description Navigates directly to a specific slide via dot indicator click.
     * @param {Event} event - Click event from dot element with data-index attribute
     */
    goToSlide(event) {
        const newIndex = Number(event.currentTarget.dataset.index);
        
        // Only update if clicking a different slide
        if (newIndex !== this.currentIndex) {
            this.currentIndex = newIndex;
            this.resetPlayingState();
        }
    }

    /**
     * @description Resets all items to non-playing state and re-enables swipe.
     *              Called after any navigation action to ensure clean state.
     */
    resetPlayingState() {
        this.items = this.items.map(item => ({
            ...item,
            isPlaying: false
        }));
        this.swipeDisabled = false;
    }

    // ============================================================
    // Media Interaction Handlers
    // ============================================================

    /**
     * @description Handles click/tap on gallery media items.
     *              Behavior differs based on device type and slide position:
     *              - Mobile: Opens modal for any media
     *              - Desktop non-center: Navigates to clicked slide
     *              - Desktop center: Toggles video playback
     * 
     * @param {Event} event - Click event with data-id attribute
     */
    handleMediaClick(event) {
        event.stopPropagation();

        const id = event.currentTarget.dataset.id;
        const index = this.items.findIndex(i => i.Id === id);
        
        if (index === -1) return;

        // MOBILE: Always open modal for media viewing
        if (this.isMobile) {
            this.activeMedia = this.items[index];
            this.showModal = true;
            this.swipeDisabled = true;
            this.stopAutoSlide();
            return;
        }

        // DESKTOP: Navigate to slide if clicking non-center item
        if (index !== this.currentIndex) {
            this.currentIndex = index;
            this.resetPlayingState();
            return;
        }

        // DESKTOP CENTER: Toggle video playback state
        this.items = this.items.map((item, i) => ({
            ...item,
            isPlaying: i === index ? !item.isPlaying : false
        }));

        // Disable swipe while video is playing to prevent accidental navigation
        this.swipeDisabled =
            this.items[index].HAM_Is_Video_Content__c && this.items[index].isPlaying;
    }

    /**
     * @description Closes the mobile media modal and resumes auto-slide.
     */
    closeModal() {
        this.showModal = false;
        this.swipeDisabled = false;
        this.startAutoSlide();
    }

    // ============================================================
    // Touch/Swipe Gesture Handlers
    // ============================================================

    /**
     * @description Records starting position of touch gesture.
     * @param {TouchEvent} e - Touch start event
     */
    handleTouchStart(e) {
        if (this.swipeDisabled) return;
        
        this.touchStartX = e.touches[0].clientX;
        this.touchMoved = false;
    }

    /**
     * @description Tracks touch movement and determines if swipe occurred.
     *              Sets touchMoved flag if movement exceeds 10px threshold.
     * @param {TouchEvent} e - Touch move event
     */
    handleTouchMove(e) {
        if (this.swipeDisabled) return;
        
        this.touchEndX = e.touches[0].clientX;
        
        // Threshold to distinguish swipe from tap
        if (Math.abs(this.touchStartX - this.touchEndX) > 10) {
            this.touchMoved = true;
        }
    }

    /**
     * @description Processes completed touch gesture to trigger slide navigation.
     *              Requires minimum 50px swipe distance to trigger navigation.
     *              Swipe left (negative diff) = next slide
     *              Swipe right (positive diff) = previous slide
     */
    handleTouchEnd() {
        // Only process swipes on mobile when enabled and movement detected
        if (!this.isMobile || this.swipeDisabled || !this.touchMoved) return;

        const diff = this.touchStartX - this.touchEndX;
        
        // Minimum swipe distance threshold
        if (Math.abs(diff) < 50) return;

        // Navigate based on swipe direction
        diff > 0 ? this.nextSlide() : this.prevSlide();
    }

    // ============================================================
    // Video URL Utility Methods
    // ============================================================

    /**
     * @description Extracts YouTube video ID from various URL formats.
     *              Supports: youtu.be, watch?v=, and embed/ formats.
     * 
     * @param {string} url - YouTube video URL
     * @returns {string|null} YouTube video ID or null if extraction fails
     * 
     * @example
     * getYouTubeId('https://youtu.be/dQw4w9WgXcQ') // Returns 'dQw4w9WgXcQ'
     * getYouTubeId('https://www.youtube.com/watch?v=dQw4w9WgXcQ') // Returns 'dQw4w9WgXcQ'
     */
    getYouTubeId(url) {
        try {
            if (url.includes('youtu.be/')) {
                return url.split('youtu.be/')[1].split('?')[0];
            }
            if (url.includes('watch?v=')) {
                return url.split('watch?v=')[1].split('&')[0];
            }
            if (url.includes('embed/')) {
                return url.split('embed/')[1].split('?')[0];
            }
        } catch {
            return null;
        }
        return null;
    }

    /**
     * @description Determines if URL points to a YouTube video.
     * @param {string} url - URL to check
     * @returns {boolean} True if URL is a YouTube link
     */
    isYouTubeVideo(url) {
        return url && (url.includes('youtube.com') || url.includes('youtu.be'));
    }

    /**
     * @description Determines if URL points to an MP4 video file.
     * @param {string} url - URL to check
     * @returns {boolean} True if URL ends with .mp4 extension
     */
    isMp4Video(url) {
        return url && url.toLowerCase().endsWith('.mp4');
    }

    // ============================================================
    // Image Load Handler
    // ============================================================

    /**
     * @description Handles image load event to detect actual image orientation.
     *              Updates item's isLandscape property based on natural dimensions.
     *              This allows accurate styling after image dimensions are known.
     * 
     * @param {Event} event - Image load event
     */
    handleImageLoad(event) {
        const img = event.target;
        const id = img.dataset.id;
        
        if (!id) return;

        // Determine orientation from natural (intrinsic) image dimensions
        const isLandscape = img.naturalWidth > img.naturalHeight;

        // Update only the specific item that loaded
        this.items = this.items.map(item =>
            item.Id === id ? { ...item, isLandscape } : item
        );
    }
}