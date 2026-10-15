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

---

## 3. Feature catalog

Tiers follow `docs/priorities.md`: **tier 1** (`p1`) is used in nearly
every session or is one of the top usage rows of 1.1, or something a tier-1
feature needs; **tier 2** (`p2`) is weekly or once per deliverable;
**tier 3** (`p3`) is specialist or occasional. "Row n" cites section 1.1.
*Inferred* marks a tier with no direct number, first to move if data turns
up. Each feature names its wave feature (section 9) and its journey
(section 5).

Shortcuts are the menu's (section 7.6); tool keys work while the page view
has focus. "Hand-offs" are the suite connections of `docs/blueprints/suite.md`
(Open In, typed pasteboard, hand-off files); each needs the suite's
`SuiteApp.folio` (section 9.5).

### 3.1 Tier 1

**P-T1 Open a PDF** (tier 1, row 1; `reader`, P-J1, P-J11). The person
double-clicks a PDF in Finder, chooses File > Open… (⌘O), drops a file on
the window or the Dock icon, or picks one from File > Open Recent. Folio
opens one window per document, titled with the file's name, and shows page
1 fitted to the width. *Empty:* with no document the window shows "No PDF
Open · Open a PDF or drop one here." with Open… (prominent) and Create from
Images…. *Loading:* a progress row appears in the page view at once and
thumbnails fill in as pages draw; a page not drawn yet is a blank sheet of
its size, never a gap. *Errors:* not a PDF, damaged (with the reason), too
large, and locked: a locked file opens a password sheet ("This PDF is
locked. Enter its password to open it."), a wrong password shakes the
field and says "That password didn't unlock this PDF. Try again.", Cancel
leaves the window empty. A file with form scripts or XFA opens with a
banner naming what Folio won't run. *Hand-offs in:* Finder (Folio declares
PDF as Editor, rank Alternate, so it never steals the system default
without the person choosing it); Open In ▸ Folio from any suite app that
writes PDF (Design's PDF export, #418); a PDF dropped on the AfterGlow home.
*Out:* recents in the suite's one list.

**P-T2 Read, zoom and page layout** (tier 1, row 1; `reader`, P-J1).
Continuous scroll (⌘2) by default, Single Page (⌘1), Two Pages (⌘3);
Actual Size (⌘0), Zoom In and Out (⌘+, ⌘−, pinch), Fit Width (⌘9), Fit
Page. The zoom pill under the page shows the percent or "Fit Width"; the
page pill shows "Page n of m" for the page nearest the top. *Empty:* none
(a document has at least one page). *Loading:* as P-T1 for pages scrolled
into view. *Errors:* a page that fails to draw shows "This page couldn't be
drawn." in its sheet; the rest of the document reads normally.

**P-T3 Navigate: thumbnails, go to page, outline** (tier 1, row 1;
`reader` for go to page and outline, `pages` for the thumbnails, P-J1). The
sidebar's PAGES section shows a thumbnail per page with its number (or
printed label); clicking one scrolls to it. View > Go to Page… (⌥⌘G) takes
a number or a label; back and forward (⌘[ and ⌘]) step through jumps. The
OUTLINE section shows the file's bookmarks as a tree; clicking one jumps.
*Empty:* "No outline in this PDF." *Errors:* "This document has pages 1 to
n." under the Go to Page field for a number out of range.

**P-T5 Select and copy text** (tier 1, row 13; `markup`, P-J3). Text
Select (T) or the default Select tool over text: drag to select, double-click
a word, triple-click a line, ⌘A selects all text on the page, ⌘C copies it
as plain text with line breaks joined inside paragraphs. *Empty:* on a page
with no text layer, the tool's help reads "This page has no text to select.
Recognize text first." with Recognize… (P-T27). *Hand-offs out:* plain text
on the general pasteboard for any app.

**P-T6 Find** (tier 1, row 15, *inferred* from the reading staples and the
tracker asks; `find`, P-J2). ⌘F opens the find bar over the top of the page
view; typing finds as you type (after 2 characters); every match is tinted
and the current one outlined; Return and ⌘G go to the next, ⇧Return and
⇧⌘G to the previous; the sidebar shows RESULTS with each hit's page and
context. Match Case and Whole Words toggles. *Empty:* "No results" and the
field's help "No matches for <text>." *Loading:* "Searching… page n of m"
while results stream in page order. *Errors:* pages with no text layer are
counted: "2 pages have no text. Recognize text to search them." with
Recognize….

