module openapi;

import vibe.data.json : Json;
import vibe.data.serialization : jsonName = name, jsonOptional = optional;

/**
 * The OpenAPI Specification (OAS) defines a standard, language-agnostic interface to RESTful APIs
 * which allows both humans and computers to discover and understand the capabilities of the service
 * without access to source code, documentation, or through network traffic inspection. When
 * properly defined, a consumer can understand and interact with the remote service with a minimal
 * amount of implementation logic.
 *
 * An OpenAPI definition can then be used by documentation generation tools to display the API, code
 * generation tools to generate servers and clients in various programming languages, testing
 * tools, and many other use cases.
 *
 * See: https://swagger.io/specification/
 */
class OasDocument {
  /**
   * **REQUIRED**. This string MUST be the semantic version number of the OpenAPI Specification
   * version that the OpenAPI document uses. The openapi field SHOULD be used by tooling
   * specifications and clients to interpret the OpenAPI document. This is not related to the API
   * info.version string.
   */
  string openapi;

  OasInfo info;

  @jsonOptional
  OasServer[] servers;

  /**
   * **REQUIRED**. The available paths and operations for the API.
   *
   * The key is a relative path to an individual endpoint. The key MUST begin with a forward slash
   * (/). The path is appended (no relative URL resolution) to the expanded URL from the [OasServer]
   * object's url field in order to construct the full URL. Path templating is allowed. When
   * matching URLs, concrete (non-templated) paths would be matched before their templated
   * counterparts. Templated paths with the same hierarchy but different templated names MUST NOT
   * exist as they are identical. In case of ambiguous matching, it's up to the tooling to decide
   * which one to use.
   */
  OasPathItem[string] paths;

  /**
   * An element to hold various schemas for the specification.
   */
  @jsonOptional
  OasComponents components;

  /**
   * A declaration of which security mechanisms can be used across the API. The list of values
   * includes alternative security requirement objects that can be used. Only one of the security
   * requirement objects need to be satisfied to authorize a request. Individual operations can
   * override this definition. To make security optional, an empty security requirement ({}) can be
   * included in the array.
   */
  @jsonOptional
  OasSecurityRequirement[] security;

  /**
   * A list of tags used by the specification with additional metadata. The order of the tags can be
   * used to reflect on their order by the parsing tools. Not all tags that are used by the
   * [OasOperation] object must be declared. The tags that are not declared MAY be organized
   * randomly or based on the tools' logic. Each tag name in the list MUST be unique.
   */
  @jsonOptional
  OasTag[] tags;

  /**
   * Additional external documentation.
   */
  @jsonOptional
  OasExternalDocumentation externalDocs;
}

/**
 * The object provides metadata about the API. The metadata MAY be used by the clients if needed,
 * and MAY be presented in editing or documentation generation tools for convenience.
 *
 * See_Also: https://swagger.io/specification/#info-object
 */
class OasInfo {
  /**
   * **REQUIRED**. The title of the API.
   */
  string title;

  /**
   * A short description of the API. [CommonMark syntax](https://spec.commonmark.org/) MAY be used
   * for rich text representation.
   */
  @jsonOptional
  string description;

  /**
   * A URL to the Terms of Service for the API. MUST be in the format of a URL.
   */
  @jsonOptional
  string termsOfService;

  /**
   * The contact information for the exposed API.
   */
  @jsonOptional
  OasContact contact;

  /**
   * The license information for the exposed API.
   */
  @jsonOptional
  OasLicense license;

  /**
   * **REQUIRED**. The version of the OpenAPI document (which is distinct from the [OpenAPI
   * Specification version](https://swagger.io/specification/#oas-version) or the API implementation
   * version).
   */
  string version_;
}

/**
 * Contact information for the exposed API.
 *
 * See_Also: https://swagger.io/specification/#contact-object
 */
class OasContact {
  /**
   * The identifying name of the contact person/organization.
   */
  @jsonOptional
  string name;

  /**
   * The URL pointing to the contact information. MUST be in the format of a URL.
   */
  @jsonOptional
  string url;

  /**
   * The email address of the contact person/organization. MUST be in the format of an email
   * address.
   */
  @jsonOptional
  string email;
}

/**
 * License information for the exposed API.
 *
 * See_Also: https://swagger.io/specification/#license-object
 */
class OasLicense {
  /**
   * **REQUIRED**. The license name used for the API.
   */
  string name;

  /**
   * A URL to the license used for the API. MUST be in the format of a URL.
   */
  @jsonOptional
  string url;
}

/**
 * An object representing a Server.
 *
 * See_Also: https://swagger.io/specification/#server-object
 */
class OasServer {
  /**
   * **REQUIRED**. A URL to the target host. This URL supports Server Variables and MAY be relative,
   * to indicate that the host location is relative to the location where the OpenAPI document is
   * being served. Variable substitutions will be made when a variable is named in {brackets}.
   */
  string url;

  /**
   * An optional string describing the host designated by the URL. [CommonMark
   * syntax](https://spec.commonmark.org/) MAY be used for rich text representation.
   */
  @jsonOptional
  string description;

  /**
   * A map between a variable name and its value. The value is used for substitution in the server's
   * URL template.
   */
  @jsonOptional
  OasServerVariable[string] variables;
}

/**
 * An object representing a Server Variable for server URL template substitution.
 *
 * See_Also: https://swagger.io/specification/#server-variable-object
 */
class OasServerVariable {
  /**
   * An enumeration of string values to be used if the substitution options are from a limited
   * set. The array SHOULD NOT be empty.
   */
  string[] enum_;

  /**
   * **REQUIRED**. The default value to use for substitution, which SHALL be sent if an alternate
   * value is not supplied. Note this behavior is different than the [OasSchema] object's treatment
   * of default values, because in those cases parameter values are optional. If the enum is
   * defined, the value SHOULD exist in the enum's values.
   */
  string default_;

