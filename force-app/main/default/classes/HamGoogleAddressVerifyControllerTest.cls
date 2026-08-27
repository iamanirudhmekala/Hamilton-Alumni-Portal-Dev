@IsTest
public with sharing class HamGoogleAddressVerifyControllerTest {

    @TestSetup
    static void makeData() {
        insert new ucinn_ascendv2__Address__c(
            ucinn_ascendv2__Address_Line_1__c = '507 Roberts St',
            ucinn_ascendv2__Address_Line_2__c = 'Apt 4',
            ucinn_ascendv2__City__c           = 'Rome',
            ucinn_ascendv2__State__c          = 'NY',
            ucinn_ascendv2__Postal_Code__c    = '13440',
            ucinn_ascendv2__Country__c        = 'United States'
        );
    }

    private static Id addressId() {
        return [SELECT Id FROM ucinn_ascendv2__Address__c LIMIT 1].Id;
    }

    // ── Geocoding provider (active) ───────────────────────────────────────────────

    @IsTest
    static void testGeocodeVerifyHappyPath() {
        Test.setMock(HttpCalloutMock.class, new GeocodeMock());

        Test.startTest();
        List<HamGoogleAddressResult> rs = HamGoogleAddressVerifyController.verifyAddress(addressId());
        HamGoogleAddressResult r = rs[0];
        Test.stopTest();

        System.assertEquals('507 Roberts St', r.addressLine1, 'Street should be built from street_number + route short_name');
        System.assertEquals('Rome', r.city, 'City should come from locality');
        System.assertEquals('NY', r.state, 'State should come from admin_area_1 short_name');
        System.assertEquals('Oneida County', r.county, 'County should come from admin_area_2');
        System.assertEquals('13440-5273', r.postalCode, 'Postal code should be ZIP+4 when a suffix is returned');
        System.assertEquals('United States', r.country, 'Country should come from country long_name');
        System.assertEquals('ROOFTOP', r.addressPrecision, 'Precision should be the Geocoding location_type');
        System.assertEquals('Verified', r.verificationStatus, 'ROOFTOP + confirmed unit should be Verified');
        System.assertEquals(true, r.unitConfirmed, 'subpremise present means the unit is confirmed');
        System.assertEquals('Google Geocoding API', r.verificationSource, 'Source should be stamped from the provider label');
        System.assertEquals(43.2072, r.latitude, 'Latitude should be rounded to scale 4');
        System.assertEquals(-75.4563, r.longitude, 'Longitude should be rounded to scale 4');
        System.assertEquals(null, r.dpvMatchCode, 'Geocoding supplies no USPS DPV data');
        System.assertEquals(null, r.dpvVacant, 'Geocoding supplies no USPS vacancy data');
    }

    /**
     * The important one: Google silently drops an unrecognised unit and still reports
     * ROOFTOP / partial_match=false. The unit must be preserved and NOT marked verified.
     */
    @IsTest
    static void testGeocodeDroppedUnitIsNotSilentlyAccepted() {
        Test.setMock(HttpCalloutMock.class,
            new GeocodeMock(GeoScenario.ROOFTOP_UNIT_DROPPED));

        Test.startTest();
        List<HamGoogleAddressResult> rs = HamGoogleAddressVerifyController.verifyAddress(addressId());
        HamGoogleAddressResult r = rs[0];
        Test.stopTest();

        System.assertEquals('Apt 4', r.addressLine2, 'A dropped unit must be preserved exactly as entered');
        System.assertEquals(false, r.unitConfirmed, 'Missing subpremise means the unit was not confirmed');
        System.assertEquals('Partial', r.verificationStatus, 'An unconfirmed unit must not report Verified');
        System.assertNotEquals(null, r.statusNote, 'A caveat should be surfaced to staff');
    }

    /**
     * Regression: a unit folded into Address Line 1 (as CASS providers do, e.g.
     * "507 Roberts St Apt 4") must not be lost when line 1 is rebuilt from
     * street_number + route.
     */
    @IsTest
    static void testGeocodeUnitEmbeddedInLine1IsNotDropped() {
        Id addrId = addressId();
        update new ucinn_ascendv2__Address__c(
            Id = addrId,
            ucinn_ascendv2__Address_Line_1__c = '507 Roberts St Apt 4',
            ucinn_ascendv2__Address_Line_2__c = null
        );
        Test.setMock(HttpCalloutMock.class,
            new GeocodeMock(GeoScenario.ROOFTOP_UNIT_DROPPED));

        Test.startTest();
        List<HamGoogleAddressResult> rs = HamGoogleAddressVerifyController.verifyAddress(addrId);
        HamGoogleAddressResult r = rs[0];
        Test.stopTest();

        System.assertEquals('507 Roberts St Apt 4', r.addressLine1,
            'An unconfirmed unit embedded in line 1 must be preserved verbatim, not rebuilt to "507 Roberts St"');
        System.assertEquals(false, r.unitConfirmed, 'The embedded unit was not confirmed');
        System.assertNotEquals('Verified', r.verificationStatus, 'An unconfirmed unit must not report Verified');
    }

    @IsTest
    static void testGeocodeApproximateIsUnverified() {
        Test.setMock(HttpCalloutMock.class,
            new GeocodeMock(GeoScenario.APPROXIMATE_PARTIAL));

        Test.startTest();
        List<HamGoogleAddressResult> rs = HamGoogleAddressVerifyController.verifyAddress(addressId());
        HamGoogleAddressResult r = rs[0];
        Test.stopTest();

        System.assertEquals('Unverified', r.verificationStatus, 'partial_match/APPROXIMATE must be Unverified');
    }

    /** An ambiguous address must surface every candidate so staff can pick the right one. */
    @IsTest
    static void testGeocodeReturnsAllCandidates() {
        Test.setMock(HttpCalloutMock.class,
            new GeocodeMock(GeoScenario.MULTIPLE_CANDIDATES));

        Test.startTest();
        List<HamGoogleAddressResult> rs = HamGoogleAddressVerifyController.verifyAddress(addressId());
        Test.stopTest();

        System.assertEquals(2, rs.size(), 'Both candidate matches should be returned, not just the first');
        System.assertEquals('507 Roberts St', rs[0].addressLine1, 'First candidate should map correctly');
        System.assertEquals('507 Roberts Rd', rs[1].addressLine1, 'Second candidate should map correctly');
        System.assertEquals('13441', rs[1].postalCode, 'Each candidate keeps its own postal code');
        System.assertEquals('Google Geocoding API', rs[1].verificationSource, 'Source is stamped on every candidate');
    }

    @IsTest
    static void testGeocodeZeroResultsSurfacesCleanError() {
        Test.setMock(HttpCalloutMock.class,
            new GeocodeMock(GeoScenario.ZERO_RESULTS));

        Boolean caught = false;
        Test.startTest();
        try {
            HamGoogleAddressVerifyController.verifyAddress(addressId());
        } catch (AuraHandledException ahe) {
            caught = true;
        }
        Test.stopTest();

        System.assertEquals(true, caught, 'ZERO_RESULTS should surface as a handled exception, not a raw error');
    }

    // ── International support ─────────────────────────────────────────────────────

    @IsTest
    static void testIsoCodeDrivesCountryFilter() {
        HamGoogleAddressVerifyController.Request gb = new HamGoogleAddressVerifyController.Request();
        gb.countryIsoCode = 'gb';
        System.assertEquals('GB', gb.resolveIsoCode(), 'An explicit ISO code should be used, upper-cased');

        HamGoogleAddressVerifyController.Request us = new HamGoogleAddressVerifyController.Request();
        us.country = 'United States';
        System.assertEquals('US', us.resolveIsoCode(), 'A spelled-out United States should map to US');

        HamGoogleAddressVerifyController.Request fr = new HamGoogleAddressVerifyController.Request();
        fr.country = 'France';
        System.assertEquals(null, fr.resolveIsoCode(),
            'An unmapped country name must search globally rather than being forced to US');

        HamGoogleAddressVerifyController.Request none = new HamGoogleAddressVerifyController.Request();
        System.assertEquals(null, none.resolveIsoCode(), 'No country data should search globally');
    }

    @IsTest
    static void testSingleLineIncludesCountryForInternational() {
        HamGoogleAddressVerifyController.Request req = new HamGoogleAddressVerifyController.Request();
        req.addressLine1 = '10 Downing St';
        req.city = 'London';
        req.postalCode = 'SW1A 2AA';
        req.country = 'United Kingdom';

        String line = req.toSingleLine();
        System.assertEquals(true, line.contains('United Kingdom'),
            'Country must be included so non-US addresses resolve: ' + line);
        System.assertEquals(true, line.contains('SW1A 2AA'), 'Non-numeric postcodes must survive: ' + line);
    }

    // ── Confirm / write-back ──────────────────────────────────────────────────────

    @IsTest
    static void testConfirmAddressWritesFieldsAndStampsMetadata() {
        Id addrId = addressId();

        HamGoogleAddressResult v = new HamGoogleAddressResult();
        v.addressLine1 = '507 Roberts St';
        v.addressLine2 = 'Apt 4';
        v.city = 'Rome';
        v.state = 'NY';
        v.county = 'Oneida County';
        v.postalCode = '13440-5273';
        v.country = 'United States';
        v.verificationStatus = 'Verified';
        v.addressPrecision = 'ROOFTOP';
        v.verificationSource = 'Google Geocoding API';
        v.latitude = 43.2072;
        v.longitude = -75.4563;

        Test.startTest();
        HamGoogleAddressVerifyController.applyConfirmation(addrId, v);
        Test.stopTest();

        ucinn_ascendv2__Address__c a = [
            SELECT ucinn_ascendv2__Postal_Code__c, ucinn_ascendv2__County__c,
                   ucinn_ascendv2__Is_Verified__c, ucinn_ascendv2__Verification_Status__c,
                   ucinn_ascendv2__Verification_Source__c, ucinn_ascendv2__Verification_Date_Time__c,
                   ucinn_ascendv2__Address_Precision__c,
                   ucinn_ascendv2__Location__Latitude__s, ucinn_ascendv2__Location__Longitude__s
            FROM ucinn_ascendv2__Address__c WHERE Id = :addrId
        ];

        System.assertEquals('13440-5273', a.ucinn_ascendv2__Postal_Code__c, 'ZIP+4 should be written');
        System.assertEquals('Oneida County', a.ucinn_ascendv2__County__c, 'County should be written');
        System.assertEquals(true, a.ucinn_ascendv2__Is_Verified__c, 'Verified status should set Is_Verified');
        System.assertEquals('ROOFTOP', a.ucinn_ascendv2__Address_Precision__c, 'Precision should be written');
        System.assertEquals('Google Geocoding API', a.ucinn_ascendv2__Verification_Source__c, 'Source should be stamped');
        System.assertNotEquals(null, a.ucinn_ascendv2__Verification_Date_Time__c, 'Timestamp should be stamped');
        System.assertEquals(43.2072, a.ucinn_ascendv2__Location__Latitude__s, 'Latitude should be written');
    }

    /**
     * Geocoding returns no DPV data. Confirming with it must not wipe DPV values that a
     * CASS-certified provider previously stamped.
     */
    @IsTest
    static void testConfirmDoesNotEraseExistingDpvData() {
        Id addrId = addressId();
        update new ucinn_ascendv2__Address__c(
            Id = addrId,
            ucinn_ascendv2__DPV_Match_Code__c = 'Y',
            ucinn_ascendv2__DPV_Vacant__c = 'N'
        );

        HamGoogleAddressResult v = new HamGoogleAddressResult();
        v.addressLine1 = '507 Roberts St';
        v.city = 'Rome';
        v.state = 'NY';
        v.postalCode = '13440-5273';
        v.country = 'United States';
        v.verificationStatus = 'Verified';
        v.verificationSource = 'Google Geocoding API';
        v.dpvMatchCode = null;
        v.dpvVacant = null;

        Test.startTest();
        HamGoogleAddressVerifyController.applyConfirmation(addrId, v);
        Test.stopTest();

        ucinn_ascendv2__Address__c a = [
            SELECT ucinn_ascendv2__DPV_Match_Code__c, ucinn_ascendv2__DPV_Vacant__c
            FROM ucinn_ascendv2__Address__c WHERE Id = :addrId
        ];
        System.assertEquals('Y', a.ucinn_ascendv2__DPV_Match_Code__c, 'Existing DPV match code must be preserved');
        System.assertEquals('N', a.ucinn_ascendv2__DPV_Vacant__c, 'Existing DPV vacancy flag must be preserved');
    }

    @IsTest
    static void testConfirmPartialDoesNotSetIsVerified() {
        Id addrId = addressId();

        HamGoogleAddressResult v = new HamGoogleAddressResult();
        v.addressLine1 = '507 Roberts St';
        v.verificationStatus = 'Partial';
        v.verificationSource = 'Google Geocoding API';
        v.unitConfirmed = false;

        Test.startTest();
        HamGoogleAddressVerifyController.applyConfirmation(addrId, v);
        Test.stopTest();

        ucinn_ascendv2__Address__c a = [
            SELECT ucinn_ascendv2__Is_Verified__c, ucinn_ascendv2__Verification_Status__c
            FROM ucinn_ascendv2__Address__c WHERE Id = :addrId
        ];
        System.assertEquals(false, a.ucinn_ascendv2__Is_Verified__c, 'Partial must not flag the address as verified');
        System.assertEquals('Partial', a.ucinn_ascendv2__Verification_Status__c, 'Status should record Partial');
    }

    /**
     * Exercises the real @AuraEnabled entry point the LWC calls, with the JSON payload
     * shape the browser actually sends. Guards the client/server contract.
     */
    @IsTest
    static void testConfirmAddressViaJsonPayloadWritesFields() {
        Id addrId = addressId();
        String payload = '{'
            + '"addressLine1":"1 Oliver St","addressLine2":null,"city":"Worcester","state":"MA",'
            + '"county":"Worcester County","postalCode":"01603-3051","country":"United States",'
            + '"countryIsoCode":"US","dpvMatchCode":null,"dpvVacant":null,'
            + '"verificationStatus":"Verified","addressPrecision":"ROOFTOP",'
            + '"verificationSource":"Google Geocoding API","latitude":42.2503,"longitude":-71.827,'
            + '"unitConfirmed":true,"statusNote":null}';

        Test.startTest();
        HamGoogleAddressVerifyController.confirmAddress(addrId, payload);
        Test.stopTest();

        ucinn_ascendv2__Address__c a = [
            SELECT ucinn_ascendv2__Address_Line_1__c, ucinn_ascendv2__City__c, ucinn_ascendv2__State__c,
                   ucinn_ascendv2__County__c, ucinn_ascendv2__Postal_Code__c,
                   ucinn_ascendv2__Country_ISO_Code__c, ucinn_ascendv2__Is_Verified__c,
                   ucinn_ascendv2__Verification_Status__c, ucinn_ascendv2__Address_Precision__c,
                   ucinn_ascendv2__Location__Latitude__s, ucinn_ascendv2__Location__Longitude__s
            FROM ucinn_ascendv2__Address__c WHERE Id = :addrId
        ];

        System.assertEquals('1 Oliver St', a.ucinn_ascendv2__Address_Line_1__c, 'Line 1 should be written from the JSON payload');
        System.assertEquals('Worcester', a.ucinn_ascendv2__City__c, 'City should be written');
        System.assertEquals('MA', a.ucinn_ascendv2__State__c, 'State should be written');
        System.assertEquals('Worcester County', a.ucinn_ascendv2__County__c, 'County should be written');
        System.assertEquals('01603-3051', a.ucinn_ascendv2__Postal_Code__c, 'ZIP+4 should be written');
        System.assertEquals('US', a.ucinn_ascendv2__Country_ISO_Code__c, 'ISO code should be written');
        System.assertEquals('ROOFTOP', a.ucinn_ascendv2__Address_Precision__c, 'Precision should be written');
        System.assertEquals('Verified', a.ucinn_ascendv2__Verification_Status__c, 'Status should be written');
        System.assertEquals(true, a.ucinn_ascendv2__Is_Verified__c, 'Is_Verified should be set for a Verified result');
        System.assertEquals(42.2503, a.ucinn_ascendv2__Location__Latitude__s, 'Latitude should be written');
        System.assertEquals(-71.827, a.ucinn_ascendv2__Location__Longitude__s, 'Longitude should be written');
    }

    /** The audit fields must be populated, and must never persist the API key. */
    @IsTest
    static void testAuditTrailIsCapturedAndKeyRedacted() {
        Test.setMock(HttpCalloutMock.class, new GeocodeMock());
        Id addrId = addressId();

        Test.startTest();
        List<HamGoogleAddressResult> rs = HamGoogleAddressVerifyController.verifyAddress(addrId);
        HamGoogleAddressVerifyController.applyConfirmation(addrId, rs[0]);
        Test.stopTest();

        ucinn_ascendv2__Address__c a = [
            SELECT ucinn_ascendv2__Address_Verification_API_Request__c,
                   ucinn_ascendv2__Address_Verification_API_Response__c,
                   ucinn_ascendv2__Verification_Response__c
            FROM ucinn_ascendv2__Address__c WHERE Id = :addrId
        ];

        System.assertNotEquals(null, a.ucinn_ascendv2__Address_Verification_API_Request__c, 'The request should be stored');
        System.assertNotEquals(null, a.ucinn_ascendv2__Address_Verification_API_Response__c, 'The raw response should be stored');
        System.assertNotEquals(null, a.ucinn_ascendv2__Verification_Response__c, 'A short verdict should be stored');
        System.assertEquals(true, a.ucinn_ascendv2__Address_Verification_API_Request__c.contains('key=REDACTED'),
            'The API key MUST be redacted before being written to a record');
        System.assertEquals(false, a.ucinn_ascendv2__Address_Verification_API_Request__c.contains('AIza'),
            'No Google API key prefix may appear in stored data');
        System.assertEquals(true, a.ucinn_ascendv2__Verification_Response__c.length() <= 255,
            'Verification_Response__c must respect its 255 char limit');
    }

    /**
     * ZIP+4 from a CASS-certified source outranks Google's best-effort suffix, so an
     * existing +4 must survive a Geocoding confirm when the 5-digit base is unchanged.
     */
    @IsTest
    static void testExistingZipPlus4IsNotDowngraded() {
        System.assertEquals(null, HamGoogleAddressVerifyController.resolvePostalCode('01603-3051', '01603-2711'),
            'Same 5-digit base: the existing CASS +4 must be preserved (null = do not write)');
        System.assertEquals('01603-2711', HamGoogleAddressVerifyController.resolvePostalCode('01603', '01603-2711'),
            'No existing +4: adopt the provider value');
        System.assertEquals('02138-1234', HamGoogleAddressVerifyController.resolvePostalCode('01603-3051', '02138-1234'),
            'Different base ZIP means the address genuinely moved: adopt the provider value');
        System.assertEquals('01603-2711', HamGoogleAddressVerifyController.resolvePostalCode(null, '01603-2711'),
            'Blank existing: adopt the provider value');
        System.assertEquals(null, HamGoogleAddressVerifyController.resolvePostalCode('01603-3051', null),
            'Nothing incoming: leave the field alone');
    }

    @IsTest
    static void testConfirmPreservesCassZipPlus4EndToEnd() {
        Id addrId = addressId();
        update new ucinn_ascendv2__Address__c(Id = addrId, ucinn_ascendv2__Postal_Code__c = '01603-3051');

        HamGoogleAddressResult v = new HamGoogleAddressResult();
        v.addressLine1 = '1 Oliver St';
        v.postalCode = '01603-2711';
        v.verificationStatus = 'Verified';
        v.verificationSource = 'Google Geocoding API';

        Test.startTest();
        HamGoogleAddressVerifyController.applyConfirmation(addrId, v);
        Test.stopTest();

        ucinn_ascendv2__Address__c a = [
            SELECT ucinn_ascendv2__Postal_Code__c FROM ucinn_ascendv2__Address__c WHERE Id = :addrId
        ];
        System.assertEquals('01603-3051', a.ucinn_ascendv2__Postal_Code__c,
            'The CASS ZIP+4 must not be replaced by Google\'s suffix');
    }

    /**
     * Data_Source__c is a RESTRICTED picklist, and whether "Google Geocoding API" has been
     * added to it is per-org admin configuration. These tests therefore assert the GUARD's
     * behaviour, not the org's picklist contents - otherwise they pass only in an org where
     * someone happened to add the value, and block every deployment elsewhere.
     */
    @IsTest
    static void testDataSourceIsStampedOnlyWhenPicklistValueExists() {
        Id addrId = addressId();
        Boolean valueExists = HamGoogleAddressVerifyController.isValidDataSource('Google Geocoding API');

        HamGoogleAddressResult v = new HamGoogleAddressResult();
        v.addressLine1 = '1 Oliver St';
        v.verificationStatus = 'Verified';
        v.verificationSource = 'Google Geocoding API';

        Test.startTest();
        HamGoogleAddressVerifyController.applyConfirmation(addrId, v);
        Test.stopTest();

        ucinn_ascendv2__Address__c a = [
            SELECT ucinn_ascendv2__Data_Source__c, ucinn_ascendv2__Verification_Source__c
            FROM ucinn_ascendv2__Address__c WHERE Id = :addrId
        ];

        if (valueExists) {
            System.assertEquals('Google Geocoding API', a.ucinn_ascendv2__Data_Source__c,
                'When the picklist value exists it must be stamped');
        } else {
            System.assertEquals(null, a.ucinn_ascendv2__Data_Source__c,
                'When the picklist value is missing it must be skipped, not written');
        }

        // Either way the confirm itself must succeed and stamp the non-picklist source field.
        System.assertEquals('Google Geocoding API', a.ucinn_ascendv2__Verification_Source__c,
            'A missing Data_Source__c picklist value must never break the confirm');
    }

    @IsTest
    static void testUnknownDataSourceIsSkippedNotThrown() {
        System.assertEquals(false, HamGoogleAddressVerifyController.isValidDataSource('Not A Real Source'),
            'An unlisted value must be reported invalid so it is skipped rather than throwing');
        System.assertEquals(false, HamGoogleAddressVerifyController.isValidDataSource(null),
            'Null must be treated as invalid');
        System.assertEquals(false, HamGoogleAddressVerifyController.isValidDataSource(''),
            'Blank must be treated as invalid');
    }

    /**
     * The stored response must be the provider's own response, unaltered apart from
     * having Google's pretty-print padding removed.
     */
    @IsTest
    static void testStoredApiResponseIsOriginalJustCompacted() {
        Test.setMock(HttpCalloutMock.class, new GeocodeMock());

        Test.startTest();
        List<HamGoogleAddressResult> rs = HamGoogleAddressVerifyController.verifyAddress(addressId());
        Test.stopTest();

        String stored = rs[0].apiResponse;
        System.assertNotEquals(null, stored, 'An audit response should be captured');

        // Still the original JSON, not a reformatted outline
        System.assertEquals(true, stored.startsWith('{'), 'Should still be the JSON response: ' + stored.left(60));
        System.assertEquals(false, stored.contains('\n'), 'Pretty-print padding should be stripped');

        // Every field of the original response survives
        System.assertEquals(true, stored.contains('"status":"OK"'), 'Top-level status kept');
        System.assertEquals(true, stored.contains('results'), 'The results array is kept');
        System.assertEquals(true, stored.contains('formatted_address'), 'formatted_address kept');
        System.assertEquals(true, stored.contains('location_type'), 'geometry.location_type kept');
        System.assertEquals(true, stored.contains('place_id'), 'place_id kept');
        System.assertEquals(true, stored.contains('postal_code_suffix'), 'ZIP+4 suffix kept');
        System.assertEquals(true, stored.contains('Oneida County'), 'County component kept');
    }

    /** Every row keeps the complete response, including the alternative candidates. */
    @IsTest
    static void testStoredApiResponseKeepsAllCandidates() {
        Test.setMock(HttpCalloutMock.class,
            new GeocodeMock(GeoScenario.MULTIPLE_CANDIDATES));

        Test.startTest();
        List<HamGoogleAddressResult> rs = HamGoogleAddressVerifyController.verifyAddress(addressId());
        Test.stopTest();

        System.assertEquals(2, rs.size(), 'Two candidates expected');
        for (HamGoogleAddressResult r : rs) {
            System.assertEquals(true, r.apiResponse.contains('Roberts St'), 'Candidate 1 data present');
            System.assertEquals(true, r.apiResponse.contains('Roberts Rd'),
                'The full original response is stored, so the alternative candidate is present too');
        }
    }

    /**
     * A DML failure (most often Ascend's duplicate-address validation firing after Google
     * standardises the street) must surface the platform's reason, not a generic
     * "please try again" - retrying cannot fix a validation rule.
     */
    @IsTest
    static void testDmlFailureSurfacesUnderlyingReason() {
        Id addrId = addressId();

        HamGoogleAddressResult v = new HamGoogleAddressResult();
        v.addressLine1 = '198 College Hill Rd';
        v.verificationStatus = 'Verified';
        v.verificationSource = 'Google Geocoding API';
        // Postal_Code__c is 25 chars; an over-long value forces a real DmlException.
        v.postalCode = '1'.repeat(60);

        String msg;
        Test.startTest();
        try {
            HamGoogleAddressVerifyController.applyConfirmation(addrId, v);
        } catch (AuraHandledException ahe) {
            msg = ahe.getMessage();
        }
        Test.stopTest();

        System.assertNotEquals(null, msg, 'A DML failure must raise an AuraHandledException');
        System.assertEquals(false, msg.contains('Please try again'),
            'The generic retry message must not be used for a DML failure: ' + msg);
        System.assertEquals(true, msg.startsWith('Could not save:'),
            'The platform reason should be surfaced to the user: ' + msg);
    }

    @IsTest
    static void testConfirmBlankJsonIsRejected() {
        Boolean caught = false;
        Test.startTest();
        try {
            HamGoogleAddressVerifyController.confirmAddress(addressId(), '');
        } catch (AuraHandledException ahe) {
            caught = true;
        }
        Test.stopTest();
        System.assertEquals(true, caught, 'A blank payload must be rejected rather than half-writing');
    }

    @IsTest
    static void testConfirmNullResultIsRejected() {
        Boolean caught = false;
        Test.startTest();
        try {
            HamGoogleAddressVerifyController.applyConfirmation(addressId(), null);
        } catch (AuraHandledException ahe) {
            caught = true;
        }
        Test.stopTest();
        System.assertEquals(true, caught, 'Confirming with no result should be rejected');
    }

    // ── Callout error handling ────────────────────────────────────────────────────

    /** A non-200 from Google must surface as a clean AuraHandledException, not a stack trace. */
    @IsTest
    static void testCalloutErrorSurfacesCleanMessage() {
        Test.setMock(HttpCalloutMock.class, new HttpErrorMock());

        Boolean caught = false;
        Test.startTest();
        try {
            HamGoogleAddressVerifyController.verifyAddress(addressId());
        } catch (AuraHandledException ahe) {
            caught = true;
        }
        Test.stopTest();

        System.assertEquals(true, caught, 'A non-200 response should surface as an AuraHandledException');
    }

    private class HttpErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(403);
            res.setBody('{"error":{"code":403,"message":"API key not valid","status":"PERMISSION_DENIED"}}');
            return res;
        }
    }

    // ── Geocoding mock (inlined; was HamGoogleAddressGeocodeCalloutMock) ───────────
    // The enum sits here rather than inside GeocodeMock: Apex permits only one level
    // of nesting, so an enum inside an inner class will not compile.
    private enum GeoScenario {
        ROOFTOP_WITH_UNIT,
        ROOFTOP_UNIT_DROPPED,
        APPROXIMATE_PARTIAL,
        ZERO_RESULTS,
        MULTIPLE_CANDIDATES
    }

    private class GeocodeMock implements HttpCalloutMock {
    

    private GeoScenario mockGeoScenario;

    public GeocodeMock() {
        this.mockGeoScenario = GeoScenario.ROOFTOP_WITH_UNIT;
    }

    public GeocodeMock(GeoScenario requested) {
        this.mockGeoScenario = requested;
    }

    public HttpResponse respond(HttpRequest req) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setStatusCode(200);
        res.setBody(bodyFor(this.mockGeoScenario));
        return res;
    }

    private String bodyFor(GeoScenario s) {
        if (s == GeoScenario.ZERO_RESULTS) {
            return '{"results":[],"status":"ZERO_RESULTS"}';
        }
        if (s == GeoScenario.APPROXIMATE_PARTIAL) {
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

        if (s == GeoScenario.MULTIPLE_CANDIDATES) {
            return '{"results":[' + candidate('507', 'Roberts St', '13440') + ','
                + candidate('507', 'Roberts Rd', '13441') + '],"status":"OK"}';
        }

        String subpremise = (s == GeoScenario.ROOFTOP_WITH_UNIT)
            ? '{"long_name":"4","short_name":"4","types":["subpremise"]},'
            : '';
        String types = (s == GeoScenario.ROOFTOP_WITH_UNIT)
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

}