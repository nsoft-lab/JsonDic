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

// jsonDic.yy - JSON parsing dictionary yacc(bison) source

%{
#include <stdio.h>
#include <string.h>
#include <stdarg.h>

#include <vector>
using std::vector;

#include "jsonDic.h"

#define YYSTACK_USE_ALLOCA 1
#define YYSTYPE JsonDic::jVal

static thread_local struct {
    JsonDic* instance = 0;
    const unsigned char* jtxt;
    int jsiz, jpos;
    vector<JsonDic::jVal> vstack;
    int vsp;
} ctx;

static int yylex();
static int yyerror(const char*);
static bool js_action(JsonDic::jVal, int);
%}

%token tkSTRING
%token tkINTEGER
%token tkREAL
%token tkTRUE
%token tkFALSE
%token tkNULL

%%
json : value
;
value : tkSTRING   { if (! js_action($1, 1)) YYERROR; }
      | tkINTEGER  { if (! js_action($1, 1)) YYERROR; }
      | tkREAL     { if (! js_action($1, 1)) YYERROR; }
      | tkTRUE     { if (! js_action($1, 1)) YYERROR; }
      | tkFALSE    { if (! js_action($1, 1)) YYERROR; }
      | tkNULL     { if (! js_action($1, 1)) YYERROR; }
      | object
      | array
;
object : '{'           { if (! js_action($1, 0)) YYERROR; }     
             members
         '}'           { if (! js_action($4, 1)) YYERROR; }
;
members : /*empty*/
        | member
        | members ',' member
;
member : tkSTRING ':'  { if (! js_action($1, 0)) YYERROR; }
            value
;
array : '['            { if (! js_action($1, 0)) YYERROR; }
            values
        ']'            { if (! js_action($4, 1)) YYERROR; }
;
values : /*empty*/
       | value
       | values ',' value
;
%%

// JSON parser
//   returns true on success, false on error.

bool JsonDic::parse() {
    ctx.instance = this;
    ctx.jtxt = (const unsigned char*)ptr;
    ctx.jsiz = size;
    ctx.jpos = 0;
    ctx.vstack.clear();
    ctx.vsp = 0;
    errMsg.clear();
    errLine = errPos = 0;
    dic.clear();
    bool ret = yyparse() == 0;
    ctx.vstack.clear();
    ctx.instance = 0;
    return ret;
}

// error handler

static int yyerror(const char* msg) {
    int ln = 1;
    for (int i = 0; i < ctx.jpos; ++i) {
        if (ctx.jtxt[i] == '\n') {
            ++ln;
        }
    }
    ctx.instance->errLine = ln;
    ctx.instance->errPos = ctx.jpos;
    if (ctx.instance->errMsg.empty()) {
        ctx.instance->errMsg = msg;
    }
    return 0;
}

// syntax action

static bool js_action(JsonDic::jVal v, int end) {
    if (end) {
        JsonDic::jVal va;
        if (v.type == ']') {
            if (ctx.vsp > 0 && ctx.vstack[ctx.vsp - 1].type == '[') {
                va = ctx.vstack[--ctx.vsp];
                va.type = JDicValue::jARRAY;
            }
        } else if (v.type == '}') {
            if (ctx.vsp > 0 && ctx.vstack[ctx.vsp - 1].type == '{') {
                va = ctx.vstack[--ctx.vsp];
                va.type = JDicValue::jOBJECT;
            }
        } else {
            va = v;
        }
        string key;
        for (int i = 0; i < ctx.vsp; ++i) {
            if (ctx.vstack[i].type == '[') {
                char sub[16];
                int len = sprintf(sub, "%c%d", JDicKey::cARR, ctx.vstack[i].len);
                key += sub;
            } else if (ctx.vstack[i].type == '{') {
                if (i > 0) {  // omit 1st '{'
                    key.push_back(JDicKey::cOBJ);
                }
            } else {
                const char* p = (const char*)&ctx.jtxt[ctx.vstack[i].ofs];
                key.append(p, ctx.vstack[i].len);
            }
        }
        // add to map
        ctx.instance->dic[key] = va;
        if (ctx.vsp > 0) {
            // update stack
            JsonDic::jVal* vp = &ctx.vstack[ctx.vsp - 1];
            if (vp->type == JDicValue::jSTRING) {
                --ctx.vsp;  // stack pop
                if (ctx.vsp > 0) {
                    vp = &ctx.vstack[ctx.vsp - 1];
                    if (vp->type == '{') {
                        ++vp->len;  // OBJECT member count++
                    }
                }
            } else if (vp->type == '[') {
                ++vp->len;  // ARRAY size++
            }
        }
    } else {
        // stack push
        if (v.type == '[' || v.type == '{') {
            v.len = 0;  // init count
        }
        if (ctx.vsp < ctx.vstack.size()) {
            ctx.vstack[ctx.vsp++] = v;
        } else {
            ctx.vstack.push_back(v);
            ++ctx.vsp;
        }
    }
    return true;
}

// lexical analyzer

static void skip_blank() {
    while (ctx.jpos < ctx.jsiz) {
        int c = ctx.jtxt[ctx.jpos];
        if (c != ' ' && c != '\t' && c != '\r' && c != '\n') {
            break;
        }
        ++ctx.jpos;
    }
}

