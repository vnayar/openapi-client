// import vibe.http.client : requestHTTP, HTTPClientRequest, HTTPClientResponse;
// import vibe.data.json : Json;
// import vibe.inet.url : URL;
// import vibe.http.common : HTTPMethod, httpMethodFromString;
// import vibe.stream.operations : readAllUTF8;
// import vibe.textfilter.urlencode : urlEncode;

// import std.algorithm : map;
// import std.array : appender, split, Appender, byPair, join;

// import stripe.servers : Servers;
// import openapi_client.util : resolveTemplate;

// /**
//  * Utility class to create HTTPClientRequests to access the REST API.
//  */
// class ApiRequest {
//   string method;

//   /**
//    * The base-part of the URL including the schema, host, and base path.
//    */
//   string serverUrl;

//   /**
//    * The path for the specific endpoint. It may include named parameters contained within curley
//    * braces, e.g. "{param}".
//    */
//   string pathUrl;

//   string[string] pathParams;
//   string[string] queryParams;
//   string[string] headerParams;

//   string contentType;
//   string requestBody;

//   this(string method, string severUrl, string pathUrl) {
//     this.method = method;
//     this.serverUrl = serverUrl;
//     this.pathUrl = pathUrl;
//   }

//   void setHeaderParam(string key, string value) {
//     // Headers can contain ASCII characters.
//     headerParams[key] = value;
//   }

//   void setPathParam(string key, string value) {
//     // Path parameters must be URL encoded.
//     pathParams[key] = urlEncode(value);
//   }

//   void setQueryParam(string key, string value) {
//     // Path parameters must be URL encoded.
//     queryParams[key] = urlEncode(value);
//   }

//   string getUrl() {
//     URL url = URL(serverUrl);
//     url.path ~= resolveTemplate(pathUrl, pathParams);
//     url.queryString = queryParams.byKeyValue()
//         .map!(pair => pair.key ~ "=" ~ pair.value)
//         .join("&");
//     return Servers.getServerUrl();
//   }

//   void makeRequest(T)(T reqBody) {
//     requestHTTP(
//         getUrl(),
//         (scope HTTPClientRequest req) {
//           req.method = httpMethodFromString(method);
//           foreach (pair; headerParams.byKeyValue()) {
//             req.headers[pair.key] = pair.value;
//           }
//           if (reqBody !is null) {
//             req.writeJsonBody(reqBody);
//           }
//         },
//         (scope HTTPClientResponse res) {
//         });
//   }
// }

// class MyApi {
//   void getCharges() {
//     ApiRequest apiRequest;
//     //apiRequest.url = URL("https://api.stripe.com/");
//     //apiRequest.url.path ~= "/v1/charges";

//     requestHTTP(
//         apiRequest.getUrl(),
//         (scope HTTPClientRequest req) {
//           req.method = HTTPMethod.GET;
//         },
//         (scope HTTPClientResponse res) {
//         });
//   }
// }

// unittest {
// }
