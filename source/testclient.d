import vibe.http.client : requestHTTP, HTTPClientRequest, HTTPClientResponse;
import vibe.inet.url : URL;
import vibe.http.common : HTTPMethod;
import vibe.stream.operations : readAllUTF8;

import std.array : appender, split, Appender;

class ApiRequest {
  /**
   * The base-part of the URL including the schema, host, and base path. It may include named
   * parameters contained within curley braces, e.g. "{param}".
   */
  string serverUrl;
  string pathUrl;
  string[string] pathParams;
  string[string] queryParams;
  string[string] headerParams;
  string contentType;
  string requestBody;

  string getUrl() {
    return "ham";
  }
}

class MyApi {
  void getCharges() {
    ApiRequest apiRequest;
    //apiRequest.url = URL("https://api.stripe.com/");
    //apiRequest.url.path ~= "/v1/charges";

    requestHTTP(
        apiRequest.getUrl(),
        (scope HTTPClientRequest req) {
          req.method = HTTPMethod.GET;
        },
        (scope HTTPClientResponse res) {
        });
  }
}

unittest {
}
