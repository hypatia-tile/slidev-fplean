---
theme: default
title: モナドで算術 — FPIL 4.3
info: |
  Functional Programming in Lean 4.3 "Example: Arithmetic in Monads" (4.3.1–4.3.3, 演習を除く)
  コードはすべて lean/ で型検査・実行結果検査済み。
highlighter: shiki
lineNumbers: false
transition: slide-left
mdc: true
---

# モナドで算術

Functional Programming in Lean — 4.3

<div class="text-sm opacity-60 mt-8">
スライド上のコードと出力は <code>lean/</code> で <code>lake build</code> により検査されたもの
</div>

<!--
このデッキの Lean コードは lean/ にあり、pnpm lean:import で取り込んでいる。
-->

---

# この節の問い

Monad は、副作用のない言語で副作用のあるプログラムを表す方法。本はその利点を二つ挙げる。

- 使う作用が**型に正直に**現れる
- どの作用を使うかを、用途に合わせて**選べる**（例外、Icon の複数の値の探索 …）

<div class="mt-8 p-4 border-l-4 border-blue-500">

その例として、本は算術式の評価器を扱う。割り算は**失敗しうる**し、演算子を足せば**探索**や**環境の参照**といった別の作用も出てくる。作用ごとに評価器を書き直すのではなく、

**評価器を一度だけ書き、作用は後から Monad として選べるか？**

</div>

<!--
本の節冒頭:「Monad は副作用のない言語に副作用のあるプログラムを埋め込む方法」。
二つの利点: 型に正直であること、作用を選べること（例外は一部の言語にしかない。Icon には複数の値の探索、Scheme や Ruby には継続がある）。
4.3 はその例として「さまざまな Monad で意味を持つプログラム」= 算術式の評価器を扱う。
-->

---

# 道のり

<div class="grid grid-cols-2 gap-8">
<div>

**第1部 失敗を扱う**（4.3.1〜4.3.2）

1. 算術式を帰納型で表す
2. `Option` で評価する ── 二つの関心が混ざっている
3. 演算子の適用を `applyPrim` に切り出す
4. 失敗するが、理由が分からない
5. `Except String` で理由を運ぶ
6. Monad について多相にする ── `evaluateM`
7. 違いは割り算だけ ── `applyDiv` を引数に
8. 評価の流れを木の上で追う

</div>
<div>

**第2部 ほかの作用へ**（4.3.3）

1. 特別な演算子を分ける ── `Prim special`
2. 作用なし ── `Empty` と `Id`
3. 非決定的な探索 ── `Many`
4. 環境を読む ── `Reader`

</div>
</div>

<!--
各段階は「前の段階で見えた問題」を解く形でつながっている。
-->

---

# 算術式を木で表す

<LeanIntent name="expr" />

<!-- lean:code expr -->
<<< @/generated/snippets/expr@1.lean {*|2|3|5-9}
<!-- /lean -->

<LeanCaption name="expr" />

<!--
lean:notes expr

本の定義どおり「整数リテラル、または二つの式に適用された基本演算子」。

クリックで const（葉）→ prim（節）→ 演算子の型 Arith の順に強調する。
-->

---

# 例となる式

<LeanIntent name="examples" />

<!-- lean:code examples -->
<<< @/generated/snippets/examples@1.lean
<!-- /lean -->

<LeanCaption name="examples" />

<!--
lean:notes examples

`twoPlusThree` は失敗しない例、`fourteenDivided` は失敗する例として最後まで使う。
-->

---

# Option で評価する

<LeanIntent name="evaluate-option" />

<!-- lean:code evaluate-option -->
````md magic-move
<<< @/generated/snippets/evaluate-option@1.lean {*|2|3-5|6-9|10}
<<< @/generated/snippets/evaluate-option@2.lean {*|1-5|12}
````
<!-- /lean -->

<LeanCaption name="evaluate-option" />

<!--
lean:notes evaluate-option

**@1** まずは Option に直接書く。部分式を評価して `>>=` でつなぐ。 割り算だけが失敗しうる。本は「この関数は二つの関心を混ぜている」と指摘する。

**@2** 演算子の適用を `applyPrim` に切り出す。`evaluateOption` は木を辿るだけになる。
-->

---

# 動かしてみる

<LeanIntent name="eval-v1" />

<!-- lean:eval eval-v1 -->
```lean
#eval evaluateOption fourteenDivided
```
<div class="lean-output">

