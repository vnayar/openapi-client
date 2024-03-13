module openapi_client.paths;

import vibe.data.json : Json, deserializeJson;
import vibe.core.log : logDebug;

import std.container.rbtree : RedBlackTree;
import std.file : mkdir, mkdirRecurse, write;
import std.array : appender, split, Appender, join;
import std.algorithm : skipOver;
import std.path : buildNormalizedPath, dirName;
import std.string : tr, capitalize, indexOf;
import std.range : tail, takeOne;
import std.stdio : writeln;
import std.regex : regex, replaceAll;
import std.conv : to;

import openapi : OasDocument, OasPathItem, OasOperation, OasParameter, OasMediaType, OasRequestBody, OasResponse;
import openapi_client.schemas;
import openapi_client.util : toUpperCamelCase, toLowerCamelCase, wordWrapText, writeCommentBlock;

struct PathEntry {
  string path;
  OasPathItem pathItem;
}

/**
 * Given the paths in an OpenApi Specification Document, produce D-language code that can perform
 * REST requests to communicate with the API. Depending on the architecture concepts being used,
 * these files are the equivalent to a "service" or a "gateway" class.
 *
 * See_Also: https://swagger.io/specification/#paths-object
 */
void writePathFiles(OasDocument oasDocument, string targetDir, string packageRoot) {
  // Rather than giving every path a separate class, group them by common URLs.
  PathEntry[][string] pathEntriesByPathRoot;
  foreach (string path, OasPathItem pathItem; oasDocument.paths) {
    writeln("Adding path: ", path);
    // Grouping API endpoints up until the first path parameter strikes a reasonable balance.
    auto re = regex(r"(/\{[^{}]*\}.*)|(/$)", "g");
    string pathRoot = replaceAll(path, re, "");
    writeln("  PathRoot: ", pathRoot);
    pathEntriesByPathRoot[pathRoot] ~= PathEntry(path, pathItem);
  }

  // Now we can write methods from the grouped PathItem objects into their class.
  foreach (string pathRoot, PathEntry[] pathEntries; pathEntriesByPathRoot) {
    writeln("Generating service for ", pathRoot, " with ", pathEntries.length, " path items.");
    auto buffer = appender!string();
    string moduleName = pathRoot[1..$].tr("-/", "_") ~ "_service";
    generateModuleHeader(buffer, packageRoot, moduleName);
    generateModuleImports(buffer, pathEntries, packageRoot);
    // TODO: Generate imports that originate from the data types created here.
    buffer.put("/**\n");
    buffer.put(" * Service to make REST API calls to paths beginning with: " ~ pathRoot ~ "\n");
    buffer.put(" */\n");
    string className = moduleName.toUpperCamelCase();
    buffer.put("class " ~ className ~ " {\n");
    foreach (PathEntry pathEntry; pathEntries) {
      writeln("  - Generating methods for ", pathEntry.path);
      generatePathItemMethods(buffer, pathEntry.path, pathEntry.pathItem);
    }
    generateModuleFooter(buffer);

    string fileName =
        buildNormalizedPath(targetDir, tr(packageRoot ~ ".service." ~ moduleName, ".", "/") ~ ".d");
    writeln("Writing file: ", fileName);
    mkdirRecurse(dirName(fileName));
    write(fileName, buffer[]);
  }
}

/**
 * Dive through the PathEntries and extract a list of needed imports.
 */
void generateModuleImports(Appender!string buffer, PathEntry[] pathEntries, string packageRoot) {
  RedBlackTree!string refs = new RedBlackTree!string();
  foreach (PathEntry pathEntry; pathEntries) {
    foreach (OperationEntry entry; getPathItemOperationEntries(pathEntry.pathItem)) {
      if (entry.operation is null)
        continue;
      // Add any types connected to path/header/query/cookie parameters.
      foreach (OasParameter parameter; entry.operation.parameters) {
        getSchemaReferences(parameter.schema, refs);
      }
      // Add any types connected to the request.
      OasRequestBody requestBody = entry.operation.requestBody;
      if (requestBody !is null) {
        OasMediaType mediaType;
        foreach (pair; requestBody.content.byKeyValue()) {
          mediaType = pair.value;
        }
        if (mediaType.schema !is null)
          getSchemaReferences(mediaType.schema, refs);
      }
      // Add any types connected to the response.
      foreach (pair; entry.operation.responses.byKeyValue()) {
        // HTTP status code = pair.key
        OasResponse response = pair.value;
        foreach (mediaEntry; response.content.byKeyValue()) {
          // HTTP content type = mediaEntry.key
          OasMediaType mediaType = mediaEntry.value;
          if (mediaType.schema !is null)
            getSchemaReferences(mediaType.schema, refs);
        }
      }
    }
  }

  // Add imports for any referenced schemas.
  with (buffer) {
    foreach (string schemaRef; refs) {
      string schemaName = getSchemaNameFromRef(schemaRef);
      put("public import ");
      put(getModuleNameFromSchemaName(packageRoot, schemaName));
      put(" : ");
      put(getClassNameFromSchemaName(schemaName));
      put(";\n");
    }
    put("\n");
  }
}

