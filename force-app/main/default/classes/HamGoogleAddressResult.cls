/**
 * Provider-agnostic verification result returned to the hamGoogleAddressVerify LWC
 * and passed back in to confirmAddress.
 *
 * Fields left null are NOT written on confirm, so a provider that cannot supply a
 * value (e.g. Geocoding has no USPS DPV data) never erases data another provider
 * previously stamped.
 */
public class HamGoogleAddressResult {
    @AuraEnabled public String addressLine1;
    @AuraEnabled public String addressLine2;
    @AuraEnabled public String city;
    @AuraEnabled public String state;
    @AuraEnabled public String postalCode;
    @AuraEnabled public String country;
    @AuraEnabled public String countryIsoCode;
    @AuraEnabled public String county;

    // USPS delivery-point data. Only the Address Validation API supplies these.
    @AuraEnabled public String dpvMatchCode;
    @AuraEnabled public String dpvVacant;

    @AuraEnabled public String verificationStatus;
    @AuraEnabled public String addressPrecision;

    // Set by the controller from the active provider's label.
    @AuraEnabled public String verificationSource;

    @AuraEnabled public Double latitude;
    @AuraEnabled public Double longitude;

    /**
     * False when the input carried a unit/apt but the provider did not confirm it.
     * The LWC surfaces this so staff are not shown a clean-looking "Verified" row
     * for an address whose unit was never validated.
     */
    @AuraEnabled public Boolean unitConfirmed = true;

    /** Short human-readable caveat shown in the UI when present. */
    @AuraEnabled public String statusNote;

    // ── Audit trail (written to the Ascend verification fields on confirm) ──────────

    /** The outbound request, API KEY REDACTED. Never store a live secret on a record. */
    @AuraEnabled public String apiRequest;

    /** Raw provider response body, truncated to fit the field. */
    @AuraEnabled public String apiResponse;

    /** Short provider verdict for Verification_Response__c (255 char limit). */
    @AuraEnabled public String verificationResponse;

    /** Field limits on ucinn_ascendv2__Address__c. */
    private static final Integer MAX_AUDIT_LEN = 32000;
    private static final Integer MAX_RESPONSE_LEN = 255;

    public void setAuditTrail(String request, String response) {
        this.apiRequest = truncate(redactKey(request), MAX_AUDIT_LEN);
        this.apiResponse = truncate(compact(response), MAX_AUDIT_LEN);
    }

    public void setVerificationResponse(String value) {
        this.verificationResponse = truncate(value, MAX_RESPONSE_LEN);
    }

    /**
     * Collapses the provider's pretty-printed JSON onto one compact line.
     *
     * The response is otherwise unaltered: same content, same fields, every candidate -
     * only Google's newline/indentation padding is removed. Falls back to the raw string
     * if it cannot be parsed.
     */
    @TestVisible
    private static String compact(String jsonStr) {
        if (String.isBlank(jsonStr)) {
            return jsonStr;
        }
        try {
            return JSON.serialize(JSON.deserializeUntyped(jsonStr));
        } catch (Exception e) {
            return jsonStr;
        }
    }

    /** Strips the Google API key so it is never persisted to a record. */
    @TestVisible
    private static String redactKey(String url) {
        if (String.isBlank(url)) {
            return url;
        }
        return url.replaceAll('(?i)([?&]key=)[^&]*', '$1REDACTED');
    }

    private static String truncate(String value, Integer max) {
        if (String.isBlank(value) || value.length() <= max) {
            return value;
        }
        return value.substring(0, max - 15) + '...[truncated]';
    }
}