  /**
   * An optional description for the server variable. CommonMark syntax MAY be used for rich text
   * representation.
   */
  @jsonOptional
  string description;
}

/**
 * Describes the operations available on a single path. A Path Item MAY be empty, due to [ACL
 * constraints](https://swagger.io/specification/#security-filtering). The path itself is still
 * exposed to the documentation viewer but they will not know which operations and parameters are
 * available.
 *
 * See_Also: https://swagger.io/specification/#path-item-object
 */
class OasPathItem {
  /**
   * Allows for an external definition of this path item. The referenced structure MUST be in the
   * format of a [OasPathItem] object. In case a [OasPathItem] field appears both in the defined
   * object and the referenced object, the behavior is undefined.
   */
  @jsonName("$ref")
  @jsonOptional
  string ref_;

  /**
   * An optional, string summary, intended to apply to all operations in this path.
   */
  @jsonOptional
  string summary;

  /**
   * An optional, string description, intended to apply to all operations in this path. [CommonMark
   * syntax](https://spec.commonmark.org/) MAY be used for rich text representation.
   */
  @jsonOptional
  string description;

  /**
   * A definition of a GET operation on this path.
   */
  @jsonOptional
  OasOperation get;

  /**
   * A definition of a PUT operation on this path.
   */
  @jsonOptional
  OasOperation put;

  /**
   * A definition of a POST operation on this path.
   */
  @jsonOptional
  OasOperation post;

  /**
   * A definition of a DELETE operation on this path.
   */
  @jsonOptional
  OasOperation delete_;

  /**
   * A definition of a OPTIONS operation on this path.
   */
  @jsonOptional
  OasOperation options;

  /**
   * A definition of a HEAD operation on this path.
   */
  @jsonOptional
  OasOperation head;

  /**
   * A definition of a PATCH operation on this path.
   */
  @jsonOptional
  OasOperation patch;

  /**
   * A definition of a TRACE operation on this path.
   */
  @jsonOptional
  OasOperation trace;

  /**
   * An alternative server array to service all operations in this path.
   */
  @jsonOptional
  OasServer[] servers;

  /**
   * A list of parameters that are applicable for all the operations described under this
   * path. These parameters can be overridden at the operation level, but cannot be removed
   * there. The list MUST NOT include duplicated parameters. A unique parameter is defined by a
   * combination of a name and location. The list can use the [OasReference] object to link to
   * parameters that are defined at the [OasDocument] object's
   * [components/parameters](https://swagger.io/specification/#components-parameters).
   */
  @jsonOptional
  OasParameter[] parameters;
}

/**
 * Describes a single operation parameter.
 *
 * A unique parameter is defined by a combination of a name and location.
 *
 * # Parameter Locations
 *
 * There are four possible parameter locations specified by the in field:
 * - path - Used together with Path Templating, where the parameter value is actually part of the
 *   operation's URL. This does not include the host or base path of the API. For example, in
 *   /items/{itemId}, the path parameter is itemId.
 * - query - Parameters that are appended to the URL. For example, in /items?id=###, the query
 *   parameter is id.
 * - header - Custom headers that are expected as part of the request. Note that RFC7230 states
 *   header names are case insensitive.
 * - cookie - Used to pass a specific cookie value to the API.
 *
 * See_Also: https://swagger.io/specification/#parameter-object
 */
class OasParameter {
  /**
   * A link to parameters defined in the [OasDocument's] components/parameters.
   */
  @jsonName("$ref")
  @jsonOptional
  string ref_;

  /**
   * **REQUIRED**. The name of the parameter. Parameter names are case sensitive.
   * - If in is "path", the name field MUST correspond to a template expression occurring within the
   *   path field in the [OasPaths] object. See Path Templating for further information.
   * - If in is "header" and the name field is "Accept", "Content-Type" or "Authorization", the
   *   parameter definition SHALL be ignored.
   * - For all other cases, the name corresponds to the parameter name used by the in property.
   */
  @jsonOptional
  string name;

  /**
   * **REQUIRED**. The location of the parameter. Possible values are "query", "header", "path" or
   * "cookie".
   */
  @jsonOptional
  string in_;

  /**
   * A brief description of the parameter. This could contain examples of use. [CommonMark
   * syntax](https://spec.commonmark.org/) MAY be used for rich text representation.
   */
  @jsonOptional
  string description;

  /**
   * Determines whether this parameter is mandatory. If the parameter location is "path", this
   * property is REQUIRED and its value MUST be true. Otherwise, the property MAY be included and
   * its default value is false.
   */
  @jsonOptional
  bool required = false;

  /**
   * Specifies that a parameter is deprecated and SHOULD be transitioned out of usage. Default value
   * is `false`.
   */
  @jsonOptional
  bool deprecated_ = false;

  /**
   * Sets the ability to pass empty-valued parameters. This is valid only for `query` parameters and
   * allows sending a parameter with an empty value. Default value is `false`. If style is used, and
   * if behavior is n/a (cannot be serialized), the value of allowEmptyValue SHALL be ignored. Use
   * of this property is NOT RECOMMENDED, as it is likely to be removed in a later revision.
   */
  @jsonOptional
  bool allowEmptyValue = false;

  // The rules for serialization of the parameter are specified in one of two ways. For simpler
  // scenarios, a schema and style can describe the structure and syntax of the parameter.

  /**
   * Describes how the parameter value will be serialized depending on the type of the parameter
   * value. Default values (based on value of in): for query - form; for path - simple; for header -
   * simple; for cookie - form.
   */
  @jsonOptional
  string style;

