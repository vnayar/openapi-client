# OpenAPI Client

The purpose of this tool is to generate client libraries that are compatible with the REST API of a
service, whose interface is described via an OpenAPI/Swagger specification document.

The format of OpenAPI specifications can be found here:
https://swagger.io/specification/

Initially, this library was developed in order to support the generation of a client for the Stripe
API, however, it is intended to be a general tool usable for all OpenAPI specifications.

## Current Features

1. An executable that, when given an OpenAPI3 JSON specification file, writes a client in D.
2. Generation of D classes under the "model" subpackage representing OpenAPI3 `components/schemas`.
3. Generation of D classes under the "service" subpackage representing OpenAPI3 `paths`.
   1. Generation of inline inner static classs for request parameters in HTTP headers, the Query
      String, or Path templates.
   2. Generation of inline inner static classes for response bodies.
   3. Generation of a "ResponseHandler" class permitting callers to receive typed responses per HTTP
      status code defined in the OpenAPI3 specification.

## Compilation

This project is written in the D programming language using the standard build tool
[dub](https://code.dlang.org/).

The binary executable can be built using the command:
> dub build

The executable will be located in `target/openapi-client`.

## Command-Line Usage

The program `openapi-client` takes as input an [OpenAPI
specification](https://swagger.io/specification/) in JSON format and generates D code that can be
used as part of a project.

The following command-line options are supported:
- **--targetDir** = The base directory in which files should be generated, e.g. the "source" directory.
- **--packageRoot** = The root package in which to generate files, e.g. "myapi.modules".
- **--openApiSpec** = The OpenAPI specification to read in order to generate a client, e.g. the [Stripe
  OpenAPI specification](https://github.com/stripe/openapi/blob/master/openapi/spec3.json).

Alternatively, the executable can be run directly using dub, e.g.:
> dub run openapi-client -- --targetDir=source --openApiSpec=json/spec3.json --packageRoot=stripe

## Project Usage

Typically the `openapi-client` program is invoked to generate source for a project. However, because
the OpenAPI specification does not frequently change, it is helpful to only regenerate this source
conditionally.

For example, the following snippet can be added to your D project's
[dub.sdl](https://dub.pm/package-format-sdl) file to only generate the client source code when the
`dub build --config=generate` command is run:
> # To re-create the Stripe API source files (e.g. when the OpenAPI spec changes, run the
> # command: dub build --config=generate
> configuration "generate" {
>   preGenerateCommands "dub run openapi-client -- --targetDir=source --openApiSpec=json/spec3.json --packageRoot=stripe"
> }

## Generated Client Usage

The following code snippet makes use of the client library generated from the Stripe OpenAPI specification.

``` d
import stripe.security : Security;
import stripe.service.v1_charges_service : V1ChargesService;
import vibe.data.json : serializeToJsonString;

// Stripe's OpenAPI specification has two valid security schemes:
//   - HTTP Basic Auth (named "BasicAuth")
//   - HTTP Bearer Auth (named "BearerAuth")
Security.configureBasicAuth(
    "sk_test_51MFbD...vri",  // Username / API key
    "");                     // With Stripe, the password is always blank.

// Service classes are created from valid URL paths + "Service", e.g. "/v1/charges" => "V1ChargesService".
auto service = new V1ChargesService();

// Each endpoint has a "Params" object which covers any path, query-string, header, or cookie parameters.
auto params = new V1ChargesService.GetChargesParams();

// Some requests have a request body, which will be an argument to the method, e.g. "postCharges".

// Different HTTP status codes can be associated with different data types.
// Create a handler object and add your own delegates that say what to do with each response.
auto handler = new V1ChargesService.GetChargesResponseHandler();
// This handler is for a successful 200 response, there's also a default handler for errors.
handler.handleResponse200 = (V1ChargesService.GetChargesResponseHandler.ChargeList chargeList) {
  // Simply print out our response in JSON format.
  writeln(serializeToJsonString(chargeList));
};

// Now call the desired endpoint and your handler will be invoked depending on the response.
service.getCharges(params, handler);
```

If you are familiar with the HTTP interface of the API you intend to use, you will find that the
client matches it very closely, and that all the generated data types, classes, and parameters are
documented from within the generated code.

## Future Features

1. Improved unit test coverage.
3. Support additional request content-types, such as `application/x-www-form-urlencoded`,
   `multipart/form-data`, and `text/plain`.
4. Support additional response body content-types, such as `application/pdf` and `text/plain`.
5. Generation of client libraries in other programming langugages, e.g. C, Java, Rust, Go, etc.
6. Alternative network/JSON library generation, rather than just [Vibe.d](https://vibed.org/).
7. Generation of `union` types to reflect OpenAPI types using "anyOf" validation.
