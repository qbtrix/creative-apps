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

Contents: 0 Working name · 1 Research · 1A Pain points we fix · 1B Features
from the future · 2 Brief · 3 Feature catalog ·
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
signals; row 15 (find) has no number of its own and is placed by inference. "Q&A" is one network of public question sites (general computing,
Linux, Mac, Unix): the 2,281 top-voted PDF questions, 58.8M views in all.
"Site A" and "site B" are web PDF tool sites that show a vote count on each
tool page, a stand-in for use (newer tools have had less time to collect
votes). "The vendor" is a web PDF service that published its own usage
split (May 2025). Search numbers are US monthly volumes.

| # | Task | Usage signal | Source |
|---|---|---|---|
| 1 | Read: open, scroll, zoom, page layout | largest Q&A group, 11.8% of 58.8M views; "pdf reader" 33,100/mo | https://www.seodata.dev/keyword/pdf-reader ; https://api.stackexchange.com/2.3/questions?site=superuser&tagged=pdf&sort=votes |
| 2 | Convert to a word-processing, spreadsheet or slide format | 246,000/mo for the word-processing variant; site A's #1 tool, 1,613,986 votes; 16% of the vendor's activity | https://www.seodata.dev/keyword/pdf-to-word ; https://pdfcandy.com/pdf-to-word.html ; https://smallpdf.com/pdf-statistics |
| 3 | Merge several PDFs into one | "pdf merger" 201,000, "merge pdf" 135,000, "combine pdf" 135,000; site A 704,085; one Q&A question 785K views | https://www.seodata.dev/keyword/merge-pdf ; https://pdfcandy.com/merge-pdf.html ; https://askubuntu.com/questions/2799 |
| 4 | Make a PDF from images or scans | "jpg to pdf" 201,000; site A 450,724; the Mac Q&A site's most-viewed PDF question, 1,502,667 views | https://www.seodata.dev/keyword/jpg-to-pdf ; https://apple.stackexchange.com/questions/11163 |
| 5 | Reduce file size | the vendor's top tool, 34% of activity; "compress pdf" 110,000; one Q&A question 1,049,735 views | https://smallpdf.com/pdf-statistics ; https://www.seodata.dev/keyword/compress-pdf ; https://askubuntu.com/questions/113544 |
| 6 | Mark up: highlight, notes, comments, drawing | second-largest Q&A group, 8.9% of views (246 questions); one question 307K views | https://askubuntu.com/questions/1529 |
| 7 | Sign with a drawn, typed or picture signature | the vendor's #2, 19% of activity; 64% of surveyed finance professionals sign about 15 times a month (a vendor survey seen in search snippets only: medium); "sign pdf" 22,200; one Q&A question 231K | https://smallpdf.com/pdf-statistics ; https://business.adobe.com/blog/financial-professionals-love-to-edit-sign-convert-with-pdfs ; https://www.seodata.dev/keyword/sign-pdf ; https://unix.stackexchange.com/questions/85873 |
| 8 | Fill in forms | "fill pdf" 74,000, "pdf filler" 74,000; one Q&A question 248K; 57 👍 in a web toolbox's tracker | https://www.seodata.dev/keyword/fill-pdf ; https://askubuntu.com/questions/29230 ; https://github.com/Stirling-Tools/Stirling-PDF/issues/320 |
| 9 | Split or extract a page range | "split pdf" 40,500; site A 226,452; one Q&A question 793K | https://www.seodata.dev/keyword/split-pdf ; https://askubuntu.com/questions/221962 |
| 10 | Rotate pages and keep the rotation | the general-computing Q&A site's most-viewed PDF question, 705K; 66 👍 in a notes app's tracker | https://superuser.com/questions/145696 ; https://github.com/xournalpp/xournalpp/issues/1883 |
| 11 | Delete, reorder, insert pages | "delete pages from pdf" 33,100; site A rearrange 64,169, delete 49,407 | https://www.seodata.dev/keyword/delete-pages-from-pdf ; https://pdfcandy.com/rearrange-pdf.html |
| 12 | Add text, fill blanks ("edit a PDF" in general) | "pdf editor" 246,000, "edit pdf" 90,500; site A 278,175 for its general editor against 464 for its in-place text editor | https://www.seodata.dev/keyword/edit-pdf ; https://pdfcandy.com/edit-pdf.html ; https://pdfcandy.com/edit-pdf-text.html |
| 13 | Copy or extract text | Q&A questions on copying text: 462K and 399K views; "pdf to text" 12,100 | https://superuser.com/questions/47462 ; https://superuser.com/questions/198392 |
| 14 | Export pages as images | "pdf to jpg" 165,000; site A 156,024; one Q&A question 466K | https://www.seodata.dev/keyword/pdf-to-jpg ; https://askubuntu.com/questions/50170 |
| 15 | Find text in a document | no search or Q&A number of its own (every viewer has it); "highlight every match" 34 CC and "keyboard text selection" 19 👍 on viewers' trackers; placed here by inference, as a reading staple | https://bugs.kde.org/show_bug.cgi?id=377487 ; https://github.com/pwmt/zathura/issues/748 |
| 16 | Remove or add a password | one Q&A question on removing protection 582K; "unlock pdf" 14,800, "password protect pdf" 8,100 | https://superuser.com/questions/179064 ; https://www.seodata.dev/keyword/unlock-pdf |
| 17 | Print (scaling, booklet, pages per sheet) | 4.6% of Q&A views; booklet 96K, four-up 63K on the Mac Q&A site | https://superuser.com/questions/205943 ; https://apple.stackexchange.com/questions/3832 |
| 18 | Make a PDF from office files or print to PDF | 110,000/mo; site A 288,131 | https://www.seodata.dev/keyword/word-to-pdf ; https://pdfcandy.com/word-to-pdf.html |
| 19 | Crop or change page size | "crop pdf" 9,900; site A 50,461 | https://www.seodata.dev/keyword/crop-pdf ; https://pdfcandy.com/crop-pdf.html |
| 20 | Make scans searchable (OCR) | about 12,200/mo across variants; site A 38,447; 1.1% of Q&A views; hidden inside "can't copy text" (462K) | https://www.seodata.dev/keyword/ocr-pdf ; https://pdfcandy.com/pdf-ocr.html |
| 21 | Certificate (digital) signatures, and checking them | 142 👍 and 26 👍 in a browser viewer's tracker; 22 upvotes in a desktop viewer's | https://github.com/mozilla/pdf.js/issues/1076 ; https://github.com/mozilla/pdf.js/issues/13351 ; https://gitlab.gnome.org/GNOME/evince/-/work_items/143 |
| 22 | Redact | "redact pdf" 5,400; the Mac Q&A site's #2 most-viewed PDF question, 490,831 views; a forum thread on bad redactions, 709 points | https://www.seodata.dev/keyword/redact-pdf ; https://apple.stackexchange.com/questions/22683 ; https://news.ycombinator.com/item?id=46369923 |
| 23 | Edit existing text in place | "edit pdf text" 8,100; 46 👍 in a web toolbox's tracker; the first complaint in two forum threads | https://www.seodata.dev/keyword/edit-pdf ; https://github.com/Stirling-Tools/Stirling-PDF/issues/1141 ; https://news.ycombinator.com/item?id=43880962 |
| 24 | Flatten | "flatten pdf" 6,600 | https://www.seodata.dev/keyword/flatten-pdf |
| 25 | Compare two versions | "pdf compare" 5,400; one Q&A question 485,773; 4 👍 in a web toolbox's tracker | https://www.seodata.dev/keyword/pdf-compare ; https://superuser.com/questions/46123 ; https://github.com/Stirling-Tools/Stirling-PDF/issues/1290 |
| 26 | Translate, summarize, ask questions | "translate pdf" 14,800, "summarize pdf" 2,400 | https://www.seodata.dev/keyword/translate-pdf |
| 27 | Read aloud | "read pdf aloud" 4,400 | https://www.seodata.dev/keyword/read-pdf-aloud |
| 28 | Stamps: page numbers, Bates numbers, watermark | page numbers 2,900/mo, Bates numbers 2,900/mo | https://www.seodata.dev/keyword/add-page-numbers-to-pdf ; https://www.seodata.dev/keyword/bates-numbering |
| 29 | Change the document's title and author | 151,099 views on the Mac Q&A site | https://apple.stackexchange.com/questions/274703 |
| 30 | Outline (bookmarks): read, then edit | 9 👍 for outline editing in a CLI's tracker | https://github.com/qpdf/qpdf/issues/343 |
| 31 | Dark or inverted reading | 37 👍 in a browser viewer's tracker | https://github.com/mozilla/pdf.js/issues/2071 |
| 32 | Tabs and split view | 41 CC and 29 CC on a desktop viewer's wishlist (its top items) | https://bugs.kde.org/show_bug.cgi?id=169847 ; https://bugs.kde.org/show_bug.cgi?id=339971 |
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
| OCR | Moderate direct demand (12,200/mo, site A 38,447), large hidden demand (copying text from scans, converting scans), a named Mac gap, a 35k-star CLI people praise | Low: Vision recognizes text on device (Apple docs: RecognizeTextRequest); Folio writes the result as an invisible text layer itself (Apple docs: CGTextDrawingMode.invisible), not through the docs-silent `saveTextFromOCROption` | **v1, tier 2** (wave 2) |
| Redaction | Low search (5,400) but the Mac Q&A site's #2 PDF question (491K) and loud forum demand; the harm of a fake redaction is high | High: PDFKit has a redact markup style but nothing that removes content (Apple docs: PDFMarkupType.redact) | **v1 only if creative-core CP-1 to CP-4 land** (wave 4, conditional); never a draw-a-box stand-in |
| Compare two versions | Low search (5,400), one 486K-view question, 4 👍; the neighbour (split view) is wanted | Medium: a text diff over page text (pure Swift) plus a two-pane view | **Later (tier 3)** |
| Full text reflow | Not asked: no request found for paragraph reflow; people ask for in-place edits that keep the font, and the 464-vote in-place editor next to a 278K-vote general editor says most "edit" means add text, fill, sign, rearrange | Very high: fixed glyph positions and subset fonts | **Not planned.** In-place editing of one line is **v1 only if CP-1 to CP-3 and CP-5 land** (wave 4, conditional) |

### 1.5 What the platform gives and what must be built

PDFKit and Vision cover the tier-1 loop (research.md E): display, page
pictures, page text with character boxes, the standard annotation kinds,
form widgets, page insert, remove and exchange, rotation, outline, find,
unlocking and saving with passwords and permissions, flatten
(`burnInAnnotationsOption`), two boolean image options (optimize images for
screen, save images as JPEG), printing, and OCR. There is no documented way
to down-sample a PDF's images to a chosen resolution, so v1's Reduce File
Size is one level built on those two options and measured (PF-11); levels
by resolution need CorePDF image re-encoding (CP-7, section 4.4).
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

## 1A. Pain points we fix

Public complaints about today's PDF tools, mined on 2026-10-15 from review
sites, the platform's support forum and other vendors' community forums,
public Q&A sites, a tech news forum, open-source issue trackers and
feature-request lists. Raw notes, with every number and URL, are in
`docs/blueprints/pdf/research.md` section F.

**How they are ranked.** Frequency (how many independent sources raise the
same complaint) times loudness (views, forum points and comments, "me too"
counts, reactions, share of 1-star reviews). The units don't compare across
sources, so the rank is a judgement over the numbers, not a sum. The table
gives each row's strongest numbers and one or two URLs; research.md F has
the rest.

**How each maps.** "Fixed in v1" names the feature, decision or test that
fixes it; "partly" says what is left; "v1 does not" says so plainly, with
where it goes.

| # | Pain point | How often, how loud | Source | What fixes it | v1? |
|---|---|---|---|---|---|
| 1 | Subscription lock-in: early-cancellation fees, "free" tools that charge at download, a cheap trial that turns into a yearly charge | a leading vendor's review page: 7,534 reviews, 91% one-star, cancellation fees in 5 of 24 visible reviews; a forum thread on it: 817 points, 587 comments; a converter site with 40 billing complaints in 3 years | https://www.trustpilot.com/review/www.adobe.com ; https://news.ycombinator.com/item?id=26786563 ; https://www.bbb.org/us/nd/fargo/profile/tech-support/files-editor-0704-1000077989/complaints | Folio is free and open source, inside AfterGlow: no account, no subscription, no per-file charge, no feature behind a paywall (2.1; 10.1 call 11) | Fixed in v1 |
| 2 | Marks disappear after a save, or are invisible or wrong in another reader | the platform forum: 366 "me too" on one thread; "annotations filled in appear blank to other users": 41,232 views; the most-reacted issue of an open-source reader asks for annotations other readers can see | https://discussions.apple.com/thread/253093013 ; https://apple.stackexchange.com/questions/68446 | Folio writes only the standard annotation kinds and widget values (P-T7 to P-T10, P-T11) and gives every mark an appearance stream so any reader draws it (Apple docs: PDFAnnotation.hasAppearanceStream); PF-3 round-trips every mark; PF-15 checks the appearance streams | Fixed in v1 |
| 3 | The built-in viewer damages files on save: adds a password nobody asked for, breaks the text layer so copy and search turn to gibberish, grows the file | password on save: 191 and 46 "me too" on two threads, 62,045 views on Q&A; garbled text after save: 39 "me too"; "file size increases when saving": 29,941 views | https://discussions.apple.com/thread/253601818 ; https://apple.stackexchange.com/questions/436596 ; https://apple.stackexchange.com/questions/76474 | A password is written only when the person sets one (`FolioWriteOptions`); the original isn't touched until a save succeeds (P-T18); PF-16 saves every fixture with no edits and checks no password appears, every page's text is unchanged and the file grows by at most 10%; incremental save (CP-2) later keeps the original bytes entirely | Fixed in v1 (incremental save Later) |
| 4 | Can't change the existing text; edits swap in the wrong font | a vendor forum thread on "font not available for editing": 237,142 views; "free software to edit PDF on Mac": 56,108 views; the second most-reacted issue of a web toolbox | https://community.adobe.com/questions-9/font-not-available-or-can-t-be-used-in-editing-1245210/index1.html ; https://apple.stackexchange.com/questions/16226 | Editing one line in place that keeps its font, saying which characters the embedded font lacks (P-T28, CP-1 to CP-3, CP-5) | v1 does not, unless W4 lands (conditional); v1 adds text boxes (P-T9) |
| 5 | Fake redaction: black boxes over text that can still be copied | forum threads: 1,029 points / 780 comments, 709 / 122, 529 / 716; the Mac Q&A site's question on redaction: 490,832 views | https://news.ycombinator.com/item?id=46368946 ; https://apple.stackexchange.com/questions/22683 | True removal with a verification pass after saving (P-T29, CP-4, PF-13); Folio never ships a box drawn over live text called "Redact" (10.1 call 7) | v1 does not, unless W4 lands; never faked |
| 6 | Slow, bloated, hangs on big files | forum threads: 193 / 172 ("intrusive, slow"), 190 / 137 (installer size); "scrolls so slowly": 86,295 views; "Mac unresponsive opening complex PDF": 9,955 views | https://news.ycombinator.com/item?id=45598776 ; https://superuser.com/questions/257881 | A native app on the platform's own PDF engine; only visible pages draw; budgets with tests: progress within 100 ms and first page within 300 ms on 500 pages, scrolling at display rate (PB-1 to PB-4, PB-17, P-P1, P-P2) | Fixed in v1 |
| 7 | Forms won't fill or save, filled fields show blank elsewhere, scripted forms stuck on "Please wait…" | a vendor forum thread on "Please wait…": 44,297 views; the platform forum: 39 and 24 "me too"; "doesn't save form data": 12,295 views; a web toolbox's most-reacted issue is form filling | https://apple.stackexchange.com/questions/87528 ; https://discussions.apple.com/thread/3255797 | Standard form fields filled with Tab order and required checks, values written so other readers show them (P-T11, P-T12, PF-3); scripted and XFA forms detected and named, never run (P-T1) | Partly: standard forms fixed; XFA forms v1 does not (none planned, Q7) |
| 8 | Having to upload private documents to web tools | forum threads on local-only PDF tools: 791 / 182, 522 / 185 ("office networks block the upload sites"), 507 / 231; a tracking-pixel complaint in an open-source toolbox | https://news.ycombinator.com/item?id=43880962 ; https://news.ycombinator.com/item?id=37110628 | Everything happens on the Mac: no network calls in Folio, OCR on device (P-T27), future AI on device only (F1) | Fixed in v1 |
| 9 | Copied text comes out garbled: broken lines, ligatures, hyphens, columns | "Can't copy text from a PDF": 461,920 views; "copy without losing formatting": 398,921; "garbled text when copy-pasting": 234,023; forum threads on why text extraction is hard: 733 / 342 | https://superuser.com/questions/47462 ; https://superuser.com/questions/137824 | Copy joins lines inside a paragraph, spells ligatures out and drops soft hyphens (`TextSelecting.copyText`, proof test; P-T5); scans get text from OCR (P-T27) | Partly: multi-column reading order v1 does not (F2's structure later) |
| 10 | No dark or night reading mode; eye strain | a vendor forum thread on night mode: 279,436 views; "adjust PDF contrast": 394,273; the Mac Q&A site: 132,875 | https://superuser.com/questions/117521 ; https://apple.stackexchange.com/questions/317845 | Dark and inverted reading (P-T32) | v1 does not (Later, tier 3) |
| 11 | Interface overhauls, AI pop-ups and upgrade nags that can't be turned off | a vendor forum thread on reverting the new interface: 164,081 views; "turn off the AI assistant box": 17,336 views; "disable the upgrade prompt" is an open-source toolbox's third most-reacted issue | https://community.adobe.com/questions-9/acrobat-2023-how-to-revert-to-classic-gui-user-interface-1285215 ; https://community.adobe.com/questions-12/how-to-turn-off-ask-ai-assistant-box-at-bottom-of-window-1505991/index1.html | No upsell anywhere; no assistant panel; future AI features (F1) appear only when the person invokes them from a menu; the window follows the suite's one shell, which changes only with the captain (10.1 call 11) | Fixed in v1 |
| 12 | Signatures don't move between Macs, can't be imported or exported, look pixelated; no certificate signing | "export my signature to another Mac": 185,125 views; "extract an image of my signature": 51,569; "import signature from image": 18,590; certificate signatures: a browser viewer's most-reacted issue | https://apple.stackexchange.com/questions/74950 ; https://apple.stackexchange.com/questions/348011 ; https://github.com/mozilla/pdf.js/issues/1076 | Drawn signatures kept as vector strokes, typed ones as text, pictures trimmed (P-T21, `Signing.make(picture:)`); Signatures > Export… and Import… write and read the library as one file (P-T21); certificate signatures (P-T31, CP-6) | Partly: portable library fixed; certificate signing Later |
| 13 | Password and permission confusion: an owner password blocks marking up, a known password can't be removed | "remove a usage restriction": 219,318 views; "removing the password": 61,340; "without the owner password you do not have permission to annotate": 32,986 | https://superuser.com/questions/616844 ; https://apple.stackexchange.com/questions/441130 | Messages that name which password is needed and why ("The owner of this PDF doesn't allow…"; "Changing this PDF's restrictions needs its owner password…"); removing an open password you know is one Save As (P-T20, PF-6) | Partly: lifting owner restrictions without the owner password v1 does not, by design |
| 14 | Compression doesn't shrink the file, or makes it worse or blurry | "decrease PDF size without losing quality": 113,529 views; "compress with adjustable ratio": 34,248; vendor forum threads on files that grew after compressing | https://apple.stackexchange.com/questions/297417 ; https://apple.stackexchange.com/questions/33702 | Reduce File Size shows the measured result before keeping it, never writes a larger file, never overwrites the original (P-T22, PF-11) | Partly: a quality slider needs CP-7 (Later, Q9) |
| 15 | No OCR: scans can't be searched or copied | "extract text with OCR": 72,911 views; "make an existing PDF searchable": 54,397; "batch OCR": 40,320 | https://superuser.com/questions/28426 ; https://apple.stackexchange.com/questions/76471 | Recognize Text on device, kept as an invisible text layer, findable and copyable (P-T27, PF-8, PF-9) | Fixed in v1 (one document at a time; batch Later) |

Just below the top 15 (research.md F): search that misses text or stops
working (45,628 views; fixed by Find over Folio's own page text and OCR,
P-T6, P-T27); printing at the wrong scale (55,962 views; the print sheet
offers Actual Size, Fit and Shrink to Fit, Apple docs: PDFPrintScalingMode,
P-T25); not reopening at the last page, no tabs (69,268 and 42,223 views;
Later, P-T32, P-T33); autosave overwriting the original (the platform forum;
fixed: Folio saves only on Save, P-T18); free web tools capped by size or
count (fixed: no caps beyond the 2 GB file limit).