  /**
   * When this is true, parameter values of type `array` or `object` generate separate parameters
   * for each value of the array or key-value pair of the map. For other types of parameters this
   * property has no effect. When [style] is `form`, the default value is `true`. For all other
   * styles, the default value is `false`.
   */
  @jsonOptional
  bool explode;

  /**
   * Determines whether the parameter value SHOULD allow reserved characters, as defined by RFC3986
   * `:/?#[]@!$&'()*+,;=` to be included without percent-encoding. This property only applies to
   * parameters with an `in` value of `query`. The default value is `false`.
   */
  @jsonOptional
  bool allowReserved;

  /**
   * The schema defining the type used for the parameter.
   */
  @jsonOptional
  OasSchema schema;
}

/**
 * Holds a set of reusable objects for different aspects of the OAS. All objects defined within the
 * components object will have no effect on the API unless they are explicitly referenced from
 * properties outside the components object.
 */
class OasComponents {
  /**
   * An object to hold reusable [OasSchema] objects.
   */
  @jsonOptional
  OasSchema[string] schemas; // |Ref

  /**
   * An object to hold reusable [OasResponse] objects.
   */
  @jsonOptional
  OasResponse[string] responses; // |Ref

  /**
   * An object to hold reusable [OasParameter] objects.
   */
  @jsonOptional
  OasParameter[string] parameters; // |Ref

  /**
   * An object to hold reusable [OasExample] objects.
   */
  @jsonOptional
  OasExample[string] examples; // |Ref

  /**
   * An object to hold reusable [OasRequestBody] objects.
   */
  @jsonOptional
  OasRequestBody[string] requestBodies; // |Ref

  /**
   * An object to hold reusable [OasHeader] objects.
   */
  @jsonOptional
  OasHeader[string] headers; // |Ref

  /**
   * An object to hold reusable [OasSecurityScheme] objects.
   */
  @jsonOptional
  OasSecurityScheme[string] securitySchemes; // |Ref

  /**
   * An object to hold reusable [OasLink] objects.
   */
  @jsonOptional
  OasLink[string] links; // |Ref

  /**
   * An object to hold reusable [OasCallback] objects.
   */
  @jsonOptional
  OasCallback[string] callbacks; // |Ref
}

/**
 * The [OasSchema] object allows the definition of input and output data types. These types can be
 * objects, but also primitives and arrays. This object is an extended subset of the [JSON Schema
 * Specification Wright Draft 00](https://json-schema.org/).
 *
 * For more information about the properties, see [JSON Schema
 * Core](https://tools.ietf.org/html/draft-wright-json-schema-00) and [JSON Schema
 * Validation](https://tools.ietf.org/html/draft-wright-json-schema-validation-00). Unless stated
 * otherwise, the property definitions follow the JSON Schema.
 *
 * # Properties
 *
 * The following properties are taken directly from the JSON Schema definition and follow the same
 * specifications:
 * - title
 * - multipleOf
 * - maximum
 * - exclusiveMaximum
 * - minimum
 * - exclusiveMinimum
 * - maxLength
 * - minLength
 * - pattern (This string SHOULD be a valid regular expression, according to the Ecma-262 Edition
     5.1 regular expression dialect)
 * - maxItems
 * - minItems
 * - uniqueItems
 * - maxProperties
 * - minProperties
 * - required
 * - enum
 *
 * The following properties are taken from the JSON Schema definition but their definitions were
 * adjusted to the OpenAPI Specification:
 *
 * - type - Value MUST be a string. Multiple types via an array are not supported.
 * - allOf - Inline or referenced schema MUST be of a [OasSchema] object and not a standard
 *   JSON Schema.
 * - oneOf - Inline or referenced schema MUST be of a [OasSchema] object and not a standard
 *   JSON Schema.
 * - anyOf - Inline or referenced schema MUST be of a [OasSchema] object and not a standard
 *   JSON Schema.
 * - not - Inline or referenced schema MUST be of a [OasSchema] object and not a standard
 *   JSON Schema.
 * - items - Value MUST be an object and not an array. Inline or referenced schema MUST be of a
 *   [OasSchema] object and not a standard JSON Schema. items MUST be present if the type is array.
 * - properties - Property definitions MUST be a [OasSchema] object and not a standard JSON Schema
 *   (inline or referenced).
 * - additionalProperties - Value can be boolean or object. Inline or referenced schema MUST be of a
 *   [OasSchema] object and not a standard JSON Schema. Consistent with JSON Schema,
 *   additionalProperties defaults to true.
 * - description - CommonMark syntax MAY be used for rich text representation.
 * - format - See Data Type Formats for further details. While relying on JSON Schema's defined
 *   formats, the OAS offers a few additional predefined formats.
 * - default - The default value represents what would be assumed by the consumer of the input as
 *   the value of the schema if one is not provided. Unlike JSON Schema, the value MUST conform to
 *   the defined type for the [OasSchema] object defined at the same level. For example, if type is
 *   string, then default can be "foo" but cannot be 1.
 *
 * Alternatively, any time a [OasSchema] object can be used, a [OasReference] object can be used in
 * its place. This allows referencing definitions instead of defining them inline.
 *
 * Additional properties defined by the JSON Schema specification that are not mentioned here are
 * strictly unsupported.
 *
 * Other than the JSON Schema subset fields, the following fields MAY be used for further schema
 * documentation:
 */
class OasSchema {
  /**
   * An internal or external reference to a schema component. If set, the other attribute are
   * unused.
   */
  @jsonName("$ref")
  @jsonOptional
  string ref_;

  /**
   * Both of these keywords can be used to decorate a user interface with information about the data
   * produced by this user interface.  A title will preferrably be short, whereas a description will
   * provide explanation about the purpose of the instance described by this schema.
   *
   * See_Also: https://datatracker.ietf.org/doc/html/draft-wright-json-schema-validation-00#section-6.1
   */
  @jsonOptional
  string title;

