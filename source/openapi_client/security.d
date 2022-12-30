module openapi_client.security;

import std.array : appender, split, Appender;
import std.file : mkdir, mkdirRecurse, write;
import std.path : buildNormalizedPath, dirName;
import std.string : tr;
import std.stdio : writeln;

import openapi : OasDocument, OasServer, OasServerVariable, OasSecurityScheme;
import openapi_client.util : wordWrapText, toUpperCamelCase;


/**
 * Writes a utility class containing information about the REST API servers to contact.
 */
void writeSecurityFiles(OasDocument oasDocument, string targetDir, string packageRoot) {
  auto buffer = appender!string();
  string moduleName = packageRoot ~ ".security";
  with (buffer) {
    put("// File automatically generated from OpenAPI spec.\n");
    put("module " ~ moduleName ~ ";\n");
    put("\n");
    put("import openapi_client.apirequest : ApiRequest;\n");
    put("import openapi;\n");
    put("\n");
    put("import std.base64 : Base64;\n");
    put("import std.conv : to;\n");
    put("import std.array : Appender;\n");
    put("\n");
    put("class Security {\n\n");
    put("  /**\n");
    put("   * The currently active security method to be applied to requests.\n");
    put("   */\n");
    put("  static void delegate(ApiRequest) applySecurityF = null;\n\n");
    foreach (string securitySchemeName, OasSecurityScheme securityScheme;
        oasDocument.components.securitySchemes) {
      if (securityScheme.type == "http") {
        if (securityScheme.scheme == "basic") {
          put("  /**\n");
          put("   * Enable and configure the use of HTTP Basic Authentication.\n");
          put("   *\n");
          put("   * See_Also: https://en.wikipedia.org/wiki/Basic_access_authentication\n");
          put("   */\n");
          put("  static void configure" ~ toUpperCamelCase(securitySchemeName)
              ~ "(string username, string password) {\n");
          put("    applySecurityF = (ApiRequest request) {\n");
          put("      auto buffer = new Appender!string();\n");
          put("      auto credentials = cast(immutable(ubyte)[])(username ~ \":\" ~ password);\n");
          put("      Base64.encode(credentials, buffer);\n");
          put("      request.setHeaderParam(\"Authorization\", \"Basic \" ~ buffer.data);\n");
          put("    };\n");
          put("  }\n\n");
        } else if (securityScheme.scheme == "bearer") {
          put("  /**\n");
          put("   * Enable and configure the use of an OAuth2.0 Bearer token for HTTP Authentication.\n");
          put("   *\n");
          put("   * See_Also: https://datatracker.ietf.org/doc/html/rfc6750\n");
          put("   */\n");
          put("  static void configure" ~ toUpperCamelCase(securitySchemeName)
              ~ "(string token) {\n");
          put("    applySecurityF = (ApiRequest request) {\n");
          put("      request.setHeaderParam(\"Authorization\", \"Bearer \" ~ token);\n");
          put("    };\n");
          put("  }\n\n");
        } else {
          writeln("Warning: Unsupported security scheme type=http, scheme=", securityScheme.scheme);
        }
      } else {
        writeln("Warning: Unsupported security scheme type '", securityScheme.type, "'.");
      }
    }
    put("  /**\n");
    put("   * Apply the currently selected security method to a request.\n");
    put("   */\n");
    put("  static void apply(ApiRequest request) {\n");
    put("    if (applySecurityF !is null)\n");
    put("      applySecurityF(request);\n");
    put("  }\n\n");
    put("}\n");
  }
  string fileName = buildNormalizedPath(targetDir, tr(moduleName, ".", "/") ~ ".d");
  mkdirRecurse(dirName(fileName));
  write(fileName, buffer[]);
}
