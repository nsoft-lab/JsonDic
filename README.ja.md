# JsonDic


[English](README.md) | [Japanese](README.ja.md)

Bison を用いて構築された、軽量でコンパクトな C++ 向け JSON パーザ＆ディクショナリです。

**JsonDic** は、シンプルさ・省サイズ・高効率を重視して設計されています。JSON 構造をパス指定可能なフラットな辞書（ディクショナリ）へと展開し、メモリオーバーヘッドと実装の複雑さを最小限に抑えます。

## 主な特徴

- **最小限のフットプリント**: わずか 2 つのソースファイル（`jsonDic.h` と `jsonDic.yy`）で完結。
- **ゼロコピー指向**: 各値は元 JSON バッファ内のオフセット位置と長さを直接参照するため、文字列の余計なコピーが発生しません。
- **`mmap` との親和性**: メモリマップトファイルや既存のメモリバッファからの直接パースに最適。
- **フラットな辞書検索**: 展開された JSON 構造をパス文字列をキーとする `std::unordered_map` で管理。
- **スタック上で連結可能なキー検索**: ローカルスタックバッファ上に確保した `JDicKey` を使い、階層構造や配列を直感的にチェーンアクセス可能（`root["items"]["name"]`）。
- **標準仕様に準拠**: JSON のオブジェクト、配列、文字列、整数、実数、真偽値、`null` に対応。

---

## アーキテクチャ概要

1. **パーザと辞書 (`JsonDic`)**: Bison を用いて生の JSON テキストを構文解析し、フラット化したオブジェクト／配列のパストークンを内部ディスクリプタ（`jVal`）にマッピングします。
2. **バッファ要件**: 各トークンは元バッファのオフセットと長さを参照するため、`JsonDic` インスタンスが存在する間、パース対象の元バッファがメモリ上に保持されている必要があります。
3. **検索キー (`JDicKey`)**: 呼び出し側が用意したバッファ（通常はスタック上の `char kbuf[1024];` など）に検索パスを構築します。`operator[]` によるチェーンアクセスは基底パスを変更せず、一時的なディスクリプタを生成して動作します。
4. **取得値 (`JDicValue`)**: 検索されたノードの型、トークン文字列、配列サイズ、オブジェクトの要素数などを保持・判定します。

---

## ディレクトリ構成

```text
.
├── jsonDic.h       # ヘッダファイル（JDicKey, JDicValue, JsonDic の宣言）
├── jsonDic.yy      # Bison 文法および字句解析の実装
└── examples/       # サンプルコードおよび Makefile
```

---

## ビルド方法

**Bison** を使用して `jsonDic.yy` から C++ ソースコードを生成します。

```bash
bison -o jsonDic.cc jsonDic.yy
```

付属のサンプルプログラムをビルドして実行する場合は、`examples/` ディレクトリ配下で make を実行してください。

```bash
cd examples
make
```

---

## クイックスタート

```cpp
#include <cstdio>
#include <string>
#include "jsonDic.h"

int main() {
    std::string json = R"({
        "action": "batch_update",
        "options": { "dryRun": false },
        "items": [
            { "id": 101, "name": "Alice" },
            { "id": 102, "name": "Bob" }
        ]
    })";

    JsonDic jdic(json);
    if (!jdic.parse()) {
        printf("Parse error: %s (line: %d, pos: %d)\n",
               jdic.errMsg.c_str(), jdic.errLine, jdic.errPos);
        return 1;
    }

    // スタック上にキー用バッファを確保
    char kbuf[1024];
    JDicKey root(kbuf, sizeof(kbuf));

    // 単純なキー検索
    JDicValue action = jdic.find(root["action"]);
    if (action.isString()) {
        printf("Action: %s\n", action.token.c_str());
    }

    // ネストしたオブジェクトの検索
    JDicValue dryRun = jdic.find(root["options"]["dryRun"]);
    if (dryRun.exists()) {
        printf("Dry run: %s\n", dryRun.isTrue() ? "true" : "false");
    }

    // 配列の走査とチェーンアクセス
    JDicKey arr = root["items"];
    JDicValue items = jdic.find(arr);
    if (items.isArray()) {
        for (int i = 0; i < items.arraySize; ++i) {
            JDicValue name = jdic.find(arr[i]["name"]);
            if (name.exists()) {
                printf("Item %d Name: %s\n", i, name.token.c_str());
            }
        }
    }

    return 0;
}
```

---

## 主要 API リファレンス

### `JsonDic`
- `JsonDic(const char* ptr, int size)`: 生のメモリバッファを指定して初期化します。
- `JsonDic(const std::string& s)`: 文字列への参照を指定して初期化します。
- `bool parse()`: JSON 入力を構文解析します。成功時に `true`、構文エラー時に `false` を返します。
- `JDicValue find(const JDicKey& path)`: 辞書内から指定パスの要素を検索します。
- `errMsg`, `errLine`, `errPos`: パース失敗時のエラーメッセージ、行番号、位置。

### `JDicKey`
- `JDicKey(char* buf, int size)`: 呼び出し側のバッファを使用してルート検索キーを構築します。
- `JDicKey operator[](const std::string&)`: オブジェクトのメンバ名をたどります。
- `JDicKey operator[](int)`: 配列のインデックスをたどります。

### `JDicValue`
- `bool exists()` / `operator bool()`: 対象のキーが存在するか判定します。
- `isNull()`, `isString()`, `isInteger()`, `isReal()`, `isTrue()`, `isFalse()`, `isArray()`, `isObject()`: 各データ型の判定ヘルパー。
- `token`: トークンの文字列表現（配列やオブジェクトの場合は空文字）。
- `arraySize`: 配列の要素数（値が配列の場合）。
- `memberCount`: オブジェクトのメンバ数（値がオブジェクトの場合）。

---

## ライセンス

本プロジェクトは Apache License, Version 2.0 のもとで公開されています。  
詳細は [LICENSE](LICENSE) を参照してください。

Copyright (c) 2026, NSoFT Co., Ltd.