**P-T7 Highlight, underline, strike out** (tier 1, row 6; `markup`, P-J3).
With text selected, Markup > Highlight (⌃⌘H), Underline (⌃⌘U) or Strike Out
(⌃⌘K); or pick the tool (H, U, K) and drag across text, which marks as you
release. The inspector shows the mark: colour (the five markup colours plus
the system colour panel), opacity, the comment field. A mark sits on its
text; it can be recoloured, commented or deleted, not moved. *Errors:* a
file whose owner forbids markup disables every markup tool with "The owner
of this PDF doesn't allow adding or changing markup."; marking with no
selection says "Select some text first."

**P-T8 Notes and comments** (tier 1, row 6; `markup`, P-J4). Note (N):
click to place a note icon, type in its popover, Escape closes it. Any mark
takes a comment in the inspector. The sidebar's MARKS section lists every
mark by page with its text or comment; clicking one selects it and scrolls
to it. *Empty:* "No markup yet. Pick a tool and drag over text." *Hand-offs:*
none in v1.

**P-T9 Add text (text box)** (tier 1, row 12: most "edit a PDF" means adding
text and filling blanks; `markup`, P-J4). Text Box (X): click to place, type,
Escape or click away to finish; double-click to edit again; drag to move,
handles to resize; the inspector sets font size, colour and alignment (the
system font, so it reads as typed). For flat forms that have no fields,
this is how people fill them. *Errors:* an empty text box is not created
("Type some text for the text box.").

**P-T11 Fill forms** (tier 1, row 8; `forms`, P-J5). Fields are drawn as
real controls over the page: text fields, checkboxes, radio buttons, pop-up
choices. Click or Tab into a field; ⇥ and ⇧⇥ move in reading order (page,
then top to bottom, then left to right), skipping read-only fields; Space
toggles a checkbox or picks a radio. The field's tooltip from the form
author is its help. *Errors:* a read-only field says "<name> is read-only
in this form."; a too-long value or a line break in a one-line field shows
its sentence under the field and keeps the old value. *Empty:* a PDF with no
fields: the Form menu is disabled with "This PDF has no form fields. Use
Text Box to type on it."

**P-T13 Rotate, delete, reorder, insert pages** (tier 1, rows 10 and 11;
`pages`, P-J7). In the sidebar thumbnails or the Page Grid (⌘4): select
pages (click, Shift-click, ⌘-click), Rotate Right (⌘R) and Left (⌘L),
Delete Page (⌘⌫), drag to reorder (a drop line shows where), ⌥⌘← and ⌥⌘→
move the selection by keyboard, Insert Blank Page (⇧⌘B, the size of the
selected page). Rotation is saved as the page's rotation, so every reader
shows it. *Errors:* deleting every page: "A PDF needs at least one page.
Add a page before deleting this one."; a file locked against changes:
page commands disabled with "The owner of this PDF doesn't allow changing
its pages."

**P-T14 Combine files** (tier 1, row 3; `pages`, P-J8). Page > Insert from
File… (⇧⌘I) inserts every page of another PDF after the selected page (or
at the start or end); dropping PDFs onto the thumbnails inserts them where
dropped; File > Combine Files… picks several files in one panel and makes
one new document in the order shown, which the sheet lets the person
reorder before Combine. Inserted forms keep their fields; a field name
already taken gets " 2". *Loading:* the open progress row. *Errors:* a
locked file in the set asks for its password in turn; a damaged one is
named and skipped with "Skipped Notes.pdf: this PDF is damaged…".
*Hand-offs in:* Library's "Make PDF from Selection" and Photo's export land
here as a new document (P-T4).

**P-T15 Extract and split** (tier 1, row 9; `pages`, P-J8). Page > Extract
Pages… takes a range ("1-3, 5, 8-") and opens a new window with those pages
(title "<name> (pages 1–3)"), leaving the original alone. Page > Split…
splits after every n pages or at typed page numbers and writes each part
next to the original with " (part k)". *Errors:* a range outside the
document: "This document has pages 1 to n."; text that isn't a range:
"\"x\" isn't a page or a range. Type pages like 1-3, 5."

**P-T17 Undo and redo** (tier 1, *inferred* as for every suite app; `history-files`,
P-J9). Every edit is one named step (Undo Highlight, Undo Move Page, Undo
Typing); typing in one field or one text box and one drag each coalesce;
scroll, zoom, find and selection are never steps; 100 steps. *Empty:* Undo
and Redo disabled with "Nothing to undo." / "Nothing to redo."