  /**
   * Both of these keywords can be used to decorate a user interface with information about the data
   * produced by this user interface.  A title will preferrably be short, whereas a description will
   * provide explanation about the purpose of the instance described by this schema.
   *
   * CommonMark syntax MAY be used for rich text representation.
   *
   * See_Also: https://datatracker.ietf.org/doc/html/draft-wright-json-schema-validation-00#section-6.1
   */
  @jsonOptional
  string description;

  /**
   * Value MUST be a string. Multiple types via an array are not supported.
   *
   * One of seven primitive types from the core specification:
   * - null
   * - boolean
   * - object
   * - array
   * - number
   * - string
   *
   * See_Also:
   *   https://datatracker.ietf.org/doc/html/draft-wright-json-schema-validation-00#section-5.21
   *   https://datatracker.ietf.org/doc/html/draft-wright-json-schema-00#section-4.2
   */
  @jsonOptional
  string type;

  /**
   * Structural validation alone may be insufficient to validate that an instance meets all the
   * requirements of an application.  The "format" keyword is defined to allow interoperable
   * semantic validation for a fixed subset of values which are accurately described by
   * authoritative resources, be they RFCs or other external specifications.
   *
   * The value of this keyword is called a format attribute.  It MUST be a string.  A format
   * attribute can generally only validate a given set of instance types.  If the type of the
   * instance to validate is not in this set, validation for this format attribute and instance
   * SHOULD succeed.
   *
   * See [Data Type Formats](https://swagger.io/specification/#data-type-format) for further
   * details. While relying on JSON Schema's defined formats, the OAS offers a few additional
   * predefined formats.
   *
   * Example values when "type" is "integer" include: "int32", "int64".
   * Example values when "type" is "number" include: "float", "double".
   * Example values when "type" is "string" include: "date", "date-time", "password".
   *
   * See_Also: https://datatracker.ietf.org/doc/html/draft-wright-json-schema-validation-00#section-7
   */
  @jsonOptional
  string format;

  /**
   * This keyword's value MUST be an array.  This array MUST have at least one element.
   *
   * Elements of the array MUST be objects.  Each object MUST be a valid JSON Schema.
   *
   * An instance validates successfully against this keyword if it validates successfully against
   * all schemas defined by this keyword's value.
   *
   * Inline or referenced schema MUST be of a [OasSchema] object and not a standard JSON Schema.
   *
   * See_Also: https://datatracker.ietf.org/doc/html/draft-wright-json-schema-validation-00#section-5.22
   */
  @jsonOptional
  OasSchema[] allOf;

  /**
   * This keyword's value MUST be an array. This array MUST have at least one element.
   *
   * Elements of the array MUST be objects. Each object MUST be a valid JSON Schema.
   *
   * An instance validates successfully against this keyword if it validates successfully against
   * exactly one schema defined by this keyword's value.
   *
   * Inline or referenced schema MUST be of a Schema Object and not a standard JSON Schema.
   *
   * See_Also: https://datatracker.ietf.org/doc/html/draft-wright-json-schema-validation-00#section-5.24
   */
  @jsonOptional
  OasSchema[] oneOf;

  /**
   * This keyword's value MUST be an array.  This array MUST have at least one element.
   *
   * Elements of the array MUST be objects. Each object MUST be a valid JSON Schema.
   *
   * An instance validates successfully against this keyword if it validates successfully against at
   * least one schema defined by this keyword's value.
   *
   * Inline or referenced schema MUST be of a Schema Object and not a standard JSON Schema.
   *
   * See_Also: https://datatracker.ietf.org/doc/html/draft-wright-json-schema-validation-00#section-5.23
   */
  @jsonOptional
  OasSchema[] anyOf;

  /**
   * This keyword's value MUST be an object.  This object MUST be a valid JSON Schema.
   *
   * An instance is valid against this keyword if it fails to validate successfully against the
   * schema defined by this keyword.
   *
   * Inline or referenced schema MUST be of a [OasSchema] object and not a standard JSON Schema.
   *
   * See_Also: https://datatracker.ietf.org/doc/html/draft-wright-json-schema-validation-00#section-5.25
   */
  @jsonOptional
  OasSchema not;

  /**
   * If present, a schema that validates items of an array
   *
   * Value MUST be an object and not an array. Inline or referenced schema MUST be of a Schema
   * Object and not a standard JSON Schema. items MUST be present if the type is array.
   *
   * See_Also: https://datatracker.ietf.org/doc/html/draft-wright-json-schema-validation-00#section-5.9
   */
  @jsonOptional
  OasSchema items;

  /**
   * An mapping from an object property name to a schemas that property must be validated against.
   *
   * The value of "properties" MUST be an object.  Each value of this object MUST be an object, and
   * each object MUST be a valid JSON Schema.
   *
   * If absent, it can be considered the same as an empty object.
   *
   * Property definitions MUST be a [OasSchema] object and not a standard JSON Schema (inline or
   * referenced).
   *
   * See_Also: https://datatracker.ietf.org/doc/html/draft-wright-json-schema-validation-00#section-5.16
   */
  @jsonOptional
  OasSchema[string] properties;

