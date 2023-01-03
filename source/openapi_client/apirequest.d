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
import std.stdio : writeln;
import std.conv : to;

import openapi_client.util : resolveTemplate;
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
    headerParams[key] = value;
  }

  /**
   * URL-encode a value to add as a path parameter.
   */
  void setPathParam(string key, string value) {
    // Path parameters must be URL encoded.
    pathParams[key] = urlEncode(value);
  }

  /**
   * URL-encode a value to add as a query-string parameter.
   */
  void setQueryParam(string key, string value) {
    // Path parameters must be URL encoded.
    queryParams[key] = urlEncode(value);
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
    logDebug("makeRequest 0: url=%s", url);
    requestHTTP(
        url,
        (scope HTTPClientRequest req) {
          req.method = method;
          foreach (pair; headerParams.byKeyValue()) {
            logDebug("Adding header: %s: %s", pair.key, pair.value);
            req.headers[pair.key] = pair.value;
          }
          if (reqBody !is null) {
            // TODO: Support additional content-types.
            if (req.contentType == "application/x-www-form-urlencoded") {
              // TODO: Only perform deepObject encoding if the OpenAPI Spec calls for it.
              auto formFields = serializeDeepObject(reqBody);
              logDebug("Writing Form Body: ", formFields.toString);
              req.writeFormBody(formFields.byKeyValue());
            } else if (req.contentType == "application/json") {
              req.writeJsonBody(reqBody);
            } else {
              logError("Unsupported request body format: %s", req.contentType);
            }
          }
        },
        (scope HTTPClientResponse res) {
          logDebug("makeRequest 1: handler=%s", handler);
          if (handler !is null)
            handler.handleResponse(res);
        });
  }

  /**
   * Serialize an object according to DeepObject style.
   *
   * See_Also: https://swagger.io/docs/specification/serialization/
   */
  static FormFields serializeDeepObject(T)(T obj) {
    Json json = serializeToJson(obj);
    FormFields fields;
    serializeDeepObject(json, "", fields);
    return fields;
  }

  /// ditto
  static void serializeDeepObject(Json json, string keyPrefix, ref FormFields fields) {
    if (json.type == Json.Type.array) {
      foreach (size_t index, Json value; json.byIndexValue) {
        serializeDeepObject(value, keyPrefix ~ "[" ~ index.to!string ~ "]", fields);
      }
    } else if (json.type == Json.Type.object) {
      foreach (string key, Json value; json.byKeyValue ) {
        serializeDeepObject(value, keyPrefix == "" ? key : keyPrefix ~ "[" ~ key ~ "]", fields);
      }
    } else if (json.type != Json.Type.null_) {
      // Finally we have an actual value.
      fields.addField(keyPrefix, json.to!string);
    }
  }
}
