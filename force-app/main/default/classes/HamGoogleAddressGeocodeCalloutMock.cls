/**
 * Geocoding API mocks for HamGoogleAddressVerifyControllerTest.
 *
 * ROOFTOP_WITH_UNIT mirrors a real response 
 * ROOFTOP_UNIT_DROPPED mirrors Google's actual behaviour for a nonexistent unit:
 * it silently omits the subpremise and still reports ROOFTOP / partial_match=false.
 */
public class HamGoogleAddressGeocodeCalloutMock implements HttpCalloutMock {
    public enum Scenario {
        ROOFTOP_WITH_UNIT,
        ROOFTOP_UNIT_DROPPED,
        APPROXIMATE_PARTIAL,
        ZERO_RESULTS,
        MULTIPLE_CANDIDATES
    }

    private Scenario mockScenario;

    public HamGoogleAddressGeocodeCalloutMock() {
        this.mockScenario = Scenario.ROOFTOP_WITH_UNIT;
    }

    public HamGoogleAddressGeocodeCalloutMock(Scenario requested) {
        this.mockScenario = requested;
    }

    public HttpResponse respond(HttpRequest req) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setStatusCode(200);
        res.setBody(bodyFor(this.mockScenario));
        return res;
    }

    private String bodyFor(Scenario s) {
        if (s == Scenario.ZERO_RESULTS) {
            return '{"results":[],"status":"ZERO_RESULTS"}';
        }
        if (s == Scenario.APPROXIMATE_PARTIAL) {
            return '{"results":[{'
                + '"formatted_address":"Rome, NY 13440, USA",'
                + '"partial_match":true,'
                + '"types":["postal_code"],'
                + '"place_id":"mockApproxPlaceId",'
                + '"geometry":{"location_type":"APPROXIMATE","location":{"lat":43.2128,"lng":-75.4557}},'
                + '"address_components":['
                + '{"long_name":"Rome","short_name":"Rome","types":["locality","political"]},'
                + '{"long_name":"New York","short_name":"NY","types":["administrative_area_level_1","political"]},'
                + '{"long_name":"13440","short_name":"13440","types":["postal_code"]}'
                + ']}],"status":"OK"}';
        }

        if (s == Scenario.MULTIPLE_CANDIDATES) {
            return '{"results":[' + candidate('507', 'Roberts St', '13440') + ','
                + candidate('507', 'Roberts Rd', '13441') + '],"status":"OK"}';
        }

        String subpremise = (s == Scenario.ROOFTOP_WITH_UNIT)
            ? '{"long_name":"4","short_name":"4","types":["subpremise"]},'
            : '';
        String types = (s == Scenario.ROOFTOP_WITH_UNIT)
            ? '["street_address","subpremise"]'
            : '["premise","street_address"]';

        return '{"results":[{'
            + '"formatted_address":"507 Roberts St, Rome, NY 13440, USA",'
            + '"partial_match":false,'
            + '"types":' + types + ','
            + '"place_id":"mockRooftopPlaceId",'
            + '"geometry":{"location_type":"ROOFTOP","location":{"lat":43.20718,"lng":-75.45632}},'
            + '"address_components":['
            + subpremise
            + '{"long_name":"507","short_name":"507","types":["street_number"]},'
            + '{"long_name":"Roberts Street","short_name":"Roberts St","types":["route"]},'
            + '{"long_name":"Rome","short_name":"Rome","types":["locality","political"]},'
            + '{"long_name":"Oneida County","short_name":"Oneida County","types":["administrative_area_level_2","political"]},'
            + '{"long_name":"New York","short_name":"NY","types":["administrative_area_level_1","political"]},'
            + '{"long_name":"United States","short_name":"US","types":["country","political"]},'
            + '{"long_name":"13440","short_name":"13440","types":["postal_code"]},'
            + '{"long_name":"5273","short_name":"5273","types":["postal_code_suffix"]}'
            + ']}],"status":"OK"}';
    }

    /** One ambiguous street-level candidate. */
    private String candidate(String num, String street, String zip) {
        return '{'
            + '"formatted_address":"' + num + ' ' + street + ', Rome, NY ' + zip + ', USA",'
            + '"partial_match":false,'
            + '"types":["premise","street_address"],'
            + '"place_id":"mock' + zip + '",'
            + '"geometry":{"location_type":"ROOFTOP","location":{"lat":43.2072,"lng":-75.4563}},'
            + '"address_components":['
            + '{"long_name":"' + num + '","short_name":"' + num + '","types":["street_number"]},'
            + '{"long_name":"' + street + '","short_name":"' + street + '","types":["route"]},'
            + '{"long_name":"Rome","short_name":"Rome","types":["locality","political"]},'
            + '{"long_name":"Oneida County","short_name":"Oneida County","types":["administrative_area_level_2","political"]},'
            + '{"long_name":"New York","short_name":"NY","types":["administrative_area_level_1","political"]},'
            + '{"long_name":"United States","short_name":"US","types":["country","political"]},'
            + '{"long_name":"' + zip + '","short_name":"' + zip + '","types":["postal_code"]}'
            + ']}';
    }
}