  /**
   * The value of "additionalProperties" MUST be a boolean or a schema.
   *
   * If "additionalProperties" is absent, it may be considered present with an empty schema as a
   * value.
   *
   * If "additionalProperties" is true, validation always succeeds.
   *
   * If "additionalProperties" is false, validation succeeds only if the instance is an object and
   * all properties on the instance were covered by "properties" and/or "patternProperties".
   *
   * If "additionalProperties" is an object, validate the value as a schema to all of the properties
   * that weren't validated by "properties" nor "patternProperties".
   *
   * Value can be boolean or object. Inline or referenced schema MUST be of a Schema Object and not
   * a standard JSON Schema. Consistent with JSON Schema, additionalProperties defaults to true.
   *
   * See_Also: https://datatracker.ietf.org/doc/html/draft-wright-json-schema-validation-00#section-5.18
   */
  @jsonOptional
  Json additionalProperties;

  /**
   * The value of this keyword MUST be an array.  This array MUST have at least one element.
   * Elements of this array MUST be strings, and MUST be unique.
   *
   * An object instance is valid against this keyword if its property set contains all elements in
   * this keyword's array value.
   *
   * See_Also: https://datatracker.ietf.org/doc/html/draft-wright-json-schema-validation-00#section-5.15
   */
  @jsonOptional
  string[] required;

  /**
   * The value of this keyword MUST be an array.  This array SHOULD have at least one element.
   * Elements in the array SHOULD be unique.
   *
   * Elements in the array MAY be of any type, including null.
   *
   * An instance validates successfully against this keyword if its value is equal to one of the
   * elements in this keyword's array value.
   *
   * See_Also: https://datatracker.ietf.org/doc/html/draft-wright-json-schema-validation-00#section-5.20
   */
  @jsonOptional
  Json[] enum_;

  // TODO: Support "default".

  /**
   * A true value adds "null" to the allowed type specified by the type keyword, only if `type` is
   * explicitly defined within the same [OasSchema] object. Other [OasSchema] object constraints
   * retain their defined behavior, and therefore may disallow the use of `null` as a value. A
   * `false` value leaves the specified or default `type` unmodified. The default value is `false`.
   */
  @jsonOptional
  bool nullable = false;

  /**
   * Adds support for polymorphism. The discriminator is an object name that is used to
   * differentiate between other schemas which may satisfy the payload description. See Composition
   * and Inheritance for more details.
   */
  @jsonOptional
  OasDiscriminator discriminator;

  /**
   * Relevant only for Schema "properties" definitions. Declares the property as "read only". This
   * means that it MAY be sent as part of a response but SHOULD NOT be sent as part of the
   * request. If the property is marked as `readOnly` being `true` and is in the `required` list,
   * the `required` will take effect on the response only. A property MUST NOT be marked as both
   * `readOnly` and `writeOnly` being `true`. Default value is `false`.
   */
  @jsonOptional
  bool readOnly = false;

  /**
   * Relevant only for Schema "properties" definitions. Declares the property as "write
   * only". Therefore, it MAY be sent as part of a request but SHOULD NOT be sent as part of the
   * response. If the property is marked as `writeOnly` being `true` and is in the `required` list,
   * the `required` will take effect on the request only. A property MUST NOT be marked as both
   * `readOnly` and `writeOnly` being `true`. Default value is `false`.
   */
  @jsonOptional
  bool writeOnly = false;

  // TODO:
  // XML xml;

  // TODO:
  // OasExternalDocs xml;

  // TODO:
  // void* example;

  // TODO:
  // bool deprecated;
}

/**
 * Describes a single response from an API Operation, including design-time, static links to
 * operations based on the response.
 *
 * See_Also: https://swagger.io/specification/#response-object
 */
class OasResponse {
  /**
   * An internal or external reference to a response component. If set, the other attribute are
   * unused.
   */
  @jsonName("$ref")
  @jsonOptional
  string ref_;

  /**
   * **REQUIRED**. A short description of the response. [CommonMark
   * syntax](https://spec.commonmark.org/) MAY be used for rich text representation.
   */
  @jsonOptional
  string description;

  /**
   * Maps a header name to its definition. [RFC7230](https://tools.ietf.org/html/rfc7230#page-22)
   * states header names are case insensitive. If a response header is defined with the name
   * "Content-Type", it SHALL be ignored.
   */
  @jsonOptional
  OasHeader[string] headers; // |Ref

  /**
   * A map containing descriptions of potential response payloads. The key is a media type or [media
   * type range](https://tools.ietf.org/html/rfc7231#appendix--d) and the value describes it. For
   * responses that match multiple keys, only the most specific key is applicable. e.g. `text/plain`
   * overrides `text/*`
   */
  @jsonOptional
  OasMediaType[string] content;

  /**
   * A map of operations links that can be followed from the response. The key of the map is a short
   * name for the link, following the naming constraints of the names for [OasComponent] objects.
   */
  @jsonOptional
  OasLink[string] links;
}

/**
 * Data about OasHeader. The OasHeader object follows the structure of the [OasParameter] object
 * with the following changes:
 *
 * 1. `name` MUST NOT be specified, it is given in the corresponding `headers` map.
 * 2. in MUST NOT be specified, it is implicitly in `header`.
 * 3. All traits that are affected by the location MUST be applicable to a location of `header` (for
 *    example, style).
 */
class OasHeader {
  /**
   * A link to parameters defined in the [OasDocument's] components/references.
   */
  @jsonName("$ref")
  @jsonOptional
  string ref_;

  /**
   * A brief description of the header. This could contain examples of use. [CommonMark
   * syntax](https://spec.commonmark.org/) MAY be used for rich text representation.
   */
  @jsonOptional
  string description;

  /**
   * Determines whether this header is mandatory. If the parameter location is "path", this
   * property is REQUIRED and its value MUST be true. Otherwise, the property MAY be included and
   * its default value is `false`.
   */
  @jsonOptional
  bool required = false;

  /**
   * Specifies that a header is deprecated and SHOULD be transitioned out of usage. Default value
   * is `false`.
   */
  @jsonOptional
  bool deprecated_ = false;

