instance : Monad (Reader ρ) where
  pure x := fun _ => x
  bind x f := fun env => f (x env) env
