/*
 * Copyright(c) 2026, NSoFT Co., Ltd.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

// jsonDic.h - Dictionary-based JSON parser

#pragma once

#define JSONDIC_VERSION "1.0.0"

#include <string>
using std::string;
#include <unordered_map>
using std::unordered_map;

class JDicKey { // JSON chainable query key
  private:
    char* ptr;
    int size, len, baselen;
    friend class JsonDic;

  public:
    JDicKey(char* buf, int size)
        : ptr(buf), size(size), len(0), baselen(0) { *ptr = 0; }
    JDicKey(const JDicKey& k)
        : ptr(k.ptr), size(k.size), len(k.len), baselen(k.len) {}

    JDicKey& operator=(const JDicKey& k) {
        ptr = k.ptr; size = k.size;
        len = baselen = k.len;
        return *this;
    }
    JDicKey operator[](const string&);
    JDicKey operator[](int);

    enum splitter {
        cARR = '\035', cOBJ = '\036'
    };
};

struct JDicValue { // JSON query result value
    enum jType {
        jUNDEFINED = 300,
        jNULL, jSTRING,
        jINTEGER, jREAL,
        jTRUE, jFALSE,
        jARRAY, jOBJECT
    };
    jType type = jUNDEFINED;
    bool exists() { return type != jUNDEFINED; }
    operator bool() { return type != jUNDEFINED; }
    int arraySize = -1;
    int memberCount = -1;
    string token;
    bool isNull() { return type == jNULL; }
    bool isString() { return type == jSTRING; }
    bool isInteger() { return type == jINTEGER; }
    bool isReal() { return type == jREAL; }
    bool isTrue() { return type == jTRUE; }
    bool isFalse() { return type == jFALSE; }
    bool isArray() { return type == jARRAY; }
    bool isObject() { return type == jOBJECT; }
};

class JsonDic { // JSON parser & dictionary
  private:
    const char* ptr;
    int size;

  public:
    JsonDic(const char* ptr, int size) : ptr(ptr), size(size) {}
    JsonDic(const string& s) : ptr(s.data()), size(s.size()) {}
    ~JsonDic() {};

    bool parse();
    string errMsg;
    int errLine;
    int errPos;

    struct jVal { int type, ofs, len; };
    unordered_map<string, jVal> dic;

    JDicValue find(const JDicKey&);
};

//EOF