  /**
   * Sets the ability to pass empty-valued headers. This is valid only for headers and allows
   * sending a header with an empty value. Default value is false. If style is used, and if behavior
   * is n/a (cannot be serialized), the value of allowEmptyValue SHALL be ignored. Use of this
   * property is NOT RECOMMENDED, as it is likely to be removed in a later revision.
   */
  @jsonOptional
  bool allowEmptyValue = false;
}

/**
 * Each OasMediaType object provides schema and examples for the media type identified by its key.
 *
 * See_Also: https://swagger.io/specification/#media-type-object
 */
class OasMediaType {
  /**
   * The schema defining the content of the request, response, or parameter.
   */
  @jsonOptional
  OasSchema schema;

  /**
   * A map between a property name and its encoding information. The key, being the property name,
   * MUST exist in the schema as a property. The encoding object SHALL only apply to `requestBody`
   * objects when the media type is `multipart` or `application/x-www-form-urlencoded`.
   */
  @jsonOptional
  OasEncoding[string] encoding;
}

/**
 * A single encoding definition applied to a single schema property.
 */
class OasEncoding {
  /**
   * The Content-Type for encoding a specific property. Default value depends on the property type:
   * for `string` with `format` being `binary` – `application/octet-stream`; for other primitive
   * types – `text/plain`; for `object` - `application/json`; for `array` – the default is defined
   * based on the inner type. The value can be a specific media type (e.g. `application/json`), a
   * wildcard media type (e.g. `image/*`), or a comma-separated list of the two types.
   */
  @jsonOptional
  string contentType;

  /**
   * A map allowing additional information to be provided as headers, for example
   * `Content-Disposition`. `Content-Type` is described separately and SHALL be ignored in this
   * section. This property SHALL be ignored if the request body media type is not a `multipart`.
   */
  @jsonOptional
  OasHeader[string] headers; // |Ref

  /**
   * Describes how a specific property value will be serialized depending on its type. See
   * [OasParameter] object for details on the [style] property. The behavior follows the same values
   * as `query` parameters, including default values. This property SHALL be ignored if the request
   * body media type is not `application/x-www-form-urlencoded`.
   */
  @jsonOptional
  string style;

  /**
   * When this is true, property values of type `array` or `object` generate separate parameters for
   * each value of the array, or key-value-pair of the map. For other types of properties this
   * property has no effect. When [style] is `form`, the default value is `true`. For all other
   * styles, the default value is `false`. This property SHALL be ignored if the request body media
   * type is not `application/x-www-form-urlencoded`.
   */
  @jsonOptional
  bool explode;

  /**
   * Determines whether the parameter value SHOULD allow reserved characters, as defined by RFC3986
   * `:/?#[]@!$&'()*+,;=` to be included without percent-encoding. The default value is
   * `false`. This property SHALL be ignored if the request body media type is not
   * `application/x-www-form-urlencoded`.
   */
  @jsonOptional
  bool allowReserved;
}

/**
 * Lists the required security schemes to execute this operation. The name used for each property
 * MUST correspond to a security scheme declared in the Security Schemes under the Components
 * Object.
 *
 * Security Requirement Objects that contain multiple schemes require that all schemes MUST be
 * satisfied for a request to be authorized. This enables support for scenarios where multiple query
 * parameters or HTTP headers are required to convey security information.
 *
 * When a list of Security Requirement Objects is defined on the OpenAPI Object or Operation Object,
 * only one of the Security Requirement Objects in the list needs to be satisfied to authorize the
 * request.
 *
 * See_Also: https://swagger.io/specification/#security-requirement-object
 */
alias OasSecurityRequirement = string[][string];

/**
 * Adds metadata to a single tag that is used by the [OasOperation] object. It is not mandatory to
 * have a Tag Object per tag defined in the Operation Object instances.
 *
 * See_Also: https://swagger.io/specification/#tag-object
 */
class OasTag {
  /**
   * **REQUIRED**. The name of the tag.
   */
  string name;

  /**
   * A short description for the tag. [CommonMark syntax](https://spec.commonmark.org/) MAY be used
   * for rich text representation.
   */
  @jsonOptional
  string description;

  /**
   * Additional external documentation for this tag.
   */
  @jsonOptional
  OasExternalDocumentation externalDocs;
}

/**
 * Allows referencing an external resource for extended documentation.
 *
 * See_Also: https://swagger.io/specification/#external-documentation-object
 */
class OasExternalDocumentation {
  /**
   * A short description of the target documentation. [CommonMark
   * syntax](https://spec.commonmark.org/) MAY be used for rich text representation.
   */
  @jsonOptional
  string description;

  /**
   * **REQUIRED**. The URL for the target documentation. Value MUST be in the format of a URL.
   */
  string url;
}

/**
 * Describes a singel API operation on a path.
 */
class OasOperation {
  /**
   * A list of tags for API documentation control. Tags can be used for logical grouping of
   * operations by resources or any other qualifier.
   */
  @jsonOptional
  string[] tags;

  /**
   * A short summary of what the operation does.
   */
  @jsonOptional
  string summary;

  /**
   * A verbose explanation of the operation behavior. [CommonMark
   * syntax](https://spec.commonmark.org/) MAY be used for rich text representation.
   */
  @jsonOptional
  string description;

  /**
   * Additional external documentation for this operation.
   */
  @jsonOptional
  OasExternalDocumentation externalDocs;

  /**
   * Unique string used to identify the operation. The id MUST be unique among all operations
   * described in the API. The operationId value is **case-sensitive**. Tools and libraries MAY use
   * the operationId to uniquely identify an operation, therefore, it is RECOMMENDED to follow
   * common programming naming conventions.
   */
  @jsonOptional
  string operationId;

