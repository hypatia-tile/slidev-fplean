import Slides.Sec4_3.Trace

/-- Print every trace run as JSON on stdout; `scripts/import-lean.ts` saves it
to `slides/generated/4-3/trace.json`. -/
def main : IO Unit :=
  IO.println Slides.allRuns.pretty
