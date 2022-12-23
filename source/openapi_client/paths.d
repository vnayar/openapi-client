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

import openapi : OasDocument, OasPathItem, OasOperation, OasParameter, OasMediaType, OasRequestBody;
import openapi_client.schemas : generateSchemaInnerClasses, getSchemaCodeType, getVariableName;
import openapi_client.util : toUpperCamelCase, toLowerCamelCase, wordWrapText;

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
void writePathFiles(OasDocument oasDocument, string targetDir, string packageName) {
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
    generateModuleHeader(buffer, packageName, moduleName, pathRoot);
    foreach (PathEntry pathEntry; pathEntries) {
      writeln("  - Generating methods for ", pathEntry.path);
      generatePathItemMethods(buffer, pathEntry.path, pathEntry.pathItem);
    }
    generateModuleFooter(buffer);

    string fileName =
        buildNormalizedPath(targetDir, tr(packageName ~ "." ~ moduleName, ".", "/") ~ ".d");
    writeln("Writing file: ", fileName);
    mkdirRecurse(dirName(fileName));
    write(fileName, buffer[]);
  }
}

/**
 * Writes the beginning of a class file for a service that can access a REST API.
 */
void generateModuleHeader(
    Appender!string buffer, string packageName, string moduleName, string pathRoot) {
  string className = moduleName.toUpperCamelCase();
  with (buffer) {
    put("// File automatically generated from OpenAPI spec.\n");
    put("module " ~ packageName ~ "." ~ moduleName ~ ";\n");
    put("\n");
    put("import vibe.http.client : requestHTTP, HTTPClientRequest, HTTPClientResponse;\n");
    put("import vibe.http.common : HTTPMethod;\n");
    put("import vibe.stream.operations : readAllUTF8;\n");
    put("\n");
    put("import " ~ packageName ~ ".servers : Servers;\n");
    put("\n");
    // TODO: Generate imports that originate from the data types created here.
    put("/**\n");
    put(" * Service to make REST API calls to paths beginning with: " ~ pathRoot ~ "\n");
    put(" */\n");
    put("class " ~ className ~ " {\n");
  }
}

struct OperationEntry {
  string method;
  OasOperation operation;
}

void generatePathItemMethods(
    Appender!string buffer, string path, OasPathItem pathItem, string prefix = "  ") {
  OperationEntry[] operationEntries = [
      OperationEntry("GET", pathItem.get),
      OperationEntry("PUT", pathItem.put),
      OperationEntry("POST", pathItem.post),
      OperationEntry("DELETE", pathItem.delete_),
      OperationEntry("OPTIONS", pathItem.options),
      OperationEntry("HEAD", pathItem.head),
      OperationEntry("PATCH", pathItem.patch),
      OperationEntry("TRACE", pathItem.trace),
    ];
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

      // The documentation is the same for all methods for a given path.
      put(prefix);
      put("/**\n");
      foreach (string line; wordWrapText(pathItem.description, 95)) {
        put(prefix);
        put(" * ");
        put(line);
        put("\n");
      }
      put(prefix);
      put(" */\n");
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

      put(prefix ~ "    ) {\n");
      // Update the HTTPClientRequest to match the OasOperation.
      // Call requestHTTP with the correct URL.
      put(prefix ~ "  requestHTTP(\n");
      put(prefix ~ "      ");
      put(pathItem.servers !is null ? "\"" ~ pathItem.servers[0].url ~ "\"" : "Servers.getServerUrl()");
      put(",\n");
      put(prefix ~ "      (scope HTTPClientRequest req) {\n");
      put(prefix ~ "        req.method = HTTPMethod." ~ operationEntry.method ~ ";\n");
      //foreach (OasParameter parameter; operationEntry.operation.parameters) {
      //  generatePathParameter(buffer, parameter, prefix ~ "        ");
      //}
      put(prefix ~ "      },\n");
      put(prefix ~ "      (scope HTTPClientResponse res) {\n");
      put(prefix ~ "      });\n");
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

/**
 * In the OpenAPI Specification, parameters are values that are sent with the request in either the
 * query-string, a header, in the path, or in a cookie. They do not include values sent with the
 * request that are in the request body.
 */
void generatePathParameter(Appender!string buffer, OasParameter parameter, string prefix) {
  if (parameter.in_ == "query") {
    // TODO: Resume here.
  } else {
    throw new Exception("Unsupported parameter.in type '" ~ parameter.in_ ~ "'!");
  }
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
    buffer.put(prefix ~ "  /**\n");
    foreach (string line; wordWrapText(parameter.description, 95)) {
      buffer.put(prefix ~ "   * ");
      buffer.put(line);
      buffer.put("\n");
    }
    buffer.put(prefix ~ "   */\n");
    buffer.put(prefix ~ "  ");
    if (parameter.schema !is null)
      buffer.put(getSchemaCodeType(parameter.schema, null));
    else
      buffer.put("string");
    buffer.put(" " ~ getVariableName(parameter.name) ~ ";\n\n");
  }
  buffer.put(prefix ~ "}\n\n");
  return className;
}
