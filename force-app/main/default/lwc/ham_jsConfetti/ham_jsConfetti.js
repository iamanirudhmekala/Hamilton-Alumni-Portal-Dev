import { LightningElement, api } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import jsConfettiResource from '@salesforce/resourceUrl/Ham_jsConfetti';

export default class Ham_jsConfetti extends LightningElement {
    
    @api type = 'confetti';
    @api size = 'large';
    @api number = 'large';
    @api emojis = '🎉,🎈,🎊,✨';
    @api autoRepeat = false; // Auto-repeat confetti
    @api repeatInterval = 10000; // 10 seconds
    
    jsConfettiInstance;
    canvas;
    libraryLoaded = false;
    intervalId;
    
    connectedCallback() {
        this.createCanvas();
    }
    
    renderedCallback() {
        if (this.libraryLoaded) {
            return;
        }
        
        loadScript(this, jsConfettiResource)
            .then(() => {
                this.libraryLoaded = true;
                this.initializeConfetti();
            })
            .catch(error => {
                console.error('Error loading js-confetti library:', error);
            });
    }
    
    createCanvas() {
        if (this.canvas) return;
        
        // Get the parent component's bounding box
        const parentElement = this.template.host.parentElement;
        
        this.canvas = document.createElement('canvas');
        // Position canvas relative to parent component, not full screen
        this.canvas.style.cssText = 'position:absolute;top:0;left:0;width:100%;height:100%;pointer-events:none;z-index:100';
        
        // Append to parent element to scope it to the component
        if (parentElement) {
            parentElement.style.position = 'relative'; // Ensure parent is positioned
            parentElement.appendChild(this.canvas);
        }
    }
    
    initializeConfetti() {
        try {
            this.jsConfettiInstance = new JSConfetti({ canvas: this.canvas });
            
            // Fire immediately
            setTimeout(() => {
                this.fireConfetti();
            }, 300);
            
            // Set up auto-repeat if enabled
            if (this.autoRepeat) {
                this.intervalId = setInterval(() => {
                    this.fireConfetti();
                }, this.repeatInterval);
            }
        } catch (error) {
            console.error('Error initializing confetti:', error);
        }
    }
    
    fireConfetti() {
        if (!this.jsConfettiInstance) return;
        
        if (this.type === 'emoji') {
            this.fireEmojiConfetti();
        } else {
            this.fireRealisticConfetti();
        }
    }
    
    fireEmojiConfetti() {
        const emojiArray = this.emojis.split(',').map(e => e.trim());
        
        this.jsConfettiInstance.addConfetti({
            emojis: emojiArray,
            emojiSize: this.getEmojiSize(),
            confettiNumber: this.getConfettiNumber()
        });
    }
    
    fireRealisticConfetti() {
        const colors = [
            '#FF1493', '#FFD700', '#00CED1', '#FF6347', 
            '#9370DB', '#32CD32', '#FF69B4', '#4169E1', 
            '#FFA500', '#7FFF00', '#DA70D6', '#40E0D0', 
            '#FF4500', '#ADFF2F', '#1E90FF', '#FF1493'
        ];
        
        // Fire confetti with rectangular shapes
        this.jsConfettiInstance.addConfetti({
            confettiColors: colors,
            confettiRadius: this.getConfettiRadius(),
            confettiNumber: this.getRealisticConfettiNumber()
        });
    }
    
    getEmojiSize() {
        const sizes = { 'small': 40, 'medium': 60, 'large': 80 };
        const baseSize = sizes[this.size] || 60;
        return window.innerWidth < 1024 ? baseSize * 0.7 : baseSize;
    }
    
    getConfettiNumber() {
        const numbers = { 'small': 30, 'medium': 50, 'large': 70 };
        let count = numbers[this.number] || 50;
        return window.innerWidth < 1024 ? Math.floor(count * 0.6) : count;
    }
    
    getConfettiRadius() {
        // For rectangular effect, use smaller radius with custom shapes
        const radii = { 'small': 3, 'medium': 5, 'large': 7 };
        return radii[this.size] || 5;
    }
    
    getRealisticConfettiNumber() {
        const numbers = { 'small': 80, 'medium': 120, 'large': 160 };
        let count = numbers[this.number] || 120;
        return window.innerWidth < 1024 ? Math.floor(count * 0.7) : count;
    }
    
    disconnectedCallback() {
        // Clear the interval
        if (this.intervalId) {
            clearInterval(this.intervalId);
        }
        
        // Remove canvas
        if (this.canvas && this.canvas.parentNode) {
            this.canvas.parentNode.removeChild(this.canvas);
        }
    }
}