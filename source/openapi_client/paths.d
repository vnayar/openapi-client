module openapi_client.paths;

import vibe.data.json : Json, deserializeJson;

import std.container.rbtree : RedBlackTree;
import std.file : mkdir, mkdirRecurse, write;
import std.array : appender, split, Appender;
import std.algorithm : skipOver;
import std.path : buildNormalizedPath, dirName;
import std.string : tr;
import std.range : tail, takeOne;
import std.stdio : writeln;
import std.regex : regex, replaceAll;

import openapi : OasDocument, OasPathItem, OasOperation, OasParameter;
import openapi_client.util : toUpperCamelCase, wordWrapText;

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
    auto buffer = appender!string();
    generateModuleHeader(buffer, packageName, pathRoot);
    foreach (PathEntry pathEntry; pathEntries) {
      generatePathItemMethods(buffer, pathEntry.path, pathEntry.pathItem);
    }
    generateModuleFooter(buffer);
  }
}

/**
 * Writes the beginning of a class file for a service that can access a REST API.
 */
void generateModuleHeader(
    Appender!string buffer, string packageName, string pathRoot) {
  string moduleName = pathRoot.tr("/", "_") ~ "_service";
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
    put("/**\n");
    put(" * Service to make REST API calls to paths beginning with: " ~ pathRoot ~ "\n");
    put(" */\n");
    put("class " ~ className ~ " {\n");
  }
}

void generatePathItemMethods(
    Appender!string buffer, string path, OasPathItem pathItem, string prefix = "  ") {
  struct OperationEntry {
    string method;
    OasOperation operation;
  }
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
      put(prefix ~ "void " ~ operationEntry.operation.operationId ~ "() {\n");
      // Call requestHTTP with the correct URL.
      put(prefix ~ "  requestHTTP(Servers.getServerUrl(");
      put(pathItem.servers !is null ? "\"" ~ pathItem.servers[0].url ~ "\"" : "null");
      put(",\n");
      // Update the HTTPClientRequest to match the OasOperation.
      put(prefix ~ "      (scope HTTPClientRequest req) {\n");
      put(prefix ~ "        req.method = HTTPMethod." ~ operationEntry.method ~ ";\n");
      foreach (OasParameter parameter; operationEntry.operation.parameters) {
        generatePathParameter(buffer, parameter, prefix ~ "        ");
      }
      put(prefix ~ "      },\n");
      put(prefix ~ "      (scope HTTPClientResponse res) {\n");
      put(prefix ~ "      }\n");
      put(prefix ~ "      );\n");
      put(prefix ~ "}\n");
    }
  }
}

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
