import Slides

/-- Print every trace run as JSON on stdout; `scripts/import-lean.ts` saves it
to `slides/generated/trace.json`. -/
def main : IO Unit :=
  IO.println Slides.allRuns.pretty
