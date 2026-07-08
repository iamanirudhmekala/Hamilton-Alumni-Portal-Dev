import { api, LightningElement } from "lwc";
 const MESSAGE_CONTENT_CLASS = "embedded-messaging-message-content";
 const ENDUSER = "EndUser";
 const AGENT = "Agent";
 const CHATBOT = "Chatbot";
 const PARTICIPANT_TYPES = [ENDUSER, AGENT, CHATBOT];

 export default class CustomTextMessageBubble extends LightningElement {
   /**
    * Deployment configuration data.
    * @type {Object}
    */
   @api configuration;

   /**
    * Conversation entry data.
    * @type {Object}
    */
   @api conversationEntry;

   /**
    * Returns the sender of this conversation entry.
    * @returns {string}
    */
   get sender() {
     return this.conversationEntry.sender && this.conversationEntry.sender.role;
   }

   /**
    * Returns the text content of the conversation entry.
    * @returns {string}
    */
   get textContent() {
     try {
       const entryPayload = JSON.parse(this.conversationEntry.entryPayload);
       if (
         entryPayload.abstractMessage &&
         entryPayload.abstractMessage.staticContent
       ) {
         const text = entryPayload.abstractMessage.staticContent.text;
         return text.replace(
           // innerText or textContent
           /(?:(?:ht|f)tp(?:s?)\:\/\/|~\/|\/)?(?:\w+:\w+@)?((?:(?:[-\w\d{1-3}]+\.)+(?:com|org|net|gov|mil|biz|info|mobi|name|aero|jobs|edu|co\.uk|ac\.uk|it|fr|tv|museum|asia|local|travel|[a-z]{2}))|((\b25[0-5]\b|\b[2][0-4][0-9]\b|\b[0-1]?[0-9]?[0-9]\b)(\.(\b25[0-5]\b|\b[2][0-4][0-9]\b|\b[0-1]?[0-9]?[0-9]\b)){3}))(?::[\d]{1,5})?(?:(?:(?:\/(?:[-\w~!$+|.,=]|%[a-f\d]{2})+)+|\/)+|\?|#)?(?:(?:\?(?:[-\w~!$+|.,*:]|%[a-f\d{2}])+=?(?:[-\w~!$+|.,*:=]|%[a-f\d]{2})*)(?:&(?:[-\w~!$+|.,*:]|%[a-f\d{2}])+=?(?:[-\w~!$+|.,*:=]|%[a-f\d]{2})*)*)*(?:#(?:[-\w~!$ |\/.,*:;=]|%[a-f\d]{2})*)?/g,
           function (imgUrl) {
             // Only switch out to specific shortened urls if the agent is the user.
             if (this.sender === AGENT) {
               // If the url is a specific link, then return a custom shortened link.
               if (
                 imgUrl === "https://www.test.com/specificLink" ||
                 imgUrl === "https://www.test.com/anotherSpecificLink"
               ) {
                 return `<a target="_blank" href="${imgUrl}">View Link</a>`;
               }
               // Otherwise just shorten to a generic link "View Article".
               return `<a target="_blank" href="${imgUrl}">View Article</a>`;
             }
             return imgUrl;
           }.bind(this),
         );
       }
       return "";
     } catch (e) {
       console.error(e);
     }
   }

   /**
    * Returns the class name of the message bubble.
    * @returns {string}
    */
   get generateMessageBubbleClassname() {
     if (this.isSupportedSender()) {
       return `${MESSAGE_CONTENT_CLASS} ${this.sender}`;
     } else {
       throw new Error(`Unsupported participant type passed in: ${this.sender}`);
     }
   }

   /**
    * True if the sender is a support participant type.
    * @returns {Boolean}
    */
   isSupportedSender() {
     return PARTICIPANT_TYPES.some(
       (participantType) => this.sender === participantType,
     );
   }
 }