**P-T18 Save and Save As** (tier 1, row 10's "save the rotated file" is the
general-computing Q&A site's most-viewed PDF question; `history-files`,
P-J10). ⌘S writes the document through a temporary file and replaces the
original only when the write succeeded; ⇧⌘S saves a copy elsewhere. The
window's subtitle reads "Edited" with unsaved changes, "Saved" after, "Not
saved ⚠" after a failure. Closing with changes asks Save, Don't Save,
Cancel. *Errors:* a read-only folder or full disk: the sentence near the
title and in an alert; the file the pages came from moved away
(`sourceMissing`). *Loading:* progress after 100 ms; the window stays usable.

**P-T21 Sign** (tier 1, row 7; `sign`, P-J6). Sign (S) opens the signature
popover: the saved signatures and initials, and New Signature…. The sheet
has three ways: Draw (a pad: drag with the trackpad or mouse, Clear),
Type (the name in a script face) and Image (pick a picture of a signature;
its light background is made transparent). "Save as initials" marks
initials. Clicking a page places the chosen signature there at a natural
size, or fitted inside an empty signature field. Placed signatures move and
resize like any mark, keeping their aspect. The library lives in Folio's
folder and survives relaunch. *Empty:* only New Signature…. *Errors:* Done
is disabled on an empty pad with "Draw your signature in the box first.";
an unwritable folder: "Signatures couldn't be saved…" and the signature
still places in this document. Certificate signatures are Later (P-T31).

**P-T4 New from Images** (tier 1, row 4; the Mac Q&A site's most-viewed PDF
question; `export-convert`, P-J22). File > New from Images… (⇧⌘N) picks
PNG, JPEG or HEIC files (or drop them on the empty window) and makes one
page per image in the order picked, each page the image's aspect, fitted
to Letter or A4 by the locale. File > Import from iPhone > Scan Documents
(Continuity Camera) adds scanned pages the same way (Apple docs: Supporting
Continuity Camera in your Mac app). The new document is "Untitled" until
saved, and its no-text banner offers Recognize Text (P-T27). *Errors:* a
file that isn't an image is named and skipped. *Hand-offs in:* Library's
selection and Photo's document arrive as images through the suite's
hand-off and open here.

**P-T22 Reduce File Size** (tier 1, row 5: the web vendor's most-used tool;
`export-convert`, P-J23). File > Reduce File Size… offers three levels
(Small: images at 96 ppi; Medium: 150 ppi; Large: 220 ppi; JPEG for photos)
and shows the result before writing: "From 8.4 MB to 2.9 MB". It writes
"<name> (reduced).pdf" next to the original and never overwrites it. Text
and vector content are untouched (PF-11). *Loading:* progress in the sheet
with Cancel. *Errors:* when the result isn't smaller: "This PDF is already
as small as Folio can make it." and nothing is written.

**P-T30 No dead controls** (tier 1 by dependency: CLAUDE.md, review rubric
QB-F1; `foundation`, P-J12). Every menu item, toolbar button and palette
tool acts or is disabled with the sentence saying why, from
`unavailableHelp(for:)` in the Model; each feature's controls read "Not built
yet." until its feature lands.

### 3.2 Tier 2 (all in v1 unless marked)

**P-T10 Pen and shapes** (tier 2, rows 6 and 30-34 of research.md B: shapes
18 👍 twice; `markup`, P-J4). Pen (P) draws freehand ink as the pointer
moves; Shape (R) draws a rectangle by default, with ellipse, line and arrow
in the tool's menu (Shift constrains). The inspector sets colour, line width
(0.5–12 pt, a bar slider) and opacity. Marks move with arrows (1 pt, Shift
10 pt). *Errors:* as P-T7 for locked files.

**P-T12 Check and clear a form** (tier 2, *inferred* from the form filler's
need to send a complete form; `forms`, P-J5). Form > Check Form lists empty
required fields ("1 required field is empty: Agree to terms") and outlines
each in the warning colour with its triangle; Form > Clear Form empties
every field in one undoable step.

**P-T16 Crop pages** (tier 2, row 19; `pages`). Page > Crop Pages… sets
margins (or drag a crop box on the page in the sheet's preview) for the
selected pages or a range; the crop is saved as the page's crop box, so
nothing is lost and Crop can be removed. *Errors:* "Keep at least 1 inch of
the page on each side."

**P-T19 Open Recent** (tier 2, "reopen previous documents" 27 CC on a desktop viewer's wishlist;
*inferred*; `reader`). File > Open Recent lists 10 files; with the suite's
recents feature it reads the one AfterGlow list filtered to Folio. A missing
file is shown dimmed with "Moved or deleted." *Hand-offs:* the AfterGlow
home lists Folio documents with thumbnails.

**P-T20 Flatten and passwords** (tier 2, rows 16 and 24; `history-files`,
P-J10). Save As… and Export… offer Flatten (marks and field values drawn
into the pages, no longer editable), an open password, and owner
restrictions (printing, copying, changing). Removing a password: open the
file with it, then Save As without one. *Errors:* a non-ASCII owner
password is refused with "Use letters, numbers and symbols from a standard
keyboard." (the system's encryption takes ASCII only: Apple docs:
kCGPDFContextOwnerPassword).

