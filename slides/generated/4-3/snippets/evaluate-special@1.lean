def applyDivOption (x : Int) (y : Int) : Option Int :=
  if y == 0 then none else pure (x / y)

def applyDivExcept (x : Int) (y : Int) : Except String Int :=
  ...

def applyPrim [Monad m]
    (applyDiv : Int → Int → m Int)
    : Arith → Int → Int → m Int
  ...
  | Arith.div, x, y => applyDiv x y

def evaluateM [Monad m]
    (applyDiv : Int → Int → m Int)
    : Expr Arith → m Int
  | Expr.const i => pure i
  | Expr.prim p e1 e2 =>
    evaluateM applyDiv e1 >>= fun v1 =>
    evaluateM applyDiv e2 >>= fun v2 =>
    applyPrim applyDiv p v1 v2
