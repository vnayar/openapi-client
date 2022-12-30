module openapi_client.servers;

import std.array : appender, split, Appender;
import std.file : mkdir, mkdirRecurse, write;
import std.path : buildNormalizedPath, dirName;
import std.string : tr;

import openapi : OasDocument, OasServer, OasServerVariable;
import openapi_client.util : wordWrapText, toUpperCamelCase;

/**
 * Writes a utility class containing information about the REST API servers to contact.
 */
void writeServerFiles(OasDocument oasDocument, string targetDir, string packageRoot) {
  auto buffer = appender!string();
  string moduleName = packageRoot ~ ".servers";
  with (buffer) {
    put("// File automatically generated from OpenAPI spec.\n");
    put("module " ~ moduleName ~ ";\n\n");
    put("import openapi_client.util : resolveTemplate;\n");
    put("import std.stdio : writeln;\n");
    put("\n");
    put("class Servers {\n");
    // For now, only support a single URL, because it is unclear what to do if each server has
    // different parameters.
    put("  /**\n");
    put("   * The server URLs to contact the service with.\n");
    put("   * The URL may use named path-parameters within curly braces,\n");
    put("   * e.g. \"https://example.com/{version}/\".\n");
    put("   */\n");
    put("  static string serverUrl = \"");
    put(oasDocument.servers[0].url);
    put("\";\n\n");

    // Parameters that will be substituted into the serverURL.
    put("  /**\n");
    put("   * Parameters that will be substituted into the serverURL.\n");
    put("   */\n");
    put("  static string[string] serverParams;\n\n");
    put("  static this() {\n");
    put("    serverParams = [\n");
    put("      \"none\": \"none\",\n");
    foreach (string name, OasServerVariable variable; oasDocument.servers[0].variables) {
      put("      \"" ~ name ~ "\": \"" ~ variable.default_ ~ "\",\n");
    }
    put("    ];\n");
    put("  }\n\n");
    // Documented methods to set the values for these parameters.
    foreach (string name, OasServerVariable variable; oasDocument.servers[0].variables) {
      put("  /**\n");
      put("   * Server URL Parameter: " ~ name ~ "\n");
      foreach (string line; wordWrapText(variable.description, 95)) {
        put("   * ");
        put(line);
        put("\n");
      }
      put("   * Valid values include:\n");
      foreach (string validValue; variable.enum_) {
        put("   * - " ~ validValue ~ "\n");
      }
      put("   */\n");
      put("  static void setParam" ~ toUpperCamelCase(name) ~ "(string value) {\n");
      put("    serverParams[\"" ~ name ~ "\"] = value;\n");
      put("  }\n\n");
    }
    // Resolve the server URL using the current values of its parameters.
    put("  /**\n");
    put("   * Chooses a url an OasPathItem given both path-specific and general servers.\n");
    put("   */\n");
    put("  static string getServerUrl() {\n");
    put("    writeln(\"getServerUrl 0: serverUrl=\", serverUrl);\n");
    put("    writeln(\"getServerUrl 1: resolve=\", resolveTemplate(serverUrl, serverParams));\n");
    put("    return resolveTemplate(serverUrl, serverParams);\n");
    put("  }\n\n");
    put("}\n");
  }
  string fileName = buildNormalizedPath(targetDir, tr(moduleName, ".", "/") ~ ".d");
  mkdirRecurse(dirName(fileName));
  write(fileName, buffer[]);
}
