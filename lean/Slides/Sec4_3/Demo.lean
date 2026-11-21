import Book.Sec4_3.Evaluate

/-!
Runs of the book's final `evaluateM` (4.3.2) that the deck shows. Slide-only: the book
defines `applyDivOption` and `applyDivExcept` but does not run these commands.
They are in namespace `V5`, like the definitions they use, so the shown commands use
the book's names unqualified.
-/

namespace V5

-- region: eval-v5 @1
-- intent: 同じ `evaluateM` に、割り算の扱いだけを差し替えて渡す。
-- caption: 一つの評価器が、失敗を `none` でも理由つきのエラーでも表せる。失敗しない式では普通に値が返る。
-- note: 割り算の関数を差し替えるだけで、同じ evaluateM が Option でも Except でも動く。
-- note: 失敗しない式ではどちらも普通に値を返す。
/-- info: none -/
#guard_msgs in
#eval evaluateM applyDivOption fourteenDivided

/-- info: Except.error "Tried to divide 14 by zero" -/
#guard_msgs in
#eval evaluateM applyDivExcept fourteenDivided

/-- info: some 5 -/
#guard_msgs in
#eval evaluateM applyDivOption twoPlusThree
-- endregion

end V5
