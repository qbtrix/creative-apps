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
  sites (https://superuser.com, https://askubuntu.com,
  https://apple.stackexchange.com, https://unix.stackexchange.com), 58.8 million
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
| Rendering library and viewer | 2,999 (mirror) | – | 60 open enhancements on its bug tracker | https://bugs.ghostscript.com |
| A desktop environment's document viewer (1) | 1,541 (mirror) | – | 560 open wishlist items | https://bugs.kde.org |
| Another desktop environment's document viewer (new) | 78 | 255 | 51 `1. Feature` | https://gitlab.gnome.org/GNOME/papers |
| The same environment's document viewer (classic) | 74 | 825 | 65 `1. Feature` | https://gitlab.gnome.org/GNOME/evince |
| An open-source office suite's PDF import and drawing | – | – | 113 open enhancements with "pdf" in the title; 54 open bugs titled "pdf import" | https://bugs.documentfoundation.org |
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

A tech news forum, https://news.ycombinator.com (read through its public search
API; a large general forum site could not be fetched from this session, so
no counts from it are claimed):

- A launch post for a free in-browser PDF editor (791 points,
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
| Document type | `UTType.pdf` is the system PDF type | Declared as Editor, Alternate | https://developer.apple.com/documentation/uniformtypeidentifiers/uttype-swift.struct/pdf |
| Read aloud | `AVSpeechSynthesizer` | Word highlighting | https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer |
| Translate | `TranslationSession` (15+), on device | Later | https://developer.apple.com/documentation/translation/translationsession |
| On-device model | `SystemLanguageModel` (26+): availability, context size | Later: summarize; no dedicated API | https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel |

---

## F. Pain points: public complaints about today's tools (2026-10-15)

Behind blueprint section 1A. Sources: a consumer review site's company
pages (review counts, share of one-star reviews, themes in the reviews
visible on the first page), a business complaints bureau's profile, the
platform's support forum ("me too" counts; it shows no views), other
vendors' community forums (views and replies), the Q&A sites (views and
scores, from the public API), a tech news forum (points and comments, from
its public search API), and open-source issue trackers (position in the
most-reacted order; this pass couldn't read reaction counts, so it gives
positions and comment counts, and where a request appears in section B its
reaction count from that pass is cited, for example 46 👍 for editing text
in place). A large general forum site
couldn't be fetched, and app-store reviews gave no usable complaint data.
Units differ, so ranks combine frequency (independent sources) with
loudness by judgement, not by sum.

