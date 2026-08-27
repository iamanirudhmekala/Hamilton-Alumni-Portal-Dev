/**
 * Typed wrapper for the Google Geocoding API response.
 *
 * Deliberately separate from the existing shared GeocodeResponse class, which is used by
 * MapFinderController and HamItineraryController and does not expose location_type or
 * partial_match. Those two fields are what let us tell a real rooftop match apart from a
 * silently-degraded guess, so address verification needs them.
 *
 * Property names match Google's snake_case JSON exactly so a plain JSON.deserialize works.
 */
public class HamGoogleAddressGeocodeResponse {
    public String status { get; set; }
    public String error_message { get; set; }
    public List<GeoResult> results { get; set; }

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

    public static HamGoogleAddressGeocodeResponse parse(String jsonStr) {
        return (HamGoogleAddressGeocodeResponse) JSON.deserialize(jsonStr, HamGoogleAddressGeocodeResponse.class);
    }

    /**
     * @return the component whose types contain the given type, or null.
     */
    public static Component findComponent(GeoResult res, String componentType) {
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
}