**P-T23 Export text and a word-processing document** (tier 2 by frequency,
row 2 by demand; `export-convert`, P-J21). File > Export… > Text, Rich
Text or Word-Processing Document writes the text in reading order with
paragraphs, bold, italic and sizes where the text layer has them; never the
layout. A scanned page without text adds nothing and the sheet says how
many pages had no text. *Hand-offs out:* the file opens in the system's
default app for its type.

**P-T24 Export pages as images** (tier 2, row 14; `export-convert`,
P-J21). File > Export… > PNG or JPEG, 72, 150 or 300 ppi, JPEG quality,
pages All, Current or a range; one file per page, "<name>-<n>.png", with the
marks drawn. *Hand-offs out:* Open In ▸ Photo opens the current page as an
image in Photo (suite hand-off; the page is rendered at 300 ppi).

**P-T25 Print** (tier 2, row 17; `export-convert`, P-J24). ⌘P opens the
system print panel with Folio's page range, scaling (fit, actual size) and
auto-rotate (Apple docs: PDFDocument.printOperation). Booklets and pages
per sheet are Later.

**P-T27 Recognize text (OCR)** (tier 2, row 20 and 1.4; `ocr`, P-J20). On
opening a document whose pages have no text, a warning pill reads "No text:
Recognize…"; Tools > Recognize Text… picks languages (the system's list,
the person's preferred first) and pages, then recognizes page by page
with progress and Cancel. Recognized text is selectable, findable and
highlightable at once and is saved as an invisible text layer. *Errors:*
Cancel keeps pages already done; a page with no text found says so in the
summary.

**P-T28 Edit text in place** (tier 2, row 23; `content-edit`, conditional
W4). Edit Text (E): click a line of existing text to edit it in place;
Folio keeps the line's font, size and colour when every typed character
exists in the embedded font, and otherwise says which characters are
missing and offers the nearest system font. One line at a time, no reflow.
Needs CP-1, CP-2, CP-3, CP-5.

**P-T29 Redact** (tier 2, row 22; `content-edit`, conditional W4). Redact
(D): drag over text or an area to mark it (a hatched outline, not yet
applied); Tools > Apply Redactions… lists what will be removed and, on
confirm, removes the text, image pixels and vector paths under each mark,
drops marks and fields there, optionally strips metadata, and saves to a
new file; then reopens it and checks that no removed text can be found
(PF-13). Never a black box over live text. Needs CP-1 to CP-4.

### 3.3 Tier 3

**P-T26 Document properties** (tier 3, row 29; cheap, so in v1;
`history-files`). The inspector's DOCUMENT section shows title, author,
page count, page size, PDF version and permissions; title and author are
editable fields, each change one undo step, saved in the file's info.

Later, in the order they would come, each with its evidence:

| # | Feature | Tier | Evidence | Needs |
|---|---|---|---|---|
| P-T31 | Certificate signatures and checking them | 2 | row 21 (142 👍) | CP-2, CP-6, the macOS Security framework's CMS encoder and decoder |
| P-T32 | Dark and inverted reading; remember the last position; default zoom | 3 | rows 31; research.md B (15 👍, 34 CC) | – |
| P-T33 | Tabs and side-by-side documents | 3 | row 32 | SuiteUI |
| P-T34 | Compare two versions (text differences, side by side) | 3 | row 25 | a text diff in FolioModel |
| P-T35 | Stamps: page numbers, Bates numbers, watermark, header and footer | 3 | row 28 | – |
| P-T36 | Edit the outline | 3 | row 30 | – |
| P-T37 | Author form fields | 3 | row 33 | – |
| P-T38 | Read aloud with word highlighting | 3 | row 27 | AVSpeechSynthesizer (Apple docs) |
| P-T39 | Translate, summarize (on device) | 3 | row 26 | Translation, Foundation Models (Apple docs) |
| P-T40 | Booklet and pages-per-sheet printing | 3 | row 17 | – |
| P-T41 | PDF/A and tagged PDF output | 3 | research.md B (33 👍), long tail | CorePDF |
| P-T42 | Export to spreadsheet and slide formats | 3 | row 2 | Vision document structure (Apple docs: RecognizeDocumentsRequest) |

