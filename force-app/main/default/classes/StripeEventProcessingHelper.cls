public with sharing class StripeEventProcessingHelper {

    @InvocableMethod
    public static List<Results> execute (List<Requests> requestList) {
        List<Results> results = new List<Results>();
        for (Requests request : requestList) {
            Results result = new Results();
            if (request.eventPayload != null) {
                try {
                    Map<String, Object> untypedStripeResponse = (Map<String, Object>) JSON.deserializeUntyped(
                        request.eventPayload
                    );
                    Map<String, Object> data = (Map<String, Object>) untypedStripeResponse.get('data');
                    if (data != null && data.get('object') != null) {
                        StripeObject stripeObjectData = (StripeObject) JSON.deserialize(JSON.serialize(data.get('object')), StripeObject.class);
                        result.amountTotalInCents = stripeObjectData?.amount_total;
                        result.email = stripeObjectData?.customer_details?.email;
                        result.paymentLinkId = stripeObjectData?.payment_link;
                    }
                } catch (Exception exp) {
                    System.debug('Exception during parsing Stripe payload: ' + exp.getMessage());
                }
            }
            
            results.add(result);
        }
        return results;
    }

    public class Requests {
        @InvocableVariable(label='Event Payload' required=true)
        public String eventPayload;
    }

    public class Results {
        @InvocableVariable(label='Email' description='email')
        public String email;

        @InvocableVariable(label='Amount Total' description='amount total')
        public Integer amountTotalInCents;

        @InvocableVariable(label='Payment Link Id' description='payment link Id')
        public String paymentLinkId;
    }

    private class StripeObject {
        public String id;
        public Integer amount_total;
        public String payment_link;
        public CustomerDetails customer_details;
    }

    private class CustomerDetails {
        public String email;
    }
}