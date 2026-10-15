#!/usr/bin/env python3
"""waves.py: the Folio blueprint's features, waves and owned files (section 9).

Checks, and exits 1 on any failure:
  1. no two features in one wave own the same file;
  2. every owned Sources/ path is covered by exactly one component in
     c4-planned.json (glob match on its "paths");
  3. every feature waits only on features of earlier waves.
Prints the owned-file lists as markdown with --markdown.

  python3 docs/blueprints/pdf/waves.py            # check
  python3 docs/blueprints/pdf/waves.py --markdown # the section 9.3 lists
"""
import fnmatch
import json
import os
import sys

M = "Sources/FolioModel/"
A = "Sources/FolioApp/"
T = "Tests/FolioModelTests/"
S = "Tests/AppSnapshotTests/"
U = "UITests/"

CONTRACTS = ["DocumentOpening", "PageImaging", "PageTextReading", "TextFinding", "TextSelecting",
             "Annotating", "FormFilling", "Signing", "SignatureStoring", "PageOrganizing",
             "DocumentHistory", "DocumentWriting", "PageExporting", "TextRecognizing"]
PURE = ["TextFinding", "TextSelecting", "Annotating", "FormFilling", "Signing", "SignatureStore",
        "PageOrganizing", "DocumentHistory"]
AREAS = ["Read", "Find", "Markup", "Forms", "Sign", "Pages", "History", "Files", "Export", "OCR"]
PLATFORM_LIVE = ["PDFKitOpening", "PDFKitImageOpening", "PDFKitImaging", "PDFKitText", "PDFKitFields",
                 "PDFKitAnnotations", "PDFKitWriting", "PDFKitExporting", "VisionRecognizing",
                 "FolioSampleWriter", "FolioSignatureMark"]


def live_pure(name):
    return M + "Live/Live" + name + ".swift"


def fake(name):
    store = "FakeSignatureStore" if name == "SignatureStoring" else "Fake" + name
    return M + "Fakes/" + store + ".swift"