/**
 * Writes the beginning of a class file for a service that can access a REST API.
 */
void generateModuleHeader(
    Appender!string buffer, string packageRoot, string moduleName) {
  with (buffer) {
    put("// File automatically generated from OpenAPI spec.\n");
    put("module " ~ packageRoot ~ ".service." ~ moduleName ~ ";\n");
    put("\n");
    put("import vibe.http.client : requestHTTP, HTTPClientRequest, HTTPClientResponse;\n");
    put("import vibe.http.common : HTTPMethod;\n");
    put("import vibe.stream.operations : readAllUTF8;\n");
    put("import vibe.data.serialization : vibeName = name, vibeOptional = optional, vibeEmbedNullable = embedNullable;\n");
    put("import vibe.data.json : Json, deserializeJson;\n");
    put("import builder : AddBuilder;\n");
    put("\n");
    put("import " ~ packageRoot ~ ".servers : Servers;\n");
    put("import " ~ packageRoot ~ ".security : Security;\n");
    put("import openapi_client.util : isNull;\n");
    put("import openapi_client.apirequest : ApiRequest;\n");
    put("import openapi_client.handler : ResponseHandler;\n");
    put("\n");
    put("import std.conv : to;\n");
    put("import std.typecons : Nullable;\n");
    put("import std.stdio;\n");
    put("\n");
  }
}

struct OperationEntry {
  string method;
  OasOperation operation;
}

OperationEntry[] getPathItemOperationEntries(OasPathItem pathItem) {
  return [
      OperationEntry("GET", pathItem.get),
      OperationEntry("PUT", pathItem.put),
      OperationEntry("POST", pathItem.post),
      OperationEntry("DELETE", pathItem.delete_),
      OperationEntry("OPTIONS", pathItem.options),
      OperationEntry("HEAD", pathItem.head),
      OperationEntry("PATCH", pathItem.patch),
      OperationEntry("TRACE", pathItem.trace),
    ];
}

void generatePathItemMethods(
    Appender!string buffer, string path, OasPathItem pathItem, string prefix = "  ") {
  OperationEntry[] operationEntries = getPathItemOperationEntries(pathItem);
  with (buffer) {
    foreach (OperationEntry operationEntry; operationEntries) {
      if (operationEntry.operation is null)
        continue;
      string requestParamType =
          generateRequestParamType(buffer, operationEntry, prefix);
      // The request body type might need to be defined, so that it may be used as an argument to
      // the function that actually performs the request.
      RequestBodyType requestBodyType =
          generateRequestBodyType(buffer, operationEntry, prefix);

      ResponseHandlerType responseHandlerType =
          generateResponseHandlerType(buffer, operationEntry, prefix);

      // The documentation is the same for all methods for a given path.
      writeCommentBlock(
          buffer,
          join(
              [
                pathItem.summary,
                pathItem.description,
                operationEntry.operation.summary,
                operationEntry.operation.description,
                "See_Also: HTTP " ~ operationEntry.method  ~ " `" ~ path ~ "`"
              ],
             "\n\n"),
          prefix,
          100);
      put(prefix ~ "void " ~ operationEntry.operation.operationId.toLowerCamelCase() ~ "(\n");

      // Put the parameters as function arguments.
      if (requestParamType !is null) {
        put(prefix ~ "    ");
        put(requestParamType);
        put(" params,\n");
      }

      // Put the requestBody (if present) argument.
      if (requestBodyType !is null) {
        put(prefix ~ "    ");
        put(requestBodyType.codeType ~ " requestBody,\n");
      }

      // Put the responseHandler (if present) argument.
      if (responseHandlerType !is null) {
        put(prefix ~ "    ");
        put(responseHandlerType.codeType ~ " responseHandler,\n");
      }

      put(prefix ~ "    ) {\n");
      put(prefix ~ "  ApiRequest requestor = new ApiRequest(\n");
      put(prefix ~ "      HTTPMethod." ~ operationEntry.method ~ ",\n");
      put(prefix ~ "      " ~ (pathItem.servers !is null
          ? "\"" ~ pathItem.servers[0].url ~ "\"" : "Servers.getServerUrl()") ~ ",\n");
      put(prefix ~ "      \"" ~ path ~ "\");\n");
      foreach (OasParameter parameter; operationEntry.operation.parameters) {
        string setterMethod;
        if (parameter.in_ == "query") {
          // TODO: Support other encoding mechanisms rather than assuming "deepObject".
          setterMethod = "setQueryParam!(\"deepObject\")";
        } else if (parameter.in_ == "header") {
          setterMethod = "setHeaderParam";
        } else if (parameter.in_ == "path") {
          setterMethod = "setPathParam";
        } else if (parameter.in_ == "cookie") {
          setterMethod = "setCookieParam";
        }
        put(prefix ~ "  if (!params." ~ getVariableName(parameter.name) ~ ".isNull)\n");
        put(prefix ~ "    requestor." ~ setterMethod ~ "(\"" ~ parameter.name ~ "\", params."
            ~ getVariableName(parameter.name) ~ ");\n");
      }
      // Don't forget to set the content-type of the requestBody.
      if (requestBodyType !is null) {
        put(prefix ~ "  requestor.setHeaderParam(\"Content-Type\", \""
            ~ requestBodyType.contentType ~ "\");\n");
      }
      // The security policy may modify the request as well.
      put(prefix ~ "  Security.apply(requestor);\n");
      // Finally let the request execute.
      put(prefix ~ "  requestor.makeRequest(");
      if (requestBodyType is null)
        put("null");
      else
        put("requestBody");
      put(", responseHandler);\n");
      put(prefix ~ "}\n\n");
    }
  }
}

