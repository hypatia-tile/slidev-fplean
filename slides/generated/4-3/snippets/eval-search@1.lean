open Expr Prim NeedsSearch in
#eval (evaluateM applySearch
        (prim plus (const 1) (prim (other choose) (const 2) (const 5)))).takeAll

open Expr Prim NeedsSearch in
#eval (evaluateM applySearch
        (prim plus (const 1) (prim (other div) (const 2) (const 0)))).takeAll

open Expr Prim NeedsSearch in
#eval (evaluateM applySearch
        (prim (other div) (const 90)
          (prim plus (prim (other choose) (const (-5)) (const 5)) (const 5)))).takeAll
