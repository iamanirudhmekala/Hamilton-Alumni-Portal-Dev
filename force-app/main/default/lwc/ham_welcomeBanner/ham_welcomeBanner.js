import { LightningElement, api } from 'lwc';

export default class Ham_WelcomeBanner extends LightningElement {
    @api userName;
    @api userFirstName;       // NEW — FirstName from Apex
    @api userBirthday;
    @api label = {};
    @api isKirklandAlumnae;
    @api kirklandAlumnaeIcon;
    @api badgeData = [];
    @api registeredUsersCount;
    @api isOverride = false;
    @api classYear;            // NEW — HAM_Reunion_Year__c (Text(4), e.g. "1995")
    //@api bannerImageUrl;  
    @api images;     // NEW — chapel bell background image URL

    /**
     * @description Returns the welcome/birthday greeting prefix
     */
    get welcomeText() {
        return this.isBirthday() ? this.label.happyBirthday : this.label.welcomeBack;
    }

    /**
     * @description Returns the user's first name.
     * Prefers the dedicated FirstName field; falls back to splitting full Name.
     */
    get displayFirstName() {
        if (this.userFirstName) return this.userFirstName;
        if (this.userName) return this.userName.split(' ')[0];
        return '';
    }

    /**
     * @description Formats class year as 'YY (e.g., "1995" → "'95", "95" → "'95").
     * Mirrors the pattern used in ham_myImpactCmp → splitNameAndYear.
     */
    get classYearShort() {
        if (!this.classYear) return '';
        const yearStr = String(this.classYear).trim();
        if (yearStr.length >= 4) {
            return "'" + yearStr.slice(-2);
        }
        if (yearStr.length === 2) {
            return "'" + yearStr;
        }
        return "'" + yearStr;
    }

    /**
     * @description Returns the bold display text: "FirstName 'YY"
     */
    get displayNameWithYear() {
        const name = this.displayFirstName;
        const year = this.classYearShort;
        if (name && year) return `${name} ${year}`;
        return name || '';
    }

    /**
     * @description Returns true if today is the user's birthday
     */
    get isBirthdayMessage() {
        return this.isBirthday();
    }

    get bannerContainerClass() {
        return this.isOverride ? 'banner-container kirkland-override' : 'banner-container';
    }

    /**
     * @description Checks if today's date matches the user's birthday (month and day)
     */
    isBirthday() {
        if (!this.userBirthday) return false;
        const today = new Date();
        const birthday = new Date(this.userBirthday);
        return today.getMonth() === birthday.getMonth() &&
               today.getDate() === birthday.getDate();
    }
}