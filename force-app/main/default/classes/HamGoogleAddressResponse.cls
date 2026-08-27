public class HamGoogleAddressResponse {
    public String responseId { get; set; }
    public Result result { get; set; }

    public class Result {
        public Verdict verdict { get; set; }
        public Address address { get; set; }
        public Geocode geocode { get; set; }
        public Metadata metadata { get; set; }
        public UspsData uspsData { get; set; }
    }

    public class Verdict {
        public String inputGranularity { get; set; }
        public String validationGranularity { get; set; }
        public String geocodeGranularity { get; set; }
        public Boolean addressComplete { get; set; }
        public Boolean hasUnconfirmedComponents { get; set; }
        public Boolean hasInferredComponents { get; set; }
        public Boolean hasReplacedComponents { get; set; }
    }

    public class Address {
        public String formattedAddress { get; set; }
        public PostalAddress postalAddress { get; set; }
        public List<AddressComponent> addressComponents { get; set; }
    }

    public class PostalAddress {
        public String regionCode { get; set; }
        public String postalCode { get; set; }
        public String administrativeArea { get; set; }
        public String locality { get; set; }
        public List<String> addressLines { get; set; }
    }

    public class AddressComponent {
        public ComponentName componentName { get; set; }
        public String componentType { get; set; }
        public String confirmationLevel { get; set; }
    }

    public class ComponentName {
        public String text { get; set; }
    }

    public class Geocode {
        public Location location { get; set; }
        public String placeId { get; set; }
    }

    public class Location {
        public Double latitude { get; set; }
        public Double longitude { get; set; }
    }

    public class Metadata {
        public Boolean business { get; set; }
        public Boolean poBox { get; set; }
        public Boolean residential { get; set; }
    }

    public class UspsData {
        public StandardizedAddress standardizedAddress { get; set; }
        public String dpvConfirmation { get; set; }
        public String dpvVacant { get; set; }
        public String dpvCmra { get; set; }
        public String carrierRoute { get; set; }
    }

    public class StandardizedAddress {
        public String firstAddressLine { get; set; }
        public String secondAddressLine { get; set; }
        public String city { get; set; }
        public String state { get; set; }
        public String zipCode { get; set; }
        public String zipCodeExtension { get; set; }
    }

    public static HamGoogleAddressResponse parse(String jsonStr) {
        return (HamGoogleAddressResponse) JSON.deserialize(jsonStr, HamGoogleAddressResponse.class);
    }
}