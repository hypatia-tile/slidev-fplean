def divOption : CanFail → Int → Int → Option Int
  ...

def divExcept : CanFail → Int → Int → Except String Int
  ...

def applyPrim [Monad m]
    (applySpecial : special → Int → Int → m Int)
    : Prim special → Int → Int → m Int
  ...
  | Prim.other op, x, y => applySpecial op x y

def evaluateM [Monad m]
    (applySpecial : special → Int → Int → m Int)
    : Expr (Prim special) → m Int
  | Expr.const i => pure i
  | Expr.prim p e1 e2 =>
    evaluateM applySpecial e1 >>= fun v1 =>
    evaluateM applySpecial e2 >>= fun v2 =>
    applyPrim applySpecial p v1 v2
