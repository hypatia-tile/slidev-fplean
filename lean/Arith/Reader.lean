import Arith.Further

/-!
FPIL 4.3.3.3 Custom Environments — the book's code, verbatim.

The book writes `Reader.bind` step by step, filling one underscore at a time and reading
Lean's message about it. Each step lives in its own namespace `Hole1` … `Hole5` (they
all define `Reader.bind`); the messages are pinned with `#guard_msgs` and shown next to
the code by <LeanMessages>.
-/

-- region: reader @1
-- intent: 環境を読む作用を、環境を受け取る関数として表す。`read` は環境そのものを返す作用。
-- caption: 定数は環境によらず同じ値になる（$\lambda e.\, n$）。だから `pure` は定数関数にする。慣習で、環境はギリシャ文字 ρ（ロー）で書く。
-- note: 本: 関数を Monad として使うものは、ふつう reader monad と呼ばれる。
def Reader (ρ : Type) (α : Type) : Type := ρ → α   -- step 1

def read : Reader ρ ρ := fun env => env           -- step 2

def Reader.pure (x : α) : Reader ρ α := fun _ => x -- step 3
-- endregion

namespace Hole1

-- region: reader-bind @1
-- intent: `bind` の型 $(\rho \to \alpha) \to (\alpha \to \rho \to \beta) \to (\rho \to \beta)$ を書き、本体を `_` にして、Lean に何が必要かを尋ねる。
-- caption: ⊢ の右が、`_` に求められている型。左は使える変数。欲しいのは関数 `ρ → β` なので、まず `fun` で包む。
-- note: 本:「⊢ は、地下鉄の改札に似ていることから turnstile と呼ばれる」。
/--
error: don't know how to synthesize placeholder
context:
ρ α β : Type
result : ρ → α
next : α → ρ → β
⊢ ρ → β
-/
#guard_msgs in
def Reader.bind {ρ : Type} {α : Type} {β : Type}
    (result : ρ → α) (next : α → ρ → β) : ρ → β :=
  _
-- endregion

end Hole1

namespace Hole2

-- region: reader-bind @2
-- caption: 引数 `env` が文脈に現れ、求められる型は `β` になった。`β` を作れるのは `next` だけで、引数を二つ取る。
/--
error: don't know how to synthesize placeholder
context:
ρ α β : Type
result : ρ → α
next : α → ρ → β
env : ρ
⊢ β
-/
#guard_msgs in
def Reader.bind {ρ : Type} {α : Type} {β : Type}
    (result : ρ → α) (next : α → ρ → β) : ρ → β :=
  fun env => _
-- endregion

end Hole2

namespace Hole3

-- Lean reports the second `_` first. Sorting the messages by text (α < ρ) puts them in
-- source order, as the book lists them.

-- region: reader-bind @3
-- caption: 一つ目の `_` には `α` が、二つ目には `ρ` が求められている。`α` を作れるのは `result` だけ。
/--
error: don't know how to synthesize placeholder
context:
ρ α β : Type
result : ρ → α
next : α → ρ → β
env : ρ
⊢ α
---
error: don't know how to synthesize placeholder
context:
ρ α β : Type
result : ρ → α
next : α → ρ → β
env : ρ
⊢ ρ
-/
#guard_msgs (ordering := sorted) in
def Reader.bind {ρ : Type} {α : Type} {β : Type}
    (result : ρ → α) (next : α → ρ → β) : ρ → β :=
  fun env => next _ _
-- endregion

end Hole3

namespace Hole4

-- region: reader-bind @4
-- caption: 二つの `_` のどちらにも `ρ` が求められている。手元の `ρ` は `env` だけ。
/--
error: don't know how to synthesize placeholder
context:
ρ α β : Type
result : ρ → α
next : α → ρ → β
env : ρ
⊢ ρ
---
error: don't know how to synthesize placeholder
context:
ρ α β : Type
result : ρ → α
next : α → ρ → β
env : ρ
⊢ ρ
-/
#guard_msgs in
def Reader.bind {ρ : Type} {α : Type} {β : Type}
    (result : ρ → α) (next : α → ρ → β) : ρ → β :=
  fun env => next (result _) _
-- endregion

end Hole4

namespace Hole5

-- region: reader-bind @5
-- caption: 型が埋まった。`Reader` の定義を戻し、型の明示を片付ける（次）。
def Reader.bind {ρ : Type} {α : Type} {β : Type}
    (result : ρ → α) (next : α → ρ → β) : ρ → β :=
  fun env => next (result env) env
-- endregion

end Hole5

-- region: reader-bind @6
-- caption: `Id` の `bind` と同じ形で、追加の引数（環境）を両方に渡すだけ。本:「型に従うだけで正しい関数が書けるとは限らないが、`_` を埋める過程から洞察が得られることもある」。
def Reader.bind (result : Reader ρ α) (next : α → Reader ρ β) : Reader ρ β :=
  fun env => next (result env) env
-- endregion

-- region: reader-instance @1
instance : Monad (Reader ρ) where
  pure x := fun _ => x
  bind x f := fun env => f (x env) env
-- endregion

-- region: apply-reader @1
-- intent: 環境は、演算子の名前と実装の組のリスト。演算子を文字列で書き、環境から実装を引いて適用する。知らない演算子は 0 にする。
-- caption: `evaluateM` はそのまま。環境を受け取る引数を足す必要はない。本:「このように引数を渡すことも、Monad の一つの形」。
-- note: 本: 評価器に環境の引数を足して再帰のたびに渡す、と考えるかもしれない。だが適切な Monad インスタンスがあれば、評価器は変えずに使える。
abbrev Env : Type := List (String × (Int → Int → Int))

def exampleEnv : Env := [("max", max), ("mod", (· % ·))]   -- step 1

def applyPrimReader (op : String) (x : Int) (y : Int) : Reader Env Int :=
  read >>= fun env =>                                       -- step 2
  match env.lookup op with                                  -- step 2
  | none => pure 0
  | some f => pure (f x y)
-- endregion

-- region: eval-reader @1
-- intent: 利用者定義の演算子 `"max"` を含む式を、`applyPrimReader` を渡した `evaluateM` で評価する。
-- caption: 評価の結果は「環境を待つ関数」。`exampleEnv` を渡すと、`"max"` が `max` に引かれて $\max(5 + 4,\ 3 \times 2)$ が計算される。
-- note: evaluateM ... の結果は Reader Env Int、つまり Env → Int なので、最後に exampleEnv を渡している。
/-- info: 9 -/
#guard_msgs in
open Expr Prim in
#eval evaluateM applyPrimReader
        (prim (other "max") (prim plus (const 5) (const 4))
          (prim times (const 3) (const 2)))
        exampleEnv
-- endregion
