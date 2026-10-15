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

---

## 1. Research: what people do most with a PDF tool

Clean-room, as `docs/priorities.md` sets it: public sources only, no PDF app
opened, run or decompiled. Unlike the other apps' categories, this one has
public per-task numbers: search volumes per task, per-tool use counters on
web tool sites, Q&A view counts, one web vendor's published usage split,
and the issue trackers of sixteen open-source PDF projects. The raw notes,
every number with its URL, are in `docs/blueprints/pdf/research.md`
(sections A to E). Search volume measures demand for a tool *outside* the
viewer people already have, so it under-counts what every viewer already
does (read, highlight, find, print); those rows lean on the Q&A numbers.

### 1.1 Ranked tasks

Rank is by the strongest signal in the row, then by agreement between
signals. "Q&A" is one network of public question sites (general computing,
Linux, Mac, Unix): the 2,281 top-voted PDF questions, 58.8M views in all.
"Site A" and "site B" are web PDF tool sites that show a use counter on each
tool page. "The vendor" is a web PDF service that published its own usage
split (May 2025). Search numbers are US monthly volumes.

| # | Task | Usage signal | Source |
|---|---|---|---|
| 1 | Read: open, scroll, zoom, page layout | largest Q&A group, 11.8% of 58.8M views; "pdf reader" 33,100/mo | https://www.seodata.dev/keyword/pdf-reader ; https://api.stackexchange.com/2.3/questions?site=superuser&tagged=pdf&sort=votes |
| 2 | Convert to a word-processing, spreadsheet or slide format | 246,000/mo for the word-processing variant; site A's #1 tool, 1,613,986 uses; 16% of the vendor's activity | https://www.seodata.dev/keyword/pdf-to-word ; https://pdfcandy.com/pdf-to-word.html ; https://smallpdf.com/pdf-statistics |
| 3 | Merge several PDFs into one | "pdf merger" 201,000, "merge pdf" 135,000, "combine pdf" 135,000; site A 704,085; one Q&A question 785K views | https://www.seodata.dev/keyword/merge-pdf ; https://pdfcandy.com/merge-pdf.html ; https://askubuntu.com/questions/2799 |
| 4 | Make a PDF from images or scans | "jpg to pdf" 201,000; site A 450,724; the Mac Q&A site's most-viewed PDF question, 1,502,667 views | https://www.seodata.dev/keyword/jpg-to-pdf ; https://apple.stackexchange.com/questions/11163 |
| 5 | Reduce file size | the vendor's top tool, 34% of activity; "compress pdf" 110,000; one Q&A question 1,049,735 views | https://smallpdf.com/pdf-statistics ; https://www.seodata.dev/keyword/compress-pdf ; https://askubuntu.com/questions/113544 |
| 6 | Mark up: highlight, notes, comments, drawing | second-largest Q&A group, 8.9% of views (246 questions); one question 307K views | https://askubuntu.com/questions/1529 |
| 7 | Sign with a drawn, typed or picture signature | the vendor's #2, 19% of activity; 64% of surveyed finance professionals sign about 15 times a month; "sign pdf" 22,200; one Q&A question 231K | https://smallpdf.com/pdf-statistics ; https://www.seodata.dev/keyword/sign-pdf ; https://unix.stackexchange.com/questions/85873 |
| 8 | Fill in forms | "fill pdf" 74,000, "pdf filler" 74,000; one Q&A question 248K; 57 👍 in a web toolbox's tracker | https://www.seodata.dev/keyword/fill-pdf ; https://askubuntu.com/questions/29230 ; https://github.com/Stirling-Tools/Stirling-PDF/issues/320 |
| 9 | Split or extract a page range | "split pdf" 40,500; site A 226,452; one Q&A question 793K | https://www.seodata.dev/keyword/split-pdf ; https://askubuntu.com/questions/221962 |
| 10 | Rotate pages and keep the rotation | the general-computing Q&A site's most-viewed PDF question, 705K; 66 👍 in a notes app's tracker | https://superuser.com/questions/145696 ; https://github.com/xournalpp/xournalpp/issues/1883 |
| 11 | Delete, reorder, insert pages | "delete pages from pdf" 33,100; site A rearrange 64,169, delete 49,407 | https://www.seodata.dev/keyword/delete-pages-from-pdf ; https://pdfcandy.com/rearrange-pdf.html |
| 12 | Add text, fill blanks ("edit a PDF" in general) | "pdf editor" 246,000, "edit pdf" 90,500; site A 278,175 for its general editor against 464 for its in-place text editor | https://www.seodata.dev/keyword/edit-pdf ; https://pdfcandy.com/edit-pdf.html ; https://pdfcandy.com/edit-pdf-text.html |
| 13 | Copy or extract text | Q&A questions on copying text: 462K and 399K views; "pdf to text" 12,100 | https://superuser.com/questions/47462 ; https://superuser.com/questions/198392 |
| 14 | Export pages as images | "pdf to jpg" 165,000; site A 156,024; one Q&A question 466K | https://www.seodata.dev/keyword/pdf-to-jpg ; https://askubuntu.com/questions/50170 |
| 15 | Find text in a document | 1.3% of Q&A views; "highlight every match" 34 CC on a desktop viewer's tracker | https://bugs.kde.org/show_bug.cgi?id=377487 |
| 16 | Remove or add a password | one Q&A question on removing protection 582K; "unlock pdf" 14,800, "password protect pdf" 8,100 | https://superuser.com/questions/179064 ; https://www.seodata.dev/keyword/unlock-pdf |
| 17 | Print (scaling, booklet, pages per sheet) | 4.6% of Q&A views; booklet 96K, four-up 63K on the Mac Q&A site | https://superuser.com/questions/205943 ; https://apple.stackexchange.com/questions/3832 |
| 18 | Make a PDF from office files or print to PDF | 110,000/mo; site A 288,131 | https://www.seodata.dev/keyword/word-to-pdf |
| 19 | Crop or change page size | "crop pdf" 9,900; site A 50,461 | https://www.seodata.dev/keyword/crop-pdf |
| 20 | Make scans searchable (OCR) | about 12,200/mo across variants; site A 38,447; 1.1% of Q&A views; hidden inside "can't copy text" (462K) | https://www.seodata.dev/keyword/ocr-pdf ; https://pdfcandy.com/pdf-ocr.html |
| 21 | Certificate (digital) signatures, and checking them | 142 👍 and 26 👍 in a browser viewer's tracker; 22 upvotes in a desktop viewer's | https://github.com/mozilla/pdf.js/issues/1076 ; https://github.com/mozilla/pdf.js/issues/13351 |
| 22 | Redact | "redact pdf" 5,400; the Mac Q&A site's #2 most-viewed PDF question, 490,831 views; a forum thread on bad redactions, 709 points | https://www.seodata.dev/keyword/redact-pdf ; https://apple.stackexchange.com/questions/22683 ; https://news.ycombinator.com/item?id=46369923 |
| 23 | Edit existing text in place | "edit pdf text" 8,100; 46 👍 in a web toolbox's tracker; the first complaint in two forum threads | https://github.com/Stirling-Tools/Stirling-PDF/issues/1141 ; https://news.ycombinator.com/item?id=43880962 |
| 24 | Flatten | "flatten pdf" 6,600 | https://www.seodata.dev/keyword/flatten-pdf |
| 25 | Compare two versions | "pdf compare" 5,400; one Q&A question 485,773; 4 👍 in a web toolbox's tracker | https://superuser.com/questions/46123 ; https://github.com/Stirling-Tools/Stirling-PDF/issues/1290 |
| 26 | Translate, summarize, ask questions | "translate pdf" 14,800, "summarize pdf" 2,400 | https://www.seodata.dev/keyword/translate-pdf |
| 27 | Read aloud | "read pdf aloud" 4,400 | https://www.seodata.dev/keyword/read-pdf-aloud |
| 28 | Stamps: page numbers, Bates numbers, watermark | 2,900, 2,900, 1,600; 0.7% of Q&A views | https://www.seodata.dev/keyword/add-page-numbers-to-pdf |
| 29 | Change the document's title and author | 151K views on the Mac Q&A site | research.md A (long tail) |
| 30 | Outline (bookmarks): read, then edit | "add bookmarks to pdf" 720; 9 👍 for outline editing in a CLI's tracker | https://github.com/qpdf/qpdf/issues/343 |
| 31 | Dark or inverted reading | 480/mo; 133K and 394K views; 37 👍 in a browser viewer's tracker | https://github.com/mozilla/pdf.js/issues/2071 |
| 32 | Tabs and split view | 41 CC and 29 CC on a desktop viewer's wishlist (its top items) | https://bugs.kde.org/show_bug.cgi?id=169847 |
| 33 | Author fillable form fields | 28 👍 | https://github.com/Stirling-Tools/Stirling-PDF/issues/2157 |

