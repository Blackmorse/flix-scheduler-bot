use Assert.assertErr
use Util.Json.JString
use Assert.assertEq
use Util.Json.JNumber
use Util.Json.JObject
use Net.Https

@Test
def testParsedUpdateId(): Unit \ Assert = 
    let json = JObject(Map#{"update_id" => JNumber(123ff)});
    assertEq(expected = Ok(123i64), extractId(json))

@Test
def testParseUpdateIdFailsOnString(): Unit \ Assert = 
    let json = JObject(Map#{"update_id" => JString("Not a number")});
    assertErr(extractId(json))

@Test
def testParseUpdateIdErrorOnMissingKey(): Unit\ Assert =
    let json = JObject(Map#{"other_key" => JNumber(11ff)});
    assertErr(extractId(json))

@Test
def testExtractUpdateIdsFromHttpResponseBody(): Unit \ Assert =
    let body = " { \"ok\": true, \"result\": [ {\"update_id\": 123}, {\"update_id\": 456}, {\"update_id\": 789} ] } ";
    assertEq(expected = Ok(List#{123i64, 456i64, 789i64}), extractUpdateIdsFromHttpResponseBody(body))

@Test
def testExecuteHttpRequestAndGetLatestUpdateId(): Unit \ Assert =
    run {
        let result = getLatestUpdateId("dummy_token");
        assertEq(expected = Ok(789i64), result)
    } with handler Https {
        def request(_, resume) = 
            let body = " { \"ok\": true, \"result\": [ {\"update_id\": 123}, {\"update_id\": 456}, {\"update_id\": 789} ] } ";
            let response = Net.HttpResponse({
                body = Net.Body.Text(body),
                headers = Map#{},
                status = 200,
                url = ""
            });
            resume(Ok(response))
    }
