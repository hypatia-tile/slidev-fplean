def Many.bind : Many α → (α → Many β) → Many β
  | Many.none, _ => Many.none
  | Many.more x xs, f => (f x).union (bind (xs ()) f)

instance : Monad Many where
  pure := Many.one
  bind := Many.bind