**What the list changed in this blueprint:** PF-15 (every mark written with
an appearance stream) and PF-16 (an unedited save keeps the text, adds no
password and grows at most 10%) in section 8; ligature and soft-hyphen
cleanup in `TextSelecting.copyText` with its test; Signatures > Export… and
Import… in P-T21; call 11 in section 10.1 (no upsell, no account, no
network, no unasked AI).

Checklist:

- [x] 15 pain points ranked by how often and how loudly they are raised, each with a URL.
- [x] Each maps to a feature, decision or test, or says plainly that v1 doesn't fix it.
- [x] No product is named outside URLs; raw notes in research.md F.

---

## 1B. Features from the future

What people will need from a PDF tool in the next two to four years that
today's tools don't give them, each grounded in a dated driver (a law, a
standard, a measured shift) and in an API that exists on a Mac now. None is
in v1; each says its tier and what it waits on. Raw notes, with every URL,
are in `docs/blueprints/pdf/research.md` section G. Apple API facts were
read on 2026-10-15 from developer.apple.com.

Not in this list, on purpose: **spatial review on a headset** (PDFView runs
on visionOS and shared spaces exist, but third-party shipment estimates fell
in 2025, research.md G, so the demand isn't there), and anything that needs
a cloud account.

### F1 Ask the document, on the Mac (tier 3, Later)

**What the person does.** Asks the open PDF a question ("what is the notice
period?") and gets an answer with the page and the highlighted lines it came
from; asks for a summary; pulls a table out to the clipboard as rows.
Nothing leaves the Mac, and Folio says so.

**Why soon.** Three in four knowledge workers already use generative AI at
work, most with tools they bring themselves (a 2024 survey of 31,000 people
in 31 countries), while a quarter of organizations had banned it at least
for a time over data leaving the company and nearly half of people had
pasted non-public information into one (a 2024 benchmark of 2,600 privacy
professionals). On-device answers resolve that conflict.

**Possible now.** The on-device model (Apple docs: SystemLanguageModel,
macOS 26) with typed answers (Apple docs: Generable), and the document's
structure (paragraphs, lists, tables) from Vision (Apple docs:
RecognizeDocumentsRequest, DocumentObservation, macOS 26). Folio's own
`FolioPageText` gives the cited lines.

**Waits on.** The model exists only on Macs that support it and in
supported regions, so availability is checked and the feature hides with a
reason; its context is small, so long PDFs are answered from retrieved
passages; answers must always cite their lines (a quote that isn't on the
page is refused). Prompt regression tests per OS release.

### F2 Accessible by default: tagged PDFs on save (tier 2 when its law bites, Later)

**What the person does.** Saves or exports and gets a tagged PDF (headings,
reading order, alt text, table headers) that a screen reader can follow,
with a short list of fixes Folio suggests and the person confirms (an
image's alt text, a heading level).

**Why soon.** The European Accessibility Act applies from 2025-06-28; the
US rule for state and local governments (WCAG 2.1 AA, PDFs and online forms
named in scope) now applies from 2027-04-26 and 2028-04-26 after its
2026-04-20 extension; the PDF/UA-2 standard (ISO 14289-2:2024) was published
2024-03-13. More than one in four US adults has a disability.

**Possible now.** CoreGraphics writes tagged PDFs (Apple docs:
CGPDFContextBeginTag, CGPDFTagType, CGPDFContextSetPageTagStructureTree);
Vision proposes structure (RecognizeDocumentsRequest); the on-device model
drafts alt text, which a person approves (the extension's own reasoning
cites the limits of generated fixes).

**Waits on.** PDFKit can't add tags to an existing PDF, so retagging means
re-emitting pages through CoreGraphics or CorePDF; a PDF/UA-2 checker is
engine work (a new `CorePDF` item after CP-7, "tag tree writer and PDF/UA-2
checker", not filed).

### F3 E-invoices you can read and make (tier 3, Later; tier 2 for business users in the EU)

**What the person does.** Opens an invoice PDF and sees the machine-readable
invoice inside it as checked fields (seller, totals, VAT), flagged where the
printed page and the data disagree; makes a hybrid invoice (a readable page
plus its data) from a template.

**Why soon.** Germany requires every business to receive e-invoices since
2025-01-01 and to issue them from 2027 or 2028 by size; France requires
receiving from 2026-09-01; the EU's VAT in the Digital Age package (adopted
2025-03-11) moves cross-border B2B to digital reporting from 2030-07-01. The
hybrid PDF format (an XML invoice embedded in a PDF/A-3 file) is accepted
in both countries.

**Possible now.** PDF/A output from CoreGraphics (Apple docs:
kCGPDFContextCreatePDFA); Vision and typed model output to read scanned
paper invoices into fields.

**Waits on.** PDFKit has no embedded-file API, so reading and writing the
associated XML file and checking PDF/A-3 is CorePDF work (CP-1, CP-2 plus a
new embedded-files item); validating against the EU invoice standard needs
its published schemas, whose licences must be checked first.

### F4 Provenance you can check: who made this, and was AI involved (tier 3, Later)

**What the person does.** Opens a PDF and sees a provenance panel: who
signed or produced it, what changed since, whether any part was generated by
AI, each claim marked verified or not. Saves with Folio's own provenance
record when the person asks, and signs so the signature still verifies in
ten years.

**Why soon.** The EU AI Act's transparency duty for AI-generated content
applies from 2026-08-02, and the EU's final code of practice on marking AI
content (2026-06-10) asks for machine-readable marks; the open content
credentials specification (C2PA 2.2) defines how a manifest is embedded in a
PDF; EU digital identity wallets with free qualified signatures arrive from
late 2026 to 2027.

**Possible now.** The C2PA 2.2 specification's PDF embedding (an embedded
manifest referenced from the catalog, incremental updates allowed, the PDF
signature's byte range excluded from its hash); the Security framework's CMS
signer for the signature and its timestamp (Apple docs: CMSEncoder,
CMSEncoderSetHasDetachedContent, CMSEncoderCopySignerTimestamp); long-term
validation by document timestamps (PAdES B-LTA).

**Waits on.** CP-2 and CP-6 (incremental save, signature placeholder) plus
new CorePDF items for the validation dictionary and document timestamp; a
signing certificate on the C2PA trust list, which has a cost and an
enrolment (Q10).

### F5 Review together on the same network, no account (tier 3, Later)

**What the person does.** Opens "Review Together…", and a colleague on the
same network (or nearby, with peer-to-peer Wi-Fi) joins after accepting a
pairing code; both see each other's marks and cursors live; working offline
and reconnecting merges the marks without conflicts. No server, no sign-up.

**Why soon.** Local-first software (fast, offline, private, owned by the
person) has a published research agenda since 2019 that names conflict-free
replicated data types as the way to merge edits; the same privacy pressure
as F1 applies. Demand evidence is weak (research.md G); this is the most
speculative item.

**Possible now.** The Network framework's peer-to-peer listener, browser
and connection with Bonjour and QUIC with mutual TLS (Apple docs:
NetworkListener, NetworkBrowser, NetworkConnection, macOS 26; TN3213 says to
use these rather than Multipeer Connectivity, which Xcode 27 deprecates);
Wi-Fi Aware for paired devices. Folio's marks are already values in the
Model (section 4), which is what a merge needs.

**Waits on.** A conflict-free merge for marks and field values (FolioModel
work; an open-source library would need a dependency issue and a licence
check at a pinned commit); pairing and identity design; the local-network
privacy prompt.

### F6 Fill and read by voice (tier 3, Later)

**What the person does.** Says "name: Ada Lovelace, email ada at example
dot com" and the form's fields fill; dictates a comment on a highlight; asks
Folio to read the page aloud in reading order, the current words highlighted.

**Why soon.** About one in eight US adults has a mobility disability (CDC
2024); reading software is in the European Accessibility Act's scope; the
platform now lets apps expose their content to the system assistant.

**Possible now.** On-device speech to text (Apple docs: SpeechAnalyzer,
SpeechTranscriber, macOS 26), mapping a sentence to typed field values
(Generable), exposing documents and fields to the system assistant and
Shortcuts (Apple docs: App Intents, IndexedEntity), speech output
(AVSpeechSynthesizer, section 1.5).

**Waits on.** A reliable reading order, which F2's tags give.

### F7 Read it in your language, in place (tier 3, Later)

**What the person does.** Chooses View > Translate Page and sees the page in
their language, each paragraph in its own place and size, and switches
back; copies the translated text.

**Why soon.** Three in four consumers prefer information in their own
language (a 2020 survey of 8,709 people in 29 countries); documents now
cross languages daily, and uploading them to translate them is the same
privacy problem as F1.

**Possible now.** On-device translation with batches and styled text
(Apple docs: TranslationSession, init(installedSource:target:),
LanguageAvailability, macOS 26); Vision's paragraph and table boxes give
the blocks and where to put them back.

**Waits on.** Fitting longer or shorter text back into its box and
right-to-left scripts (an overlay, never rewriting the file); languages must
be installed, which the sheet offers to do.

### F8 Signatures that outlive today's cryptography (tier 3, Later)

**What the person does.** Signs a contract whose signature will still
verify after today's signature algorithms are retired; attaches or checks a
verifiable credential (a diploma, a licence) carried in the PDF.

**Why soon.** A draft from the US standards body (NIST IR 8547, 2024-11-12)
proposes retiring today's public-key signatures after 2030 and disallowing
them after 2035; W3C Verifiable Credentials 2.0 became a Recommendation on
2025-05-15.

**Possible now.** Post-quantum signatures and key exchange in CryptoKit
(Apple docs: MLDSA65, MLDSA87, MLKEM768, macOS 26); long-term validation by
document timestamps (F4).

**Waits on.** No PDF signature profile for post-quantum algorithms exists
yet and readers can't verify one, so Folio would add it beside a standard
signature, never instead; F4's CorePDF work.

### 1B.9 Summary

| # | Feature | Tier | Driver (date) | Possible now through | Waits on |
|---|---|---|---|---|---|
| F1 | Ask the document, on the Mac | 3 | workplace AI use vs. data bans (2024 surveys) | SystemLanguageModel, Generable, RecognizeDocumentsRequest | model availability; cited answers |
| F2 | Accessible by default (tagged PDFs) | 2 when due, else 3 | EAA 2025-06-28; US rule 2027-04-26; PDF/UA-2 2024 | CGPDFContextBeginTag; Vision structure | CorePDF tag writer and checker |
| F3 | E-invoices you can read and make | 3 (2 for EU business) | Germany 2025/2027/2028; France 2026-09-01; ViDA 2030 | kCGPDFContextCreatePDFA; Vision | CorePDF embedded files; schema licences |
| F4 | Provenance you can check | 3 | EU AI Act Art. 50 2026-08-02; C2PA 2.2 | C2PA PDF embedding; CMSEncoder; PAdES B-LTA | CP-2, CP-6, timestamps; a trust-listed certificate |
| F5 | Review together, no account | 3 | local-first agenda (2019); privacy | NetworkListener, NetworkBrowser, NetworkConnection, Wi-Fi Aware | merge of marks; pairing |
| F6 | Fill and read by voice | 3 | accessibility law; 12% mobility disability | SpeechAnalyzer, App Intents, AVSpeechSynthesizer | F2's reading order |
| F7 | Translate in place | 3 | own-language preference (2020 survey) | TranslationSession | text fitting; RTL |
| F8 | Signatures that outlive today's cryptography | 3 | NIST IR 8547 draft 2030/2035; VC 2.0 2025 | CryptoKit ML-DSA | a PDF profile for post-quantum signatures |

How these shape v1 without being in it: the document is already a value
(section 4), which is what F5's merge and F1's citations need; `FolioPageText`
keeps character boxes, which F1, F6 and F7 point back into; CorePDF's
incremental writer (CP-2) is the base of F3, F4 and F8; and nothing in v1
uploads a document, so none of these has to undo a cloud dependency.

Checklist:

- [x] 5 to 8 features (8), each with what the person does, why soon (dated), what makes it possible now on a Mac (cited), and its tier.
- [x] Every source in research.md G; no product named.

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
| Export | Pages as PNG or JPEG at 72, 150, 300 ppi; text as plain text, rich text or a word-processing document (text and paragraphs, not layout); Reduce File Size (the platform's image optimization, one level) with the measured result before writing; Print | Spreadsheet and slide formats; PDF/A; tagged PDF |
| OCR | Recognize text on scanned pages (languages from the system), kept as an invisible text layer on Save | Deskew and clean-up of scans; document structure export |
| Suite | One of the apps in AfterGlow: switcher item, Switch To, recents, Open In; hand-offs from Library and Photo (images to a PDF), to Photo (a page as an image) | Linked placement of PDF pages in Design |

**The line in one sentence:** a person opens or makes a PDF, reads and
finds in it, marks it up, fills and signs it, rearranges its pages, undoes
any step, and saves or shrinks or exports it, all on their Mac, in a file
every other reader opens.

**Why this line** (from section 1): rows 1 to 17 of 1.1 are in v1, except
the spreadsheet and slide parts of row 2 (Later); outside them, row 18
(making a PDF from office files) is a non-goal because the system already
prints to PDF, and row 21 (certificate signatures) is engine work, Later; OCR is in
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
every session, or is one of the top usage rows of 1.1 whose result stays a
PDF (open, make, merge, shrink, mark up, sign, fill, rearrange), or
something a tier-1 feature needs. Converting out of PDF (rows 2 and 14) is
tier 2 however high its demand. That is this blueprint's call, not a suite
rule: `docs/priorities.md` ranks export tier 2 for Flare and Halo ("once per
deliverable") but tier 1 for Photo and Library; Folio follows the first two
because a conversion out ends the work in another app, and 10.1 item 4
lets the captain overrule it; **tier 2** (`p2`) is weekly or once per deliverable;
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
its size, never a gap. *Errors:* not a PDF (no `%PDF-` header in the first 1,024 bytes), damaged
(the header is there but `PDFDocument(data:)` returns nil: "This PDF is
damaged and can't be opened."), too large, and locked: a locked file opens a password sheet ("This PDF is
locked. Enter its password to open it."), a wrong password shakes the
field and says "That password didn't unlock this PDF. Try again.", Cancel
leaves the window empty. A file with form scripts or XFA opens with a
banner naming what Folio won't run; the live opener finds them by walking
the catalog with CoreGraphics (an `/XFA` entry in `/AcroForm`; `/JavaScript`
in `/Names`, or `/AA` actions on fields: Apple docs, CGPDFDocument.catalog,
CGPDFDictionaryGetObject). *Hand-offs in:* Finder (Folio declares
PDF as Editor with handler rank Alternate, so it never becomes the default
without the person choosing it: Apple docs, LSHandlerRank); Open In ▸ Folio from any suite app that
writes PDF (Design's PDF export, #418); a PDF dropped on the AfterGlow home.
*Out:* recents in the suite's one list.

**P-T2 Read, zoom and page layout** (tier 1, row 1; `reader`, P-J1).
Continuous scroll (⌥⌘2) by default, Single Page (⌥⌘1), Two Pages (⌥⌘3);
Actual Size (⌘1), Fit Page (⌘0), Fit Width (⌘9), Zoom In and Out (⌘+, ⌘−,
pinch) along the steps 50, 75, 100, 125, 150, 200, 300, 400% (from a fit
zoom, the next step above or below it), the suite's ⌘1 and ⌘0 meanings. The zoom pill under the page shows the percent (`ViewerStatusBar`
formats it); the trailing pill shows "Page n of m" for the page nearest the
top. *Empty:* none
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

**P-T6 Find** (tier 1, row 15, *inferred*: no number of its own, a reading
staple every viewer has; `find`, P-J2). ⌘F opens the find bar over the top of the page
view; typing finds as you type (after 2 characters); every match is tinted
and the current one outlined; Return and ⌘G go to the next, ⇧Return and
⇧⌘G to the previous; the sidebar shows RESULTS with each hit's page and
context. Match Case and Whole Words toggles. *Empty:* "No results" and the
field's help "No matches for <text>." *Loading:* find runs on page text the
window loads in the background; pages whose text isn't loaded yet are
counted ("Loading text… 120 of 500") and searched when it arrives. *Errors:* pages with no text layer are
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
choices. Click or Tab into a field; Tab and Shift-Tab move in reading order (page,
then top to bottom, then left to right), skipping read-only and signature
fields; a radio group is one stop and the arrow keys pick within it; Space
toggles a checkbox. Tab, Shift-Tab and Delete are handled by the focused
field and page view, never as menu key equivalents, so typing in a field
or sheet never triggers a command. The field's tooltip from the form
author is its help. *Errors:* a read-only field says "<name> is read-only
in this form."; a too-long value or a line break in a one-line field shows
its sentence under the field and keeps the old value. *Empty:* a PDF with no
fields: the Form menu is disabled with "This PDF has no form fields. Use
Text Box to type on it."

**P-T13 Rotate, delete, reorder, insert pages** (tier 1, rows 10 and 11;
`pages`, P-J7). In the sidebar thumbnails or the Page Grid (⌥⌘4): select
pages (click, Shift-click, ⌘-click), Rotate Right (⌘R) and Left (⌘L),
Delete Page (⌘⌫; plain Delete too while the thumbnails have focus), drag to reorder (a drop line shows where), ⌥⌘← and ⌥⌘→
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

**P-T17 Undo and redo** (tier 1, *inferred* as for every suite app;
`foundation`, proven in every feature's journey and across features by
P-J9 in core-loop). Every edit is one named step (Undo Highlight, Undo Move Page, Undo
Typing); typing in one field or one text box and one drag each coalesce;
scroll, zoom, find and selection are never steps; 100 steps. *Empty:* Undo
and Redo disabled with "Nothing to undo." / "Nothing to redo."

**P-T18 Save and Save As** (tier 1, row 10's "save the rotated file" is the
general-computing Q&A site's most-viewed PDF question; `files`,
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
Type (the name, drawn as document content by `FolioSignatureMark`
through CoreText in the system font's italic at display size, so no custom
font reaches a view: Apple docs, CTFontCreateUIFontForLanguage) and Image
(pick a picture; the app decodes it with ImageIO into a `FolioBitmap`, and
`Signing.make(picture:)` makes near-white pixels transparent and trims to
the ink, pure Swift tested on Linux). "Save as initials" marks
initials. Clicking a page places the chosen signature there at a natural
size, or fitted inside an empty signature field. Placed signatures move and
resize like any mark, keeping their aspect. The library lives in Folio's
folder and survives relaunch, and Signatures > Export… and Import… write
and read it as one file, so a signature moves to another Mac (pain point 12). *Empty:* only New Signature…. *Errors:* Done
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
`export-convert`, P-J23). File > Reduce File Size… writes a copy with the
platform's image optimization (images optimized for screen and saved as
JPEG: Apple docs, PDFDocumentWriteOption.optimizeImagesForScreenOption and
saveImagesAsJPEGOption) and shows the measured result before keeping it:
"From 8.4 MB to 2.9 MB". Choosing a resolution (Small, Medium, Large) is
Later, with CorePDF's image re-encoding (CP-7, Q9). It writes
"<name> (reduced).pdf" next to the original and never overwrites it. Text
and vector content are untouched (PF-11); if the platform options prove not
to shrink real files, the feature ships off and Q9 decides. *Loading:* progress in the sheet
with Cancel. *Errors:* when the result isn't smaller: "This PDF is already
as small as Folio can make it." and nothing is written.

**P-T30 No dead controls** (tier 1 by dependency: CLAUDE.md, review rubric
QB-F1; `foundation`, P-J12). Every menu item, toolbar button and palette
tool acts or is disabled with the sentence saying why, from
`unavailableHelp(for:)` in the Model; each feature's controls read "Not built
yet." until its feature lands.

### 3.2 Tier 2 (all in v1 unless marked)

**P-T10 Pen and shapes** (tier 2, row 6 and research.md B.2 rows 34 and 35:
shapes 18 👍 and 18 upvotes; `markup`, P-J4). Pen (P) draws freehand ink as the pointer
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

**P-T20 Flatten and passwords** (tier 2, rows 16 and 24; `files`,
P-J10). Save As… and Export… offer Flatten (marks and field values drawn
into the pages, no longer editable), an open password, and owner
restrictions (printing, copying, changing). Removing an open password: open the
file with it, then Save As without one. Changing or removing owner
restrictions needs the file opened with its owner password (or a file that
has none); otherwise Save As keeps them and says "Changing this PDF's
restrictions needs its owner password." (`FolioWriteError.restricted`, PF-6). *Errors:* a non-ASCII owner
password is refused with "Use letters, numbers and symbols from a standard
keyboard." (the system's encryption takes ASCII only: Apple docs:
kCGPDFContextOwnerPassword).

**P-T23 Export text and a word-processing document** (tier 2 by the
conversion rule above, though row 2 by demand; `export-convert`, P-J21). File > Export… > Text, Rich
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

**P-T25 Print** (tier 2, row 17 and the printing-scale complaints of 1A; `export-convert`, P-J24). ⌘P opens the
system print panel with Folio's page range, scaling (fit, actual size) and
auto-rotate (Apple docs: PDFDocument.printOperation); the scaling is the
person's choice of Actual Size, Fit or Shrink to Fit (Apple docs:
PDFPrintScalingMode), shown in the panel, defaulting to Actual Size. Booklets and pages
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
`files`). The inspector's DOCUMENT section shows title, author,
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
| P-T42 | Export to spreadsheet and slide formats | 2 (the conversion rule; Later because it needs layout-aware structure) | row 2 | Vision document structure (Apple docs: RecognizeDocumentsRequest) |

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
| P-T17 Undo (foundation) | 1 | yes | P-J9 (core-loop) and every journey's Edit-menu asserts |
| P-T18 Save (files) | 1 | yes | P-J10 |
| P-T19 Open Recent (reader) | 2 | yes | P-J1 (last step) |
| P-T20 Flatten and passwords (files) | 2 | yes | P-J10 |
| P-T21 Sign (sign) | 1 | yes | P-J6 |
| P-T22 Reduce File Size (export-convert) | 1 | yes | P-J23 |
| P-T23 Export text (export-convert) | 2 | yes | P-J21 |
| P-T24 Export images (export-convert) | 2 | yes | P-J21 |
| P-T25 Print (export-convert) | 2 | yes | P-J24 |
| P-T26 Document properties (files) | 3 | yes | P-J10 (properties step) |
| P-T27 OCR (ocr) | 2 | yes | P-J20 |
| P-T28 Edit text in place (content-edit) | 2 | conditional | P-J25 |
| P-T29 Redact (content-edit) | 2 | conditional | P-J26 |
| P-T30 No dead controls (foundation) | 1 | yes | P-J12 |
| P-T31 to P-T42 | 2-3 | Later | – |

Checklist:

- [x] Every feature has a tier that cites a row of 1.1 or is marked *inferred*.
- [x] Every tier-1 feature has a tier-1 journey (3.4).
- [x] Each feature says what the person does and sees, its empty, error and loading states, its shortcuts, and its hand-offs where it has any.

---

## 4. Pseudo-C4 (drawn before code)

Every element here is **planned**: nothing of Folio is on `origin/dev`.
Three layers as `docs/engineering.md` sets them: creative-core engines,
`FolioModel` (Linux-safe state and logic), `FolioApp` (SwiftUI, macOS).
SuiteUI sits beside the app and knows no Model. The same model as data is
`docs/blueprints/pdf/c4-planned.json` (the shape of `docs/c4/model.json`,
one level finer, every element `"status": "planned"` and `"authored":
true`). It is not read by `scripts/ci`. W0's first PR (the supervisor-merged
one that adds the targets to `Package.swift`) also adds the `folio-model` and
`folio-app` containers, one component per target folder, to
`docs/c4/model.json`, so every later Folio PR passes the C4 ownership gate;
W0's last PR refines their descriptions.

**The one architectural call.** PDFKit is macOS only, so it can never be
the Model. Folio's Model holds the document as a value
(`FolioDocumentState`: pages in order with their origin and rotation,
annotations, form field values, outline, permissions) and treats the bytes
it opened as read-only **sources**, held for the window's life in one
`DocumentSources` store (bytes by source id, registered by the opener, read
by every platform service). The app reads a file of up to 512 MB into
memory; a larger one is first copied to a private temporary file only
Folio writes, and that copy is mapped, so another process changing the
original can never fault a mapped page (no crash, CLAUDE.md), and a file
deleted after opening still saves. PDFKit does exactly four jobs, each
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
| folio-fixtures | Named fixtures (`letter`, `form`, `filled`, `scripted`, `scan`, `locked`, `restricted`, `marked`, `photos`, `long` in W0; each feature adds its own in `Fixtures/FolioFixtures+<Area>.swift`, a file W0 stubs empty: `long1000marks` and `page1000marks` (markup), `form200` (forms), `big50` (files), `scan300` (ocr)) | `Fixtures/*.swift` | fakes; FolioApp's sample writer |
| folio-services | `FolioServices` with `.fake`; the live slots are filled in FolioApp | `FolioServices.swift` | workspace |
| folio-workspace | `FolioWorkspace`: the window's one value-type state (document, history, selection, tool, zoom and page, page text, find state, file state, open progress, refusal), `edit(_:coalesceKey:_:)` (the one place undo is recorded), undo and redo, and one extension file per area, each owned by its feature; `pageSummary(n)`, the per-page accessibility value journeys read, and `statusPills`, both whole in W0 (`FolioPageSummary.swift`, pure reads of the document value) | `FolioWorkspace.swift`, `Workspace/*.swift`, `FolioPageSummary.swift` | services; read and called by FolioApp |
| folio-commands | `FolioCommand` (every menu item and toolbar action), `unavailableHelp(for:)` and `title(for:)`, one availability file per area | `FolioCommand.swift`, `Availability/FolioAvailability+<Area>.swift` | workspace; FolioApp menus and toolbar |
| folio-tools | `FolioTool` (the palette: Select, Text Select, Highlight, Underline, Strike Out, Note, Text Box, Pen, Shape, Sign, Hand), its one-key shortcuts and `drag(from:to:)` routing per tool | `FolioTool.swift`, `Tools/FolioTool+<Kind>.swift` | annotating, selecting, signing; `FolioToolsTests` |
| folio-layout | Page layout math: the continuous column, two-up, page gaps, fit width and fit page scale (the page column starts after the floating palette's band, PL2), the zoom steps, which pages are visible, page ↔ view points (`FolioLayout.swift`, reader); the Page Grid's columns (`FolioGridLayout.swift`, pages) | `FolioLayout.swift`, `FolioGridLayout.swift` | reader view, pages grid; budgets PB-2, PB-3 |
| folio-live | The Linux live types: the source store, finding, selecting, annotating, form filling, signing, page organizing, history, the signature store (JSON in a folder the app names) | `Live/Live<Contract>.swift` | contract suites |
| folio-launch | Launch arguments (`-FolioFixture`, `-FolioSample`, `-FolioOpenFile`, `-FolioSaveTo`, `-FolioExportTo`, `-FolioPickFile(s)`, `-FolioSignaturesDir`, `-FolioWindowSize`, `-SuitePerfProbe`, and `-FolioWriteSample <name> <path>`, which writes one fixture as a real PDF and quits, so a journey can make the files it opens) parsed into `FolioLaunch` | `FolioLaunch.swift` | FolioApp's window root |

#### FolioApp (planned)

| Component | Responsibility | Paths | Relationships |
|---|---|---|---|
| folio-scene | `@main FolioApp`: a `DocumentGroup`-free `WindowGroup` (one window per open PDF, Halo's pattern), the `.suiteApp(.folio, host:)` modifier once the suite lands, menus as one `Commands` type per area | `FolioApp.swift`, `FolioCommands+<Area>.swift` | SuiteShell; folio-commands |
| folio-window | `FolioWindow`: `SuiteWindow` with the sidebar (Pages, Outline, Marks), the detail (page view, palette, status pills), the inspector; one `FolioWindow+<Area>.swift` per area (intents to the workspace, sheets) | `FolioWindow.swift`, `FolioWindow+<Area>.swift`, `FolioPrinting.swift` | workspace; SuiteUI |
| folio-pageview | The page view (`FolioPageView.swift`, reader): page pictures from `PageImaging` in `FolioLayout`'s column, and over each page the overlays listed in `FolioPageOverlays.swift` (W0, the one seam, so no feature edits the page view to add a layer): marks (markup), form fields (forms), text selection (markup), find hits (find), signatures (sign), redaction marks (W4), each its own file W0 stubs empty; gestures routed to the active tool's `drag`; the find bar; the Page Grid | `PageView/*.swift`, `PageGrid/*.swift` | layout, tools |
| folio-sidebar | `FolioNavigator` (named so: the design lint rejects a struct ending in `Sidebar`) lists the sidebar sections, each its own file W0 stubs and a feature owns: thumbnails (pages), outline (reader), find results (find), the marks list (markup) | `Sidebar/*.swift` | organizing |
| folio-inspector | `FolioInspector` lists the inspector sections, each its own file W0 stubs and a feature owns: document properties (files), the selected mark (markup), the selected field (forms), the selected page (pages) | `Inspector/*.swift` | annotating, forms |
| folio-sheets | Password, Insert, Combine, Extract and Split, Crop, Save Options, Signature, Export, Reduce Size, Recognize Text, Apply Redactions | `Sheets/*.swift` | the feature that owns each |
| folio-live-macos | The macOS live services: `PDFKitOpening`, `PDFKitImageOpening` (New from Images), `PDFKitImaging`, `PDFKitText`, `PDFKitFields` (widgets ↔ `FolioFormField`), `PDFKitAnnotations` (PDF annotations ↔ `FolioAnnotation`), `PDFKitWriting`, `PDFKitExporting`, `VisionRecognizing`, `FolioSampleWriter` (fixtures as real PDFs for `-FolioSample`), `FolioSignatureMark` (draws a signature body), `FolioServices+Live` | `Live/*.swift` | contracts; PDFKit, Vision, CoreGraphics |
| (no own probe) | Every Folio control registers with SuiteUI's shared control inventory (`.suiteControl(id:enabled:reason:)`; the window root adds `.suiteProbes()`, which publishes `suite.controls` under `-SuitePerfProbe`), so Folio adds no probe of its own | – | SuiteUI `ControlInventory.swift` |

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
| CP-7 | `CorePDF` image re-encoding: rewrite each image XObject at a target resolution and JPEG quality (pixels through CoreRaster) without touching text or vector content; acceptance: on a fixture of 300 ppi photos, 150 ppi output is ≤ 40% of the bytes and every page's extracted text is unchanged | Reduce File Size levels (Later, Q9) | 1 (the level control) | needs a new core issue |

None blocks v1. `content-edit` is the conditional W4 feature (section 2.4);
certificate signing is Later.

Checklist:

- [x] Every `Sources/` path planned here sits in exactly one component (`waves.py` checks it against `c4-planned.json`).
- [x] Every engine need says "needs a new core issue" with a one-line spec and an acceptance line (CP-1 to CP-7).
- [x] `c4-planned.json` mirrors this section, every element planned and authored.

---

## 5. Journeys

Every tier-1 feature has a journey: an XCUITest that launches the bundle,
works the window the way a person would, and shoots the whole window after
every step (`docs/engineering.md`, Human-like UI tests). The app audit runs
on every shot.

**Files.** W0 creates `UITests/FolioJourneyTests.swift` (launch, menus,
every control, layout). Its every-control and every-menu journey (P-J12)
is data-driven: it reads `suite.controls` and the menu list from
`FolioCommand` (Linux-tested), so a feature adds controls and menu items
without editing the journey file. Each feature owns `UITests/FolioJourneyTests+<Area>.swift`
with its own `XCTestCase` class, so no two features edit one journey file;
`project.yml`'s journey bundle globs `UITests/FolioJourneyTests*.swift`
(W0's supervisor-merged task adds the Folio bundle).

**Modes.** `FolioLaunch` picks the services: `-FolioFixture <name>` and
`-FolioFake` mean fake services (`-FolioFake` with `-FolioOpenFile` opens a
fake file, such as one the fake writer saved); `-FolioSample <name>` and a
plain `-FolioOpenFile` mean live PDFKit and Vision. A journey first runs on
`-FolioFixture <name>` (fake services, section 6) and is flipped to `-FolioSample <name>` (live PDFKit and Vision,
the same fixture written as a real PDF by `FolioSampleWriter` into the
test's temp folder with `-FolioWriteSample`) by the task that lands the live
type. P-J14 runs live from its first PR. A journey uses only controls its
own feature or an earlier wave owns; W0's working pieces (thumbnails that go
to a page, undo and redo with named steps, the page column on fakes) are
in every later journey, and a feature that replaces a W0 file keeps them
working.

**Finding things.** By the title a person reads where there is one, else by
identifier: `folio.page.<n>` (1-based) for each page view,
`folio.thumb.<n>`, `folio.mark.<id>`, `folio.field.<name>`, `folio.find`,
`folio.tool.<tool>`. The page view's pixels can't be read through XCUITest,
so `folio.page.<n>` carries the Model's `pageSummary(n)` as its
accessibility value, built and tested in FolioModel. W0 writes it whole, a pure read of the document value (rotation, crop,
marks by kind, field values, text origin), so no feature edits it and every
journey can read every facet from the day its data exists; facets with
nothing to say are left out: "Page 2 of 3, Letter; rotated 90°;
cropped 540 × 720; marks: highlight, underline, note; fields: name=Ada
Lovelace, agree=on; text: embedded" (text: embedded, recognized or none).
Drags use page points mapped through `folio.page.<n>`'s frame and the zoom
(`FolioLayout` math, tested on Linux).

**Probe.** P-J12 and every perf journey (P-P1 to P-P6) launch with
`-SuitePerfProbe`, which `.suiteProbes()` at Folio's window root reads
(SuiteUI, `SuiteEnvironment.swift`).

**Waiting.** No timing through XCUI queries. State changes are awaited with
`waitForExistence` or a value predicate (2 s); timing comes from the probe
(section 8).

### 5.1 Tier-1 journeys

| # | Test (file, feature) | Launch | Steps (each one shot, `folio-<step>`) | Asserts |
|---|---|---|---|---|
| P-J0 | `testLaunchShowsWindowShell` (`FolioJourneyTests.swift`, foundation) | none | launch | `expectWindowShell()`; the empty state "No PDF Open" with Open… and Create from Images…; the inspector "No Selection"; the switcher row's Folio item current and disabled "You're in Folio." once the suite wires it (until then every switcher item is disabled with its reason); every audit count 0 |
| P-J1 | `testOpenAndRead` (`+Read`, reader) | `-FolioWriteSample letter <tmp>/Lease.pdf`, then `-FolioOpenFile <tmp>/Lease.pdf` | open; ⌥⌘2 Continuous; scroll to the end; ⌥⌘G, type 2, Return; ⌘1 Actual Size; ⌘+ twice; ⌘9 Fit Width; click thumbnail 3; ⌥⌘3 Two Pages; open the Outline section, click "Signatures"; ⌘[ Back; quit, relaunch with no file, File > Open Recent > Lease | title "Lease"; `folio.page.1` value starts "Page 1 of 3, Letter"; the page pill reads "Page 3 of 3" at the end, "Page 2 of 3" after Go to Page 2; zoom pill "100%", then "150%"; after Fit Width the page's frame matches PL2; page 3 at the top after the thumbnail click (W0's thumbnails); two pages side by side (frames of page 1 and 2 share a top); the outline lists Agreement, Deposit and pets, Signatures and clicking Signatures puts page 3 at the top; Back returns to the page before; Open Recent lists "Lease" first and reopens it |
| P-J1b | `testGoToPageLabel` (`+Read`, reader) | `letter` (fake: pages labelled i, ii, iii) | ⌥⌘G, type ii, Return; ⌥⌘G, type x, Return | page 2 at the top; "x" refused with "No page is labelled x." under the field. Fixture mode only: PDFKit reads page labels but can't write them (Apple docs: PDFPage.label is get-only), so the sample writer can't make a labelled live file; live label reading is checked when CorePDF can write a fixture (CP-2) |
| P-J2 | `testFindText` (`+Find`, find) | `letter` | ⌘F; type "first day"; Return; Return; ⌘G; Match Case on, type "FIRST"; Escape | "1 of 2" then "2 of 2" then wraps "1 of 2"; the sidebar RESULTS list has 2 rows with "p. 1" and their context; with Match Case "No results" and the field's help "No matches for FIRST."; Escape closes the bar and keeps the page where the last hit was |
| P-J3 | `testSelectCopyAndMark` (`+Markup`, markup) | `letter` | press T; drag across "RESIDENTIAL LEASE" on page 1; ⌘C; double-click "LEASE"; triple-click line 2; ⌘A; click away; drag across "RESIDENTIAL LEASE", Markup > Highlight; press U and drag line 3; press K and drag line 4; click the highlight; set colour Green in the inspector; type a comment "Check name"; select the strike-out, Delete | the general pasteboard (read by the test) holds "RESIDENTIAL LEASE"; the selection reads "LEASE", then line 2's text, then all four lines (the `folio.selection` value); page 1's value gains "marks: highlight", then "marks: highlight, underline, strike-out", then "marks: highlight, underline"; Edit menu "Undo Highlight", "Undo Underline", "Undo Strike Out", "Undo Change Color", "Undo Comment", "Undo Delete" (W0's undo) |
| P-J4 | `testNotesTextBoxPenShape` (`+Annotate`, markup) | `letter` | N, click page 1 at the margin, type "Ask about parking", Escape; X, click, type "Initial here", Escape; set its font size to 18 in the inspector; P, draw a stroke; R, drag a rectangle; set line width 4; V, drag the note 40 pt down; ⌘Z; with the note selected press → twice and Shift-↓; X, click, Escape | page value "marks: note, text box, ink, rectangle"; the note's popover holds the text; the text box shows "Initial here" at 18 pt (inspector row); after the drag the note's frame moved by 40 pt × zoom; ⌘Z puts it back ("Undo Move Note"); the arrows move it 2 pt right and 10 pt down; the empty text box is not created and the help reads "Type some text for the text box." |
| P-J5 | `testFillForm` (`+Forms`, forms) | `form` | click Name; type "Ada Lovelace"; Tab; type "ada@example.com"; Tab (to the Plan group); → (Plus); Tab (to Agree to terms); Form > Check Form; Space; Form > Check Form; Form > Clear Form; ⌘Z | after typing, `folio.field.name` value "Ada Lovelace"; Tab order Name → Email → Plan → Agree to terms (the signature field is never a Tab stop); → picks Plus and clears Basic; the first Check Form reads "1 required field is empty: Agree to terms" with a warning outline and triangle on it, the second "All required fields are filled."; Clear empties all; Edit menu "Undo Clear Form" restores them; typing in Name was one step "Undo Typing"; `scripted` (second launch) shows the banner "This form has scripts Folio doesn't run. Check calculated fields before sending." |
| P-J6 | `testSignDocument` (`+Sign`, sign) | `form` with `-FolioSignaturesDir <tmp>` and `-FolioPickFile` a PNG of dark ink on white | press S; New Signature…; Done (pad empty); Draw two strokes on the pad; Done; click inside the Signature field; drag the signature's corner handle; press S, New Signature…, Type, "A.L.", Save as initials on, Done; click near the bottom margin; press S, New Signature…, Image, pick, Done; quit; relaunch with the same `-FolioSignaturesDir`; press S | the empty pad's Done is disabled with help "Draw your signature in the box first."; placed inside the field, fitted and centered (its frame inside `folio.field.signature`'s); resize keeps the aspect within 1%; initials placed where clicked at 72 pt wide; the picture signature appears in the library trimmed to its ink; after relaunch the library still lists all three |
| P-J7 | `testOrganizePages` (`+Pages`, pages) | `letter` | ⌥⌘4 Page Grid; click page 3; ⌘R; drag page 3 before page 1; select page 1, ⌥⌘→ (moves it right); select page 2, Shift-click page 3; Page > Delete Page; ⇧⌘B; Page > Crop Pages… with 36 pt margins on page 1, Crop; ⌘Z four times | rotated: page 3 value "rotated 90°"; order (by the `folio.thumb.n` values) 3, 1, 2 after the drag, then 1, 3, 2 after ⌥⌘→; after delete 1 page left, and selecting every page then ⌘⌫ shows "A PDF needs at least one page…" and changes nothing; a blank Letter page appended; page 1's value reads "cropped 540 × 720"; each ⌘Z names "Undo Crop", "Undo Insert Page", "Undo Delete Pages", "Undo Move Page" |
| P-J8 | `testCombineExtractSplit` (`+Combine`, pages) | `-FolioWriteSample letter <tmp>/Lease.pdf`, `-FolioWriteSample form <tmp>/Application.pdf`, then `-FolioOpenFile <tmp>/Lease.pdf` with `-FolioPickFile <tmp>/Application.pdf`, `-FolioPickFiles <tmp>/Lease.pdf,<tmp>/Application.pdf` and `-FolioExportTo <tmp>/out` | Page > Insert from File…, at End; Page > Extract Pages…, type "5", then "2-3", Extract; File > Combine Files… (`-FolioPickFiles` both files), Combine; in the combined window Page > Split…, after page 3, Split | 4 pages; page 4's value lists its fields ("fields: name=, email=, …"); the Extract sheet refuses "5" with "This document has pages 1 to 4." under the field; a new window "Lease (pages 2–3)" with 2 pages; the original unchanged; a new window "Combined" with 4 pages (Lease then Application); Split writes `Combined (part 1).pdf` (3 pages) and `Combined (part 2).pdf` (1 page) into `<tmp>/out` |
| P-J9 | `testUndoRedoEveryEdit` (`+History`, core-loop) | `form` | type in Name; highlight a line; rotate page 1; ⌘Z ×3; ⇧⌘Z ×3; scroll and zoom between | Edit menu names each step in order and back; scroll and zoom add no step; with nothing left Undo is disabled with "Nothing to undo." (undo itself is W0's, proven step by step in every feature's journey; this journey crosses three features, so it runs after them) |
| P-J10 | `testSaveAndReopen` (`+Files`, files) | `filled` (a filled form with a highlight from the file), `-FolioSaveTo <tmp>/Filled.pdf`; relaunches with `-FolioFake -FolioOpenFile` | in the inspector's DOCUMENT section set Title to "Membership"; ⌘S; quit; relaunch `-FolioOpenFile <tmp>/Filled.pdf`; File > Save As… with Flatten on and a password (`-FolioSaveTo <tmp>/Flat.pdf`); open Flat.pdf; then `restricted`: Save As… with "Allow changes" on | subtitle "Edited" then "Saved"; reopened: page 1's value has "fields: name=Ada Lovelace, agree=on" and "marks: highlight", the inspector title "Membership", Undo disabled; Flat.pdf asks for its password, a wrong one reads "That password didn't unlock this PDF. Try again.", the right one opens with no fields (no "fields:" facet); the restricted save refuses with "Changing this PDF's restrictions needs its owner password…" and writes nothing. Runs on fakes; the live round trip of fields and marks is P-J14 (core-loop), after forms and markup land their PDFKit mappings |
| P-J11 | `testOpenProblems` (`+OpenErrors`, reader) | none, then `-FolioOpenFile` per file | write `not a pdf` text, a truncated PDF (sample cut at half), `locked` sample; open each; on the locked one Cancel, then open again and type the password | each message is `FolioOpenError.message` for its case (not a PDF; damaged with the reason; locked); Cancel leaves the empty state; the right password opens "Payslip"; the window never shows a half-open document |
| P-J12 | `testEveryControlActsOrSaysWhy` and `testEveryMenuOpens` (`FolioJourneyTests.swift`, foundation; data-driven, never edited by a feature) | `letter` with `-SuitePerfProbe` | open each menu; read the `suite.controls` JSON; click each enabled control, Escape, ⌘Z | every enabled control changed the shot or a value; every disabled one has help (QB-F1); each menu holds exactly the items `FolioCommand.menu(_:)` lists for the features built so far (the same list section 7.6 shows) |
| P-J13 | `testLayoutAtWidths` (`FolioJourneyTests.swift`, foundation) and `testLayoutWithMarksAndFind` (`FolioJourneyTests+Loop.swift`, core-loop) | `letter`, `-FolioWindowSize` ×5 | relaunch at each size of 8.3 | PL2, PL3, PL5 (foundation); PL1, PL4 (core-loop) |
| P-J22 | `testCreateFromImages` (`+Images`, export-convert) | none, `-FolioPickFiles` a 600 × 800 PNG, an 800 × 600 PNG and a text file, `-FolioSaveTo <tmp>/Scans.pdf` | File > New from Images…; ⌘S | 2 pages, the first portrait and the second landscape, each the image's aspect fitted to the locale's paper; "Skipped notes.txt: not an image."; each page's value ends "text: none"; title "Scans" after save |
| P-J23 | `testReduceSize` (`+Reduce`, export-convert) | `photos` (fake: picture bytes divide by 4 when optimized; live: `-FolioWriteSample photos`, 300 ppi photos), `-FolioExportTo <tmp>` | File > Reduce File Size…, Reduce; File > Open `<tmp>/Photos (reduced).pdf`; File > Reduce File Size…, Reduce | the sheet reads "From <a> MB to <b> MB", with b ≤ 0.6 a asserted on fakes and recorded (report-only, like PF-11) on the live run until Q9 is answered; `Photos (reduced).pdf` exists and the original's bytes are unchanged; the second run says "This PDF is already as small as Folio can make it." and writes nothing |
| P-J14 | `testReadMarkFillSignSave` (`FolioJourneyTests+Loop.swift`, core-loop) | live, `-FolioSample form`, `-FolioSaveTo` | the whole loop on live services: open; find "Name"; highlight it; fill Name and Agree; sign in the field; rotate page 1 and back; ⌘Z, ⇧⌘Z; ⌘S; relaunch on the file | each step on PDFKit; the reopened file has the value, the highlight, the signature (PF-12) and no extra page |

### 5.2 States each journey passes through

| Journey | Empty | Error | Loading |
|---|---|---|---|
| P-J0, P-J1 | no document: "No PDF Open" with Open… (prominent) and Create from Images…; a document with no outline: "No outline in this PDF."; no marks: "No markup yet. Pick a tool and drag over text." | – | open shows a progress row in the page view at once (`beginOpen`, QB-L9) and the thumbnails fill in as `PageImaging` returns; a page whose picture isn't ready shows a blank sheet of its size with a spinner, never a gap |
| P-J2 | no query: the bar's placeholder "Find in document"; no hits: "No results" and the field's help sentence | a page with no text layer is skipped and the bar says "2 pages have no text. Recognize text to search them." with Recognize… | find is synchronous over loaded page text (PB-5); pages whose text is still loading are counted, "Loading text… 120 of 500", and searched when it arrives |
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
| P-J20 | `testRecognizeScan` (`+OCR`, ocr) | `scan` | open; the warning pill "No text: Recognize…"; Tools > Recognize Text…, English, Recognize; ⌘F "total"; T, double-click "TOTAL"; ⌘Z; ⇧⌘Z; ⌘S and reopen | progress "Page n of 2"; afterwards the pill reads "Text recognized" and page 1's value ends "text: recognized"; Find gets 1 hit on page 1; the selection reads "TOTAL"; ⌘Z names "Undo Recognize Text" and page 1 reads "text: none" again, ⇧⌘Z brings it back; after save and reopen the text is still there (PF-9) |
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

Checklist:

- [x] Every tier-1 feature has a journey with the XCUITest that proves it.
- [x] Every journey lists its empty, error and loading states (5.2).
- [x] Every journey uses only controls its own feature or an earlier wave owns.

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
`Fakes/FolioFakes.swift`, `FolioServices.swift`) with twelve proof tests in
`Tests/FolioContractTests.swift`: open, outline and labels, source
registration and find (P-J1, P-J2); open refusals, a damaged file and the
script flag (P-J11, P-J5); select, word, line, copy with paragraphs, mark,
text-box style, note, move, delete (P-J3, P-J4); Tab order with a radio
group as one stop and labels (P-J5); sign into a field and keep the library
(P-J6, with a picture signature); reorder, rotate, delete, insert, crop, ranges, split and combine
(P-J7, P-J8); undo coalescing (P-J9); save, reopen under a new source,
flatten, passwords and owner restrictions (P-J10); export images and text
(P-J21); new from images with a skipped file and Reduce (P-J22, P-J23);
recognize, find, save and reopen the recognized text (P-J20); permissions
refusing edits.
`docs/blueprints/pdf/contracts/check.sh` builds them as a `FolioModel`
target plus a test target in a throwaway package and runs the tests. Run on
2026-10-15 with Swift 6.1.2 on Ubuntu 24.04 after critic round 2:
`CONTRACTS: PASS`, no errors, no warnings, 12 of 12 tests. W0 copies the files into `Sources/FolioModel/`
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
| UC-0 Keep the opened bytes | `DocumentSources` | `FakeDocumentSources` (an actor; also decodes fake files for the other fakes) | `FolioModel/Live/LiveDocumentSources.swift` (foundation) | every journey |
| UC-1 Open a PDF or images | `DocumentOpening` | `FakeDocumentOpening` (reads the fake file; passwords, not-PDF, too large) | `FolioApp/Live/PDFKitOpening.swift` (reader), `PDFKitImageOpening.swift` (export-convert) | P-J1, P-J11, P-J22 |
| UC-2 See a page | `PageImaging` | `FakePageImaging` (white page, grey band per line) | `FolioApp/Live/PDFKitImaging.swift` (reader) | P-J1 and every shot |
| UC-3 Page text | `PageTextReading` | `FakePageTextReading` (fixed grid: 72 pt in, 14 pt lines, 6 pt glyphs) | `FolioApp/Live/PDFKitText.swift` (reader) | P-J2, P-J3 |
| UC-4 Find | `TextFinding` | `FakeTextFinding` (reference) | `FolioModel/Live/LiveTextFinding.swift` (find) | P-J2 |
| UC-5 Select text | `TextSelecting` | `FakeTextSelecting` (reference) | `FolioModel/Live/LiveTextSelecting.swift` (markup) | P-J3 |
| UC-6 Mark up | `Annotating` | `FakeAnnotating` (reference) | `FolioModel/Live/LiveAnnotating.swift` (markup); `FolioApp/Live/PDFKitAnnotations.swift` maps to and from PDF annotations | P-J3, P-J4 |
| UC-7 Fill forms | `FormFilling` | `FakeFormFilling` (reference) | `FolioModel/Live/LiveFormFilling.swift` (forms); `FolioApp/Live/PDFKitFields.swift` maps widgets | P-J5 |
| UC-8 Make and place a signature (drawn, typed, picture) | `Signing` | `FakeSigning` (reference) | `FolioModel/Live/LiveSigning.swift` (sign) | P-J6 |
| UC-8b Keep signatures | `SignatureStoring` | `FakeSignatureStore` (an actor in memory; can fail on save) | `FolioModel/Live/LiveSignatureStore.swift` (sign; JSON in the folder the app names) | P-J6 |
| UC-9 Organize pages | `PageOrganizing` | `FakePageOrganizing` (reference) | `FolioModel/Live/LivePageOrganizing.swift` (pages) | P-J7, P-J8 |
| UC-10 Undo and redo | `DocumentHistory` | `FakeDocumentHistory` (reference) | `FolioModel/Live/LiveDocumentHistory.swift` (foundation) | P-J9 and every Edit-menu assert |
| UC-11 Save | `DocumentWriting` | `FakeDocumentWriting` (writes the fake file; flatten and password) | `FolioApp/Live/PDFKitWriting.swift` (files) | P-J10, P-J14 |
| UC-12 Export | `PageExporting` | `FakePageExporting` (describes each image; text with format markers) | `FolioApp/Live/PDFKitExporting.swift` (export-convert) | P-J21, P-J23 |
| UC-13 Recognize text | `TextRecognizing` | `FakeTextRecognizing` (returns a scan page's known lines) | `FolioApp/Live/VisionRecognizing.swift` (ocr) | P-J20 |
| (W4) Replace a line, redact | `TextReplacing`, `Redacting` in `Contracts/FolioContentEditContracts.swift` | written by content-edit with its fakes | `FolioModel/Live/LiveTextReplacing.swift`, `LiveRedacting.swift` over CorePDF | P-J25, P-J26 |

Reduce File Size is `DocumentWriting.write` with `optimizeImages` set; Combine
Files is `PageOrganizing.combine`; Print
is the system print operation on the saved bytes; document properties and
zoom, page and view mode are workspace methods (pure value edits, tested on
`FolioWorkspace`).

### 6.2 The workspace methods views call

Each lives in the extension file its feature owns (section 9). Every write
goes through `edit`; every read is a computed property. `FolioWorkspace` is
a `struct` the window keeps in `@State` (Halo's `HaloProject` pattern).

| File (feature) | Methods |
|---|---|
| `FolioWorkspace.swift` (foundation) | `init(services:launch:)`, `init(document:services:)` (a window for an extracted, combined or split document; its sources are already in the shared `services.sources`), `edit(_ name: String, coalesceKey: String?, _ change: (inout FolioDocumentState) throws(FolioEditError) -> Void)` (internal), `endCoalescing()`, `var refusal: FolioRefusal?`, `dismissRefusal()`, `pageText(_:) -> FolioPageText?` (a page's `recognizedText` first), `didLoadText(_:for:)`, `var textLoading: (loaded: Int, total: Int)`, `var tool: FolioTool`, `selectTool(_:)` |
| `Workspace/FolioWorkspace+History.swift` (foundation) | `undo()`, `redo()`, `var undoTitle: String?`, `var redoTitle: String?` |
| `FolioPageSummary.swift` (foundation) | `pageSummary(_ number: Int) -> String` (the accessibility value of `folio.page.<n>`, grammar in section 5), `var statusPills: [String]` (zoom, size, "Page n of m", and "Text recognized" or "No text: Recognize…" from the pages' text origin) |
| `Workspace/FolioWorkspace+Read.swift` (reader) | `beginOpen(name:)`, `finishOpen(_: Result<FolioOpened, FolioOpenError>)`, `var needsPassword: Bool`, `setZoom(_: FolioZoom)`, `zoomIn()`, `zoomOut()` (the steps 50 to 400% of P-T2), `setViewMode(_: FolioViewMode)`, `go(toPage:)`, `go(toLabel:) throws(FolioEditError)`, `back()`, `forward()`, `didScroll(toPage:)`, `var recent: [FolioRecentFile]`, `setRecent(_:)` |
| `Workspace/FolioWorkspace+Find.swift` (find) | (synchronous over loaded page text, PB-5) `setFindText(_:)`, `setMatchCase(_:)`, `setWholeWords(_:)`, `findNext()`, `findPrevious()`, `closeFind()`, `var findHits: [FolioSearchHit]`, `var findCurrent: Int?`, `var findStatus: String` |
| `Workspace/FolioWorkspace+Markup.swift` (markup) | `beginTextDrag(at:on:)`, `moveTextDrag(to:)`, `endTextDrag()`, `selectWord(at:on:)`, `selectLine(at:on:)`, `selectAllText(on:)`, `var textSelection: FolioTextSelection`, `copyText() -> String` (through `TextSelecting.copyText`), `mark(_: FolioMarkupStyle)`, `addNote(at:on:)`, `addTextBox(at:on:)`, `setMarkText(_:)`, `beginInk(at:on:)`, `addInkPoint(_:)`, `endInk()`, `beginShape(_:at:on:)`, `moveShape(to:)`, `endShape()`, `selectMark(_:)`, `moveSelectedMark(dx:dy:)`, `resizeSelectedMark(to:)`, `setMarkColor(_:)`, `setMarkStyle(_: FolioMarkStyle)` (font size, alignment, line width, opacity, through `Annotating.setStyle`), `deleteSelectedMarks()`, `var marks: [FolioMarkRow]` |
| `Workspace/FolioWorkspace+Forms.swift` (forms) | `focusField(_:)`, `focusNextField(backward:)`, `setField(_:to:)` (coalesced per field), `checkForm() -> [FolioFieldID]`, `clearForm()`, `var focusedField: FolioFieldID?`, `var formBanner: String?` |
| `Workspace/FolioWorkspace+Sign.swift` (sign) | `beginSignatures()`, `finishSignatures(_: [FolioSignature])`, `addSignature(strokes:isInitials:) throws(FolioEditError)`, `addSignature(typed:isInitials:) throws(FolioEditError)`, `addSignature(picture: FolioBitmap, isInitials:) throws(FolioEditError)`, `removeSignature(_:)`, `exportSignatures() -> Data` (the library as JSON), `importSignatures(_: Data) throws(FolioEditError)` (merges by id; a file that isn't a library is refused with "That file isn't a Folio signature library."), `chooseSignature(_:)`, `placeSignature(at:on:)`, `var signatures: [FolioSignature]`, `var signaturesToSave: [FolioSignature]?` |
| `Workspace/FolioWorkspace+Pages.swift` (pages) | `selectPages(_:extending:)`, `rotateSelectedPages(clockwise:)`, `deleteSelectedPages()`, `moveSelectedPages(to:)`, `nudgeSelectedPages(by:)`, `insertBlankPage()`, `beginInsert(at:)`, `finishInsert(_: Result<FolioOpened, FolioOpenError>)`, `extract(range:) throws(FolioEditError) -> FolioDocumentState`, `split(after:) throws(FolioEditError) -> [FolioDocumentState]`, `beginCombine()`, `finishCombine(_: [Result<FolioOpened, FolioOpenError>]) -> FolioDocumentState?` (skipped files go to the refusal sentence), `cropSelectedPages(to:)`, `var selectedPages: [FolioPageID]` |
| `Workspace/FolioWorkspace+Files.swift` (files) | `beginSave(options:)`, `finishSave(_: Result<Data, FolioWriteError>, name:path:)`, `var saveState: FolioSaveState` (`edited`, `saved`, `failed(String)`), `setTitle(_:)`, `setAuthor(_:)` |
| `Workspace/FolioWorkspace+Export.swift` (export-convert) | `beginNewFromImages()`, `finishNewFromImages(_: Result<FolioOpened, FolioOpenError>)` (`skipped` names go to the sheet), `beginExport(_: FolioExportRequest)`, `exportProgress(page:)`, `finishExport(_:)`, `cancelExport()`, `beginReduce()`, `finishReduce(original: Int, reduced: Int)` (byte counts; not smaller → nothing written) |
| `Workspace/FolioWorkspace+OCR.swift` (ocr) | `var pagesWithoutText: [FolioPageID]`, `beginRecognize(pages:languages:)`, `didRecognize(_: FolioPageText, for:)` (stores it in `FolioPage.recognizedText` through `edit("Recognize Text", coalesceKey: "ocr")`, so one run is one undo step), `finishRecognize(_: FolioRecognizeError?)` |

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

/// UC-0 The bytes of every opened file, by source id, for the window's life.
/// Opening registers; imaging, text, writing, exporting and recognizing read.
/// The app passes memory-mapped file data, so a file deleted after opening
/// still saves. Live: `FolioModel/Live/LiveDocumentSources.swift` (an actor).
public protocol DocumentSources: Sendable {
    func register(_ id: FolioSourceID, data: Data, name: String) async
    func data(for id: FolioSourceID) async -> Data?
    func name(for id: FolioSourceID) async -> String?
}

/// UC-1 Open a PDF (or make one from images) and read its pages, fields,
/// annotations, outline and labels into a FolioDocumentState. Registers the
/// bytes in the DocumentSources the conformance was made with; the source id
/// is derived from the bytes, so reopening a saved file gets its own id.
/// Live: `FolioApp/Live/PDFKitOpening.swift` (PDFDocument(data:), unlock(withPassword:)),
/// `PDFKitImageOpening.swift` (PDFPage(image:options:)).
public protocol DocumentOpening: Sendable {
    var unavailableHelp: String? { get }
    /// Opens PDF bytes. Throws `.needsPassword` for a locked file opened with
    /// nil, `.wrongPassword` for a bad one, `.notPDF`, `.damaged`, `.tooLarge`.
    func open(_ data: Data, name: String, password: String?) async throws(FolioOpenError) -> FolioOpened
    /// One page per image, in order, each fitted inside `paper` (Letter or A4,
    /// from the locale) keeping its aspect. Inputs that aren't images are left
    /// out and listed in `skipped`; throws `.notPDF` only when none is an image.
    func open(images: [FolioImageInput], name: String, paper: FolioSize) async throws(FolioOpenError) -> FolioOpened
}

/// UC-2 See a page: the page's own content with no annotations or form
/// widgets at all (the file's own marks and fields are in the Model and the
/// view draws them, so a deleted or edited one never lingers in the picture).
/// Live: `FolioApp/Live/PDFKitImaging.swift`: PDFPage.draw(with:to:) on a copy
/// of the page whose annotations have shouldDisplay = false.
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
    /// The whole line under the point (triple-click), or an empty selection.
    func line(at point: FolioPoint, on page: FolioPageID, text: FolioPageText) -> FolioTextSelection
    /// The selection as copied text: lines inside a paragraph joined with a
    /// space, a line break after each paragraph.
    func copyText(_ selection: FolioTextSelection, text: FolioPageText) -> String
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
    /// Font size, alignment, line width, opacity (each clamped by FolioMarkStyle).
    func setStyle(_ id: FolioAnnotationID, to style: FolioMarkStyle, in doc: inout FolioDocumentState) throws(FolioEditError)
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
    /// read-only and signature fields; a radio group is one stop (its first
    /// button, or the checked one), arrows move inside it; wraps. nil when
    /// the form has no fillable field.
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
    /// From a picture the app decoded (ImageIO) to RGBA: pixels with
    /// luminance at or above 0.85 become transparent, the rest is trimmed to
    /// its ink box and kept as PNG-ready RGBA. Refuses a picture with no ink.
    func make(picture: FolioBitmap, isInitials: Bool, id: FolioSignatureID) throws(FolioEditError) -> FolioSignature
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
    /// A new document of every page of `files` in order (File > Combine Files).
    func combine(_ files: [FolioOpened], title: String) throws(FolioEditError) -> FolioDocumentState
    /// Inserts every page of another opened file at `index` (Insert from File);
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
    /// Throws `.restricted` when `options.permissions` differ from the
    /// document's and its `ownerUnlocked` is false; `.sourceMissing` when a
    /// page's source isn't in DocumentSources.
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
/// (RecognizeTextRequest, accurate level). The workspace stores the result in
/// FolioPage.recognizedText through `edit`, so it undoes and saves.
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
rotation, label, crop, `recognizedText`, `displaySize`), `FolioTextLine`
(text, one rect per Character, `endsParagraph`), `FolioTextOrigin` (`embedded`, `recognized`, `none`),
`FolioPageText`, `FolioTextSpan`, `FolioTextSelection`, `FolioSearchQuery`,
`FolioSearchHit`, `FolioAnnotationID`, `FolioMarkupStyle`, `FolioShape`,
`FolioTextAlignment`, `FolioMarkStyle` (font size, alignment, line width,
opacity, clamped), `FolioAnnotationBody` (`markup`, `note`, `freeText`,
`ink`, `shape`, `signature`, `image`), `FolioAnnotation` (with `style`); `FolioSignatureKind` is `drawn`, `typed` or `picture(FolioBitmap)`,
`FolioFieldID`, `FolioFieldKind`
(`text(multiline:maxLength:)`, `checkbox`, `radio(group:option:)`,
`choice(options:editable:)`, `signature`), `FolioFieldValue`,
`FolioFormField` (with `label`), `FolioSignatureID`, `FolioSignatureKind` (`drawn`,
`typed`, `image`), `FolioSignature`, `FolioOutlineItem`, `FolioPermissions` (with `ownerUnlocked`),
`FolioScriptKind`, `FolioDocumentState` (with `author`, `scripts`),
`FolioSkipped`, `FolioImageInput`, `FolioOpened` (with `skipped`),
`FolioBitmap`, `FolioWriteOptions` (flatten, passwords, permissions or nil
to keep, `optimizeImages`, keep OCR text),
`FolioImageFormat`, `FolioTextFormat` (`plain`, `rtf`, `docx`),
`FolioImageExport`, and the typed errors `FolioOpenError`,
`FolioEditError`, `FolioWriteError` (with `restricted`), `FolioRecognizeError`, each with the
`message` sentence the person reads. `String.folioTrimmed` stands in for
`trimmingCharacters`, which FoundationEssentials lacks.

`Fakes/FolioFakes.swift` holds the fake file format (`FolioFixtureFile`:
the line `%FOLIO-FAKE-PDF-1`, then JSON, so a cut file reads as damaged and
anything else as not a PDF; pages with lines, paragraph joins, scan flag,
recognized text, labels and picture bytes; outline; fields; marks;
passwords; restrictions; scripts), the fixed glyph layout
(`FolioFakeLayout`), `FakeDocumentSources` (an actor keyed by a hash of the
bytes, so a saved file reopens under its own id and saves again), and one
fake per contract. `FolioServices.swift` holds `FolioServices` and the
named fixtures (`letter`, `form`, `filled`, `scripted`, `scan`, `locked`,
`restricted`, `marked`, `photos`, `long`); W0 moves `FolioFixtures` into
`Sources/FolioModel/Fixtures/FolioFixtures.swift` and keeps `FolioServices`
in `FolioServices.swift`.

### 6.5 Can every tier-1 journey be built from these?

| Journey | Contract calls (in order) | Proof test |
|---|---|---|
| P-J1 Open and read | `DocumentOpening.open` (registers in `DocumentSources`), `PageImaging.image` per visible page, `PageTextReading.text`; outline and labels from the document value; zoom and pages are `FolioLayout` | `openReadAndFind` |
| P-J2 Find | `PageTextReading.text` per page, `TextFinding.find` | `openReadAndFind` |
| P-J3 Select, copy, mark | `TextSelecting.select`, `word(at:)`, `line(at:)`, `copyText`; `Annotating.mark`, `setColor`, `setText`, `delete` | `selectMarkAndCopy` |
| P-J4 Notes, text box, pen, shape | `Annotating.add` (`.note`, `.freeText`, `.ink`, `.shape`), `setStyle`, `hit`, `move`, `DocumentHistory.undo` | `selectMarkAndCopy`, `undoRedoCoalesces` |
| P-J5 Fill | `FormFilling.next` (radio group one stop), `set`, `missingRequired` (labels), `clear`; `scripts` from opening | `fillFormInTabOrder`, `openRefusals` |
| P-J6 Sign | `Signing.make(strokes:)`, `make(typed:)`, `make(picture:)`, `SignatureStoring.save`, `load`, `Signing.place` | `signIntoField` |
| P-J7 Organize | `PageOrganizing.move`, `rotate`, `delete`, `insertBlank`, `crop` | `organizeCombineSplit` |
| P-J8 Combine, extract, split | `DocumentOpening.open`, `PageOrganizing.insert`, `parseRange`, `extract`, `combine`, `split` | `organizeCombineSplit` |
| P-J9 Undo | `DocumentHistory.record`, `endCoalescing`, `undo`, `redo` | `undoRedoCoalesces` |
| P-J10 Save, reopen, flatten, password, restrictions | `DocumentWriting.write` (throws `.restricted`), `DocumentOpening.open` with and without the password | `saveRoundTripFlattenPasswordRestrictions` |
| P-J11 Open problems | `DocumentOpening.open` throwing each `FolioOpenError` | `openRefusals` |
| P-J22 New from Images | `DocumentOpening.open(images:name:paper:)` with `skipped` | `newFromImagesAndReduce` (the fake reads PNG headers) |
| P-J23 Reduce size | `DocumentWriting.write` with `optimizeImages`; byte counts compared in the workspace | `newFromImagesAndReduce`; PF-11 for real files |
| P-J20 (tier 2) Recognize | `TextRecognizing.recognize`, stored in `FolioPage.recognizedText` by `edit`, then `TextFinding.find`; saved and reopened by `DocumentWriting` and `DocumentOpening` | `recognizeKeepAndReopen` |
| P-J12 Every control | `FolioCommand.unavailableHelp(for:)` over every service's `unavailableHelp`; `FolioCommand.menu(_:)` | W0's `FolioCommandTests` |

Checklist:

- [x] One protocol per use case, each with a fake, Linux-safe, Swift 6.
- [x] `check.sh` passes (12 of 12 tests, no warnings).
- [x] Every tier-1 journey maps to contract calls and a proof test (6.5).

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
sidebar, inspector, the floating palette, the find bar and sheets. Custom
glass over the content is exactly two surfaces: the one floating palette
(`ToolbarGroup(.floating)`, at the detail's leading edge, vertically
centered; in the Page Grid it swaps its tools for the page commands, so it
stays one capsule) and the find bar (`GlassPanel` along the top edge, shown
only while finding).

### 7.1 The main window (reading, 1440 × 900)

```
┌──────────────────────────────────────────────────────────────────────────────────────────┐
│ ● ● ●  ▤ │ ◁ ▷ │ Lease — Edited      ⌂  ✦  ▱  ◐  ▦  ◎  [▣]       │ ⌕  ⬆ Share  ⓘ │ ← toolbar (glass); the
├───────────────┬──────────────────────────────────────────────────────────┬───────────────┤   switcher row centered:
│ PAGES ▾       │ ╭───╮                                                      │ DOCUMENT      │   Home, Flare, Design,
│ ┌─────┐       │ │ ↖ │    ┌─────────────────────────────┐                   │ ┌───────────┐ │   Photo, Library, Halo,
│ │ ▓▓▓ │ i     │ │ ⌶ │    │ RESIDENTIAL LEASE AGREEMENT │                   │ │Pages     3│ │   Folio (current, in
│ │ ▓▓  │       │ │ ▮ │    │ ███████ This lease is made  │                   │ │Size Letter│ │   the capsule)
│ └─────┘       │ │ U̲ │    │ between the Landlord and... │                   │ │Text  Yes  │ │
│ ┌─────┐       │ │ S̶ │    │ 1. Term. The term begins... │                   │ └───────────┘ │ ← inspector:
│ │ ▓▓  │ ii    │ │ ✎ │    │ 2. Rent. Rent is due on...  │                   │ MARKS         │   InspectorHeader + info
│ └─────┘       │ │ ☐ │    │                    [note ▣] │                   │ Highlight  1  │   card with nothing
│ ┌─────┐       │ │ T │    └─────────────────────────────┘                   │ Notes      1  │   selected; the selected
│ │ ▓   │ iii   │ │ ✍ │    ┌─────────────────────────────┐                   │               │   mark's rows when one is
│ └─────┘       │ │ ✋ │    │ 3. Deposit. The deposit...  │                   │               │
│ OUTLINE ▸     │ ╰───╯ ↑ floating palette (ToolbarGroup .floating, one glass capsule,          │
│ MARKS ▸       │         leading edge, vertically centered); pages start after its band     │
│               │                                    (100%)  (Letter 8.5 × 11 in)  (Page 1 of 3) ← ViewerStatusBar pills
└───────────────┴──────────────────────────────────────────────────────────┴───────────────┘
```

| Region | Component | Status |
|---|---|---|
| Window | `SuiteWindow` (sidebar, detail, inspector); Folio's own `-FolioWindowSize` argument | existing; the sidebar slot, window subtitle and `EditorDetail` arrive with editor-in-window (#973) |
| App switcher | `AppSwitcher` in `SuiteWindow`'s toolbar | planned by #973; **needs a seventh item** (`suite.switcher.folio`, ⌃⌘6): a `needs-ui` issue plus the suite's `SuiteApp.folio` (section 9.5) |
| Save state | window subtitle ("Edited", "Saved", "Not saved ⚠") | planned by #973 |
| Toolbar items | `ToolbarAction`: sidebar toggle, back and forward (page history), zoom menu, Find (⌘F), Share (export-convert: the system share sheet with the saved file, disabled with "Save the PDF first." while it has unsaved changes; P-J21's last step opens it), inspector toggle; one prominent action at most: none while reading | existing |
| Sidebar | `SidebarSection` + `SidebarRow` for Outline and Marks; thumbnails are a `ThumbnailGrid` (one column in the sidebar) with its caption (the page label) and its Shift and ⌘ selection | existing; ThumbnailGrid **needs** a drop-insertion line, drag reorder and keyboard reorder (`needs-ui`, section 9.5) |
| Page view | content: Folio's own view (`PageView/`), pages on `SuiteColor.canvasSurround`, centered, a 16 pt gap between pages | Folio-owned content view, no look-alike control in it |
| Tool palette | `ToolbarGroup(style: .floating)` | existing (Flare) |
| Status | `ViewerStatusBar` pills as it draws them: zoom percent, page size, then the trailing slot: "Page n of m", and "Text recognized" or the warning pill "No text: Recognize…" | existing |
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

### 7.3 Organize pages (View > Page Grid, ⌥⌘4)

```
┌───────────────┬───────────────────────────────────────────────────────────┬──────────────┐
│ PAGES         │  ┌─────┐  ┌─────┐  ┌─────┐  ┌─────┐  ┌─────┐                │ PAGE 3       │
│ (sidebar      │  │ ▓▓▓ │  │ ▓▓  │  │╔═══╗│  │ ▓▓  │  │     │                │ ┌──────────┐ │
│  hidden in    │  │ ▓▓  │  │ ▓   │  │║▓▓ ║│  │ ▓   │  │     │                │ │Size  A4  │ │
│  the grid)    │  └─────┘  └─────┘  │╚═══╝│  └─────┘  └─────┘                │ │Rotation 0│ │
│               │     1        2     └─────┘     4    ▏   5  ← drop line      │ └──────────┘ │
│               │                       3 (selected: accent outline)         │ ↻ Rotate     │
│               │  (the floating palette at the leading edge swaps its tools for  │ ⊕ Insert…    │
│               │   ↻ ↺ ⊕Blank ⊕File… ⇪Extract ✂Crop 🗑 while the grid shows)   │ 🗑 Delete     │
│               │                                                              │              │
└───────────────┴───────────────────────────────────────────────────────────┴──────────────┘
```

`ThumbnailGrid` in the detail (existing; its drop line and drag reorder are
the `needs-ui` above), the same floating palette with the page commands in
place of the tools (existing), `InspectorAction` rows for the selected page
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
the sheet a system sheet with `Picker`, `Toggle(.checkbox)`, `Button`. (Apple docs: RadioGroupPickerStyle, CheckboxToggleStyle.)

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
| File | New from Images… (⇧⌘N), Import from iPhone ▸ Scan Documents (Continuity Camera), Open… (⌘O), Open Recent ▸, Combine Files…, Close (⌘W), Save (⌘S), Save As… (⇧⌘S), Export… (⌥⌘E), Reduce File Size…, Print… (⌘P) | reader, files, pages, export-convert |
| Edit | Undo (⌘Z), Redo (⇧⌘Z), Cut (⌘X: copies the selected marks and deletes them), Copy (⌘C: selected text as plain text, or selected marks), Paste (⌘V: marks copied from Folio land on the current page; plain text becomes a text box; an image becomes an image mark), Delete (no key equivalent; Delete is handled by the focused page view or thumbnails), Select All (⌘A: all text on the page), Find ▸ Find… (⌘F), Find Next (⌘G), Find Previous (⇧⌘G) | foundation (undo), markup (cut, copy, paste, select), find |
| View | Single Page (⌥⌘1), Continuous (⌥⌘2), Two Pages (⌥⌘3), Page Grid (⌥⌘4), Actual Size (⌘1), Fit Page (⌘0), Fit Width (⌘9), Zoom In (⌘+), Zoom Out (⌘−), Back (⌘[), Forward (⌘]), Go to Page… (⌥⌘G), Show Sidebar (⌃⌘S), Show Inspector (⌥⌘I) | reader, pages |
| Markup | Highlight (⌃⌘H), Underline (⌃⌘U), Strike Out (⌃⌘K), Add Note (⌃⌘N), Add Text Box (⌃⌘T), Pen, Shape ▸, Sign ▸; conditional W4: Edit Text, Redact | markup, sign, content-edit |
| Form | Next Field and Previous Field (shown with Tab and Shift-Tab in their help, no key equivalent; the focused field handles the keys), Check Form, Clear Form | forms |
| Page | Rotate Right (⌘R), Rotate Left (⌘L), Move Left (⌥⌘←), Move Right (⌥⌘→), Insert Blank Page (⇧⌘B), Insert from File… (⇧⌘I), Delete Page (⌘⌫), Crop Pages…, Extract Pages…, Split… | pages |
| Tools | Recognize Text…; conditional W4: Apply Redactions… | ocr, content-edit |
| Window | Switch To ▸ (suite), the system's items | suite |

Tool shortcuts while the page view has focus (design.md, Canvas apps):
V Select, T Text Select, H Highlight, U Underline, K Strike Out, N Note,
X Text Box, P Pen, R Shape, S Sign, G Hand (and Space-drag from any tool); conditional W4: E Edit
Text, D Redact. Every item above is listed by `FolioCommand.menu(_:)`,
which P-J12 compares with the real menus.

### 7.7 SuiteUI Folio needs (filed as `needs-ui` by the named feature)

| Need | For | Filed by |
|---|---|---|
| `AppSwitcher` seventh item and ⌃⌘6, once `SuiteApp` gains `.folio` | the switcher row | foundation (with the suite line's `SuiteApp.folio` task) |
| `ThumbnailGrid`: a drop-insertion line, drag reorder, keyboard reorder (⌥⌘← →); it already has captions and Shift and ⌘ selection | sidebar and Page Grid | pages |
| A pad view for drawing a signature: a flat drawing well with Clear, keyboard alternative "Type instead" | signature sheet | sign; placeholder: a SwiftUI `Canvas` in FolioApp until it lands |
| `ViewerStatusBar` trailing slot accepting a button pill ("Recognize…") | the no-text pill | ocr; placeholder: a menu item and the inspector row |

Checklist:

- [x] `SuiteWindow`, Flare's floating palette and the switcher row, per the 2026-10-15 decisions.
- [x] Each screen lists the SuiteUI and system components it uses.
- [x] Each missing component has a `needs-ui` owner and a placeholder (7.7, 9.5).

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
late, read from the frame probe (`FrameProbe`, SuiteUI, with the journey
helpers in `UITests/Journey+Input.swift`) in the perf journeys P-P1 to P-P6.
Every new row ships report-only, as the rubric sets it, until ten green
runs set its gate as a constant in `UITests/FolioJourneyTests+Perf.swift`
(core-loop), as Suite does in `SuiteJourneyTests+Budgets.swift`.

| id | Tool | What is timed | Fixture | Device target | CI gate | Test | Feature |
|---|---|---|---|---|---|---|---|
| PB-1 | Open | `DocumentOpening.open` + `finishOpen` on the fake; on the live type, first page drawn | `long` (500 pages) | fake ≤ 20 ms; live first page on screen ≤ 300 ms (QB-L9: progress shown ≤ 100 ms) | fake ≤ 200 ms debug; live report-only | `FolioFoundationBudgetTests.openLong`; P-P1 | foundation, reader |
| PB-2 | Layout | `FolioLayout` for every page (continuous, fit width) | `long` | ≤ 2 ms | ≤ 20 ms debug | `FolioReaderBudgetTests.layoutLong` | reader |
| PB-3 | Scroll | `visiblePages(in:)` per scroll step | `long` | ≤ 0.2 ms | ≤ 2 ms debug | `FolioReaderBudgetTests.visiblePages`; UI half P-P2: p95 frame interval ≤ 1.5 refreshes (QB-L10) | reader |
| PB-4 | Zoom | one `setZoom` + layout | `long` | ≤ 2 ms | ≤ 20 ms debug | `FolioReaderBudgetTests.zoomStep`; P-P3 ≤ 2 frames late | reader |
| PB-5 | Find | `TextFinding.find` over all page text | `long` (20,000 lines) | ≤ 50 ms for the whole document (synchronous, so the first hit shows in the same refresh) | ≤ 500 ms debug | `FolioFindBudgetTests.findLong` | find |
| PB-6 | Text select drag | one `select(from:to:)` step | `letter` page 1 and a `long` page | ≤ 0.5 ms | ≤ 5 ms debug | `FolioMarkupBudgetTests.selectStep`; P-P4 ≤ 2 frames late (QB-L1) | markup |
| PB-7 | Highlight | `mark` + workspace `edit` record | `long1000marks` (markup's fixture) | ≤ 1 ms | ≤ 10 ms debug | `FolioMarkupBudgetTests.markStep` | markup |
| PB-8 | Move or resize a mark | one drag step | `long1000marks` | ≤ 1 ms | ≤ 10 ms debug | `FolioMarkupBudgetTests.moveMarkStep`; P-P4 | markup |
| PB-9 | Hit test | `Annotating.hit` per pointer move | `page1000marks` (markup's fixture: 1,000 marks on page 1 of `letter`) | ≤ 1 ms (QB-L5) | ≤ 10 ms debug | `FolioMarkupBudgetTests.hit` | markup |
| PB-10 | Pen | one ink point appended | a 2,000-point stroke the test generates on `letter` | ≤ 0.2 ms | ≤ 2 ms debug | `FolioMarkupBudgetTests.inkPoint`; P-P5 ≤ 2 frames late (QB-L1) | markup |
| PB-11 | Type in a field | one `FormFilling.set` + record (coalesced) | `form200` (forms' fixture: 200 fields over 10 pages) | ≤ 1 ms | ≤ 10 ms debug | `FolioFormsBudgetTests.fieldKeystroke` | forms |
| PB-12 | Place a signature | `Signing.place` | `form` | ≤ 1 ms | ≤ 10 ms debug | `FolioSignBudgetTests.placeSignature` | sign |
| PB-13 | Page reorder drag | one `move` + thumbnail list rebuild | `long` | ≤ 2 ms | ≤ 20 ms debug | `FolioPagesBudgetTests.reorderLong`; P-P6 ≤ 2 frames late | pages |
| PB-14 | Undo, Redo | one step | `long` after 1,000 note edits made in the test | ≤ 2 ms | ≤ 20 ms debug | `FolioFoundationBudgetTests.undoStep` | foundation |
| PB-15 | Save | live `PDFKitWriting.write` | `big50` (files' fixture: 50 pages, about 5 MB of pictures, 100 marks) written as a sample | ≤ 1 s release, progress ≤ 100 ms (QB-L9) | report-only | `FolioWritingBudgetTests` (macOS) | files |
| PB-16 | Recognize text | live Vision, accurate, per page | `scan300` (ocr's fixture: scanned pages the sample writer renders at 300 ppi) | ≤ 1.5 s per page release; progress per page | report-only | `FolioOCRBudgetTests` (macOS) | ocr |
| PB-17 | Thumbnail | live `PageImaging.image(maxPixels: 256)` | `long` sample | ≤ 15 ms per page | report-only | `FolioImagingBudgetTests` (macOS) | reader |
| PB-18 | New from Images | fake `open(images:)` of 20 PNG headers + `finishNewFromImages`; live: 20 photos to pages | generated in the test | fake ≤ 5 ms; live ≤ 2 s release, progress ≤ 100 ms | fake ≤ 50 ms debug; live report-only | `FolioExportBudgetTests.newFromImages` (Linux); `FolioExportTests` (macOS) | export-convert |
| PB-19 | Reduce File Size | live write with `optimizeImages` | `photos` sample | ≤ 3 s release, progress ≤ 100 ms (QB-L9) | report-only | `FolioReduceSizeTests` (macOS) | export-convert |
| PB-20 | Export pages as images | live 3 pages at 300 ppi | `letter` sample | < 1 s release (Folio's own target: three pages, not QB-L8's 48 frames) | report-only | `FolioExportTests` (macOS) | export-convert |
| PB-21 | Combine | `PageOrganizing.combine` of `long` with `long` | `long` | ≤ 5 ms | ≤ 50 ms debug | `FolioPagesBudgetTests.combineLong` | pages |

Every row above names a fixture from section 6 (`long`, `form`, `letter`,
`photos`) or one its feature adds in its own fixtures file (`long1000marks`,
`page1000marks`, `form200`, `big50`, `scan300`) or data the test generates, written as a real PDF by `FolioSampleWriter`
(`-FolioWriteSample`), and a test in a file its feature owns (section 9);
none is judged by eye.

### 8.2 App-audit checks

All six checks of `docs/blueprints/app-audit.md` run on every Folio shot:
`disabled-dim`, `overlap`, `contrast`, `identifier`, `offscreen`,
`unnamed`. Folio is new, so it enters `UITests/audit-baseline.json` at **0
for every check** in W0's PR (adding a new app at 0 is not a loosening; a
count above 0 would need the captain). Every Folio control ships with a
`folio.<area>.<name>` identifier and a label.

| Check | Target | How Folio holds it | Measured by |
|---|---|---|---|
| `identifier`, `unnamed` | 0 | every control in FolioApp has `.accessibilityIdentifier("folio.…")` and a label; form-field views use the field's name and tooltip as label | `audit-folio-*.json`; `FolioCommandTests` (Linux: every `FolioCommand` has a title and identifier) |
| `offscreen` | 0 | layout spec 8.3 at 1024 × 768 | same, plus PL1 |
| `overlap` | 0 | the floating palette never covers the status pills or the find bar (PL4) | same |
| `contrast` | 0 | only tokens; the page is document content and its marks use document colours, but the selection outline, find tint and handles are tokens | same |
| `disabled-dim` | 0 | every disabled control is a system or SuiteUI control drawn disabled from `unavailableHelp` | same |

### 8.3 Layout spec

Checked at window sizes **minimum** (`SuiteSize.windowMinimum`, read from
the tokens at test time: 880 × 560 on `dev` today, 944 × 560 once #973's
editor inspector lands), **1024 × 768** (the CI runner's display), **1280 × 800**,
**1440 × 900** and **1920 × 1080**, through `-FolioWindowSize`, with the
`letter` fixture open and page 1 selected (W0); core-loop repeats the
sizes with a highlight selected and the find bar open (PL1, PL4).

| id | Rule | Tolerance | Measured by |
|---|---|---|---|
| PL1 | Nothing off the window; no two enabled controls overlap | the audit's own (1 pt slack, 2 pt overlap) | `testLayoutAtWidths` (`FolioJourneyTests.swift`, W0) on the plain window, then `testLayoutWithMarksAndFind` (`+Loop`, core-loop) with marks and the find bar: relaunch at each size, shoot `folio-layout-<w>` |
| PL2 | The page column starts after the palette's band (the palette's leading inset 12 pt + its width + 12 pt) and ends 24 pt before the detail's trailing edge; Fit Width makes the page exactly that column's width; Fit Page shows the whole page inside it | ≤ 1 pt | same journey reads `folio.page.1`'s frame; Linux half `FolioLayoutTests.fitWidth`, `.fitPage` |
| PL3 | Pages are centered in the page column (PL2), 16 pt apart, so at Fit Width and any smaller zoom no page lies under the palette | centers ≤ 1 pt; gap ≤ 0.5 pt | same; Linux half `FolioLayoutTests.column` |
| PL4 | The floating palette sits 12 pt in from the detail's leading edge, vertically centered, and never overlaps the status pills or the find bar at any width | 0 pt overlap | core-loop's `testLayoutWithMarksAndFind` (`+Loop`) reads the frames of `suite.tools`, `folio.find` and `folio.status` (the identifier reader's `FolioPageView` puts on its `ViewerStatusBar`) |
| PL5 | At the minimum window with the sidebar collapsed and the inspector shown, Fit Width shows a page ≥ 320 pt wide (computed from the tokens at test time; with #973's values 944 − 304 inspector − 68 palette band − 24 = 548 pt of column); with the sidebar shown too, ≥ 320 pt or the inspector hides on ⌥⌘I and the page widens | ≥ 320 pt | same, at minimum |
| PL6 | Thumbnails: one column in the sidebar, each ≤ the sidebar width − 24 pt, captions never truncate below 4 digits ("1234") | ≤ 0.5 pt | `FolioThumbnailLayoutTests` (macOS host) |
| PL7 | Page Grid: as many columns as fit at 160 pt per thumbnail plus 16 pt gaps, at least 2 | exact column count | `FolioGridLayoutTests.columns` (Linux) at 600, 900, 1400 pt |
| PL8 | Form fields drawn over the page stay inside their PDF rect at every zoom from 50% to 400% | ≤ 0.5 pt after scale | `FolioFieldOverlayTests` (macOS host) |

### 8.4 Fidelity tests (output equals a reference)

| id | Output | Reference | Tolerance | Test (where) | Feature |
|---|---|---|---|---|---|
| PF-1 | Live `PageImaging` of a sample page `FolioSampleWriter` draws with known content: a filled square of a known colour at a known rect and a text line | the known pixels (the square's colour inside its rect, white outside) | channel ≤ 2/255 | `FolioImagingFidelityTests` (macOS) | reader |
| PF-14 | Live `PageImaging` of a sample with a file highlight and a filled text field (written by `FolioSampleWriter+Marks` and `+Fields`) over a blank area | the blank area stays white: annotations and widgets hidden (Apple docs: PDFAnnotation.shouldDisplay), drawn only by Folio from the Model | exactly white | `FolioLoopFidelityTests` (macOS) | core-loop |
| PF-15 | Every mark Folio saves has an appearance stream, so other readers draw it (1A, pain point 2) | the saved file reopened: each annotation's `hasAppearanceStream` (Apple docs: PDFAnnotation) | all true, for every annotation kind of P-T7 to P-T10 | `FolioAnnotationInteropTests` (macOS) | markup |
| PF-16 | Saving an opened file with no edits (1A, pain point 3) | the original | no password added; every page's text equal (`PageTextReading`); page count equal; size within +10% | `FolioSaveIntegrityTests` (macOS, every fixture as a sample) | files |
| PF-2 | `PDFKitText.text(of:)` of a sample written by `FolioSampleWriter` with known strings at known points | the strings and their positions the writer used | strings exact; glyph boxes ≤ 1 pt | `FolioTextFidelityTests` (macOS) | reader |
| PF-3 | Saved file reopened: pages, order, rotation, crop, title (files, W1, `FolioRoundTripTests`); field values, annotation kinds, rects and colours (core-loop, `FolioLoopFidelityTests`, once forms and markup map them) | the `FolioDocumentState` that was saved | exact for values; rects ≤ 0.01 pt; colours ≤ 1/255 | both (macOS, every fixture as a sample) | files, core-loop |
| PF-4 | A page with Folio's marks drawn on screen vs the same page exported to PNG at the same scale | each other | channel ≤ 2/255, ≤ 0.5% of pixels (QB-V4: what you see is what you export) | `FolioMarksFidelityTests` (macOS) | markup, export-convert |
| PF-5 | Flatten: a flattened save has no annotation or widget objects, and its pixels equal the unflattened save's | the unflattened save rendered | annotation count 0; pixels as PF-4 | `FolioLoopFidelityTests` (macOS) | core-loop |
| PF-6 | Password save: opening with no password throws `.needsPassword`, with the wrong one `.wrongPassword`, with the right one equals the saved state; owner restrictions read back as set; a restricted file opened without its owner password refuses to save changed restrictions (`.restricted`) | the options used | exact | `FolioPasswordTests` (macOS) | files |
| PF-7 | Combine `letter` + `form`: page count, order, every field name (a taken name gets " 2"), every value | the two inputs | exact | `PageOrganizingContractTests` (Linux) and `FolioCombineRoundTripTests` (macOS) | pages |
| PF-8 | OCR on a sample rendered from known lines at 300 ppi | the known lines | character error rate ≤ 1% on the clean sample; found by Find afterwards | `FolioOCRFidelityTests` (macOS) | ocr |
| PF-9 | Saved OCR text layer: `PDFKitWriting+TextLayer.swift` (ocr's seam into the writer, W0 stub) re-renders each page that has `recognizedText`: it draws the page with `PDFPage.draw(with:to:)` into a CoreGraphics PDF context (Apple docs: CGContext init(consumer:mediaBox:_:)), annotations hidden, adds the lines as invisible text (Apple docs: CGTextDrawingMode.invisible) at their glyph boxes, then puts the original page's annotations back on the new page; after Save and reopen, `PageTextReading` returns the recognized lines with origin `embedded` and the page's pixels are unchanged | the recognized text; the page before save | strings exact; pixels as PF-1 | `FolioOCRRoundTripTests` (macOS) | ocr |
| PF-10 | Export PNG at 72, 150, 300 ppi | page size × ppi / 72 | pixel size exact | `FolioExportTests` (macOS) and `PageExportingContractTests` (Linux) | export-convert |
| PF-11 | Reduce File Size on the `photos` sample (300 ppi photos) | the original | output ≤ 60% of the input's bytes, every page's text equal, pixels within channel ≤ 12/255 at 1× (images re-encoded); report-only until Q9 is answered: the test records the ratio and fails only if the output is larger than the input | `FolioReduceSizeTests` (macOS) | export-convert |
| PF-12 | Signature placed in a field, saved, reopened | the placed rect and the signature's strokes | rect ≤ 0.01 pt; stroke points ≤ 0.1 pt | `FolioSignatureRoundTripTests` (macOS) | sign |
| PF-13 | (W4) Redaction: text extracted from a redacted region after save, and every content stream's decoded bytes | nothing; the removed strings | no text; no occurrence | `FolioRedactionTests` (macOS) and CP-4's own tests (Linux, creative-core) | content-edit |

### 8.5 Feel (rubric section 6)

| id | How Folio meets it | Measured by |
|---|---|---|
| QB-F1 No dead controls | every command's availability is `unavailableHelp(for:)`; every enabled palette tool's `drag` on `letter` changes the workspace (document, selection or viewport: Hand pans, Text Select selects) or the tool is disabled with help | `FolioToolsTests`, `FolioCommandTests` (Linux); P-J12 |
| QB-F2 Immediate feedback | a text drag shows the selection before mouse-up; a pen stroke draws as it goes; a refused edit shows its sentence at the place it was refused | the probe's preview mark (P-P4, P-P5); journey asserts |
| QB-F3 One gesture, one named step | `edit(_:coalesceKey:_:)` names every step ("Undo Highlight", "Undo Move Page", "Undo Typing"); scroll, zoom and find are never steps | Model tests count undo steps; journeys read the Edit menu |
| QB-F4 Keyboard parity | every tool has a one-key shortcut; Tab and Shift-Tab walk form fields and the arrows pick inside a radio group; arrows move a selected mark 1 pt (Shift 10 pt); ⌥⌘← → move a selected page | P-J5 (Tab, →), P-J7 (⌥⌘→), P-J4 (arrows on the note, added by the markup feature) |
| QB-F5 Reduce Motion, Increase Contrast | page scroll is content; zoom is instant under Reduce Motion; goldens in Increase Contrast | goldens |
| QB-F6 Geometry holds | only SuiteUI components and tokens in chrome | design lint |

Checklist:

- [x] Every budget names a fixture that exists, a number, and a test in a file its feature owns.
- [x] The audit enters at 0 for every check.
- [x] Every layout rule has a tolerance and a test; every fidelity test has an independent reference.

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
and every wait on an earlier wave. Run on 2026-10-15 after critic round 2:
`WAVES: PASS (12 features, 143 agent-hours)`.

```
W0  foundation (P-T17, P-T30) ───────────────────────────────── waits on nothing
        │                                                        (+ supervisor: Package.swift, bundle-apps, CLAUDE.md, AGENTS.md)
        ├──▶ W1  reader          (P-T1, P-T2, P-T3, P-T19)
        ├──▶ W1  find            (P-T6)
        ├──▶ W1  markup          (P-T5, P-T7–P-T10)            six leads side by side,
        ├──▶ W1  forms           (P-T11, P-T12)                 no shared file
        ├──▶ W1  pages           (P-T3 thumbnails, P-T13–P-T16)
        └──▶ W1  files           (P-T18, P-T20, P-T26)
                 │
                 ├──▶ W2  sign            after markup, forms
                 ├──▶ W2  export-convert  after files, markup   (P-T4, P-T22–P-T25)
                 └──▶ W2  ocr             after reader, find, markup, files
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
| W0 | `foundation` | nothing (its first PR is supervisor-merged) | 15 PRs: targets, C4 containers and the CLAUDE.md line (supervisor); values; protocols; fakes (two PRs); source store, fixtures and services; workspace state, `edit`, undo and redo; commands and availability; tools; layout, the whole page summary and status pills; launch arguments and the sample-writer seam; window shell, thumbnails, the overlay, navigator, inspector, sample-writer and text-layer seams with their stubs, area stubs; live stubs; contract suites; the every-control and layout journeys; audit entry | 24 |
| W1 | `reader` | foundation | 8 | 13 |
| W1 | `find` | foundation | 4 | 6 |
| W1 | `markup` | foundation | 9 | 15 |
| W1 | `forms` | foundation | 6 | 10 |
| W1 | `pages` | foundation | 8 | 13 |
| W1 | `files` | foundation | 6 | 10 |
| W2 | `sign` | filed once markup and forms are done; the later of the two | 6 | 10 |
| W2 | `export-convert` | the later of files and markup | 7 | 12 |
| W2 | `ocr` | the last of reader, find, markup, files | 5 | 8 |
| W3 | `core-loop` | the last W1 or W2 feature to finish | 4 | 6 |
| W4 | `content-edit` | core-loop, and creative-core CP-1 to CP-5 closed | 8 | 16 |

Totals: W0 24 agent-hours; W1 67 (about 12 wall-clock hours with six leads
in parallel); W2 30; W3 6; W4 16 (plus the creative-core work, estimated
there). 143 agent-hours for Folio's own work; v1 without W4 is 127.

### 9.2 Features and their owned files

Generated by `python3 docs/blueprints/pdf/waves.py --markdown`.

#### W0 · `foundation`: Foundation: targets, contracts, fakes, workspace, the window's seams

- **Covers:** P-T17 (undo and redo), P-T30 (no dead controls); open and show pages on fakes, thumbnails that go to a page, the complete page summary and status pills, the overlay, sidebar, inspector, sample-writer and text-layer seams, the source store; the targets, C4 and the audit entry
- **Waits on:** nothing
- **Proves:** P-J0, P-J12, P-J13 (PL2, PL3, PL5); PB-1 (fake half), PB-14
- **Estimate:** about 15 PRs, 24 agent-hours
- **Owned files (152):** `Sources/FolioModel/Contracts/FolioValues.swift`, `Sources/FolioModel/Contracts/FolioContracts.swift`, `Sources/FolioModel/Fakes/FolioFakeFile.swift`, `Sources/FolioModel/Fakes/FakeDocumentOpening.swift`, `Sources/FolioModel/Fakes/FakePageImaging.swift`, `Sources/FolioModel/Fakes/FakePageTextReading.swift`, `Sources/FolioModel/Fakes/FakeTextFinding.swift`, `Sources/FolioModel/Fakes/FakeTextSelecting.swift`, `Sources/FolioModel/Fakes/FakeAnnotating.swift`, `Sources/FolioModel/Fakes/FakeFormFilling.swift`, `Sources/FolioModel/Fakes/FakeSigning.swift`, `Sources/FolioModel/Fakes/FakeSignatureStore.swift`, `Sources/FolioModel/Fakes/FakePageOrganizing.swift`, `Sources/FolioModel/Fakes/FakeDocumentHistory.swift`, `Sources/FolioModel/Fakes/FakeDocumentWriting.swift`, `Sources/FolioModel/Fakes/FakePageExporting.swift`, `Sources/FolioModel/Fakes/FakeTextRecognizing.swift`, `Sources/FolioModel/Fakes/FakeDocumentSources.swift`, `Sources/FolioModel/Fixtures/FolioFixtures.swift`, `Sources/FolioModel/FolioServices.swift`, `Sources/FolioModel/FolioWorkspace.swift`, `Sources/FolioModel/FolioCommand.swift`, `Sources/FolioModel/FolioTool.swift`, `Sources/FolioModel/FolioLaunch.swift`, `Sources/FolioModel/FolioLayout.swift`, `Sources/FolioModel/FolioPageSummary.swift`, `Sources/FolioModel/Fixtures/FolioFixtures+Markup.swift`, `Sources/FolioModel/Fixtures/FolioFixtures+Forms.swift`, `Sources/FolioModel/Fixtures/FolioFixtures+Files.swift`, `Sources/FolioModel/Fixtures/FolioFixtures+OCR.swift`, `Sources/FolioModel/Workspace/FolioWorkspace+Read.swift`, `Sources/FolioModel/Workspace/FolioWorkspace+Find.swift`, `Sources/FolioModel/Workspace/FolioWorkspace+Markup.swift`, `Sources/FolioModel/Workspace/FolioWorkspace+Forms.swift`, `Sources/FolioModel/Workspace/FolioWorkspace+Sign.swift`, `Sources/FolioModel/Workspace/FolioWorkspace+Pages.swift`, `Sources/FolioModel/Workspace/FolioWorkspace+History.swift`, `Sources/FolioModel/Workspace/FolioWorkspace+Files.swift`, `Sources/FolioModel/Workspace/FolioWorkspace+Export.swift`, `Sources/FolioModel/Workspace/FolioWorkspace+OCR.swift`, `Sources/FolioModel/Availability/FolioAvailability+Read.swift`, `Sources/FolioModel/Availability/FolioAvailability+Find.swift`, `Sources/FolioModel/Availability/FolioAvailability+Markup.swift`, `Sources/FolioModel/Availability/FolioAvailability+Forms.swift`, `Sources/FolioModel/Availability/FolioAvailability+Sign.swift`, `Sources/FolioModel/Availability/FolioAvailability+Pages.swift`, `Sources/FolioModel/Availability/FolioAvailability+History.swift`, `Sources/FolioModel/Availability/FolioAvailability+Files.swift`, `Sources/FolioModel/Availability/FolioAvailability+Export.swift`, `Sources/FolioModel/Availability/FolioAvailability+OCR.swift`, `Sources/FolioModel/Tools/FolioTool+Select.swift`, `Sources/FolioModel/Tools/FolioTool+TextMarkup.swift`, `Sources/FolioModel/Tools/FolioTool+Annotate.swift`, `Sources/FolioModel/Tools/FolioTool+Sign.swift`, `Sources/FolioModel/Live/LiveTextFinding.swift`, `Sources/FolioModel/Live/LiveTextSelecting.swift`, `Sources/FolioModel/Live/LiveAnnotating.swift`, `Sources/FolioModel/Live/LiveFormFilling.swift`, `Sources/FolioModel/Live/LiveSigning.swift`, `Sources/FolioModel/Live/LiveSignatureStore.swift`, `Sources/FolioModel/Live/LivePageOrganizing.swift`, `Sources/FolioModel/Live/LiveDocumentHistory.swift`, `Sources/FolioModel/Live/LiveDocumentSources.swift`, `Sources/FolioApp/FolioApp.swift`, `Sources/FolioApp/FolioWindow.swift`, `Sources/FolioApp/PageView/FolioPageView.swift`, `Sources/FolioApp/PageView/FolioPageGestures.swift`, `Sources/FolioApp/PageView/FolioPageOverlays.swift`, `Sources/FolioApp/PageView/FolioMarksLayer.swift`, `Sources/FolioApp/PageView/FolioFieldLayer.swift`, `Sources/FolioApp/PageView/FolioSelectionLayer.swift`, `Sources/FolioApp/PageView/FolioFindHitsLayer.swift`, `Sources/FolioApp/PageView/FolioRedactionLayer.swift`, `Sources/FolioApp/Sidebar/FolioNavigator.swift`, `Sources/FolioApp/Sidebar/FolioThumbnails.swift`, `Sources/FolioApp/Inspector/FolioInspector.swift`, `Sources/FolioApp/Live/FolioServices+Live.swift`, `Sources/FolioApp/Sidebar/FolioOutline.swift`, `Sources/FolioApp/Sidebar/FolioFindResults.swift`, `Sources/FolioApp/Sidebar/FolioMarksList.swift`, `Sources/FolioApp/Inspector/FolioMarkInspector.swift`, `Sources/FolioApp/Inspector/FolioFieldInspector.swift`, `Sources/FolioApp/Inspector/FolioDocumentInspector.swift`, `Sources/FolioApp/Inspector/FolioPageInspector.swift`, `Sources/FolioApp/Live/FolioSampleWriter+Marks.swift`, `Sources/FolioApp/Live/FolioSampleWriter+Fields.swift`, `Sources/FolioApp/Live/FolioSampleWriter+Scan.swift`, `Sources/FolioApp/Live/FolioSampleWriter+Photos.swift`, `Sources/FolioApp/Live/PDFKitWriting+TextLayer.swift`, `Sources/FolioApp/FolioWindow+Read.swift`, `Sources/FolioApp/FolioWindow+Find.swift`, `Sources/FolioApp/FolioWindow+Markup.swift`, `Sources/FolioApp/FolioWindow+Forms.swift`, `Sources/FolioApp/FolioWindow+Sign.swift`, `Sources/FolioApp/FolioWindow+Pages.swift`, `Sources/FolioApp/FolioWindow+History.swift`, `Sources/FolioApp/FolioWindow+Files.swift`, `Sources/FolioApp/FolioWindow+Export.swift`, `Sources/FolioApp/FolioWindow+OCR.swift`, `Sources/FolioApp/FolioCommands+Read.swift`, `Sources/FolioApp/FolioCommands+Find.swift`, `Sources/FolioApp/FolioCommands+Markup.swift`, `Sources/FolioApp/FolioCommands+Forms.swift`, `Sources/FolioApp/FolioCommands+Sign.swift`, `Sources/FolioApp/FolioCommands+Pages.swift`, `Sources/FolioApp/FolioCommands+History.swift`, `Sources/FolioApp/FolioCommands+Files.swift`, `Sources/FolioApp/FolioCommands+Export.swift`, `Sources/FolioApp/FolioCommands+OCR.swift`, `Sources/FolioApp/Live/PDFKitOpening.swift`, `Sources/FolioApp/Live/PDFKitImageOpening.swift`, `Sources/FolioApp/Live/PDFKitImaging.swift`, `Sources/FolioApp/Live/PDFKitText.swift`, `Sources/FolioApp/Live/PDFKitFields.swift`, `Sources/FolioApp/Live/PDFKitAnnotations.swift`, `Sources/FolioApp/Live/PDFKitWriting.swift`, `Sources/FolioApp/Live/PDFKitExporting.swift`, `Sources/FolioApp/Live/VisionRecognizing.swift`, `Sources/FolioApp/Live/FolioSampleWriter.swift`, `Sources/FolioApp/Live/FolioSignatureMark.swift`, `Tests/FolioModelTests/DocumentOpeningContractTests.swift`, `Tests/FolioModelTests/PageImagingContractTests.swift`, `Tests/FolioModelTests/PageTextReadingContractTests.swift`, `Tests/FolioModelTests/TextFindingContractTests.swift`, `Tests/FolioModelTests/TextSelectingContractTests.swift`, `Tests/FolioModelTests/AnnotatingContractTests.swift`, `Tests/FolioModelTests/FormFillingContractTests.swift`, `Tests/FolioModelTests/SigningContractTests.swift`, `Tests/FolioModelTests/SignatureStoringContractTests.swift`, `Tests/FolioModelTests/PageOrganizingContractTests.swift`, `Tests/FolioModelTests/DocumentHistoryContractTests.swift`, `Tests/FolioModelTests/DocumentWritingContractTests.swift`, `Tests/FolioModelTests/PageExportingContractTests.swift`, `Tests/FolioModelTests/TextRecognizingContractTests.swift`, `Tests/FolioModelTests/FolioCommandTests.swift`, `Tests/FolioModelTests/FolioToolsTests.swift`, `Tests/FolioModelTests/FolioWorkspaceTests.swift`, `Tests/FolioModelTests/FolioLayoutTests.swift`, `Tests/FolioModelTests/FolioFixturesTests.swift`, `Tests/FolioModelTests/FolioPageSummaryTests.swift`, `Tests/FolioModelTests/FolioHistoryTests.swift`, `Tests/FolioModelTests/FolioBudget.swift`, `Tests/FolioModelTests/FolioFoundationBudgetTests.swift`, `Tests/AppSnapshotTests/FolioWindowSnapshots.swift`, `UITests/FolioJourneyTests.swift`, `UITests/audit-baseline.json`, `docs/c4/model.json`, `Package.swift`, `project.yml`, `scripts/bundle-apps`, `CLAUDE.md`, `AGENTS.md`

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
- **Owned files (14):** `Sources/FolioModel/Live/LiveTextFinding.swift`, `Sources/FolioModel/Fakes/FakeTextFinding.swift`, `Sources/FolioModel/Workspace/FolioWorkspace+Find.swift`, `Sources/FolioModel/Availability/FolioAvailability+Find.swift`, `Sources/FolioApp/FolioWindow+Find.swift`, `Sources/FolioApp/FolioCommands+Find.swift`, `Sources/FolioApp/PageView/FolioFindBar.swift`, `Sources/FolioApp/PageView/FolioFindHitsLayer.swift`, `Sources/FolioApp/Sidebar/FolioFindResults.swift`, `Tests/FolioModelTests/TextFindingContractTests.swift`, `Tests/FolioModelTests/FolioFindTests.swift`, `Tests/FolioModelTests/FolioFindBudgetTests.swift`, `Tests/AppSnapshotTests/FolioFindSnapshots.swift`, `UITests/FolioJourneyTests+Find.swift`

#### W1 · `markup`: Mark up: select text, highlight, underline, strike out, notes, text boxes, pen, shapes

- **Covers:** P-T5, P-T7, P-T8, P-T9, P-T10
- **Waits on:** foundation
- **Proves:** P-J3, P-J4; PB-6, PB-7, PB-8, PB-9, PB-10; PF-15
- **Estimate:** about 9 PRs, 15 agent-hours
- **Owned files (28):** `Sources/FolioModel/Live/LiveTextSelecting.swift`, `Sources/FolioModel/Live/LiveAnnotating.swift`, `Sources/FolioModel/Fakes/FakeTextSelecting.swift`, `Sources/FolioModel/Fakes/FakeAnnotating.swift`, `Sources/FolioModel/Workspace/FolioWorkspace+Markup.swift`, `Sources/FolioModel/Availability/FolioAvailability+Markup.swift`, `Sources/FolioModel/Tools/FolioTool+Select.swift`, `Sources/FolioModel/Tools/FolioTool+TextMarkup.swift`, `Sources/FolioModel/Tools/FolioTool+Annotate.swift`, `Sources/FolioApp/FolioWindow+Markup.swift`, `Sources/FolioApp/FolioCommands+Markup.swift`, `Sources/FolioApp/PageView/FolioMarksLayer.swift`, `Sources/FolioApp/PageView/FolioSelectionLayer.swift`, `Sources/FolioApp/PageView/FolioPageGestures.swift`, `Sources/FolioApp/Inspector/FolioMarkInspector.swift`, `Sources/FolioApp/Sidebar/FolioMarksList.swift`, `Sources/FolioApp/Live/PDFKitAnnotations.swift`, `Sources/FolioModel/Fixtures/FolioFixtures+Markup.swift`, `Sources/FolioApp/Live/FolioSampleWriter+Marks.swift`, `Tests/FolioModelTests/TextSelectingContractTests.swift`, `Tests/FolioModelTests/AnnotatingContractTests.swift`, `Tests/FolioModelTests/FolioMarkupTests.swift`, `Tests/FolioModelTests/FolioToolsTests.swift`, `Tests/FolioModelTests/FolioMarkupBudgetTests.swift`, `Tests/AppSnapshotTests/FolioMarkupSnapshots.swift`, `Tests/AppSnapshotTests/FolioAnnotationInteropTests.swift`, `UITests/FolioJourneyTests+Markup.swift`, `UITests/FolioJourneyTests+Annotate.swift`

#### W1 · `forms`: Fill forms: fields over the page, Tab order, required fields, clear

- **Covers:** P-T11, P-T12
- **Waits on:** foundation
- **Proves:** P-J5; PB-11; PL8
- **Estimate:** about 6 PRs, 10 agent-hours
- **Owned files (17):** `Sources/FolioModel/Live/LiveFormFilling.swift`, `Sources/FolioModel/Fakes/FakeFormFilling.swift`, `Sources/FolioModel/Workspace/FolioWorkspace+Forms.swift`, `Sources/FolioModel/Availability/FolioAvailability+Forms.swift`, `Sources/FolioApp/FolioWindow+Forms.swift`, `Sources/FolioApp/FolioCommands+Forms.swift`, `Sources/FolioApp/PageView/FolioFieldLayer.swift`, `Sources/FolioApp/Inspector/FolioFieldInspector.swift`, `Sources/FolioApp/Live/PDFKitFields.swift`, `Sources/FolioModel/Fixtures/FolioFixtures+Forms.swift`, `Sources/FolioApp/Live/FolioSampleWriter+Fields.swift`, `Tests/FolioModelTests/FormFillingContractTests.swift`, `Tests/FolioModelTests/FolioFormsTests.swift`, `Tests/FolioModelTests/FolioFormsBudgetTests.swift`, `Tests/AppSnapshotTests/FolioFormsSnapshots.swift`, `Tests/AppSnapshotTests/FolioFieldOverlayTests.swift`, `UITests/FolioJourneyTests+Forms.swift`

#### W1 · `pages`: Organize pages: thumbnails, grid, reorder, rotate, delete, insert, combine, extract, split

- **Covers:** P-T3 (thumbnails), P-T13, P-T14, P-T15, P-T16
- **Waits on:** foundation
- **Proves:** P-J7, P-J8; PB-13, PB-21; PL6, PL7; PF-7
- **Estimate:** about 8 PRs, 13 agent-hours
- **Owned files (23):** `Sources/FolioModel/Live/LivePageOrganizing.swift`, `Sources/FolioModel/Fakes/FakePageOrganizing.swift`, `Sources/FolioModel/Workspace/FolioWorkspace+Pages.swift`, `Sources/FolioModel/Availability/FolioAvailability+Pages.swift`, `Sources/FolioApp/FolioWindow+Pages.swift`, `Sources/FolioApp/FolioCommands+Pages.swift`, `Sources/FolioApp/Sidebar/FolioThumbnails.swift`, `Sources/FolioApp/PageGrid/FolioPageGrid.swift`, `Sources/FolioApp/Sheets/FolioExtractSheet.swift`, `Sources/FolioApp/Sheets/FolioInsertSheet.swift`, `Sources/FolioApp/Sheets/FolioCombineSheet.swift`, `Sources/FolioApp/Sheets/FolioCropSheet.swift`, `Sources/FolioModel/FolioGridLayout.swift`, `Sources/FolioApp/Inspector/FolioPageInspector.swift`, `Tests/FolioModelTests/PageOrganizingContractTests.swift`, `Tests/FolioModelTests/FolioPagesTests.swift`, `Tests/FolioModelTests/FolioGridLayoutTests.swift`, `Tests/AppSnapshotTests/FolioCombineRoundTripTests.swift`, `Tests/FolioModelTests/FolioPagesBudgetTests.swift`, `Tests/AppSnapshotTests/FolioPagesSnapshots.swift`, `Tests/AppSnapshotTests/FolioThumbnailLayoutTests.swift`, `UITests/FolioJourneyTests+Pages.swift`, `UITests/FolioJourneyTests+Combine.swift`

#### W1 · `files`: Save, save as, flatten, passwords and restrictions, document properties

- **Covers:** P-T18, P-T20, P-T26
- **Waits on:** foundation
- **Proves:** P-J10; PB-15; PF-3 (page level: order, rotation, crop, labels kept, title), PF-6, PF-16
- **Estimate:** about 6 PRs, 10 agent-hours
- **Owned files (16):** `Sources/FolioApp/Live/PDFKitWriting.swift`, `Sources/FolioModel/Workspace/FolioWorkspace+Files.swift`, `Sources/FolioModel/Availability/FolioAvailability+Files.swift`, `Sources/FolioApp/FolioWindow+Files.swift`, `Sources/FolioApp/FolioCommands+Files.swift`, `Sources/FolioApp/Sheets/FolioSaveOptionsSheet.swift`, `Sources/FolioApp/Inspector/FolioDocumentInspector.swift`, `Sources/FolioModel/Fixtures/FolioFixtures+Files.swift`, `Tests/FolioModelTests/DocumentWritingContractTests.swift`, `Tests/FolioModelTests/FolioFilesTests.swift`, `Tests/FolioModelTests/FolioFilesBudgetTests.swift`, `Tests/AppSnapshotTests/FolioRoundTripTests.swift`, `Tests/AppSnapshotTests/FolioPasswordTests.swift`, `Tests/AppSnapshotTests/FolioSaveIntegrityTests.swift`, `Tests/AppSnapshotTests/FolioWritingBudgetTests.swift`, `UITests/FolioJourneyTests+Files.swift`

#### W2 · `sign`: Sign: draw, type or pick a signature and initials; keep them; place them

- **Covers:** P-T21
- **Waits on:** markup, forms
- **Proves:** P-J6; PB-12; PF-12
- **Estimate:** about 6 PRs, 10 agent-hours
- **Owned files (20):** `Sources/FolioModel/Live/LiveSigning.swift`, `Sources/FolioModel/Live/LiveSignatureStore.swift`, `Sources/FolioModel/Fakes/FakeSigning.swift`, `Sources/FolioModel/Fakes/FakeSignatureStore.swift`, `Sources/FolioModel/Workspace/FolioWorkspace+Sign.swift`, `Sources/FolioModel/Availability/FolioAvailability+Sign.swift`, `Sources/FolioModel/Tools/FolioTool+Sign.swift`, `Sources/FolioApp/FolioWindow+Sign.swift`, `Sources/FolioApp/FolioCommands+Sign.swift`, `Sources/FolioApp/Sheets/FolioSignatureSheet.swift`, `Sources/FolioApp/PageView/FolioSignaturePopover.swift`, `Sources/FolioApp/Live/FolioSignatureMark.swift`, `Tests/FolioModelTests/SigningContractTests.swift`, `Tests/FolioModelTests/SignatureStoringContractTests.swift`, `Tests/FolioModelTests/FolioSignTests.swift`, `Tests/FolioModelTests/FolioToolsTests.swift`, `Tests/FolioModelTests/FolioSignBudgetTests.swift`, `Tests/AppSnapshotTests/FolioSignSnapshots.swift`, `Tests/AppSnapshotTests/FolioSignatureRoundTripTests.swift`, `UITests/FolioJourneyTests+Sign.swift`

#### W2 · `export-convert`: Export pages and text, new from images, reduce size, print

- **Covers:** P-T4, P-T22, P-T23, P-T24, P-T25
- **Waits on:** files, markup
- **Proves:** P-J21, P-J22, P-J23, P-J24; PB-18, PB-19, PB-20; PF-4, PF-10, PF-11
- **Estimate:** about 7 PRs, 12 agent-hours
- **Owned files (20):** `Sources/FolioApp/Live/PDFKitExporting.swift`, `Sources/FolioApp/Live/PDFKitImageOpening.swift`, `Sources/FolioModel/Workspace/FolioWorkspace+Export.swift`, `Sources/FolioModel/Availability/FolioAvailability+Export.swift`, `Sources/FolioApp/FolioWindow+Export.swift`, `Sources/FolioApp/FolioCommands+Export.swift`, `Sources/FolioApp/Sheets/FolioExportSheet.swift`, `Sources/FolioApp/Sheets/FolioReduceSheet.swift`, `Sources/FolioApp/FolioPrinting.swift`, `Sources/FolioApp/Live/FolioSampleWriter+Photos.swift`, `Tests/FolioModelTests/PageExportingContractTests.swift`, `Tests/FolioModelTests/FolioExportBudgetTests.swift`, `Tests/FolioModelTests/FolioExportTests.swift`, `Tests/AppSnapshotTests/FolioExportTests.swift`, `Tests/AppSnapshotTests/FolioReduceSizeTests.swift`, `Tests/AppSnapshotTests/FolioMarksFidelityTests.swift`, `UITests/FolioJourneyTests+Export.swift`, `UITests/FolioJourneyTests+Images.swift`, `UITests/FolioJourneyTests+Reduce.swift`, `UITests/FolioJourneyTests+Print.swift`

#### W2 · `ocr`: Recognize text on scans and keep it as a text layer

- **Covers:** P-T27
- **Waits on:** reader, find, markup, files
- **Proves:** P-J20; PB-16; PF-8, PF-9
- **Estimate:** about 5 PRs, 8 agent-hours
- **Owned files (15):** `Sources/FolioApp/Live/VisionRecognizing.swift`, `Sources/FolioModel/Workspace/FolioWorkspace+OCR.swift`, `Sources/FolioModel/Availability/FolioAvailability+OCR.swift`, `Sources/FolioApp/FolioWindow+OCR.swift`, `Sources/FolioApp/FolioCommands+OCR.swift`, `Sources/FolioApp/Sheets/FolioRecognizeSheet.swift`, `Sources/FolioModel/Fixtures/FolioFixtures+OCR.swift`, `Sources/FolioApp/Live/FolioSampleWriter+Scan.swift`, `Sources/FolioApp/Live/PDFKitWriting+TextLayer.swift`, `Tests/FolioModelTests/TextRecognizingContractTests.swift`, `Tests/FolioModelTests/FolioOCRTests.swift`, `Tests/AppSnapshotTests/FolioOCRFidelityTests.swift`, `Tests/AppSnapshotTests/FolioOCRRoundTripTests.swift`, `Tests/AppSnapshotTests/FolioOCRBudgetTests.swift`, `UITests/FolioJourneyTests+OCR.swift`

#### W3 · `core-loop`: The core loop, live, measured

- **Covers:** every tier-1 row on live services
- **Waits on:** reader, find, markup, forms, pages, files, sign, export-convert, ocr
- **Proves:** P-J9, P-J14 (with PF-3 for fields and marks, PF-5, PF-14), PL1 and PL4 (in +Loop), P-P1-P-P6
- **Estimate:** about 4 PRs, 6 agent-hours
- **Owned files (6):** `UITests/FolioJourneyTests+Loop.swift`, `UITests/FolioJourneyTests+Perf.swift`, `Tests/AppSnapshotTests/FolioLoopFidelityTests.swift`, `UITests/FolioJourneyTests+History.swift`, `Tests/FolioModelTests/FolioLoopTests.swift`, `docs/blueprints/pdf.md`

#### W4 · `content-edit`: Conditional: edit existing text in place, and true redaction (needs CorePDF CP-1 to CP-5)

- **Covers:** P-T28, P-T29
- **Waits on:** core-loop
- **Proves:** P-J25, P-J26; PF-13
- **Estimate:** about 8 PRs, 16 agent-hours
- **Owned files (23):** `Sources/FolioModel/Contracts/FolioContentEditContracts.swift`, `Sources/FolioModel/Fakes/FakeTextReplacing.swift`, `Sources/FolioModel/Fakes/FakeRedacting.swift`, `Sources/FolioModel/Live/LiveTextReplacing.swift`, `Sources/FolioModel/Live/LiveRedacting.swift`, `Sources/FolioModel/Workspace/FolioWorkspace+ContentEdit.swift`, `Sources/FolioModel/Availability/FolioAvailability+ContentEdit.swift`, `Sources/FolioModel/Tools/FolioTool+ContentEdit.swift`, `Sources/FolioApp/FolioWindow+ContentEdit.swift`, `Sources/FolioApp/FolioCommands+ContentEdit.swift`, `Sources/FolioApp/PageView/FolioRedactionLayer.swift`, `Sources/FolioApp/Sheets/FolioApplyRedactionSheet.swift`, `Tests/FolioModelTests/TextReplacingContractTests.swift`, `Tests/FolioModelTests/RedactingContractTests.swift`, `Tests/AppSnapshotTests/FolioRedactionTests.swift`, `UITests/FolioJourneyTests+ContentEdit.swift`, `Sources/FolioModel/FolioPageSummary.swift`, `Sources/FolioModel/FolioTool.swift`, `Sources/FolioModel/FolioCommand.swift`, `Sources/FolioModel/FolioServices.swift`, `Sources/FolioApp/Live/FolioServices+Live.swift`, `Sources/FolioModel/Contracts/FolioValues.swift`, `Package.swift`


### 9.3 creative-core work

The seven `CorePDF` items of section 4.4. None blocks v1's W0 to W3. CP-1
to CP-5 gate the conditional W4 feature; CP-6 is for certificate signing
and CP-7 for Reduce File Size levels (both Later). Each is "needs a new core issue": one issue per item on
qbtrix/creative-core, labelled `needs-core`, filed after the captain
approves, with the acceptance line from 4.4.

### 9.4 Protected paths (supervisor merges)

W0's first task touches files the fast lane refuses (CLAUDE.md, Parallel
agents: `Package.swift`, `scripts/`, `CLAUDE.md`, `AGENTS.md`), so it is a
supervisor-merged PR, not a fast-lane one. It also carries three
unprotected files that must land with the targets (`project.yml`,
`UITests/audit-baseline.json`, `docs/c4/model.json`):

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
- The first source files, so the new targets build: `Sources/FolioModel/FolioWorkspace.swift`
  and `Sources/FolioApp/FolioApp.swift` as minimal stubs and
  `Tests/FolioModelTests/FolioWorkspaceTests.swift` with one test (an empty
  target fails SwiftPM).
- `docs/c4/model.json`: the `folio-model` and `folio-app` containers, one
  component per target folder, so the C4 gate passes from the first Folio
  file (section 4).
- `CLAUDE.md` and `AGENTS.md`: Folio added to the list of apps and lines
  ("X is Flare, Design, Photo, Library, Halo or Folio"; `line:folio`).

W4 also edits `Package.swift` (FolioModel gains the `CorePDF` product), and
when the suite's `SuiteModel` target lands, a supervisor-merged change adds
it to FolioModel's dependencies for the `SuiteDocumentHost` conformance
(section 4.3).

### 9.5 What Folio needs from other lines

| Line | Need | Filed by | Until it lands |
|---|---|---|---|
| `line:suite` | `SuiteApp.folio` in `SuiteModel` (identity, bundle id, glyph `doc.richtext`, ⌃⌘6), PDF in `SuiteTypeRegistry` (Folio: Editor, Alternate), `SwitchMenu` and `SwitcherEntries` with seven items | foundation (an issue on the suite line) | Folio runs standalone; its switcher row shows the suite's six items disabled with their reason, plus nothing for Folio |
| `line:suite` | Hand-offs: Library "Make PDF from Selection" and Photo "Open In ▸ Folio" (images in), Folio "Open In ▸ Photo" (a page out at 300 ppi), Design's PDF export "Open In ▸ Folio" | export-convert (issues on the suite, Library, Photo and Design lines) | File > New from Images and Export cover the same work by hand |
| `line:suiteui` | `AppSwitcher` seventh item | foundation (`needs-ui`) | the six-item row |
| `line:suiteui` | `ThumbnailGrid`: a drop-insertion line, drag reorder and keyboard reorder (captions and multi-select exist) | pages (`needs-ui`) | a plain `LazyVGrid` placeholder in `FolioPageGrid.swift` with the same identifiers |
| `line:suiteui` | A signature pad (flat drawing well with Clear) | sign (`needs-ui`) | a SwiftUI `Canvas` placeholder in `FolioSignatureSheet.swift` |
| `line:suiteui` | `ViewerStatusBar` trailing button pill | ocr (`needs-ui`) | the menu item and the inspector row |
| `line:suiteui` | editor-in-window (#973): sidebar slot, window subtitle, `EditorDetail`, `AppSwitcher` | – (in flight) | `SuiteWindow` as on `dev`; the subtitle shows as the title's suffix |

Checklist:

- [x] `waves.py` passes: no file owned twice in a wave, every `Sources/` file in one component, every wait on an earlier wave.
- [x] Each feature names its waits, owned files and estimate.
- [x] Protected paths and other lines' work are named, with who files what.

---

## 10. Decisions and questions for the captain

### 10.1 Calls this blueprint makes (overrule any of them)

1. **Name: Folio** (section 0), with Page and Quill as the alternatives.
2. **The document is a value; PDFKit is a service** (section 4). Undo,
   tests and journeys run on Linux; PDFKit reads and writes at the edges.
3. **Folio follows the system appearance** like Library: it is a reading app,
   and pages are white paper.
4. **Tier 1 includes New from Images and Reduce File Size** (rows 4 and 5),
   whose result stays a PDF, while converting out of PDF (rows 2 and 14) is
   tier 2, as Flare and Halo rank export (Photo and Library rank it tier 1). Overrule this and P-T23 becomes
   tier 1 with P-J21 as its journey.
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
11. **No upsell, no account, no network, no unasked AI** (1A, pain points 1,
    8 and 11): Folio makes no network call, shows no upgrade or sign-in
    prompt, and any future AI feature (F1) runs on the Mac and appears only
    when the person invokes it.

### 10.2 Questions

- **Q1 Name.** Folio, Page or Quill? Whichever is picked needs a trademark
  check before the first public build.
- **Q2 Line.** Approve a new line `line:folio`, and the W0 supervisor task
  on `Package.swift`, `scripts/bundle-apps`, `CLAUDE.md` and `AGENTS.md`
  (with `project.yml`, the audit baseline and `docs/c4/model.json`)?
- **Q3 Default app.** Should Folio ever offer to become the default PDF app
  (a one-time prompt in onboarding), or only declare itself an Alternate
  and leave the choice to Finder's Get Info?
- **Q4 Architecture.** Confirm the value-document design (section 4) over
  driving `PDFView` and its annotation objects directly.
- **Q5 Engine.** Approve filing CP-1 to CP-7 on creative-core now (none
  blocks v1), and whether W4 content-edit holds the v1 release or ships as
  v1.1 if CorePDF isn't ready when W3 ends.
- **Q6 Word-processing export.** Ship it in v1 as text-and-paragraphs only,
  or hold it until layout-aware export (Vision's document structure,
  macOS 26) can keep tables?
- **Q7 Scripted forms.** Folio detects and names scripts and XFA but never
  runs them. Acceptable, or should the scripted-form banner also refuse to
  save such forms?
- **Q10 Provenance.** Folio's own provenance records (F4) need a signing
  certificate on the content-credentials trust list, which costs money and
  an enrolment. Pursue it when F4 is scheduled, or leave Folio able to
  check provenance but not to add its own?
- **Q8 Suite slot.** Folio becomes the sixth app in AfterGlow (⌃⌘6, after
  Halo). Confirm the order and the glyph.
- **Q9 Reduce File Size.** v1 has one level built on PDFKit's two
  documented image options, whose effect the docs don't describe; PF-11
  measures it. If it can't shrink a 300 ppi photo PDF by 40%, ship the
  feature off, or wait for CorePDF's image re-encoding (CP-7), which also
  brings Small, Medium and Large levels?

Checklist:

- [x] Every call can be overruled on its own.
- [x] Every question can be answered with a choice.

---

## 11. Critic rounds

One critic agent (a Workflow run) read this document and its folder and
tried to refute it: a tier with no research, a journey with no component,
a contract a journey can't be built from, a budget that can't be measured,
overlapping owned files, a product name, internal contradictions.

### Round 1: 41 findings (2 blocking, 24 major, 15 minor), on fc26f9c

| # | Severity | Finding | Fixed by |
|---|---|---|---|
| F1 | blocking | Reduce File Size promised three ppi levels; PDFKit documents only two boolean image options | One level on those options, measured by PF-11; levels moved to CP-7 (Later); Q9 |
| F2 | blocking | Live services had no way to reach the opened bytes | `DocumentSources` contract, fake actor and live type (UC-0); openers register; source ids from the bytes |
| F3 | major | Recognized text lived only in a cache; save couldn't write it | `FolioPage.recognizedText`, recognition is an undo step, the writer and the fake carry it; PF-9 cites the invisible text mode |
| F4 | major | Journeys depended on features in the same wave | Undo moved into foundation; P-J9 to core-loop; P-J10 uses the `filled` fixture; ocr waits on markup; P-J22 no longer asserts the OCR pill |
| F5 | major | Fit Width page ran under the palette | PL2 to PL5 measure from the palette's band; PL5 arithmetic at 944 pt |
| F6 | major | C4 containers came last, failing the gate | C4 containers in W0's first PR |
| F7 | major | pages proved rules in reader's and files' files | `FolioGridLayout.swift` and its tests, `FolioCombineRoundTripTests.swift` owned by pages |
| F8 | major | Page summary owned by W0 alone; grammar inconsistent | Fixed grammar; one facet file per area, owned by each feature |
| F9 | major | Every-control journey edited by every feature | Data-driven from `suite.controls` and `FolioCommand.menu` |
| F10 | major | Find hits and other overlays had no layer file | `FolioPageOverlays.swift` seam with stub layers; find owns its hits layer |
| F11 | major | Journeys and budgets named samples nobody makes | `-FolioWriteSample`; per-area fixture files; `long1000marks`, `big50`, `scan300`, `photos` |
| F12 | major | Budget tests named a suite no feature owns; no export budgets | Each PB row names its feature's suite; PB-18 to PB-21 |
| F13 | major | Tab order put both radio buttons and the signature field in the order; no field label | Radio group one stop, signature fields skipped; `FolioFormField.label`; P-J5 uses → |
| F14 | major | No value carried form scripts | `FolioDocumentState.scripts`, a `scripted` fixture and a test |
| F15 | major | New from Images couldn't report skipped files; fake made pages from anything | `FolioImageInput`, `paper:`, `FolioOpened.skipped`; the fake reads PNG headers |
| F16 | major | Fake library fixed at launch; truncated fake file read as not-a-PDF | Fake source store keyed by content hash; the magic line comes first |
| F17 | major | Combine Files had no method, menu item or journey; Split untested | `PageOrganizing.combine`, workspace begin/finish, `init(document:services:)`, menu item, P-J8 steps |
| F18 | major | Menus in 7.6 missed items features use | 7.6 completed; P-J12 compares with `FolioCommand.menu` |
| F19 | major | ⌘0 and ⌘1 opposite to the suite; bare Tab and Delete as key equivalents | Actual Size ⌘1, Fit Page ⌘0, view modes ⌥⌘1–4; Tab and Delete handled by focus, not menus |
| F20 | major | Tier rule applied unevenly to conversions | Rule stated: results that stay PDF can be tier 1, conversions out are tier 2; Q-call 10.1 item 4 |
| F21 | major | Find's 1.3% was compare's number | Row 15 re-sourced and marked inferred |
| F22 | major | Vote counts called use counts | Called votes, with the caveat |
| F23 | major | Copy, word, line, ⌘A untested; no paragraph data | `line(at:)`, `copyText`, `endsParagraph`; P-J3 copies and reads the pasteboard |
| F24 | major | Outline and labels unexercisable | Fixture outline and labels; P-J1 clicks the outline and goes to "ii" |
| F25 | major | No contract for font size, alignment, width, opacity | `FolioMarkStyle` and `Annotating.setStyle` |
| F26 | major | Page pictures could double-draw file marks; PF-1 compared PDFKit with itself | Imaging hides annotations (`shouldDisplay`); PF-1 checks known pixels |
| F27 | minor | Wrong journey ids; no ⌥⌘→ step; untested tier-1 journeys | Ids fixed; P-J7 step; proof test for P-J22 and P-J23 |
| F28 | minor | Rows without URLs; wrong research rows | URLs added; rows corrected |
| F29 | minor | Names outside URLs | Trackers and sites described; names kept only in URLs. Kept as is: Finder and Dock, which are the platform's own UI named in Apple's HIG, not a competing product |
| F30 | minor | Asked SuiteUI for what exists; pill order; wrong argument; 600 | Needs trimmed; pills as drawn; `-FolioWindowSize`; 944 × 560 |
| F31 | minor | Glass surfaces and palette position contradicted | Two named surfaces; the palette at the leading edge in every sketch |
| F32 | minor | Protected list wrong; CLAUDE.md update missing | 9.4 corrected; CLAUDE.md and AGENTS.md in W0's supervisor PR; Q2 |
| F33 | minor | W4 couldn't add its enum cases and slots | W4 owns those files (after every other wave) |
| F34 | minor | No section 11; no checklists after section 2 | This section; checklists in 3 to 10 |
| F35 | minor | Dangling C4 ids; SuiteModel dependency unplanned | Externals added; 9.4 names the later supervisor change |
| F36 | minor | Platform claims without citations | LSHandlerRank, shouldDisplay, invisible text mode, picker and toggle styles cited; background removal made a pure threshold |
| F37 | minor | Saving could drop owner restrictions | `ownerUnlocked`, `FolioWriteError.restricted`, PF-6 case, test |
| F38 | minor | A Folio control probe duplicated SuiteUI's | SuiteUI's `.suiteControl` and `suite.controls` |
| F39 | minor | Stale probe reason; streaming find with no API | Report-only per the rubric, gates in `Journey+Budgets.swift`; find is synchronous over loaded text |
| F40 | minor | Text Select and Hand can't change the document | QB-F1 reads "changes the workspace" |
| F41 | minor | W0 claimed layout rules it can't show; zoom ladder undefined | W0 proves PL2, PL3, PL5; core-loop PL1, PL4; zoom steps in P-T2 |

### Round 2: 40 findings (1 blocking, 17 major, 22 minor), on 59f8abd

Round 2 checked round 1's fixes and looked again. One round-1 fix (F4)
had not gone far enough, and one fix had broken a row: the menu edit for
F18 replaced the brief's Edit row (2.4) instead of 7.6's.

| # | Severity | Finding | Fixed by |
|---|---|---|---|
| R2-1 | blocking | Journeys still read page-summary facets owned by other features in the same wave (P-J10, P-J8, P-J22) | The page summary and status pills are whole in W0, pure reads of the document value; no facet files (supersedes F8's split); P-J8 reads fields from the page value |
| R2-2 | major | Only reader owned the sample writer every feature's samples need | `FolioSampleWriter+Marks`, `+Fields`, `+Scan`, `+Photos`, W0 stubs, each owned by its feature; PF-1 keeps only known pixels; the hidden-annotation check is PF-14 (core-loop) |
| R2-3 | major | No one owned writing the OCR text layer, and the path wasn't designed | `PDFKitWriting+TextLayer.swift` (ocr, W0 stub); the re-render path spelled out in PF-9 with citations |
| R2-4 | major | PF-3 and PF-5 needed markup's and forms' mappings in the same wave | Files proves the page-level round trip; fields, marks and flatten move to core-loop (`FolioLoopFidelityTests`) |
| R2-5 | major | Sidebar and inspector had no seam | `FolioNavigator` and `FolioInspector` list section files W0 stubs and features own |
| R2-6 | major | `FolioSidebar` trips the design lint | Renamed `FolioNavigator`; the lint rule is noted |
| R2-7 | major | `-SuiteControlsProbe` doesn't exist | `-SuitePerfProbe` with `.suiteProbes()` for P-J12 and P-P1 to P-P6 |
| R2-8 | major | `suite.status` doesn't exist | `folio.status` on the status bar (reader) |
| R2-9 | major | Live samples can't carry page labels (PDFKit's label is get-only) | Go to label moved to P-J1b in fixture mode, with the reason cited; live labels wait for CP-2 |
| R2-10 | major | Which services `-FolioOpenFile` uses was undefined | `FolioLaunch` rules in section 5 Modes; `-FolioFake`; P-J10 relaunches with it |
| R2-11 | major | The fake shrank a reduced file again | Fake pages remember `optimized`; P-J23 opens the reduced file; proof test |
| R2-12 | major | The tier rule misquoted `docs/priorities.md` | Quoted correctly (tier 2 for Flare and Halo, tier 1 for Photo and Library) and stated as this blueprint's call, 10.1 item 4 |
| R2-13 | major | Picture signatures had no contract | `Signing.make(picture:)` with a threshold and trim, proof test, P-J6 step |
| R2-14 | major | Delete kept ⌫; Cut, Paste and Share had no owner | 7.6 fixed (and 2.4's Edit row restored); markup owns cut, copy and paste of marks; export-convert owns Share, disabled until saved |
| R2-15 | major | OCR's status pill had no seam | Status pills are whole in W0 from the document value |
| R2-16 | major | Empty targets fail SwiftPM | First PR adds stub sources and one test |
| R2-17 | major | `form` ×200 and 1,000 marks on one page undefined | `form200` (forms) and `page1000marks` (markup) fixtures; the pen stroke is generated in its test |
| R2-18 | major | PL7 named reader's test file | `FolioGridLayoutTests.columns` |
| R2-19 | minor | The gate file didn't exist | Gates go in `FolioJourneyTests+Perf.swift` (core-loop), as Suite does |
| R2-20 | minor | PB-20 cited the wrong QB-L8 row | Folio's own target |
| R2-21 | minor | `FolioControlsTests` not owned | `FolioCommandTests` |
| R2-22 | minor | W0's layout journey can't select a highlight | W0 runs plain; core-loop repeats with marks and find |
| R2-23 | minor | Asserts without steps (P-J6, P-J4, P-J8) | Steps and launch arguments added |
| R2-24 | minor | Hand had no key | G |
| R2-25 | minor | Typed signature face unnamed and against the lint | Drawn as content through CoreText in the system font's italic, cited |
| R2-26 | minor | "Damaged with the reason" and script detection unsourced | Header check plus nil document; catalog walk for `/XFA`, `/JavaScript`, `/AA`, cited |
| R2-27 | minor | Mapped files can crash if changed outside | Read into memory up to 512 MB; larger files copied privately, then mapped |
| R2-28 | minor | The fake lost crop on save | The fake file carries crop; proof test |
| R2-29 | minor | 5.2 still described streaming find | Matches the synchronous design |
| R2-30 | minor | "Why this line" contradicted itself | Rewritten |
| R2-31 | minor | 2.4 Edit row damaged | Restored |
| R2-32 | minor | P-T42 tier 3 against the rule | Tier 2, Later for its structure need |
| R2-33 | minor | Rows with numbers but no URL; survey strength | URLs added, numbers without one dropped, survey marked medium |
| R2-34 | minor | A forum's post prefix in prose | Described |
| R2-35 | minor | CP-7 outside its table; Q5 and C4 said CP-6; questions out of order; C4 fixture list stale | Fixed |
| R2-36 | minor | 9.5 still asked for existing ThumbnailGrid features | Trimmed |
| R2-37 | minor | Core-loop edited the file P-J12 says no feature edits | Core-loop's layout checks moved to `+Loop` |
| R2-38 | minor | 944 × 560 assumed #973 | Read from the tokens at test time; both values stated |
| R2-39 | minor | PF-11 gate or report-only unclear | Report-only until Q9; P-J23's live run follows |
| R2-40 | minor | Fixtures placed in two files | W0 moves `FolioFixtures` to `Fixtures/FolioFixtures.swift` |

After round 2: `check.sh` `CONTRACTS: PASS` (12 of 12, no warnings) and
`waves.py` `WAVES: PASS`. No third round was run: round 2's single blocking
item was a same-wave dependency, now removed by making the shared reads
whole in W0, and every other item was a local fix.

