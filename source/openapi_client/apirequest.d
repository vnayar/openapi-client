module openapi_client.apirequest;

import vibe.http.client : requestHTTP, HTTPClientRequest, HTTPClientResponse;
import vibe.data.json : Json, deserializeJson;
import vibe.inet.url : URL;
import vibe.http.common : HTTPMethod, httpMethodFromString;
import vibe.textfilter.urlencode : urlEncode;

import std.algorithm : map;
import std.array : join;

import openapi_client.util : resolveTemplate;

/**
 * Utility class to create HTTPClientRequests to access the REST API.
 */
class ApiRequest {
  /**
   * The HTTP Method to use for the request, e.g. "GET", "POST", "PUT", etc.
   */
  HTTPMethod method;

  /**
   * The base-part of the URL including the schema, host, and base path.
   */
  string serverUrl;

  /**
   * The path for the specific endpoint. It may include named parameters contained within curley
   * braces, e.g. "{param}".
   */
  string pathUrl;

  string[string] pathParams;
  string[string] queryParams;
  string[string] headerParams;

  string contentType;
  string requestBody;

  this(HTTPMethod method, string severUrl, string pathUrl) {
    this.method = method;
    this.serverUrl = serverUrl;
    this.pathUrl = pathUrl;
  }

  void setHeaderParam(string key, string value) {
    // Headers can contain ASCII characters.
    headerParams[key] = value;
  }

  void setPathParam(string key, string value) {
    // Path parameters must be URL encoded.
    pathParams[key] = urlEncode(value);
  }

  void setQueryParam(string key, string value) {
    // Path parameters must be URL encoded.
    queryParams[key] = urlEncode(value);
  }

  /**
   * Return the URL of an API Request, resolving any path and query-string parameters.
   */
  string getUrl() {
    URL url = URL(serverUrl);
    url.path ~= resolveTemplate(pathUrl, pathParams);
    url.queryString = queryParams.byKeyValue()
        .map!(pair => pair.key ~ "=" ~ pair.value)
        .join("&");
    return url.toString();
  }

  /**
   * Perform the network request for an API Request, resolving cookie and header parameters, and
   * transmitting the request body.
   */
  void makeRequest(ResponseT, RequestT)(RequestT reqBody, void delegate(ResponseT) responseCb) {
    requestHTTP(
        getUrl(),
        (scope HTTPClientRequest req) {
          req.method = method;
          foreach (pair; headerParams.byKeyValue()) {
            req.headers[pair.key] = pair.value;
          }
          if (reqBody !is null) {
            req.writeJsonBody(reqBody);
          }
        },
        (scope HTTPClientResponse res) {
          responseCb(deserializeJson!ResponseT(res.readJson()));
        });
  }
}
