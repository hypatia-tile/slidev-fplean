/-!
FPIL 4.3.1 Arithmetic Expressions — the book's code, verbatim.
-/

-- region: expr @1
-- intent: 算術式を、整数定数を葉、二項演算を節とする木として、帰納型で表す。
-- caption: 式の形（`Expr`）と演算子の集合（`Arith`）は別の型。演算子の種類は型引数 `op` で受け取る。
-- note: 本の定義どおり「整数リテラル、または二つの式に適用された基本演算子」。
-- note: クリックで const（葉）→ prim（節）→ 演算子の型 Arith の順に強調する。
inductive Expr (op : Type) where
  | const : Int → Expr op         -- step 1
  | prim : op → Expr op → Expr op → Expr op  -- step 2

inductive Arith where   -- step 3
  | plus                -- step 3
  | minus               -- step 3
  | times               -- step 3
  | div                 -- step 3
-- endregion

-- region: examples @1
-- intent: 評価器を試すための式を二つ用意する。普通に計算できる式と、ゼロ除算を含む式。
-- caption: `fourteenDivided` = 14 / (45 − 5 × 9) の分母は 0。評価器はこの失敗をどう表せばよいか？
-- note: `twoPlusThree` は失敗しない例、`fourteenDivided` は失敗する例として最後まで使う。
open Expr in
open Arith in
def twoPlusThree : Expr Arith :=
  prim plus (const 2) (const 3)

open Expr in
open Arith in
def fourteenDivided : Expr Arith :=
  prim div (const 14)
    (prim minus (const 45)
      (prim times (const 5)
        (const 9)))
-- endregion
