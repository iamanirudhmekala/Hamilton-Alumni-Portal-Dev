/**
 * Selects the active address-verification provider.
 *
 * ── TO SWITCH TO THE ADDRESS VALIDATION API ──────────────────────────────────────
 * Change ACTIVE_PROVIDER to ProviderType.ADDRESS_VALIDATION and deploy this one class.
 *
 * Prerequisite: the API key in the Google_Map_API_Key__c custom setting must be
 * allowlisted for the Address Validation API in Google Cloud project 843892269827
 * (Credentials > the key > API restrictions). Until then the callout fails with
 * 403 API_KEY_SERVICE_BLOCKED and this must stay on GEOCODING.
 *
 * Address Validation is the preferred provider: it adds USPS DPV deliverability and
 * vacancy data, and it explicitly reports components it could not confirm rather than
 * silently dropping them the way Geocoding does.
 */
public with sharing class HamGoogleAddressProviderFactory {
    public enum ProviderType {
        GEOCODING,
        ADDRESS_VALIDATION
    }

    @TestVisible
    private static ProviderType activeProvider = ProviderType.GEOCODING;

    public static HamGoogleAddressProvider getProvider() {
        if (activeProvider == ProviderType.ADDRESS_VALIDATION) {
            return new HamGoogleAddressCallout();
        }
        return new HamGoogleAddressGeocodeCallout();
    }
}