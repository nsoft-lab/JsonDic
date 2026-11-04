/*
 * Copyright(c) 2026, NSoFT Co., Ltd.
 * SPDX-License-Identifier: Apache-2.0
 */

// dumps the parsed results of JSON from stdin

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <vector>
#include <utility>
#include <algorithm>
using std::vector;
using std::pair;
using std::sort;

#include "jsonDic.h"

void print_key(const string& key) {
    fputc('[', stdout);
    for (char c : key) {
        if (c == JDicKey::cARR || c == JDicKey::cOBJ) {
            printf("<%03o>", c);
        } else {
            fputc(c, stdout);
        }
    }
    fputs("]=", stdout);
}

void print_val(const char* ptr, const JsonDic::jVal& val) {
    bool err = false;
    fputc('[', stdout);
    switch (val.type) {
    case JDicValue::jNULL: fputs("<NULL>", stdout); break;
    case JDicValue::jSTRING: fputs("<STRING>", stdout); break;
    case JDicValue::jINTEGER: fputs("<INTEGER>", stdout); break;
    case JDicValue::jREAL: fputs("<REAL>", stdout); break;
    case JDicValue::jTRUE: fputs("<TRUE>", stdout); break;
    case JDicValue::jFALSE: fputs("<FALSE>", stdout); break;
    case JDicValue::jARRAY: fputs("<ARRAY>", stdout); break;
    case JDicValue::jOBJECT: fputs("<OBJECT>", stdout); break;
    default:
        fputs("???", stdout);
        err = true;
    }
    if (val.type == JDicValue::jARRAY || val.type == JDicValue::jOBJECT) {
        printf("%d", val.len);
    } else if (! err) {
        fputc('`', stdout);
        fwrite(ptr + val.ofs, val.len, 1, stdout);
        fputc('`', stdout);
    }
    fputs("]\n", stdout);
}

int main() {
    char* ptr;
    size_t size;
    FILE* mf = open_memstream(&ptr, &size);
    char buf[BUFSIZ];
    bool tty = isatty(fileno(stdin));
    if (tty) {
        printf("input json:\n");
    }
    int n;
    while ((n = read(0, buf, sizeof(buf))) > 0) {
        fwrite(buf, n, 1, mf);
    } 
    fclose(mf);
    if (tty) {
        printf("---\n");
    }

    JsonDic jd(ptr, size);
    if (! jd.parse()) {
        printf("error: %s (line:%d, pos:%d)\n",
            jd.errMsg.data(), jd.errLine, jd.errPos);
        free(ptr);
        return -1;
    }
    unordered_map<string, JsonDic::jVal>& d = jd.dic;
    vector<string> keys;
    keys.reserve(d.size());
    unordered_map<string, JsonDic::jVal>::const_iterator i = d.begin();
    while (i != d.end()) {
        keys.push_back(i->first);
        ++i;
    }
    sort(keys.begin(), keys.end());
    vector<string>::const_iterator k = keys.begin();
    while (k != keys.end()) {
        const string& key = *k;
        const JsonDic::jVal& val = d.at(key);
        print_key(key);
        print_val(ptr, val);
        ++k;
    }
    free(ptr);
    return 0;
}
