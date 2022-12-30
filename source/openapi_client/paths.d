module openapi_client.paths;

import vibe.data.json : Json, deserializeJson;

import std.container.rbtree : RedBlackTree;
import std.file : mkdir, mkdirRecurse, write;
import std.array : appender, split, Appender;
import std.algorithm : skipOver;
import std.path : buildNormalizedPath, dirName;
import std.string : tr, capitalize;
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
    string moduleName = pathRoot[1..$].tr("/", "_") ~ "_service";
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
      if (requestBody !is null && requestBody.required == true) {
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

  foreach (string schemaRef; refs) {
    string schemaName = getSchemaNameFromRef(schemaRef);
    with (buffer) {
      put("import ");
      put(getModuleNameFromSchemaName(packageRoot, schemaName));
      put(" : ");
      put(getClassNameFromSchemaName(schemaName));
      put(";\n");
    }
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
    put("import vibe.data.json : Json, deserializeJson;\n");
    put("\n");
    put("import " ~ packageRoot ~ ".servers : Servers;\n");
    put("import " ~ packageRoot ~ ".security : Security;\n");
    put("import openapi_client.apirequest : ApiRequest;\n");
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
      writeCommentBlock(buffer, pathItem.description, prefix, 100);
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
        put(responseHandlerType.codeType ~ " responseHandler = null,\n");
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
          setterMethod = "setQueryParam";
        } else if (parameter.in_ == "header") {
          setterMethod = "setHeaderParam";
        } else if (parameter.in_ == "path") {
          setterMethod = "setPathParam";
        } else if (parameter.in_ == "cookie") {
          setterMethod = "setCookieParam";
        }
        put(prefix ~ "  if (!params." ~ getVariableName(parameter.name) ~ ".isNull)\n");
        put(prefix ~ "    requestor." ~ setterMethod ~ "(\"" ~ parameter.name ~ "\", params."
            ~ getVariableName(parameter.name) ~ ".get.to!string);\n");
      }
      put(prefix ~ "  Security.apply(requestor);\n");
      put(prefix ~ "  requestor.makeRequest(null, (Json res) { writeln(res); });\n");
      put(prefix ~ "}\n\n");
    }
  }
}

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
  if (requestBody.required == false)
    return null;

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

  generateSchemaInnerClasses(buffer, mediaType.schema, prefix, defaultRequestBodyTypeName);

  return requestBodyType;
}

void generateModuleFooter(Appender!string buffer) {
  buffer.put("}\n");
}

string generateRequestParamType(
    Appender!string buffer, OperationEntry operationEntry, string prefix = "  ") {
  OasParameter[] parameters = operationEntry.operation.parameters;
  if (parameters is null || parameters.length == 0)
    return null;
  string className = operationEntry.operation.operationId ~ "Params";
  buffer.put(prefix ~ "static class " ~ className ~ "{\n");
  foreach (OasParameter parameter; operationEntry.operation.parameters) {
    writeCommentBlock(buffer, parameter.description, prefix ~ "  ", 100);
    if (parameter.schema !is null) {
      generateSchemaInnerClasses(buffer, parameter.schema, prefix ~ "  ");
      // Nullable is needed to allow unset parameters to be excluded from the request.
      buffer.put(prefix ~ "  Nullable!(");
      buffer.put(getSchemaCodeType(parameter.schema, null));
      buffer.put(")");
    } else {
      // Nullable is needed to allow unset parameters to be excluded from the request.
      buffer.put(prefix ~ "  Nullable!(");
      buffer.put("string");
      buffer.put(")");
    }
    buffer.put(" " ~ getVariableName(parameter.name) ~ ";\n\n");
  }
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
  string typeName = operationEntry.operation.operationId ~ "ResponseHandler";
  with (buffer) {
    put(prefix ~ "static class " ~ typeName ~ " {\n\n");
    foreach (string responseCode, OasResponse oasResponse; responses) {
      // Read the content type and pick out the first media type entry.
      string contentType;
      OasMediaType mediaType;
      foreach (pair; oasResponse.content.byKeyValue()) {
        contentType = pair.key;
        mediaType = pair.value;
        break;
      }
      // Determine if an inner class needs to be defined for the type, or if it references an
      // existing schema.
      string defaultResponseCodeType =
          operationEntry.operation.operationId ~ "Response" ~ responseCode;
      string responseCodeType = getSchemaCodeType(mediaType.schema, defaultResponseCodeType);
      // TODO: Save data needed to map response codes to methods to call.

      // Generate an inner class if needed, otherwise, do nothing.
      generateSchemaInnerClasses(buffer, mediaType.schema, prefix ~ "  ", defaultResponseCodeType);

      writeCommentBlock(buffer, oasResponse.description, prefix ~ "  ");
      put(prefix ~ "  void delegate(" ~ responseCodeType ~ " response) handleResponse" ~ responseCode ~ ";\n\n");
    }
    put(prefix ~ "}\n\n");
  }

  ResponseHandlerType responseHandlerType = new ResponseHandlerType;
  responseHandlerType.codeType = typeName;
  // TODO: Save data needed to map response codes to methods to call.
  return responseHandlerType;
}
