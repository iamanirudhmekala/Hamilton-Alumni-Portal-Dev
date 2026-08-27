/**
 * Provider-agnostic address input for the hamGoogleAddressVerify flow.
 * Shared by HamGoogleAddressCallout (Address Validation API) and
 * HamGoogleAddressGeocodeCallout (Geocoding API).
 */
public class HamGoogleAddressRequest {
    public String addressLine1;
    public String addressLine2;
    public String city;
    public String state;
    public String postalCode;
    public String country;

    /** ISO 3166-1 alpha-2 (US, CA, GB...). Drives the Geocoding country filter. */
    public String countryIsoCode;

    /**
     * @return true when the caller supplied a unit / apartment / suite line.
     *         Used to detect a provider silently dropping an unconfirmed unit.
     */
    public Boolean hasUnit() {
        return String.isNotBlank(this.addressLine2);
    }

    /**
     * Flattens the address into the single-line form the Geocoding API expects.
     */
    public String toSingleLine() {
        List<String> parts = new List<String>();
        if (String.isNotBlank(addressLine1)) {
            parts.add(addressLine1.trim());
        }
        if (String.isNotBlank(addressLine2)) {
            parts.add(addressLine2.trim());
        }
        if (String.isNotBlank(city)) {
            parts.add(city.trim());
        }

        String stateZip = String.isNotBlank(state) ? state.trim() : '';
        if (String.isNotBlank(postalCode)) {
            stateZip = String.isBlank(stateZip) ? postalCode.trim() : stateZip + ' ' + postalCode.trim();
        }
        if (String.isNotBlank(stateZip)) {
            parts.add(stateZip);
        }
        // Include the country so non-US addresses resolve even when no ISO filter is applied.
        if (String.isNotBlank(country)) {
            parts.add(country.trim());
        }

        return String.join(parts, ', ');
    }

    /**
     * @return the ISO country code to restrict geocoding to, or blank to search globally.
     *         Falls back to mapping a spelled-out United States, which is by far the most
     *         common Country__c value in this org and often stored without an ISO code.
     */
    public String resolveIsoCode() {
        if (String.isNotBlank(countryIsoCode)) {
            return countryIsoCode.trim().toUpperCase();
        }
        if (String.isNotBlank(country)) {
            String c = country.trim().toLowerCase();
            if (c == 'united states' || c == 'usa' || c == 'united states of america' || c == 'us') {
                return 'US';
            }
        }
        return null;
    }
}