theorem Many.bind_one_left (v : α) (f : α → Many β) :
    Many.bind (Many.one v) f = f v := by
  ...

theorem Many.bind_one_right (v : Many α) :
    Many.bind v Many.one = v := by
  ...

theorem Many.bind_assoc (v : Many α) (f : α → Many β) (g : β → Many γ) :
    Many.bind (Many.bind v f) g = Many.bind v (fun x => Many.bind (f x) g) := by
  ...
