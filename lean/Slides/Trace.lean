import Arith
import Lean.Data.Json

/-!
A traced copy of `V5.evaluateM`, used only to drive the deck's trace animation.

`evaluateTraced` returns the same monadic result as `V5.evaluateM` together with
the list of steps a reader would follow through the expression tree. The result
half is built with exactly the same `>>=` chain as the book's code, and
`evaluateTraced_result` proves the two agree for every monad and every
expression.

What that does **not** cover: the steps. They are built by a separate branch on
`observe`, so a change to that branch could make the animation tell a different
story while the result still matches. The steps of every run shown in the deck
are therefore pinned below with `#guard`, so any such change fails the build and
has to be reviewed.
-/

namespace Slides

open Lean (Json ToJson toJson)

/-- A node in the tree is addressed by the child indices from the root
(`0` = left operand, `1` = right operand). -/
abbrev Path := List Nat

inductive StepKind where
  | enter
  | ret
  | fail
  deriving Repr, BEq

instance : ToJson StepKind where
  toJson
    | .enter => "enter"
    | .ret => "return"
    | .fail => "fail"

structure Step where
  kind : StepKind
  path : Path
  value : Option String := none
  deriving Repr, BEq

instance : ToJson Step where
  toJson s :=
    let base := [("kind", toJson s.kind), ("path", toJson s.path)]
    Json.mkObj (base ++ (s.value.map (fun v => [("value", toJson v)])).getD [])

/-- `observe` tells the tracer whether a monadic value succeeded (and with what)
or failed (and what to print). It is used only to build the steps; the result
never depends on it. -/
def evaluateTraced [Monad m]
    (applyDiv : Int → Int → m Int)
    (observe : m Int → Except String Int)
    (path : Path) : Expr Arith → m Int × Array Step
  | Expr.const i =>
    (pure i, #[{ kind := .enter, path }, { kind := .ret, path, value := some (toString i) }])
  | Expr.prim p e1 e2 =>
    let (r1, s1) := evaluateTraced applyDiv observe (path ++ [0]) e1
    let (r2, s2) := evaluateTraced applyDiv observe (path ++ [1]) e2
    let result :=
      r1 >>= fun v1 =>
      r2 >>= fun v2 =>
      V5.applyPrim applyDiv p v1 v2
    let enter : Step := { kind := .enter, path }
    let fail (msg : String) : Step := { kind := .fail, path, value := some msg }
    let steps :=
      match observe r1 with
      | .error msg => #[enter] ++ s1 ++ #[fail msg]
      | .ok _ =>
        match observe r2 with
        | .error msg => #[enter] ++ s1 ++ s2 ++ #[fail msg]
        | .ok _ =>
          match observe result with
          | .error msg => #[enter] ++ s1 ++ s2 ++ #[fail msg]
          | .ok v => #[enter] ++ s1 ++ s2 ++ #[{ kind := .ret, path, value := some (toString v) }]
    (result, steps)

-- region: theorem @1
-- intent: トレースを作る `evaluateTraced` が、本の `evaluateM` と常に同じ結果を返すことを証明しておく。
-- caption: どの Monad・どの式でも成り立つ。トレース側の定義が本のコードからずれれば、`lake build` が失敗する。
-- note: 証明は構造的帰納法と simp だけ。結果側は evaluateM と同じ >>= の連鎖で組んでいる。
/-- The traced evaluator computes exactly what the book's `evaluateM` computes. -/
theorem evaluateTraced_result [Monad m]
    (applyDiv : Int → Int → m Int) (observe : m Int → Except String Int)
    (path : Path) (e : Expr Arith) :
    (evaluateTraced applyDiv observe path e).1 = V5.evaluateM applyDiv e := by
  induction e generalizing path with
  | const i => rfl
  | prim p e1 e2 ih1 ih2 =>
    simp only [evaluateTraced, V5.evaluateM, ih1, ih2]
-- endregion

def observeOption : Option Int → Except String Int
  | some v => .ok v
  | none => .error "none"

def observeExcept : Except String Int → Except String Int
  | .ok v => .ok v
  | .error msg => .error s!"error: {msg}"

def traceOption (e : Expr Arith) := evaluateTraced V5.applyDivOption observeOption [] e
def traceExcept (e : Expr Arith) := evaluateTraced V5.applyDivExcept observeExcept [] e

-- Concrete spot checks, in addition to the general theorem above.
#guard (traceOption fourteenDivided).1 == V5.evaluateM V5.applyDivOption fourteenDivided
#guard (traceOption twoPlusThree).1 == V5.evaluateM V5.applyDivOption twoPlusThree
#guard (traceExcept fourteenDivided).1.toOption == (V5.evaluateM V5.applyDivExcept fourteenDivided).toOption
#guard (traceExcept twoPlusThree).1.toOption == (V5.evaluateM V5.applyDivExcept twoPlusThree).toOption

-- The full step sequence of every run shown in the deck. Not proved: reviewed
-- by hand and pinned here, so a change to how steps are built fails the build.
private def en (p : Path) : Step := { kind := .enter, path := p }
private def rt (p : Path) (v : String) : Step := { kind := .ret, path := p, value := some v }
private def fl (p : Path) (v : String) : Step := { kind := .fail, path := p, value := some v }

/-- Left to right, depth first; the divisor `45 - 5 * 9` evaluates to `0`. -/
private def fourteenDividedPrefix : Array Step := #[
  en [], en [0], rt [0] "14",
  en [1], en [1, 0], rt [1, 0] "45",
  en [1, 1], en [1, 1, 0], rt [1, 1, 0] "5", en [1, 1, 1], rt [1, 1, 1] "9", rt [1, 1] "45",
  rt [1] "0"]

#guard (traceOption fourteenDivided).2 == fourteenDividedPrefix.push (fl [] "none")
#guard (traceExcept fourteenDivided).2 == fourteenDividedPrefix.push (fl [] "error: Tried to divide 14 by zero")
#guard (traceOption twoPlusThree).2 == #[en [], en [0], rt [0] "2", en [1], rt [1] "3", rt [] "5"]

/-- The expression tree as JSON, for drawing. -/
def arithLabel : Arith → String
  | .plus => "+"
  | .minus => "-"
  | .times => "*"
  | .div => "/"

def exprToJson : Expr Arith → Json
  | .const i => Json.mkObj [("label", toJson (toString i)), ("children", Json.arr #[])]
  | .prim p e1 e2 =>
    Json.mkObj [("label", toJson (arithLabel p)), ("children", Json.arr #[exprToJson e1, exprToJson e2])]

def run (id name monad : String) (e : Expr Arith) (steps : Array Step) : Json :=
  Json.mkObj [
    ("id", toJson id), ("example", toJson name), ("monad", toJson monad),
    ("expr", exprToJson e), ("steps", toJson steps)]

def allRuns : Json :=
  Json.arr #[
    run "fourteenDivided-option" "fourteenDivided" "Option" fourteenDivided (traceOption fourteenDivided).2,
    run "fourteenDivided-except" "fourteenDivided" "Except String" fourteenDivided (traceExcept fourteenDivided).2,
    run "twoPlusThree-option" "twoPlusThree" "Option" twoPlusThree (traceOption twoPlusThree).2]

end Slides
