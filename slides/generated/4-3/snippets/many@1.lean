inductive Many (α : Type) where
  | none : Many α
  | more : α → (Unit → Many α) → Many α
