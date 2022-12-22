module openapi_client.util;

import std.array : array, split, appender, Appender;
import std.algorithm : map, joiner;
import std.array : appender;
import std.uni : toUpper, toLower, isUpper, isLower, isAlpha;

/**
 * Given a block of text, first split it using the "\n" escape, and then word-wrap each line.
 */
string[] wordWrapText(string text, size_t width = 80, char sep = ' ') {
  return text.split("\n").map!(line => wordWrapLine(line, width, sep)).joiner().array;
}

/**
 * Separates a single long line into separate lines, performing word-wrapping where possible.
 *
 * Params:
 *   text = The long line of text to split into lines.
 *   width = The maximum length of a line.
 *   sep = The separator character that can be used for word-wrapping.
 */
string[] wordWrapLine(string text, size_t width = 80, char sep = ' ') {
  string[] results;
  size_t start = 0;
  while (start < text.length) {
    size_t end;
    if (start + width >= text.length) {
      // There's not enough text for a full line, take what's there.
      end = text.length;
    } else {
      end = start + width;
      // Find the closest separator character to split the line.
      while (text[end] != sep && end > start) {
        end--;
      }
      // There may be no separator characters at all.
      if (start == end) {
        end = start + width;
      }
    }
    results ~= text[start..end];
    start = end;
    // Consume any separators before the next line starts.
    while (start < text.length && text[start] == sep) {
      start++;
    }
  }
  return results;
}

unittest {
  assert(
      wordWrapText("aaaa aaaa aaaa aaaa bbbb bbbb bbbb bbbb", 20)
      == ["aaaa aaaa aaaa aaaa", "bbbb bbbb bbbb bbbb"]);
  assert(
      wordWrapText("aaaa aaaa aaaa aaaaaa bbbb bbbb bbbb bbbb", 20)
      == ["aaaa aaaa aaaa", "aaaaaa bbbb bbbb", "bbbb bbbb"]);
  assert(
      wordWrapText("aaaaaaaaaaaaaaaaaaaabbbbbbbbbb", 20)
      == ["aaaaaaaaaaaaaaaaaaaa", "bbbbbbbbbb"]);
  assert(
      wordWrapText("aaaaaaaaaaa\naaaaaaaaa\nbbbbbbbbbb", 20)
      == ["aaaaaaaaaaa", "aaaaaaaaa", "bbbbbbbbbb"]);
}

/// Converts a string in "snake_case" to "UpperCamelCase".
string toUpperCamelCase(string input) {
  auto str = appender!string();
  bool newWord = true;
  foreach (c; input) {
    if (c == '_') {
      newWord = true;
    } else if (!isAlpha(c)) {
      str.put(c);
      newWord = true;
    } else if (newWord == true || isUpper(c)) {
      str.put(toUpper(c));
      newWord = false;
    } else {
      str.put(toLower(c));
    }
  }
  return str[];
}

unittest {
  assert(toUpperCamelCase("HamOnRye") == "HamOnRye");
  assert(toUpperCamelCase("hamOnRye") == "HamOnRye");
  assert(toUpperCamelCase("ham_On_Rye") == "HamOnRye");
  assert(toUpperCamelCase("ham_on_rye") == "HamOnRye");
  assert(toUpperCamelCase("_ham_on_rye") == "HamOnRye");
  assert(toUpperCamelCase("__ham__on__rye__") == "HamOnRye");
  assert(toUpperCamelCase("3bird_ham") == "3BirdHam");
}

/**
 * Given a string with bracket parameters, e.g. "hello/{name}", and an associative array of
 * parameters, substitute parameter values and return the new string.
 *
 * For example, `resolveTemplate("hello/{name}", ["name": "world"]}` would return "hello/world".
 */
string resolveTemplate(string urlTemplate, string[string] params) {
  Appender!string buf = appender!string();
  Appender!string param = appender!string();
  bool inParam = false;
  foreach (char c; urlTemplate) {
    if (!inParam) {
      if (c == '{') {
        inParam = true;
        param = appender!string();
      } else if (c == '}') {
        throw new Exception("\"" ~ urlTemplate ~ "\": Unbalanced braces!");
      } else {
        buf.put(c);
      }
    } else {
      if (c == '{') {
        throw new Exception("\"" ~ urlTemplate ~ "\": Unbalanced braces!");
      } else if (c == '}') {
        inParam = false;
        string* val = param[] in params;
        if (val is null) {
          throw new Exception("\"" ~ urlTemplate ~ "\": Missing value for parameter '"
              ~ param[] ~ "'!");
        }
        buf.put(*val);
      } else {
        param.put(c);
      }
    }
  }
  return buf[];
}

unittest {
  import std.exception;

  assert(resolveTemplate("hello/{name}", ["name": "world"]) == "hello/world");
  assert(resolveTemplate("{name}/{fish}/{name}", ["name": "world", "fish": "carp"])
      == "world/carp/world");
  assertThrown!Exception(resolveTemplate("abc{def{hij}", ["def": "ham"]));
  assertThrown!Exception(resolveTemplate("ab}c{def}", ["def": "ham"]));
}
