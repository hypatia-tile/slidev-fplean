/-- The traced evaluator computes exactly what the book's `evaluateM` computes. -/
theorem evaluateTraced_result [Monad m]
    (applyDiv : Int → Int → m Int) (observe : m Int → Except String Int)
    (path : Path) (e : Expr Arith) :
    (evaluateTraced applyDiv observe path e).1 = V5.evaluateM applyDiv e := by
  induction e generalizing path with
  | const i => rfl
  | prim p e1 e2 ih1 ih2 =>
    simp only [evaluateTraced, V5.evaluateM, ih1, ih2]
