@isTest
public class HamGivingPagePaymentTabControllerMock {

    // Basic success mock returning a JSON body containing a 'url' field
    public class SuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            String body = '{"id":"pl_1","object":"payment_link","url":"https://checkout.stripe.com/pay/cs_test_123"}';
            res.setBody(body);
            return res;
        }
    }

    // Mock that simulates an error response from Stripe
    public class ErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(400);
            String body = '{"error":{"message":"Invalid request","type":"invalid_request_error"}}';
            res.setBody(body);
            return res;
        }
    }
}