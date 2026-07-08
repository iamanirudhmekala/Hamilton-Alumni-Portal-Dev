import { LightningElement, track, api } from 'lwc';
import getInterests from '@salesforce/apex/HAM_MyImpactController.getInterests';
import saveInterests from '@salesforce/apex/HAM_MyImpactController.saveInterests';
import getInvolments from '@salesforce/apex/HAM_MyImpactController.getInvolments';
import saveInvolments from '@salesforce/apex/HAM_MyImpactController.saveInvolments';
import getInvolmentsUnderG from '@salesforce/apex/HAM_MyImpactController.getInvolmentsUnderG';




export default class Ham_myAffinitiesCmp extends LightningElement {
    @track showAffinities = false;
    @track interests = [];
    @track involments = [];  // Involments array
    @track isModalOpen = false;
    @track isLoading = false;
    @track isPlayedTeamModalOpen = false;
    @track isunderGradModalOpen = false;
    @track dynamicModalTitle = '';
    @track screenWidth = window.innerWidth;
    @track filteredInvolments = [];
    @track filteredInterest = [];

    
    
    @track _myAffinities = [];
    @api label = {};
    @api userContactId;
    @api isOverride = false;

     /**
     * @description Lifecycle hook that runs when the component is inserted into the DOM.
     * It sets up event listeners for window resize .
     */
    connectedCallback() {
            
        //  event listener for window resize
        window.addEventListener('resize', this.handleResize.bind(this));
        
    }

    /**
     * @description Lifecycle hook that runs when the component is removed from the DOM.
     * It removes event listeners to prevent memory leaks.
     */
    disconnectedCallback() {
     
        // Remove event listener when component is removed from DOM
        window.removeEventListener('resize', this.handleResize.bind(this));

    }

    /**
     * @description Updates the screen width property on window resize.
     */
    handleResize() {
        this.screenWidth = window.innerWidth;
    }

    get isDesktopView() {
        // Define desktop breakpoint (e.g., 769px or more)
        return this.screenWidth >= 1024;
    }

    get isMobileView() {
        return this.screenWidth < 1024;
    }

    get wrapperClass() {
        return this.isOverride ? 'affinities-wrapper kirkland-override' : 'affinities-wrapper';
    }


    toggleAffinities() {
        this.showAffinities = !this.showAffinities;
    }

    @api 
    get myAffinities() {
        return this._myAffinities;
    }

    set myAffinities(value) {

         
        if (value) {
            this._myAffinities = value.map(item => {
                return {
                    ...item,
                    showManageButton: item.displaylabel === this.label.myaffinitySectin2,
                    teamsIPlayedOnButton: item.displaylabel === this.label.myaffinitySectin1,
                    underGradOrgButton: item.displaylabel === this.label.myaffinitySectin3

                };
            });
        } else {
            this._myAffinities = [];
        }
    }
   
  

    handleOpenModal(event) {
        const dataType = event.target.dataset.type;

        if(dataType === 'Teams I Follow'){
            this.isModalOpen = true;
            this.loadData();
        }
       
        if(dataType === 'Teams I Played On'){
            this.isPlayedTeamModalOpen = true;
            this.loadInvolData(false);
        }

        if(dataType === 'My Undergraduate Organizations'){
            this.isPlayedTeamModalOpen = true;
             this.loadInvolData(true);
        }
    }

    handleCloseModal() {
        this.isModalOpen = false;
        this.isPlayedTeamModalOpen = false;
        this.isunderGradModalOpen = false;
        this.involments =[];
        this.dynamicModalTitle = '';
    }

    loadData() {
        this.isLoading = true;
        getInterests({ currentUserContactId: this.userContactId })
            .then(result => {
                // Clone result to ensure it's mutable
                this.interests = JSON.parse(JSON.stringify(result));
                this.filteredInterest = JSON.parse(JSON.stringify(result));
                this.isLoading = false;
            })
            .catch(error => {
                console.error('Error loading interests', error);
                this.isLoading = false;
            });
    }

    loadInvolData(isUnderGrad){
        this.isLoading = true;
        const action = isUnderGrad ? getInvolmentsUnderG : getInvolments;
        action({ currentUserContactId: this.userContactId })
            .then(result => {
                // Clone result to ensure it's mutable
                this.involments = JSON.parse(JSON.stringify(result));
                this.filteredInvolments = JSON.parse(JSON.stringify(result));
                if(isUnderGrad){
                   this.dynamicModalTitle = this.label.affinityUnderGradOrg;
                }else{
                   this.dynamicModalTitle = this.label.affinityTeamsIPlayed; 
                }
                //console.log('this.involments -'+JSON.stringify(result));
                this.isLoading = false;
            })
            .catch(error => {
                console.error('Error loading interests', error);
                this.isLoading = false;
            });

    }

    //Updated logic to use event.target.name
    handleCheckboxChange(event) {
        // Use 'name' to identify the row, not dataset.id, as it is more reliable in inputs
        const selectedId = event.target.name; 
        const isChecked = event.target.checked;

        const interestIndex = this.interests.findIndex(int => int.foundationInterestId === selectedId);
        if (interestIndex !== -1) {
            this.interests[interestIndex].isChecked = isChecked;
        }
    }

     handleCheckboxChangeInvol(event) {
        // Use 'name' to identify the row, not dataset.id, as it is more reliable in inputs
        const selectedId = event.target.name; 
        const isChecked = event.target.checked;

        const interestIndex = this.involments.findIndex(int => int.foundationInterestId === selectedId);
        if (interestIndex !== -1) {
            this.involments[interestIndex].isChecked = isChecked;
        }

    }

    handleSave() {
        this.isLoading = true;
        const dataStr = JSON.stringify(this.interests);

        saveInterests({ dataStr: dataStr, currentUserContactId: this.userContactId })
            .then(() => {
                this.isModalOpen = false; 
                // FIRE EVENT to Parent
                const refreshEvent = new CustomEvent('refreshdata');
                this.dispatchEvent(refreshEvent);
            })
            .catch(error => {
                console.error('Error saving records ',error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

     handleSaveInvol() {
        this.isLoading = true;
        const dataStr = JSON.stringify(this.involments);

        saveInvolments({ dataStr: dataStr, currentUserContactId: this.userContactId })
            .then(() => {
                this.isPlayedTeamModalOpen = false; 
                // FIRE EVENT to Parent
                const refreshEvent = new CustomEvent('refreshdata');
                this.dispatchEvent(refreshEvent);
            })
            .catch(error => {
                console.error('Error saving records ',error);
            })
            .finally(() => {
                this.isLoading = false;
                this.involments =[];
                this.dynamicModalTitle = '';
            });
    }

    handleSearch(event) {
        const searchKey = event.target.value.toLowerCase();

        if (!searchKey) {
            this.involments = this.filteredInvolments;
            return;
        }

        this.involments = this.filteredInvolments.filter(item =>
            item.foundationInterestName.toLowerCase().includes(searchKey)
        );
    }

    handleInterestSearch(event) {
        const searchKey = event.target.value.toLowerCase();

        if (!searchKey) {
            this.interests = this.filteredInterest;
            return;
        }

        this.interests = this.filteredInterest.filter(item =>
            item.foundationInterestName.toLowerCase().includes(searchKey)
        );
    }
}