// 1char read
inline int c_get() { return ctx.jpos >= ctx.jsiz ? -1 : ctx.jtxt[ctx.jpos++]; }

static int tk_string() { // STRING
    int c = c_get();
    if (c != '"') {
        return YYUNDEF;
    }
    int esc = 0;
    while ((c = c_get()) != -1) {
        if (c < 0x20) {
            break;
        } else if (c == '"' && !esc) {
            return tkSTRING;
        } else if (c == '\\' && !esc) {
            esc = 1;
        } else {
            esc = 0;
        }
    }
    return YYUNDEF;
}

static int tk_number() { // INTEGER or REAL
    int c = c_get();
    if (c == '-') {
        c = c_get();
    }
    if (c >= '1' && c <= '9') {
        do { c = c_get(); } while (c >= '0' && c <= '9');
    } else if (c == '0') {
        c = c_get();
    } else {
        return YYUNDEF;
    }
    if (c != '.' && c != 'e' && c != 'E') {
        if (c != -1) --ctx.jpos;
        return tkINTEGER;
    }
    if (c == '.') {
        c = c_get();
        if (c < '0' || c > '9') {
            return YYUNDEF;
        }
        do { c = c_get(); } while (c >= '0' && c <= '9');
    }
    if (c == 'e' || c == 'E') {
        c = c_get();
        if (c == '+' || c == '-') {
            c = c_get();
        }
        if (c < '0' || c > '9') {
            return YYUNDEF;
        }
        do { c = c_get(); } while (c >= '0' && c <= '9');
    }
    if (c != -1) --ctx.jpos;
    return tkREAL;
}

static int tk_keywd() { // NULL, TRUE or FALSE
    int n = ctx.jsiz - ctx.jpos;
    if (n >= 4 && strncmp("null", (const char*)&ctx.jtxt[ctx.jpos], 4) == 0) {
        ctx.jpos += 4;
        return tkNULL;
    }
    if (n >= 4 && strncmp("true", (const char*)&ctx.jtxt[ctx.jpos], 4) == 0) {
        ctx.jpos += 4;
        return tkTRUE;
    }
    if (n >= 5 && strncmp("false", (const char*)&ctx.jtxt[ctx.jpos], 5) == 0) {
        ctx.jpos += 5;
        return tkFALSE;
    }
    return YYUNDEF;
}

static int yylex() {
    skip_blank();
    if (ctx.jpos >= ctx.jsiz) {
        return YYEOF;
    }
    int ofs = ctx.jpos;
    int tk;
    if ((tk = tk_string()) != YYUNDEF) {  // STRING?
        yylval.type = JDicValue::jSTRING;
        yylval.ofs = ofs + 1;  // delete (")
        yylval.len = ctx.jpos - ofs - 2;
        return tk;
    }
    ctx.jpos = ofs;
    if ((tk = tk_number()) != YYUNDEF) {  // INTERGER? REAL?
        if (tk == tkINTEGER) {
            yylval.type = JDicValue::jINTEGER;
        } else {
            yylval.type = JDicValue::jREAL;
        }
        yylval.ofs = ofs;
        yylval.len = ctx.jpos - ofs;
        return tk;
    }
    ctx.jpos = ofs;
    if ((tk = tk_keywd()) != YYUNDEF) {  // true? false? null?
        if (tk == tkTRUE) {
            yylval.type = JDicValue::jTRUE;
        } else if (tk == tkFALSE) {
            yylval.type = JDicValue::jFALSE;
        } else {
            yylval.type = JDicValue::jNULL;
        }
        yylval.ofs = ofs;
        yylval.len = ctx.jpos - ofs;
        return tk;
    }
    ctx.jpos = ofs;
    yylval.ofs = ofs;
    yylval.len = 1;
    yylval.type = c_get();
    return yylval.type;
}

// JSON path search

JDicValue JsonDic::find(const JDicKey& path) {
    string key(path.ptr, path.len);
    JDicValue ret;
    unordered_map<string, jVal>::const_iterator it = dic.find(key);
    if (it == dic.end()) {
        return ret;
    }
    const jVal& val = it->second;
    ret.type = (JDicValue::jType)val.type;
    if (ret.type == JDicValue::jOBJECT) {
        ret.memberCount = val.len;
    } else if (ret.type == JDicValue::jARRAY) {
        ret.arraySize = val.len;
    } else {
        ret.token.assign(&ptr[val.ofs], val.len);
    }
    return ret;
}

inline int _fmtcat(char* buf, int size, const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    int n = vsnprintf(buf, size, fmt, ap);
    va_end(ap);
    return n >= size ? size - 1 : n;
}

JDicKey JDicKey::operator[](const string& s) {
    JDicKey k = *this;
    if (k.baselen == 0) {
        k.len = _fmtcat(k.ptr, k.size, "%s", s.data());
    } else {
        char* p = k.ptr + k.baselen;
        int sz = k.size - k.baselen;
        int n = _fmtcat(p, sz, "%c%s", JDicKey::cOBJ, s.data());
        k.len = k.baselen + n;
    }
    return k;
}

JDicKey JDicKey::operator[](int i) {
    JDicKey k = *this;
    char* p = k.ptr + k.baselen;
    int sz = k.size - k.baselen;
    int n = _fmtcat(p, sz, "%c%d", JDicKey::cARR, i);
    k.len = k.baselen + n;
    return k;
}

//EOF