### 3.4 Coverage

| Feature (wave feature) | Tier | v1 | Journey |
|---|---|---|---|
| P-T1 Open (reader) | 1 | yes | P-J1, P-J11 |
| P-T2 Read and zoom (reader) | 1 | yes | P-J1 |
| P-T3 Navigate (reader, pages) | 1 | yes | P-J1 |
| P-T4 New from Images (export-convert) | 1 | yes | P-J22 |
| P-T5 Select and copy text (markup) | 1 | yes | P-J3 |
| P-T6 Find (find) | 1 | yes | P-J2 |
| P-T7 Highlight, underline, strike out (markup) | 1 | yes | P-J3 |
| P-T8 Notes and comments (markup) | 1 | yes | P-J4 |
| P-T9 Text box (markup) | 1 | yes | P-J4 |
| P-T10 Pen and shapes (markup) | 2 | yes | P-J4 |
| P-T11 Fill forms (forms) | 1 | yes | P-J5 |
| P-T12 Check and clear (forms) | 2 | yes | P-J5 |
| P-T13 Page operations (pages) | 1 | yes | P-J7 |
| P-T14 Combine (pages) | 1 | yes | P-J8 |
| P-T15 Extract and split (pages) | 1 | yes | P-J8 |
| P-T16 Crop (pages) | 2 | yes | P-J7 (extended by the crop task) |
| P-T17 Undo (history-files) | 1 | yes | P-J9 |
| P-T18 Save (history-files) | 1 | yes | P-J10 |
| P-T19 Open Recent (reader) | 2 | yes | P-J1 (last step) |
| P-T20 Flatten and passwords (history-files) | 2 | yes | P-J10 |
| P-T21 Sign (sign) | 1 | yes | P-J6 |
| P-T22 Reduce File Size (export-convert) | 1 | yes | P-J23 |
| P-T23 Export text (export-convert) | 2 | yes | P-J21 |
| P-T24 Export images (export-convert) | 2 | yes | P-J21 |
| P-T25 Print (export-convert) | 2 | yes | P-J24 |
| P-T26 Document properties (history-files) | 3 | yes | P-J10 (properties step) |
| P-T27 OCR (ocr) | 2 | yes | P-J20 |
| P-T28 Edit text in place (content-edit) | 2 | conditional | P-J25 |
| P-T29 Redact (content-edit) | 2 | conditional | P-J26 |
| P-T30 No dead controls (foundation) | 1 | yes | P-J12 |
| P-T31 to P-T42 | 2-3 | Later | – |

---

## 4. Pseudo-C4 (drawn before code)

Every element here is **planned**: nothing of Folio is on `origin/dev`.
Three layers as `docs/engineering.md` sets them: creative-core engines,
`FolioModel` (Linux-safe state and logic), `FolioApp` (SwiftUI, macOS).
SuiteUI sits beside the app and knows no Model. The same model as data is
`docs/blueprints/pdf/c4-planned.json` (the shape of `docs/c4/model.json`,
one level finer, every element `"status": "planned"` and `"authored":
true`). It is not read by `scripts/ci`; W0's last task adds the
`folio-model` and `folio-app` containers to `docs/c4/model.json` when the
targets exist.

**The one architectural call.** PDFKit is macOS only, so it can never be
the Model. Folio's Model holds the document as a value
(`FolioDocumentState`: pages in order with their origin and rotation,
annotations, form field values, outline, permissions) and treats the bytes
it opened as read-only **sources**. PDFKit does exactly four jobs, each
behind a contract with a fake: read a source into that value
(`DocumentOpening`), draw a source page's picture (`PageImaging`), give a
page's text with character boxes (`PageTextReading`), and write sources
plus the value into new bytes (`DocumentWriting`, `PageExporting`). Vision
does one (`TextRecognizing`). Everything a person does between open and
save (select, find, mark up, fill, sign, reorder, undo) is pure Swift over
the value, tested on Linux, and fast because it never round-trips through
PDFKit. The view shows the page picture from `PageImaging` with Folio's own
marks drawn over it from the Model, so an edit is on screen in the same
frame; PDFKit's own annotation drawing is used only at save and export.