| # | Pain point | Signals | URLs |
|---|---|---|---|
| 1 | Subscription lock-in, hidden cancellation fees, "free" tools that charge at download, trials that turn into yearly charges | a leading vendor's review page: 7,534 reviews, score 1.1 of 5, 91% one-star, cancellation fees in 5 of 24 visible reviews; forum thread 817 points / 587 comments; a forum item on a government cancellation-fee settlement (headline only seen); a form-filling site's review page (18,181 reviews): 4 of 8 visible negatives "pay to download", 4 "hidden subscription"; a converter site's review page: 102,138 reviews, 15% one-star; a converter's complaints-bureau profile: rated F, 40 complaints in 3 years (a 1.45 one-time charge, then 249 a year) | https://www.trustpilot.com/review/www.adobe.com ; https://news.ycombinator.com/item?id=26786563 ; https://news.ycombinator.com/item?id=47368793 ; https://news.ycombinator.com/item?id=40713216 ; https://www.trustpilot.com/review/pdffiller.com ; https://www.trustpilot.com/review/pdfguru.com ; https://www.bbb.org/us/nd/fargo/profile/tech-support/files-editor-0704-1000077989/complaints ; https://news.ycombinator.com/item?id=27005475 ; https://www.gtlaw.com/en/insights/2024/7/ftc-targets-adobe-for-hidden-fees-and-deceptive-subscription-practices |
| 2 | Marks disappear after save or are invisible in another reader | platform forum: 366 and 9 "me too"; Q&A "forms/annotations filled in the built-in viewer appear blank to other users": 41,232 views; "corrupted PDF and lost all annotations": 8,737 views; an open-source reader's most-reacted issue: compatibility of annotations with other readers; a vendor forum thread on comments shown differently in the built-in viewer | https://discussions.apple.com/thread/253093013 ; https://discussions.apple.com/thread/254652432 ; https://apple.stackexchange.com/questions/68446 ; https://apple.stackexchange.com/questions/224750 ; https://github.com/ahrm/sioyek/issues?q=is%3Aissue+sort%3Areactions-%2B1-desc ; https://community.adobe.com/t5/acrobat-reader-discussions/comments-made-on-acrobat-reader-appear-incorrectly-on-preview/td-p/10057859 |
| 3 | The built-in viewer damages files on save (password added, text layer broken, size grows) | platform forum: 191 and 46 "me too" (password); Q&A on the same: 62,045 views, score 67; a forum post says the bug came back; platform forum "corrupts PDF documents when saving": 39 "me too"; Q&A "file size increases when saving": 29,941 views; "duplicate pages blows up file size": 19,775 views. Workarounds offered: re-export through a print filter, or print to PDF | https://discussions.apple.com/thread/253601818 ; https://discussions.apple.com/thread/254161035 ; https://apple.stackexchange.com/questions/436596 ; https://news.ycombinator.com/item?id=41929248 ; https://discussions.apple.com/thread/4487157 ; https://apple.stackexchange.com/questions/76474 ; https://apple.stackexchange.com/questions/100034 |
| 4 | Can't edit existing text; wrong font after editing | vendor forum "font not available or can't be used in editing": 237,142 views, 46 replies (the font must be installed even when embedded); Q&A "free software to edit PDF on Mac": 56,108 views; a web toolbox's second most-reacted issue (27 comments); forum "why is one company the only one able to edit PDFs": 16 / 11; the 791-point thread's top complaint | https://community.adobe.com/questions-9/font-not-available-or-can-t-be-used-in-editing-1245210/index1.html ; https://apple.stackexchange.com/questions/16226 ; https://github.com/Stirling-Tools/Stirling-PDF/issues?q=is%3Aissue+sort%3Areactions-%2B1-desc ; https://news.ycombinator.com/item?id=34967891 ; https://news.ycombinator.com/item?id=43880962 |
| 5 | Fake redaction | forum: 1,029 / 780 (redactions undone in a public document release), 709 / 122, 529 / 716, 398 / 135 (pixelation), 108 / 54 (copy-paste failure); Q&A: 490,832 views, score 83 | https://news.ycombinator.com/item?id=46368946 ; https://news.ycombinator.com/item?id=46369923 ; https://news.ycombinator.com/item?id=49957068 ; https://news.ycombinator.com/item?id=34031568 ; https://news.ycombinator.com/item?id=980465 ; https://apple.stackexchange.com/questions/22683 |
| 6 | Slow, bloated, hangs | forum "intrusive, slow and non-customizable": 193 / 172; "installer size through the years": 190 / 137; vendor forum "spinning wheel after opening": 37,483 views, 62 replies; Q&A "scrolls so slowly": 86,295; "slow opening PDF files": 48,321; "Mac unresponsive opening complex PDF": 9,955; "viewer hangs opening any PDF": 31,281 | https://news.ycombinator.com/item?id=45598776 ; https://news.ycombinator.com/item?id=45012931 ; https://community.adobe.com/t5/acrobat-discussions/acrobat-dc-spinning-wheel-after-opening-on-osx/td-p/9893773/page/2 ; https://superuser.com/questions/257881 ; https://superuser.com/questions/511192 ; https://apple.stackexchange.com/questions/154624 ; https://apple.stackexchange.com/questions/152188 |
| 7 | Forms won't fill or save; blank elsewhere; scripted forms stuck | vendor forum "Please wait…": 44,297 views; platform forum: 39 and 24 "me too"; Q&A "need a later version of the PDF viewer": 36,927; "doesn't save form data": 12,295; forum "browser viewer supports filling forms": 1,093 / 375; a web toolbox's most-reacted issue is form filling | https://community.adobe.com/questions-9/how-do-i-open-the-document-which-states-please-wait-if-this-message-is-not-eventually-replaced-b-1281516 ; https://discussions.apple.com/thread/251612640 ; https://discussions.apple.com/thread/3255797 ; https://apple.stackexchange.com/questions/150785 ; https://apple.stackexchange.com/questions/87528 ; https://news.ycombinator.com/item?id=24554581 |
| 8 | Uploading private documents to web tools | forum threads on local-only tools: 791 / 182, 522 / 185 (office networks block the upload sites), 507 / 231, 366 / 103, 177 / 131; a forum item on a government warning about converter-site scams; an open-source toolbox issue on a tracking pixel sending data after opting out (23 comments) | https://news.ycombinator.com/item?id=43880962 ; https://news.ycombinator.com/item?id=37110628 ; https://news.ycombinator.com/item?id=38765627 ; https://news.ycombinator.com/item?id=40242639 ; https://news.ycombinator.com/item?id=46675231 ; https://news.ycombinator.com/item?id=43704112 |
| 9 | Garbled copied text | Q&A: 461,920, 398,921 and 234,023 views; forum threads on text extraction: 733 / 342, 406 / 235, 357 / 201; Q&A on ligature handling: 1,620 | https://superuser.com/questions/47462 ; https://superuser.com/questions/198392 ; https://superuser.com/questions/137824 ; https://news.ycombinator.com/item?id=22473263 ; https://news.ycombinator.com/item?id=43973721 ; https://apple.stackexchange.com/questions/217532 |
| 10 | No dark reading mode | vendor forum "night mode": 279,436 views; Q&A "adjust PDF contrast": 394,273; Mac Q&A: 132,875, score 106; a browser viewer issue (#2071); forum: 100 / 29 | https://community.adobe.com/t5/acrobat-reader-discussions/night-mode-adobe-pc-version/m-p/7157048 ; https://superuser.com/questions/117521 ; https://apple.stackexchange.com/questions/317845 ; https://github.com/mozilla/pdf.js/issues/2071 ; https://news.ycombinator.com/item?id=47529306 |
| 11 | Interface overhauls, AI pop-ups, upgrade nags | vendor forum "revert to the classic interface": 164,081 views, 108 replies (2026 posts still ask to remove the AI features); "turn off the AI assistant box": 17,336 views; an open-source toolbox's third most-reacted issue: "disable Upgrade to Pro", plus "asks for login at start" | https://community.adobe.com/questions-9/acrobat-2023-how-to-revert-to-classic-gui-user-interface-1285215 ; https://community.adobe.com/questions-12/how-to-turn-off-ask-ai-assistant-box-at-bottom-of-window-1505991/index1.html ; https://github.com/Stirling-Tools/Stirling-PDF/issues?q=is%3Aissue+sort%3Areactions-%2B1-desc |
| 12 | Signatures not portable; certificate signing missing | Q&A: 185,125 (move a signature to another Mac), 51,569 (extract an image of it), 37,790 (camera capture broken), 34,563 (rotate), 18,590 (import from an image); a vendor forum "saved signature gone": 1,719; a browser viewer's most-reacted issue: digital signatures | https://apple.stackexchange.com/questions/74950 ; https://apple.stackexchange.com/questions/49452 ; https://apple.stackexchange.com/questions/343484 ; https://apple.stackexchange.com/questions/348011 ; https://community.adobe.com/questions-9/fill-and-sign-saved-signature-gone-1283304 ; https://github.com/mozilla/pdf.js/issues/1076 |
| 13 | Password and permission confusion | Q&A: 219,318 (remove a usage restriction), 61,340 (remove the password), 58,538 (decrypt), 35,217 (remove a known password without a paid editor), 32,986 (no permission to annotate without the owner password) | https://superuser.com/questions/616844 ; https://superuser.com/questions/86266 ; https://superuser.com/questions/244832 ; https://superuser.com/questions/1272412 ; https://apple.stackexchange.com/questions/441130 |
| 14 | Compression doesn't shrink, or blurs | Q&A: 113,529 (decrease size without losing quality), 34,248 (adjustable ratio); vendor forum threads on files growing after compressing and compression behind a paywall | https://apple.stackexchange.com/questions/297417 ; https://apple.stackexchange.com/questions/33702 ; https://community.adobe.com/t5/acrobat-discussions/why-do-some-pdfs-become-larger-after-compressing-in-adobe-acrobat/m-p/15539848 ; https://superuser.com/questions/85083 |
| 15 | No OCR | Q&A: 72,911 (extract text with OCR), 54,397 (make a PDF searchable), 40,320 and 23,811 (batch OCR), 20,009 (scanned pages with selectable text); forum: 301 / 58 | https://superuser.com/questions/28426 ; https://apple.stackexchange.com/questions/76471 ; https://superuser.com/questions/107678 ; https://superuser.com/questions/1293412 ; https://news.ycombinator.com/item?id=39877391 |
| 16 | Search misses text or stops working | Q&A: 45,628 (search not working), 28,925 (search a phrase), 4,075 (crash when searching), 2,924 (search stops until restart); 13,683 (non-standard encodings) | https://apple.stackexchange.com/questions/281445 ; https://apple.stackexchange.com/questions/155409 ; https://apple.stackexchange.com/questions/167465 ; https://superuser.com/questions/119393 |
| 17 | Printing at the wrong scale | Q&A: 55,962 (print as-is, no scaling), 7,053 (keep the viewer from resizing print output), 4,477 (prints shrunk); vendor forum: 24,024 | https://apple.stackexchange.com/questions/152686 ; https://apple.stackexchange.com/questions/2931 ; https://superuser.com/questions/522181 ; https://community.adobe.com/t5/acrobat-discussions/can-t-print-pdf-to-fit-the-page/m-p/9426194 |
| 18 | Reading comfort basics: last position, tabs, two-up full screen | Q&A: 69,268 (two-page full screen), 42,223 and 30,937 and 12,351 (remember the last page), 21,726 (tabbed reader) | https://superuser.com/questions/250100 ; https://superuser.com/questions/209171 ; https://superuser.com/questions/149948 ; https://apple.stackexchange.com/questions/28028 |
| 19 | Autosave overwrites the original; no undo after a save | platform forum: two weeks of notes lost, recovery only from a backup; Q&A: 12,210 (undo changes accidentally saved), 10,013 (can't delete a page) | https://origin-discussions2-us-dr-prz.apple.com/thread/251227965 ; https://apple.stackexchange.com/questions/331738 ; https://apple.stackexchange.com/questions/426721 |
| 20 | Free web tools capped by size or uses | vendor forum "why not free when it says free?": 1,462; a review of a web tool failing on a 197 MB file | https://community.adobe.com/t5/acrobat-discussions/why-not-free-when-it-says-free/td-p/15275773 ; https://www.trustpilot.com/review/ilovepdf.com |

Below the cut: reader security holes pushing people to a smaller, safer
reader (forum 871 / 418 and 344 / 166:
https://news.ycombinator.com/item?id=23180975 ,
https://news.ycombinator.com/item?id=18669720); accessibility with screen
readers (forum 177 / 78, https://news.ycombinator.com/item?id=28880936 ; a
2024 report of the screen reader skipping pages in long PDFs,
https://mail.applevis.com/comment/173491); crashes on very large files
(https://discussions.apple.com/thread/6625952).

---

## G. Features from the future: drivers and platform facts (2026-10-15)

Behind blueprint section 1B. Apple facts read with the apple-docs tools from
developer.apple.com; market and regulatory facts from public pages. Several
regulatory sources are secondary (law-firm or vendor write-ups) and are
marked so; where sources disagreed the most primary is given.

**Three findings that changed the plan:** the peer-to-peer framework apps
used before is being deprecated (Xcode 27), so F5 uses the Network
framework; the US accessibility deadlines moved on 2026-04-20; and no Apple
API adds tags to an existing PDF (CoreGraphics writes tags only while
drawing a new one).

| Item | Driver (date, source) | Possible now (Apple docs or standard) | Gaps |
|---|---|---|---|
| F1 Ask the document | 75% of knowledge workers use generative AI at work, 78% of them bring their own tools (survey of 31,000 in 31 countries, 2024-05-08: https://news.microsoft.com/source/2024/05/08/microsoft-and-linkedin-release-the-2024-work-trend-index-on-the-state-of-ai-at-work/); 27% of organizations banned it at least for a time, 48% of people entered non-public information, 63% limit what may be entered (2,600 privacy professionals, 2024-01-25: https://newsroom.cisco.com/c/r/newsroom/en/us/a/y2024/m01/organizations-ban-use-of-generative-ai-over-data-privacy-security-cisco-study.html); 26.4% of files uploaded to AI tools held sensitive data in Q3 2025 (vendor, secondary: https://www.businesswire.com/news/home/20251113987633/en/Over-a-Quarter-26-of-Uploads-to-GenAI-Tools-Contain-Sensitive-Data-an-Increase-of-Over-4-in-Just-Three-Months) | https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel ; https://developer.apple.com/documentation/foundationmodels/generable ; https://developer.apple.com/documentation/vision/recognizedocumentsrequest ; https://developer.apple.com/documentation/vision/documentobservation ; https://developer.apple.com/documentation/vision/recognize-tables-within-a-document | supported Macs and regions only; small context; model changes per OS release; image input to the model is macOS 27 (https://developer.apple.com/documentation/foundationmodels/imagereference) |
| F2 Accessible by default | European Accessibility Act from 2025-06-28 (https://www.accessibility-developer-guide.com/knowledge/legal/eaa/ ; secondary: https://www.quadient.com/en-us/blog/eaa-key-dates-requirements-and-impact); US state and local government rule moved on 2026-04-20 to 2027-04-26 and 2028-04-26, court PDFs and online forms in scope (https://www.duanemorris.com/alerts/doj_extends_ada_title_ii_digital_accessibility_deadlines_one_year_0426.html); PDF/UA-2, ISO 14289-2:2024, published 2024-03-13 (https://scc-ccn.ca/standardsdb/standards/8185912); 28.7% of US adults have a disability, 5.5% vision, 13.9% cognitive, 12.2% mobility (CDC, 2024-07-15: https://www.cdc.gov/disability-and-health/articles-documents/disability-impacts-all-of-us-infographic.html) | https://developer.apple.com/documentation/coregraphics/cgpdfcontextbegintag(_:_:_:) (also CGPDFTagType, CGPDFTagProperty, CGPDFContextSetPageTagStructureTree, kCGPDFContextCreatePDFA) | PDFKit can't tag an existing PDF (its only related switch is allowsContentAccessibility); no PDF/UA-2 checker on the platform; the US extension itself cites the limits of generated remediation |
| F3 E-invoices | Germany: receive since 2025-01-01, issue from 2027-01-01 above 800k turnover, nearly all from 2028-01-01, hybrid PDF profiles EN 16931 and EXTENDED only (secondary: https://econnect.eu/en/docs/knowledge/regulations/europe/germany ; https://www.houseblend.io/articles/pdfs/netsuite-xrechnung-zugferd-germany-2027.pdf); France: receive from 2026-09-01 (secondary: https://www.taxually.com/blog/e-invoicing-france-everything-you-need-to-know); EU VAT in the Digital Age adopted 2025-03-11, cross-border digital reporting from 2030-07-01, national alignment by 2035-01-01 (https://taxation-customs.ec.europa.eu/news/adoption-vat-digital-age-package-2025-03-11_en) | the hybrid format: PDF/A-3 with one embedded XML invoice linked from the catalog's associated files (https://pdflib.com/pdf-knowledge-base/zugferd-and-factur-x ; https://ferd-net.de/en/downloads/publications/details/zugferd-23-english); PDF/A output: kCGPDFContextCreatePDFA | PDFKit has no embedded-file API; schema and rule licences to check; Germany's 2027 date was lobbied against, unchanged as of July 2026 |
| F4 Provenance | EU AI Act Article 50 from 2026-08-02, systems already on the market by 2026-12-02 (secondary: https://www.bakerbotts.com/thought-leadership/publications/2026/september/eu-ai-act-article-50-transparency-obligations-go-live ; https://letsdatascience.com/news/eu-ai-act-transparency-rules-take-effect-august-2-81e72020); EU code of practice on marking AI content, final 2026-06-10, at least two layers of machine-readable marking (https://www.jonesday.com/en/insights/2026/06/european-commission-publishes-final-code-of-practice-on-marking-and-labelling-aigenerated-content); content-credential adoption on phones and the trust list frozen 2026-01-01 (secondary: https://softwareseni.com/c2pa-adoption-in-2026-hardware-platforms-and-verification-reality); EU digital identity wallets by late 2026, free qualified signatures reported for 2027 (secondary, dates disagree: https://fintech.global/2026/07/13/eidas-2-0-deadlines-loom-two-tracks-one-trust-chain/) | C2PA 2.2, Appendix A.4, embedding manifests in PDFs (https://spec.c2pa.org/specifications/specifications/2.2/specs/C2PA_Specification.html); PAdES levels B-B to B-LTA (secondary: https://www.pdf-tools.com/pdf-knowledge/pades-pdf-advanced-electronic-signature/); https://developer.apple.com/documentation/security/cmsencoder ; https://developer.apple.com/documentation/security/cmsencodersethasdetachedcontent(_:_:) | no C2PA or PAdES library in the SDKs; requesting an RFC 3161 timestamp through the CMS API unconfirmed; a trust-listed certificate costs money |
| F5 Review together, no account | local-first software essay, 2019 (https://www.inkandswitch.com/essay/local-first/); no dated demand survey found (weak) | https://developer.apple.com/documentation/technotes/tn3213-moving-from-multipeer-connectivity-to-network-framework ; https://developer.apple.com/documentation/network/networklistener ; (Wi-Fi Aware, https://developer.apple.com/documentation/wifiaware , is iOS and iPadOS only: not a Mac path) ; an MIT-listed merge library for Swift (https://github.com/automerge/automerge-swift; licence to be read at a pinned commit before any reuse) | don't build on the deprecated framework; pairing and identity design; the local-network privacy prompt |
| F6 Fill and read by voice | disability figures as F2; speech output: https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer ; a 2026 platform session on exposing app content to the system assistant (https://developer.apple.com/videos/play/wwdc2026/240); no dated dictation survey found (weak) | https://developer.apple.com/documentation/speech/speechanalyzer ; https://developer.apple.com/documentation/speech/speechtranscriber ; https://developer.apple.com/documentation/appintents/indexedentity ; https://developer.apple.com/documentation/appintents/making-actions-and-content-discoverable-by-apple-intelligence | reading order needs F2's tags; languages vary by device |
| F7 Translate in place | 76% prefer information in their own language, 40% never buy in another (8,709 consumers in 29 countries, 2020-07-07: https://csa-research.com/blogs-events/csa-in-the-media/press-releases/consumers-prefer-their-own-language) | https://developer.apple.com/documentation/translation ; https://developer.apple.com/documentation/translation/translationsession/init(installedsource:target:) | fitting text back into boxes; right-to-left scripts; outside the SwiftUI modifier languages must already be installed |
| F8 Signatures that outlive today's cryptography | NIST IR 8547 initial public draft, 2024-11-12 (https://csrc.nist.gov/pubs/ir/8547/ipd); the 2030 and 2035 dates come from secondary write-ups (https://www.encryptionconsulting.com/nist-ir-8547-2030-2035-action-plan/); W3C Verifiable Credentials 2.0 Recommendation 2025-05-15 (https://www.w3.org/TR/vc-data-model/) | https://developer.apple.com/documentation/cryptokit/mldsa65 (also MLDSA87, MLKEM768, MLKEM1024, XWingMLKEM768X25519, macOS 26) | no PDF signature profile for post-quantum algorithms; CMS encoder support for them unverified; no standard way to embed a credential in a PDF |
| (dropped) Spatial review on a headset | third-party shipment estimates: about 390,000 units in 2024, about 45,000 in Q4 2025, the category expected down 42.8% in 2025 (https://www.theregister.com/2026/01/02/apple_vision_pro_meta_quest_sales_drop/) | PDFView on visionOS (https://developer.apple.com/documentation/pdfkit/pdfview); shared spaces (https://developer.apple.com/documentation/groupactivities/configure-your-app-for-sharing-with-people-nearby) | needs a visionOS target; demand falling |
