def Reader.bind {ρ : Type} {α : Type} {β : Type}
    (result : ρ → α) (next : α → ρ → β) : ρ → β :=
  fun env => _
