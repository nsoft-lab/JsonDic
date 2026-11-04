/*
 * Copyright(c) 2026, NSoFT Co., Ltd.
 * SPDX-License-Identifier: Apache-2.0
 */

// example of parsing a JSON string

#include <stdio.h>
#include <string>
using std::string;

#include "jsonDic.h"

const string request_json = R"json(
{
    "action": "batch_update",
    "requestId": "req-98765",
    "options": {
        "dryRun": false,
        "timeoutMs": 3000
    },
    "items": [
        {
            "id": 101,
            "operation": "insert",
            "tags": ["user", "active"],
            "payload": { "name": "Alice", "role": "admin" }
        },
        {
            "id": 102,
            "operation": "update",
            "tags": ["guest"],
            "payload": { "name": "Bob", "role": "viewer" }
        }
    ]
}
)json";

int main() {
    JsonDic jdic(request_json);
    if (! jdic.parse()) {
        printf("error: %s (line:%d, pos:%d)\n",
                       jdic.errMsg.data(), jdic.errLine, jdic.errPos);
        return 1;
    }

    char kbuf[256];
    JDicKey root(kbuf, sizeof(kbuf));

    JDicValue action = jdic.find(root["action"]);
    JDicValue reqId  = jdic.find(root["requestId"]);
    if (action.isString() && reqId.isString()) {
        printf("Handling Action: %s [Request ID: %s]\n"
                    , action.token.data(), reqId.token.data());
    }

    JDicValue dryRun = jdic.find(root["options"]["dryRun"]);
    if (dryRun.exists()) {
        printf("Dry Run Mode: %s\n"
                    , dryRun.isTrue() ? "true" : "false");
    }

    JDicKey arr = root["items"];
    JDicValue items = jdic.find(arr);
    if (items.isArray()) {
        printf("Processing %d items...\n", items.arraySize);
        for (int i = 0; i < items.arraySize; ++i) {
            JDicKey obj = arr[i];
            JDicValue op   = jdic.find(obj["operation"]);
            JDicValue name = jdic.find(obj["payload"]["name"]);
            JDicValue role = jdic.find(obj["payload"]["role"]);
            if (op.exists() && name.exists()) {
                printf("[%d] Operation: %s -> Target User: %s (Role: %s)\n"
                   , i, op.token.data(), name.token.data(), role.token.data());
            }
        }
    }
    return 0;
}
