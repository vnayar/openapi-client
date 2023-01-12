/**
 * Methods and classes used to generate classes and other data structures representing common
 * schemas in an OpenAPI Specification.
 *
 * See_Also: https://spec.openapis.org/oas/latest.html#schema-object
 */
module openapi_client.schemas;

import vibe.data.json : Json, deserializeJson;
import vibe.core.log : logDebug;

import std.container.rbtree : RedBlackTree;
import std.file : mkdir, mkdirRecurse, write;
import std.array : array, appender, split, Appender;
import std.algorithm : skipOver;
import std.path : buildNormalizedPath, dirName;
import std.string : tr;
import std.range : tail, takeOne;
import std.stdio : writeln;

import openapi : OasDocument, OasSchema;
import openapi_client.util : toUpperCamelCase, wordWrapText;

/**
 * Descriptive information about a OpenAPI schema and the Dlang code that represents it.
 *
 * Information in this class is used during code generation via [jsonSchemaByRef].
 */
class JsonSchema {
  /**
   * The name of the schema as per the OpenAPI Specification.
   */
  string schemaName;

  /**
   * The name of the Dlang module that contains classes for the schema.
   */
  string moduleName;

  /**
   * The name of the Dlang class representing this schema.
   */
  string className;

  /**
   * The OpenAPI Specification data representing the schema, in case it needs re-processing.
   */
  OasSchema schema;
}

JsonSchema[string] jsonSchemaByRef;

/**
 * In our code generation, the module is a file name which contains a class whose
 * name is in CamelCase.
 */
string getClassNameFromSchemaName(string schemaName) {
  static immutable RedBlackTree!string RESERVED_CLASSES = new RedBlackTree!string([
          "Error"
                                                                                   ]);
  string className = toUpperCamelCase(tr(schemaName, ".", "_"));
  if (className in RESERVED_CLASSES)
    return className ~ "_";
  else
    return className;
}

/**
 * Produce the full module name for a given schemaName and package.
 *
 * Params:
 *   packageRoot = The D base-package for the modules, e.g. "stripe.openapi".
 *   schemaName = The OpenAPI Spec schema name, e.g. "transfer_data".
 */
string getModuleNameFromSchemaName(string packageRoot, string schemaName) {
  if (packageRoot is null)
    return schemaName;
  else
    return packageRoot ~ ".model." ~ schemaName;
}

/**
 * Returns the OpenAPI Specification schema name from a schema
 * reference. E.g. "#/components/schemas/Thing" => "Thing".
 */
string getSchemaNameFromRef(string ref_) {
  string schemaName = ref_;
  if (!skipOver(schemaName, "#/components/schemas/"))
    throw new Exception("External references not supported! " ~ ref_);
  return schemaName;
}

/**
 * Generates and writes to disk D-language files that correspond to the OpenAPI Document's
 * components/schemas data. Depending on the software architecture ideas being used, such
 * files can be known as "model" or "dto" files.
 */
void writeSchemaFiles(OasDocument oasDocument, string targetDir, string packageRoot) {
  foreach (string schemaName, OasSchema schema; oasDocument.components.schemas) {
    JsonSchema jsonSchema = new JsonSchema();
    jsonSchema.schemaName = schemaName;
    jsonSchema.moduleName = getModuleNameFromSchemaName(packageRoot, schemaName);
    jsonSchema.className = getClassNameFromSchemaName(schemaName);
    jsonSchema.schema = schema;
    string ref_ = "#/components/schemas/" ~ schemaName;
    jsonSchemaByRef[ref_] = jsonSchema;
    writeln("Added reference: ", ref_);

    generateModuleCode(targetDir, jsonSchema, schema, packageRoot);
  }
}

/**
 * A collection of variable names that cannot be used to generate Dlang code.
 */
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
 * Writes a Dlang source file for a module that contains a class representing an OpenAPI
 * Specification schema.
 */
void generateModuleCode(string targetDir, JsonSchema jsonSchema, OasSchema oasSchema, string packageRoot) {
  auto buffer = appender!string();
  with (buffer) {
    put("// File automatically generated from OpenAPI spec.\n");
    put("module " ~ jsonSchema.moduleName ~ ";\n\n");
    // We generate the class in a separate buffer, because it's production may add dependencies.
    auto classBuffer = appender!string();
    generateClassCode(  // TODO: Pass the entire schema as an argument, not just parts of it.
        classBuffer, oasSchema.description, jsonSchema.className, oasSchema.properties);

    put("import vibe.data.serialization : optional;\n");
    put("import vibe.data.json : Json;\n");
    put("import builder : AddBuilder;\n");
    put("\n");
    put("import std.typecons : Nullable;\n\n");
    // While generating the class code, we accumulated external references to import.
    foreach (string schemaRef; getSchemaReferences(oasSchema)) {
      string schemaName = getSchemaNameFromRef(schemaRef);
      // Do not add an import for self-references.
      if (schemaName == jsonSchema.schemaName)
        continue;
      put("import ");
      put(getModuleNameFromSchemaName(packageRoot, schemaName));
      put(" : ");
      put(getClassNameFromSchemaName(schemaName));
      put(";\n");
    }
    put("\n");

    // Finally add our class code to the module file.
    put(classBuffer[]);
  }
  string fileName = buildNormalizedPath(targetDir, tr(jsonSchema.moduleName, ".", "/") ~ ".d");
  writeln("Writing file: ", fileName);
  mkdirRecurse(dirName(fileName));
  write(fileName, buffer[]);
}

