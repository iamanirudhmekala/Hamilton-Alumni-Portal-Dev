import { LightningElement, api } from 'lwc';
import HAM_ICONS from '@salesforce/resourceUrl/HAM_Icons'; 

export default class Ham_previewProfileCmp extends LightningElement {
    @api profileData; // { name, year, pic, fields: [{label, value, section}] }
    @api isOverride = false;

    get wrapperClass() {
        return this.isOverride ? 'preview-wrapper kirkland-override' : 'preview-wrapper';
    }

      hamicons = {
       profileIcon: `${HAM_ICONS}/profile_icon.png`,
    }
    // --- GETTERS ---

    get socialMediaLinks() {
        if (!this.profileData || !this.profileData.fields) return [];
        
        // Filter for Social Media section ONLY (do NOT filter out empty values)
        return this.profileData.fields
            .filter(f => f.section === 'Social Media')
            .map(f => {
                // Determine icon based on Label
                let iconUrl = `${HAM_ICONS}/world.png`; 
                const label = f.label.toLowerCase();

                if (label.includes('linkedin')) {
                    iconUrl = `${HAM_ICONS}/linkedin.png`;
                } else if (label.includes('facebook')) {
                    iconUrl = `${HAM_ICONS}/facebook.png`;
                } else if (label.includes('instagram')) {
                    iconUrl = `${HAM_ICONS}/instagram.png`;
                }else if (label.includes('twitter')) {
                    iconUrl = `${HAM_ICONS}/twitter.png`;
                }

                // Check if value exists (is not empty/dash)
                const hasLink = f.value && f.value !== '-';

                return {
                    ...f,
                    iconUrl: iconUrl,
                    url: hasLink ? f.value : null,
                    // If no link, add 'disabled' class for styling
                    linkClass: hasLink ? 'my-social-link' : 'my-social-link disabled'
                };
            });
    }

    get rightColumnSections() {
        if (!this.profileData || !this.profileData.fields) return [];

        // Define display order
        const sectionOrder = ['Personal Information', 'Address Details', 'Campus Life'];
        
        // Group fields
        const grouped = {};
        this.profileData.fields.forEach(f => {
            // Exclude Social Media (handled on left)
            // Exclude Phone Type and Address Type (per requirement)
            if (f.section !== 'Social Media' && 
                f.label !== 'Phone Type' && 
                f.label !== 'Address Type' &&
                f.label !== 'Email Type') {
                
                if (!grouped[f.section]) grouped[f.section] = [];
                grouped[f.section].push(f);
            }
        });

        // Return array
        return sectionOrder.map(name => {
            if (grouped[name] && grouped[name].length > 0) {
                return { name: name, fields: grouped[name] };
            }
            return null;
        }).filter(s => s !== null);
    }

    get hasProfilePic() {
        return this.profileData && this.profileData.pic;
    }

    // --- ACTIONS ---

    handleBack() {
        this.dispatchEvent(new CustomEvent('back'));
    }

    handleSave() {
        this.dispatchEvent(new CustomEvent('save'));
    }

    handleSocialClick(event) {
        event.preventDefault();

        const targetUrl = event.currentTarget.dataset.url;
        const targetLabel = event.currentTarget.dataset.label;

        let finalUrl = '';

        if (targetLabel.includes('LinkedIn')) {
            finalUrl = 'https://www.linkedin.com/in/' + targetUrl;
        } else if (targetLabel.includes('Facebook')) {
            finalUrl = 'https://www.facebook.com/' + targetUrl;
        } else if (targetLabel.includes('Instagram')) {
            finalUrl = 'https://www.instagram.com/' + targetUrl;
        } else if (targetLabel.includes('Twitter')) {
            finalUrl = 'https://x.com/' + targetUrl;
        }

        if (!finalUrl) {
            return;
        }

        window.open(finalUrl, '_blank');
    }
    }