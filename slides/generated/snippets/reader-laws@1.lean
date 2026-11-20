theorem Reader.bind_pure_left (v : α) (f : α → Reader ρ β) :
    Reader.bind (Reader.pure v) f = f v := rfl

theorem Reader.bind_pure_right (r : Reader ρ α) :
    Reader.bind r Reader.pure = r := rfl

theorem Reader.bind_assoc (r : Reader ρ α) (f : α → Reader ρ β) (g : β → Reader ρ γ) :
    Reader.bind (Reader.bind r f) g = Reader.bind r (fun x => Reader.bind (f x) g) := rfl
