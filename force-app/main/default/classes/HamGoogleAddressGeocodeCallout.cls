/**
 * Address verification backed by the Google Geocoding API.
 *
 * This is the provider that works with the current API key. It reuses the existing,
 * already-working Geocoding_API_Named_Cred (whose URL carries the full
 * /maps/api/geocode/json path, so only query params are appended here).
 *
 * IMPORTANT LIMITATION: Geocoding is a "where is this on a map" service, not a
 * deliverability service. It supplies no USPS DPV data, and given a nonexistent unit
 * it silently drops the unit and still reports a confident ROOFTOP match. This class
 * therefore checks whether the unit survived the round trip and refuses to report a
 * clean "Verified" (or to overwrite the unit line) when it did not. See markUnit().
 */
public with sharing class HamGoogleAddressGeocodeCallout implements HamGoogleAddressProvider {
    public static final String NAME_CRED = 'callout:Geocoding_API_Named_Cred';

    public String getSourceLabel() {
        return 'Google Geocoding API';
    }

    /** Upper bound on candidates shown to staff; Google can return ~10. */
    @TestVisible
    private static final Integer MAX_CANDIDATES = 5;

    public List<HamGoogleAddressResult> verify(HamGoogleAddressRequest req) {
        String encoded = EncodingUtil.urlEncode(req.toSingleLine(), 'UTF-8');

        // Bias to the record's own country rather than hardcoding US, so international
        // addresses resolve. With no ISO code we search globally instead of forcing US,
        // which would otherwise mangle a non-US address into a wrong US match.
        String isoCode = req.resolveIsoCode();
        String components = String.isNotBlank(isoCode)
            ? '&components=country:' + EncodingUtil.urlEncode(isoCode, 'UTF-8')
            : '';

        String endpoint = NAME_CRED + '?address=' + encoded + components + '&key=' + getApiKey();

        HttpRequest httpReq = new HttpRequest();
        httpReq.setEndpoint(endpoint);
        httpReq.setMethod('GET');

        HttpResponse res = new Http().send(httpReq);

        if (res.getStatusCode() != 200) {
            throw new HamGoogleAddressCallout.HamGoogleAddressException(
                'Geocoding API returned status ' + res.getStatusCode() + ': ' + res.getBody()
            );
        }

        HamGoogleAddressGeocodeResponse parsed = HamGoogleAddressGeocodeResponse.parse(res.getBody());

        if (parsed == null || parsed.status != 'OK' || parsed.results == null || parsed.results.isEmpty()) {
            String detail = parsed == null ? 'unparseable response' : parsed.status + ' ' + parsed.error_message;
            throw new HamGoogleAddressCallout.HamGoogleAddressException('Geocoding API returned no usable result: ' + detail);
        }

        List<HamGoogleAddressResult> candidates = new List<HamGoogleAddressResult>();
        for (HamGoogleAddressGeocodeResponse.GeoResult geoRes : parsed.results) {
            if (candidates.size() >= MAX_CANDIDATES) {
                System.debug('@@HamGoogleAddressGeocodeCallout truncated candidates at '
                    + MAX_CANDIDATES + ' of ' + parsed.results.size());
                break;
            }
            HamGoogleAddressResult mapped = mapResult(geoRes, req);
            // The complete, unaltered response body. setAuditTrail redacts the key in the
            // request and strips only Google's pretty-print padding from the response.
            mapped.setAuditTrail(endpoint, res.getBody());
            mapped.setVerificationResponse(parsed.status
                + (String.isNotBlank(geoRes.formatted_address) ? ' | ' + geoRes.formatted_address : '')
                + ' | ' + geoRes.geometry?.location_type
                + (geoRes.partial_match == true ? ' | partial_match' : ''));
            candidates.add(mapped);
        }
        return candidates;
    }

    @TestVisible
    private HamGoogleAddressResult mapResult(HamGoogleAddressGeocodeResponse.GeoResult res, HamGoogleAddressRequest req) {
        HamGoogleAddressResult out = new HamGoogleAddressResult();

        HamGoogleAddressGeocodeResponse.Component streetNumber = HamGoogleAddressGeocodeResponse.findComponent(res, 'street_number');
        HamGoogleAddressGeocodeResponse.Component route        = HamGoogleAddressGeocodeResponse.findComponent(res, 'route');
        HamGoogleAddressGeocodeResponse.Component subpremise   = HamGoogleAddressGeocodeResponse.findComponent(res, 'subpremise');
        HamGoogleAddressGeocodeResponse.Component locality     = HamGoogleAddressGeocodeResponse.findComponent(res, 'locality');
        HamGoogleAddressGeocodeResponse.Component postalTown   = HamGoogleAddressGeocodeResponse.findComponent(res, 'postal_town');
        HamGoogleAddressGeocodeResponse.Component adminOne     = HamGoogleAddressGeocodeResponse.findComponent(res, 'administrative_area_level_1');
        HamGoogleAddressGeocodeResponse.Component adminTwo     = HamGoogleAddressGeocodeResponse.findComponent(res, 'administrative_area_level_2');
        HamGoogleAddressGeocodeResponse.Component countryCmp   = HamGoogleAddressGeocodeResponse.findComponent(res, 'country');
        HamGoogleAddressGeocodeResponse.Component postal       = HamGoogleAddressGeocodeResponse.findComponent(res, 'postal_code');
        HamGoogleAddressGeocodeResponse.Component postalSuffix = HamGoogleAddressGeocodeResponse.findComponent(res, 'postal_code_suffix');

        // Street line: USPS-style abbreviations come from short_name ("Roberts St").
        List<String> streetParts = new List<String>();
        if (streetNumber != null && String.isNotBlank(streetNumber.short_name)) {
            streetParts.add(streetNumber.short_name);
        }
        if (route != null && String.isNotBlank(route.short_name)) {
            streetParts.add(route.short_name);
        }
        out.addressLine1 = streetParts.isEmpty() ? null : String.join(streetParts, ' ');

        out.city    = locality != null ? locality.long_name : (postalTown != null ? postalTown.long_name : null);
        out.state   = adminOne != null ? adminOne.short_name : null;
        out.county  = adminTwo != null ? adminTwo.long_name : null;
        out.country = countryCmp != null ? countryCmp.long_name : null;
        // Google's country short_name is the ISO 3166-1 alpha-2 code.
        out.countryIsoCode = countryCmp != null ? countryCmp.short_name : null;

        // ZIP+4 when Google supplies the suffix.
        if (postal != null && String.isNotBlank(postal.long_name)) {
            out.postalCode = String.isNotBlank(postalSuffix?.long_name)
                ? postal.long_name + '-' + postalSuffix.long_name
                : postal.long_name;
        }

        if (res.geometry?.location != null) {
            // Location__Latitude__s / __Longitude__s are scale 4 in this org.
            if (res.geometry.location.lat != null) {
                out.latitude = Decimal.valueOf(res.geometry.location.lat).setScale(4).doubleValue();
            }
            if (res.geometry.location.lng != null) {
                out.longitude = Decimal.valueOf(res.geometry.location.lng).setScale(4).doubleValue();
            }
        }

        out.addressPrecision = res.geometry?.location_type;

        // Geocoding never returns USPS data. Leaving these null means confirmAddress
        // will not overwrite DPV values a CASS-certified provider previously stamped.
        out.dpvMatchCode = null;
        out.dpvVacant    = null;

        markUnit(out, res, req, subpremise);
        out.verificationStatus = deriveStatus(res, out);

        return out;
    }

    /**
     * Matches a secondary-unit designator anywhere in a street line, e.g.
     * "507 Roberts St Apt 4", "12 Main Street, Unit 3B", "8 Elm St #2".
     */
    private static final Pattern UNIT_PATTERN = Pattern.compile(
        '(?i).*\\b(apt|apartment|unit|ste|suite|fl|floor|rm|room|bldg|building|trlr|lot|spc|space)\\b\\.?\\s*\\S+.*'
    );

    /**
     * Protects the unit. Google drops an unrecognised apartment number without flagging
     * it, so an unconfirmed unit must never be silently erased from the record.
     *
     * The unit may live in EITHER line: staff type it in Address Line 2, but a prior
     * CASS provider may have folded it into Address Line 1 ("507 Roberts St Apt 4").
     * Rebuilding line 1 from street_number + route would drop it, so when the unit is
     * embedded in line 1 and unconfirmed we keep line 1 exactly as it was.
     */
    private void markUnit(
        HamGoogleAddressResult out,
        HamGoogleAddressGeocodeResponse.GeoResult res,
        HamGoogleAddressRequest req,
        HamGoogleAddressGeocodeResponse.Component subpremise
    ) {
        Boolean googleReturnedUnit = subpremise != null && String.isNotBlank(subpremise.long_name);
        Boolean unitInLine1 = String.isNotBlank(req.addressLine1)
            && (UNIT_PATTERN.matcher(req.addressLine1).matches() || req.addressLine1.contains('#'));

        if (req.hasUnit()) {
            // Keep exactly what staff entered ("Apt 4"), not Google's bare "4".
            out.addressLine2 = req.addressLine2;
            out.unitConfirmed = googleReturnedUnit;
            if (!googleReturnedUnit) {
                out.statusNote = 'Google could not confirm unit "' + req.addressLine2
                    + '". The unit was kept as entered and NOT verified.';
            }
            return;
        }

        if (unitInLine1 && !googleReturnedUnit) {
            // Preserve the original line 1 verbatim so the embedded unit survives.
            out.addressLine1 = req.addressLine1;
            out.addressLine2 = null;
            out.unitConfirmed = false;
            out.statusNote = 'Google could not confirm the unit in "' + req.addressLine1
                + '". Address Line 1 was kept as entered and NOT verified.';
            return;
        }

        if (googleReturnedUnit) {
            out.addressLine2 = unitInLine1 ? null : '#' + subpremise.long_name;
            if (unitInLine1) {
                // Unit confirmed but it lives in line 1 - keep it there, do not split.
                out.addressLine1 = req.addressLine1;
            }
            out.unitConfirmed = true;
            return;
        }

        out.addressLine2 = null;
        out.unitConfirmed = true;
    }

    private String deriveStatus(HamGoogleAddressGeocodeResponse.GeoResult res, HamGoogleAddressResult out) {
        String precision = res.geometry?.location_type;
        Boolean partial  = res.partial_match == true;
        Boolean streetLevel = res.types != null
            && (res.types.contains('street_address') || res.types.contains('premise') || res.types.contains('subpremise'));

        // Values must fit ucinn_ascendv2__Verification_Status__c (16 chars).
        if (partial || !streetLevel || precision == 'APPROXIMATE' || precision == 'GEOMETRIC_CENTER') {
            if (String.isBlank(out.statusNote)) {
                out.statusNote = 'Google could not match this to a specific street address.';
            }
            return 'Unverified';
        }
        if (!out.unitConfirmed || precision == 'RANGE_INTERPOLATED') {
            if (String.isBlank(out.statusNote)) {
                out.statusNote = 'Street matched but the exact building was interpolated, not confirmed.';
            }
            return 'Partial';
        }
        return 'Verified';
    }

    private static String getApiKey() {
        return Google_Map_API_Key__c.getOrgDefaults()?.Key__c;
    }
}