inductive NeedsSearch
  | div
  | choose

def applySearch : NeedsSearch → Int → Int → Many Int
  | NeedsSearch.choose, x, y =>
    Many.fromList [x, y]
  | NeedsSearch.div, x, y =>
    if y == 0 then Many.none
    else Many.one (x / y)