### 1.2 What open-source users say is missing

From the trackers of sixteen open-source PDF projects and two large
threads on a tech news forum (research.md B and C):

1. **Editing means adding, not changing.** The top complaint in both
   threads about a free PDF editor is that it "doesn't edit PDF text, just
   adds more"; text boxes that can't be re-edited or resized, one forced
   font, undo that fails, links lost on save.
2. **Redaction that only draws a box.** Black rectangles that leave the
   text underneath are called out in 2025 and 2026, and a 2026 bug in a
   popular toolbox let redacted text be copied.
3. **Signatures.** A drawn or picture signature is a top ask in the desktop
   viewers (23 upvotes, 15 CC); certificate signing and checking is the
   second most-reacted request across all projects (142 👍).
4. **Privacy and no upsell.** People value files never leaving the machine
   and distrust free web tools with export limits; a self-hosted toolbox's
   own users asked to turn off its upgrade prompt (32 👍).
5. **Scans.** Split two-page scans, deskew, black and white, OCR and
   compress in one place; OCR exists mostly as a command-line tool (35k
   stars) that people praise but that a viewer doesn't offer.
6. **Reading comfort.** Tabs, split view, remembering the last position,
   two-up, dark colours, a default zoom.
7. **A native Mac app.** Roundups name one basic open-source Mac reader
   with no OCR; the best page arranger and a popular keyboard reader have
   no proper Mac build.