Why not drive `PDFView` and its live annotation objects directly: undo,
tests and journeys would all have to go through AppKit objects that don't
exist on Linux, a page reorder in `PDFThumbnailView` has no undo (Apple
docs: PDFThumbnailView, docs silent on undo), and every tool would be a
view-layer feature the app-state rule forbids. What `PDFView` does well,
sharp vector drawing at any zoom, Folio keeps: the live `PageImaging`
draws a visible page with `PDFPage.draw(with:to:)` at the view's current
scale (Apple docs: PDFPage), and only pages in or near the visible rect are
drawn (`FolioLayout.visiblePages`, budget PB-3). Q4 in section 10 asks the
captain to confirm this split.

### 4.1 L1 and L2: containers

```
 Person with a PDF (reader, form filler, signer, organizer)
       │ opens, reads, marks up, fills, signs, reorders, saves, exports
       ▼
┌──────────────────────────── creative-apps ─────────────────────────────┐      ┌──── creative-core ─────┐
│                                                                        │      │                        │
│  FolioApp (macOS) ──reads, calls──▶ FolioModel (Linux + macOS) ────────┼────▶ │ CorePDF (planned):     │
│    │ scene, SuiteWindow, menus,        document value, workspace,      │      │  object reader,        │
│    │ page view, thumbnails, sheets,    tools, history, contracts,      │      │  incremental writer,   │
│    │ live PDFKit + Vision services     fakes, pure live services       │      │  content streams,      │
│    ├──builds from──▶ SuiteUI (macOS)                                   │      │  redaction, text edit, │
│    └──joins──▶ SuiteShell / SuiteModel (suite blueprint, planned)      │      │  signature byte ranges │
│                                                                        │      │ CoreRaster (existing): │
│  Folio tests: FolioModelTests (Linux), Folio snapshots and goldens,    │      │  pixels for redaction  │
│  Folio journeys (XCUITest), contracts/check.sh                         │      └────────────────────────┘
└────────────────────────────────────────────────────────────────────────┘
   Apple frameworks only in FolioApp: SwiftUI, PDFKit, Vision, CoreGraphics,
   ImageIO, UniformTypeIdentifiers, AppKit (print, Continuity Camera), Security (later: CMS)
```

| Container | Status | Responsibility | Owned paths | Line |
|---|---|---|---|---|
| `FolioModel` | planned | All state and logic: the document value, the workspace (selection, tool, zoom, find, history, file state), one contract per use case with its fake and its Linux live type; no Apple framework, no engine in v1 | `Sources/FolioModel/` | `line:folio` |
| `FolioApp` | planned | The SwiftUI app: `SuiteWindow` with thumbnails and outline in the sidebar, the page view as detail with the floating tool palette, the inspector, sheets, menus; the macOS live services (PDFKit, Vision, CoreGraphics) | `Sources/FolioApp/` | `line:folio` |
| Folio tests | planned | Model tests and budgets (Linux), snapshots and fidelity goldens (macOS), journeys (XCUITest) | `Tests/FolioModelTests/`, `Tests/AppSnapshotTests/Folio*`, `UITests/FolioJourneyTests*.swift` | `line:folio` |
| SuiteUI | existing (other line) | Window shell, palette, inspector rows, status pills, switcher; gaps go to `needs-ui` (section 7.3) | `Sources/SuiteUI/` | `line:suiteui` |
| SuiteModel, SuiteShell | planned by the suite blueprint (other line) | The app's identity in the suite, switching, recents, hand-offs, Open In | `Sources/SuiteModel/`, `Sources/SuiteShell/` | `line:suite` |
| creative-core `CorePDF` | planned (needs new core issues, 4.4) | Pure-Swift PDF object model for what PDFKit can't do: true redaction, editing existing text, certificate signature byte ranges, incremental save | qbtrix/creative-core | `needs-core` |
| creative-core `CoreRaster` | existing | Fills image regions for redaction (later); nothing in v1 | qbtrix/creative-core | – |

`Package.swift` gains `model("Folio", [])` and `"Folio"` in `apps` (W0,
protected path: supervisor merges, section 9). `FolioModel` depends on no
engine in v1; the `content-edit` feature adds `CorePDF` when its core
issues land.

### 4.2 L3: components

A file belongs to exactly one component (`waves.py` checks it against
`c4-planned.json`). Paths are relative to the container's folder.

#### FolioModel (planned)

