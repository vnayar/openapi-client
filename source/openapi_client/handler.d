/**
 * Interfaces and utilities common to response handlers for any API Endpoint.
 */
module openapi_client.handler;

import vibe.http.client : HTTPClientResponse;

/**
 * An object capable of processing an HTTPClientResponse of an HTTPClientRequest.
 */
interface ResponseHandler {
  /**
   * The primary responsibility of this method is to determine the response body type from the HTTP
   * status code and OpenAPI specification, deserialize the HTTP Response Body into the appropriate
   * type, and call a user-provided method with the deserialized response body.
   */
  void handleResponse(HTTPClientResponse res);
}
