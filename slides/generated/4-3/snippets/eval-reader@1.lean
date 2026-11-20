open Expr Prim in
#eval evaluateM applyPrimReader
        (prim (other "max") (prim plus (const 5) (const 4))
          (prim times (const 3) (const 2)))
        exampleEnv
