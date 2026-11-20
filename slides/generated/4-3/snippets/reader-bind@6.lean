def Reader.bind (result : Reader ρ α) (next : α → Reader ρ β) : Reader ρ β :=
  fun env => next (result env) env
