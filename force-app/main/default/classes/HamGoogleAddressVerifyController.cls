/**
 * Controller for the hamGoogleAddressVerify LWC.
 *
 * Verification runs against the Google Geocoding API (see the provider section below).
 * Runs in user mode (WITH USER_MODE + stripInaccessible) so the same methods are safe
 * to reuse from an Experience Cloud page, not just for internal admins.
 */
public with sharing class HamGoogleAddressVerifyController {

    /**
     * @return one entry per candidate match, best first. More than one means Google found
     *         the address ambiguous and staff should pick the correct row.
     */
    @AuraEnabled(cacheable=false)
    public static List<HamGoogleAddressResult> verifyAddress(Id addressId) {
        try {
            ucinn_ascendv2__Address__c addr = [
                SELECT Id, ucinn_ascendv2__Address_Line_1__c, ucinn_ascendv2__Address_Line_2__c,
                       ucinn_ascendv2__City__c, ucinn_ascendv2__State__c,
                       ucinn_ascendv2__Postal_Code__c, ucinn_ascendv2__Country__c,
                       ucinn_ascendv2__Country_ISO_Code__c
                FROM ucinn_ascendv2__Address__c
                WHERE Id = :addressId
                WITH USER_MODE
                LIMIT 1
            ];

            Request req = new Request();
            req.addressLine1 = addr.ucinn_ascendv2__Address_Line_1__c;
            req.addressLine2 = addr.ucinn_ascendv2__Address_Line_2__c;
            req.city         = addr.ucinn_ascendv2__City__c;
            req.state        = addr.ucinn_ascendv2__State__c;
            req.postalCode   = addr.ucinn_ascendv2__Postal_Code__c;
            req.country      = addr.ucinn_ascendv2__Country__c;
            req.countryIsoCode = addr.ucinn_ascendv2__Country_ISO_Code__c;

            List<HamGoogleAddressResult> results = verifyViaGeocoding(req);
            for (HamGoogleAddressResult r : results) {
                r.verificationSource = SOURCE_LABEL;
            }
            return results;

        } catch (QueryException qe) {
            throw new AuraHandledException('Address record not found or not accessible.');
        } catch (HamGoogleAddressException hgae) {
            System.debug('@@HamGoogleAddressVerifyController callout error: ' + hgae.getMessage());
            throw new AuraHandledException('Unable to verify this address right now. Please try again later.');
        } catch (Exception e) {
            System.debug('@@HamGoogleAddressVerifyController unexpected error: ' + e.getMessage());
            throw new AuraHandledException('An unexpected error occurred while verifying the address.');
        }
    }

    /**
     * Takes the chosen candidate as a JSON string rather than a typed parameter.
     *
     * Complex @AuraEnabled parameters proved unreliable here: the LWC builds its payload
     * from lightning-datatable rows, which Lightning Web Security hands over as read-only
     * proxies. Those deserialized into an all-null Apex object, so a confirm appeared to
     * succeed while writing nothing. JSON.stringify reads through the proxy correctly, so
     * the client sends a string and we deserialize it here.
     */
    @AuraEnabled
    public static void confirmAddress(Id addressId, String verifiedJson) {
        System.debug('@@confirmAddress rawJson: ' + verifiedJson);

        HamGoogleAddressResult parsed;
        try {
            parsed = String.isBlank(verifiedJson)
                ? null
                : (HamGoogleAddressResult) JSON.deserialize(verifiedJson, HamGoogleAddressResult.class);
        } catch (Exception e) {
            System.debug('@@confirmAddress could not parse payload: ' + e.getMessage());
            throw new AuraHandledException('The verification data could not be read, so nothing was saved.');
        }
        applyConfirmation(addressId, parsed);
    }

    /**
     * @return true when the value is an active picklist entry on Data_Source__c.
     *         Guards against INVALID_OR_NULL_FOR_RESTRICTED_PICKLIST on a restricted field.
     */
    @TestVisible
    private static Boolean isValidDataSource(String value) {
        if (String.isBlank(value)) {
            return false;
        }
        for (Schema.PicklistEntry entry :
                ucinn_ascendv2__Address__c.ucinn_ascendv2__Data_Source__c.getDescribe().getPicklistValues()) {
            if (entry.isActive() && entry.getValue() == value) {
                return true;
            }
        }
        return false;
    }

    /**
     * Decides what to write to Postal_Code__c.
     *
     * ZIP+4 is USPS data. A CASS-certified provider (SmartyStreets) is authoritative for
     * the +4; Google's postal_code_suffix is best-effort and demonstrably disagrees (for
     * 1 Oliver St Apt 3, Worcester MA: CASS says 01603-3051, Google says 01603-2711).
     * So when the record already carries a +4 and the 5-digit base still matches, the
     * existing value is kept rather than downgraded to Google's approximation.
     *
     * @return the value to write, or null to leave the field untouched.
     */
    @TestVisible
    private static String resolvePostalCode(String existing, String incoming) {
        if (String.isBlank(incoming)) {
            return null;
        }
        if (String.isBlank(existing)) {
            return incoming;
        }

        List<String> existingParts = existing.trim().split('-');
        Boolean existingHasPlus4 = existingParts.size() > 1 && String.isNotBlank(existingParts[1]);
        if (!existingHasPlus4) {
            return incoming;
        }

        String existingBase = existingParts[0].trim();
        String incomingBase = incoming.trim().split('-')[0].trim();
        // Same 5-digit ZIP: trust the existing (CASS) +4 over the provider's guess.
        return existingBase == incomingBase ? null : incoming;
    }

    /**
     * The actual write. Separate from the @AuraEnabled entry point so tests (and any
     * future server-side caller) can pass a typed result directly.
     */
    @TestVisible
    private static void applyConfirmation(Id addressId, HamGoogleAddressResult verified) {
        try {
            System.debug('@@applyConfirmation received: ' + JSON.serialize(verified));

            if (verified == null) {
                throw new AuraHandledException('Nothing to confirm - run Verify Address first.');
            }
            // Guard against a truncated payload. Previously an incomplete object still
            // wrote Source/Date and nulled Status/Precision, which looked like a silent
            // no-op on the record. Fail loudly instead of half-writing.
            if (String.isBlank(verified.verificationStatus)) {
                throw new AuraHandledException(
                    'Verification data was incomplete, so nothing was saved. Please click Verify Address again, then Confirm.'
                );
            }
            if (!Schema.sObjectType.ucinn_ascendv2__Address__c.isUpdateable()) {
                throw new AuraHandledException('You do not have permission to update Address records.');
            }

            ucinn_ascendv2__Address__c current = [
                SELECT Id, ucinn_ascendv2__Postal_Code__c
                FROM ucinn_ascendv2__Address__c
                WHERE Id = :addressId
                WITH USER_MODE
                LIMIT 1
            ];

            ucinn_ascendv2__Address__c addr = new ucinn_ascendv2__Address__c(Id = addressId);

            // Address fields: only overwrite what the provider actually returned, so a
            // partial response can never blank out data already on the record.
            if (String.isNotBlank(verified.addressLine1)) {
                addr.ucinn_ascendv2__Address_Line_1__c = verified.addressLine1;
            }
            if (String.isNotBlank(verified.addressLine2)) {
                addr.ucinn_ascendv2__Address_Line_2__c = verified.addressLine2;
            }
            if (String.isNotBlank(verified.city)) {
                addr.ucinn_ascendv2__City__c = verified.city;
            }
            if (String.isNotBlank(verified.state)) {
                addr.ucinn_ascendv2__State__c = verified.state;
            }
            String postalToWrite = resolvePostalCode(current.ucinn_ascendv2__Postal_Code__c, verified.postalCode);
            if (String.isNotBlank(postalToWrite)) {
                addr.ucinn_ascendv2__Postal_Code__c = postalToWrite;
            }
            if (String.isNotBlank(verified.country)) {
                addr.ucinn_ascendv2__Country__c = verified.country;
            }
            if (String.isNotBlank(verified.countryIsoCode)) {
                addr.ucinn_ascendv2__Country_ISO_Code__c = verified.countryIsoCode;
            }
            if (String.isNotBlank(verified.county)) {
                addr.ucinn_ascendv2__County__c = verified.county;
            }

            // USPS DPV data. Geocoding cannot supply these; skipping them when blank
            // preserves values a CASS-certified provider (e.g. SmartyStreets) stamped.
            if (String.isNotBlank(verified.dpvMatchCode)) {
                addr.ucinn_ascendv2__DPV_Match_Code__c = verified.dpvMatchCode;
            }
            if (String.isNotBlank(verified.dpvVacant)) {
                addr.ucinn_ascendv2__DPV_Vacant__c = verified.dpvVacant;
            }

            if (verified.latitude != null) {
                addr.ucinn_ascendv2__Location__Latitude__s = verified.latitude;
            }
            if (verified.longitude != null) {
                addr.ucinn_ascendv2__Location__Longitude__s = verified.longitude;
            }

            // Only a fully confirmed match counts as verified.
            Boolean isVerified = verified.verificationStatus == 'Verified';
            addr.ucinn_ascendv2__Is_Verified__c = isVerified;
            addr.ucinn_ascendv2__Verification_Status__c = verified.verificationStatus;
            if (String.isNotBlank(verified.addressPrecision)) {
                addr.ucinn_ascendv2__Address_Precision__c = verified.addressPrecision;
            }
            addr.ucinn_ascendv2__Verification_Source__c = String.isNotBlank(verified.verificationSource)
                ? verified.verificationSource
                : SOURCE_LABEL;
            addr.ucinn_ascendv2__Verification_Date_Time__c = Datetime.now();

            // Data_Source__c is a RESTRICTED picklist, so an unlisted value throws on save.
            // Only set it when the value exists; otherwise log and carry on rather than
            // failing the whole confirm. 'Google Address Validation API' is NOT yet a value,
            // so it must be added in Setup before switching providers or it simply won't stamp.
            String dataSource = String.isNotBlank(verified.verificationSource)
                ? verified.verificationSource
                : SOURCE_LABEL;
            if (isValidDataSource(dataSource)) {
                addr.ucinn_ascendv2__Data_Source__c = dataSource;
            } else {
                System.debug('@@Data_Source__c has no active picklist value "' + dataSource
                    + '" - skipping so the confirm still succeeds. Add it in Setup to record the source.');
            }

            // Audit trail. The request has its API key redacted upstream; never persist a secret.
            if (String.isNotBlank(verified.apiRequest)) {
                addr.ucinn_ascendv2__Address_Verification_API_Request__c = verified.apiRequest;
            }
            if (String.isNotBlank(verified.apiResponse)) {
                addr.ucinn_ascendv2__Address_Verification_API_Response__c = verified.apiResponse;
            }
            if (String.isNotBlank(verified.verificationResponse)) {
                addr.ucinn_ascendv2__Verification_Response__c = verified.verificationResponse;
            }

            SObjectAccessDecision decision = Security.stripInaccessible(
                AccessType.UPDATABLE,
                new List<ucinn_ascendv2__Address__c>{ addr }
            );
            update decision.getRecords();

        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (DmlException de) {
            // Surface the platform's own reason rather than a generic retry message. The
            // common case is Ascend's duplicate-address validation firing because Google's
            // standardisation ("College Hill Road" -> "College Hill Rd") now collides with
            // an existing Address record - retrying can never fix that, so telling the user
            // to try again is worse than useless. The message names the conflicting record.
            String reason = de.getNumDml() > 0 ? de.getDmlMessage(0) : de.getMessage();
            System.debug('@@HamGoogleAddressVerifyController confirmAddress DML error: ' + de.getMessage());
            throw userError(
                String.isBlank(reason) ? 'Unable to save the confirmed address.' : 'Could not save: ' + reason
            );
        } catch (Exception e) {
            System.debug('@@HamGoogleAddressVerifyController confirmAddress error: ' + e.getMessage());
            throw new AuraHandledException('Unable to save the confirmed address. Please try again.');
        }
    }

    /**
     * Provider-agnostic address input. Inner class so the DTO travels with the
     * controller that owns it; it is server-side only and never sent to the browser.
     */
    public class Request {
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

    // ═══════════════════════════════════════════════════════════════════════════════
    //  Google Geocoding provider
    //
    //  Uses the pre-existing Geocoding_API_Named_Cred, whose URL already carries the
    //  full /maps/api/geocode/json path, so only query params are appended.
    //
    //  LIMITATION: Geocoding answers "where is this on a map", not "is this mailable".
    //  It returns no USPS DPV data, and given a nonexistent unit it silently drops the
    //  unit while still reporting a confident ROOFTOP match - hence markUnit() below.
    //
    //  TO SWITCH TO THE ADDRESS VALIDATION API (better: adds USPS DPV deliverability
    //  and vacancy, and reports unconfirmed components instead of dropping them):
    //    1. Google Cloud project 843892269827: add "Address Validation API" to the
    //       API-restrictions allowlist for the key in Google_Map_API_Key__c.
    //    2. Create a Named Credential whose URL is the FULL path including the colon:
    //         https://addressvalidation.googleapis.com/v1:validateAddress
    //       The path MUST live in the credential URL - Salesforce URL-encodes a colon
    //       in an appended path and Google rejects that with an HTML 400.
    //    3. POST {"address":{"addressLines":[..],"locality":..,"administrativeArea":..,
    //       "postalCode":..,"regionCode":..}} with ?key= appended.
    //    4. Map result.address.postalAddress.* for the address, result.uspsData
    //       .dpvConfirmation/.dpvVacant for DPV, result.verdict.validationGranularity
    //       for precision, and .hasUnconfirmedComponents for the unit check.
    //    5. Add "Google Address Validation API" to the Data_Source__c picklist (it is
    //       RESTRICTED - an unlisted value would otherwise be skipped by isValidDataSource).
    // ═══════════════════════════════════════════════════════════════════════════════

    /** Stamped into Verification_Source__c and Data_Source__c so records stay auditable. */
    @TestVisible
    private static final String SOURCE_LABEL = 'Google Geocoding API';

    /** Thrown on a non-200 or unusable provider response. */
    public class HamGoogleAddressException extends Exception {}

    public static final String NAME_CRED = 'callout:Geocoding_API_Named_Cred';


    /** Upper bound on candidates shown to staff; Google can return ~10. */
    @TestVisible
    private static final Integer MAX_CANDIDATES = 5;

    private static List<HamGoogleAddressResult> verifyViaGeocoding(Request req) {
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
            throw new HamGoogleAddressException(
                'Geocoding API returned status ' + res.getStatusCode() + ': ' + res.getBody()
            );
        }

        GeoResponse parsed = parseResponse(res.getBody());

        if (parsed == null || parsed.status != 'OK' || parsed.results == null || parsed.results.isEmpty()) {
            String detail = parsed == null ? 'unparseable response' : parsed.status + ' ' + parsed.error_message;
            throw new HamGoogleAddressException('Geocoding API returned no usable result: ' + detail);
        }

        List<HamGoogleAddressResult> candidates = new List<HamGoogleAddressResult>();
        for (GeoResult geoRes : parsed.results) {
            if (candidates.size() >= MAX_CANDIDATES) {
                System.debug('@@HamGoogleAddressVerifyController truncated candidates at '
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
    private static HamGoogleAddressResult mapResult(GeoResult res, Request req) {
        HamGoogleAddressResult out = new HamGoogleAddressResult();

        Component streetNumber = findComponent(res, 'street_number');
        Component route        = findComponent(res, 'route');
        Component subpremise   = findComponent(res, 'subpremise');
        Component locality     = findComponent(res, 'locality');
        Component postalTown   = findComponent(res, 'postal_town');
        Component adminOne     = findComponent(res, 'administrative_area_level_1');
        Component adminTwo     = findComponent(res, 'administrative_area_level_2');
        Component countryCmp   = findComponent(res, 'country');
        Component postal       = findComponent(res, 'postal_code');
        Component postalSuffix = findComponent(res, 'postal_code_suffix');

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
    private static void markUnit(
        HamGoogleAddressResult out,
        GeoResult res,
        Request req,
        Component subpremise
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

    private static String deriveStatus(GeoResult res, HamGoogleAddressResult out) {
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

    // ── Google Geocoding response types ────────────────────────────────────────────
    // Flattened as siblings, not nested: Apex allows only one level of inner classes.
    // Property names match Google's snake_case JSON so plain JSON.deserialize works.

    public class GeoResponse {
        public String status { get; set; }
        public String error_message { get; set; }
        public List<GeoResult> results { get; set; }
    }

    public class GeoResult {
        public String formatted_address { get; set; }
        public Boolean partial_match { get; set; }
        public String place_id { get; set; }
        public List<String> types { get; set; }
        public Geometry geometry { get; set; }
        public List<Component> address_components { get; set; }
    }

    public class Geometry {
        public String location_type { get; set; }
        public Loc location { get; set; }
    }

    public class Loc {
        public Double lat { get; set; }
        public Double lng { get; set; }
    }

    public class Component {
        public String long_name { get; set; }
        public String short_name { get; set; }
        public List<String> types { get; set; }
    }

    private static GeoResponse parseResponse(String jsonStr) {
        return (GeoResponse) JSON.deserialize(jsonStr, GeoResponse.class);
    }

    /** @return the component whose types contain the given type, or null. */
    private static Component findComponent(GeoResult res, String componentType) {
        if (res == null || res.address_components == null) {
            return null;
        }
        for (Component c : res.address_components) {
            if (c.types != null && c.types.contains(componentType)) {
                return c;
            }
        }
        return null;
    }

    /**
     * Builds an AuraHandledException whose message is readable both client-side and from
     * Apex. Without the explicit setMessage(), getMessage() returns only
     * "Script-thrown exception", which makes the reason untestable and hides it from logs.
     */
    private static AuraHandledException userError(String message) {
        AuraHandledException e = new AuraHandledException(message);
        e.setMessage(message);
        return e;
    }
}