  /**
   * A list of parameters that are applicable for this operation. If a parameter is already defined
   * at the Path Item, the new definition will override it but can never remove it. The list MUST
   * NOT include duplicated parameters. A unique parameter is defined by a combination of a name and
   * location. The list can use the Reference Object to link to parameters that are defined at the
   * OpenAPI Object's components/parameters.
   */
  @jsonOptional
  OasParameter[] parameters;  // |Ref

  /**
   * The request body applicable for this operation. The `requestBody` is only supported in HTTP
   * methods where the HTTP 1.1 specification
   * [RFC7231](https://tools.ietf.org/html/rfc7231#section-4.3.1) has explicitly defined semantics
   * for request bodies. In other cases where the HTTP spec is vague, `requestBody` SHALL be ignored
   * by consumers.
   */
  @jsonOptional
  OasRequestBody requestBody; // |Ref

  /**
   * **REQUIRED**. The list of possible responses as they are returned from executing this
   * operation.
   */
  OasResponses responses;

  /**
   * A map of possible out-of band callbacks related to the parent operation. The key is a unique
   * identifier for the [OasCallback] object. Each value in the map is a Callback Object that
   * describes a request that may be initiated by the API provider and the expected responses.
   */
  @jsonOptional
  OasCallback[string] callbacks; // |Ref

  /**
   * Declares this operation to be deprecated. Consumers SHOULD refrain from usage of the declared
   * operation. Default value is false.
   */
  @jsonOptional
  bool deprecated_ = false;

  /**
   * A declaration of which security mechanisms can be used for this operation. The list of values
   * includes alternative security requirement objects that can be used. Only one of the security
   * requirement objects need to be satisfied to authorize a request. To make security optional, an
   * empty security requirement (`{}`) can be included in the array. This definition overrides any
   * declared top-level security. To remove a top-level security declaration, an empty array can be
   * used.
   */
  @jsonOptional
  OasSecurityRequirement[] security;

  /**
   * An alternative `server` array to service this operation. If an alternative `server` object is
   * specified at the Path Item Object or Root level, it will be overridden by this value.
   */
  @jsonOptional
  OasServer[] servers;
}

class OasExample {
  /**
   * A link to parameters defined in the [OasDocument's] components/examples.
   */
  @jsonName("$ref")
  @jsonOptional
  string ref_;

  /**
   * Short description for the example.
   */
  @jsonOptional
  string summary;

  /**
   * Long description for the example. [CommonMark syntax](https://spec.commonmark.org/) MAY be used
   * for rich text representation.
   */
  @jsonOptional
  string description;

  /**
   * Embedded literal example. The value field and externalValue field are mutually exclusive. To
   * represent examples of media types that cannot naturally represented in JSON or YAML, use a
   * string value to contain the example, escaping where necessary.
   */
  @jsonOptional
  Json value;

  /**
   * A URL that points to the literal example. This provides the capability to reference examples
   * that cannot easily be included in JSON or YAML documents. The `value` field and `externalValue`
   * field are mutually exclusive.
   */
  @jsonOptional
  string externalValue;
}

class OasRequestBody {
  /**
   * A link to request bodies defined in the [OasDocument's] components/requestBodies.
   */
  @jsonName("$ref")
  @jsonOptional
  string ref_;

  /**
   * A brief description of the request body. This could contain examples of use. [CommonMark
   * syntax](https://spec.commonmark.org/) MAY be used for rich text representation.
   */
  @jsonOptional
  string description;

  /**
   * **REQUIRED**. The content of the request body. The key is a media type or media type range and
   * the value describes it. For requests that match multiple keys, only the most specific key is
   * applicable. e.g. `text/plain` overrides `text/*`
   */
  @jsonOptional
  OasMediaType[string] content;

  /**
   * Determines if the request body is required in the request. Defaults to `false`.
   */
  @jsonOptional
  bool required = false;
}

/**
 * Defines a security scheme that can be used by the operations. Supported schemes are HTTP
 * authentication, an API key (either as a header, a cookie parameter or as a query parameter),
 * OAuth2's common flows (implicit, password, client credentials and authorization code) as defined
 * in [RFC6749](https://tools.ietf.org/html/rfc6749), and [OpenID Connect
 * Discovery](https://tools.ietf.org/html/draft-ietf-oauth-discovery-06).
 */
class OasSecurityScheme {
  /**
   * A link to request bodies defined in the [OasDocument's] components/securitySchemes.
   */
  @jsonName("$ref")
  @jsonOptional
  string ref_;

  /**
   * **REQUIRED**. The type of the security scheme. Valid values are "apiKey", "http", "oauth2",
   * "openIdConnect".
   */
  @jsonOptional
  string type;

  /**
   * A short description for security scheme. [CommonMark syntax](https://spec.commonmark.org/) MAY
   * be used for rich text representation.
   */
  @jsonOptional
  string description;

  /**
   * **REQUIRED**. The name of the header, query or cookie parameter to be used.
   */
  @jsonOptional // Optional due to missing values in Stripe OpenAPI.
  string name;

  /**
   * **REQUIRED**. The location of the API key. Valid values are "query", "header" or "cookie".
   */
  @jsonOptional
  string in_;

  /**
   * **REQUIRED**. The name of the HTTP Authorization scheme to be used in the [Authorization header
   * as defined in RFC7235](https://tools.ietf.org/html/rfc7235#section-5.1). The values used SHOULD
   * be registered in the [IANA Authentication Scheme
   * registry](https://www.iana.org/assignments/http-authschemes/http-authschemes.xhtml).
   */
  @jsonOptional
  string scheme;

  /**
   * A hint to the client to identify how the bearer token is formatted. Bearer tokens are usually
   * generated by an authorization server, so this information is primarily for documentation
   * purposes.
   */
  @jsonOptional
  string bearerFormat;

