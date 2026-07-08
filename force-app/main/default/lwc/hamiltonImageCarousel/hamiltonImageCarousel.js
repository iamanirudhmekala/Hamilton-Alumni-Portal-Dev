import { LightningElement, track } from 'lwc';

const CAROUSEL_SLIDES = [
    { id: '1', caption: 'Support Hamilton Students', index: 0, imgUrl: 'https://s3.amazonaws.com/mediacdn.hamilton.edu/images/16:9/1220/1sciencecenteratrium1015amjpg.jpg' },
    { id: '2', caption: 'Invest in Academic Excellence', index: 1, imgUrl: 'https://s3.amazonaws.com/mediacdn.hamilton.edu/images/base/chapelaerialf22web1800jpg.jpg' },
    { id: '3', caption: 'Build the Future Together', index: 2, imgUrl: 'https://s3.amazonaws.com/mediacdn.hamilton.edu/images/16:9/1220/dji0010jpg.jpg' }
];

export default class HamiltonImageCarousel extends LightningElement {
    @track currentSlideIndex = 0;
    intervalId;

    get slides() {
        return CAROUSEL_SLIDES.map((slide, index) => ({
            ...slide,
            cssClass: index === this.currentSlideIndex ? 'carousel-slide active' : 'carousel-slide',
            indicatorClass: index === this.currentSlideIndex ? 'carousel-indicator active' : 'carousel-indicator'
        }));
    }

    connectedCallback() {
        // Auto-advance carousel every 5 seconds
        this.startAutoAdvance();
    }

    disconnectedCallback() {
        this.stopAutoAdvance();
    }

    startAutoAdvance() {
        this.intervalId = setInterval(() => {
            this.handleNext();
        }, 5000);
    }

    stopAutoAdvance() {
        if (this.intervalId) {
            clearInterval(this.intervalId);
        }
    }

    handleNext() {
        this.currentSlideIndex = (this.currentSlideIndex + 1) % CAROUSEL_SLIDES.length;
    }

    handlePrevious() {
        this.currentSlideIndex = (this.currentSlideIndex - 1 + CAROUSEL_SLIDES.length) % CAROUSEL_SLIDES.length;
        this.resetAutoAdvance();
    }

    handleIndicatorClick(event) {
        const index = parseInt(event.target.dataset.index, 10);
        this.currentSlideIndex = index;
        this.resetAutoAdvance();
    }

    resetAutoAdvance() {
        this.stopAutoAdvance();
        this.startAutoAdvance();
    }
}