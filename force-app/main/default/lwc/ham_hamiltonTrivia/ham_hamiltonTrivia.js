import { LightningElement,wire,track,api} from 'lwc';
import { refreshApex } from '@salesforce/apex';

//import apex methods
import getTriviaQuestionAndOptions from '@salesforce/apex/HAM_TriviaController.getTriviaQuestionAndOptions';
import updateTriviaInfoOnConstituent from '@salesforce/apex/HAM_TriviaController.updateTriviaInfoOnConstituent';

//import needed custom labels
import LABEL_HEADING from '@salesforce/label/c.ham_TriviaHeading';
import LABEL_SUB_HEADING from '@salesforce/label/c.ham_TriviaSubHeading';
import LABEL_POINTS from '@salesforce/label/c.ham_TriviaPoints';
import LABEL_RIGHT_ANSWER from '@salesforce/label/c.ham_TriviaAnsweredRight';
import LABEL_WRONG_ANSWER from '@salesforce/label/c.ham_TriviaAnsweredWrong';
import NO_OPTION_SELECTED from '@salesforce/label/c.ham_TriviaNoOptionSelected';

//import static resorces
import NEW_TRIVIA from '@salesforce/resourceUrl/ham_NewTriviaOnTheWay';

export default class Ham_HamiltonTrivia extends LightningElement {

labels = {
    heading: LABEL_HEADING,
    subHeading: LABEL_SUB_HEADING,
    points: LABEL_POINTS,
    rightAnswer: LABEL_RIGHT_ANSWER,
    wrongAnswer: LABEL_WRONG_ANSWER,
    noOption: NO_OPTION_SELECTED
};

newTrivia = NEW_TRIVIA;
@api usercontactId;
wiredTriviaData;
@track trivia = [];
@track constituentInfo = {};
@track correctAnswerValue;
@track answeredCorrectly;
@track hasSubmitted = false;
@track selectedOption;
@track constituentScore;
@track questionPoints;
@track noOptionSelected = false;
// @track showCustomToast = false;
@api userContactId;
toastTitle;
toastVariant;
toastDuration;
toastMessage;
@track isLoading = false;
@api isOverride = false;

get wrapperClass() {
    return this.isOverride ? 'trivia-wrapper kirkland-override' : 'trivia-wrapper';
}

get containerClass() {
    return 'trivia-container slds-p-around_medium';
}

// getter that returns blur class when loading
get contentClass() {
    return this.isLoading ? 'content-blurred' : 'content-normal';
}

/*wire method to get the data from the server, we build the constituent object and trivia data and some individual data points 
 separately inorder to update individual track variables.
 This helps in fast UI updates */

@wire (getTriviaQuestionAndOptions,{ ContactId:'$usercontactId' })
    wiredTrivia(result){
    this.wiredTriviaData = result;
    const {data,error} = result;

    if(data){
        this.constituentInfo = data.Constituent ? data.Constituent : null;
        
        this.constituentInfo = {
            ...this.constituentInfo,
            HAM_Trivia_Score__c: data.Constituent.HAM_Trivia_Score__c ? data.Constituent.HAM_Trivia_Score__c : 0,
            HAM_Trivia_Attempted_Date__c: data.Constituent.HAM_Trivia_Attempted_Date__c ? data.Constituent.HAM_Trivia_Attempted_Date__c : null,
            HAM_Trivia_Option_Chosen__c: data.Constituent.HAM_Trivia_Option_Chosen__c ? data.Constituent.HAM_Trivia_Option_Chosen__c : null
        };

        this.trivia = data.Trivia ? data.Trivia : null;

        const correctOption = this.trivia && this.trivia.Trivia_Options__r?.find(opt => opt.Is_Correct__c === true);

        this.correctAnswerValue = correctOption?.Option__c || null;

        this.hasSubmitted = this.constituentInfo.HAM_Trivia_Attempted__c ? true : false;

        this.answeredCorrectly = this.constituentInfo.HAM_Trivia_Option_Chosen__c && this.correctAnswerValue &&
                                    this.constituentInfo.HAM_Trivia_Option_Chosen__c ===  this.correctAnswerValue ? true : false;
        
        if(this.trivia && this.trivia.Trivia_Options__r?.length > 0 && this.constituentInfo.HAM_Trivia_Option_Chosen__c){
            this.selectedOption = this.trivia.Trivia_Options__r.some(opt => opt.Option__c === this.constituentInfo.HAM_Trivia_Option_Chosen__c) ?
                                    this.constituentInfo.HAM_Trivia_Option_Chosen__c : null;
        }
        this.constituentScore = this.constituentInfo.HAM_Trivia_Score__c ? this.constituentInfo.HAM_Trivia_Score__c : null;

        this.questionPoints = this.trivia && this.trivia.Points__c ? this.trivia.Points__c : null;
    }

    if(error){
        console.log('Error occurred while fetching trivia data - '+error);
    }
}

//Capture the selected option
handleOptionSelect(event){
    this.selectedOption = event.target.value;
    this.noOptionSelected = false;
}


/*After submit is clicked, we captur the selected option, and validate it. 
 We  render the tracked variable to show the appropriate message based on right/wrong answer. we update the score if it is correct answer.
 Then we call the apex class to store the user's score and option chosen for the particular question*/
handleSubmit(){

    if (!this.selectedOption){
        this.noOptionSelected = true;
        return;
    }
    
    //Call the apex class to update the constituent's score and option chosen
    this.updateTriviaInfo();

}

//Update the trivia info on constituent record and get the status
updateTriviaInfo(){
    this.isLoading = true; 

    // Calculate the NEW score before sending to Apex
    const isCorrect = this.selectedOption === this.correctAnswerValue;
    const newScore = isCorrect ? (this.constituentScore || 0) + this.questionPoints : (this.constituentScore || 0);

    updateTriviaInfoOnConstituent({ContactId:this.usercontactId, Points:newScore, SelectedOption:this.selectedOption})
    .then(result => {
        if(result && result.includes('Success')){

            //console.log('Success');
            this.hasSubmitted = true;

            //update points and answer state
            if (this.selectedOption === this.correctAnswerValue) {
                this.constituentScore += this.questionPoints;
                this.answeredCorrectly = true
            }

            refreshApex(this.wiredTriviaData);
    
        }else if(result && result.includes('Error')){
            console.log('Trivia Result Error: ',result);
        }
    })
    .catch(error => {
        console.error('Trivia Error: ',error);
    })
    .finally(() => { 
        this.isLoading = false; 
    });
}

// //On the toast, when the close icon is clicked, we remove the toast child component's state
// handleErrorClose(){
//     this.showCustomToast = false;
// }

// getter that sets the option's css classes
get triviaOptions() {
    if (!this.trivia || !this.trivia.Trivia_Options__r) return [];

        return this.trivia.Trivia_Options__r.map(opt => {
            let className = 'option-card';

            if (this.hasSubmitted) {
                if (opt.Option__c === this.correctAnswerValue) {
                    className += ' correct';
                }
                if (opt.Option__c === this.selectedOption && opt.Option__c != this.correctAnswerValue) {
                    className += ' wrong';
                }
            }else if(!this.hasSubmitted && opt.Option__c === this.selectedOption){
                className += ' selected';
            }

            return { ...opt, className };
        });
    }
}