```text
none
```

</div>
<!-- /lean -->

<LeanCaption name="eval-v1" />

<!--
lean:notes eval-v1

分母が 0 なので none。Option は失敗の理由を運べない。
-->

---

# 理由を運び、評価器を一つにする

<LeanIntent name="evaluate-generic" />

<!-- lean:code evaluate-generic -->
````md magic-move
<<< @/generated/snippets/evaluate-generic@1.lean {*|1-5|12}
<<< @/generated/snippets/evaluate-generic@2.lean {*|1,10|7}
<<< @/generated/snippets/evaluate-generic@3.lean {*|7-9|14}
<<< @/generated/snippets/evaluate-generic@4.lean {*|1,4|8,11|14,20}
````
<!-- /lean -->

<LeanCaption name="evaluate-generic" />

<!--
lean:notes evaluate-generic

**@1** 前のスライドの最後の形から始める。ここから Except に置き換える。

**@2** エラーメッセージが欲しいので Except String に置き換える。 本は「>>= を使っていたので、小さな変更で済む」と言う。

**@3** 二つの評価器は Monad 以外同じ。`applyPrim` を引数にして一般化する。

**@4** Option 版と Except 版で違うのは割り算だけ。そこだけを引数にする。 本の結論:「二つのコードパスが失敗の扱いだけで異なることが、完全に明らかになった」。
-->

---

# 同じ evaluateM、違う Monad

<LeanIntent name="eval-v5" />

<!-- lean:eval eval-v5 -->
```lean
#eval evaluateM applyDivOption fourteenDivided
```
<div class="lean-output">

```text
none
```

</div>

```lean
#eval evaluateM applyDivExcept fourteenDivided
```
<div class="lean-output">

```text
Except.error "Tried to divide 14 by zero"
```

</div>

```lean
#eval evaluateM applyDivOption twoPlusThree
```
<div class="lean-output">

```text
some 5
```

</div>
<!-- /lean -->

<LeanCaption name="eval-v5" />

<!--
lean:notes eval-v5

割り算の関数を差し替えるだけで、同じ evaluateM が Option でも Except でも動く。

失敗しない式ではどちらも普通に値を返す。
-->

---

# 評価の流れ: Option

<div class="lean-intent-static">
評価器は木を葉から順に辿る。どこで失敗が起き、それがどう根まで伝わるかを一歩ずつ見る。
</div>

<TraceView run="fourteenDivided-option" />

<!--
クリックごとに 1 ステップ進む。ステップ列は Lean の evaluateTraced が出力したもの。
葉から値が返り、最後に根の「/」で分母 0 により none になる。
-->

---

# 評価の流れ: Except String

<div class="lean-intent-static">
同じ木を <code>Except String</code> で評価する。辿り方は同じで、失敗のときに運ばれるものだけが違う。
</div>

<TraceView run="fourteenDivided-except" />

<!--
木の辿り方は Option と全く同じ。違うのは失敗時に運ばれる値だけ。
-->

---
layout: section
---

# 第2部 ほかの作用へ

4.3.3 Further Effects

---

# 失敗以外の作用

<div class="lean-intent-static">
割り算の作用は失敗だけ。だが、ほかの演算子を式に足せば、ほかの作用も表せる。
</div>

本はこの順に三つの作用を扱う。

| 演算子 | 作用 | Monad |
|---|---|---|
| なし | 作用なし | `Id` |
| 割り算 + どちらかを選ぶ `choose` | 非決定的な探索 | `Many`（この節で定義） |
| 名前で呼ぶ利用者定義の演算子 | 環境を読む | `Reader`（この節で定義） |

<div class="mt-6 p-4 border-l-4 border-blue-500">

**評価器 `evaluateM` を変えずに、渡す関数と Monad だけでこれらを表せるか？**

</div>

<!--
本:「失敗や例外だけが、評価器で興味深い作用ではない。割り算の唯一の副作用は失敗だが、ほかの基本演算子を式に足せば、ほかの作用も表せる」。
-->

---

# 特別な演算子を分ける

<LeanIntent name="prim" />

<!-- lean:code prim -->
<<< @/generated/snippets/prim@1.lean {*|5|7-8}
<!-- /lean -->

<LeanCaption name="prim" />

<!--
lean:notes prim

本:「割り算の唯一の副作用は失敗だが、ほかの基本演算子を式に足せば、ほかの作用も表せる」。

