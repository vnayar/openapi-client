module openapi_client.schemas;

import vibe.data.json : Json, deserializeJson;

import std.container.rbtree : RedBlackTree;
import std.file : mkdir, mkdirRecurse, write;
import std.array : appender, split, Appender;
import std.algorithm : skipOver;
import std.path : buildNormalizedPath, dirName;
import std.string : tr;
import std.range : tail, takeOne;
import std.stdio : writeln;

import openapi : OasDocument, OasSchema;
import openapi_client.util : toUpperCamelCase, wordWrapText;

class JsonSchema {
  string schemaName;
  string moduleName;
  string className;
  OasSchema schema;
}

JsonSchema[string] jsonSchemaByRef;

/**
 * In our code generation, the module is a file name which contains a class whose
 * name is in CamelCase.
 */
string getClassNameFromSchemaName(string schemaName) {
  immutable RedBlackTree!string RESERVED_CLASSES = new RedBlackTree!string([
    "Error"
  ]);
  string className = toUpperCamelCase(schemaName).split(".").tail(1)[0];
  if (className in RESERVED_CLASSES)
    return className ~ "_";
  else
    return className;
}

/**
 * Produce the full module name for a given schemaName and package.
 *
 * Params:
 *   packageName = The D base-package for the modules, e.g. "stripe.openapi".
 *   schemaName = The OpenAPI Spec schema name, e.g. "transfer_data".
 */
string getModuleNameFromSchemaName(string packageName, string schemaName) {
  if (packageName is null)
    return schemaName;
  else
    return packageName ~ "." ~ schemaName;
}

string getSchemaNameFromRef(string ref_) {
  string schemaName = ref_;
  if (!skipOver(schemaName, "#/components/schemas/"))
    throw new Exception("External references not supported! " ~ ref_);
  return schemaName;
}

void writeSchemaFiles(OasDocument oasDocument, string targetDir, string packageName) {
  foreach (string schemaName, OasSchema schema; oasDocument.components.schemas) {
    JsonSchema jsonSchema = new JsonSchema();
    jsonSchema.schemaName = schemaName;
    jsonSchema.moduleName = getModuleNameFromSchemaName(packageName, schemaName);
    jsonSchema.className = getClassNameFromSchemaName(schemaName);
    jsonSchema.schema = schema;
    string ref_ = "#/components/schemas/" ~ schemaName;
    jsonSchemaByRef[ref_] = jsonSchema;
    writeln("Added reference: ", ref_);

    // Use `scope` to create our class on the stack rather than the heap.
    scope generator = new ModuleCodeGenerator();
    generator.generateModuleCode(targetDir, jsonSchema, schema, packageName);
  }
}

class ModuleCodeGenerator {

  static immutable RedBlackTree!string RESERVED_WORDS = new RedBlackTree!string([
        "abstract",
        "alias",
        "align",
        "asm",
        "assert",
        "auto",
        "bool",
        "break",
        "byte",
        "case",
        "catch",
        "cast",
        "char",
        "class",
        "const",
        "continue",
        "dchar",
        "debug",
        "delegate",
        "double",
        "dstring",
        "else",
        "enum",
        "export",
        "extern",
        "finally",
        "float",
        "for",
        "foreach",
        "foreach_reverse",
        "function",
        "if",
        "in",
        "invariant",
        "immutable",
        "import",
        "int",
        "lazy",
        "long",
        "mixin",
        "module",
        "new",
        "nothrow",
        "package",
        "private",
        "public",
        "pure",
        "real",
        "scope",
        "string",
        "struct",
        "switch",
        "ulong",
        "union",
        "version",
        "wchar",
        "while",
        "with",
        "wstring",
      ]);

  /**
   * A list of references to other schemas encountered while writing the module.
   *
   * E.g. "account_link"
   *
   * Using a red-black-tree allows us to keep imports unique and sorted.
   */
  RedBlackTree!string importedSchemaNames;

  this() {
    importedSchemaNames = new RedBlackTree!string();
  }

  void generateModuleCode(string targetDir, JsonSchema jsonSchema, OasSchema oasSchema, string packageName) {
    auto buffer = appender!string();
    with (buffer) {
      put("// File automatically generated from OpenAPI spec.\n");
      put("module " ~ jsonSchema.moduleName ~ ";\n\n");
      // We generate the class in a separate buffer, because it's production may add dependencies.
      auto classBuffer = appender!string();
      generateClassCode(
          classBuffer, oasSchema.description, jsonSchema.className, oasSchema.properties);

      // While generating the class code, we accumulated external references to import.
      foreach (string importedSchemaName; importedSchemaNames[]) {
        put("import ");
        put(getModuleNameFromSchemaName(packageName, importedSchemaName));
        put(" : ");
        put(getClassNameFromSchemaName(importedSchemaName));
        put(";\n");
      }
      put("\n");

      // Finally add our class code to the module file.
      put(classBuffer[]);
    }
    string fileName = buildNormalizedPath(targetDir, tr(jsonSchema.moduleName, ".", "/") ~ ".d");
    mkdirRecurse(dirName(fileName));
    write(fileName, buffer[]);
  }

