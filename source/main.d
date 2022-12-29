import openapi : OasDocument, OasPathItem, OasOperation, OasParameter;
import vibe.data.json : Json, parseJsonString, deserializeJson;
import vibe.http.client : requestHTTP, HTTPClientRequest, HTTPClientResponse, HTTPClientSettings;
import vibe.http.common : HTTPMethod, HTTPStatusException;
import vibe.core.args : readOption, finalizeCommandLineOptions;
import std.file : readText;
import std.stdio : writeln, File;
import std.algorithm : min;

import openapi_client.schemas : writeSchemaFiles;
import openapi_client.servers : writeServerFiles;
import openapi_client.paths : writePathFiles;
import openapi_client.security : writeSecurityFiles;
import openapi_client.util;

void main() {
  string openApiSpec = "json/spec3.json";
  readOption("openApiSpec|o", &openApiSpec,
      "The path to a JSON-formatted OpenAPI Specification to generate a client for. Default: json/spec3.json");
  string targetDir = "source";
  readOption("targetDir|t", &targetDir,
      "The target directory in which to generate source files. Default: source");
  string packageRoot = "apiclient";
  readOption("packageRoot|p", &packageRoot,
      "The package name under which to generate a client. Default: apiclient");
  if (!finalizeCommandLineOptions())
    return;

  OasDocument oasDocument = readText(openApiSpec)
      .parseJsonString()
      .deserializeJson!OasDocument;

  writeSchemaFiles(oasDocument, targetDir, packageRoot);
  writeServerFiles(oasDocument, targetDir, packageRoot);
  writeSecurityFiles(oasDocument, targetDir, packageRoot);
  writePathFiles(oasDocument, targetDir, packageRoot);
}