そのための最初の一歩が、割り算をプリミティブの型から取り出すこと。
-->

---

# 評価器を特別な演算子に広げる

<LeanIntent name="evaluate-special" />

<!-- lean:code evaluate-special -->
````md magic-move
<<< @/generated/snippets/evaluate-special@1.lean {*|1,4|8,11|14,20}
<<< @/generated/snippets/evaluate-special@2.lean {*|1,4|8-9,11|14-15,20}
````
<!-- /lean -->

<LeanCaption name="evaluate-special" />

<!--
lean:notes evaluate-special

**@1** 4.3.2 の最後の形から始める。

**@2** 割り算専用だった引数を、任意の特別な演算子を処理する引数に広げる。
-->

---

# 作用なし: Empty と Id

<LeanIntent name="apply-empty" />

<!-- lean:code apply-empty -->
<<< @/generated/snippets/apply-empty@1.lean
<!-- /lean -->

<!-- lean:eval eval-empty -->
```lean
open Expr Prim in
#eval evaluateM (m := Id) applyEmpty (prim plus (const 5) (const (-14)))
```
<div class="lean-output">

```text
-9
```

</div>
<!-- /lean -->

<LeanCaption name="eval-empty" />

<!--
lean:notes eval-empty

`nomatch op` は「op の型には構成子がないので、ここには来ない」と Lean に伝える。

本: Scala や Kotlin の Nothing に似ている。

(m := Id) で Monad を明示している。Id は「何もしない」Monad。
-->

---

# 非決定的な探索: 評価の規則

<div class="lean-intent-static">
ゼロ除算で単に失敗する代わりに、戻って別の選び方を試す。結果は一つの値ではなく、失敗しない答えの多重集合になる。
</div>

- 定数 $n$ は $\{n\}$
- 割り算以外の演算子は、答えのすべての組に適用する: $X + Y$ は $\{\, x + y \mid x \in X,\ y \in Y \,\}$
- 割り算は分母 0 の組を捨てる: $X / Y$ は $\{\, x / y \mid x \in X,\ y \in Y,\ y \neq 0 \,\}$
- 選択 $\mathrm{choose}(x, y)$ は $\{x, y\}$

<div class="mt-6 text-sm opacity-80">

集合ではなく多重集合にするのは、要素の重複を調べなくて済むから（本）。この規則を、同じ `evaluateM` と新しい Monad `Many` で実現する。

</div>

<!--
本:「適切な Monad があれば、まったく同じ evaluateM が、失敗しない答えの集合を非決定的に探索できる」。
選択を表すために、引数のどちらかを選ぶ choose を式の言語に足す。
-->

---

# 答えの多重集合 Many

<LeanIntent name="many" />

<!-- lean:code many -->
<<< @/generated/snippets/many@1.lean {*|3}
<!-- /lean -->

<LeanCaption name="many" />

<!--
lean:notes many

本:「この型は List によく似ている。違いは List.cons が残りのリストを持つのに対し、more は残りを必要に応じて計算する関数を持つこと」。
-->

---

# 一つの答え、答えの和

<LeanIntent name="many-ops" />

<!-- lean:code many-ops -->
<<< @/generated/snippets/many-ops@1.lean {*|1|3-5}
<!-- /lean -->

<LeanCaption name="many-ops" />

<!--
lean:notes many-ops

本: 和は、最初の多重集合が空なら二つ目そのもの。そうでなければ、最初の要素に「残り と 二つ目 の和」を続けたもの。
-->

---

# 探索をつなぐ bind

<LeanIntent name="many-bind" />

<!-- lean:code many-bind -->
<<< @/generated/snippets/many-bind@1.lean {*|3|5-7}
<!-- /lean -->

<LeanCaption name="many-bind" />

<!--
lean:notes many-bind

本: 最初の段階が三つの答えを返したら、二つ目の段階は三つすべてについて試す必要がある。それらの和が探索空間全体を表す。
-->

---

# Many のモナド則を Lean で

<LeanIntent name="many-laws" />

<!-- lean:code many-laws -->
<<< @/generated/snippets/many-laws@1.lean
<!-- /lean -->

<LeanCaption name="many-laws" />

<!--
lean:notes many-laws

補題: union の右単位元が none、union の結合律、bind が union に分配すること。いずれも帰納法と simp。
-->

---

# 探索の例: 合計が 15 になる組

<LeanIntent name="adds-to" />

