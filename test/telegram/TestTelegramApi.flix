use Util.Json.{JObject, JNumber, JString}
use TelegramApi.{extractId, getLatestUpdateIdFun}
use Assert.{assertEq, assertErr}
use Net.Https


@Test
def testExecuteHttpRequestAndGetLatestUpdateId(): Unit \ Assert =
    run {
        let result = getLatestUpdateIdFun("dummy_token", None);
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
