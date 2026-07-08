public with sharing class HamGivingPagePaymentTabController {

    @TestVisible
    private static final String GIFT_TRANSACTION_TYPE = 'Gift';
    @TestVisible
    private static final String PLEDGE_PAYMENT_TRANSACTION_TYPE = 'Pledge Payment';
    @TestVisible
    private static final String OUTRIGHT_OPPORTUNITY_TYPE = 'Outright';
    @TestVisible
    private static final String RECURRING_PAYMENT = 'monthly';
    @TestVisible
    private static final String IN_MEMORY_OF_TYPE = 'In Memory Of';
    @TestVisible
    private static final String IN_HONOR_OF_TYPE = 'In Honor Of';
    @TestVisible
    private static final String NEW_STATUS = 'New';
    @TestVisible
    private static final String CAMPAIGN_EXTERNAL_ID = 'WB';
    @TestVisible
    private static final String STRIPE_TENDER_TYPE = 'Stripe';
    @TestVisible
    private static final String PLEDGE_GIFT_PATH = 'pledge';
    

    @AuraEnabled(cacheable=true)
    public static List<Stripe_Credentials__mdt> getStripeCredentials() {
        return [
            SELECT Id, DeveloperName, Active__c, Publishable_Key__c, Secret_Key__c
            FROM Stripe_Credentials__mdt
            WHERE Active__c = TRUE
            LIMIT 1
        ];
    }

    @AuraEnabled
    public static PaymentLink createPaymentLink(Integer amountCents, String donationTo) {
        PaymentLink link = new PaymentLink();

        List<Stripe_Credentials__mdt> credentials = getStripeCredentials();
        if (credentials.isEmpty()) {
            return link;
        } else {
            String endPoint = 'callout:StripeAPI' + '/v1/payment_links';
            String body = 'line_items[0][price_data][currency]=usd';
            body += '&line_items[0][price_data][unit_amount]=' + amountCents;
            body += '&line_items[0][price_data][product_data][name]=' + donationTo + '';
            body += '&line_items[0][quantity]=1';
            body += '&payment_method_types[0]=card';
            // body += '&payment_method_types[1]=us_bank_account';
            body += '&payment_method_types[1]=link';
            //body += '&payment_method_types[2]=paypal';
            system.debug('Key----->'+credentials.get(0).Secret_Key__c);
            Http http = new Http();
            HttpRequest request = new HttpRequest();
            request.setEndpoint(endPoint);
            request.setMethod('POST');
            request.setBody(body);
            request.setHeader('Authorization', 'Bearer ' + credentials.get(0).Secret_Key__c);
            request.setHeader('Content-Type', 'application/x-www-form-urlencoded');

            try {
                HttpResponse response = http.send(request);
                Map<String, Object> responseObjMap = (Map<String,Object>) JSON.deserializeUntyped(response.getBody());
                System.debug('Response: >> '+ response.getBody());
                System.debug(JSON.serializePretty(responseObjMap));
                String paymentURL = String.valueOf(responseObjMap.get('url'));
                String paymentLinkId = String.valueOf(responseObjMap.get('id'));
                System.debug('paymentURL: >> '+ paymentURL);
                System.debug('paymentLinkId: >> '+ paymentLinkId);
                if (responseObjMap.containsKey('error')) {
                    System.debug('Stripe error: ' + responseObjMap.get('error'));
                    return link;
                }
                system.debug('LinkId---->'+String.valueOf(responseObjMap.get('id')));
                system.debug('LinkUrl---->'+String.valueOf(responseObjMap.get('url')));
                link.id = String.valueOf(responseObjMap.get('id'));
                link.url = String.valueOf(responseObjMap.get('url'));
            } catch (Exception exp) {
                System.debug('EXCEPTION TYPE: ' + exp.getTypeName());
                System.debug('EXCEPTION MSG: ' + exp.getMessage());
                System.debug('STACK: ' + exp.getStackTraceString());
            }
        }

        return link;
    }

    @AuraEnabled(cacheable=false)
    public static List<stripeGC__Stripe_Event__c> getStripeSuccessfulPaymentEvent(String paymentLinkId) {
        return new StripeEventSelector().getEvent(paymentLinkId);    
    }

    @AuraEnabled
    public static Person getPersonDetails(String userId, String contactId) {
        Person person = new Person();
        if (String.isNotBlank(contactId)) {
            List<Contact> contacts = [
                SELECT Id, Name, Email
                FROM Contact
                WHERE Id = :contactId
            ];
            if (!contacts.isEmpty()) {
                person.email = contacts.get(0).Email;
                person.fullName = contacts.get(0).Name;
                return person;
            }
        }
        if (String.isNotBlank(userId)) {
            List<User> users = [
                SELECT Id, Name, Email
                FROM User
                WHERE Id = :userId
            ];
            if (!users.isEmpty()) {
                person.email = users.get(0).Email;
                person.fullName = users.get(0).Name;
                return person;
            }
        }
        return person;
    }

    @AuraEnabled
    public static void savePaymentTransaction(Object formDataJSON, String status) {
        FormData formData = (FormData) JSON.deserialize(
            JSON.serialize(formDataJSON), FormData.class
        );

        Payment_Transaction__c paymentTransaction = new Payment_Transaction__c();
        paymentTransaction.Constituent__c = formData.contactId;
        paymentTransaction.Payment_Method__c = formData.paymentMethodUI;
        paymentTransaction.Payment_Method_Stripe__c = formData.paymentMethod;
        paymentTransaction.Total_Amount__c = formData.amount;
        paymentTransaction.Transaction_Date_Time__c = Datetime.now();
        paymentTransaction.Transaction_Status__c = status;
        paymentTransaction.Person_Name__c = formData.personName;
        paymentTransaction.Person_Email__c = formData.personEmail;

        insert paymentTransaction;

        if (formData.selectedDesignations != null) {
            List<Payment_Transaction_Designation_Item__c> designationItems = new List<Payment_Transaction_Designation_Item__c>();
            for (Designation designation : formData.selectedDesignations) {
                designationItems.add(new Payment_Transaction_Designation_Item__c(
                    Designation__c = designation.id,
                    Payment_Transaction__c = paymentTransaction.Id,
                    Amount__c = designation.amt,
                    Name = designation.name
                ));
            }
            if (!designationItems.isEmpty()) {
                insert designationItems;
            }
        }
    }

    @AuraEnabled
    public static void saveReviewTransactionV2(Object formDataJSON) {
        FormData formData = (FormData) JSON.deserialize(
            JSON.serialize(formDataJSON), FormData.class
        );

        Boolean isPledgePath = formData.giftPath == PLEDGE_GIFT_PATH;

        Id rtId = Schema.SObjectType.ucinn_ascendv2__Review_Transaction_v2__c.getRecordTypeInfosByDeveloperName()
            .get('MGFT')
            .getRecordTypeId();

        // Look up Contact details once — shared across all RTV2 records
        String contactFirstName;
        String contactLastName;
        List<Contact> contacts = [
            SELECT FirstName, LastName FROM Contact WHERE Id = :formData.contactId
        ];
        if (!contacts.isEmpty()) {
            contactFirstName = contacts.get(0).FirstName;
            contactLastName  = contacts.get(0).LastName;
        }

        if (isPledgePath) {
            // ── PLEDGE PATH ──────────────────────────────────────────────────────────
            // One RTV2 per pledge, each linked to its Opportunity (the pledge record).
            List<ucinn_ascendv2__Review_Transaction_v2__c> reviewTransactions =
                new List<ucinn_ascendv2__Review_Transaction_v2__c>();

            if (formData.selectedDesignations != null) {
                Integer pledgeIndex = 0;
                for (Designation pledge : formData.selectedDesignations) {

                    ucinn_ascendv2__Review_Transaction_v2__c rt = buildBaseReviewTransaction(
                        formData, rtId, contactFirstName, contactLastName
                    );

                    rt.ucinn_ascendv2__Transaction_Type__c = PLEDGE_PAYMENT_TRANSACTION_TYPE;

                    // Link to the pledge Opportunity
                    if (String.isNotBlank(pledge.pledgeId)) {
                        rt.ucinn_ascendv2__Opportunity__c = pledge.pledgeId;
                    }

                    // Single designation per RTV2
                    rt.ucinn_ascendv2__Designation_1__c      = pledge.id;
                    rt.ucinn_ascendv2__Payment_Amount_1_1__c = pledge.amt;
                    rt.ucinn_ascendv2__Payment_Date_1_1__c   = rt.ucinn_ascendv2__Transaction_Date__c;

                    // Make the external ID unique per pledge within the transaction
                    rt.ucinn_ascendv2__External_System_ID__c = 'MGFT-' + formData.transactionId + '-' + pledgeIndex;
                    rt.Name = rt.ucinn_ascendv2__External_System_ID__c;

                    reviewTransactions.add(rt);
                    pledgeIndex++;
                }
            }

            if (!reviewTransactions.isEmpty()) {
                insert reviewTransactions;
            }

        } else {
            // ── GIFT PATH ────────────────────────────────────────────────────────────
            // Single RTV2 with up to 5 designations (existing behaviour).
            ucinn_ascendv2__Review_Transaction_v2__c reviewTransaction = buildBaseReviewTransaction(
                formData, rtId, contactFirstName, contactLastName
            );

            reviewTransaction.ucinn_ascendv2__Transaction_Type__c = GIFT_TRANSACTION_TYPE;

            // Tribute handling (gift path only)
            if (String.isNotBlank(formData.inMemoryOf)) {
                FullName inMemoryOfName = parseName(formData.inMemoryOf);
                reviewTransaction.ucinn_ascendv2__Tribute_Type_1__c = IN_MEMORY_OF_TYPE;
                reviewTransaction.ucinn_ascendv2__In_Memory_Honor_First_Name_1__c = inMemoryOfName.firstName;
                reviewTransaction.ucinn_ascendv2__In_Memory_Honor_Last_Name_1__c = inMemoryOfName.lastName;
            }
            if (String.isNotBlank(formData.inHonorOf)) {
                FullName inHonorOfName = parseName(formData.inHonorOf);
                reviewTransaction.ucinn_ascendv2__Tribute_Type_1__c = IN_HONOR_OF_TYPE;
                reviewTransaction.ucinn_ascendv2__In_Memory_Honor_First_Name_1__c = inHonorOfName.firstName;
                reviewTransaction.ucinn_ascendv2__In_Memory_Honor_Last_Name_1__c = inHonorOfName.lastName;
            }

            // Multi-designation mapping (up to 5)
            if (formData.selectedDesignations != null) {
                Integer numberOfDesignations = formData.selectedDesignations.size();
                if(numberOfDesignations > 1){
                    reviewTransaction.HAM_Notes__c = 'SPLIT PAYMENT';
                }

                Decimal totalAmount = 0;
                for (Designation d : formData.selectedDesignations) {
                    if (d.amt != null) {
                        totalAmount += d.amt;
                    }
                }
                reviewTransaction.ucinn_ascendv2__Total_Transaction_Amount__c = totalAmount;

                switch on numberOfDesignations {
                    when 1 {
                        reviewTransaction.ucinn_ascendv2__Designation_1__c = formData.selectedDesignations[0].id;
                        reviewTransaction.ucinn_ascendv2__Payment_Amount_1_1__c = formData.selectedDesignations[0].amt;
                        reviewTransaction.ucinn_ascendv2__Payment_Date_1_1__c = reviewTransaction.ucinn_ascendv2__Transaction_Date__c;
                    }
                    when 2 {
                        reviewTransaction.ucinn_ascendv2__Designation_1__c = formData.selectedDesignations[0].id;
                        reviewTransaction.ucinn_ascendv2__Designation_2__c = formData.selectedDesignations[1].id;
                        reviewTransaction.ucinn_ascendv2__Payment_Amount_1_1__c = formData.selectedDesignations[0].amt;
                        reviewTransaction.ucinn_ascendv2__Payment_Amount_2_1__c = formData.selectedDesignations[1].amt;
                        reviewTransaction.ucinn_ascendv2__Payment_Date_1_1__c = reviewTransaction.ucinn_ascendv2__Transaction_Date__c;
                        reviewTransaction.ucinn_ascendv2__Payment_Date_2_1__c = reviewTransaction.ucinn_ascendv2__Transaction_Date__c;
                    }
                    when 3 {
                        reviewTransaction.ucinn_ascendv2__Designation_1__c = formData.selectedDesignations[0].id;
                        reviewTransaction.ucinn_ascendv2__Designation_2__c = formData.selectedDesignations[1].id;
                        reviewTransaction.ucinn_ascendv2__Designation_3__c = formData.selectedDesignations[2].id;
                        reviewTransaction.ucinn_ascendv2__Payment_Amount_1_1__c = formData.selectedDesignations[0].amt;
                        reviewTransaction.ucinn_ascendv2__Payment_Amount_2_1__c = formData.selectedDesignations[1].amt;
                        reviewTransaction.ucinn_ascendv2__Payment_Amount_3_1__c = formData.selectedDesignations[2].amt;
                        reviewTransaction.ucinn_ascendv2__Payment_Date_1_1__c = reviewTransaction.ucinn_ascendv2__Transaction_Date__c;
                        reviewTransaction.ucinn_ascendv2__Payment_Date_2_1__c = reviewTransaction.ucinn_ascendv2__Transaction_Date__c;
                        reviewTransaction.ucinn_ascendv2__Payment_Date_3_1__c = reviewTransaction.ucinn_ascendv2__Transaction_Date__c;
                    }
                    when 4 {
                        reviewTransaction.ucinn_ascendv2__Designation_1__c = formData.selectedDesignations[0].id;
                        reviewTransaction.ucinn_ascendv2__Designation_2__c = formData.selectedDesignations[1].id;
                        reviewTransaction.ucinn_ascendv2__Designation_3__c = formData.selectedDesignations[2].id;
                        reviewTransaction.ucinn_ascendv2__Designation_4__c = formData.selectedDesignations[3].id;
                        reviewTransaction.ucinn_ascendv2__Payment_Amount_1_1__c = formData.selectedDesignations[0].amt;
                        reviewTransaction.ucinn_ascendv2__Payment_Amount_2_1__c = formData.selectedDesignations[1].amt;
                        reviewTransaction.ucinn_ascendv2__Payment_Amount_3_1__c = formData.selectedDesignations[2].amt;
                        reviewTransaction.ucinn_ascendv2__Payment_Amount_4_1__c = formData.selectedDesignations[3].amt;
                        reviewTransaction.ucinn_ascendv2__Payment_Date_1_1__c = reviewTransaction.ucinn_ascendv2__Transaction_Date__c;
                        reviewTransaction.ucinn_ascendv2__Payment_Date_2_1__c = reviewTransaction.ucinn_ascendv2__Transaction_Date__c;
                        reviewTransaction.ucinn_ascendv2__Payment_Date_3_1__c = reviewTransaction.ucinn_ascendv2__Transaction_Date__c;
                        reviewTransaction.ucinn_ascendv2__Payment_Date_4_1__c = reviewTransaction.ucinn_ascendv2__Transaction_Date__c;
                    }
                    when 5 {
                        reviewTransaction.ucinn_ascendv2__Designation_1__c = formData.selectedDesignations[0].id;
                        reviewTransaction.ucinn_ascendv2__Designation_2__c = formData.selectedDesignations[1].id;
                        reviewTransaction.ucinn_ascendv2__Designation_3__c = formData.selectedDesignations[2].id;
                        reviewTransaction.ucinn_ascendv2__Designation_4__c = formData.selectedDesignations[3].id;
                        reviewTransaction.ucinn_ascendv2__Designation_5__c = formData.selectedDesignations[4].id;
                        reviewTransaction.ucinn_ascendv2__Payment_Amount_1_1__c = formData.selectedDesignations[0].amt;
                        reviewTransaction.ucinn_ascendv2__Payment_Amount_2_1__c = formData.selectedDesignations[1].amt;
                        reviewTransaction.ucinn_ascendv2__Payment_Amount_3_1__c = formData.selectedDesignations[2].amt;
                        reviewTransaction.ucinn_ascendv2__Payment_Amount_4_1__c = formData.selectedDesignations[3].amt;
                        reviewTransaction.ucinn_ascendv2__Payment_Amount_5_1__c = formData.selectedDesignations[4].amt;
                        reviewTransaction.ucinn_ascendv2__Payment_Date_1_1__c = reviewTransaction.ucinn_ascendv2__Transaction_Date__c;
                        reviewTransaction.ucinn_ascendv2__Payment_Date_2_1__c = reviewTransaction.ucinn_ascendv2__Transaction_Date__c;
                        reviewTransaction.ucinn_ascendv2__Payment_Date_3_1__c = reviewTransaction.ucinn_ascendv2__Transaction_Date__c;
                        reviewTransaction.ucinn_ascendv2__Payment_Date_4_1__c = reviewTransaction.ucinn_ascendv2__Transaction_Date__c;
                        reviewTransaction.ucinn_ascendv2__Payment_Date_5_1__c = reviewTransaction.ucinn_ascendv2__Transaction_Date__c;
                    }
                }
            }

            reviewTransaction.ucinn_ascendv2__External_System_ID__c = 'MGFT-' + formData.transactionId;
            reviewTransaction.Name = reviewTransaction.ucinn_ascendv2__External_System_ID__c;

            insert reviewTransaction;
        }
    }

    /**
     * Builds a Review Transaction with all fields that are common to both the
     * gift path and the pledge path.  Caller is responsible for setting
     * transaction-type-specific fields afterwards.
     */
    private static ucinn_ascendv2__Review_Transaction_v2__c buildBaseReviewTransaction(
        FormData formData,
        Id rtId,
        String contactFirstName,
        String contactLastName
    ) {
        ucinn_ascendv2__Review_Transaction_v2__c rt = new ucinn_ascendv2__Review_Transaction_v2__c();
        rt.RecordTypeId = rtId;
        rt.ucinn_ascendv2__Opportunity_Type__c  = OUTRIGHT_OPPORTUNITY_TYPE;
        rt.HAM_Is_Recurring_Gift__c = formData.paymentType == RECURRING_PAYMENT;
        rt.ucinn_ascendv2__Status__c = NEW_STATUS;
        rt.ucinn_ascendv2__Campaign_External_ID__c = CAMPAIGN_EXTERNAL_ID;
        rt.ucinn_ascendv2__Email_1__c = formData.personEmail;
        rt.ucinn_ascendv2__Transaction_Date__c = formData.transactionDate?.date();
        rt.HAM_Data_Source__c = 'Portal - MakeAGift';
        rt.ucinn_ascendv2__Tender_Type_1__c = STRIPE_TENDER_TYPE;
        rt.ucinn_ascendv2__Tender_Type_2__c = STRIPE_TENDER_TYPE;
        rt.ucinn_ascendv2__Country_1__c = formData.personCountry;
        rt.ucinn_ascendv2__Postal_Code_1__c = formData.personZipCode;

        if (String.isNotBlank(contactFirstName)) {
            rt.ucinn_ascendv2__First_Name__c = contactFirstName;
            rt.ucinn_ascendv2__Last_Name__c  = contactLastName;
            rt.ucinn_ascendv2__Contact__c    = formData.contactId;
        }

        return rt;
    }

    private static FullName parseName(String name) {
        FullName fullName = new FullName();
        if (String.isNotBlank(name)) {
            List<String> names = name.split('\\s+');
            if (names.size() == 1) {
                fullName.firstName = names.get(0);
            }
            if (names.size() > 1) {
                fullName.firstName = names.get(0);
                names.remove(0);
                fullName.lastName = String.join(names, ' ');
            }
        }
        return fullName;
    }

    @TestVisible
    private class FormData {
        public String paymentType;
        public String paymentMethod;
        public String paymentMethodUI;
        public Decimal amount;
        public Decimal deltaAmount;
        public String personName;
        public String personEmail;
        public String inMemoryOf;
        public String inHonorOf;
        public String giftPath;

        public String contactId;

        public Datetime transactionDate;
        public String transactionId;

        public String personAddressLineOne;
        public String personAddressLineTwo;

        public String personCountry;
        public String personZipCode;

        public List<Designation> selectedDesignations;
    }

    @TestVisible
    private class Designation {
        public String name;
        public String id;
        public Decimal amt;
        public String pledgeId;   // Opportunity Id of the pledge (pledge path only)
    }

    @TestVisible
    private class FullName {
        public String firstName;
        public String lastName;
    }

    @TestVisible
    private class Person {
        @AuraEnabled
        public String fullName;
        @AuraEnabled
        public String email;
    }

    public class PaymentLink {
        @AuraEnabled
        public String url;

        @AuraEnabled
        public String id;
    }

    private without sharing class StripeEventSelector {
        public List<stripeGC__Stripe_Event__c> getEvent(String paymentLinkId) {
            return [
                SELECT Id, stripeGC__Event_Name__c, Email__c, Total_Amount_Cents__c, 
                    stripeGC__Request_Body__c, stripeGC__Stripe_Event_Id__c, 
                    CreatedDate, Payment_Processed_UI__c
                FROM stripeGC__Stripe_Event__c
                WHERE stripeGC__Event_Name__c = 'checkout.session.completed'
                AND Payment_Link_Id__c = :paymentLinkId
                LIMIT 1
            ];
        }
    }
}