<div class="grid grid-cols-[3fr_2fr] gap-4">
<div>

<!-- lean:code adds-to -->
<<< @/generated/snippets/adds-to@1.lean {*|11|12-13}
<!-- /lean -->

</div>
<div class="adds-to-output">

<!-- lean:eval eval-adds-to -->
```lean
#eval printList (addsTo 15 [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]).takeAll
```
<div class="lean-output">

```text
[7, 8]
[6, 9]
[5, 10]
[4, 5, 6]
[3, 5, 7]
[3, 4, 8]
[2, 6, 7]
[2, 5, 8]
[2, 4, 9]
[2, 3, 10]
[2, 3, 4, 6]
[1, 6, 8]
[1, 5, 9]
[1, 4, 10]
[1, 3, 5, 6]
[1, 3, 4, 7]
[1, 2, 5, 7]
[1, 2, 4, 8]
[1, 2, 3, 9]
[1, 2, 3, 4, 5]
```

</div>
<!-- /lean -->

</div>
</div>

<LeanCaption name="adds-to" />

<!--
lean:notes adds-to

本: 先頭が候補なら、答えはそれを含むか含まないかのどちらか。含まない答えは残りへの再帰で、含む答えは目標から先頭を引いて再帰し、先頭を付け足して得る。
-->

---

# 評価器で探索する

<LeanIntent name="apply-search" />

<!-- lean:code apply-search -->
<<< @/generated/snippets/apply-search@1.lean {*|7|9}
<!-- /lean -->

<LeanCaption name="apply-search" />

<!--
lean:notes apply-search

本:「適切な Monad があれば、まったく同じ evaluateM が、失敗しない答えの集合を非決定的に探索できる」。
-->

---

# 探索の結果

<LeanIntent name="eval-search" />

<!-- lean:eval eval-search -->
```lean
open Expr Prim NeedsSearch in
#eval (evaluateM applySearch
        (prim plus (const 1) (prim (other choose) (const 2) (const 5)))).takeAll
```
<div class="lean-output">

```text
[3, 6]
```

</div>

```lean
open Expr Prim NeedsSearch in
#eval (evaluateM applySearch
        (prim plus (const 1) (prim (other div) (const 2) (const 0)))).takeAll
```
<div class="lean-output">

```text
[]
```

</div>

```lean
open Expr Prim NeedsSearch in
#eval (evaluateM applySearch
        (prim (other div) (const 90)
          (prim plus (prim (other choose) (const (-5)) (const 5)) (const 5)))).takeAll
```
<div class="lean-output">

```text
[9]
```

</div>
<!-- /lean -->

<LeanCaption name="eval-search" />

<!--
lean:notes eval-search

本の三つの例。前のスライドの規則で計算した結果と比べてみる。
-->

---

# 環境を読む: 評価の規則

<div class="lean-intent-static">
演算子を文字列で書き、名前から実装への対応（環境）を渡せば、利用者が評価器を拡張できる（剰余や最大値など）。評価は「環境を受け取る関数」になる。
</div>

- 定数 $n$ は定数関数 $\lambda e.\, n$
- 算術演算子は環境をそのまま渡す: $f + g$ は $\lambda e.\, f(e) + g(e)$
- 利用者の演算子 $f\ \mathrm{OP}\ g$ は

$$
\lambda e.
\begin{cases}
h(f(e), g(e)) & \mathrm{if}\ e\ \mathrm{contains}\ (\mathrm{OP}, h) \\
0 & \mathrm{otherwise}
\end{cases}
$$

<div class="text-sm opacity-80">

環境は再帰呼び出しのたびに渡す必要がある。評価器に引数を足したくなるが、本によれば「このように引数を渡すことも、Monad の一つの形」。

</div>

<!--
本: 関数を Monad として使うものは reader monad と呼ばれる。0 は未知の演算子のための代わりの値。
-->

---

# Reader: 環境を受け取る関数

<LeanIntent name="reader" />

<!-- lean:code reader -->
<<< @/generated/snippets/reader@1.lean {*|1|3|5}
<!-- /lean -->

<LeanCaption name="reader" />

<!--
lean:notes reader

本: 関数を Monad として使うものは、ふつう reader monad と呼ばれる。
-->

---

# bind を型に従って書く

<LeanIntent name="reader-bind" />

<div class="grid grid-cols-[3fr_2fr] gap-4">
<div>