### 1.3 What the built-in macOS viewer leaves to others

From public Q&A and the platform's own help pages (research.md A.1):
combining images into one PDF (1.5M views), redaction that is really
removal (491K), editing existing text (Apple's guide says it can't), OCR of
scanned PDFs, a better Reduce File Size (114K), dark reading (133K),
annotations that survive a save and other tools (support threads), carrying
a signature to another Mac (185K), setting the title (151K).

### 1.4 OCR, redaction, compare and full text reflow: in v1 or later?

| Capability | Evidence | Platform cost | Call |
|---|---|---|---|
| OCR | Moderate direct demand (12,200/mo, site A 38,447), large hidden demand (copying text from scans, converting scans), a named Mac gap, a 35k-star CLI people praise | Low: Vision recognizes text on device and PDFKit has a save option for an OCR text layer (Apple docs: RecognizeTextRequest; PDFDocumentWriteOption.saveTextFromOCROption) | **v1, tier 2** (wave 2) |
| Redaction | Low search (5,400) but the Mac Q&A site's #2 PDF question (491K) and loud forum demand; the harm of a fake redaction is high | High: PDFKit has a redact markup style but nothing that removes content (Apple docs: PDFMarkupType.redact) | **v1 only if creative-core CP-1 to CP-4 land** (wave 4, conditional); never a draw-a-box stand-in |
| Compare two versions | Low search (5,400), one 486K-view question, 4 👍; the neighbour (split view) is wanted | Medium: a text diff over page text (pure Swift) plus a two-pane view | **Later (tier 3)** |
| Full text reflow | Not asked: no request found for paragraph reflow; people ask for in-place edits that keep the font, and the 464-vote in-place editor next to a 278K-vote general editor says most "edit" means add text, fill, sign, rearrange | Very high: fixed glyph positions and subset fonts | **Not planned.** In-place editing of one line is **v1 only if CP-1 to CP-3 and CP-5 land** (wave 4, conditional) |

