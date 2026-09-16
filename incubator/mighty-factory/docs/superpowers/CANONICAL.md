# Mighty Factory canonical documents

As of 2026-09-16, implementation must use **all four** documents below:

- Design: `specs/2026-09-16-herdr-software-factory-design-v12.md`
- Normative contract amendment: `specs/2026-09-16-herdr-software-factory-contract-amendment-v12-1.md`
- Implementation plan: `plans/2026-09-16-herdr-software-factory-implementation-v12.md`
- Normative plan amendment: `plans/2026-09-16-herdr-software-factory-plan-amendment-v12-1.md`

All Review-11 and earlier Mighty Factory design/implementation-plan files are historical drafts and are superseded. Do not implement from them.

The Review-12 canonical set is the implementation-ready contract. Review-12 restores exact task/classification/run/state/specialist schemas and a self-contained TDD handoff. Amendment 12.1 makes worker results status-dependent so a pre-implementation blocker can have `commit:null`, tightens reviewer PASS/FAIL consistency and confidence bounds, and fixes bounded arbiter/repair schemas plus their required regression tests.
