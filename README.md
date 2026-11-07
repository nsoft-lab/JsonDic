# JsonDic

A lightweight, minimal C++ JSON parser and dictionary built with Bison (under 440 lines of code).

**JsonDic** is designed to be straightforward, compact, and efficient. It focuses on parsing JSON structures into a flattened, path-addressable dictionary while keeping memory overhead and complexity to a minimum.

## Key Features

- **Minimal Footprint**: Consists of only two source files (`jsonDic.h` and `jsonDic.yy`).
- **Zero-Copy Architecture**: Values refer directly to byte offsets and lengths within the original JSON buffer, avoiding intermediate string copying.
- **Ideal for `mmap`**: Designed to parse directly from memory-mapped files or existing memory buffers.
- **Flattened Dictionary Lookup**: Parses JSON structures into an `std::unordered_map` keyed by path.
- **Chainable Stack-Allocated Keys**: Use `JDicKey` on local stack memory to naturally query nested objects and arrays (`root["items"]["name"]`).
- **Standard Compliant**: Handles JSON objects, arrays, strings, integers, reals, booleans, and `null`.

---

## Architecture Overview

1. **Parser & Dictionary (`JsonDic`)**: Parses raw JSON text using Bison and maps flattened object/array path keys to internal descriptor values (`jVal`).
2. **Buffer Requirement**: Because parsed tokens reference the original payload by offset and length, the JSON source buffer must remain valid in memory for the lifetime of the `JsonDic` instance.
3. **Query Key (`JDicKey`)**: Formats query paths into a caller-supplied buffer (typically a local stack array like `char kbuf[1024];`). Key chaining with `operator[]` creates temporary descriptors without mutating the base key path.
4. **Result Value (`JDicValue`)**: Encapsulates the queried node's type, token substring, array size, or object member count.

---

## File Structure

```text
.
├── jsonDic.h       # Header file (JDicKey, JDicValue, JsonDic declarations)
├── jsonDic.yy      # Bison grammar and lexer implementation
└── examples/       # Sample programs and Makefile
```

---

## Building

Generate the C++ source from `jsonDic.yy` using **Bison**:

```bash
bison -o jsonDic.cc jsonDic.yy
```

To build and run the provided examples, check the `examples/` directory:

```bash
cd examples
make
```

---

## Quick Start

```cpp
#include <stdio.h>
#include <string>
using std::string;

#include "jsonDic.h"

string json = R"(
{
    "action": "batch_update",
    "options": { "dryRun": false },
    "items": [
        { "id": 101, "name": "Alice" },
        { "id": 102, "name": "Bob" }
    ]
})";

int main() {
    JsonDic jdic(json);
    if (!jdic.parse()) {
        printf("Parse error: %s (line: %d, pos: %d)\n",
               jdic.errMsg.data(), jdic.errLine, jdic.errPos);
        return 1;
    }

    // Allocate key buffer on the stack
    char kbuf[256];
    JDicKey root(kbuf, sizeof(kbuf));

    // Simple key lookup
    JDicValue action = jdic.find(root["action"]);
    if (action.isString()) {
        printf("Action: %s\n", action.token.data());
    }

    // Nested object lookup
    JDicValue dryRun = jdic.find(root["options"]["dryRun"]);
    if (dryRun.exists()) {
        printf("Dry run: %s\n", dryRun.isTrue() ? "true" : "false");
    }

    // Array iteration and chained access
    JDicKey arr = root["items"];
    JDicValue items = jdic.find(arr);
    if (items.isArray()) {
        for (int i = 0; i < items.arraySize; ++i) {
            JDicValue name = jdic.find(arr[i]["name"]);
            if (name.exists()) {
                printf("Item %d Name: %s\n", i, name.token.data());
            }
        }
    }

    return 0;
}
```

---

## API Summary

### `JsonDic`
- `JsonDic(const char* ptr, int size)`: Initializes parser with a raw memory buffer.
- `JsonDic(const std::string& s)`: Initializes parser with a string reference.
- `bool parse()`: Parses the JSON input. Returns `true` on success, `false` on syntax error.
- `JDicValue find(const JDicKey& path)`: Looks up a path in the dictionary.
- `errMsg`, `errLine`, `errPos`: Error diagnostic attributes populated on parsing failure.

### `JDicKey`
- `JDicKey(char* buf, int size)`: Constructs a root query key using a caller-provided buffer.
- `JDicKey operator[](const std::string&)`: Traverses an object member name.
- `JDicKey operator[](int)`: Traverses an array index.

### `JDicValue`
- `bool exists()` / `operator bool()`: Checks if the queried key exists.
- `isNull()`, `isString()`, `isInteger()`, `isReal()`, `isTrue()`, `isFalse()`, `isArray()`, `isObject()`: Type inspection helpers.
- `token`: String representation of the token (empty for arrays/objects).
- `arraySize`: Number of elements (when value is an array).
- `memberCount`: Number of members (when value is an object).

---

## License

This project is licensed under the Apache License, Version 2.0.  
See [LICENSE](LICENSE) for details.

Copyright (c) 2026, NSoFT Co., Ltd.
