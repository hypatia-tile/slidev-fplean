def applyPrimOption : Arith → Int → Int → Option Int
  ...

def applyPrimExcept : Arith → Int → Int → Except String Int
  ...

def evaluateM [Monad m]
    (applyPrim : Arith → Int → Int → m Int)
    : Expr Arith → m Int
  | Expr.const i => pure i
  | Expr.prim p e1 e2 =>
    evaluateM applyPrim e1 >>= fun v1 =>
    evaluateM applyPrim e2 >>= fun v2 =>
    applyPrim p v1 v2