### 1.5 What the platform gives and what must be built

PDFKit and Vision cover the tier-1 loop (research.md E): display, page
pictures, page text with character boxes, the standard annotation kinds,
form widgets, page insert, remove and exchange, rotation, outline, find,
unlocking and saving with passwords and permissions, flatten
(`burnInAnnotationsOption`), image down-sampling options, printing, and OCR.
Gaps Folio builds itself: undo for every page and markup edit (PDFKit's
thumbnail reordering has no documented undo), its own find bar (the system
find interaction isn't on macOS), its own ink canvas (the system drawing
canvas isn't on native macOS), Tab order and required-field checks, and
measured tests of what each save option really does (every option page is
"docs silent"). Gaps creative-core must build (section 4.4): editing
content streams, true redaction, certificate signatures and incremental
save. Unsupported in every plan: form scripts and XFA (absent from PDFKit's
symbol index), which Folio detects and says so.

Checklist:

- [x] Every row has a number and a URL (or a pointer into research.md).
- [x] No product is named in the table text; URLs may carry names.
- [x] OCR, redaction, compare and reflow each get a call with evidence.
- [x] Open-source "missing" themes recorded (1.2).

---

## 2. Brief

### 2.1 The problem

PDF is how forms, contracts, statements, papers, manuals and scans travel.
People mostly read them, but the moment they must *do* something (sign a
lease, fill a form, combine scans into one file, send something under an
email size limit, pull three pages out of a report) the built-in viewer
either hides the way (1.5M views on how to combine images), does it badly
(Reduce File Size, redaction), or can't (OCR, editing). The usual answer is
a web tool that uploads private documents, counts free uses and upsells,
or a large paid desktop suite. Folio is a free, open, native Mac app that
does the everyday PDF jobs on the machine, fast, with undo for everything,
and saves files every other reader opens.

### 2.2 Who uses it

| Person | What they do | What they need most | Evidence |
|---|---|---|---|
| **The form filler and signer** (most people, a few times a month: leases, applications, tax forms, school forms) | open, fill, sign, save, send under a size limit | fields that just work with Tab, a signature they draw once, Reduce File Size | 1.1 rows 5, 7, 8; the survey's 15 signatures a month |
| **The reader and reviewer** (students, researchers, lawyers, editors, weekly to daily) | read long documents, find, highlight, comment, copy text | fast scrolling on 500 pages, find that highlights every match, marks that survive a save | rows 1, 6, 13, 15; 1.2 items 6 and 1 |
| **The organizer** (office work, admin, anyone with scans) | merge, split, reorder, rotate, delete pages; make a PDF from photos of paper; OCR | a page grid with drag and undo, images to PDF in one step, searchable scans | rows 3, 4, 9, 10, 11, 20 |
| **The suite user** | sends a Library photo set or a Photo export to Folio as a PDF, a Folio page to Photo as an image, a Design export to Folio for review | hand-offs that keep the file's name and land in the right app | suite.md section 1.2 and 1.4 |

### 2.3 Non-goals

- Authoring documents: page layout, flowing text, styles. That is a
  word-processing or layout tool; Design covers vector page design.
- Re-flowing paragraphs of existing text (1.4: not asked, very costly).
- Form scripts and XFA forms: detected, and the person told; never run.
- Converting from office formats or web pages into PDF: the system's
  Print > Save as PDF does it, and Folio opens the result.
- Cloud storage, accounts, sharing links, collaboration, review workflows
  with other people's servers.
- Generative AI features in v1 (summarize, ask questions, translate): Later
  (1.1 rows 26), on device only when they come.
- Opening or writing other vendors' closed formats; reverse engineering
  anything.
- An iPad or iPhone build.

### 2.4 The v1 line

| Area | In v1 | Out of v1 (later, in order) |
|---|---|---|
| Open and read | Open from Finder, File > Open, drop, Open Recent; locked files ask for the password; damaged and non-PDF files refused with a sentence; continuous, single page, two pages; zoom in, out, actual size, fit width, fit page; thumbnails, go to page, back and forward; read-only outline navigation; document info | Tabs; split view; remembering the last position per file; dark or inverted reading; read aloud |
| Make | New from Images (and scans from an iPhone through Continuity Camera) | New blank document with templates |
| Find and copy | Find with every match highlighted, a results list, Match Case, Whole Words; select text by drag, double-click a word, copy | Find and replace (needs text editing) |
| Mark up | Highlight, underline, strike out, notes, comments on any mark, text boxes, pen, rectangle, ellipse, line, arrow; colour, line width, opacity; move, resize, delete; a marks list | Stamps, measurements, comment replies and authors, import and export of comments |
| Forms | Fill text, checkbox, radio, choice fields; Tab order; required-field check; Clear Form; scripts detected and named | Authoring form fields; calculated fields |
| Sign | Draw, type or pick a picture; initials; a library kept between launches; place anywhere or fit into a signature field | Certificate signatures and checking them (CP-6) |
| Pages | Page grid; reorder by drag; rotate; delete; insert blank; insert from file (combine); combine several files at once; extract a range; split; crop | Page labels; pages per sheet; replace page |
| Edit | Add text boxes and images; **conditional:** edit one line of existing text in place and true redaction, in v1 only if creative-core CP-1 to CP-5 land in time (W4), otherwise v1.1 | Paragraph reflow (not planned); find-and-redact patterns |
| Undo | every edit one named step, 100 steps; typing in a field and a drag each coalesce into one | History panel |
| Save | Save, Save As; flatten; add or remove an open password and owner restrictions; atomic writes; the original is never changed until Save | Version browser; autosave and recovery (the suite's policy, adopted on Folio's line when the suite schedules it) |
| Export | Pages as PNG or JPEG at 72, 150, 300 ppi; text as plain text, rich text or a word-processing document (text and paragraphs, not layout); Reduce File Size with three levels and the measured result; Print | Spreadsheet and slide formats; PDF/A; tagged PDF |
| OCR | Recognize text on scanned pages (languages from the system), kept as an invisible text layer on Save | Deskew and clean-up of scans; document structure export |
| Suite | One of the apps in AfterGlow: switcher item, Switch To, recents, Open In; hand-offs from Library and Photo (images to a PDF), to Photo (a page as an image) | Linked placement of PDF pages in Design |

**The line in one sentence:** a person opens or makes a PDF, reads and
finds in it, marks it up, fills and signs it, rearranges its pages, undoes
any step, and saves or shrinks or exports it, all on their Mac, in a file
every other reader opens.

**Why this line** (from section 1): rows 1 to 17 of 1.1 are in v1 except
the office-format import of row 18 (a non-goal because the system already
prints to PDF) and certificate signatures (row 21, engine work); OCR is in
because the platform makes it cheap and it is a named Mac gap; redaction
and in-place text editing are the two highest-value engine features, so
they are planned, conditional, and never faked; compare, translate,
summarize, read aloud, stamps, outline editing, dark reading, tabs and form
authoring are tier 3 and Later.

Checklist:

- [x] Every "In v1" row traces to a row of 1.1 or a platform fact in 1.5.
- [x] Every non-goal names a behaviour, not another company's product.
- [x] Every "out" item says where it goes.