/**
 * Information about the request body for an [OasOperation].
 */
class RequestBodyType {
  /**
   * The type in D-code representing the request body.
   */
  string codeType;
  string contentType;
  OasMediaType mediaType;
}

/**
 * Determine what type the RequestBody is for a request, and if needed, generated.
 */
RequestBodyType generateRequestBodyType(
    Appender!string buffer, OperationEntry operationEntry, string prefix = "  ") {
  if (operationEntry.operation.requestBody is null)
    return null;
  OasRequestBody requestBody = operationEntry.operation.requestBody;

  string contentType;
  OasMediaType mediaType;
  // Take the first defined content type, it is unclear how to resolve multiple types.
  foreach (pair; requestBody.content.byKeyValue()) {
    contentType = pair.key;
    mediaType = pair.value;
    break;
  }

  // TODO: Figure out what to do with `mediaType.encoding`

  string defaultRequestBodyTypeName = operationEntry.operation.operationId ~ "Body";
  RequestBodyType requestBodyType = new RequestBodyType();
  requestBodyType.contentType = contentType;
  requestBodyType.codeType = getSchemaCodeType(mediaType.schema, defaultRequestBodyTypeName);
  requestBodyType.mediaType = mediaType;
  if (requestBodyType.codeType is null)
    return null;

  generateSchemaInnerClasses(buffer, mediaType.schema, prefix, defaultRequestBodyTypeName);

  return requestBodyType;
}

void generateModuleFooter(Appender!string buffer) {
  buffer.put("  mixin AddBuilder!(typeof(this));\n\n");
  buffer.put("}\n");
}

string generateRequestParamType(
    Appender!string buffer, OperationEntry operationEntry, string prefix = "  ") {
  OasParameter[] parameters = operationEntry.operation.parameters;
  if (parameters is null || parameters.length == 0)
    return null;
  string className = toUpperCamelCase(operationEntry.operation.operationId) ~ "Params";
  buffer.put(prefix ~ "static class " ~ className ~ " {\n");
  foreach (OasParameter parameter; operationEntry.operation.parameters) {
    writeCommentBlock(buffer, parameter.description, prefix ~ "  ", 100);
    generateSchemaInnerClasses(buffer, parameter.schema, prefix ~ "  ");
    generatePropertyCode(buffer, parameter.name, parameter.schema, prefix ~ "  ", parameter.required);
  }
  buffer.put(prefix ~ "  mixin AddBuilder!(typeof(this));\n\n");
  buffer.put(prefix ~ "}\n\n");
  return className;
}

class ResponseHandlerType {
  string codeType;
}

/**
 * Based on the request responses and their types, generate a "response handler" class that allows
 * the caller to define handlers that are specific to the response type.
 */
