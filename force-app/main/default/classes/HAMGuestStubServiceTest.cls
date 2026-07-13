/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : HAMGuestStubServiceTest
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

@isTest
private class HAMGuestStubServiceTest {
	 @isTest static void testGeneratesDistinctDeterministicStubs() {
        HAMGuestStubService.Request req = new HAMGuestStubService.Request();
        req.firstName = 'Jane';
        req.lastName = 'Doe';
        req.email = 'jane.doe@example.com';
        req.sourceRecordId = '001000000000001AAA';

        List<HAMGuestStubService.Response> res1 = HAMGuestStubService.generateStubs(
            new List<HAMGuestStubService.Request>{ req }
        );
        List<HAMGuestStubService.Response> res2 = HAMGuestStubService.generateStubs(
            new List<HAMGuestStubService.Request>{ req }
        );

        System.assertNotEquals(res1[0].contactStub, res1[0].attendeeStub, 'Contact and Attendee stubs should differ');
        System.assertEquals(res1[0].contactStub, res2[0].contactStub, 'Should be deterministic');
        System.assert(res1[0].contactStub.startsWith('GST-'));
    }
}