  /**
   * **REQUIRED**. An object containing configuration information for the flow types supported.
   */
  @jsonOptional
  OasOAuthFlows flows;

  /**
   * **REQUIRED**. OpenId Connect URL to discover OAuth2 configuration values. This MUST be in the
   * form of a URL.
   */
  @jsonOptional
  string openIdConnectUrl;
}

/**
 * The Link object represents a possible design-time link for a response. The presence of a link
 * does not guarantee the caller's ability to successfully invoke it, rather it provides a known
 * relationship and traversal mechanism between responses and other operations.
 *
 * Unlike *dynamic* links (i.e. links provided in the response payload), the OAS linking
 * mechanism does not require link information in the runtime response.
 *
 * For computing links, and providing instructions to execute them, a [runtime
 * expression](https://swagger.io/specification/#runtime-expression) is used for accessing values in
 * an operation and using them as parameters while invoking the linked operation.
 *
 * See_Also: https://swagger.io/specification/#link-object
 */
class OasLink {
  /**
   * A link to request bodies defined in the [OasDocument's] components/links.
   */
  @jsonName("$ref")
  @jsonOptional
  string ref_;

  /**
   * A relative or absolute URI reference to an OAS operation. This field is mutually exclusive of
   * the `operationId` field, and MUST point to an [OasOperation] object. Relative `operationRef`
   * values MAY be used to locate an existing [OasOperation] object in the OpenAPI definition.
   */
  @jsonOptional
  string operationRef;

  /**
   * The name of an existing, resolvable OAS operation, as defined with a unique `operationId`. This
   * field is mutually exclusive of the `operationRef` field.
   */
  @jsonOptional
  string operationId;

  /**
   * A map representing parameters to pass to an operation as specified with `operationId` or
   * identified via `operationRef`. The key is the parameter name to be used, whereas the value can
   * be a constant or an expression to be evaluated and passed to the linked operation. The
   * parameter name can be qualified using the parameter location `[{in}.]{name}` for operations
   * that use the same parameter name in different locations (e.g. path.id).
   */
  @jsonOptional
  string[string] parameters; // TODO: Support Any type as map values.

  /**
   * A literal value or {expression} to use as a request body when calling the target operation.
   */
  @jsonOptional
  string requestBody;

  /**
   * A description of the link. [CommonMark syntax](https://spec.commonmark.org/) MAY be used for
   * rich text representation.
   */
  @jsonOptional
  string description;

  /**
   * A server object to be used by the target operation.
   */
  @jsonOptional
  OasServer server;
}

/**
 * A map of possible out-of band callbacks related to the parent operation. Each value in the map is
 * a [OasPathItem] object that describes a set of requests that may be initiated by the API provider
 * and the expected responses. The key value used to identify the path item object is an expression,
 * evaluated at runtime, that identifies a URL to use for the callback operation.
 *
 * See_Also: https://swagger.io/specification/#callback-object
 */
alias OasCallback = OasPathItem[string];


/**
 * When request bodies or response payloads may be one of a number of different schemas, a
 * `discriminator` object can be used to aid in serialization, deserialization, and validation. The
 * discriminator is a specific object in a schema which is used to inform the consumer of the
 * specification of an alternative schema based on the value associated with it.
 *
 * When using the discriminator, *inline* schemas will not be considered.
 *
 * See_Also: https://swagger.io/specification/#discriminator-object
 */
class OasDiscriminator {
  /**
   * **REQUIRED**. The name of the property in the payload that will hold the discriminator value.
   */
  string propertyName;

  /**
   * An object to hold mappings between payload values and schema names or references.
   */
  @jsonOptional
  string[string] mapping;
}

/**
 * A container for the expected responses of an operation. The container maps a HTTP response code
 * to the expected response.
 *
 * The documentation is not necessarily expected to cover all possible HTTP response codes because
 * they may not be known in advance. However, documentation is expected to cover a successful
 * operation response and any known errors.
 *
 * The `default` MAY be used as a default response object for all HTTP codes that are not covered
 * individually by the specification.
 *
 * The Responses Object MUST contain at least one response code, and it SHOULD be the response for a
 * successful operation call.
 */
alias OasResponses = OasResponse[string];

/**
 * Allows configuration of the supported OAuth Flows.
 */
class OasOAuthFlows {
  /**
   * Configuration for the OAuth Implicit flow.
   */
  @jsonOptional
  OasOAuthFlow implicit;

  /**
   * Configuration for the OAuth Resource Owner Password flow.
   */
  @jsonOptional
  OasOAuthFlow password;

  /**
   * Configuration for the OAuth Client Credentials flow. Previously called `application` in OpenAPI
   * 2.0.
   */
  @jsonOptional
  OasOAuthFlow clientCredentials;

  /**
   * Configuration for the OAuth Authorization Code flow. Previously called `accessCode` in OpenAPI
   * 2.0.
   */
  @jsonOptional
  OasOAuthFlow authorizationCode;
}

/**
 * Configuration details for a supported OAuth Flow.
 */
class OasOAuthFlow {
  /**
   * **REQUIRED**. The authorization URL to be used for this flow. This MUST be in the form of a
   * URL.
   */
  string authorizationUrl;

  /**
   * **REQUIRED**. The token URL to be used for this flow. This MUST be in the form of a URL.
   */
  string tokenUrl;

  /**
   * The URL to be used for obtaining refresh tokens. This MUST be in the form of a URL.
   */
  @jsonOptional
  string refreshUrl;

  /**
   * **REQUIRED**. The available scopes for the OAuth2 security scheme. A map between the scope name
   * and a short description for it. The map MAY be empty.
   */
  string[string] scopes;
}
