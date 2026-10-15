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
| 29 | Change the document's title and author | 151,099 views on the Mac Q&A site | https://apple.stackexchange.com/questions/274703 |
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

---

## 5. Journeys

Every tier-1 feature has a journey: an XCUITest that launches the bundle,
works the window the way a person would, and shoots the whole window after
every step (`docs/engineering.md`, Human-like UI tests). The app audit runs
on every shot.

**Files.** W0 creates `UITests/FolioJourneyTests.swift` (launch, menus,
every control, layout). Each feature owns `UITests/FolioJourneyTests+<Area>.swift`
with its own `XCTestCase` class, so no two features edit one journey file;
`project.yml`'s journey bundle globs `UITests/FolioJourneyTests*.swift`
(W0's supervisor-merged task adds the Folio bundle).

**Modes.** A journey first runs on `-FolioFixture <name>` (fake services,
section 6) and is flipped to `-FolioSample <name>` (live PDFKit and Vision,
the same fixture written as a real PDF by `FolioSampleWriter` into the
test's temp folder) by the task that lands the live type. P-J14 runs live
from its first PR.

**Finding things.** By the title a person reads where there is one, else by
identifier: `folio.page.<n>` (1-based) for each page view,
`folio.thumb.<n>`, `folio.mark.<id>`, `folio.field.<name>`, `folio.find`,
`folio.tool.<tool>`. The page view's pixels can't be read through XCUITest,
so `folio.page.<n>` carries the Model's `pageSummary(n)` as its
accessibility value, built and tested in FolioModel: "Page 2 of 3, Letter,
rotated 90°, 2 highlights, 1 note, fields: name=Ada Lovelace; agree=on".
Drags use page points mapped through `folio.page.<n>`'s frame and the zoom
(`FolioLayout` math, tested on Linux).

**Waiting.** No timing through XCUI queries. State changes are awaited with
`waitForExistence` or a value predicate (2 s); timing comes from the probe
(section 8).

### 5.1 Tier-1 journeys

| # | Test (file, feature) | Launch | Steps (each one shot, `folio-<step>`) | Asserts |
|---|---|---|---|---|
| P-J0 | `testLaunchShowsWindowShell` (`FolioJourneyTests.swift`, foundation) | none | launch | `expectWindowShell()`; the empty state "No PDF Open" with Open… and Create from Images…; the inspector "No Selection"; the switcher row's Folio item current and disabled "You're in Folio." once the suite wires it (until then every switcher item is disabled with its reason); every audit count 0 |
| P-J1 | `testOpenAndRead` (`+Read`, reader) | `-FolioOpenFile <tmp>/Lease.pdf` (sample `letter`) | open; ⌘2 Continuous; scroll to the end; ⌥⌘G, type 2, Return; ⌘9 Fit Width; ⌘+ twice; ⌘0; click thumbnail 3; ⌘3 Two Pages; open the Outline section; quit, relaunch with no file, File > Open Recent > Lease | title "Lease"; `folio.page.1` value starts "Page 1 of 3"; the status pill reads "Page 3 of 3" at the end, "Page 2 of 3" after Go to Page; zoom pill "Fit Width" then "125%"…"100%"; thumbnail 3 selected and page 3 at the top; two pages side by side (frames of page 1 and 2 share a top); the Outline section shows "No outline in this PDF." for `letter`; Open Recent lists "Lease" first and reopens it |
| P-J2 | `testFindText` (`+Find`, find) | `letter` | ⌘F; type "first day"; Return; Return; ⌘G; Match Case on, type "FIRST"; Escape | "1 of 2" then "2 of 2" then wraps "1 of 2"; the sidebar RESULTS list has 2 rows with "p. 1" and their context; with Match Case "No results" and the field's help "No matches for FIRST."; Escape closes the bar and keeps the page where the last hit was |
| P-J3 | `testHighlightUnderlineStrike` (`+Markup`, markup) | `letter` | press T; drag across "RESIDENTIAL LEASE" on page 1; Markup > Highlight; drag across line 2; press U (Underline tool) and drag line 3; press K and drag line 4; click the highlight; set colour Green in the inspector; type a comment "Check name"; ⌫ on the strike-out | page 1 value "3 marks" then "highlight, underline, strike-out"; Edit menu "Undo Highlight", "Undo Underline", "Undo Strike Out", "Undo Change Color", "Undo Comment", "Undo Delete"; inspector header "Highlight · Page 1" with the comment row; after ⌫ "2 marks" |
| P-J4 | `testNotesTextBoxPenShape` (`+Annotate`, markup) | `letter` | N, click page 1 at the margin, type "Ask about parking", Escape; X, click, type "Initial here", Escape; P, draw a stroke; R, drag a rectangle; V, drag the note 40 pt down; ⌘Z | page value lists "note, text box, ink, rectangle"; the note's popover holds the text; the text box shows "Initial here"; after the drag the note's frame moved by 40 pt × zoom; ⌘Z puts it back ("Undo Move Note"); an empty text box (X, click, Escape) is not created and the palette's help reads "Type some text for the text box." |
| P-J5 | `testFillForm` (`+Forms`, forms) | `form` | click Name; type "Ada Lovelace"; ⇥; type "ada@example.com"; ⇥ (to Plan); Space on Plus; ⇥; Space (Agree); Form > Check Form; Form > Clear Form; ⌘Z | after typing, `folio.field.name` value "Ada Lovelace"; ⇥ order Name → Email → Plan → Agree; Plus on and Basic off; Check Form before Agree reads "1 required field is empty: Agree to terms" with a warning outline on Agree, after Agree "All required fields are filled."; Clear empties all, Edit menu "Undo Clear Form" restores them; typing in Name is one step "Undo Typing" |
| P-J6 | `testSignDocument` (`+Sign`, sign) | `form` with `-FolioSignaturesDir <tmp>` | press S; New Signature…; Draw; drag two strokes on the pad; Done; click inside the Signature field; drag the signature's corner handle; press S, New Signature…, Type, "A.L.", Save as initials on, Done; click near the bottom margin | the library lists the drawn signature; placed inside the field, fitted and centered (its frame inside `folio.field.signature`'s); resize keeps the aspect within 1%; initials placed where clicked at 72 pt wide; quit and relaunch: the library still has both (stored in the folder); an empty pad's Done is disabled with help "Draw your signature in the box first." |
| P-J7 | `testOrganizePages` (`+Pages`, pages) | `letter` | ⌘4 Page Grid; click page 3; ⌘R; drag page 3 before page 1; select page 2, Shift-click page 3; Page > Delete Page; ⇧⌘B; Page > Crop Pages… with 36 pt margins on page 1, Crop; ⌘Z four times | rotated: page 3 value "rotated 90°"; order (by `folio.thumb.n` captions' content) 3, 1, 2; after delete 1 page left, and selecting all then ⌘⌫ shows "A PDF needs at least one page…" and changes nothing; a blank Letter page appended; page 1's value reads "cropped 540 × 720"; each ⌘Z names "Undo Crop", "Undo Insert Page", "Undo Delete Pages", "Undo Move Page" |
| P-J8 | `testCombineAndExtract` (`+Combine`, pages) | `letter`, with `form` written to `<tmp>/Application.pdf` | Page > Insert from File…, pick Application.pdf (`-FolioPickFile` skips the panel), at End; Page > Extract Pages…, type "2-3", Extract; in the new window ⌘S with `-FolioSaveTo` | 4 pages; page 4's fields fillable (`folio.field.name` exists on page 4); the Extract sheet refuses "5" with "This document has pages 1 to 4." under the field; a new window "Lease (pages 2–3)" with 2 pages; the original is unchanged |
| P-J9 | `testUndoRedoEveryEdit` (`+History`, history-files) | `form` | type in Name; highlight a line; rotate page 1; ⌘Z ×3; ⇧⌘Z ×3; scroll and zoom between | Edit menu names each step in order and back; scroll and zoom add no step; with nothing left Undo is disabled with "Nothing to undo." |
| P-J10 | `testSaveAndReopen` (`+Files`, history-files) | `form` sample, `-FolioSaveTo <tmp>/Filled.pdf` | fill Name; highlight; in the inspector's DOCUMENT section set Title to "Membership"; ⌘S; quit; relaunch `-FolioOpenFile <tmp>/Filled.pdf`; File > Save As… with Flatten on and a password (`-FolioSaveTo <tmp>/Flat.pdf`); open Flat.pdf | subtitle "Edited" then "Saved"; reopened: the value "Ada Lovelace", 1 highlight, the inspector title "Membership", Undo disabled; Flat.pdf asks for its password (the sheet), a wrong one reads "That password didn't unlock this PDF. Try again.", the right one opens with no fields (`folio.field.*` absent) and the name drawn into the page (page value "fields: none") |
| P-J11 | `testOpenProblems` (`+OpenErrors`, reader) | none, then `-FolioOpenFile` per file | write `not a pdf` text, a truncated PDF (sample cut at half), `locked` sample; open each; on the locked one Cancel, then open again and type the password | each message is `FolioOpenError.message` for its case (not a PDF; damaged with the reason; locked); Cancel leaves the empty state; the right password opens "Payslip"; the window never shows a half-open document |
| P-J12 | `testEveryControlActsOrSaysWhy` and `testEveryMenuOpens` (`FolioJourneyTests.swift`, foundation; extended by each feature) | `letter` with `-FolioControlsProbe` | open each menu; read the `folio.controls` JSON; click each enabled control, Escape, ⌘Z | every enabled control changed the shot or a value; every disabled one has help (QB-F1); each menu holds section 7.6's items for the features built so far |
| P-J13 | `testLayoutAtWidths` (`FolioJourneyTests.swift`, foundation) | `letter`, `-FolioWindowSize` ×5 | relaunch at each size of 8.3 | PL1–PL5 |
| P-J22 | `testCreateFromImages` (`+Images`, export-convert) | none, `-FolioPickFiles` a 600 × 800 PNG, a 800 × 600 JPEG and a text file, `-FolioSaveTo <tmp>/Scans.pdf` | File > New from Images…; ⌘S | 2 pages, the first portrait and the second landscape, each the image's aspect; "Skipped notes.txt: not an image."; the no-text pill offers Recognize…; title "Scans" after save |
| P-J23 | `testReduceSize` (`+Reduce`, export-convert) | `-FolioSample photos` (6 pages of 300 ppi photos, written by `FolioSampleWriter`), `-FolioExportTo <tmp>` | File > Reduce File Size…, Medium, Reduce; then Reduce again on the reduced file | the sheet reads "From <a> MB to <b> MB" with b ≤ 0.6 a (PF-11); `Photos (reduced).pdf` exists and the original's bytes are unchanged; the second run says "This PDF is already as small as Folio can make it." and writes nothing |
| P-J14 | `testReadMarkFillSignSave` (`FolioJourneyTests+Loop.swift`, core-loop) | live, `-FolioSample form`, `-FolioSaveTo` | the whole loop on live services: open; find "Name"; highlight it; fill Name and Agree; sign in the field; rotate page 1 and back; ⌘Z, ⇧⌘Z; ⌘S; relaunch on the file | each step on PDFKit; the reopened file has the value, the highlight, the signature (PF-12) and no extra page |

### 5.2 States each journey passes through

| Journey | Empty | Error | Loading |
|---|---|---|---|
| P-J0, P-J1 | no document: "No PDF Open" with Open… (prominent) and Create from Images…; a document with no outline: "No outline in this PDF."; no marks: "No markup yet. Pick a tool and drag over text." | – | open shows a progress row in the page view at once (`beginOpen`, QB-L9) and the thumbnails fill in as `PageImaging` returns; a page whose picture isn't ready shows a blank sheet of its size with a spinner, never a gap |
| P-J2 | no query: the bar's placeholder "Find in document"; no hits: "No results" and the field's help sentence | a page with no text layer is skipped and the bar says "2 pages have no text. Recognize text to search them." with Recognize… | search runs off the main thread; results stream in page order with "Searching… page n of m" |
| P-J3, P-J4 | Text Select on a page with no text: the help "This page has no text to select. Recognize text first."; markup on nothing: "Select some text first." | a file whose owner forbids markup: every markup tool disabled with "The owner of this PDF doesn't allow adding or changing markup."; moving a highlight: "Highlights stay on their text…" | – |
| P-J5 | a PDF without fields: the Form menu items disabled with "This PDF has no form fields. Use Text Box to type on it."; a scripted form: the banner "This form has scripts Folio doesn't run. Check calculated fields before sending." | read-only field: "<name> is read-only in this form."; a value too long or two lines in a one-line field: its sentence under the field | – |
| P-J6 | no signatures yet: the popover shows only "New Signature…" | an empty pad: Done disabled with its help; the library folder unwritable: "Signatures couldn't be saved…" and the signature still places for this document | – |
| P-J7, P-J8 | – | deleting every page: `lastPage`; a range outside the document: its sentence; a file the owner locked against assembly: page commands disabled with "The owner of this PDF doesn't allow changing its pages." | inserting a large file: the progress row as in open |
| P-J9 | nothing to undo or redo: disabled with "Nothing to undo." / "Nothing to redo." | – | – |
| P-J10, P-J11 | a new document from images is "Untitled" until saved | save to a read-only folder: subtitle "Not saved ⚠" and the sentence; the source file moved away: `sourceMissing`; open errors per `FolioOpenError` | save shows progress after 100 ms; the window stays usable and the save is atomic (temp file, then replace) |
| P-J14 | – | – | every live step's progress as above |
| P-J22, P-J23 | New from Images with nothing picked changes nothing; a new document is "Untitled" | a file that isn't an image is named and skipped; Reduce when the result isn't smaller writes nothing and says so | both sheets show progress with Cancel; the window stays usable |

### 5.3 Tier-2 journeys (v1, after the core loop)

| # | Test (file, feature) | Launch | Steps | Asserts |
|---|---|---|---|---|
| P-J20 | `testRecognizeScan` (`+OCR`, ocr) | `scan` | open; the warning pill "No text: Recognize…"; Tools > Recognize Text…, English, Recognize; ⌘F "total" | progress "Page n of 2"; afterwards the pill reads "Text recognized"; Find gets 1 hit on page 1; T selects "TOTAL 7.70"; after ⌘S and reopen the text is still there (PF-9) |
| P-J21 | `testExportPagesAndText` (`+Export`, export-convert) | `letter` with `-FolioExportTo <tmp>` | File > Export…, PNG, 150 ppi, Pages 1-2, Export; again as Text; again as a word-processing document | 2 files `Lease-1.png`, `Lease-2.png` of 1275 × 1650; `Lease.txt` with every line; `Lease.docx` exists and is non-empty; success line with Reveal in Finder |
| P-J24 | `testPrint` (`+Print`, export-convert) | `letter` | ⌘P; Cancel | the system print panel appears with 3 pages; Cancel returns with no change |
| P-J25 | `testEditLineInPlace` (`+ContentEdit`, content-edit; conditional) | `-FolioSample letter` | E; click "2. Rent."'s line; change "first" to "fifth"; Escape; ⌘S; reopen | the line reads "…due on the fifth day." in the same font (the page value names the font); Find "first day" finds 1 (page 1 line 3 only); a character missing from the font names itself in the help |
| P-J26 | `testRedactAndVerify` (`+ContentEdit`, content-edit; conditional) | `-FolioSample letter`, `-FolioSaveTo <tmp>/Redacted.pdf` | D; drag over "Landlord" on page 1; Tools > Apply Redactions…, Apply; open Redacted.pdf; ⌘F "Landlord" | the sheet lists "1 area on page 1"; the new file has no hit for "Landlord" on page 1 (page 3 still has its own); copying the area yields no text (PF-13) |

### 5.4 Perf journeys (`+Perf`, core-loop)

Report-only until the frame probe's journey helpers are on `dev`; each
reads the probe's JSON, never an XCUI timing.

| # | Test | Launch | Steps | Budget (section 8) |
|---|---|---|---|---|
| P-P1 | `testOpenLongDocument` | `-FolioSample long` | open from the empty window | PB-1: progress mark ≤ 100 ms, first page drawn ≤ 300 ms |
| P-P2 | `testScrollLongDocument` | `-FolioSample long` | scroll from page 1 to 500 at 3,000 pt/s | PB-3: p95 frame interval ≤ 1.5 refreshes |
| P-P3 | `testZoomSteps` | `-FolioSample long` | ⌘+ ×6, ⌘− ×6, pinch | PB-4: p95 ≤ 2 frames late |
| P-P4 | `testDragLatency` | `-FolioSample long` with 1,000 marks | drag-select a line; drag a note 300 pt at 300 pt/s | PB-6, PB-8: p95 ≤ 2 frames late, preview before mouse-up |
| P-P5 | `testPenLatency` | `letter` sample | a 2,000-point pen stroke at 300 pt/s | PB-10: p95 ≤ 2 frames late |
| P-P6 | `testReorderLatency` | `-FolioSample long`, Page Grid | drag page 3 across 40 thumbnails | PB-13: p95 ≤ 2 frames late |

---

## 6. Contracts

One Swift protocol per use case, each with a fake, so a feature's views can
be built and journeyed on the fake while its logic or its PDFKit type is
built, and the two meet by swapping one slot in `FolioServices`. They are
written for `FolioModel`: Linux-safe, Foundation through the
FoundationEssentials pattern, no engine, value types, `Sendable`, Swift 6
language mode, typed throws.

**Proof.** The files are in `docs/blueprints/pdf/contracts/`
(`Contracts/FolioValues.swift`, `Contracts/FolioContracts.swift`,
`Fakes/FolioFakes.swift`, `FolioServices.swift`) with ten proof tests in
`Tests/FolioContractTests.swift`, one per tier-1 journey group (open and
find, open refusals, highlight and note, fill in Tab order, sign into a
field, organize and combine and crop and split, undo coalescing, save round
trip with flatten and password and export, recognize a scan, permissions).
`docs/blueprints/pdf/contracts/check.sh` builds them as a `FolioModel`
target plus a test target in a throwaway package and runs the tests. Run on
2026-10-15 with Swift 6.1.2 on Ubuntu 24.04: `CONTRACTS: PASS`, no errors,
no warnings, 10 of 10 tests. W0 copies the files into `Sources/FolioModel/`
(the fakes one file per contract).

**Rules every conformance keeps.**

- Reads take values; writes take the document `inout` and throw
  `FolioEditError`, changing nothing when they throw (the fakes write to a
  copy where a partial change could happen).
- No contract records undo. `FolioWorkspace.edit(_:coalesceKey:_:)` wraps
  every write: it copies the document, runs the write, and on success hands
  the old value to `DocumentHistory.record`, so fakes and live types are
  tested without a workspace.
- Platform contracts (`DocumentOpening`, `PageImaging`, `PageTextReading`,
  `DocumentWriting`, `PageExporting`, `TextRecognizing`, `SignatureStoring`)
  carry `unavailableHelp`: nil once the service works. W0's live stubs in
  FolioApp return "Not built yet.", so every control that needs one is
  disabled with that sentence until its feature lands.
- Platform calls are `async`; the workspace stays synchronous: the window
  calls `begin…` on the workspace, awaits the service off the main actor,
  then calls `finish…` with the result (Halo's open pattern), so a 500-page
  open never blocks a frame (QB-L12).
- **No copies between fake and live.** For the pure use cases the fake *is*
  the reference behaviour: the feature that lands the live type moves the
  code to `Live/Live<Contract>.swift` and the fake becomes a one-line
  wrapper, so `scripts/ci`'s duplicate gate never sees two copies.
- One conformance suite per contract (`Tests/FolioModelTests/<Contract>ContractTests.swift`,
  W0) runs the same expectations against the fake and, once it exists, the
  live type (`@Test(arguments:)` over both). A live type is done when it
  passes its suite.

### 6.1 Use cases at a glance

| Use case | Protocol | Fake | Live (feature) | Journeys |
|---|---|---|---|---|
| UC-1 Open a PDF or images | `DocumentOpening` | `FakeDocumentOpening` (reads the fake file; passwords, not-PDF, too large) | `FolioApp/Live/PDFKitOpening.swift` (reader), `PDFKitImageOpening.swift` (export-convert) | P-J1, P-J11, P-J22 |
| UC-2 See a page | `PageImaging` | `FakePageImaging` (white page, grey band per line) | `FolioApp/Live/PDFKitImaging.swift` (reader) | P-J1 and every shot |
| UC-3 Page text | `PageTextReading` | `FakePageTextReading` (fixed grid: 72 pt in, 14 pt lines, 6 pt glyphs) | `FolioApp/Live/PDFKitText.swift` (reader) | P-J2, P-J3 |
| UC-4 Find | `TextFinding` | `FakeTextFinding` (reference) | `FolioModel/Live/LiveTextFinding.swift` (find) | P-J2 |
| UC-5 Select text | `TextSelecting` | `FakeTextSelecting` (reference) | `FolioModel/Live/LiveTextSelecting.swift` (markup) | P-J3 |
| UC-6 Mark up | `Annotating` | `FakeAnnotating` (reference) | `FolioModel/Live/LiveAnnotating.swift` (markup); `FolioApp/Live/PDFKitAnnotations.swift` maps to and from PDF annotations | P-J3, P-J4 |
| UC-7 Fill forms | `FormFilling` | `FakeFormFilling` (reference) | `FolioModel/Live/LiveFormFilling.swift` (forms); `FolioApp/Live/PDFKitFields.swift` maps widgets | P-J5 |
| UC-8 Make and place a signature | `Signing` | `FakeSigning` (reference) | `FolioModel/Live/LiveSigning.swift` (sign) | P-J6 |
| UC-8b Keep signatures | `SignatureStoring` | `FakeSignatureStore` (an actor in memory; can fail on save) | `FolioModel/Live/LiveSignatureStore.swift` (sign; JSON in the folder the app names) | P-J6 |
| UC-9 Organize pages | `PageOrganizing` | `FakePageOrganizing` (reference) | `FolioModel/Live/LivePageOrganizing.swift` (pages) | P-J7, P-J8 |
| UC-10 Undo and redo | `DocumentHistory` | `FakeDocumentHistory` (reference) | `FolioModel/Live/LiveDocumentHistory.swift` (history-files) | P-J9 and every Edit-menu assert |
| UC-11 Save | `DocumentWriting` | `FakeDocumentWriting` (writes the fake file; flatten and password) | `FolioApp/Live/PDFKitWriting.swift` (history-files) | P-J10, P-J14 |
| UC-12 Export | `PageExporting` | `FakePageExporting` (describes each image; text with format markers) | `FolioApp/Live/PDFKitExporting.swift` (export-convert) | P-J21, P-J23 |
| UC-13 Recognize text | `TextRecognizing` | `FakeTextRecognizing` (returns a scan page's known lines) | `FolioApp/Live/VisionRecognizing.swift` (ocr) | P-J20 |
| (W4) Replace a line, redact | `TextReplacing`, `Redacting` in `Contracts/FolioContentEditContracts.swift` | written by content-edit with its fakes | `FolioModel/Live/LiveTextReplacing.swift`, `LiveRedacting.swift` over CorePDF | P-J25, P-J26 |

Reduce File Size is `DocumentWriting.write` with `maxImagePPI` set; Print
is the system print operation on the saved bytes; document properties and
zoom, page and view mode are workspace methods (pure value edits, tested on
`FolioWorkspace`).

### 6.2 The workspace methods views call

Each lives in the extension file its feature owns (section 9). Every write
goes through `edit`; every read is a computed property. `FolioWorkspace` is
a `struct` the window keeps in `@State` (Halo's `HaloProject` pattern).

| File (feature) | Methods |
|---|---|
| `FolioWorkspace.swift` (foundation) | `init(services:launch:)`, `edit(_ name: String, coalesceKey: String?, _ change: (inout FolioDocumentState) throws(FolioEditError) -> Void)` (internal), `endCoalescing()`, `var refusal: FolioRefusal?`, `dismissRefusal()`, `pageText(_:) -> FolioPageText?`, `didLoadText(_:for:)`, `var tool: FolioTool`, `selectTool(_:)` |
| `FolioPageSummary.swift` (foundation) | `pageSummary(_ number: Int) -> String` (the accessibility value of `folio.page.<n>`) |
| `Workspace/FolioWorkspace+Read.swift` (reader) | `beginOpen(name:)`, `finishOpen(_: Result<FolioOpened, FolioOpenError>)`, `var needsPassword: Bool`, `setZoom(_: FolioZoom)`, `zoomIn()`, `zoomOut()`, `setViewMode(_: FolioViewMode)`, `go(toPage:)`, `go(toLabel:) throws(FolioEditError)`, `back()`, `forward()`, `didScroll(toPage:)`, `var statusPills: [String]`, `var recent: [FolioRecentFile]`, `setRecent(_:)` |
| `Workspace/FolioWorkspace+Find.swift` (find) | `setFindText(_:)`, `setMatchCase(_:)`, `setWholeWords(_:)`, `findNext()`, `findPrevious()`, `closeFind()`, `var findHits: [FolioSearchHit]`, `var findCurrent: Int?`, `var findStatus: String` |
| `Workspace/FolioWorkspace+Markup.swift` (markup) | `beginTextDrag(at:on:)`, `moveTextDrag(to:)`, `endTextDrag()`, `selectWord(at:on:)`, `selectAllText(on:)`, `var textSelection: FolioTextSelection`, `copyText() -> String`, `mark(_: FolioMarkupStyle)`, `addNote(at:on:)`, `addTextBox(at:on:)`, `setMarkText(_:)`, `beginInk(at:on:)`, `addInkPoint(_:)`, `endInk()`, `beginShape(_:at:on:)`, `moveShape(to:)`, `endShape()`, `selectMark(_:)`, `moveSelectedMark(dx:dy:)`, `resizeSelectedMark(to:)`, `setMarkColor(_:)`, `setLineWidth(_:)`, `deleteSelectedMarks()`, `var marks: [FolioMarkRow]` |
| `Workspace/FolioWorkspace+Forms.swift` (forms) | `focusField(_:)`, `focusNextField(backward:)`, `setField(_:to:)` (coalesced per field), `checkForm() -> [FolioFieldID]`, `clearForm()`, `var focusedField: FolioFieldID?`, `var formBanner: String?` |
| `Workspace/FolioWorkspace+Sign.swift` (sign) | `beginSignatures()`, `finishSignatures(_: [FolioSignature])`, `addSignature(strokes:isInitials:) throws(FolioEditError)`, `addSignature(typed:isInitials:) throws(FolioEditError)`, `addSignature(image:aspect:isInitials:)`, `removeSignature(_:)`, `chooseSignature(_:)`, `placeSignature(at:on:)`, `var signatures: [FolioSignature]`, `var signaturesToSave: [FolioSignature]?` |
| `Workspace/FolioWorkspace+Pages.swift` (pages) | `selectPages(_:extending:)`, `rotateSelectedPages(clockwise:)`, `deleteSelectedPages()`, `moveSelectedPages(to:)`, `nudgeSelectedPages(by:)`, `insertBlankPage()`, `beginInsert(at:)`, `finishInsert(_: Result<FolioOpened, FolioOpenError>)`, `extract(range:) throws(FolioEditError) -> FolioDocumentState`, `split(after:) throws(FolioEditError) -> [FolioDocumentState]`, `cropSelectedPages(to:)`, `var selectedPages: [FolioPageID]` |
| `Workspace/FolioWorkspace+History.swift` (history-files) | `undo()`, `redo()`, `var undoTitle: String?`, `var redoTitle: String?` |
| `Workspace/FolioWorkspace+Files.swift` (history-files) | `beginSave(options:)`, `finishSave(_: Result<Data, FolioWriteError>, name:path:)`, `var saveState: FolioSaveState` (`edited`, `saved`, `failed(String)`), `setTitle(_:)`, `setAuthor(_:)` |
| `Workspace/FolioWorkspace+Export.swift` (export-convert) | `beginExport(_: FolioExportRequest)`, `exportProgress(page:)`, `finishExport(_:)`, `cancelExport()`, `beginReduce(level:)`, `finishReduce(original:reduced:)` |
| `Workspace/FolioWorkspace+OCR.swift` (ocr) | `var pagesWithoutText: [FolioPageID]`, `beginRecognize(pages:languages:)`, `didRecognize(_: FolioPageText, for:)`, `finishRecognize(_: FolioRecognizeError?)` |

The state types these read (`FolioZoom`, `FolioViewMode`, `FolioRefusal`,
`FolioRecentFile`, `FolioMarkRow`, `FolioSaveState`, `FolioExportRequest`)
are declared with `FolioWorkspace` in W0, `Sendable` and `Equatable` with
public memberwise inits, so W0 owns them and each feature only fills them.

### 6.3 The protocols (`Contracts/FolioContracts.swift`)

```swift
// Contracts/FolioContracts.swift: one protocol per Folio use case.
// Linux-safe. Rules every conformance keeps:
// - Reads take values. Writes take the document `inout` and throw
//   FolioEditError, leaving it unchanged when they throw.
// - No contract records undo: FolioWorkspace.edit(_:_:) does, around a call.
// - `unavailableHelp` is nil once the service works; until then every control
//   that needs it is disabled with that sentence (CLAUDE.md, No dead controls).
// - Platform work (PDFKit, Vision, CoreGraphics) lives only in live types in
//   FolioApp; everything else has a Linux live type in FolioModel/Live.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// UC-1 Open a PDF (or make one from images) and read its pages, fields,
/// annotations and outline into a FolioDocumentState.
/// Live: `FolioApp/Live/PDFKitOpening.swift` (PDFDocument(data:), unlock(withPassword:)).
public protocol DocumentOpening: Sendable {
    var unavailableHelp: String? { get }
    /// Opens PDF bytes. Throws `.needsPassword` for a locked file opened with
    /// nil, `.wrongPassword` for a bad one, `.notPDF`, `.damaged`, `.tooLarge`.
    func open(_ data: Data, name: String, password: String?) async throws(FolioOpenError) -> FolioOpened
    /// Makes a document of one page per image (PNG, JPEG or HEIC bytes), each
    /// page the image's size at 72 ppi capped to fit A4 or Letter.
    func open(images: [Data], name: String) async throws(FolioOpenError) -> FolioOpened
}

/// UC-2 See a page: the page's picture without Folio's own annotations
/// (the view draws those from the Model, so edits never wait on a render).
/// Live: `FolioApp/Live/PDFKitImaging.swift` (PDFPage.thumbnail(of:for:)).
public protocol PageImaging: Sendable {
    var unavailableHelp: String? { get }
    /// A picture at most `maxPixels` on its long side, rotation applied.
    /// nil when the page's source is gone.
    func image(of page: FolioPage, maxPixels: Int) async -> FolioBitmap?
}

/// UC-3 The text on a page, line by line with each Character's box.
/// Live: `FolioApp/Live/PDFKitText.swift` (PDFPage.string, characterBounds(at:)).
public protocol PageTextReading: Sendable {
    var unavailableHelp: String? { get }
    func text(of page: FolioPage) async -> FolioPageText
}

/// UC-4 Find text across the document. Pure: works on page text.
/// Live: `FolioModel/Live/LiveTextFinding.swift`.
public protocol TextFinding: Sendable {
    /// Hits in page order, then reading order. An empty query finds nothing.
    func find(_ query: FolioSearchQuery, pages: [FolioPageID], text: [FolioPageID: FolioPageText]) -> [FolioSearchHit]
}

/// UC-5 Select text by dragging, double-click a word. Pure.
/// Live: `FolioModel/Live/LiveTextSelecting.swift`.
public protocol TextSelecting: Sendable {
    /// Characters between the two points in reading order on one page.
    func select(from: FolioPoint, to: FolioPoint, on page: FolioPageID, text: FolioPageText) -> FolioTextSelection
    /// The word under the point, or an empty selection.
    func word(at point: FolioPoint, on page: FolioPageID, text: FolioPageText) -> FolioTextSelection
}

/// UC-6 Mark up: highlight, underline, strike out, notes, text boxes, ink,
/// shapes, images; move, resize, recolor, comment, delete. Pure.
/// Live: `FolioModel/Live/LiveAnnotating.swift`.
public protocol Annotating: Sendable {
    /// Text markup over a selection; refuses an empty one (`.emptySelection`).
    func mark(_ selection: FolioTextSelection, style: FolioMarkupStyle, color: FolioColor,
              in doc: inout FolioDocumentState) throws(FolioEditError) -> [FolioAnnotationID]
    /// Any other body placed at `rect` on `page`.
    func add(_ body: FolioAnnotationBody, rect: FolioRect, color: FolioColor, on page: FolioPageID,
             in doc: inout FolioDocumentState) throws(FolioEditError) -> FolioAnnotationID
    func move(_ id: FolioAnnotationID, dx: Double, dy: Double, in doc: inout FolioDocumentState) throws(FolioEditError)
    func setRect(_ id: FolioAnnotationID, to rect: FolioRect, in doc: inout FolioDocumentState) throws(FolioEditError)
    func setColor(_ id: FolioAnnotationID, to color: FolioColor, in doc: inout FolioDocumentState) throws(FolioEditError)
    /// The text of a note or text box, or the comment on any other kind.
    func setText(_ id: FolioAnnotationID, to text: String, in doc: inout FolioDocumentState) throws(FolioEditError)
    func delete(_ ids: [FolioAnnotationID], in doc: inout FolioDocumentState) throws(FolioEditError)
    /// The topmost annotation whose rect holds the point (4 pt slop), or nil.
    func hit(_ point: FolioPoint, on page: FolioPageID, in doc: FolioDocumentState) -> FolioAnnotationID?
}

/// UC-7 Fill a form: type, check, choose; Tab order; required fields. Pure.
/// Live: `FolioModel/Live/LiveFormFilling.swift`.
public protocol FormFilling: Sendable {
    /// Sets one field. A radio option sets its whole group; a value the field
    /// can't take is refused with `.invalidValue("<sentence>")`.
    func set(_ field: FolioFieldID, to value: FolioFieldValue, in doc: inout FolioDocumentState) throws(FolioEditError)
    /// Tab order: page order, then top to bottom, then left to right; skips
    /// read-only fields; wraps. nil when the form has no fillable field.
    func next(after field: FolioFieldID?, backward: Bool, in doc: FolioDocumentState) -> FolioFieldID?
    /// Required fields still empty, in Tab order.
    func missingRequired(in doc: FolioDocumentState) -> [FolioFieldID]
    /// Every field back to empty (Clear Form).
    func clear(in doc: inout FolioDocumentState) throws(FolioEditError)
}

/// UC-8 Make a signature or initials and place it. Pure.
/// Live: `FolioModel/Live/LiveSigning.swift`.
public protocol Signing: Sendable {
    /// From pad strokes in view points: trims to the ink box, scales into the
    /// unit box, keeps the aspect. Refuses fewer than 2 points of ink.
    func make(strokes: [[FolioPoint]], isInitials: Bool, id: FolioSignatureID) throws(FolioEditError) -> FolioSignature
    func make(typed name: String, isInitials: Bool, id: FolioSignatureID) throws(FolioEditError) -> FolioSignature
    /// Places a signature centered on `point`, `width` points wide. Inside an
    /// empty signature field it fits that field instead.
    func place(_ signature: FolioSignature, at point: FolioPoint, width: Double, on page: FolioPageID,
               in doc: inout FolioDocumentState) throws(FolioEditError) -> FolioAnnotationID
}

/// UC-8b Keep signatures between launches.
/// Live: `FolioModel/Live/LiveSignatureStore.swift` (a JSON file the app's
/// folder holds; the macOS app passes the URL).
public protocol SignatureStoring: Sendable {
    var unavailableHelp: String? { get }
    func load() async -> [FolioSignature]
    func save(_ signatures: [FolioSignature]) async throws(FolioWriteError)
}

/// UC-9 Organize pages: reorder, rotate, delete, insert blank, combine
/// files, extract and split. Pure.
/// Live: `FolioModel/Live/LivePageOrganizing.swift`.
public protocol PageOrganizing: Sendable {
    /// Moves the pages, keeping their order, so the first lands at `index`
    /// of the document as it is after they are taken out.
    func move(_ pages: [FolioPageID], to index: Int, in doc: inout FolioDocumentState) throws(FolioEditError)
    func rotate(_ pages: [FolioPageID], clockwise: Bool, in doc: inout FolioDocumentState) throws(FolioEditError)
    /// Deletes pages and their annotations and fields. Refuses all of them (`.lastPage`).
    func delete(_ pages: [FolioPageID], in doc: inout FolioDocumentState) throws(FolioEditError)
    /// Inserts every page of another opened file at `index` (Combine);
    /// returns the new page ids. Its fields keep their names unless taken,
    /// then get a " 2" suffix.
    func insert(_ other: FolioOpened, at index: Int, in doc: inout FolioDocumentState) throws(FolioEditError) -> [FolioPageID]
    func insertBlank(size: FolioSize, at index: Int, in doc: inout FolioDocumentState) throws(FolioEditError) -> FolioPageID
    /// Crops pages to `rect` (page space, before rotation), clamped to each
    /// page; refuses a rect under 72 pt on a side. nil removes the crop.
    func crop(_ pages: [FolioPageID], to rect: FolioRect?, in doc: inout FolioDocumentState) throws(FolioEditError)
    /// A new document of just these pages, in document order (Extract).
    func extract(_ pages: [FolioPageID], from doc: FolioDocumentState) throws(FolioEditError) -> FolioDocumentState
    /// Splits after each page number in `after` (1-based), into parts.
    func split(_ doc: FolioDocumentState, after: [Int]) throws(FolioEditError) -> [FolioDocumentState]
    /// "1-3, 5, 8-" style text to 1-based page numbers, sorted, unique.
    func parseRange(_ text: String, pageCount: Int) throws(FolioEditError) -> [Int]
}

/// UC-10 Undo and redo: a stack of named document snapshots. Pure.
/// Live: `FolioModel/Live/LiveDocumentHistory.swift`.
public protocol DocumentHistory: Sendable {
    /// Records `before` under `name`. Two records in a row with the same
    /// non-nil `coalesceKey` make one step (a drag, typing in one field).
    func record(_ before: FolioDocumentState, name: String, coalesceKey: String?, in history: inout FolioHistory)
    /// Ends coalescing, so the next record is its own step.
    func endCoalescing(_ history: inout FolioHistory)
    func undo(_ current: FolioDocumentState, in history: inout FolioHistory) -> FolioDocumentState?
    func redo(_ current: FolioDocumentState, in history: inout FolioHistory) -> FolioDocumentState?
}

public struct FolioHistory: Equatable, Sendable {
    public struct Step: Equatable, Sendable {
        public var name: String
        public var state: FolioDocumentState
        public var coalesceKey: String?
        public init(name: String, state: FolioDocumentState, coalesceKey: String?) {
            self.name = name; self.state = state; self.coalesceKey = coalesceKey
        }
    }
    public var undoSteps: [Step] = []
    public var redoSteps: [Step] = []
    public var limit: Int
    public var coalescing = false
    public init(limit: Int = 100) { self.limit = max(1, limit) }
    public var undoName: String? { undoSteps.last?.name }
    public var redoName: String? { redoSteps.last?.name }
}

/// UC-11 Save: the document as PDF bytes, from its sources plus the edits.
/// Live: `FolioApp/Live/PDFKitWriting.swift` (PDFDocument.write(to:withOptions:)).
public protocol DocumentWriting: Sendable {
    var unavailableHelp: String? { get }
    func write(_ doc: FolioDocumentState, options: FolioWriteOptions) async throws(FolioWriteError) -> Data
}

/// UC-12 Export pages as pictures, or the text as plain text, rich text or a
/// word-processing document.
/// Live: `FolioApp/Live/PDFKitExporting.swift`.
public protocol PageExporting: Sendable {
    var unavailableHelp: String? { get }
    /// One encoded image per page, in the order given, annotations drawn.
    func images(of pages: [FolioPage], annotations: [FolioAnnotation], as format: FolioImageExport)
        async throws(FolioWriteError) -> [Data]
    /// The document's text in reading order. Plain text separates pages with a
    /// form feed; rich text and word-processing keep paragraphs, bold, italic
    /// and size where the PDF's text layer has them.
    func text(of doc: FolioDocumentState, as format: FolioTextFormat) async throws(FolioWriteError) -> Data
}

/// UC-13 Recognize text on a scanned page (OCR), so it can be found,
/// selected and highlighted. Live: `FolioApp/Live/VisionRecognizing.swift`
/// (RecognizeTextRequest, accurate level).
public protocol TextRecognizing: Sendable {
    var unavailableHelp: String? { get }
    /// Languages offered in the Recognize Text sheet, BCP 47 tags.
    var languages: [String] { get }
    func recognize(_ page: FolioPage, languages: [String]) async throws(FolioRecognizeError) -> FolioPageText
}
```

### 6.4 Values and fakes

`Contracts/FolioValues.swift` (shown in full in the file) declares, all
`Hashable`, `Codable` where they cross a file and `Sendable`:
`FolioPoint`, `FolioSize` (`.letter`, `.a4`), `FolioRect`, `FolioRotation`,
`FolioColor` (clamped sRGB), `FolioSourceID`, `FolioPageID`,
`FolioPageOrigin` (`.source(id, index:)`, `.blank`), `FolioPage` (size,
rotation, label, crop, `displaySize`), `FolioTextLine` (text plus one
rect per Character), `FolioTextOrigin` (`embedded`, `recognized`, `none`),
`FolioPageText`, `FolioTextSpan`, `FolioTextSelection`, `FolioSearchQuery`,
`FolioSearchHit`, `FolioAnnotationID`, `FolioMarkupStyle`, `FolioShape`,
`FolioAnnotationBody` (`markup`, `note`, `freeText`, `ink`, `shape`,
`signature`, `image`), `FolioAnnotation`, `FolioFieldID`, `FolioFieldKind`
(`text(multiline:maxLength:)`, `checkbox`, `radio(group:option:)`,
`choice(options:editable:)`, `signature`), `FolioFieldValue`,
`FolioFormField`, `FolioSignatureID`, `FolioSignatureKind` (`drawn`,
`typed`, `image`), `FolioSignature`, `FolioOutlineItem`, `FolioPermissions`,
`FolioDocumentState`, `FolioOpened`, `FolioBitmap`, `FolioWriteOptions`
(flatten, passwords, permissions, `maxImagePPI`, keep OCR text),
`FolioImageFormat`, `FolioTextFormat` (`plain`, `rtf`, `docx`),
`FolioImageExport`, and the typed errors `FolioOpenError`,
`FolioEditError`, `FolioWriteError`, `FolioRecognizeError`, each with the
`message` sentence the person reads. `String.folioTrimmed` stands in for
`trimmingCharacters`, which FoundationEssentials lacks.

`Fakes/FolioFakes.swift` holds the fake file format (`FolioFixtureFile`,
JSON starting `%FOLIO-FAKE-PDF-1` so the fake opener can tell it from a
real PDF), the fixed glyph layout (`FolioFakeLayout`), the
`FolioFakeLibrary` the platform fakes read, and one fake per contract.
`FolioServices.swift` holds `FolioServices` and the named fixtures
(`FolioFixtures.letter`, `.form`, `.scan`, `.locked`, `.marked`, `.long`).

### 6.5 Can every tier-1 journey be built from these?

| Journey | Contract calls (in order) | Proof test |
|---|---|---|
| P-J1 Open and read | `DocumentOpening.open`, `PageImaging.image` per visible page, `PageTextReading.text`; zoom and pages are `FolioLayout` | `openReadAndFind` |
| P-J2 Find | `PageTextReading.text` per page, `TextFinding.find` | `openReadAndFind` |
| P-J3 Highlight | `TextSelecting.select`, `Annotating.mark`, `setColor`, `setText`, `delete`; `word(at:)` | `highlightAndNote` |
| P-J4 Notes, text box, pen, shape | `Annotating.add` (`.note`, `.freeText`, `.ink`, `.shape`), `hit`, `move`, `DocumentHistory.undo` | `highlightAndNote`, `undoRedoCoalesces` |
| P-J5 Fill | `FormFilling.next`, `set`, `missingRequired`, `clear` | `fillFormInTabOrder` |
| P-J6 Sign | `Signing.make(strokes:)`, `make(typed:)`, `SignatureStoring.save`, `load`, `Signing.place` | `signIntoField` |
| P-J7 Organize | `PageOrganizing.move`, `rotate`, `delete`, `insertBlank`, `crop` | `organizeAndCombine` |
| P-J8 Combine, extract | `DocumentOpening.open`, `PageOrganizing.insert`, `parseRange`, `extract`, `split` | `organizeAndCombine` |
| P-J9 Undo | `DocumentHistory.record`, `endCoalescing`, `undo`, `redo` | `undoRedoCoalesces` |
| P-J10 Save, reopen, flatten, password | `DocumentWriting.write`, `DocumentOpening.open` with and without the password | `saveRoundTripAndFlatten` |
| P-J11 Open problems | `DocumentOpening.open` throwing each `FolioOpenError` | `openRefusals` |
| P-J22 New from Images | `DocumentOpening.open(images:)` | (W0's `DocumentOpeningContractTests`; the fake reads "IMG w x h" bytes) |
| P-J23 Reduce size | `DocumentWriting.write` with `maxImagePPI`; byte counts compared in the workspace | `saveRoundTripAndFlatten` (write path); PF-11 for the size |
| P-J20 (tier 2) Recognize | `TextRecognizing.recognize`, then `TextFinding.find` on the result | `recognizeScannedPages` |
| P-J12 Every control | `FolioCommand.unavailableHelp(for:)` over every service's `unavailableHelp` | W0's `FolioCommandTests` |

---

## 7. Look

The captain's look decisions of 2026-10-15 (PR #973) apply as written:
Folio opens in `SuiteWindow` (sidebar, content, a trailing inspector the
person can hide with ⌥⌘I; chrome in system Liquid Glass, content flat;
title bar kept; follows the system appearance), its tools are Flare's
floating glass palette (`ToolbarGroup`, `.floating` style, one capsule
over the content), and the app switcher row sits centered in the window
toolbar with Folio's item current. Folio is a reading app before it is an
editor, so it follows the system's Light and Dark appearance like Library,
not the always-dark editor look; the page itself is document content and
is always drawn as the PDF says (white paper stays white), on the
`canvasSurround` token around it.

Content vs. control (design.md, Layers): **content** is the pages, the
thumbnails grid and the find results list; **control** is the toolbar,
sidebar, inspector, the floating palette, the find bar (a `GlassPanel`
over the top of the page view, the one other glass surface) and sheets.

### 7.1 The main window (reading, 1440 × 900)

```
┌──────────────────────────────────────────────────────────────────────────────────────────┐
│ ● ● ●  ▤ │ ◁ ▷ │ Lease.pdf — Edited        ⌂   ✦   ▱   ◐   ▦   ◎  [▣]   │ ⌕  ⬆ Share  ⓘ │ ← toolbar (glass)
├───────────────┬──────────────────────────────────────────────────────────┬───────────────┤   switcher row centered:
│ PAGES ▾       │   ┌─────────────────────────────┐                         │ DOCUMENT      │   Home, Flare, Design, Photo,
│ ┌─────┐       │   │ RESIDENTIAL LEASE AGREEMENT │                         │ ┌───────────┐ │   Library, Halo, Folio (current,
│ │ ▓▓▓ │ 1     │   │ ███████ This lease is made  │      ╭──────────────╮   │ │Pages     3│ │   in the capsule)
│ │ ▓▓  │       │   │ between the Landlord and... │      │ ↖ ⌶ ▮ U̲ S̶ ✎ │   │ │Size Letter│ │
│ └─────┘       │   │ 1. Term. The term begins... │      │ ☐ T ✍ ✋     │   │ │Text  Yes  │ │ ← inspector:
│ ┌─────┐       │   │ 2. Rent. Rent is due on...  │      ╰──────────────╯   │ └───────────┘ │   InspectorHeader + info card
│ │ ▓▓  │ 2     │   │                    [note ▣] │  ↑ floating palette      │ MARKS         │   with nothing selected;
│ └─────┘       │   └─────────────────────────────┘    (ToolbarGroup        │ Highlight  1  │   the selected mark's rows
│ ┌─────┐       │   ┌─────────────────────────────┐     .floating, glass)   │ Notes      1  │   when one is
│ │ ▓   │ 3     │   │ 3. Deposit. The deposit...  │                         │               │
│ └─────┘       │                                                            │               │
│ OUTLINE ▸     │                                                            │               │
│ MARKS ▸       │  (Page 1 of 3)  (110%)  (Letter 8.5 × 11 in)      ViewerStatusBar pills       │
└───────────────┴──────────────────────────────────────────────────────────┴───────────────┘
```

| Region | Component | Status |
|---|---|---|
| Window | `SuiteWindow` (sidebar, detail, inspector), the `-SuiteWindowSize` argument | existing; the sidebar slot, window subtitle and `EditorDetail` arrive with editor-in-window (#973) |
| App switcher | `AppSwitcher` in `SuiteWindow`'s toolbar | planned by #973; **needs a seventh item** (`suite.switcher.folio`, ⌃⌘6): a `needs-ui` issue plus the suite's `SuiteApp.folio` (section 9.5) |
| Save state | window subtitle ("Edited", "Saved", "Not saved ⚠") | planned by #973 |
| Toolbar items | `ToolbarAction`: sidebar toggle, back and forward (page history), zoom menu, Find (⌘F), Share, inspector toggle; one prominent action at most: none while reading | existing |
| Sidebar | `SidebarSection` + `SidebarRow` for Outline and Marks; thumbnails are a `ThumbnailGrid` (one column in the sidebar) | existing; ThumbnailGrid **needs** a page-number caption, a drop-insertion indicator and multi-select with Shift and ⌘ (`needs-ui`, section 9.5) |
| Page view | content: Folio's own view (`PageView/`), pages on `SuiteColor.canvasSurround`, centered, a 16 pt gap between pages | Folio-owned content view, no look-alike control in it |
| Tool palette | `ToolbarGroup(style: .floating)` | existing (Flare) |
| Status | `ViewerStatusBar` pills: page n of m, zoom, page size; the trailing slot shows "Text recognized" or "No text: Recognize…" as a warning pill | existing |
| Inspector | `InspectorHeader` (document name, info card: pages, size, text layer, permissions), `InspectorSection`, `InspectorColorRow`, `InspectorSliderRow` (line width, opacity), `InspectorPickerRow` (font size, shape), `InspectorAction` | existing |
| Empty state | `EmptyStateView`: "No PDF Open" · "Open a PDF or drop one here." · Open… (prominent), Create from Images… | existing |

### 7.2 Find (⌘F)

```
┌──────────────────────────────── page view ──────────────────────────────┐
│  ╭──────────────────────────────────────────────────────────────────╮   │
│  │ ⌕ first day          ✕ │ 2 of 2 │ ‹ › │ Aa  ⎵W │ Done           │   │ ← GlassPanel over the top edge
│  ╰──────────────────────────────────────────────────────────────────╯   │
│   ┌───────────────────────────┐                                         │
│   │ 1. Term. The term begins  │                                         │
│   │ on the ▒first day▒ of ... │  ← every hit tinted; the current one    │
│   └───────────────────────────┘     outlined in accent (shape cue)      │
└─────────────────────────────────────────────────────────────────────────┘
 sidebar while searching: RESULTS (2) · rows "p. 1  …begins on the first day of the month."
```

Uses `.searchable`-style field inside `GlassPanel` (existing), `List` rows
in the sidebar (system), `Toggle` buttons for Match Case and Whole Words
(system, `.toggleStyle(.button)`). Hits use `stateSelected` tint; the
current hit adds a 2 pt `accent` outline (colour plus shape).

### 7.3 Organize pages (View > Page Grid, ⌘4)

```
┌───────────────┬───────────────────────────────────────────────────────────┬──────────────┐
│ PAGES         │  ┌─────┐  ┌─────┐  ┌─────┐  ┌─────┐  ┌─────┐                │ PAGE 3       │
│ (sidebar      │  │ ▓▓▓ │  │ ▓▓  │  │╔═══╗│  │ ▓▓  │  │     │                │ ┌──────────┐ │
│  hidden in    │  │ ▓▓  │  │ ▓   │  │║▓▓ ║│  │ ▓   │  │     │                │ │Size  A4  │ │
│  the grid)    │  └─────┘  └─────┘  │╚═══╝│  └─────┘  └─────┘                │ │Rotation 0│ │
│               │     1        2     └─────┘     4    ▏   5  ← drop line      │ └──────────┘ │
│               │                       3 (selected: accent outline)         │ ↻ Rotate     │
│               │  ╭─────────────────────────────────────╮                    │ ⊕ Insert…    │
│               │  │ ↻  ↺  ⊕ Blank  ⊕ File…  ⇪ Extract  🗑 │ ← floating group │ 🗑 Delete     │
│               │  ╰─────────────────────────────────────╯                    │              │
└───────────────┴───────────────────────────────────────────────────────────┴──────────────┘
```

`ThumbnailGrid` in the detail (existing; the caption, drop indicator and
multi-select are the `needs-ui` above), the floating `ToolbarGroup` for page
commands (existing), `InspectorAction` rows for the selected page
(existing).

### 7.4 Fill and sign

```
   ┌─────────────────────────────────────────┐
   │ MEMBERSHIP APPLICATION                  │
   │ Name   [Ada Lovelace_______________]    │ ← fields drawn by Folio over the page:
   │ Email  [____________________________] * │   focus ring = 2 pt accent; required
   │ Plan   (•) Basic   ( ) Plus             │   empty field after "Check Form" =
   │ [✓] Agree to terms                      │   stateWarning outline + triangle
   │ Signature ┌──────────────────────┐      │
   │           │   𝓐𝓭𝓪 𝓛𝓸𝓿𝓮𝓵𝓪𝓬𝓮      │ ← placed signature (selected: handles)
   │           └──────────────────────┘      │
   └─────────────────────────────────────────┘

 Sign tool (S) → popover from the palette:
   ╭──────────────────────────────╮
   │ SIGNATURES                   │
   │  𝓐𝓭𝓪 𝓛𝓸𝓿𝓮𝓵𝓪𝓬𝓮        ✕      │ ← rows: system List
   │  A.L.  (initials)     ✕      │
   │ ＋ New Signature…            │
   ╰──────────────────────────────╯

 New Signature sheet: Picker (segmented: Draw · Type · Image), a pad
 (content: a flat Canvas, 3:1), Clear, Save as initials (checkbox), Done.
```

Form fields are Folio's own content views over the page (a text field
drawn on paper is document content), but each one is a real `TextField`,
`Toggle(.checkbox)`, radio `Picker(.radioGroup)` or `Picker(.menu)` placed
at the field's rect, so keyboard, focus ring and VoiceOver are the
system's (no look-alike). The signature pad is a SwiftUI `Canvas` (content),
the sheet a system sheet with `Picker`, `Toggle(.checkbox)`, `Button`.

### 7.5 Export, Reduce Size, Recognize Text

Each is a sheet on the document window (design.md, Commands: "Export lives
at File > Export, opening a sheet"): a `Form` with `Picker` rows (Format:
PDF, PNG, JPEG, Text; Pages: All, Current, Range [field]; Resolution 72,
150, 300 ppi), a `Slider` for JPEG quality, `Toggle(.checkbox)` for
Flatten, Password fields as `SecureField`, and one prominent button
(Export…, Reduce, Recognize). Progress inside the sheet with a system
`ProgressView` and Cancel; the result line uses `stateSuccess` with a
checkmark or `stateError` with an exclamation and the error's sentence.

### 7.6 Commands and menus

| Menu | Items (shortcut) | Owner feature |
|---|---|---|
| File | New from Images… (⇧⌘N), Open… (⌘O), Open Recent ▸, Close (⌘W), Save (⌘S), Save As… (⇧⌘S), Export… (⌥⌘E), Reduce File Size…, Print… (⌘P) | reader, history-files, export-convert |
| Edit | Undo (⌘Z), Redo (⇧⌘Z), Cut, Copy (⌘C copies selected text or mark), Paste, Delete (⌫), Select All (⌘A: all text on the page), Find ▸ Find… (⌘F), Find Next (⌘G), Find Previous (⇧⌘G) | history-files, markup, find |
| View | Single Page, Continuous (⌘1, ⌘2), Two Pages (⌘3), Page Grid (⌘4), Actual Size (⌘0), Zoom In (⌘+), Zoom Out (⌘−), Fit Width (⌘9), Fit Page, Show Sidebar (⌃⌘S), Show Inspector (⌥⌘I), Go to Page… (⌥⌘G) | reader, pages |
| Markup | Highlight (⌃⌘H), Underline (⌃⌘U), Strike Out (⌃⌘K), Add Note (⌃⌘N), Add Text Box (⌃⌘T), Pen, Shape ▸, Sign ▸ | markup, sign |
| Form | Next Field (⇥), Previous Field (⇧⇥), Check Form, Clear Form | forms |
| Page | Rotate Right (⌘R), Rotate Left (⌘L), Insert Blank Page (⇧⌘B), Insert from File… (⇧⌘I), Delete Page (⌘⌫), Extract Pages…, Split… | pages |
| Tools | Recognize Text… | ocr |
| Window | Switch To ▸ (suite), the system's items | suite |

Tool shortcuts while the page view has focus (design.md, Canvas apps):
V Select, T Text Select, H Highlight, U Underline, K Strike Out, N Note,
X Text Box, P Pen, R Shape, S Sign, Space-drag Hand.

### 7.7 SuiteUI Folio needs (filed as `needs-ui` by the named feature)

| Need | For | Filed by |
|---|---|---|
| `AppSwitcher` seventh item and ⌃⌘6, once `SuiteApp` gains `.folio` | the switcher row | foundation (with the suite line's `SuiteApp.folio` task) |
| `ThumbnailGrid`: page caption, multi-select (Shift, ⌘), drag reorder with a drop line, keyboard reorder (⌥⌘← →) | sidebar and Page Grid | pages |
| A pad view for drawing a signature: a flat drawing well with Clear, keyboard alternative "Type instead" | signature sheet | sign; placeholder: a SwiftUI `Canvas` in FolioApp until it lands |
| `ViewerStatusBar` trailing slot accepting a button pill ("Recognize…") | the no-text pill | ocr; placeholder: a menu item and the inspector row |

---

## 8. Quality bar

Every item names where it is measured and the test that measures it.
"Gate" means a test fails over the number; "report-only" means the test
records the number and fails only on too few samples, until ten green CI
runs set the gate at the measured CI p95 × 1.5, never tighter than the
device target (`docs/review-rubric.md`, How gates are set). A gate never
loosens without the captain. The rubric's ids (`QB-…`) are cited where a
row instantiates one.

### 8.1 Speed budgets per interactive tool

Two halves per tool, as Halo does it. The **Model half** is the work
between the input and a value the view can draw, measured on Linux and
macOS by budget tests in `FolioModelTests` (median and p95 over 200 runs on
the named fixture; debug CI gates carry the rubric's ×10). W0 adds the
shared timing helper `Tests/FolioModelTests/FolioBudget.swift`; each
feature writes its rows in its own `Folio<Feature>BudgetTests.swift`. The
**UI half** is input to the first display refresh that shows it, in frames
late, read from the frame probe (`FrameProbe`, SuiteUI) in the perf
journeys P-P1 to P-P6; until the probe's journey helpers are on `dev` these
are report-only.

| id | Tool | What is timed | Fixture | Device target | CI gate | Test | Feature |
|---|---|---|---|---|---|---|---|
| PB-1 | Open | `DocumentOpening.open` + `finishOpen` on the fake; on the live type, first page drawn | `long` (500 pages) | fake ≤ 20 ms; live first page on screen ≤ 300 ms (QB-L9: progress shown ≤ 100 ms) | fake ≤ 200 ms debug; live report-only | `FolioBudgetTests.openLong`; P-P1 | foundation, reader |
| PB-2 | Layout | `FolioLayout` for every page (continuous, fit width) | `long` | ≤ 2 ms | ≤ 20 ms debug | `FolioBudgetTests.layoutLong` | reader |
| PB-3 | Scroll | `visiblePages(in:)` per scroll step | `long` | ≤ 0.2 ms | ≤ 2 ms debug | `FolioBudgetTests.visiblePages`; UI half P-P2: p95 frame interval ≤ 1.5 refreshes (QB-L10) | reader |
| PB-4 | Zoom | one `setZoom` + layout | `long` | ≤ 2 ms | ≤ 20 ms debug | `FolioBudgetTests.zoomStep`; P-P3 ≤ 2 frames late | reader |
| PB-5 | Find | `TextFinding.find` over all page text | `long` (20,000 lines) | ≤ 50 ms for the whole document; first hit shown ≤ 100 ms | ≤ 500 ms debug | `FolioBudgetTests.findLong` | find |
| PB-6 | Text select drag | one `select(from:to:)` step | `letter` page 1 and a `long` page | ≤ 0.5 ms | ≤ 5 ms debug | `FolioBudgetTests.selectStep`; P-P4 ≤ 2 frames late (QB-L1) | markup |
| PB-7 | Highlight | `mark` + workspace `edit` record | `long` with 1,000 marks | ≤ 1 ms | ≤ 10 ms debug | `FolioBudgetTests.markStep` | markup |
| PB-8 | Move or resize a mark | one drag step | `long` with 1,000 marks | ≤ 1 ms | ≤ 10 ms debug | `FolioBudgetTests.moveMarkStep`; P-P4 | markup |
| PB-9 | Hit test | `Annotating.hit` per pointer move | 1,000 marks on one page | ≤ 1 ms (QB-L5) | ≤ 10 ms debug | `FolioBudgetTests.hit` | markup |
| PB-10 | Pen | one ink point appended | a 2,000-point stroke | ≤ 0.2 ms | ≤ 2 ms debug | `FolioBudgetTests.inkPoint`; P-P5 ≤ 2 frames late (QB-L1) | markup |
| PB-11 | Type in a field | one `FormFilling.set` + record (coalesced) | `form` ×200 fields | ≤ 1 ms | ≤ 10 ms debug | `FolioBudgetTests.fieldKeystroke` | forms |
| PB-12 | Place a signature | `Signing.place` | `form` | ≤ 1 ms | ≤ 10 ms debug | `FolioBudgetTests.placeSignature` | sign |
| PB-13 | Page reorder drag | one `move` + thumbnail list rebuild | `long` | ≤ 2 ms | ≤ 20 ms debug | `FolioBudgetTests.reorderLong`; P-P6 ≤ 2 frames late | pages |
| PB-14 | Undo, Redo | one step | `long` with 1,000 marks | ≤ 2 ms | ≤ 20 ms debug | `FolioBudgetTests.undoStep` | history-files |
| PB-15 | Save | live `PDFKitWriting.write` | a 50-page, 5 MB sample with 100 marks | ≤ 1 s release, progress ≤ 100 ms (QB-L9) | report-only | `FolioWritingBudgetTests` (macOS) | history-files |
| PB-16 | Recognize text | live Vision, accurate, per page | 300 ppi scan sample | ≤ 1.5 s per page release; progress per page | report-only | `FolioOCRBudgetTests` (macOS) | ocr |
| PB-17 | Thumbnail | live `PageImaging.image(maxPixels: 256)` | `long` sample | ≤ 15 ms per page | report-only | `FolioImagingBudgetTests` (macOS) | reader |

Every row above has a fixture that exists in section 6 (`long`, `form`,
`letter`) or a sample the named feature writes with `FolioSampleWriter`,
and a named test; none is judged by eye.

### 8.2 App-audit checks

All six checks of `docs/blueprints/app-audit.md` run on every Folio shot:
`disabled-dim`, `overlap`, `contrast`, `identifier`, `offscreen`,
`unnamed`. Folio is new, so it enters `UITests/audit-baseline.json` at **0
for every check** in W0's PR (adding a new app at 0 is not a loosening; a
count above 0 would need the captain). Every Folio control ships with a
`folio.<area>.<name>` identifier and a label.

| Check | Target | How Folio holds it | Measured by |
|---|---|---|---|
| `identifier`, `unnamed` | 0 | every control in FolioApp has `.accessibilityIdentifier("folio.…")` and a label; form-field views use the field's name and tooltip as label | `audit-folio-*.json`; `FolioControlsTests` (Linux: every `FolioCommand` has a title and identifier) |
| `offscreen` | 0 | layout spec 8.3 at 1024 × 768 | same, plus PL1 |
| `overlap` | 0 | the floating palette never covers the status pills or the find bar (PL4) | same |
| `contrast` | 0 | only tokens; the page is document content and its marks use document colours, but the selection outline, find tint and handles are tokens | same |
| `disabled-dim` | 0 | every disabled control is a system or SuiteUI control drawn disabled from `unavailableHelp` | same |

### 8.3 Layout spec

Checked at window sizes **minimum** (`SuiteSize.windowMinimum`, about 944 ×
600 after #973), **1024 × 768** (the CI runner's display), **1280 × 800**,
**1440 × 900** and **1920 × 1080**, through `-FolioWindowSize`, with the
`letter` fixture open, page 1 selected and a highlight selected.

| id | Rule | Tolerance | Measured by |
|---|---|---|---|
| PL1 | Nothing off the window; no two enabled controls overlap | the audit's own (1 pt slack, 2 pt overlap) | `testLayoutAtWidths` (`FolioJourneyTests.swift`, W0): relaunch at each size, shoot `folio-layout-<w>` |
| PL2 | Fit Width: the page's width equals the detail width minus 2 × 24 pt margins; Fit Page: the whole page shows | ≤ 1 pt | same journey reads `folio.page.1`'s frame; Linux half `FolioLayoutTests.fitWidth`, `.fitPage` |
| PL3 | Pages are centered in the detail column, 16 pt apart, never under the floating palette at the default zoom | centers ≤ 1 pt; gap ≤ 0.5 pt | same; Linux half `FolioLayoutTests.column` |
| PL4 | The floating palette sits 12 pt in from the detail's leading edge, vertically centered, and never overlaps the status pills or the find bar at any width | 0 pt overlap | `testLayoutAtWidths` frames of `suite.tools`, `folio.find`, `suite.status` |
| PL5 | At minimum width the inspector can be hidden and the page still fits at ≥ 50% zoom; with it shown, Fit Width still shows a page ≥ 320 pt wide | ≥ 320 pt | same, at minimum |
| PL6 | Thumbnails: one column in the sidebar, each ≤ the sidebar width − 24 pt, captions never truncate below 4 digits ("1234") | ≤ 0.5 pt | `FolioThumbnailLayoutTests` (macOS host) |
| PL7 | Page Grid: as many columns as fit at 160 pt per thumbnail plus 16 pt gaps, at least 2 | exact column count | `FolioLayoutTests.grid` (Linux) at 600, 900, 1400 pt |
| PL8 | Form fields drawn over the page stay inside their PDF rect at every zoom from 50% to 400% | ≤ 0.5 pt after scale | `FolioFieldOverlayTests` (macOS host) |

### 8.4 Fidelity tests (output equals a reference)

| id | Output | Reference | Tolerance | Test (where) | Feature |
|---|---|---|---|---|---|
| PF-1 | Live `PageImaging` of a sample page (vector text, a filled shape, an image) at 2× | the same page drawn by `PDFPage.draw(with:to:)` into a bitmap context in the test (the reference renderer) | channel ≤ 2/255, ≤ 0.5% of pixels (QB-V2) | `FolioImagingFidelityTests` (macOS) | reader |
| PF-2 | `PDFKitText.text(of:)` of a sample written by `FolioSampleWriter` with known strings at known points | the strings and their positions the writer used | strings exact; glyph boxes ≤ 1 pt | `FolioTextFidelityTests` (macOS) | reader |
| PF-3 | Saved file reopened: pages, order, rotation, field values, annotation kinds, rects and colours | the `FolioDocumentState` that was saved | exact for values; rects ≤ 0.01 pt; colours ≤ 1/255 | `FolioRoundTripTests` (macOS, every fixture as a sample) | history-files |
| PF-4 | A page with Folio's marks drawn on screen vs the same page exported to PNG at the same scale | each other | channel ≤ 2/255, ≤ 0.5% of pixels (QB-V4: what you see is what you export) | `FolioMarksFidelityTests` (macOS) | markup, export-convert |
| PF-5 | Flatten: a flattened save has no annotation or widget objects, and its pixels equal the unflattened save's | the unflattened save rendered | annotation count 0; pixels as PF-4 | `FolioFlattenTests` (macOS) | history-files |
| PF-6 | Password save: opening with no password throws `.needsPassword`, with the wrong one `.wrongPassword`, with the right one equals the saved state; owner restrictions read back as set | the options used | exact | `FolioPasswordTests` (macOS) | history-files |
| PF-7 | Combine `letter` + `form`: page count, order, every field name (a taken name gets " 2"), every value | the two inputs | exact | `PageOrganizingContractTests` (Linux) and `FolioRoundTripTests` (macOS) | pages |
| PF-8 | OCR on a sample rendered from known lines at 300 ppi | the known lines | character error rate ≤ 1% on the clean sample; found by Find afterwards | `FolioOCRFidelityTests` (macOS) | ocr |
| PF-9 | Saved OCR text layer: after Save and reopen, `PageTextReading` returns the recognized lines with origin `embedded` and the page's pixels are unchanged | the recognized text; the page before save | strings exact; pixels as PF-1 | `FolioOCRRoundTripTests` (macOS) | ocr |
| PF-10 | Export PNG at 72, 150, 300 ppi | page size × ppi / 72 | pixel size exact | `FolioExportTests` (macOS) and `PageExportingContractTests` (Linux) | export-convert |
| PF-11 | Reduce File Size on the image-heavy sample | the original | output ≤ 60% of the input's bytes, every page's text equal, PF-1 pixels within channel ≤ 12/255 at 1× (images resampled) | `FolioReduceSizeTests` (macOS) | export-convert |
| PF-12 | Signature placed in a field, saved, reopened | the placed rect and the signature's strokes | rect ≤ 0.01 pt; stroke points ≤ 0.1 pt | `FolioSignatureRoundTripTests` (macOS) | sign |
| PF-13 | (W4) Redaction: text extracted from a redacted region after save, and every content stream's decoded bytes | nothing; the removed strings | no text; no occurrence | `FolioRedactionTests` (macOS) and CP-4's own tests (Linux, creative-core) | content-edit |

### 8.5 Feel (rubric section 6)

| id | How Folio meets it | Measured by |
|---|---|---|
| QB-F1 No dead controls | every command's availability is `unavailableHelp(for:)`; every palette tool's `drag` changes the document on `letter` or is disabled with help | `FolioToolsTests`, `FolioCommandTests` (Linux); P-J13 |
| QB-F2 Immediate feedback | a text drag shows the selection before mouse-up; a pen stroke draws as it goes; a refused edit shows its sentence at the place it was refused | the probe's preview mark (P-P4, P-P5); journey asserts |
| QB-F3 One gesture, one named step | `edit(_:coalesceKey:_:)` names every step ("Undo Highlight", "Undo Move Page", "Undo Typing"); scroll, zoom and find are never steps | Model tests count undo steps; journeys read the Edit menu |
| QB-F4 Keyboard parity | every tool has a one-key shortcut; Tab and Shift-Tab walk form fields; arrows move a selected mark 1 pt (Shift 10 pt); ⌥⌘← → move a selected page | P-J5, P-J7 |
| QB-F5 Reduce Motion, Increase Contrast | page scroll is content; zoom is instant under Reduce Motion; goldens in Increase Contrast | goldens |
| QB-F6 Geometry holds | only SuiteUI components and tokens in chrome | design lint |

---

## 9. Waves

### 9.1 How the work is split

A **feature** is one lead's packet (`docs/blueprints/pdf/features/<feature>.md`,
written after approval) and one `feature-lead` issue labelled `line:folio`.
A **wave** is a set of features that own disjoint files and wait on nothing
in the same wave, so their leads run side by side. Files W0 creates as
stubs pass to the feature named on them, which replaces them whole; across
waves a later feature may own an earlier one's file only after that one is
done, which the filing rule below guarantees. `docs/blueprints/pdf/waves.py`
holds the table below as data and checks it: no file owned twice in a wave,
every owned `Sources/` file in exactly one component of `c4-planned.json`,
and every wait on an earlier wave. Run on 2026-10-15: `WAVES: PASS (12
features, 143 agent-hours)`.

```
W0  foundation ─────────────────────────────────────────────── waits on nothing
        │                                                        (+ supervisor: Package.swift, project.yml, bundle-apps)
        ├──▶ W1  reader          (P-T1, P-T2, P-T3, P-T19)
        ├──▶ W1  find            (P-T6)
        ├──▶ W1  markup          (P-T5, P-T7–P-T10)            six leads side by side,
        ├──▶ W1  forms           (P-T11, P-T12)                 no shared file
        ├──▶ W1  pages           (P-T3 thumbnails, P-T13–P-T16)
        └──▶ W1  history-files   (P-T17, P-T18, P-T20, P-T26)
                 │
                 ├──▶ W2  sign            after markup, forms
                 ├──▶ W2  export-convert  after history-files, markup   (P-T4, P-T22–P-T25)
                 └──▶ W2  ocr             after reader, find, history-files
                          │
                          └──▶ W3  core-loop   after every W1 and W2 feature
                                   │
                                   └──▶ W4  content-edit (conditional)   after core-loop and creative-core CP-1–CP-5
```

A W2 feature starts as soon as its own W1 dependencies merge. Journey tasks
need the Folio journey bundle in `project.yml` (W0). The lead playbook's
stage 0 stops a lead whose `Depends on:` issue is open, so each feature
issue is filed with the one dependency in its row.

| Wave | Feature | Feature issue `Depends on:` | Tasks (about) | Agent-hours (about) |
|---|---|---|---|---|
| W0 | `foundation` | nothing (its supervisor task needs the captain's merge) | 14 PRs: values; protocols; fakes (two PRs); fixtures and services; workspace state and `edit`; commands and availability; tools; layout and page summary; launch arguments; window shell, sidebar and inspector stubs, area stubs; live stubs; contract suites; the every-control and layout journeys; audit entry and C4 | 22 |
| W1 | `reader` | foundation | 8 | 13 |
| W1 | `find` | foundation | 4 | 6 |
| W1 | `markup` | foundation | 9 | 15 |
| W1 | `forms` | foundation | 6 | 10 |
| W1 | `pages` | foundation | 8 | 13 |
| W1 | `history-files` | foundation | 7 | 12 |
| W2 | `sign` | filed once markup and forms are done; the later of the two | 6 | 10 |
| W2 | `export-convert` | the later of history-files and markup | 7 | 12 |
| W2 | `ocr` | the last of reader, find, history-files | 5 | 8 |
| W3 | `core-loop` | the last W1 or W2 feature to finish | 4 | 6 |
| W4 | `content-edit` | core-loop, and creative-core CP-1 to CP-5 closed | 8 | 16 |

Totals: W0 22 agent-hours; W1 69 (about 12 wall-clock hours with six leads
in parallel); W2 30; W3 6; W4 16 (plus the creative-core work, estimated
there). 143 agent-hours for Folio's own work; v1 without W4 is 127.

### 9.2 Features and their owned files

Generated by `python3 docs/blueprints/pdf/waves.py --markdown`.

#### W0 · `foundation`: Foundation: targets, contracts, fakes, workspace, the window's seams

- **Covers:** P-T30 (no dead controls); open and show pages on fakes for every W1 feature; the targets and the audit entry
- **Waits on:** nothing
- **Proves:** P-J0, P-J12, P-J13; PB-1 (fake half); PL1-PL5
- **Estimate:** about 14 PRs, 22 agent-hours
- **Owned files (128):** `Sources/FolioModel/Contracts/FolioValues.swift`, `Sources/FolioModel/Contracts/FolioContracts.swift`, `Sources/FolioModel/Fakes/FolioFakeFile.swift`, `Sources/FolioModel/Fakes/FakeDocumentOpening.swift`, `Sources/FolioModel/Fakes/FakePageImaging.swift`, `Sources/FolioModel/Fakes/FakePageTextReading.swift`, `Sources/FolioModel/Fakes/FakeTextFinding.swift`, `Sources/FolioModel/Fakes/FakeTextSelecting.swift`, `Sources/FolioModel/Fakes/FakeAnnotating.swift`, `Sources/FolioModel/Fakes/FakeFormFilling.swift`, `Sources/FolioModel/Fakes/FakeSigning.swift`, `Sources/FolioModel/Fakes/FakeSignatureStore.swift`, `Sources/FolioModel/Fakes/FakePageOrganizing.swift`, `Sources/FolioModel/Fakes/FakeDocumentHistory.swift`, `Sources/FolioModel/Fakes/FakeDocumentWriting.swift`, `Sources/FolioModel/Fakes/FakePageExporting.swift`, `Sources/FolioModel/Fakes/FakeTextRecognizing.swift`, `Sources/FolioModel/Fixtures/FolioFixtures.swift`, `Sources/FolioModel/FolioServices.swift`, `Sources/FolioModel/FolioWorkspace.swift`, `Sources/FolioModel/FolioCommand.swift`, `Sources/FolioModel/FolioTool.swift`, `Sources/FolioModel/FolioLaunch.swift`, `Sources/FolioModel/FolioLayout.swift`, `Sources/FolioModel/FolioPageSummary.swift`, `Sources/FolioModel/Workspace/FolioWorkspace+Read.swift`, `Sources/FolioModel/Workspace/FolioWorkspace+Find.swift`, `Sources/FolioModel/Workspace/FolioWorkspace+Markup.swift`, `Sources/FolioModel/Workspace/FolioWorkspace+Forms.swift`, `Sources/FolioModel/Workspace/FolioWorkspace+Sign.swift`, `Sources/FolioModel/Workspace/FolioWorkspace+Pages.swift`, `Sources/FolioModel/Workspace/FolioWorkspace+History.swift`, `Sources/FolioModel/Workspace/FolioWorkspace+Files.swift`, `Sources/FolioModel/Workspace/FolioWorkspace+Export.swift`, `Sources/FolioModel/Workspace/FolioWorkspace+OCR.swift`, `Sources/FolioModel/Availability/FolioAvailability+Read.swift`, `Sources/FolioModel/Availability/FolioAvailability+Find.swift`, `Sources/FolioModel/Availability/FolioAvailability+Markup.swift`, `Sources/FolioModel/Availability/FolioAvailability+Forms.swift`, `Sources/FolioModel/Availability/FolioAvailability+Sign.swift`, `Sources/FolioModel/Availability/FolioAvailability+Pages.swift`, `Sources/FolioModel/Availability/FolioAvailability+History.swift`, `Sources/FolioModel/Availability/FolioAvailability+Files.swift`, `Sources/FolioModel/Availability/FolioAvailability+Export.swift`, `Sources/FolioModel/Availability/FolioAvailability+OCR.swift`, `Sources/FolioModel/Tools/FolioTool+Select.swift`, `Sources/FolioModel/Tools/FolioTool+TextMarkup.swift`, `Sources/FolioModel/Tools/FolioTool+Annotate.swift`, `Sources/FolioModel/Tools/FolioTool+Sign.swift`, `Sources/FolioModel/Live/LiveTextFinding.swift`, `Sources/FolioModel/Live/LiveTextSelecting.swift`, `Sources/FolioModel/Live/LiveAnnotating.swift`, `Sources/FolioModel/Live/LiveFormFilling.swift`, `Sources/FolioModel/Live/LiveSigning.swift`, `Sources/FolioModel/Live/LiveSignatureStore.swift`, `Sources/FolioModel/Live/LivePageOrganizing.swift`, `Sources/FolioModel/Live/LiveDocumentHistory.swift`, `Sources/FolioApp/FolioApp.swift`, `Sources/FolioApp/FolioWindow.swift`, `Sources/FolioApp/FolioControls.swift`, `Sources/FolioApp/PageView/FolioPageView.swift`, `Sources/FolioApp/PageView/FolioPageGestures.swift`, `Sources/FolioApp/PageView/FolioMarksLayer.swift`, `Sources/FolioApp/PageView/FolioFieldLayer.swift`, `Sources/FolioApp/Sidebar/FolioSidebar.swift`, `Sources/FolioApp/Sidebar/FolioThumbnails.swift`, `Sources/FolioApp/Inspector/FolioInspector.swift`, `Sources/FolioApp/Live/FolioServices+Live.swift`, `Sources/FolioApp/FolioWindow+Read.swift`, `Sources/FolioApp/FolioWindow+Find.swift`, `Sources/FolioApp/FolioWindow+Markup.swift`, `Sources/FolioApp/FolioWindow+Forms.swift`, `Sources/FolioApp/FolioWindow+Sign.swift`, `Sources/FolioApp/FolioWindow+Pages.swift`, `Sources/FolioApp/FolioWindow+History.swift`, `Sources/FolioApp/FolioWindow+Files.swift`, `Sources/FolioApp/FolioWindow+Export.swift`, `Sources/FolioApp/FolioWindow+OCR.swift`, `Sources/FolioApp/FolioCommands+Read.swift`, `Sources/FolioApp/FolioCommands+Find.swift`, `Sources/FolioApp/FolioCommands+Markup.swift`, `Sources/FolioApp/FolioCommands+Forms.swift`, `Sources/FolioApp/FolioCommands+Sign.swift`, `Sources/FolioApp/FolioCommands+Pages.swift`, `Sources/FolioApp/FolioCommands+History.swift`, `Sources/FolioApp/FolioCommands+Files.swift`, `Sources/FolioApp/FolioCommands+Export.swift`, `Sources/FolioApp/FolioCommands+OCR.swift`, `Sources/FolioApp/Live/PDFKitOpening.swift`, `Sources/FolioApp/Live/PDFKitImageOpening.swift`, `Sources/FolioApp/Live/PDFKitImaging.swift`, `Sources/FolioApp/Live/PDFKitText.swift`, `Sources/FolioApp/Live/PDFKitFields.swift`, `Sources/FolioApp/Live/PDFKitAnnotations.swift`, `Sources/FolioApp/Live/PDFKitWriting.swift`, `Sources/FolioApp/Live/PDFKitExporting.swift`, `Sources/FolioApp/Live/VisionRecognizing.swift`, `Sources/FolioApp/Live/FolioSampleWriter.swift`, `Sources/FolioApp/Live/FolioSignatureMark.swift`, `Tests/FolioModelTests/DocumentOpeningContractTests.swift`, `Tests/FolioModelTests/PageImagingContractTests.swift`, `Tests/FolioModelTests/PageTextReadingContractTests.swift`, `Tests/FolioModelTests/TextFindingContractTests.swift`, `Tests/FolioModelTests/TextSelectingContractTests.swift`, `Tests/FolioModelTests/AnnotatingContractTests.swift`, `Tests/FolioModelTests/FormFillingContractTests.swift`, `Tests/FolioModelTests/SigningContractTests.swift`, `Tests/FolioModelTests/SignatureStoringContractTests.swift`, `Tests/FolioModelTests/PageOrganizingContractTests.swift`, `Tests/FolioModelTests/DocumentHistoryContractTests.swift`, `Tests/FolioModelTests/DocumentWritingContractTests.swift`, `Tests/FolioModelTests/PageExportingContractTests.swift`, `Tests/FolioModelTests/TextRecognizingContractTests.swift`, `Tests/FolioModelTests/FolioCommandTests.swift`, `Tests/FolioModelTests/FolioToolsTests.swift`, `Tests/FolioModelTests/FolioWorkspaceTests.swift`, `Tests/FolioModelTests/FolioLayoutTests.swift`, `Tests/FolioModelTests/FolioFixturesTests.swift`, `Tests/FolioModelTests/FolioPageSummaryTests.swift`, `Tests/FolioModelTests/FolioBudget.swift`, `Tests/FolioModelTests/FolioFoundationBudgetTests.swift`, `Tests/AppSnapshotTests/FolioWindowSnapshots.swift`, `UITests/FolioJourneyTests.swift`, `UITests/audit-baseline.json`, `docs/c4/model.json`, `Package.swift`, `project.yml`, `scripts/bundle-apps`

#### W1 · `reader`: Open and read: live PDFKit, zoom and view modes, go to page, outline, passwords, open errors

- **Covers:** P-T1, P-T2, P-T3 (go to page, outline), P-T19
- **Waits on:** foundation
- **Proves:** P-J1, P-J11; PB-1 (live), PB-2, PB-3, PB-4, PB-17; PF-1, PF-2
- **Estimate:** about 8 PRs, 13 agent-hours
- **Owned files (24):** `Sources/FolioApp/Live/PDFKitOpening.swift`, `Sources/FolioApp/Live/PDFKitImaging.swift`, `Sources/FolioApp/Live/PDFKitText.swift`, `Sources/FolioApp/Live/FolioSampleWriter.swift`, `Sources/FolioModel/FolioLayout.swift`, `Sources/FolioModel/Workspace/FolioWorkspace+Read.swift`, `Sources/FolioModel/Availability/FolioAvailability+Read.swift`, `Sources/FolioApp/FolioWindow+Read.swift`, `Sources/FolioApp/FolioCommands+Read.swift`, `Sources/FolioApp/PageView/FolioPageView.swift`, `Sources/FolioApp/Sidebar/FolioOutline.swift`, `Sources/FolioApp/Sheets/FolioPasswordSheet.swift`, `Tests/FolioModelTests/DocumentOpeningContractTests.swift`, `Tests/FolioModelTests/PageImagingContractTests.swift`, `Tests/FolioModelTests/PageTextReadingContractTests.swift`, `Tests/FolioModelTests/FolioLayoutTests.swift`, `Tests/FolioModelTests/FolioReadTests.swift`, `Tests/FolioModelTests/FolioReaderBudgetTests.swift`, `Tests/AppSnapshotTests/FolioReaderSnapshots.swift`, `Tests/AppSnapshotTests/FolioImagingFidelityTests.swift`, `Tests/AppSnapshotTests/FolioTextFidelityTests.swift`, `Tests/AppSnapshotTests/FolioImagingBudgetTests.swift`, `UITests/FolioJourneyTests+Read.swift`, `UITests/FolioJourneyTests+OpenErrors.swift`

#### W1 · `find`: Find text: the find bar, every hit, results list

- **Covers:** P-T6
- **Waits on:** foundation
- **Proves:** P-J2; PB-5
- **Estimate:** about 4 PRs, 6 agent-hours
- **Owned files (13):** `Sources/FolioModel/Live/LiveTextFinding.swift`, `Sources/FolioModel/Fakes/FakeTextFinding.swift`, `Sources/FolioModel/Workspace/FolioWorkspace+Find.swift`, `Sources/FolioModel/Availability/FolioAvailability+Find.swift`, `Sources/FolioApp/FolioWindow+Find.swift`, `Sources/FolioApp/FolioCommands+Find.swift`, `Sources/FolioApp/PageView/FolioFindBar.swift`, `Sources/FolioApp/Sidebar/FolioFindResults.swift`, `Tests/FolioModelTests/TextFindingContractTests.swift`, `Tests/FolioModelTests/FolioFindTests.swift`, `Tests/FolioModelTests/FolioFindBudgetTests.swift`, `Tests/AppSnapshotTests/FolioFindSnapshots.swift`, `UITests/FolioJourneyTests+Find.swift`

#### W1 · `markup`: Mark up: select text, highlight, underline, strike out, notes, text boxes, pen, shapes

- **Covers:** P-T5, P-T7, P-T8, P-T9, P-T10
- **Waits on:** foundation
- **Proves:** P-J3, P-J4; PB-6, PB-7, PB-8, PB-9, PB-10
- **Estimate:** about 9 PRs, 15 agent-hours
- **Owned files (25):** `Sources/FolioModel/Live/LiveTextSelecting.swift`, `Sources/FolioModel/Live/LiveAnnotating.swift`, `Sources/FolioModel/Fakes/FakeTextSelecting.swift`, `Sources/FolioModel/Fakes/FakeAnnotating.swift`, `Sources/FolioModel/Workspace/FolioWorkspace+Markup.swift`, `Sources/FolioModel/Availability/FolioAvailability+Markup.swift`, `Sources/FolioModel/Tools/FolioTool+Select.swift`, `Sources/FolioModel/Tools/FolioTool+TextMarkup.swift`, `Sources/FolioModel/Tools/FolioTool+Annotate.swift`, `Sources/FolioApp/FolioWindow+Markup.swift`, `Sources/FolioApp/FolioCommands+Markup.swift`, `Sources/FolioApp/PageView/FolioMarksLayer.swift`, `Sources/FolioApp/PageView/FolioSelectionLayer.swift`, `Sources/FolioApp/PageView/FolioPageGestures.swift`, `Sources/FolioApp/Inspector/FolioMarkInspector.swift`, `Sources/FolioApp/Sidebar/FolioMarksList.swift`, `Sources/FolioApp/Live/PDFKitAnnotations.swift`, `Tests/FolioModelTests/TextSelectingContractTests.swift`, `Tests/FolioModelTests/AnnotatingContractTests.swift`, `Tests/FolioModelTests/FolioMarkupTests.swift`, `Tests/FolioModelTests/FolioToolsTests.swift`, `Tests/FolioModelTests/FolioMarkupBudgetTests.swift`, `Tests/AppSnapshotTests/FolioMarkupSnapshots.swift`, `UITests/FolioJourneyTests+Markup.swift`, `UITests/FolioJourneyTests+Annotate.swift`

#### W1 · `forms`: Fill forms: fields over the page, Tab order, required fields, clear

- **Covers:** P-T11, P-T12
- **Waits on:** foundation
- **Proves:** P-J5; PB-11; PL8
- **Estimate:** about 6 PRs, 10 agent-hours
- **Owned files (15):** `Sources/FolioModel/Live/LiveFormFilling.swift`, `Sources/FolioModel/Fakes/FakeFormFilling.swift`, `Sources/FolioModel/Workspace/FolioWorkspace+Forms.swift`, `Sources/FolioModel/Availability/FolioAvailability+Forms.swift`, `Sources/FolioApp/FolioWindow+Forms.swift`, `Sources/FolioApp/FolioCommands+Forms.swift`, `Sources/FolioApp/PageView/FolioFieldLayer.swift`, `Sources/FolioApp/Inspector/FolioFieldInspector.swift`, `Sources/FolioApp/Live/PDFKitFields.swift`, `Tests/FolioModelTests/FormFillingContractTests.swift`, `Tests/FolioModelTests/FolioFormsTests.swift`, `Tests/FolioModelTests/FolioFormsBudgetTests.swift`, `Tests/AppSnapshotTests/FolioFormsSnapshots.swift`, `Tests/AppSnapshotTests/FolioFieldOverlayTests.swift`, `UITests/FolioJourneyTests+Forms.swift`

#### W1 · `pages`: Organize pages: thumbnails, grid, reorder, rotate, delete, insert, combine, extract, split

- **Covers:** P-T3 (thumbnails), P-T13, P-T14, P-T15, P-T16
- **Waits on:** foundation
- **Proves:** P-J7, P-J8; PB-13; PL6, PL7; PF-7
- **Estimate:** about 8 PRs, 13 agent-hours
- **Owned files (19):** `Sources/FolioModel/Live/LivePageOrganizing.swift`, `Sources/FolioModel/Fakes/FakePageOrganizing.swift`, `Sources/FolioModel/Workspace/FolioWorkspace+Pages.swift`, `Sources/FolioModel/Availability/FolioAvailability+Pages.swift`, `Sources/FolioApp/FolioWindow+Pages.swift`, `Sources/FolioApp/FolioCommands+Pages.swift`, `Sources/FolioApp/Sidebar/FolioThumbnails.swift`, `Sources/FolioApp/PageGrid/FolioPageGrid.swift`, `Sources/FolioApp/Sheets/FolioExtractSheet.swift`, `Sources/FolioApp/Sheets/FolioInsertSheet.swift`, `Sources/FolioApp/Sheets/FolioCombineSheet.swift`, `Sources/FolioApp/Sheets/FolioCropSheet.swift`, `Tests/FolioModelTests/PageOrganizingContractTests.swift`, `Tests/FolioModelTests/FolioPagesTests.swift`, `Tests/FolioModelTests/FolioPagesBudgetTests.swift`, `Tests/AppSnapshotTests/FolioPagesSnapshots.swift`, `Tests/AppSnapshotTests/FolioThumbnailLayoutTests.swift`, `UITests/FolioJourneyTests+Pages.swift`, `UITests/FolioJourneyTests+Combine.swift`

#### W1 · `history-files`: Undo, redo, save, save as, flatten, passwords

- **Covers:** P-T17, P-T18, P-T20, P-T26
- **Waits on:** foundation
- **Proves:** P-J9, P-J10; PB-14, PB-15; PF-3, PF-5, PF-6
- **Estimate:** about 7 PRs, 12 agent-hours
- **Owned files (24):** `Sources/FolioModel/Live/LiveDocumentHistory.swift`, `Sources/FolioModel/Fakes/FakeDocumentHistory.swift`, `Sources/FolioApp/Live/PDFKitWriting.swift`, `Sources/FolioModel/Workspace/FolioWorkspace+History.swift`, `Sources/FolioModel/Workspace/FolioWorkspace+Files.swift`, `Sources/FolioModel/Availability/FolioAvailability+History.swift`, `Sources/FolioModel/Availability/FolioAvailability+Files.swift`, `Sources/FolioApp/FolioWindow+History.swift`, `Sources/FolioApp/FolioWindow+Files.swift`, `Sources/FolioApp/FolioCommands+History.swift`, `Sources/FolioApp/FolioCommands+Files.swift`, `Sources/FolioApp/Sheets/FolioSaveOptionsSheet.swift`, `Sources/FolioApp/Inspector/FolioDocumentInspector.swift`, `Tests/FolioModelTests/DocumentHistoryContractTests.swift`, `Tests/FolioModelTests/DocumentWritingContractTests.swift`, `Tests/FolioModelTests/FolioHistoryTests.swift`, `Tests/FolioModelTests/FolioFilesTests.swift`, `Tests/FolioModelTests/FolioFilesBudgetTests.swift`, `Tests/AppSnapshotTests/FolioRoundTripTests.swift`, `Tests/AppSnapshotTests/FolioFlattenTests.swift`, `Tests/AppSnapshotTests/FolioPasswordTests.swift`, `Tests/AppSnapshotTests/FolioWritingBudgetTests.swift`, `UITests/FolioJourneyTests+History.swift`, `UITests/FolioJourneyTests+Files.swift`

#### W2 · `sign`: Sign: draw, type or pick a signature and initials; keep them; place them

- **Covers:** P-T21
- **Waits on:** markup, forms
- **Proves:** P-J6; PB-12; PF-12
- **Estimate:** about 6 PRs, 10 agent-hours
- **Owned files (20):** `Sources/FolioModel/Live/LiveSigning.swift`, `Sources/FolioModel/Live/LiveSignatureStore.swift`, `Sources/FolioModel/Fakes/FakeSigning.swift`, `Sources/FolioModel/Fakes/FakeSignatureStore.swift`, `Sources/FolioModel/Workspace/FolioWorkspace+Sign.swift`, `Sources/FolioModel/Availability/FolioAvailability+Sign.swift`, `Sources/FolioModel/Tools/FolioTool+Sign.swift`, `Sources/FolioApp/FolioWindow+Sign.swift`, `Sources/FolioApp/FolioCommands+Sign.swift`, `Sources/FolioApp/Sheets/FolioSignatureSheet.swift`, `Sources/FolioApp/PageView/FolioSignaturePopover.swift`, `Sources/FolioApp/Live/FolioSignatureMark.swift`, `Tests/FolioModelTests/SigningContractTests.swift`, `Tests/FolioModelTests/SignatureStoringContractTests.swift`, `Tests/FolioModelTests/FolioSignTests.swift`, `Tests/FolioModelTests/FolioToolsTests.swift`, `Tests/FolioModelTests/FolioSignBudgetTests.swift`, `Tests/AppSnapshotTests/FolioSignSnapshots.swift`, `Tests/AppSnapshotTests/FolioSignatureRoundTripTests.swift`, `UITests/FolioJourneyTests+Sign.swift`

#### W2 · `export-convert`: Export pages and text, new from images, reduce size, print

- **Covers:** P-T4, P-T22, P-T23, P-T24, P-T25
- **Waits on:** history-files, markup
- **Proves:** P-J21, P-J22, P-J23, P-J24; PF-4, PF-10, PF-11
- **Estimate:** about 7 PRs, 12 agent-hours
- **Owned files (18):** `Sources/FolioApp/Live/PDFKitExporting.swift`, `Sources/FolioApp/Live/PDFKitImageOpening.swift`, `Sources/FolioModel/Workspace/FolioWorkspace+Export.swift`, `Sources/FolioModel/Availability/FolioAvailability+Export.swift`, `Sources/FolioApp/FolioWindow+Export.swift`, `Sources/FolioApp/FolioCommands+Export.swift`, `Sources/FolioApp/Sheets/FolioExportSheet.swift`, `Sources/FolioApp/Sheets/FolioReduceSheet.swift`, `Sources/FolioApp/FolioPrinting.swift`, `Tests/FolioModelTests/PageExportingContractTests.swift`, `Tests/FolioModelTests/FolioExportTests.swift`, `Tests/AppSnapshotTests/FolioExportTests.swift`, `Tests/AppSnapshotTests/FolioReduceSizeTests.swift`, `Tests/AppSnapshotTests/FolioMarksFidelityTests.swift`, `UITests/FolioJourneyTests+Export.swift`, `UITests/FolioJourneyTests+Images.swift`, `UITests/FolioJourneyTests+Reduce.swift`, `UITests/FolioJourneyTests+Print.swift`

#### W2 · `ocr`: Recognize text on scans and keep it as a text layer

- **Covers:** P-T27
- **Waits on:** reader, find, history-files
- **Proves:** P-J20; PB-16; PF-8, PF-9
- **Estimate:** about 5 PRs, 8 agent-hours
- **Owned files (12):** `Sources/FolioApp/Live/VisionRecognizing.swift`, `Sources/FolioModel/Workspace/FolioWorkspace+OCR.swift`, `Sources/FolioModel/Availability/FolioAvailability+OCR.swift`, `Sources/FolioApp/FolioWindow+OCR.swift`, `Sources/FolioApp/FolioCommands+OCR.swift`, `Sources/FolioApp/Sheets/FolioRecognizeSheet.swift`, `Tests/FolioModelTests/TextRecognizingContractTests.swift`, `Tests/FolioModelTests/FolioOCRTests.swift`, `Tests/AppSnapshotTests/FolioOCRFidelityTests.swift`, `Tests/AppSnapshotTests/FolioOCRRoundTripTests.swift`, `Tests/AppSnapshotTests/FolioOCRBudgetTests.swift`, `UITests/FolioJourneyTests+OCR.swift`

#### W3 · `core-loop`: The core loop, live, measured

- **Covers:** every tier-1 row on live services
- **Waits on:** reader, find, markup, forms, pages, history-files, sign, export-convert, ocr
- **Proves:** P-J14, P-J12 (final), P-J13 (final), P-P1-P-P6
- **Estimate:** about 4 PRs, 6 agent-hours
- **Owned files (5):** `UITests/FolioJourneyTests+Loop.swift`, `UITests/FolioJourneyTests+Perf.swift`, `UITests/FolioJourneyTests.swift`, `Tests/FolioModelTests/FolioLoopTests.swift`, `docs/blueprints/pdf.md`

#### W4 · `content-edit`: Conditional: edit existing text in place, and true redaction (needs CorePDF CP-1 to CP-5)

- **Covers:** P-T28, P-T29
- **Waits on:** core-loop
- **Proves:** P-J25, P-J26; PF-13
- **Estimate:** about 8 PRs, 16 agent-hours
- **Owned files (17):** `Sources/FolioModel/Contracts/FolioContentEditContracts.swift`, `Sources/FolioModel/Fakes/FakeTextReplacing.swift`, `Sources/FolioModel/Fakes/FakeRedacting.swift`, `Sources/FolioModel/Live/LiveTextReplacing.swift`, `Sources/FolioModel/Live/LiveRedacting.swift`, `Sources/FolioModel/Workspace/FolioWorkspace+ContentEdit.swift`, `Sources/FolioModel/Availability/FolioAvailability+ContentEdit.swift`, `Sources/FolioModel/Tools/FolioTool+ContentEdit.swift`, `Sources/FolioApp/FolioWindow+ContentEdit.swift`, `Sources/FolioApp/FolioCommands+ContentEdit.swift`, `Sources/FolioApp/PageView/FolioRedactionLayer.swift`, `Sources/FolioApp/Sheets/FolioApplyRedactionSheet.swift`, `Tests/FolioModelTests/TextReplacingContractTests.swift`, `Tests/FolioModelTests/RedactingContractTests.swift`, `Tests/AppSnapshotTests/FolioRedactionTests.swift`, `UITests/FolioJourneyTests+ContentEdit.swift`, `Package.swift`

### 9.3 creative-core work

The six `CorePDF` items of section 4.4. None blocks v1's W0 to W3. CP-1 to
CP-5 gate the conditional W4 feature; CP-6 is for certificate signing
(Later). Each is "needs a new core issue": one issue per item on
qbtrix/creative-core, labelled `needs-core`, filed after the captain
approves, with the acceptance line from 4.4.

### 9.4 Protected paths (supervisor merges)

W0's first task touches files the fast lane refuses (CLAUDE.md, Parallel
agents), so it is a supervisor-merged PR, not a fast-lane one:

- `Package.swift`: `"Folio"` added to `apps` and `model("Folio", [])`
  (FolioModel with no engine; `AppSnapshotTests` gains FolioApp and
  FolioModel through the existing `apps` map).
- `project.yml`: the `FolioJourneyTests` bundle globbing
  `UITests/FolioJourneyTests*.swift` in the `Journeys` scheme.
- `scripts/bundle-apps`: Folio's bundle and Info.plist (PDF as an
  Editor of rank Alternate, `UTType.pdf`, Apple docs: UTType.pdf),
  or, once the suite's packaging lands, Folio as the sixth embedded app.
- `UITests/audit-baseline.json`: `folio` at 0 for every check (a new app at
  0 is not a loosening; section 8.2).

W4 also edits `Package.swift` (FolioModel gains the `CorePDF` product).

### 9.5 What Folio needs from other lines

| Line | Need | Filed by | Until it lands |
|---|---|---|---|
| `line:suite` | `SuiteApp.folio` in `SuiteModel` (identity, bundle id, glyph `doc.richtext`, ⌃⌘6), PDF in `SuiteTypeRegistry` (Folio: Editor, Alternate), `SwitchMenu` and `SwitcherEntries` with seven items | foundation (an issue on the suite line) | Folio runs standalone; its switcher row shows the suite's six items disabled with their reason, plus nothing for Folio |
| `line:suite` | Hand-offs: Library "Make PDF from Selection" and Photo "Open In ▸ Folio" (images in), Folio "Open In ▸ Photo" (a page out at 300 ppi), Design's PDF export "Open In ▸ Folio" | export-convert (issues on the suite, Library, Photo and Design lines) | File > New from Images and Export cover the same work by hand |
| `line:suiteui` | `AppSwitcher` seventh item | foundation (`needs-ui`) | the six-item row |
| `line:suiteui` | `ThumbnailGrid`: page caption, multi-select, drag reorder with a drop line, keyboard reorder | pages (`needs-ui`) | a plain `LazyVGrid` placeholder in `FolioPageGrid.swift` with the same identifiers |
| `line:suiteui` | A signature pad (flat drawing well with Clear) | sign (`needs-ui`) | a SwiftUI `Canvas` placeholder in `FolioSignatureSheet.swift` |
| `line:suiteui` | `ViewerStatusBar` trailing button pill | ocr (`needs-ui`) | the menu item and the inspector row |
| `line:suiteui` | editor-in-window (#973): sidebar slot, window subtitle, `EditorDetail`, `AppSwitcher` | – (in flight) | `SuiteWindow` as on `dev`; the subtitle shows as the title's suffix |

---

## 10. Decisions and questions for the captain

### 10.1 Calls this blueprint makes (overrule any of them)

1. **Name: Folio** (section 0), with Page and Quill as the alternatives.
2. **The document is a value; PDFKit is a service** (section 4). Undo,
   tests and journeys run on Linux; PDFKit reads and writes at the edges.
3. **Folio follows the system appearance** like Library: it is a reading app,
   and pages are white paper.
4. **Tier 1 includes New from Images and Reduce File Size** because the
   numbers put them in the top five (1.1 rows 4 and 5), although they are
   one-off actions.
5. **Word-processing export is text only** (no layout), named so in the
   sheet; spreadsheet and slide exports are Later.
6. **OCR is in v1** (Vision is on device and cheap); **compare is Later**;
   **reflow is not planned**.
7. **Redaction and in-place text editing are conditional (W4) and never
   faked**: no black box over live text ships under the name "Redact".
8. **Drawn and typed signatures are v1; certificate signatures are Later**
   (CP-6 plus the Security framework).
9. **Saving never touches the original until the write succeeds**, and
   Reduce File Size and Extract always write new files.
10. **One window per document** (`WindowGroup`, like Halo), no tabs in v1.

### 10.2 Questions

- **Q1 Name.** Folio, Page or Quill? Whichever is picked needs a trademark
  check before the first public build.
- **Q2 Line.** Approve a new line `line:folio` (labels `line:folio`,
  `gap`), and the W0 supervisor task on `Package.swift`, `project.yml`,
  `scripts/bundle-apps` and the audit baseline?
- **Q3 Default app.** Should Folio ever offer to become the default PDF app
  (a one-time prompt in onboarding), or only declare itself an Alternate
  and leave the choice to Finder's Get Info?
- **Q4 Architecture.** Confirm the value-document design (section 4) over
  driving `PDFView` and its annotation objects directly.
- **Q5 Engine.** Approve filing CP-1 to CP-6 on creative-core now (none
  blocks v1), and whether W4 content-edit holds the v1 release or ships as
  v1.1 if CorePDF isn't ready when W3 ends.
- **Q6 Word-processing export.** Ship it in v1 as text-and-paragraphs only,
  or hold it until layout-aware export (Vision's document structure,
  macOS 26) can keep tables?
- **Q7 Scripted forms.** Folio detects and names scripts and XFA but never
  runs them. Acceptable, or should the scripted-form banner also refuse to
  save such forms?
- **Q8 Suite slot.** Folio becomes the sixth app in AfterGlow (⌃⌘6, after
  Halo). Confirm the order and the glyph.