FEATURES = [
    {
        "id": "foundation", "wave": 0, "waits": [],
        "title": "Foundation: targets, contracts, fakes, workspace, the window's seams",
        "covers": "P-T1 (open on fakes), P-T26 (no dead controls); the targets and the audit entry",
        "proves": "P-J0, P-J12, P-J13; PB-1 (fake half); PL1-PL5",
        "prs": 14, "hours": 22,
        "files": (
            [M + "Contracts/FolioValues.swift", M + "Contracts/FolioContracts.swift", M + "Fakes/FolioFakeFile.swift"]
            + [fake(c) for c in CONTRACTS]
            + [M + "Fixtures/FolioFixtures.swift", M + "FolioServices.swift", M + "FolioWorkspace.swift",
               M + "FolioCommand.swift", M + "FolioTool.swift", M + "FolioLaunch.swift", M + "FolioLayout.swift",
               M + "FolioPageSummary.swift"]
            + [M + "Workspace/FolioWorkspace+" + a + ".swift" for a in AREAS]
            + [M + "Availability/FolioAvailability+" + a + ".swift" for a in AREAS]
            + [M + "Tools/FolioTool+" + k + ".swift" for k in ["Select", "TextMarkup", "Annotate", "Sign"]]
            + [live_pure(p) for p in PURE]
            + [A + "FolioApp.swift", A + "FolioWindow.swift", A + "FolioControls.swift",
               A + "PageView/FolioPageView.swift", A + "PageView/FolioPageGestures.swift",
               A + "PageView/FolioMarksLayer.swift", A + "PageView/FolioFieldLayer.swift",
               A + "Sidebar/FolioSidebar.swift", A + "Sidebar/FolioThumbnails.swift",
               A + "Inspector/FolioInspector.swift", A + "Live/FolioServices+Live.swift"]
            + [A + "FolioWindow+" + a + ".swift" for a in AREAS]
            + [A + "FolioCommands+" + a + ".swift" for a in AREAS]
            + [A + "Live/" + n + ".swift" for n in PLATFORM_LIVE]
            + [T + c + "ContractTests.swift" for c in CONTRACTS]
            + [T + n + ".swift" for n in ["FolioCommandTests", "FolioToolsTests", "FolioWorkspaceTests",
                                           "FolioLayoutTests", "FolioFixturesTests", "FolioPageSummaryTests",
                                           "FolioBudget", "FolioFoundationBudgetTests"]]
            + [S + "FolioWindowSnapshots.swift", U + "FolioJourneyTests.swift",
               "UITests/audit-baseline.json", "docs/c4/model.json",
               "Package.swift", "project.yml", "scripts/bundle-apps"]
        ),
    },
    {
        "id": "reader", "wave": 1, "waits": ["foundation"],
        "title": "Open and read: live PDFKit, zoom and view modes, go to page, outline, passwords, open errors",
        "covers": "P-T1, P-T2, P-T3, P-T4, P-T5, P-T20 (recents)",
        "proves": "P-J1, P-J11; PB-1 (live), PB-2, PB-3, PB-4, PB-17; PF-1, PF-2",
        "prs": 8, "hours": 13,
        "files": [A + "Live/PDFKitOpening.swift", A + "Live/PDFKitImaging.swift", A + "Live/PDFKitText.swift",
                  A + "Live/FolioSampleWriter.swift", M + "FolioLayout.swift",
                  M + "Workspace/FolioWorkspace+Read.swift", M + "Availability/FolioAvailability+Read.swift",
                  A + "FolioWindow+Read.swift", A + "FolioCommands+Read.swift", A + "PageView/FolioPageView.swift",
                  A + "Sidebar/FolioOutline.swift", A + "Sheets/FolioPasswordSheet.swift",
                  T + "DocumentOpeningContractTests.swift", T + "PageImagingContractTests.swift",
                  T + "PageTextReadingContractTests.swift", T + "FolioLayoutTests.swift", T + "FolioReadTests.swift",
                  T + "FolioReaderBudgetTests.swift", S + "FolioReaderSnapshots.swift",
                  S + "FolioImagingFidelityTests.swift", S + "FolioTextFidelityTests.swift",
                  S + "FolioImagingBudgetTests.swift", U + "FolioJourneyTests+Read.swift",
                  U + "FolioJourneyTests+OpenErrors.swift"],
    },
    {
        "id": "find", "wave": 1, "waits": ["foundation"],
        "title": "Find text: the find bar, every hit, results list",
        "covers": "P-T6",
        "proves": "P-J2; PB-5",
        "prs": 4, "hours": 6,
        "files": [live_pure("TextFinding"), fake("TextFinding"), M + "Workspace/FolioWorkspace+Find.swift",
                  M + "Availability/FolioAvailability+Find.swift", A + "FolioWindow+Find.swift",
                  A + "FolioCommands+Find.swift", A + "PageView/FolioFindBar.swift", A + "Sidebar/FolioFindResults.swift",
                  T + "TextFindingContractTests.swift", T + "FolioFindTests.swift", T + "FolioFindBudgetTests.swift",
                  S + "FolioFindSnapshots.swift", U + "FolioJourneyTests+Find.swift"],
    },
    {
        "id": "markup", "wave": 1, "waits": ["foundation"],
        "title": "Mark up: select text, highlight, underline, strike out, notes, text boxes, pen, shapes",
        "covers": "P-T7, P-T8, P-T9, P-T10, P-T15 (copy text)",
        "proves": "P-J3, P-J4; PB-6, PB-7, PB-8, PB-9, PB-10",
        "prs": 9, "hours": 15,
        "files": [live_pure("TextSelecting"), live_pure("Annotating"), fake("TextSelecting"), fake("Annotating"),
                  M + "Workspace/FolioWorkspace+Markup.swift", M + "Availability/FolioAvailability+Markup.swift",
                  M + "Tools/FolioTool+Select.swift", M + "Tools/FolioTool+TextMarkup.swift", M + "Tools/FolioTool+Annotate.swift",
                  A + "FolioWindow+Markup.swift", A + "FolioCommands+Markup.swift", A + "PageView/FolioMarksLayer.swift",
                  A + "PageView/FolioSelectionLayer.swift", A + "PageView/FolioPageGestures.swift",
                  A + "Inspector/FolioMarkInspector.swift", A + "Sidebar/FolioMarksList.swift", A + "Live/PDFKitAnnotations.swift",
                  T + "TextSelectingContractTests.swift", T + "AnnotatingContractTests.swift", T + "FolioMarkupTests.swift",
                  T + "FolioToolsTests.swift", T + "FolioMarkupBudgetTests.swift", S + "FolioMarkupSnapshots.swift",
                  U + "FolioJourneyTests+Markup.swift", U + "FolioJourneyTests+Annotate.swift"],
    },
    {
        "id": "forms", "wave": 1, "waits": ["foundation"],
        "title": "Fill forms: fields over the page, Tab order, required fields, clear",
        "covers": "P-T11, P-T12",
        "proves": "P-J5; PB-11; PL8",
        "prs": 6, "hours": 10,
        "files": [live_pure("FormFilling"), fake("FormFilling"), M + "Workspace/FolioWorkspace+Forms.swift",
                  M + "Availability/FolioAvailability+Forms.swift", A + "FolioWindow+Forms.swift", A + "FolioCommands+Forms.swift",
                  A + "PageView/FolioFieldLayer.swift", A + "Inspector/FolioFieldInspector.swift", A + "Live/PDFKitFields.swift",
                  T + "FormFillingContractTests.swift", T + "FolioFormsTests.swift", T + "FolioFormsBudgetTests.swift",
                  S + "FolioFormsSnapshots.swift", S + "FolioFieldOverlayTests.swift", U + "FolioJourneyTests+Forms.swift"],
    },
    {
        "id": "pages", "wave": 1, "waits": ["foundation"],
        "title": "Organize pages: thumbnails, grid, reorder, rotate, delete, insert, combine, extract, split",
        "covers": "P-T13, P-T14, P-T16, P-T17",
        "proves": "P-J7, P-J8; PB-13; PL6, PL7; PF-7",
        "prs": 8, "hours": 13,
        "files": [live_pure("PageOrganizing"), fake("PageOrganizing"), M + "Workspace/FolioWorkspace+Pages.swift",
                  M + "Availability/FolioAvailability+Pages.swift", A + "FolioWindow+Pages.swift", A + "FolioCommands+Pages.swift",
                  A + "Sidebar/FolioThumbnails.swift", A + "PageGrid/FolioPageGrid.swift", A + "Sheets/FolioExtractSheet.swift",
                  A + "Sheets/FolioInsertSheet.swift", T + "PageOrganizingContractTests.swift", T + "FolioPagesTests.swift",
                  T + "FolioPagesBudgetTests.swift", S + "FolioPagesSnapshots.swift", S + "FolioThumbnailLayoutTests.swift",
                  U + "FolioJourneyTests+Pages.swift", U + "FolioJourneyTests+Combine.swift"],
    },
    {
        "id": "history-files", "wave": 1, "waits": ["foundation"],
        "title": "Undo, redo, save, save as, flatten, passwords",
        "covers": "P-T18, P-T19, P-T21",
        "proves": "P-J9, P-J10; PB-14, PB-15; PF-3, PF-5, PF-6",
        "prs": 7, "hours": 12,
        "files": [live_pure("DocumentHistory"), fake("DocumentHistory"), A + "Live/PDFKitWriting.swift",
                  M + "Workspace/FolioWorkspace+History.swift", M + "Workspace/FolioWorkspace+Files.swift",
                  M + "Availability/FolioAvailability+History.swift", M + "Availability/FolioAvailability+Files.swift",
                  A + "FolioWindow+History.swift", A + "FolioWindow+Files.swift", A + "FolioCommands+History.swift",
                  A + "FolioCommands+Files.swift", A + "Sheets/FolioSaveOptionsSheet.swift",
                  T + "DocumentHistoryContractTests.swift", T + "DocumentWritingContractTests.swift", T + "FolioHistoryTests.swift",
                  T + "FolioFilesTests.swift", T + "FolioFilesBudgetTests.swift", S + "FolioRoundTripTests.swift",
                  S + "FolioFlattenTests.swift", S + "FolioPasswordTests.swift", S + "FolioWritingBudgetTests.swift",
                  U + "FolioJourneyTests+History.swift", U + "FolioJourneyTests+Files.swift"],
    },
    {
        "id": "sign", "wave": 2, "waits": ["markup", "forms"],
        "title": "Sign: draw, type or pick a signature and initials; keep them; place them",
        "covers": "P-T22",
        "proves": "P-J6; PB-12; PF-12",
        "prs": 6, "hours": 10,
        "files": [live_pure("Signing"), live_pure("SignatureStore"), fake("Signing"), fake("SignatureStoring"),
                  M + "Workspace/FolioWorkspace+Sign.swift", M + "Availability/FolioAvailability+Sign.swift",
                  M + "Tools/FolioTool+Sign.swift", A + "FolioWindow+Sign.swift", A + "FolioCommands+Sign.swift",
                  A + "Sheets/FolioSignatureSheet.swift", A + "PageView/FolioSignaturePopover.swift",
                  A + "Live/FolioSignatureMark.swift", T + "SigningContractTests.swift", T + "SignatureStoringContractTests.swift",
                  T + "FolioSignTests.swift", T + "FolioToolsTests.swift", T + "FolioSignBudgetTests.swift",
                  S + "FolioSignSnapshots.swift", S + "FolioSignatureRoundTripTests.swift", U + "FolioJourneyTests+Sign.swift"],
    },
    {
        "id": "export-convert", "wave": 2, "waits": ["history-files", "markup"],
        "title": "Export pages and text, new from images, reduce size, print",
        "covers": "P-T23, P-T24, P-T25, P-T27, P-T28",
        "proves": "P-J21, P-J22, P-J23, P-J24; PF-4, PF-10, PF-11",
        "prs": 7, "hours": 12,
        "files": [A + "Live/PDFKitExporting.swift", A + "Live/PDFKitImageOpening.swift",
                  M + "Workspace/FolioWorkspace+Export.swift", M + "Availability/FolioAvailability+Export.swift",
                  A + "FolioWindow+Export.swift", A + "FolioCommands+Export.swift", A + "Sheets/FolioExportSheet.swift",
                  A + "Sheets/FolioReduceSheet.swift", A + "FolioPrinting.swift", T + "PageExportingContractTests.swift",
                  T + "FolioExportTests.swift", S + "FolioExportTests.swift", S + "FolioReduceSizeTests.swift",
                  S + "FolioMarksFidelityTests.swift", U + "FolioJourneyTests+Export.swift", U + "FolioJourneyTests+Images.swift",
                  U + "FolioJourneyTests+Reduce.swift", U + "FolioJourneyTests+Print.swift"],
    },
    {
        "id": "ocr", "wave": 2, "waits": ["reader", "find", "history-files"],
        "title": "Recognize text on scans and keep it as a text layer",
        "covers": "P-T29",
        "proves": "P-J20; PB-16; PF-8, PF-9",
        "prs": 5, "hours": 8,
        "files": [A + "Live/VisionRecognizing.swift", M + "Workspace/FolioWorkspace+OCR.swift",
                  M + "Availability/FolioAvailability+OCR.swift", A + "FolioWindow+OCR.swift", A + "FolioCommands+OCR.swift",
                  A + "Sheets/FolioRecognizeSheet.swift", T + "TextRecognizingContractTests.swift", T + "FolioOCRTests.swift",
                  S + "FolioOCRFidelityTests.swift", S + "FolioOCRRoundTripTests.swift", S + "FolioOCRBudgetTests.swift",
                  U + "FolioJourneyTests+OCR.swift"],
    },
    {
        "id": "core-loop", "wave": 3, "waits": ["reader", "find", "markup", "forms", "pages", "history-files",
                                               "sign", "export-convert", "ocr"],
        "title": "The core loop, live, measured",
        "covers": "every tier-1 row on live services",
        "proves": "P-J14, P-J12 (final), P-J13 (final), P-P1-P-P6",
        "prs": 4, "hours": 6,
        "files": [U + "FolioJourneyTests+Loop.swift", U + "FolioJourneyTests+Perf.swift", U + "FolioJourneyTests.swift",
                  T + "FolioLoopTests.swift", "docs/blueprints/pdf.md"],
    },
    {
        "id": "content-edit", "wave": 4, "waits": ["core-loop"],
        "title": "Conditional: edit existing text in place, and true redaction (needs CorePDF CP-1 to CP-5)",
        "covers": "P-T30, P-T31",
        "proves": "P-J25, P-J26; PF-13",
        "prs": 8, "hours": 16,
        "files": [M + "Contracts/FolioContentEditContracts.swift", M + "Fakes/FakeTextReplacing.swift",
                  M + "Fakes/FakeRedacting.swift", M + "Live/LiveTextReplacing.swift", M + "Live/LiveRedacting.swift",
                  M + "Workspace/FolioWorkspace+ContentEdit.swift", M + "Availability/FolioAvailability+ContentEdit.swift",
                  M + "Tools/FolioTool+ContentEdit.swift", A + "FolioWindow+ContentEdit.swift", A + "FolioCommands+ContentEdit.swift",
                  A + "PageView/FolioRedactionLayer.swift", A + "Sheets/FolioApplyRedactionSheet.swift",
                  T + "TextReplacingContractTests.swift", T + "RedactingContractTests.swift", S + "FolioRedactionTests.swift",
                  U + "FolioJourneyTests+ContentEdit.swift", "Package.swift"],
    },
]


