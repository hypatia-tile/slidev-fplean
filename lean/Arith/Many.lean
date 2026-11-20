import Arith.Further

/-!
FPIL 4.3.3.2 Nondeterministic Search — the book's code, verbatim.
-/

-- region: many @1
-- intent: 答えの多重集合を表す Monad を作る。答えがない場合と、一つの答えに「残りの答え」が続く場合を表せればよい。
-- caption: `List` に似ているが、`more` は残りの答えそのものではなく、残りを必要になったときに計算する関数を持つ。だから、欲しい数だけ答えが見つかれば探索を止められる。
-- note: 本:「この型は List によく似ている。違いは List.cons が残りのリストを持つのに対し、more は残りを必要に応じて計算する関数を持つこと」。
inductive Many (α : Type) where
  | none : Many α
  | more : α → (Unit → Many α) → Many α   -- step 1
-- endregion

-- region: many-ops @1
-- intent: 答えが一つの場合と、二つの多重集合の和を定義する。和は、最初の多重集合の答えを順に並べ、その後ろに二つ目を続ける。
-- caption: リストから作る `fromList`、答えを取り出す `take`・`takeAll` もある。取り出す側は、`more` の関数を呼ぶたびに次の答えを計算する。
-- note: 本: 和は、最初の多重集合が空なら二つ目そのもの。そうでなければ、最初の要素に「残り と 二つ目 の和」を続けたもの。
def Many.one (x : α) : Many α := Many.more x (fun () => Many.none)   -- step 1

def Many.union : Many α → Many α → Many α                            -- step 2
  | Many.none, ys => ys                                               -- step 2
  | Many.more x xs, ys => Many.more x (fun () => union (xs ()) ys)    -- step 2

def Many.fromList : List α → Many α
  -- elide-begin
  | [] => Many.none
  | x :: xs => Many.more x (fun () => fromList xs)
  -- elide-end

def Many.take : Nat → Many α → List α
  -- elide-begin
  | 0, _ => []
  | _ + 1, Many.none => []
  | n + 1, Many.more x xs => x :: (xs ()).take n
  -- elide-end

def Many.takeAll : Many α → List α
  -- elide-begin
  | Many.none => []
  | Many.more x xs => x :: (xs ()).takeAll
  -- elide-end
-- endregion

-- region: many-bind @1
-- intent: 二つの処理をつなぐ `bind` は、最初の段階のすべての答えに残りの処理を試し、その結果の和をとる。$\mathrm{bind}\ \{v_1, \dots, v_n\}\ f = f\,v_1 \cup \dots \cup f\,v_n$
-- caption: `one` と `bind` で `Monad Many` のインスタンスができる。本はモナド則を手で確かめている。
-- note: 本: 最初の段階が三つの答えを返したら、二つ目の段階は三つすべてについて試す必要がある。それらの和が探索空間全体を表す。
def Many.bind : Many α → (α → Many β) → Many β
  | Many.none, _ => Many.none
  | Many.more x xs, f => (f x).union (bind (xs ()) f)   -- step 1

instance : Monad Many where   -- step 2
  pure := Many.one            -- step 2
  bind := Many.bind           -- step 2
-- endregion

-- region: adds-to @1
-- intent: 合計がちょうど目標になる組をすべて探す。先頭の数を使う場合と使わない場合を `union` で合わせる。
-- caption: 目標より大きい数は使えない。空のリストに着いたとき、目標が 0 なら成功、そうでなければ失敗（答えなし）。
-- note: 本: 先頭が候補なら、答えはそれを含むか含まないかのどちらか。含まない答えは残りへの再帰で、含む答えは目標から先頭を引いて再帰し、先頭を付け足して得る。
def addsTo (goal : Nat) : List Nat → Many (List Nat)
  | [] =>
    if goal == 0 then
      pure []
    else
      Many.none
  | x :: xs =>
    if x > goal then
      addsTo goal xs
    else
      (addsTo goal xs).union                                 -- step 1
        (addsTo (goal - x) xs >>= fun answer =>              -- step 2
         pure (x :: answer))                                 -- step 2

def printList [ToString α] : List α → IO Unit
  -- elide-begin
  | [] => pure ()
  | x :: xs => do
    IO.println x
    printList xs
  -- elide-end
-- endregion

-- region: eval-adds-to @1
/--
info: [7, 8]
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
-/
#guard_msgs in
#eval printList (addsTo 15 [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]).takeAll
-- endregion

-- region: apply-search @1
-- intent: 評価器に戻る。割り算に加えて、二つの引数のどちらかを選ぶ演算子 `choose` を特別な演算子にする。ゼロ除算はその選び方を無効にする（答えなし）。
-- caption: `evaluateM` は 4.3.3 冒頭のものをそのまま使う。変わったのは、特別な演算子の型と、それを処理する関数だけ。
-- note: 本:「適切な Monad があれば、まったく同じ evaluateM が、失敗しない答えの集合を非決定的に探索できる」。
inductive NeedsSearch
  | div
  | choose

def applySearch : NeedsSearch → Int → Int → Many Int
  | NeedsSearch.choose, x, y =>
    Many.fromList [x, y]                         -- step 1
  | NeedsSearch.div, x, y =>
    if y == 0 then Many.none                     -- step 2
    else Many.one (x / y)
-- endregion

-- region: eval-search @1
-- intent: 規則のスライドで見た本の三つの式を、`applySearch` を渡した `evaluateM` で評価し、答えをすべて取り出す。
-- caption: 順に $1 + \mathrm{choose}(2, 5)$、$1 + 2 / 0$、$90 / (\mathrm{choose}(-5, 5) + 5)$。三つ目では $-5$ を選ぶとゼロ除算になり、その選び方は捨てられる。
-- note: 本の三つの例。前のスライドの規則で計算した結果と比べてみる。
/-- info: [3, 6] -/
#guard_msgs in
open Expr Prim NeedsSearch in
#eval (evaluateM applySearch
        (prim plus (const 1) (prim (other choose) (const 2) (const 5)))).takeAll

/-- info: [] -/
#guard_msgs in
open Expr Prim NeedsSearch in
#eval (evaluateM applySearch
        (prim plus (const 1) (prim (other div) (const 2) (const 0)))).takeAll

/-- info: [9] -/
#guard_msgs in
open Expr Prim NeedsSearch in
#eval (evaluateM applySearch
        (prim (other div) (const 90)
          (prim plus (prim (other choose) (const (-5)) (const 5)) (const 5)))).takeAll
-- endregion