/**
 * Writes to a buffer a Dlang class representing an OpenAPI Specification schema.
 */
void generateClassCode(
    Appender!string buffer, string description, string className, OasSchema[string] properties) {
  with (buffer) {
    // Display the class description and declare it.
    put("/**\n");
    foreach (string line; wordWrapText(description, 95)) {
      put(" * ");
      put(line);
      put("\n");
    }
    put(" */\n");
    put("class " ~ className ~ " {\n");
    // Define individual properties of the class.
    foreach (string propertyName, OasSchema propertySchema; properties) {
      try {
        generateSchemaInnerClasses(buffer, propertySchema, "  ");
        generatePropertyCode(buffer, propertyName, propertySchema, "  ");
      } catch (Exception e) {
        writeln("Error writing className=", className);
        throw e;
      }
    }
    put("  mixin AddBuilder!(typeof(this));\n\n");
    put("}\n");
  }
}

/**
 * Produce code for a class declaring a named property based on an [OasSchema] for the property.
 */
void generatePropertyCode(
    Appender!string buffer, string propertyName, OasSchema propertySchema, string prefix = "  ") {
  string propertyCodeType = getSchemaCodeType(propertySchema);
  if (propertyCodeType is null)
    return;
  if (propertySchema.description !is null) {
    buffer.put(prefix);
    buffer.put("/**\n");
    foreach (string line; wordWrapText(propertySchema.description, 93)) {
      buffer.put(prefix);
      buffer.put(" * ");
      buffer.put(line);
      buffer.put("\n");
    }
    buffer.put(prefix);
    buffer.put(" */\n");
  }
  try {
    buffer.put(prefix ~ "@optional\n");
    buffer.put(prefix ~ propertyCodeType ~ " "
        ~ getVariableName(propertyName) ~ ";\n\n");
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
void generateSchemaInnerClasses(
    Appender!string buffer, OasSchema schema, string prefix="  ", string defaultName = null,
    RedBlackTree!string context = null) {
  // To prevent the same class from being generated twice (which can happen when two properties are
  // themselves objects and have an identical set of properties and names), keep track of class
  // names that have been generated.
  if (context is null)
    context = new RedBlackTree!string();
  // Otherwise, we create static inner classes that match any objects, arrays, or other things that
  // are defined.
  if (schema.type == "object") {
    if (schema.properties is null) {
      // If additionalProperties is an object, it's a schema for the data type, but an arbitrary set
      // of attributes may exist.
      if (schema.additionalProperties.type == Json.Type.Undefined
          || schema.additionalProperties.type == Json.Type.Bool) {
        // Do not generate a class, this will be either Json or nothing at all.
      }
      else if (schema.additionalProperties.type == Json.Type.Object) {
        OasSchema propertySchema = deserializeJson!OasSchema(schema.additionalProperties);
        generateSchemaInnerClasses(buffer, propertySchema, prefix, defaultName, context);
      }
    }
    else {
      // We will have to make a class/struct out of this type from its name.
      string className = (schema.title !is null) ? schema.title.toUpperCamelCase() : defaultName;
      if (className is null)
        throw new Exception("Creating an Inner Class for property requires a title or default name!");
      if (className in context) {
        writeln("Avoiding generating duplicate inner class '", className, "'.");
        return;
      }
      if (schema.additionalProperties.type == Json.Type.Undefined ||
          (schema.additionalProperties.type == Json.Type.Bool
              && schema.additionalProperties.get!bool == true)) {
        writeln("Warning: ", className, " may have additional properties!");
      }
      buffer.put(prefix);
      buffer.put("static class " ~ className ~ " {\n");
      // Before we start a new context, let the previous one know about the class being defined.
      context.insert(className);
      // Start a new context, because the inner class creates a new naming scope.
      context = new RedBlackTree!string();
      foreach (string propertyName, OasSchema propertySchema; schema.properties) {
        generateSchemaInnerClasses(buffer, propertySchema, prefix ~ "  ", null, context);
        generatePropertyCode(buffer, propertyName, propertySchema, prefix ~ "  ");
      }
      buffer.put(prefix ~ "  mixin AddBuilder!(typeof(this));\n\n");
      buffer.put(prefix ~ "}\n\n");
    }
  }
  // The type might be an array and it's schema could be hidden beneath.
  else if (schema.type == "array" && schema.items !is null) {
    generateSchemaInnerClasses(buffer, schema.items, prefix, defaultName, context);
  }
  // Sometimes data has no explicit properties, but we can infer them from validation data.
  else if (schema.anyOf !is null && schema.anyOf.length == 1) {
    generateSchemaInnerClasses(buffer, schema.anyOf[0], prefix, null, context);
  }
}

/**
 * Converts a given [OasSchema] type into the equivalent type in source code.
 *
 * Params:
 *   defaultName = If a structured type can be created as an inner class, the default name to use
 *     for that class.
 */
string getSchemaCodeType(OasSchema schema, string defaultName = null) {
  // This could be a reference to an existing type.
  if (schema.ref_ !is null) {
    string schemaName = getSchemaNameFromRef(schema.ref_);
    // Resolving this class name depends on having an import statement.
    return getClassNameFromSchemaName(schemaName);
  }
  // First check if we have a primitive type.
  // TODO: Use the "schema.required" to determine which are nullable.
  else if (schema.type !is null) {
    if (schema.type == "integer") {
      if (schema.format == "int32")
        return "Nullable!(int)";
      else if (schema.format == "int64")
        return "Nullable!(long)";
      else if (schema.format == "unix-time")
        return "Nullable!(long)";
      return "Nullable!(int)";
    } else if (schema.type == "number") {
      if (schema.format == "float")
        return "Nullable!(float)";
      else if (schema.format == "double")
        return "Nullable!(double)";
      return "Nullable!(float)";
    } else if (schema.type == "boolean") {
      return "Nullable!(bool)";
    } else if (schema.type == "string") {
      return "string";
    } else if (schema.type == "array") {
      string arrayCodeType = getSchemaCodeType(schema.items);
      return arrayCodeType !is null ? arrayCodeType ~ "[]" : null;
    } else if (schema.type == "object") {
      // If we are missing both properties and additionalProperties, we assume a generic string[string] object.
      if (schema.properties is null) {
        // If additionalProperties is an object, it's a schema for the data type, but any number of
        // fields may exist.
        if (schema.additionalProperties.type == Json.Type.Object) {
          OasSchema propertySchema = deserializeJson!OasSchema(schema.additionalProperties);
          string propertyCodeType = getSchemaCodeType(propertySchema);
          return propertyCodeType !is null ? propertyCodeType ~ "[string]" : null;
        }
        // If additional properties exist, but we have no type information, it can be anything.
        else if (schema.additionalProperties.type == Json.Type.Undefined
            || (schema.additionalProperties.type == Json.Type.Bool
                && schema.additionalProperties.get!bool == true)) {
          return "Json";
        }
        // If there are no properties, and no additional properties, then it's not a type at all.
        else {
          return null;
        }
      }
      // If properties are present we can safely assume a class will be created.
      else {
        // We will have to make a class/struct out of this type from its name.
        if (schema.title !is null)
          return schema.title.toUpperCamelCase();
        else if (defaultName !is null)
          return defaultName;
        throw new Exception("Creating a named object type requires a title or defaultName!");
      }
    }
  }
  // Perhaps we can infer the type from the "anyOf" validation.
  else if (schema.anyOf !is null && schema.anyOf.length == 1) {
    return getSchemaCodeType(schema.anyOf[0]);
  }
  // If all else fails, put the programmer in the driver's seat.
  return "Json";
}

/**
 * When using a schema, it may reference other external schemas which have to be imported into any
 * module that uses them.
 */
string[] getSchemaReferences(OasSchema schema) {
  RedBlackTree!string refs = new RedBlackTree!string();
  getSchemaReferences(schema, refs);
  return refs[].array;
}

/// ditto
private void getSchemaReferences(OasSchema schema, ref RedBlackTree!string refs) {
  if (schema.ref_ !is null) {
    refs.insert(schema.ref_);
  } else if (schema.type == "array") {
    getSchemaReferences(schema.items, refs);
  } else if (schema.type == "object") {
    if (schema.properties !is null) {
      foreach (string propertyName, OasSchema propertySchema; schema.properties) {
        getSchemaReferences(propertySchema, refs);
      }
    }
    if (schema.additionalProperties.type == Json.Type.Object) {
      getSchemaReferences(deserializeJson!OasSchema(schema.additionalProperties), refs);
    }
  } else if (schema.anyOf !is null) {
    foreach (OasSchema anyOfSchema; schema.anyOf) {
      getSchemaReferences(anyOfSchema, refs);
    }
  } else if (schema.allOf !is null) {
    foreach (OasSchema allOfSchema; schema.allOf) {
      getSchemaReferences(allOfSchema, refs);
    }
  }
}
