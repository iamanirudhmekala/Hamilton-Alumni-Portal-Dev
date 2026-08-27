/**
 * Pluggable address-verification provider.
 *
 * Implementations:
 *   HamGoogleAddressGeocodeCallout - Google Geocoding API (active today; the only
 *                                    API the current API key is permitted to call)
 *   HamGoogleAddressCallout        - Google Address Validation API (preferred; adds
 *                                    USPS DPV deliverability + vacancy data, blocked
 *                                    until the key is allowlisted for it)
 *
 * Swap the active provider in HamGoogleAddressProviderFactory.
 */
public interface HamGoogleAddressProvider {
    /**
     * @param req the address to verify
     * @return one entry per candidate match, best first; never null or empty.
     *         Geocoding can return several candidates for an ambiguous address so staff
     *         can pick the right one. Address Validation returns a single candidate.
     * @throws HamGoogleAddressCallout.HamGoogleAddressException on a non-200 response
     */
    List<HamGoogleAddressResult> verify(HamGoogleAddressRequest req);

    /** Value stamped into ucinn_ascendv2__Verification_Source__c so records stay auditable. */
    String getSourceLabel();
}