  void generateClassCode(
      Appender!string buffer, string description, string className, OasSchema[string] properties) {
    with (buffer) {
      // Display the class description and declare it.
      put("/**\n");
      foreach (string line; wordWrapText(description, 75)) {
        put(" * ");
        put(line);
        put("\n");
      }
      put(" */\n");
      put("class " ~ className ~ " {\n");
      // Define individual properties of the class.
      foreach (string propertyName, OasSchema propertySchema; properties) {
        try {
          generatePropertyInnerClasses(buffer, propertySchema, "  ");
          generatePropertyCode(buffer, propertyName, propertySchema, "  ");
        } catch (Exception e) {
          writeln("Error writing className=", className);
          throw e;
        }
      }
      put("}\n");
    }
  }

  /**
   * Produce code for a class declaring a named property based on an [OasSchema] for the property.
   */
  void generatePropertyCode(
      Appender!string buffer, string propertyName, OasSchema propertySchema, string prefix = "  ") {
    if (propertySchema.description !is null) {
      buffer.put(prefix);
      buffer.put("/**\n");
      foreach (string line; wordWrapText(propertySchema.description, 73)) {
        buffer.put(prefix);
        buffer.put(" * ");
        buffer.put(line);
        buffer.put("\n");
      }
      buffer.put(prefix);
      buffer.put(" */\n");
    }
    buffer.put(prefix);
    try {
      buffer.put(getSchemaCodeType(propertySchema) ~ " " ~ getVariableName(propertyName) ~ ";\n\n");
    } catch (Exception e) {
      writeln("Error writing propertyName=", propertyName,
          ", propertyDescription=", propertySchema.description);
      throw e;
    }
  }

  /**
   * Not every propertyName to be found in an OpenAPI Specification Document can be used to a
   * variable name in code. E.g. the name "scope" is a reserved word in D, and must be replaced with
   * "scope_".
   */
  static string getVariableName(string propertyName) {
    if (propertyName in RESERVED_WORDS)
      return propertyName ~ "_";
    else
      return propertyName;
  }

  /**
   * Some OasSchema types refer to unnamed objects that have a fixed set of
   * parameters. The best representation of this in D is a named class.
   *
   * Most types, like a simple "integer" or "string" will not generate any inner classes, but a few
   * cases will, such as "object" with a specific set of valid "properties".
   */
  void generatePropertyInnerClasses(Appender!string buffer, OasSchema schema, string prefix="  ") {
    if (schema.type == "object" && schema.properties !is null) {
      if (schema.additionalProperties.type == Json.Type.Undefined
          || (schema.additionalProperties.type == Json.Type.Bool
              && schema.additionalProperties.get!bool == false)) {
        // We will have to make a class/struct out of this type from its name.
        if (schema.title is null)
          throw new Exception("Creating a Inner Class for property requires a title!");
        buffer.put(prefix);
        buffer.put("static class " ~ schema.title ~ " {\n");
        foreach (string propertyName, OasSchema propertySchema; schema.properties) {
          generatePropertyInnerClasses(buffer, propertySchema, prefix ~ "  ");
          generatePropertyCode(buffer, propertyName, propertySchema, prefix ~ "  ");
        }
        buffer.put(prefix);
        buffer.put("}\n");
      }
    }
  }

  /**
   * Converts a given [OasSchema] type into the equivalent type in source code.
   */
  string getSchemaCodeType(OasSchema schema) {
    // This could be a reference to an existing type.
    if (schema.ref_ !is null) {
      string schemaName = getSchemaNameFromRef(schema.ref_);
      // Save a list of references external to the module requiring imports.
      importedSchemaNames.insert(schemaName);
      // Resolving this class name depends on having an import statement.
      return getClassNameFromSchemaName(schemaName);
    }
    // First check if we have a primitive type.
    else if (schema.type !is null) {
      if (schema.type == "integer") {
        if (schema.format == "int32")
          return "int";
        else if (schema.format == "int64")
          return "long";
        else if (schema.format == "unix-time")
          return "long";
        return "int";
      } else if (schema.type == "number") {
        if (schema.format == "float")
          return "float";
        else if (schema.format == "double")
          return "double";
        return "float";
      } else if (schema.type == "boolean") {
        return "bool";
      } else if (schema.type == "string") {
        return "string";
      } else if (schema.type == "array") {
        return getSchemaCodeType(schema.items) ~ "[]";
      } else if (schema.type == "object") {
        // If we are missing both properties and additionalProperties, we assume a generic string[string] object.
        if (schema.properties is null && schema.additionalProperties.type == Json.Type.Undefined) {
          return "string[string]";
        }
        // If additionalProperties is false or missing, then the fields in properties must be
        // complete, we can make a class or struct.
        else if (schema.additionalProperties.type == Json.Type.Undefined
            || (schema.additionalProperties.type == Json.Type.Bool
                && schema.additionalProperties.get!bool == false)) {
          // We will have to make a class/struct out of this type from its name.
          if (schema.title is null)
            throw new Exception("Creating a named object type requires a title!");
          else
            writeln("-- Creating inner class '", schema.title, "'");
          return schema.title;
        }
        // If additionalProperties is an object, it's a schema for the data type, but any number of
        // fields may exist.
        else if (schema.additionalProperties.type == Json.Type.Object) {
          OasSchema propertySchema = deserializeJson!OasSchema(schema.additionalProperties);
          return getSchemaCodeType(propertySchema) ~ "[string]";
        }
      }
    }
    // Perhaps we can infer the type from the "anyOf" validation.
    else if (schema.anyOf !is null && schema.anyOf.length > 0) {
      return getSchemaCodeType(schema.anyOf[0]);
    }
    throw new Exception("No code type for Schema: " ~ schema.type ~ " " ~ schema.ref_);
  }

}