def components(c4_path):
    with open(c4_path) as f:
        model = json.load(f)["model"]
    out = []
    for system in model["systems"]:
        for container in system.get("containers", []):
            for comp in container.get("components", []):
                out.append((comp["id"], comp.get("paths", [])))
    return out


def check(c4_path):
    problems = []
    by_wave = {}
    waves = {f["id"]: f["wave"] for f in FEATURES}
    for f in FEATURES:
        if len(set(f["files"])) != len(f["files"]):
            problems.append(f"{f['id']}: lists a file twice")
        for w in f["waits"]:
            if w not in waves:
                problems.append(f"{f['id']}: waits on unknown {w}")
            elif waves[w] >= f["wave"]:
                problems.append(f"{f['id']} (W{f['wave']}) waits on {w} (W{waves[w]}), not an earlier wave")
        for path in f["files"]:
            by_wave.setdefault((f["wave"], path), []).append(f["id"])
    for (wave, path), owners in sorted(by_wave.items()):
        if len(owners) > 1:
            problems.append(f"W{wave}: {path} owned by {', '.join(owners)}")
    comps = components(c4_path)
    for f in FEATURES:
        for path in f["files"]:
            if not path.startswith("Sources/"):
                continue
            hits = [cid for cid, globs in comps if any(fnmatch.fnmatch(path, g) for g in globs)]
            if len(hits) != 1:
                problems.append(f"{path}: {len(hits)} owning components ({', '.join(hits) or 'none'})")
    return problems


def markdown():
    lines = []
    for f in FEATURES:
        lines.append(f"#### W{f['wave']} · `{f['id']}`: {f['title']}")
        lines.append("")
        lines.append(f"- **Covers:** {f['covers']}")
        lines.append(f"- **Waits on:** {', '.join(f['waits']) or 'nothing'}")
        lines.append(f"- **Proves:** {f['proves']}")
        lines.append(f"- **Estimate:** about {f['prs']} PRs, {f['hours']} agent-hours")
        lines.append(f"- **Owned files ({len(f['files'])}):** " + ", ".join(f"`{p}`" for p in f["files"]))
        lines.append("")
    return "\n".join(lines)


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    if "--markdown" in sys.argv:
        print(markdown())
        sys.exit(0)
    found = check(os.path.join(here, "c4-planned.json"))
    for p in found:
        print("WAVES:", p)
    total = sum(f["hours"] for f in FEATURES)
    print(f"WAVES: {'FAIL' if found else 'PASS'} ({len(FEATURES)} features, {total} agent-hours)")
    sys.exit(1 if found else 0)
