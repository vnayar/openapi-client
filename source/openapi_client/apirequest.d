/**
 * Utilities needed to gather information for and execute an HTTP request.
 */
module openapi_client.apirequest;

import vibe.core.log : logDebug, logError;
import vibe.data.json : Json, deserializeJson, serializeToJson;
import vibe.http.client : requestHTTP, HTTPClientRequest, HTTPClientResponse;
import vibe.http.common : HTTPMethod, httpMethodFromString;
import vibe.http.status : isSuccessCode;
import vibe.inet.url : URL;
import vibe.inet.webform : FormFields;
import vibe.textfilter.urlencode : urlEncode;

import std.algorithm : map;
import std.array : join;
import std.conv : to;
import std.typecons : Nullable;

import openapi_client.util : resolveTemplate, serializeDeepObject;
import openapi_client.handler : ResponseHandler;

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

  /**
   * A mapping from path-parameter names to their values.
   */
  string[string] pathParams;

  /**
   * A mapping from query-string parameter names to their values.
   */
  string[string] queryParams;

  /**
   * A mapping from header parameter names to their values.
   */
  string[string] headerParams;

  /**
   * Constructs a new ApiRequest.
   *
   * Params:
   *   method = The HTTP method of the request.
   *   serverUrl = The base-URL of the server that offers the API.
   *   pathUrl = The endpoint-specific path to add to the request.
   */
  this(HTTPMethod method, string serverUrl, string pathUrl) {
    this.method = method;
    this.serverUrl = serverUrl;
    this.pathUrl = pathUrl;

    logDebug("Creating ApiRequest: method=%s, serverUrl=%s, pathUrl=%s", method, serverUrl, pathUrl);
  }

  /**
   * Adds a header parameter and value to the request.
   */
  void setHeaderParam(string key, string value) {
    // Headers can contain ASCII characters.
    logDebug("setHeaderParam(string,string): key=%s, value=%s", key, value);
    headerParams[key] = value;
  }

  /// ditto
  void setHeaderParam(T)(string key, Nullable!T value) {
    setHeaderParam(key, value.get);
  }

  /**
   * URL-encode a value to add as a path parameter.
   */
  void setPathParam(string key, string value) {
    // Path parameters must be URL encoded.
    pathParams[key] = urlEncode(value);
  }

  /// ditto
  void setPathParam(T)(string key, T value) {
    setPathParam(key, value.to!string);
  }

  /// ditto
  void setPathParam(T : Nullable!T)(string key, Nullable!T value) {
    setPathParam(key, value.get);
  }

  /**
   * URL-encode a value to add as a query-string parameter.
   */
  void setQueryParam(string key, string value) {
    // Path parameters must be URL encoded.
    queryParams[key] = urlEncode(value);
  }

  /// ditto
  void setQueryParam(string mode : "deepObject", T : Nullable!T)(string key, T value) {
    setQueryParam!("deepObject")(key, value.get);
  }

  // TODO: Add more encoding mechanisms.
  /// ditto
  void setQueryParam(string mode : "deepObject", T)(string keyPrefix, T obj) {
    FormFields fields;
    serializeDeepObject(serializeToJson(obj), keyPrefix, fields);
    foreach (string key, string value; fields.byKeyValue()) {
      setQueryParam(key, value);
    }
  }

  /**
   * Return the URL of an API Request, resolving any path and query-string parameters.
   */
  string getUrl() {
    URL url = URL(serverUrl);
    url.path = url.path ~ resolveTemplate(pathUrl[1..$], pathParams);
    url.queryString = queryParams.byKeyValue()
        .map!(pair => pair.key ~ "=" ~ pair.value)
        .join("&");
    return url.toString();
  }

  /**
   * Asynchronously perform the network request for an API Request, resolving cookie and header
   * parameters, and transmitting the request body.
   */
  void makeRequest(RequestT)(RequestT reqBody, ResponseHandler handler) {
    string url = getUrl();
    logDebug("makeRequest 0: url=%s, reqBody=%s", url, serializeToJson(reqBody));
    requestHTTP(
        url,
        (scope HTTPClientRequest req) {
          req.method = method;
          foreach (pair; headerParams.byKeyValue()) {
            logDebug("makeRequest 1: Adding header  %s: %s", pair.key, pair.value);
            req.headers[pair.key] = pair.value;
          }
          if (reqBody !is null) {
            // TODO: Support additional content-types.
            if (req.contentType == "application/x-www-form-urlencoded") {
              // TODO: Only perform deepObject encoding if the OpenAPI Spec calls for it.
              auto formFields = serializeDeepObject(reqBody);
              logDebug("Writing Form Body: %s", formFields.toString);
              req.writeFormBody(formFields.byKeyValue());
            } else if (req.contentType == "application/json") {
              req.writeJsonBody(reqBody);
            } else {
              logError("Unsupported request body format: %s", req.contentType);
            }
          }
        },
        (scope HTTPClientResponse res) {
          logDebug("makeRequest 2: handler=%s", handler);
          if (handler !is null)
            handler.handleResponse(res);
        });
  }

}
