# Folio research notes (raw)

Raw notes behind `docs/blueprints/pdf.md` section 1, gathered 2026-10-15
from public sources only: usage numbers published by web PDF tool sites,
keyword-volume pages, help-centre and forum counts, open-source issue
trackers (reaction and subscriber counts), tech-forum threads, and Apple's
developer documentation. No PDF app was opened, run, decompiled or scraped
beyond reading its public pages. A URL may contain a product's name; the
text describes behaviour only.

Signal strength: **strong** = a number read on the fetched page;
**medium** = a number seen in a search-result snippet, page not fetched or
not readable; **weak** = qualitative.

Contents: A Usage signals · B Open-source asks · C What people say is
missing · D OCR, redaction, compare, reflow · E Platform facts

---

## A. Usage signals

Four kinds of evidence, each a number:

- **US monthly searches** from a public keyword-volume site's per-keyword
  pages (it states the numbers come from the search engine's ads API).
  Search volume measures demand for a tool *outside* the default viewer, so
  it under-counts what every viewer already does (read, highlight, search,
  print); those tasks are ranked by the Q&A data instead.
- **Per-tool vote counts** shown on the tool pages of two web PDF tool sites
  (site A and site B; their URLs are in the table), a stand-in for use. Newer tools
  have had less time to collect votes.
- **Q&A sites** of one network: the 2,281 top-voted questions tagged pdf (or
  the built-in viewer's tag) on its general-computing, Linux, Mac and Unix
  sites (superuser.com, askubuntu.com, apple.stackexchange.com,
  unix.stackexchange.com), 58.8 million
  views in all, grouped by task from title keywords (approximate), plus
  single-question view counts (api.stackexchange.com).
- **One web vendor's published usage split** (May 2025, 100M+ files a week:
  compress 34%, all conversion 28%, e-sign 19%, PDF to a word-processing format 16%,
  https://smallpdf.com/pdf-statistics), and a vendor-commissioned survey of
  US financial professionals (98% work with PDFs; 61% edit about 20 times a
  month; 64% sign about 15 times a month; seen only in search snippets,
  https://business.adobe.com/blog/financial-professionals-love-to-edit-sign-convert-with-pdfs).

| # | Task | Signal | Strength | Source |
|---|---|---|---|---|
| 1 | Read and view (open, scroll, zoom, layout, default app) | largest Q&A group: 11.8% of 58.8M views; "pdf reader" 33,100/mo, "pdf viewer" 14,800/mo | strong | https://www.seodata.dev/keyword/pdf-reader ; https://api.stackexchange.com/2.3/questions?site=superuser&tagged=pdf&sort=votes |
| 2 | Convert to a word-processing, spreadsheet or slide format | "pdf to <word processor>" 246,000/mo, "pdf to <spreadsheet>" 33,100, "pdf to <slides>" 22,200; #1 tool on site A (1,613,986 votes) and site B (38,056); 16% of the vendor's activity | strong | https://www.seodata.dev/keyword/pdf-to-word ; https://pdfcandy.com/pdf-to-word.html ; https://www.pdf2go.com/pdf-to-word ; https://smallpdf.com/pdf-statistics |
| 3 | Merge several PDFs into one | "pdf merger" 201,000, "merge pdf" 135,000, "combine pdf" 135,000; site A 704,085 votes; 8.1% of Q&A views from 76 questions; "How to merge several PDF files?" 785K views | strong | https://www.seodata.dev/keyword/merge-pdf ; https://www.seodata.dev/keyword/combine-pdf ; https://pdfcandy.com/merge-pdf.html ; https://askubuntu.com/questions/2799 |
| 4 | Make a PDF from images or scans | "jpg to pdf" 201,000, "image to pdf" 60,500; site A 450,724 votes; the Mac Q&A site's most-viewed PDF question, combining images into one PDF, 1,502,667 views | strong | https://www.seodata.dev/keyword/jpg-to-pdf ; https://pdfcandy.com/jpg-to-pdf.html ; https://apple.stackexchange.com/questions/11163 |
| 5 | Reduce file size | 34% of the vendor's activity (its top tool); "compress pdf" 110,000, "reduce pdf size" 33,100; "reduce the file size of a scanned PDF" 1,049,735 views | strong | https://smallpdf.com/pdf-statistics ; https://www.seodata.dev/keyword/compress-pdf ; https://askubuntu.com/questions/113544 |
| 6 | "Edit a PDF" in general (add text, fill blanks, sign, rearrange) | "pdf editor" 246,000, "edit pdf" 90,500; site A 278,175; site B 36,741; "How to Edit PDFs?" 350K views | strong | https://www.seodata.dev/keyword/pdf-editor ; https://www.seodata.dev/keyword/edit-pdf ; https://pdfcandy.com/edit-pdf.html |
| 7 | Export pages as images | "pdf to jpg" 165,000, "pdf to png" 74,000; site A 156,024; "convert PDF to image" 466K views | strong | https://www.seodata.dev/keyword/pdf-to-jpg ; https://pdfcandy.com/pdf-to-jpg.html ; https://askubuntu.com/questions/50170 |
| 8 | Make a PDF from office files, web pages, print to PDF | "<word processor> to pdf" 110,000; site A 288,131; 6.1% of Q&A views | strong | https://www.seodata.dev/keyword/word-to-pdf ; https://pdfcandy.com/word-to-pdf.html |
| 9 | Fill in forms | "fill pdf" 74,000, "pdf filler" 74,000; "software that can fill PDF forms" 248K views; 1.4% of Q&A views | strong | https://www.seodata.dev/keyword/fill-pdf ; https://askubuntu.com/questions/29230 |
| 10 | Annotate: highlight, notes, comments, drawing | second-largest Q&A group: 8.9% of views, 246 questions; "highlight or annotate PDFs" 307K views; low search volume (3,600) because viewers already do it | strong (Q&A) | https://askubuntu.com/questions/1529 ; https://www.seodata.dev/keyword/annotate-pdf |
| 11 | Sign (drawn, typed or picture) | 19% of the vendor's activity (its #2); 64% of surveyed professionals sign ~15 times a month; "sign pdf" 22,200, "pdf signature" 18,100; "add a signature .png to a PDF" 231K views | strong | https://smallpdf.com/pdf-statistics ; https://www.seodata.dev/keyword/sign-pdf ; https://unix.stackexchange.com/questions/85873 |
| 12 | Split, extract a page range | "split pdf" 40,500, "extract pages from pdf" 8,100; site A 226,452; site B 30,858; "extract a page range" 793K views | strong | https://www.seodata.dev/keyword/split-pdf ; https://pdfcandy.com/split-pdf.html ; https://askubuntu.com/questions/221962 |
| 13 | Delete, reorder, insert pages | "delete pages from pdf" 33,100, "rearrange pdf pages" 3,600, "add page to pdf" 3,600; site A rearrange 64,169, delete 49,407 | strong | https://www.seodata.dev/keyword/delete-pages-from-pdf ; https://pdfcandy.com/rearrange-pdf.html |
| 14 | Print (booklet, n-up, poster, scaling) | 4.6% of Q&A views (126 questions); "print one page enlarged to multiple pages" 315K; booklet 96K, 4-up 63K | strong | https://superuser.com/questions/205943 ; https://apple.stackexchange.com/questions/3832 |
| 15 | Copy or extract text | "Can't copy text from a pdf file" 462K views, "copy text without losing formatting" 399K; "pdf to text" 12,100/mo | strong | https://superuser.com/questions/47462 ; https://superuser.com/questions/198392 ; https://www.seodata.dev/keyword/pdf-to-text |
| 16 | Rotate pages and keep the rotation | the general-computing Q&A site's most-viewed PDF question, saving a rotated PDF, 705K; "rotate pdf" 9,900 | strong | https://superuser.com/questions/145696 ; https://www.seodata.dev/keyword/rotate-pdf |
| 17 | Remove or add a password | "remove security from a PDF" 582K views; "unlock pdf" 14,800, "password protect pdf" 8,100 | strong | https://superuser.com/questions/179064 ; https://www.seodata.dev/keyword/unlock-pdf ; https://www.seodata.dev/keyword/password-protect-pdf |
| 18 | Translate, summarize, ask questions of a PDF | "translate pdf" 14,800, "summarize pdf" 2,400, "chat with pdf" 1,600 | strong | https://www.seodata.dev/keyword/translate-pdf |
| 19 | Crop or change page size | "crop pdf" 9,900; site A 50,461; 1.7% of Q&A views | strong | https://www.seodata.dev/keyword/crop-pdf ; https://pdfcandy.com/crop-pdf.html |
| 20 | Edit existing text in place | "edit pdf text" 8,100 (vs "edit pdf" 90,500); site A's in-place text editor 464 votes vs 278K for its general editor; "change font style in the built-in viewer" 135K views | strong | https://www.seodata.dev/keyword/edit-pdf ; https://apple.stackexchange.com/questions/170840 ; https://pdfcandy.com/edit-pdf-text.html |
| 21 | Flatten | "flatten pdf" 6,600 | strong | https://www.seodata.dev/keyword/flatten-pdf |
| 22 | OCR: make scans searchable | "pdf ocr" 5,400 + "ocr pdf" 4,400 + "make pdf searchable" 2,400; site A 38,447; 1.1% of Q&A views; hidden demand inside "can't copy text" (462K) and scan conversions | strong | https://www.seodata.dev/keyword/ocr-pdf ; https://pdfcandy.com/pdf-ocr.html |
| 23 | Redact | "redact pdf" 5,400; the Mac Q&A site's #2 most-viewed PDF question, blacking out or redacting text, 490,831 views; site B 38 votes | strong | https://www.seodata.dev/keyword/redact-pdf ; https://apple.stackexchange.com/questions/22683 |
| 24 | Compare two versions | "pdf compare" 5,400; the general-computing Q&A site's #3 most-viewed PDF question, 485,773 views; 1.3% of Q&A views | strong | https://www.seodata.dev/keyword/pdf-compare ; https://superuser.com/questions/46123 |
| 25 | Read aloud | "read pdf aloud" 4,400, "pdf text to speech" 1,600 | strong | https://www.seodata.dev/keyword/read-pdf-aloud |
| 26 | Stamps: Bates, page numbers, watermark, header and footer | "bates numbering" 2,900, "add page numbers to pdf" 2,900, "watermark pdf" 1,600; 0.7% of Q&A views | strong | https://www.seodata.dev/keyword/bates-numbering ; https://www.seodata.dev/keyword/add-page-numbers-to-pdf |

Long tail (US monthly searches unless noted): dark or inverted reading 480
(the Mac Q&A site 133K views; "adjust PDF contrast" 394K); bookmarks and
outline 720 + 320; accessibility 720; PDF/A 480; change a PDF's title
151,099 views on the Mac Q&A site (https://apple.stackexchange.com/questions/274703); repair a damaged PDF 236K views; which
fonts a PDF uses 447K views.

Mac-specific US searches (2026-10-15): "how to modify a pdf on mac" 9,900,
"how to edit a pdf on mac" 6,600, "pdf editor for mac" 4,400, "combine pdf
on mac" 2,400, "how to reduce pdf file size mac" 2,400, "how to sign a pdf
mac" 1,600, "compress pdf mac" 1,300, "sign pdf on mac" 880, "ocr pdf mac"
210, "redact pdf mac" 140.

Other public numbers seen: India volumes on a public SEO site's pages ("pdf
to <word processor>" 4M, "jpg to pdf" 4.8M, "pdf to jpg" 3.4M, "merge pdf" 1.7M,
"compress pdf" 1.6M; https://ahrefstop.com/websites/pdf24.org); one web
tool site's home page lists Merge, Split, Compress, PDF to a word-processing format first (no
counts). Q&A tag sizes: general computing pdf 3,801, Linux 1,457, Mac pdf 1,185
and the built-in viewer's tag 1,094, Unix 733.

### A.1 Where the built-in macOS viewer falls short (from public Q&A and help pages)

- Combining images into one PDF is not obvious: 1.5M views (above), plus
  adding images to an existing PDF 335K and pasting an image into a PDF 115K.
- Redaction: 491K views. It used to draw boxes that left the text; there is
  no find-and-redact-all and metadata stays.
- No editing of existing text: Apple's own guide says text in a PDF can't be
  edited, only marked up on top
  (https://support.apple.com/guide/preview/annotate-a-pdf-prvw11580/mac);
  135K views on changing a PDF's font.
- No OCR for scanned PDFs (the system's on-device text recognition works on images only).
- Reduce File Size quality is a common complaint ("decrease .pdf size
  without losing quality" 114K views).
- Splitting one page into several: 306K views.
- No dark or inverted reading mode: 133K views.
- Saving problems: annotations disappearing after save, annotated files
  other tools reject (https://discussions.apple.com/thread/253675313 ,
  https://discussions.apple.com/thread/253649204 ,
  https://discussions.apple.com/thread/255716950); ghost note squares that
  can't be removed 156K views; an unexpected password on save 62K.
- Dynamic XFA forms (a scripted form format) show only a placeholder.
- Also: setting a document's title (151K), carrying a saved signature to
  another Mac (185K), default view settings such as continuous scroll (64K),
  booklets and pages per sheet (96K, 63K); no compare, Bates or page-number
  stamps, watermarks, or outline editing.

Gaps in this pass: the Apple Community's search runs in JavaScript, so its
thread counts weren't read; the other large web tool sites publish no
per-tool numbers; search volumes are ads-tool estimates where close variants
share one number.

---

## B. Open-source asks

Read through each project's public issue tracker: reaction counts (👍) on
one code host, upvotes on another, and on three bug trackers with no votes
the subscriber count (CC) stands in. Units differ across trackers, so
ranks across them are approximate.

### B.1 Projects

| Project (what it is) | Stars | Open issues | Open feature or enhancement items | Source |
|---|---|---|---|---|
| Self-hosted web toolbox of PDF operations | 94,223 | 320 | 126 `enhancement` (605 all time) | https://github.com/Stirling-Tools/Stirling-PDF |
| Browser PDF viewer library | 54,003 | 382 | 48 `feature` (366 all time) | https://github.com/mozilla/pdf.js |
| Command-line OCR that adds a text layer | 35,026 | 59 | 18 `enhancement` | https://github.com/ocrmypdf/OCRmyPDF |
| Handwritten-notes app that annotates PDFs | 15,517 | 1,164 | 541 `enhancement` | https://github.com/xournalpp/xournalpp |
| Keyboard-driven reader for papers | 9,944 | 315 | no label | https://github.com/ahrm/sioyek |
| PDF processing library and CLI | 8,865 | 103 | sparse labels | https://github.com/pdfcpu/pdfcpu |
| Desktop page arranger (merge, split, rotate) | 5,976 | 76 | 14 `feature` | https://github.com/pdfarranger/pdfarranger |
| Structural PDF transformer (CLI) | 5,482 | 143 | no label | https://github.com/qpdf/qpdf |
| Desktop merge and split tool | 4,619 | 115 | 2 | https://github.com/torakiki/pdfsam |
| Minimal keyboard viewer | 3,352 | 160 | no label | https://github.com/pwmt/zathura |
| Rendering library and viewer | 2,999 (mirror) | – | 60 open enhancements on its Bugzilla | https://bugs.ghostscript.com |
| KDE document viewer | 1,541 (mirror) | – | 560 open wishlist items | https://bugs.kde.org |
| GNOME document viewer (new) | 78 | 255 | 51 `1. Feature` | https://gitlab.gnome.org/GNOME/papers |
| GNOME document viewer (classic) | 74 | 825 | 65 `1. Feature` | https://gitlab.gnome.org/GNOME/evince |
| Office suite's PDF import and drawing | – | – | 113 open enhancements with "pdf" in the title; 54 open bugs titled "pdf import" | https://bugs.documentfoundation.org |
| Native macOS reader and note taker | – | – | 17 open feature requests | https://sourceforge.net/p/skim-app/feature-requests/ |

### B.2 Most-requested features (top of every tracker, merged)

| # | Feature | Count | Issue |
|---|---|---|---|
| 1 | Configurable shortcuts | 195 👍 | https://github.com/xournalpp/xournalpp/issues/919 |
| 2 | Digital (certificate) signatures | 142 👍 | https://github.com/mozilla/pdf.js/issues/1076 |
| 3 | Infinite canvas around pages | 109 👍 | https://github.com/xournalpp/xournalpp/issues/1174 |
| 4 | Rotate pages | 66 👍 | https://github.com/xournalpp/xournalpp/issues/1883 |
| 5 | Two-page view | 63 👍 | https://github.com/mozilla/pdf.js/issues/590 |
| 6 | Fill in form entries | 57 👍 | https://github.com/Stirling-Tools/Stirling-PDF/issues/320 |
| 7 | Edit existing text directly | 46 👍 | https://github.com/Stirling-Tools/Stirling-PDF/issues/1141 |
| 8 | Reader comforts (outline, citations, resume) | 44 👍 | https://github.com/mozilla/pdf.js/issues/17921 |
| 9 | Split view | 41 CC | https://bugs.kde.org/show_bug.cgi?id=169847 |
| 10 | Crop placed images | 37 👍 | https://github.com/xournalpp/xournalpp/issues/1842 |
| 11 | Change text and page colours (dark reading) | 37 👍 | https://github.com/mozilla/pdf.js/issues/2071 |
| 12 | Find: highlight every match | 34 CC | https://bugs.kde.org/show_bug.cgi?id=377487 |
| 13 | Default zoom setting | 34 CC | https://bugs.kde.org/show_bug.cgi?id=169516 |
| 14 | Tagged PDF, PDF/UA, PDF/A | 33 👍 | https://github.com/pdfcpu/pdfcpu/issues/832 |
| 15 | No upsell prompts | 32 👍 | https://github.com/Stirling-Tools/Stirling-PDF/issues/2974 |
| 16 | Hold a key for a temporary tool | 31 👍 | https://github.com/xournalpp/xournalpp/issues/2310 |
| 18 | Bookmarks, comments on highlights, interchange with other readers | 30 👍 | https://github.com/ahrm/sioyek/issues/160 |
| 19 | Tabs | 29 CC | https://bugs.kde.org/show_bug.cgi?id=339971 |
| 20 | Add fillable form fields | 28 👍 | https://github.com/Stirling-Tools/Stirling-PDF/issues/2157 |
| 21 | Reopen previous documents | 27 CC | https://bugs.kde.org/show_bug.cgi?id=364680 |
| 22 | Validate digital signatures | 26 👍 | https://github.com/mozilla/pdf.js/issues/13351 |
| 26 | Tabs for several documents | 24 upvotes | https://gitlab.gnome.org/GNOME/papers/-/work_items/54 |
| 27 | Better highlight and notes | 24 upvotes | https://gitlab.gnome.org/GNOME/evince/-/work_items/1134 |
| 28 | Make imported text editable | 24 CC | https://bugs.documentfoundation.org/show_bug.cgi?id=32249 |
| 29 | Add a drawn or picture signature | 23 upvotes | https://gitlab.gnome.org/GNOME/evince/-/work_items/639 |
| 30 | Verify digital signatures | 22 upvotes | https://gitlab.gnome.org/GNOME/evince/-/work_items/143 |
| 32 | Text extraction | 20 👍 | https://github.com/pdfcpu/pdfcpu/issues/122 |
| 33 | Keyboard text selection | 19 👍 | https://github.com/pwmt/zathura/issues/748 |
| 34 | Line, rectangle, arrow | 18 👍 | https://github.com/mozilla/pdf.js/issues/15588 |
| 35 | Draw shapes | 18 upvotes | https://gitlab.gnome.org/GNOME/evince/-/work_items/1363 |
| 36 | Native Apple-silicon build | 18 👍 | https://github.com/ahrm/sioyek/issues/375 |
| 37 | Sign with a scanned signature image | 15 CC | https://bugs.kde.org/show_bug.cgi?id=315930 |
| 38 | Remember the last read position | 15 👍 | https://github.com/Stirling-Tools/Stirling-PDF/issues/5520 |
| 39 | Translate | 10 👍 | https://github.com/Stirling-Tools/Stirling-PDF/issues/2192 |
| 40 | Create or edit the outline | 9 👍 | https://github.com/qpdf/qpdf/issues/343 |
| 41 | Insert text more easily | 8 👍 | https://github.com/Stirling-Tools/Stirling-PDF/issues/5257 |
| 42 | Open two PDFs side by side | 7 👍 | https://github.com/Stirling-Tools/Stirling-PDF/issues/6140 |
| 43 | Undo and redo | 4 👍 | https://github.com/Stirling-Tools/Stirling-PDF/issues/6755 |
| 44 | Page labels | 4 👍 | https://github.com/pdfarranger/pdfarranger/issues/336 |

Clusters, strongest first: signatures (drawn or picture, then certificate
and validation); markup tools and shapes; forms (fill, then author);
editing existing text; reading comfort (tabs, split view, resume, two-up,
dark colours, default zoom); page operations (rotate, labels, outline);
a native build per platform, Apple silicon included.

---

## C. What people say is missing

A tech news forum, news.ycombinator.com (read through its public search
API; a large general forum site could not be fetched from this session, so
no counts from it are claimed):

- "Show HN: free in-browser PDF editor" (791 points,
  https://news.ycombinator.com/item?id=43880962): the top complaint is that
  it "doesn't edit PDF text, just adds more" (comment 43881500); subset fonts
  stop typing new glyphs (43883065); people want text boxes that resize and
  re-edit, a font choice, bold and italic (43881651); undo for a page delete
  instead of a confirmation, and an outline editor (43887624); links lost on
  save (43888208).
- The 2026 follow-up (https://news.ycombinator.com/item?id=47563103): undo
  failed and text edits forced one sans-serif face (47566227); black boxes
  sold as redaction leave the text underneath (47569622); "free" tools with
  export limits are distrusted (47568014).
- Privacy and offline: files staying on the machine is valued, but people
  doubt web tools will keep it (43882168, 43882188); asks for a desktop app
  or the source (43886255, 43887810); the web toolbox's own users asked to
  turn off its upgrade prompt (#2974, 32 👍).
- Scans: split two-page scans, deskew, black and white, OCR and compress
  (43882279); clean grey backgrounds from scanned text without a slow manual
  route in the built-in viewer (47564020).
- Batch: merge, compress to a size cap, then number pages, as one chain
  (43884497, 43885724).
- Why editing is hard: PDF is fixed-position glyphs "optimized for viewing
  rather than editing" (https://news.ycombinator.com/item?id=44295237,
  comments 44295292, 44295320).
- The Mac gap: roundups name one native open-source Mac reader as the main
  option and call it basic with no OCR; an open-source Mac editor is at an
  early stage (https://github.com/orklann/PEP,
  https://tech.yahoo.com/apps/articles/5-open-source-alternatives-adobe-190018433.html);
  the page arranger has no proper Mac build
  (https://github.com/pdfarranger/pdfarranger/issues/279), nor does the
  keyboard reader on Apple silicon (#375).
- Certificate signing on Linux and with smart cards from a GUI
  (https://bugs.kde.org/show_bug.cgi?id=451060).

---

## D. OCR, redaction, compare and text reflow

**OCR: wanted; met today mostly by a command-line tool.** The OCR CLI has
35k stars and a thank-you issue with 133 👍
(https://github.com/ocrmypdf/OCRmyPDF/issues/139). In viewers it is a
light, steady ask: 10 CC (https://bugs.kde.org/show_bug.cgi?id=417274),
3 👍 (https://github.com/mozilla/pdf.js/issues/15843), handwriting
recognition 25 👍. "Best way to turn a scanned book PDF into text" drew 206
points and 109 comments (https://news.ycombinator.com/item?id=43048698);
the platform's own on-device recognition came up as good enough, and people
distrust generative OCR that can silently change text.

**Redaction: few votes, loud news-driven demand, and correctness is the
whole point.** Viewer trackers: 2 CC each
(https://bugs.kde.org/show_bug.cgi?id=452403,
https://bugs.kde.org/show_bug.cgi?id=489299); the web toolbox has about 10
redaction issues, including a 2026 bug where redacted text could still be
copied (https://github.com/Stirling-Tools/Stirling-PDF/issues/7564). The tech news forum: "finding bad redactions in PDFs", 709 points
(https://news.ycombinator.com/item?id=46369923), and two forensics posts on
a public document release, 409 and 544 points (46886440, 46890335). What
people want: the text truly gone, small output, no side channel from box
widths and kerning (46371001).

**Compare: weak.** 4 👍 for better compare
(https://github.com/Stirling-Tools/Stirling-PDF/issues/1290), 7 👍 for side
by side (#6140). The neighbour, split view, is strong (41 CC, the top of one
desktop viewer's wishlist). No thread on the tech news forum asked for compare.

**Editing existing text: the loudest editing ask; reflow is not asked.**
46 👍 (#1141), 12 👍 (#258), 10 👍 (#2305), 8 👍 open (#5257); 24 CC open
since 2010 (tdf#32249); the first complaint in both tech-forum threads.
The asks are for in-place edits that keep the font. No one asked for
multi-line paragraph reflow; commenters call it hard because of fixed
layout and subset fonts. The nearest is copying wrapped paragraphs without
line breaks (https://github.com/mozilla/pdf.js/issues/19343).

---

## E. Platform facts (Apple developer documentation, read 2026-10-15)

Read with the apple-docs tools from developer.apple.com. "Docs silent"
means the page gives only the symbol and its availability.

| Capability | What the platform gives | Gap Folio or creative-core must build | Source |
|---|---|---|---|
| Page display | `PDFView` (NSView): `displayMode` single page, continuous, two-up, two-up continuous; `displayDirection`, `displaysPageBreaks`, `autoScales`, `scaleFactor`, `scaleFactorForSizeToFit`, min and max scale | SwiftUI wrapper, zoom and mode UI | https://developer.apple.com/documentation/pdfkit/pdfview , https://developer.apple.com/documentation/pdfkit/pdfdisplaymode |
| Navigation | `go(to:)` page, destination or selection; back, forward, first, last, next, previous with `canGo…`; `currentPage`, `visiblePages` | Page-number field, history buttons | https://developer.apple.com/documentation/pdfkit/navigation |
| Built-in find bar | `findInteraction` is iOS and Catalyst only | Folio's own find bar on `findString` / `beginFindString` | https://developer.apple.com/documentation/pdfkit/pdfview/isfindinteractionenabled |
| Markup mode | `isInMarkupMode` (macOS 13+), behaviour docs silent | Folio's own tools | https://developer.apple.com/documentation/pdfkit/pdfview/isinmarkupmode |
| Page overlays | `pageOverlayViewProvider` returns an `NSView` per page (macOS 13+) | The ink canvas and Folio's annotation layer per page | https://developer.apple.com/documentation/pdfkit/pdfview/pageoverlayviewprovider |
| Thumbnails | `PDFThumbnailView`: `allowsDragging` reorders, `allowsMultipleSelection`, `selectedPages` | Undo for reorders (docs silent on undo); Folio draws its own grid from the Model instead | https://developer.apple.com/documentation/pdfkit/pdfthumbnailview |
| Open, pages, metadata | `PDFDocument(data:)`, `page(at:)`, `insert`, `removePage`, `exchangePage`, `outlineRoot`, `documentAttributes` (Info dictionary keys) | Page operations' undo; XMP docs silent | https://developer.apple.com/documentation/pdfkit/read-operations , https://developer.apple.com/documentation/pdfkit/pdfdocumentattribute |
| Search | `findString(_:withOptions:)` sync; `beginFindString` async by notification; `cancelFindString()` | An async wrapper; Folio searches its own page text model instead (section 4) | https://developer.apple.com/documentation/pdfkit/search-operations |
| Locked files | `isEncrypted`, `isLocked`, `unlock(withPassword:)`, `permissionsStatus`, `accessPermissions` | Password sheet | https://developer.apple.com/documentation/pdfkit/pdfdocument/unlock(withpassword:) |
| Save options | `write(to:withOptions:)`: `ownerPasswordOption`, `userPasswordOption`, `accessPermissionsOption` (12+), `burnInAnnotationsOption` (13+), `saveTextFromOCROption` (13+), `saveImagesAsJPEGOption`, `optimizeImagesForScreenOption` (13.4+); every key page docs silent on exact behaviour | Fidelity tests that check what each key does on disk (section 8) | https://developer.apple.com/documentation/pdfkit/pdfdocumentwriteoption |
| Page text | `PDFPage.string`, `numberOfCharacters`, `characterBounds(at:)`, `selection(for:)`, `selectionForWord`, `selectionForLine`, `thumbnail(of:for:)`, `draw(with:to:)`, `PDFPage(image:options:)` (13+) | Mapping to Folio's line model | https://developer.apple.com/documentation/pdfkit/pdfpage |
| Annotation kinds | circle, freeText, highlight, ink, line, link, popup, square, stamp, strikeOut, text (note), underline, widget; markup types include `redact` | Tool UI per kind | https://developer.apple.com/documentation/pdfkit/pdfannotationsubtype , https://developer.apple.com/documentation/pdfkit/pdfmarkuptype |
| Forms | widget field types button, choice, text, signature; radio, checkbox, push button; `widgetStringValue`, `fieldName`, `isReadOnly`, `isMultiline`, `maximumLength`, `buttonWidgetState`, `choices`, `radiosInUnison` | Tab order, validation, required fields | https://developer.apple.com/documentation/pdfkit/pdfannotationwidgetsubtype , https://developer.apple.com/documentation/pdfkit/adding-widgets-to-a-pdf-document |
| Actions | GoTo, Named, RemoteGoTo, ResetForm, URL; no JavaScript, SubmitForm or Launch class | Scripted forms unsupported; detect and say so | https://developer.apple.com/documentation/pdfkit/pdfaction |
| Certificate signatures | only the widget type `signature`; no signing or verifying API | All of it: needs creative-core | https://developer.apple.com/documentation/pdfkit/pdfannotationwidgetsubtype/signature |
| Redaction | `PDFMarkupType.redact` is a markup style; no API removes content; whether burn-in removes what is under it is docs silent | True removal: needs creative-core | https://developer.apple.com/documentation/pdfkit/pdfmarkuptype/redact |
| Edit page text | no PDFKit API edits content streams; CoreGraphics parses (`CGPDFScanner`) but cannot write a modified stream | A content-stream editor: needs creative-core | https://developer.apple.com/documentation/coregraphics/cgpdfscanner |
| JavaScript, XFA | not in the PDFKit symbol index | Unsupported; detect XFA and warn | https://developer.apple.com/documentation/pdfkit |
| Printing | `PDFView.print(with:autoRotate:)`, `PDFDocument.printOperation(for:scalingMode:autoRotate:)` | Menu wiring | https://developer.apple.com/documentation/pdfkit/pdfview/print(with:autorotate:) |
| OCR | `VNRecognizeTextRequest` (10.15+) and the Swift `RecognizeTextRequest` (15+): level, languages, auto-detect, language correction, custom words | Text layer from results | https://developer.apple.com/documentation/vision/recognizetextrequest , https://developer.apple.com/documentation/vision/vnrecognizetextrequest |
| Document structure | `RecognizeDocumentsRequest` (26+): paragraphs, lists, tables | Later: export structure | https://developer.apple.com/documentation/vision/recognizedocumentsrequest |
| Document edges | `VNDetectDocumentSegmentationRequest` (12+): four corners | Later: deskew and crop scans | https://developer.apple.com/documentation/vision/vndetectdocumentsegmentationrequest |
| Scan from iPhone | Continuity Camera: `NSMenuItem.importFromDeviceIdentifier`, `validRequestor(forSendType:returnType:)`, `readSelection(from:)` returns images | Images to pages | https://developer.apple.com/documentation/appkit/supporting-continuity-camera-in-your-mac-app |
| Drawing input | `PKCanvasView` is not on native macOS; `PKDrawing` is | Folio's own ink canvas | https://developer.apple.com/documentation/pencilkit/pkcanvasview |
| Writing PDFs | `CGContext(consumer:mediaBox:_:)` with owner and user password keys; the owner password must be ASCII | Fallback writer | https://developer.apple.com/documentation/coregraphics/cgcontext/init(consumer:mediabox:_:) , https://developer.apple.com/documentation/coregraphics/auxiliary-dictionary-keys |
| Document type | `UTType.pdf` is `com.adobe.pdf` | Declared as Editor, Alternate | https://developer.apple.com/documentation/uniformtypeidentifiers/uttype-swift.struct/pdf |
| Read aloud | `AVSpeechSynthesizer` | Word highlighting | https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer |
| Translate | `TranslationSession` (15+), on device | Later | https://developer.apple.com/documentation/translation/translationsession |
| On-device model | `SystemLanguageModel` (26+): availability, context size | Later: summarize; no dedicated API | https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel |
