public class HamGoogleAddressCalloutMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
        String json = '{'
            + '"result":{'
            + '"verdict":{"inputGranularity":"PREMISE","validationGranularity":"PREMISE","addressComplete":true,"hasUnconfirmedComponents":false},'
            + '"address":{'
            + '"formattedAddress":"198 College Hill Rd, Clinton, NY 13323, USA",'
            + '"postalAddress":{"regionCode":"US","postalCode":"13323","administrativeArea":"NY","locality":"Clinton","addressLines":["198 College Hill Rd"]},'
            + '"addressComponents":[]'
            + '},'
            + '"geocode":{"location":{"latitude":43.0481,"longitude":-75.3902},"placeId":"mock-place-id"},'
            + '"metadata":{"business":false,"poBox":false,"residential":true},'
            + '"uspsData":{'
            + '"standardizedAddress":{"firstAddressLine":"198 COLLEGE HILL RD","city":"CLINTON","state":"NY","zipCode":"13323","zipCodeExtension":"1200"},'
            + '"dpvConfirmation":"Y","dpvVacant":"N","dpvCmra":"N","carrierRoute":"R001"'
            + '}'
            + '},'
            + '"responseId":"mock-response-id"'
            + '}';

        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody(json);
        res.setStatusCode(200);
        return res;
    }
}