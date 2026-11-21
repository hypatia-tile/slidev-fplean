import Book.Sec4_3.Expr

/-!
FPIL 4.3.2 Evaluating Expressions — the book's code, verbatim.

The book redefines `evaluateOption`, `applyPrim` and `evaluateM` several times.
Each version lives in its own namespace `V1` … `V5`. The deck shows them as two
Magic Move sequences, with the `#eval` of V2 in between (the book's order):
`evaluate-option` (V1, V2) and `evaluate-generic` (V2, V3, V4, V5). V2 is a frame
of both.
-/

namespace V1

-- region: evaluate-option @1
-- intent: 割り算は失敗しうるので、評価の結果を `Option Int` にする。部分式の結果は `>>=` でつなぎ、失敗はそのまま外へ伝わる。
-- caption: 動くが、部分式の評価と演算子の適用という二つの関心が一つの関数に混ざっている。
-- note: まずは Option に直接書く。部分式を評価して `>>=` でつなぐ。
-- note: 割り算だけが失敗しうる。本は「この関数は二つの関心を混ぜている」と指摘する。
def evaluateOption : Expr Arith → Option Int
  | Expr.const i => pure i                              -- step 1
  | Expr.prim p e1 e2 =>                                -- step 2
    evaluateOption e1 >>= fun v1 =>                     -- step 2
    evaluateOption e2 >>= fun v2 =>                     -- step 2
    match p with                                        -- step 3
    | Arith.plus => pure (v1 + v2)                      -- step 3
    | Arith.minus => pure (v1 - v2)                     -- step 3
    | Arith.times => pure (v1 * v2)                     -- step 3
    | Arith.div => if v2 == 0 then none else pure (v1 / v2)  -- step 4
-- endregion

-- region: eval-v1 @1
-- intent: `fourteenDivided` を評価してみる。
-- caption: 失敗したことは分かるが、なぜ失敗したかは分からない。本の言葉では「あまり役に立つエラーメッセージではない」。
-- note: 分母が 0 なので none。Option は失敗の理由を運べない。
/-- info: none -/
#guard_msgs in
#eval evaluateOption fourteenDivided
-- endregion

end V1

namespace V2

-- region: evaluate-option @2, evaluate-generic @1
-- intent(evaluate-option): 二つの関心を分けるため、演算子の適用を `applyPrim` に切り出す。
-- caption(evaluate-option): 評価器は木を辿るだけになった。失敗の扱いは `applyPrim` と `>>=` に集まっている。
-- intent(evaluate-generic): 失敗の理由も運びたい。失敗の扱いは `applyPrim` と `>>=` に集まっているので、変える場所は少ないはず。
-- caption(evaluate-generic): `Option` に依存しているのは、二つの型と、失敗を表す `none` だけ。
-- note(evaluate-option): 演算子の適用を `applyPrim` に切り出す。`evaluateOption` は木を辿るだけになる。
-- note(evaluate-generic): 前のスライドの最後の形から始める。ここから Except に置き換える。
def applyPrim : Arith → Int → Int → Option Int          -- step 1
  | Arith.plus, x, y => pure (x + y)                    -- step 1
  | Arith.minus, x, y => pure (x - y)                   -- step 1
  | Arith.times, x, y => pure (x * y)                   -- step 1
  | Arith.div, x, y => if y == 0 then none else pure (x / y)  -- step 1

def evaluateOption : Expr Arith → Option Int
  | Expr.const i => pure i
  | Expr.prim p e1 e2 =>
    evaluateOption e1 >>= fun v1 =>
    evaluateOption e2 >>= fun v2 =>
    applyPrim p v1 v2                                   -- step 2
-- endregion

end V2

namespace V3

-- region: evaluate-generic @2
-- intent: 失敗の理由を文字列で運ぶため、`Option` を `Except String` に置き換える。
-- caption: 変わったのは型と失敗の箇所だけ。`>>=` で書いてあったので、評価器の形はそのまま。
-- note: エラーメッセージが欲しいので Except String に置き換える。
-- note: 本は「>>= を使っていたので、小さな変更で済む」と言う。
def applyPrim : Arith → Int → Int → Except String Int   -- step 1
  | Arith.plus, x, y => pure (x + y)
  | Arith.minus, x, y => pure (x - y)
  | Arith.times, x, y => pure (x * y)
  | Arith.div, x, y =>
    if y == 0 then
      Except.error s!"Tried to divide {x} by zero"      -- step 2
    else pure (x / y)

def evaluateExcept : Expr Arith → Except String Int     -- step 1
  | Expr.const i => pure i
  | Expr.prim p e1 e2 =>
    evaluateExcept e1 >>= fun v1 =>
    evaluateExcept e2 >>= fun v2 =>
    applyPrim p v1 v2
-- endregion

end V3

namespace V4

-- region: evaluate-generic @3
-- intent: 二つの評価器は Monad 以外同じ形。Monad について多相にし、演算子の適用を引数で受け取れば、評価器は一つで済む。
-- caption: `evaluateM` は Option でも Except でも動く。ただし `applyPrimOption` と `applyPrimExcept` はまだほとんど同じ。
-- note: 二つの評価器は Monad 以外同じ。`applyPrim` を引数にして一般化する。
def applyPrimOption : Arith → Int → Int → Option Int
  -- elide-begin
  | Arith.plus, x, y => pure (x + y)
  | Arith.minus, x, y => pure (x - y)
  | Arith.times, x, y => pure (x * y)
  | Arith.div, x, y =>
    if y == 0 then
      none
    else pure (x / y)
  -- elide-end

def applyPrimExcept : Arith → Int → Int → Except String Int
  -- elide-begin
  | Arith.plus, x, y => pure (x + y)
  | Arith.minus, x, y => pure (x - y)
  | Arith.times, x, y => pure (x * y)
  | Arith.div, x, y =>
    if y == 0 then
      Except.error s!"Tried to divide {x} by zero"
    else pure (x / y)
  -- elide-end

def evaluateM [Monad m]                                 -- step 1
    (applyPrim : Arith → Int → Int → m Int)             -- step 1
    : Expr Arith → m Int                                -- step 1
  | Expr.const i => pure i
  | Expr.prim p e1 e2 =>
    evaluateM applyPrim e1 >>= fun v1 =>
    evaluateM applyPrim e2 >>= fun v2 =>
    applyPrim p v1 v2                                   -- step 2
-- endregion

-- region: eval-v4 @1
-- note: 同じ `evaluateM` が、渡す関数によって違う Monad で動く。
/-- info: none -/
#guard_msgs in
#eval evaluateM applyPrimOption fourteenDivided

/-- info: Except.error "Tried to divide 14 by zero" -/
#guard_msgs in
#eval evaluateM applyPrimExcept fourteenDivided
-- endregion

end V4

namespace V5

-- region: evaluate-generic @4, evaluate-special @1
-- intent(evaluate-generic): 二つの `applyPrim` で違うのは割り算の扱いだけ。違う部分だけを `applyDiv` として引数にする。
-- caption(evaluate-generic): 二つの評価の違いは失敗の扱いだけ、ということがコードの形で明らかになった。
-- note(evaluate-generic): Option 版と Except 版で違うのは割り算だけ。そこだけを引数にする。
-- note(evaluate-generic): 本の結論:「二つのコードパスが失敗の扱いだけで異なることが、完全に明らかになった」。
-- intent(evaluate-special): 割り算専用の引数 `applyDiv` を、どんな特別な演算子でも処理する `applySpecial` に広げる。
-- caption(evaluate-special): 4.3.2 の最後の形。演算子の型は `Arith` で、割り算だけが引数 `applyDiv` に任されている。
-- note(evaluate-special): 4.3.2 の最後の形から始める。
def applyDivOption (x : Int) (y : Int) : Option Int :=  -- step 1
  if y == 0 then none else pure (x / y)

def applyDivExcept (x : Int) (y : Int) : Except String Int :=  -- step 1
  -- elide-begin
  if y == 0 then
    Except.error s!"Tried to divide {x} by zero"
  else pure (x / y)
  -- elide-end

def applyPrim [Monad m]
    (applyDiv : Int → Int → m Int)                      -- step 2
    : Arith → Int → Int → m Int
  -- elide-begin
  | Arith.plus, x, y => pure (x + y)
  | Arith.minus, x, y => pure (x - y)
  | Arith.times, x, y => pure (x * y)
  -- elide-end
  | Arith.div, x, y => applyDiv x y                     -- step 2

def evaluateM [Monad m]
    (applyDiv : Int → Int → m Int)                      -- step 3
    : Expr Arith → m Int
  | Expr.const i => pure i
  | Expr.prim p e1 e2 =>
    evaluateM applyDiv e1 >>= fun v1 =>
    evaluateM applyDiv e2 >>= fun v2 =>
    applyPrim applyDiv p v1 v2                          -- step 3
-- endregion

end V5
