import openapi : OasDocument, OasPathItem, OasOperation, OasParameter;
import vibe.data.json : Json, parseJsonString, deserializeJson;
import vibe.http.client : requestHTTP, HTTPClientRequest, HTTPClientResponse, HTTPClientSettings;
import vibe.http.common : HTTPMethod, HTTPStatusException;
import std.file : readText;
import std.stdio : writeln, File;
import std.algorithm : min;

import openapi_client.schemas : writeSchemaFiles;
import openapi_client.util;

void main() {
  OasDocument oasDocument = readText("json/spec3.json")
      .parseJsonString()
      .deserializeJson!OasDocument;

  writeSchemaFiles(oasDocument, "source", "stripe.client");

  ////
  // Iterate Paths and Operations
  ////
  // foreach (string path, OasPathItem pathItem; oasDocument.paths) {
  //   writeln("Found path: ", path);
  //   if (pathItem.get !is null) {
  //     OasOperation op = pathItem.get;
  //     writeln("  /**");
  //     foreach (string line; wordWrapText(op.description, 70)) {
  //       writeln("   * " ~ line);
  //     }
  //     if (op.parameters.length > 0) {
  //       writeln("   *");
  //       writeln("   * Params:");
  //       foreach (OasParameter parameter; op.parameters) {
  //         string[] descriptionLines = [""];
  //         if (parameter.description != null) {
  //           descriptionLines = wordWrapText(parameter.description, 65);
  //         }
  //         writeln("   *   ", parameter.name, " = ", descriptionLines[0]);
  //         for (size_t i = 1; i < descriptionLines.length; i++) {
  //           writeln("   *     ", descriptionLines[i]);
  //         }
  //       }
  //     }
  //     writeln("   */");
  //     writeln("  void ", op.operationId, "(");
  //     writeln("  ) {");
  //     writeln("    requestHTTP(\"", path, "\",");
  //     writeln("        (scope req) {");
  //     writeln("          req.method = HTTPMethod.GET;");
  //     writeln("  }");
  //   }
  //   if (pathItem.put !is null) {
  //     OasOperation op = pathItem.put;
  //   }
  //   if (pathItem.post !is null) {
  //     OasOperation op = pathItem.post;
  //   }
  //   if (pathItem.delete_ !is null) {
  //     OasOperation op = pathItem.delete_;
  //   }
  //   if (pathItem.options !is null) {
  //     OasOperation op = pathItem.options;
  //   }
  //   if (pathItem.head !is null) {
  //     OasOperation op = pathItem.head;
  //   }
  //   if (pathItem.trace !is null) {
  //     OasOperation op = pathItem.trace;
  //   }
  // }
}