<!-- lean:code reader-bind -->
````md magic-move
<<< @/generated/snippets/reader-bind@1.lean
<<< @/generated/snippets/reader-bind@2.lean
<<< @/generated/snippets/reader-bind@3.lean
<<< @/generated/snippets/reader-bind@4.lean
<<< @/generated/snippets/reader-bind@5.lean
<<< @/generated/snippets/reader-bind@6.lean
````
<!-- /lean -->

</div>
<div>

<LeanMessages name="reader-bind" />

</div>
</div>

<LeanCaption name="reader-bind" />

<!--
lean:notes reader-bind

**@1** 本:「⊢ は、地下鉄の改札に似ていることから turnstile と呼ばれる」。
-->

---

# Monad (Reader ρ)

<LeanIntent name="reader-laws" />

<!-- lean:code reader-laws -->
<<< @/generated/snippets/reader-laws@1.lean
<!-- /lean -->

<LeanCaption name="reader-laws" />

<!-- lean:code reader-instance -->
<<< @/generated/snippets/reader-instance@1.lean
<!-- /lean -->

<!--
lean:notes reader-laws

本の計算: Reader.bind (Reader.pure v) f → fun env => f ((Reader.pure v) env) env → … → f v。
-->

---

# 環境から演算子を引く

<LeanIntent name="apply-reader" />

<!-- lean:code apply-reader -->
<<< @/generated/snippets/apply-reader@1.lean {*|3|6-7}
<!-- /lean -->

<LeanCaption name="apply-reader" />

<!--
lean:notes apply-reader

本: 評価器に環境の引数を足して再帰のたびに渡す、と考えるかもしれない。だが適切な Monad インスタンスがあれば、評価器は変えずに使える。
-->

---

# 環境を渡して評価する

<LeanIntent name="eval-reader" />

<!-- lean:eval eval-reader -->
```lean
open Expr Prim in
#eval evaluateM applyPrimReader
        (prim (other "max") (prim plus (const 5) (const 4))
          (prim times (const 3) (const 2)))
        exampleEnv
```
<div class="lean-output">

```text
9
```

</div>
<!-- /lean -->

<LeanCaption name="eval-reader" />

<!--
lean:notes eval-reader

evaluateM ... の結果は Reader Env Int、つまり Env → Int なので、最後に exampleEnv を渡している。
-->

---

# Lean で何が保証されているか

<LeanIntent name="theorem" />

- スライドのコードは本の定義そのもの（`lean/Arith/`）
- 表示した `#eval` の出力と、`_` に対する Lean のメッセージは `#guard_msgs` で検査済み
- `Many` と `Reader` のモナド則は証明済み（本では手計算）
- トレースの**結果**は、任意の Monad・任意の式で `evaluateM` と一致することを証明済み（ステップ列は `#guard` で固定）

<!-- lean:code theorem -->
<<< @/generated/snippets/theorem@1.lean
<!-- /lean -->

<LeanCaption name="theorem" />

<!--
lean:notes theorem

証明は構造的帰納法と simp だけ。結果側は evaluateM と同じ >>= の連鎖で組んでいる。
-->

---

# まとめ

<div class="p-4 border-l-4 border-blue-500 mb-4">

**評価器を一度だけ書き、作用は後から Monad として選べるか？** ── できる。

</div>

<div class="grid grid-cols-[3fr_2fr] gap-6 items-start">
<div>

- `evaluateM` は Monad について多相。木の辿り方は一度だけ書く
- 作用は、特別な演算子の扱い（`applySpecial`）と Monad として外から渡す
- 評価器の違いが「作用の扱いだけ」であることが、コードの形に現れた
- `Many` や `Reader` は多くの言語では組み込みにくい作用だが、型クラスと Monad があれば他の作用と同じように使える（本）

</div>
<div>

| Monad | 作用 |
|---|---|
| `Option` | 理由なしの失敗 |
| `Except String` | 理由つきの失敗 |
| `Id` | 作用なし |
| `Many` | 非決定的な探索 |
| `Reader Env` | 環境の参照 |

</div>
</div>

<!--
本: Reader に当たるものとして、Common Lisp・Clojure・Emacs Lisp の動的変数、Scheme や Racket のパラメータオブジェクトがある。
演習（4.3.3.4: モナド則の確認、失敗する Reader、トレースする評価器）はこのデッキでは扱わない。
次の節（4.4）は do 記法。
-->
