/**
 * Address verification backed by the Google Address Validation API.
 *
 * PREFERRED provider: adds USPS DPV deliverability + vacancy data and explicitly
 * reports unconfirmed/inferred/replaced components.
 *
 * NOT ACTIVE YET. The API is enabled on Google Cloud project 843892269827, but the
 * API key is not allowlisted for it, so calls fail with 403 API_KEY_SERVICE_BLOCKED.
 * Once the key is allowlisted, switch HamGoogleAddressProviderFactory to
 * ProviderType.ADDRESS_VALIDATION.
 */
public with sharing class HamGoogleAddressCallout implements HamGoogleAddressProvider {
    public static final String NAME_CRED = 'callout:Google_Address_Validation';

    public String getSourceLabel() {
        return 'Google Address Validation API';
    }

    public List<HamGoogleAddressResult> verify(HamGoogleAddressRequest addr) {
        String endpoint = NAME_CRED + '?key=' + getApiKey();
        String body = JSON.serialize(buildRequestBody(addr));

        HttpRequest req = new HttpRequest();
        // The '/v1:validateAddress' path is baked into the named credential URL because
        // Salesforce URL-encodes the colon when it appends a path to a named credential,
        // which Google's frontend rejects with a 400. Same convention as Geocoding_API_Named_Cred.
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(body);

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() != 200) {
            throw new HamGoogleAddressException(
                'Address Validation API returned status ' + res.getStatusCode() + ': ' + res.getBody()
            );
        }

        HamGoogleAddressResponse parsed = HamGoogleAddressResponse.parse(res.getBody());
        HamGoogleAddressResult mapped = mapResult(parsed, addr);
        // Audit trail; setAuditTrail redacts the API key from the endpoint.
        mapped.setAuditTrail(endpoint + ' | body=' + body, res.getBody());
        if (parsed?.result?.verdict != null) {
            mapped.setVerificationResponse('granularity=' + parsed.result.verdict.validationGranularity
                + ' | complete=' + parsed.result.verdict.addressComplete
                + ' | unconfirmed=' + parsed.result.verdict.hasUnconfirmedComponents
                + (parsed.result.uspsData != null ? ' | dpv=' + parsed.result.uspsData.dpvConfirmation : ''));
        }

        // The Address Validation API returns a single verdict rather than alternatives.
        return new List<HamGoogleAddressResult>{ mapped };
    }

    private Map<String, Object> buildRequestBody(HamGoogleAddressRequest addr) {
        List<String> addressLines = new List<String>();
        if (String.isNotBlank(addr.addressLine1)) {
            addressLines.add(addr.addressLine1);
        }
        if (String.isNotBlank(addr.addressLine2)) {
            addressLines.add(addr.addressLine2);
        }

        Map<String, Object> address = new Map<String, Object>();
        address.put('addressLines', addressLines);
        if (String.isNotBlank(addr.city)) {
            address.put('locality', addr.city);
        }
        if (String.isNotBlank(addr.state)) {
            address.put('administrativeArea', addr.state);
        }
        if (String.isNotBlank(addr.postalCode)) {
            address.put('postalCode', addr.postalCode);
        }
        if (String.isNotBlank(addr.country)) {
            address.put('regionCode', addr.country);
        }

        return new Map<String, Object>{ 'address' => address };
    }

    @TestVisible
    private HamGoogleAddressResult mapResult(HamGoogleAddressResponse apiResp, HamGoogleAddressRequest req) {
        HamGoogleAddressResult result = new HamGoogleAddressResult();
        HamGoogleAddressResponse.Result r = apiResp?.result;
        if (r == null) {
            result.verificationStatus = 'Unverified';
            return result;
        }

        if (r.address?.postalAddress != null) {
            List<String> lines = r.address.postalAddress.addressLines;
            result.addressLine1 = (lines != null && lines.size() > 0) ? lines[0] : null;
            result.addressLine2 = (lines != null && lines.size() > 1) ? lines[1] : null;
            result.city         = r.address.postalAddress.locality;
            result.state        = r.address.postalAddress.administrativeArea;
            result.postalCode   = r.address.postalAddress.postalCode;
            // regionCode is the ISO code, not a display name, so it must not overwrite
            // Country__c (e.g. "United States"); it populates Country_ISO_Code__c instead.
            result.countryIsoCode = r.address.postalAddress.regionCode;
        }

        if (r.uspsData != null) {
            result.dpvMatchCode = r.uspsData.dpvConfirmation;
            result.dpvVacant    = r.uspsData.dpvVacant;
        }

        if (r.geocode?.location != null) {
            if (r.geocode.location.latitude != null) {
                result.latitude = Decimal.valueOf(r.geocode.location.latitude).setScale(4).doubleValue();
            }
            if (r.geocode.location.longitude != null) {
                result.longitude = Decimal.valueOf(r.geocode.location.longitude).setScale(4).doubleValue();
            }
        }

        if (r.verdict != null) {
            result.addressPrecision = r.verdict.validationGranularity;
            // Address Validation tells us outright when it could not confirm something,
            // so unlike Geocoding we do not have to infer it from a missing component.
            Boolean unconfirmed = r.verdict.hasUnconfirmedComponents == true;
            result.unitConfirmed = !unconfirmed;

            if (r.verdict.addressComplete == true) {
                result.verificationStatus = unconfirmed ? 'Partial' : 'Verified';
            } else {
                result.verificationStatus = 'Unverified';
            }
            if (unconfirmed) {
                result.statusNote = 'Google reported unconfirmed address components.';
            }
        }

        // Preserve a staff-entered unit that the API dropped entirely.
        if (req != null && req.hasUnit() && String.isBlank(result.addressLine2)) {
            result.addressLine2 = req.addressLine2;
            result.unitConfirmed = false;
            result.statusNote = 'Google could not confirm unit "' + req.addressLine2
                + '". The unit was kept as entered and NOT verified.';
            if (result.verificationStatus == 'Verified') {
                result.verificationStatus = 'Partial';
            }
        }

        return result;
    }

    private static String getApiKey() {
        return Google_Map_API_Key__c.getOrgDefaults()?.Key__c;
    }

    public class HamGoogleAddressException extends Exception {}
}