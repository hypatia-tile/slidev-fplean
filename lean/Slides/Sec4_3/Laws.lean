import Book.Sec4_3.Many
import Book.Sec4_3.Reader

/-!
The monad contract for `Many` and `Reader`, which the book checks by hand (4.3.3.2,
4.3.3.3). Slide-only: not in the book. The statements use the book's own names
(`Many.one`/`Many.bind`, `Reader.pure`/`Reader.bind`).
-/

namespace Slides

theorem Many.union_none (xs : Many α) : xs.union Many.none = xs := by
  induction xs with
  | none => rfl
  | more x xs ih => simp only [_root_.Many.union, ih]

theorem Many.union_assoc (xs ys zs : Many α) :
    (xs.union ys).union zs = xs.union (ys.union zs) := by
  induction xs with
  | none => rfl
  | more x xs ih => simp only [_root_.Many.union, ih]

theorem Many.bind_union (xs ys : Many α) (f : α → Many β) :
    (xs.union ys).bind f = (xs.bind f).union (ys.bind f) := by
  induction xs with
  | none => rfl
  | more x xs ih => simp only [_root_.Many.union, _root_.Many.bind, ih, union_assoc]

-- region: many-laws @1
-- intent: 本が手で確かめた `Many` のモナド則を、Lean で証明しておく。和 `union` の結合律などの補題を使った帰納法。
-- caption: 本は多重集合 $\{v_1, \dots, v_n\}$ として論じる。ここでは `Many` の値そのものが等しいことを証明している（答えの順序も含めて）。
-- note: 補題: union の右単位元が none、union の結合律、bind が union に分配すること。いずれも帰納法と simp。
theorem Many.bind_one_left (v : α) (f : α → Many β) :
    Many.bind (Many.one v) f = f v := by
  -- elide-begin
  simp only [_root_.Many.one, _root_.Many.bind, union_none]
  -- elide-end

theorem Many.bind_one_right (v : Many α) :
    Many.bind v Many.one = v := by
  -- elide-begin
  induction v with
  | none => rfl
  | more x xs ih => simp only [_root_.Many.bind, _root_.Many.one, _root_.Many.union, ih]
  -- elide-end

theorem Many.bind_assoc (v : Many α) (f : α → Many β) (g : β → Many γ) :
    Many.bind (Many.bind v f) g = Many.bind v (fun x => Many.bind (f x) g) := by
  -- elide-begin
  induction v with
  | none => rfl
  | more x xs ih => simp only [_root_.Many.bind, bind_union, ih]
  -- elide-end
-- endregion

-- region: reader-laws @1
-- intent: `Reader` のモナド則。本は定義を一つずつ展開して確かめる。
-- caption: 三つとも `rfl`、つまり定義を展開するだけで両辺が一致する。本の手計算と同じことを Lean が確かめている。
-- note: 本の計算: Reader.bind (Reader.pure v) f → fun env => f ((Reader.pure v) env) env → … → f v。
theorem Reader.bind_pure_left (v : α) (f : α → Reader ρ β) :
    Reader.bind (Reader.pure v) f = f v := rfl

theorem Reader.bind_pure_right (r : Reader ρ α) :
    Reader.bind r Reader.pure = r := rfl

theorem Reader.bind_assoc (r : Reader ρ α) (f : α → Reader ρ β) (g : β → Reader ρ γ) :
    Reader.bind (Reader.bind r f) g = Reader.bind r (fun x => Reader.bind (f x) g) := rfl
-- endregion

end Slides