ResponseHandlerType generateResponseHandlerType(
    Appender!string buffer, OperationEntry operationEntry, string prefix = "  ") {
  if (operationEntry.operation.responses is null)
    return null;
  OasResponse[string] responses = operationEntry.operation.responses;
  string typeName = (operationEntry.operation.operationId ~ "ResponseHandler").toUpperCamelCase();
  with (buffer) {
    put(prefix ~ "static class " ~ typeName ~ " : ResponseHandler {\n\n");

    struct ResponseHandlerData {
      string contentType;
      string statusCode;
      string responseSourceType;
      string handlerMethodName;
    }
    ResponseHandlerData[] responseHandlerData;

    // Create a handler method that can be defined for each HTTP status code and its corresponding
    // response body type.
    foreach (string statusCode, OasResponse oasResponse; responses) {
      logDebug("Generating response for operationId=%s statusCode=%s",
          operationEntry.operation.operationId, statusCode);
      // Read the content type and pick out the first media type entry.
      string contentType;
      OasMediaType mediaType;
      foreach (pair; oasResponse.content.byKeyValue()) {
        logDebug("Checking contentType: %s", pair.key);
        if (pair.key.indexOf("/") == -1 || pair.value.schema is null) {
          logDebug("Skipping content type %s due to invalid type or missing schema.", pair.key);
          continue;
        }
        contentType = pair.key;
        mediaType = pair.value;
        break;
      }
      import vibe.data.json : serializeToJsonString;
      logDebug("Found mediaType: %s", serializeToJsonString(mediaType));
      // Determine if an inner class needs to be defined for the type, or if it references an
      // existing schema.
      string defaultResponseSourceType =
          operationEntry.operation.operationId ~ "Response" ~ toUpperCamelCase(statusCode);
      string responseSourceType = (mediaType) ? getSchemaCodeType(mediaType.schema, defaultResponseSourceType) : null;

      // Generate an inner class if needed, otherwise, do nothing.
      if (mediaType) {
        generateSchemaInnerClasses(buffer, mediaType.schema, prefix ~ "  ", defaultResponseSourceType);
      }

      writeCommentBlock(buffer, oasResponse.description, prefix ~ "  ");
      string handlerMethodName = "handleResponse" ~ toUpperCamelCase(statusCode);
      put(prefix ~ "  void delegate(" ~ (responseSourceType ? (responseSourceType ~ " response") : "") ~ ") "
          ~ handlerMethodName ~ ";\n\n");

      // Save data needed to map response codes to methods to call.
      responseHandlerData ~=
          ResponseHandlerData(contentType, statusCode, responseSourceType, handlerMethodName);
    }

    // Generate a handler method that routes to the individual handler methods above.
    put(prefix ~ "  /**\n");
    put(prefix ~ "   * An HTTPResponse handler that routes to a particular handler method.\n");
    put(prefix ~ "   */\n");
    put(prefix ~ "  void handleResponse(HTTPClientResponse res) {\n");
    ResponseHandlerData* defaultHandlerDatum = null;
    foreach (ref ResponseHandlerData datum; responseHandlerData) {
      if (datum.statusCode == "default") {
        defaultHandlerDatum = &datum;
      } else {
        int statusCodeMin = datum.statusCode.tr("x", "0").to!int;
        int statusCodeMax = datum.statusCode.tr("x", "9").to!int;
        put(prefix ~ "    if (res.statusCode >= " ~ statusCodeMin.to!string ~ " && res.statusCode <= "
            ~ statusCodeMax.to!string ~ " && " ~ datum.handlerMethodName ~ " !is null) {\n");
        // TODO: Support additional response body types.
        if (datum.contentType == "application/json") {
          put(prefix ~ "      " ~ datum.handlerMethodName ~ "(deserializeJson!("
              ~ datum.responseSourceType ~ ")(res.readJson()));\n");
          put(prefix ~ "      return;\n");
        } else {
          put(prefix ~ "      writeln(\"Unsupported contentType " ~ datum.contentType ~ ".\");\n");
        }
        put(prefix ~ "    }\n");
      }
    }
    if (defaultHandlerDatum !is null) {
      put(prefix
          ~ "    if (" ~ defaultHandlerDatum.handlerMethodName ~ " !is null) {\n"
          ~ "      " ~ defaultHandlerDatum.handlerMethodName ~ "(deserializeJson!("
          ~ defaultHandlerDatum.responseSourceType ~ ")(res.readJson()));\n"
          ~ "      return;\n"
          ~ "    }\n");
    }
    put(prefix
        ~ "    throw new Exception(\"Unhandled response status code: \"\n"
        ~ "        ~ res.statusCode.to!string\n"
        ~ "        ~ \", Body: \" ~ res.bodyReader().readAllUTF8());\n");
    put(prefix ~ "  }\n\n");
    put(prefix ~ "  mixin AddBuilder!(typeof(this));\n\n");
    put(prefix ~ "}\n\n");
  }

  ResponseHandlerType responseHandlerType = new ResponseHandlerType;
  responseHandlerType.codeType = typeName;
  return responseHandlerType;
}
