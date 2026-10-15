# Folio blueprint (the AfterGlow PDF app)

Folio is the suite's sixth app: read, mark up, fill, sign, organize, lightly
edit and export PDF documents. Nothing exists for it yet: no target, no
issue, no line. This blueprint is the gate before any code. It fixes the
name candidates, the research the scope rests on, the v1 line, every
feature with its tier, the components and the engine work, every tier-1
journey, the use-case contracts, the look, the quality bar and the build
order. Feature packets (`docs/blueprints/pdf/features/`) come after the
captain approves it.

Sources read on 2026-10-15: creative-apps `origin/dev` f7d30fd (CLAUDE.md,
`docs/design.md`, `docs/priorities.md`, `docs/engineering.md`,
`docs/review-rubric.md`, `docs/factory/lead.md`, `docs/c4/model.json`,
`docs/blueprints/app-audit.md`, `docs/blueprints/suite.md`,
`docs/blueprints/flare.md`, `docs/blueprints/halo.md`), and the open PR
#973 (`docs/shell-parity` at baf95c9), which records the captain's three
look decisions of 2026-10-15: every app on `SuiteWindow`, Flare's floating
glass tool palette for every app with tools, and the app switcher row
centered at the top of every window. Platform facts were checked in Apple's
developer documentation and are cited inline as "Apple docs: <page>"
(section 4.5 lists the URLs). Usage research is in section 1 and its raw
notes in `docs/blueprints/pdf/research.md`.

Contents: 0 Working name · 1 Research · 2 Brief · 3 Feature catalog ·
4 Pseudo-C4 · 5 Journeys · 6 Contracts · 7 Look · 8 Quality bar · 9 Waves ·
10 Decisions and questions for the captain · 11 Critic rounds

Files: this document; `docs/blueprints/pdf/research.md` (raw research
notes); `docs/blueprints/pdf/c4-planned.json` (section 4 as data);
`docs/blueprints/pdf/contracts/` (section 6 as Swift that compiles on Linux,
with `check.sh`); `docs/blueprints/pdf/waves.py` (the owned-file overlap
check of section 9).

Ids used below: **P-T<n>** a feature (section 3), **P-J<n>** a journey
(section 5), **PB-<n>** a speed budget, **PF-<n>** a fidelity test, **PL<n>**
a layout rule (section 8), **W<n>** a wave (section 9).

---

## 0. Working name

The suite's names are one short English word each, a plain noun or an image
of light: Flare, Design, Photo, Library, Halo. The PDF app's name should be
one word, say "pages and paper" without naming a file format, and read well
in the switcher's tooltip ("Folio (⌃⌘6)").

| # | Name | Why it fits |
|---|---|---|
| 1 | **Folio** | A folio is a sheet of paper and a page number: the app is about pages, and the word is as plain as Library and Photo. |
| 2 | **Page** | The plainest noun for what the app shows and organizes, in the same register as Photo and Design. |
| 3 | **Quill** | The pen that marks up and signs: the two things people do most after reading, and an image as short as Flare and Halo. |

This document uses **Folio** throughout: `FolioModel`, `FolioApp`,
`line:folio`, the `folio.` identifier prefix and `-Folio*` launch arguments.
If the captain picks another name, one rename pass changes those strings;
nothing else depends on it. Before shipping, the chosen word needs a
trademark check (Q1, section 10).

Checklist:

- [x] Three names, one line of reason each.
- [x] The first is used everywhere in this document.
- [x] No other company's product is named.
