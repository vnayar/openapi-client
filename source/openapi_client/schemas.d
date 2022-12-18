module openapi_client.schemas;

import vibe.data.json : Json, deserializeJson;

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
  return toUpperCamelCase(schemaName).split(".").tail(1)[0];
}

void writeSchemaFiles(OasDocument oasDocument, string targetDir) {
  foreach (string schemaName, OasSchema schema; oasDocument.components.schemas) {
    JsonSchema jsonSchema = new JsonSchema();
    jsonSchema.schemaName = schemaName;
    jsonSchema.moduleName = schemaName;
    jsonSchema.className = getClassNameFromSchemaName(schemaName);
    jsonSchema.schema = schema;
    string ref_ = "#/components/schemas/" ~ schemaName;
    jsonSchemaByRef[ref_] = jsonSchema;
    writeln("Added reference: ", ref_);

    generateModuleCode(targetDir, jsonSchema, schema);
  }
}

void generateModuleCode(string targetDir, JsonSchema jsonSchema, OasSchema oasSchema) {
  auto buffer = appender!string();
  with (buffer) {
    put("// File automatically generated from OpenAPI spec.\n");
    put("module " ~ jsonSchema.moduleName ~ ";\n");
    put("\n");
    // Display the class description and declare it.
    generateClassCode(buffer, oasSchema.description, jsonSchema.className, oasSchema.properties);
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
      if (propertySchema.description !is null) {
        put("  /**\n");
        foreach (string line; wordWrapText(propertySchema.description, 73)) {
          put("   * ");
          put(line);
          put("\n");
        }
        put("   */\n");
      }
      put("  ");
      try {
        put(getCodeType(propertySchema) ~ " " ~ propertyName ~ ";\n\n");
      } catch (Exception e) {
        writeln("Error writing className=", className, ", propertyName=", propertyName,
            ", propertyDescription=", propertySchema.description);
        throw e;
      }
    }
    put("}\n");
  }
}

/**
 * Converts a given OasSchema type into the equivalent type in source code.
 */
string getCodeType(OasSchema schema) {
  // This could be a reference to an existing type.
  if (schema.ref_ !is null) {
    string schemaName = schema.ref_;
    if (!skipOver(schemaName, "#/components/schemas/"))
      throw new Exception("External references not supported! " ~ schema.ref_);
    // Return the full module_name.class_name name to avoid namespace collisions.
    return schemaName ~ "." ~ getClassNameFromSchemaName(schemaName);
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
      return getCodeType(schema.items) ~ "[]";
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
        return getCodeType(propertySchema) ~ "[string]";
      }
    }
  }
  // Perhaps we can infer the type from the "anyOf" validation.
  else if (schema.anyOf !is null && schema.anyOf.length > 0) {
    return getCodeType(schema.anyOf[0]);
  }
  throw new Exception("No code type for Schema: " ~ schema.type ~ " " ~ schema.ref_);
}
