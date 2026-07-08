@isTest
private class StripeEventProcessingHelperTest {

    @isTest static void testExecute_withNullPayload() {
        StripeEventProcessingHelper.Requests req = new StripeEventProcessingHelper.Requests();
        req.eventPayload = null;
        List<StripeEventProcessingHelper.Results> res = StripeEventProcessingHelper.execute(new List<StripeEventProcessingHelper.Requests>{req});

        System.assertNotEquals(null, res, 'Results list should not be null');
        System.assertEquals(1, res.size(), 'Should return one result');
        System.assertEquals(null, res[0].email, 'Email should be null for null payload');
        System.assertEquals(null, res[0].amountTotalInCents, 'Amount should be null for null payload');
        System.assertEquals(null, res[0].paymentLinkId, 'Payment Link Id should be null for null payload');
    }

    @isTest static void testExecute_withValidStripePayload_but_untypedParsing() {
        // Build a payload that mirrors Stripe's payment_link or checkout.session.completed structure
        Map<String, Object> customerDetails = new Map<String, Object>{ 'email' => 'payer@example.com' };
        Map<String, Object> obj = new Map<String, Object>{ 'amount_total' => 2500, 'customer_details' => customerDetails, 'payment_link' => 'plink_12345' };
        Map<String, Object> data = new Map<String, Object>{ 'object' => obj };
        Map<String, Object> envelope = new Map<String, Object>{ 'data' => data };

        String payload = JSON.serialize(envelope);

        StripeEventProcessingHelper.Requests req = new StripeEventProcessingHelper.Requests();
        req.eventPayload = payload;

        // Call the invocable method - it should not throw even if the implementation uses untyped maps
        List<StripeEventProcessingHelper.Results> res = StripeEventProcessingHelper.execute(new List<StripeEventProcessingHelper.Requests>{req});

        System.assertEquals(1, res.size(), 'One result expected');
        // Implementation casts the map to the inner class which does not convert automatically,
        // so the helper swallows exceptions — we assert the code executed and returned a Result object.
        System.assertNotEquals(null, res[0], 'Result entry must exist');
        System.assertEquals('payer@example.com', res.get(0).email, 'Email is incorrect');
        System.assertEquals(2500, res.get(0).amountTotalInCents, 'Amount is incorrect');
        System.assertEquals('plink_12345', res.get(0).paymentLinkId, 'Payment Link Id is incorrect');
    }
}