| Component | Responsibility | Paths | Relationships |
|---|---|---|---|
| folio-values | The value types every contract speaks (section 6.1): geometry, pages, page text, selections, annotations, fields, signatures, outline, permissions, the document value, write and export options, typed errors with their sentences | `Contracts/FolioValues.swift` | used by every component |
| folio-contracts | One protocol per use case (section 6.2) and `FolioHistory` | `Contracts/FolioContracts.swift` | implemented by fakes, `Live/` and FolioApp's live types |
| folio-fakes | A fake per contract; the fake file format and layout | `Fakes/*.swift` (one file per contract, plus `FolioFakeFile.swift`) | snapshots, journeys on `-FolioFixture`, contract suites |
| folio-fixtures | Named fixtures (`letter`, `form`, `scan`, `locked`, `marked`, `long`, then each feature's own) | `Fixtures/*.swift` | fakes; FolioApp's `-FolioSample` writer |
| folio-services | `FolioServices` with `.fake`; the live slots are filled in FolioApp | `FolioServices.swift` | workspace |
| folio-workspace | `FolioWorkspace`: the window's one value-type state (document, source map, history, selection, tool, zoom and page, find state, file state, open progress, refusal), `edit(_:coalesceKey:_:)` (the one place undo is recorded) and one extension file per area, each owned by its feature | `FolioWorkspace.swift`, `Workspace/FolioWorkspace+<Area>.swift`, `FolioPageSummary.swift` (the per-page accessibility value journeys read) | services; read and called by FolioApp |
| folio-commands | `FolioCommand` (every menu item and toolbar action), `unavailableHelp(for:)` and `title(for:)`, one availability file per area | `FolioCommand.swift`, `Availability/FolioAvailability+<Area>.swift` | workspace; FolioApp menus and toolbar |
| folio-tools | `FolioTool` (the palette: Select, Text Select, Highlight, Underline, Strike Out, Note, Text Box, Pen, Shape, Sign, Hand), its one-key shortcuts and `drag(from:to:)` routing per tool | `FolioTool.swift`, `Tools/FolioTool+<Kind>.swift` | annotating, selecting, signing; `FolioToolsTests` |
| folio-layout | Page layout math: the continuous column, two-up, page gaps, fit width and fit page scale, which pages are visible, page ↔ view points | `FolioLayout.swift` | reader view; budgets PB-2, PB-3 |
| folio-live | The Linux live types of the pure use cases: finding, selecting, annotating, form filling, signing, page organizing, history, the signature store (JSON in a folder the app names) | `Live/Live<Contract>.swift` | contract suites |
| folio-launch | Launch arguments (`-FolioFixture`, `-FolioSample`, `-FolioOpenFile`, `-FolioSaveTo`, `-FolioExportTo`, `-FolioPickFile(s)`, `-FolioSignaturesDir`, `-FolioWindowSize`, `-FolioControlsProbe`) parsed into `FolioLaunch` | `FolioLaunch.swift` | FolioApp's window root |

#### FolioApp (planned)

| Component | Responsibility | Paths | Relationships |
|---|---|---|---|
| folio-scene | `@main FolioApp`: a `DocumentGroup`-free `WindowGroup` (one window per open PDF, Halo's pattern), the `.suiteApp(.folio, host:)` modifier once the suite lands, menus as one `Commands` type per area | `FolioApp.swift`, `FolioCommands+<Area>.swift` | SuiteShell; folio-commands |
| folio-window | `FolioWindow`: `SuiteWindow` with the sidebar (Pages, Outline, Marks), the detail (page view, palette, status pills), the inspector; one `FolioWindow+<Area>.swift` per area (intents to the workspace, sheets) | `FolioWindow.swift`, `FolioWindow+<Area>.swift`, `FolioPrinting.swift` | workspace; SuiteUI |
| folio-pageview | The page view: page pictures from `PageImaging` in `FolioLayout`'s column, Folio's marks and form fields drawn over them, gestures routed to the active tool's `drag`, text selection, find bar and highlights; the Page Grid | `PageView/*.swift`, `PageGrid/*.swift` | layout, tools |
| folio-sidebar | Thumbnails (also the organize grid), outline, the marks list | `Sidebar/*.swift` | organizing |
| folio-inspector | Document info; the selected mark's colour, width, text, comment; the selected field; the selected page's size and rotation | `Inspector/*.swift` | annotating, forms |
| folio-sheets | Password, Insert, Combine, Extract and Split, Crop, Save Options, Signature, Export, Reduce Size, Recognize Text, Apply Redactions | `Sheets/*.swift` | the feature that owns each |
| folio-live-macos | The macOS live services: `PDFKitOpening`, `PDFKitImageOpening` (New from Images), `PDFKitImaging`, `PDFKitText`, `PDFKitFields` (widgets ↔ `FolioFormField`), `PDFKitAnnotations` (PDF annotations ↔ `FolioAnnotation`), `PDFKitWriting`, `PDFKitExporting`, `VisionRecognizing`, `FolioSampleWriter` (fixtures as real PDFs for `-FolioSample`), `FolioSignatureMark` (draws a signature body), `FolioServices+Live` | `Live/*.swift` | contracts; PDFKit, Vision, CoreGraphics |
| folio-controls | `folio.controls` probe JSON (every control with enabled and help) for the every-control journey | `FolioControls.swift` | journeys |

#### Folio tests (planned)

| Component | Paths |
|---|---|
| Model tests, contract suites, budgets | `Tests/FolioModelTests/*.swift` (one file per contract suite, one budget file per feature) |
| Snapshots and fidelity | `Tests/AppSnapshotTests/Folio*.swift` |
| Journeys | `UITests/FolioJourneyTests.swift` (W0) and `UITests/FolioJourneyTests+<Area>.swift` (one per feature) |

### 4.3 Relationships

| From | To | What |
|---|---|---|
| FolioApp | FolioModel | holds one `FolioWorkspace` in `@State` at the window root; reads it; calls its methods; runs the async service calls between a workspace's `begin…` and `finish…` methods (Halo's open pattern) |
| FolioApp | SuiteUI | `SuiteWindow`, `ToolbarGroup(.floating)`, inspector rows, `ViewerStatusBar`, `EmptyStateView`, `AppSwitcher` (section 7) |
| FolioApp | SuiteShell | `.suiteApp(.folio, host:)`, `SuiteAppDelegate`, Switch To and Open In menus, recents (once the suite's switching and recents features land; until then Folio keeps a 10-item recents list like Halo's) |
| FolioModel | SuiteModel | conforms to `SuiteDocumentHost` (open a file, make a PDF from images handed off by Photo or Library) |
| FolioApp live types | PDFKit, Vision, CoreGraphics | the four reading and writing jobs, OCR |
| FolioModel | creative-core CorePDF | none in v1; the `content-edit` feature (conditional, W4) |

### 4.4 creative-core work

PDFKit and Vision cover v1's reading, markup, forms, drawn signatures,
page organizing, save with passwords and OCR (section 1.5). They cannot do
the three things the research ranks next after those: edit existing text,
true redaction and certificate signatures (Apple docs: PDFMarkupType.redact
has no apply step; CGPDFScanner parses but cannot write a stream;
PDFAnnotationWidgetSubtype.signature has no signing API). Those need a
pure-Swift PDF engine. It belongs in creative-core because it is engine
work every platform can test, and because a future Linux or iPad build of
any suite app that touches PDF (Design's PDF export, #418) would share it.

| # | Spec (one line each) | Needed by | Tier | Status |
|---|---|---|---|---|
| CP-1 | `CorePDF` module: read any PDF 1.7 / 2.0 file into an object graph (lexer, cross-reference tables and streams, object streams, Flate and the predictor filters), lazily, read-only, with typed errors; acceptance: every file in a public conformance corpus opens or throws a typed error, none crashes | content-edit (W4), cert-sign (later) | 2 | needs a new core issue |
| CP-2 | `CorePDF` incremental writer: append changed and new objects and a new cross-reference section after the original bytes, so earlier bytes (and any signature over them) are untouched; acceptance: a file written with one changed object re-reads equal and its first N bytes are the original's | content-edit, cert-sign | 2 | needs a new core issue |
| CP-3 | `CorePDF` content streams: tokenize and serialize a page's content (operators and operands), and a text-run view (each show-text run with its font, size, matrix and glyph boxes); acceptance: tokenize then serialize is byte-identical modulo whitespace, run boxes match a reference within 0.5 pt | content-edit | 2 | needs a new core issue |
| CP-4 | `CorePDF` redaction: given page regions, remove every glyph whose box intersects them, cut intersecting image pixels (through CoreRaster) and vector paths, drop annotations and form fields there, and strip document metadata on request; acceptance: re-extracting text from the region yields nothing and the redacted file's bytes don't contain the removed strings in any stream | content-edit | 2 | needs a new core issue |
| CP-5 | `CorePDF` text replace: replace a text run's string, reusing its font when every new glyph exists in the embedded subset and otherwise reporting the missing characters; acceptance: the replaced line renders with the old font and the same baseline | content-edit | 2 | needs a new core issue |
| CP-6 | `CorePDF` signature placeholder: write a signature field with a fixed-size `/Contents` hole and `/ByteRange`, return the bytes to hash, and fill the hole with a CMS blob the app makes (the app signs with the macOS Security framework's CMS encoder); acceptance: a signed fixture validates with an independent open-source verifier | cert-sign (later) | 2 | needs a new core issue |

None blocks v1. `content-edit` is the conditional W4 feature (section 2.4);
certificate signing is Later.
