/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : HAMGuestStubService
 * Author          : <YourName>
 * Created Date    : Jul 8, 2026
 * Last Modified By: <YourName>
 * Last Modified On: Jul 8, 2026
 * Description     : This class implements for......
 *  
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Jul 8, 2026  │ <YourName>   │ Initial version
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */

public class HAMGuestStubService {

	public class Request {
        @InvocableVariable(required=true) public String firstName;
        @InvocableVariable(required=true) public String lastName;
        @InvocableVariable(required=true) public String email;
        @InvocableVariable(required=true) public String sourceRecordId; // triggering Attendee Id
    }

    public class Response {
        @InvocableVariable public String contactStub;
        @InvocableVariable public String attendeeStub;
    }

    @InvocableMethod(
        label='Generate Guest Stub Values'
        description='Generates unique, deterministic Contact/Attendee stub values for Cvent guest records, distinct in format from native Cvent auto-numbered stubs.'
    )
    public static List<Response> generateStubs(List<Request> requests) {
        List<Response> responses = new List<Response>();
        for (Request req : requests) {
            Response resp = new Response();
            resp.contactStub = buildStub(req, 'CON');
            resp.attendeeStub = buildStub(req, 'ATT');
            responses.add(resp);
        }
        return responses;
    }

    private static String buildStub(Request req, String salt) {
        String seed = salt + '|'
            + (req.sourceRecordId == null ? '' : req.sourceRecordId)
            + '|' + normalize(req.firstName)
            + '|' + normalize(req.lastName)
            + '|' + normalize(req.email);

        Blob hashed = Crypto.generateDigest('MD5', Blob.valueOf(seed));
        String hex = EncodingUtil.convertToHex(hashed); // 32 hex chars

        // 'GST-' + 30 hex chars = 34 chars, safely under the 36-char field limit
        return 'GST-' + hex.substring(0, 30).toUpperCase();
    }

    private static String normalize(String val) {
        return val == null ? '' : val.trim().toLowerCase();
    }
}