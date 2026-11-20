import Book.Sec4_3.Evaluate

/-!
FPIL 4.3.3 Further Effects (introduction) and 4.3.3.1 No Effects — the book's code, verbatim.

From here on the book's final `applyPrim` and `evaluateM` live at the top level, as in
the book. The sequence `evaluate-special` starts from the last frame of
`evaluate-generic` (V5, in `Evaluate.lean`).
-/

-- region: prim @1
-- intent: 作用を持つのは割り算だけ。基本演算子（足し算・引き算・掛け算）と「特別な演算子」を分け、特別な演算子の型を `special` として受け取る。
-- caption: 割り算は `CanFail` という別の型になった。本によれば、この名前は「割り算の作用は失敗しうること」を表す。
-- note: 本:「割り算の唯一の副作用は失敗だが、ほかの基本演算子を式に足せば、ほかの作用も表せる」。
-- note: そのための最初の一歩が、割り算をプリミティブの型から取り出すこと。
inductive Prim (special : Type) where
  | plus
  | minus
  | times
  | other : special → Prim special          -- step 1

inductive CanFail where                     -- step 2
  | div                                     -- step 2
-- endregion

-- region: evaluate-special @2
-- caption: 評価器の形は変わらない。`Prim.other` は `applySpecial` に任され、作用は渡す関数と Monad が決める。
-- note: 割り算専用だった引数を、任意の特別な演算子を処理する引数に広げる。
def divOption : CanFail → Int → Int → Option Int         -- step 1
  -- elide-begin
  | CanFail.div, x, y => if y == 0 then none else pure (x / y)
  -- elide-end

def divExcept : CanFail → Int → Int → Except String Int  -- step 1
  -- elide-begin
  | CanFail.div, x, y =>
    if y == 0 then
      Except.error s!"Tried to divide {x} by zero"
    else pure (x / y)
  -- elide-end

def applyPrim [Monad m]
    (applySpecial : special → Int → Int → m Int)         -- step 2
    : Prim special → Int → Int → m Int                   -- step 2
  -- elide-begin
  | Prim.plus, x, y => pure (x + y)
  | Prim.minus, x, y => pure (x - y)
  | Prim.times, x, y => pure (x * y)
  -- elide-end
  | Prim.other op, x, y => applySpecial op x y           -- step 2

def evaluateM [Monad m]
    (applySpecial : special → Int → Int → m Int)         -- step 3
    : Expr (Prim special) → m Int                        -- step 3
  | Expr.const i => pure i
  | Expr.prim p e1 e2 =>
    evaluateM applySpecial e1 >>= fun v1 =>
    evaluateM applySpecial e2 >>= fun v2 =>
    applyPrim applySpecial p v1 v2                       -- step 3
-- endregion

-- region: apply-empty @1
-- intent: 特別な演算子が一つもない式。値を持たない型 `Empty` を `special` にすると、`Prim.other` は作れない。だから `applyEmpty` は決して呼ばれず、結果を返す必要もない。
def applyEmpty [Monad m] (op : Empty) (_ : Int) (_ : Int) : m Int :=
  nomatch op
-- endregion

-- region: eval-empty @1
-- caption: 結果を返さないので、`applyEmpty` はどんな Monad でも使える。恒等 Monad `Id` を選ぶと、作用のまったくない普通の計算になる。
-- note: `nomatch op` は「op の型には構成子がないので、ここには来ない」と Lean に伝える。
-- note: 本: Scala や Kotlin の Nothing に似ている。
-- note: (m := Id) で Monad を明示している。Id は「何もしない」Monad。
/-- info: -9 -/
#guard_msgs in
open Expr Prim in
#eval evaluateM (m := Id) applyEmpty (prim plus (const 5) (const (-14)))
-- endregion
