# AfterGlow roadmap

AfterGlow is a free, open-source creative suite for the Mac. One app holds
five: Flare (2D animation), Design (vector and UI design), Photo (raster
editing), Library (photo catalog) and Halo (motion graphics). This page says
what the beta covers, what is still missing, and what comes after it. It
changes as work lands.

## 1. Where we are

**Stage: beta, in progress.** The first beta is aimed at 27 to 29 October
2026. That date is an estimate. The counts below are measured
from the issue tracker. A feature is one piece of work with its own issue; a
slice is one small, tested step of a feature. `scripts/roadmap-numbers`
rewrites this table.

<!-- numbers:start -->
| App | Beta promise | Features done | Slices done |
|---|---|---|---|
| Flare | Draw shapes, key and ease them, play, save, and export an SVG frame or a PNG sequence. | 12 / 19 | 36 / 51 |
| Design | Draw frames, shapes and text, style, group, align and snap them, save, and export PNG or SVG. | 17 / 23 | 56 / 79 |
| Photo | Open a photo, crop it, adjust it with layers, retouch, save with layers kept, and export PNG or JPEG. | 15 / 20 | 40 / 59 |
| Library | Import a folder, cull from the keyboard, develop, crop and export JPEGs. The catalog survives a relaunch. | 12 / 20 | 41 / 64 |
| Halo | Build a composition, key and ease layers, add text, play, save, and render to files. | 16 / 19 | 44 / 54 |
| Suite | One AfterGlow app: onboarding, a home with recents, switching with state kept, Finder opens the right app. | 15 / 17 | 58 / 60 |
| Shared UI | The editor parts every app shares: canvas, timeline, layers, inspector controls. | 28 / 50 | 146 / 234 |
| Engines | The engines underneath: file codecs, geometry, rendering. | 22 / 23 | 77 / 79 |
| **All** | | **137 / 191** | **498 / 680** |

Counts measured on 2026-10-24. At the last three days' pace the remaining slices finish around 2026-10-27 (estimated).
<!-- numbers:end -->

## 2. In the beta, per app

Each table lists the jobs people do in nearly every session (tier 1 in each
app's usage map), plus the ones pulled into the beta since. Links go to the
feature issue.

| Mark | Meaning |
|---|---|
| works | The feature issue is closed. Open bugs against it are listed under Known gaps, and the whole beta build is checked again before release. |
| partial | Some steps have landed. |
| not yet | Planned for the beta, not landed. |

### Flare

| Capability | Status | Issue |
|---|---|---|
| Draw rectangles, ellipses and pen paths; select and transform on the stage | works | [#1514](https://github.com/qbtrix/creative-apps/issues/1514) [#3519](https://github.com/qbtrix/creative-apps/issues/3519) |
| Key position, scale, rotation and opacity; ease; scrub, play and loop | works | [#1515](https://github.com/qbtrix/creative-apps/issues/1515) [#1365](https://github.com/qbtrix/creative-apps/issues/1365) |
| Scenes and layers | works | [#800](https://github.com/qbtrix/creative-apps/issues/800) [#1516](https://github.com/qbtrix/creative-apps/issues/1516) |
| Save, reopen, recover after a crash, Open Recent and file drops | works | [#1365](https://github.com/qbtrix/creative-apps/issues/1365) [#3482](https://github.com/qbtrix/creative-apps/issues/3482) |
| Gradient fills | works | [#3419](https://github.com/qbtrix/creative-apps/issues/3419) |
| Export an SVG frame or a PNG sequence | works | [#1973](https://github.com/qbtrix/creative-apps/issues/1973) |
| Polygons, stars, lines and arrows | partial | [#3451](https://github.com/qbtrix/creative-apps/issues/3451) |
| Place SVG art as editable layers | partial | [#3459](https://github.com/qbtrix/creative-apps/issues/3459) |
| Export MP4 or a looping GIF | partial | [#3481](https://github.com/qbtrix/creative-apps/issues/3481) |
| Open Lottie files, and a check that exported Lottie plays the same elsewhere | partial | [#3791](https://github.com/qbtrix/creative-apps/issues/3791) [#3792](https://github.com/qbtrix/creative-apps/issues/3792) |
| Stroke style: dashes, caps, joins | not yet | [#3452](https://github.com/qbtrix/creative-apps/issues/3452) |
| Select all keys | not yet | [#3538](https://github.com/qbtrix/creative-apps/issues/3538) |

### Design

| Capability | Status | Issue |
|---|---|---|
| Frames, rectangles, ellipses, text and more shapes; zoom and pan | works | [#1500](https://github.com/qbtrix/creative-apps/issues/1500) [#1494](https://github.com/qbtrix/creative-apps/issues/1494) [#3440](https://github.com/qbtrix/creative-apps/issues/3440) |
| Fill, stroke, opacity, text style and gradients | works | [#1497](https://github.com/qbtrix/creative-apps/issues/1497) [#3415](https://github.com/qbtrix/creative-apps/issues/3415) |
| Select several, move, resize, nudge, transform, align and snap | works | [#1495](https://github.com/qbtrix/creative-apps/issues/1495) [#3436](https://github.com/qbtrix/creative-apps/issues/3436) [#1552](https://github.com/qbtrix/creative-apps/issues/1552) |
| Duplicate, group, copy and paste | works | [#1496](https://github.com/qbtrix/creative-apps/issues/1496) |
| Layers panel | works | [#1498](https://github.com/qbtrix/creative-apps/issues/1498) |
| Save, unsaved state, reopen, autosave and history | works | [#1499](https://github.com/qbtrix/creative-apps/issues/1499) [#3434](https://github.com/qbtrix/creative-apps/issues/3434) |
| Eyedropper | works | [#3438](https://github.com/qbtrix/creative-apps/issues/3438) |
| Export PNG and SVG | works | [#1970](https://github.com/qbtrix/creative-apps/issues/1970) |
| Stroke style: dashes, caps, joins | partial | [#3441](https://github.com/qbtrix/creative-apps/issues/3441) |
| Pen paths | not yet | [#3517](https://github.com/qbtrix/creative-apps/issues/3517) |
| Place images | not yet | [#3454](https://github.com/qbtrix/creative-apps/issues/3454) |
| Export JPEG or PNG at an exact pixel size | not yet | [#3467](https://github.com/qbtrix/creative-apps/issues/3467) |
| Open Recent, Open In, file drops and dragging art out | not yet | [#3469](https://github.com/qbtrix/creative-apps/issues/3469) |
| Layer styles | not yet | [#3858](https://github.com/qbtrix/creative-apps/issues/3858) |

### Photo

| Capability | Status | Issue |
|---|---|---|
| Open, save with layers, reopen, Open Recent, crash recovery | works | [#1074](https://github.com/qbtrix/creative-apps/issues/1074) [#3471](https://github.com/qbtrix/creative-apps/issues/3471) |
| Crop, straighten, typed size; free transform, flips, canvas size | works | [#1076](https://github.com/qbtrix/creative-apps/issues/1076) [#3435](https://github.com/qbtrix/creative-apps/issues/3435) |
| Tone and colour; adjustment layers | works | [#1501](https://github.com/qbtrix/creative-apps/issues/1501) |
| Cut, copy, paste as a layer, merge, flatten; select several layers | works | [#1075](https://github.com/qbtrix/creative-apps/issues/1075) [#3535](https://github.com/qbtrix/creative-apps/issues/3535) |
| History tab and autosave | works | [#3437](https://github.com/qbtrix/creative-apps/issues/3437) |
| Brush, eraser, heal, clone, eyedropper, gradient tool | works | [#3439](https://github.com/qbtrix/creative-apps/issues/3439) [#3416](https://github.com/qbtrix/creative-apps/issues/3416) |
| Place an image; text layers | works | [#3455](https://github.com/qbtrix/creative-apps/issues/3455) [#3785](https://github.com/qbtrix/creative-apps/issues/3785) |
| Export PNG and JPEG | works | [Photo v1](docs/photo-v1.md) |
| White balance, tone, presence and sharpen rows | not yet | [#3468](https://github.com/qbtrix/creative-apps/issues/3468) |
| Export at a size, HEIC and TIFF | not yet | [#3470](https://github.com/qbtrix/creative-apps/issues/3470) |
| Layer styles, layer masks and clipping | not yet | [#3793](https://github.com/qbtrix/creative-apps/issues/3793) [#3859](https://github.com/qbtrix/creative-apps/issues/3859) |
| PSD layer effects open as editable styles | not yet | [#3930](https://github.com/qbtrix/creative-apps/issues/3930) |
| Paths and a pen tool (shared with Flare and Design) | not yet | [#5072](https://github.com/qbtrix/creative-apps/issues/5072) |

### Library

| Capability | Status | Issue |
|---|---|---|
| Import a folder, real thumbnails, folders in the sidebar | works | [#1334](https://github.com/qbtrix/creative-apps/issues/1334) [#1506](https://github.com/qbtrix/creative-apps/issues/1506) [#3787](https://github.com/qbtrix/creative-apps/issues/3787) |
| The loupe, with zoom to 100% | works | [#1513](https://github.com/qbtrix/creative-apps/issues/1513) |
| Cull from the keyboard with Auto Advance and undo | works | [#1345](https://github.com/qbtrix/creative-apps/issues/1345) |
| Develop sliders with a histogram; crop | works | [#1527](https://github.com/qbtrix/creative-apps/issues/1527) [#1553](https://github.com/qbtrix/creative-apps/issues/1553) |
| Export JPEG at a long edge | works | [#1554](https://github.com/qbtrix/creative-apps/issues/1554) |
| The catalog is there after relaunch | works | [#1511](https://github.com/qbtrix/creative-apps/issues/1511) |
| Share sheet | works | [#3789](https://github.com/qbtrix/creative-apps/issues/3789) |
| Delete rejected photos, colour label keys | partial | [#3458](https://github.com/qbtrix/creative-apps/issues/3458) |
| Catalog backups and restore | partial | [#3788](https://github.com/qbtrix/creative-apps/issues/3788) |
| Drop photos to import, drag thumbnails out, Open In | partial | [#3479](https://github.com/qbtrix/creative-apps/issues/3479) |
| Stays fast at 10,000 photos | partial | [#3790](https://github.com/qbtrix/creative-apps/issues/3790) |
| Tone and sharpen rows, Auto | not yet | [#3475](https://github.com/qbtrix/creative-apps/issues/3475) |
| Export without location data | not yet | [#3478](https://github.com/qbtrix/creative-apps/issues/3478) |
| Copy on import, remove from catalog, relink missing photos | not yet | [#3786](https://github.com/qbtrix/creative-apps/issues/3786) |
| Camera RAW files | not yet | [#1530](https://github.com/qbtrix/creative-apps/issues/1530) |

### Halo

| Capability | Status | Issue |
|---|---|---|
| A composition, layers, keys with easing | works | [#777](https://github.com/qbtrix/creative-apps/issues/777) [#1036](https://github.com/qbtrix/creative-apps/issues/1036) [#1038](https://github.com/qbtrix/creative-apps/issues/1038) [#1333](https://github.com/qbtrix/creative-apps/issues/1333) |
| Play at the composition rate | works | [#1035](https://github.com/qbtrix/creative-apps/issues/1035) [#1971](https://github.com/qbtrix/creative-apps/issues/1971) |
| Drag a layer in the viewer to key it (fails in a full test run) | partial | [#1036](https://github.com/qbtrix/creative-apps/issues/1036) [#1283](https://github.com/qbtrix/creative-apps/issues/1283) |
| Move and edit keys on the timeline | works | [#3536](https://github.com/qbtrix/creative-apps/issues/3536) |
| Text, shape, gradient and image layers; stroke style; transform | works | [#1509](https://github.com/qbtrix/creative-apps/issues/1509) [#3445](https://github.com/qbtrix/creative-apps/issues/3445) [#3417](https://github.com/qbtrix/creative-apps/issues/3417) [#3456](https://github.com/qbtrix/creative-apps/issues/3456) [#3447](https://github.com/qbtrix/creative-apps/issues/3447) [#3443](https://github.com/qbtrix/creative-apps/issues/3443) |
| Undo, save, reopen, autosave | works | [#1037](https://github.com/qbtrix/creative-apps/issues/1037) [#3442](https://github.com/qbtrix/creative-apps/issues/3442) |
| Render a frame and render to files | works | [#1505](https://github.com/qbtrix/creative-apps/issues/1505) |
| ProRes 4444 with a transparent background | partial | [#3472](https://github.com/qbtrix/creative-apps/issues/3472) |
| Open Recent, file drops, Flare scenes by Open In | partial | [#3474](https://github.com/qbtrix/creative-apps/issues/3474) |
| Layer styles | not yet | [#3936](https://github.com/qbtrix/creative-apps/issues/3936) |

### Suite

| Capability | Status | Issue |
|---|---|---|
| One AfterGlow app that holds all five | works | [#1331](https://github.com/qbtrix/creative-apps/issues/1331) |
| First-launch onboarding, shown once, with sample files | works | [#1972](https://github.com/qbtrix/creative-apps/issues/1972) [#3775](https://github.com/qbtrix/creative-apps/issues/3775) |
| A home with recents; switch apps with state kept | works | [#1503](https://github.com/qbtrix/creative-apps/issues/1503) [#1507](https://github.com/qbtrix/creative-apps/issues/1507) |
| Finder opens the right app; drag between apps; Open Recent everywhere | works | [#3480](https://github.com/qbtrix/creative-apps/issues/3480) |
| Every action is a command, reachable from the `afterglow` CLI and MCP | works | [#2998](https://github.com/qbtrix/creative-apps/issues/2998) [#3000](https://github.com/qbtrix/creative-apps/issues/3000) [#3771](https://github.com/qbtrix/creative-apps/issues/3771) |
| Help > Report a Problem and Beta Notes | works | [#3772](https://github.com/qbtrix/creative-apps/issues/3772) |
| No placeholder menu items | works | [#3776](https://github.com/qbtrix/creative-apps/issues/3776) |
| The CLI inside the app; Help > Connect an AI Assistant | partial | [#3773](https://github.com/qbtrix/creative-apps/issues/3773) |
| Switch To, AI Access and Help menus in every editor | partial | [#3774](https://github.com/qbtrix/creative-apps/issues/3774) |

Every app gets one shared zoom ([#5070](https://github.com/qbtrix/creative-apps/issues/5070)).

## 3. Known gaps

- **This is a beta.** Keep a copy of work you care about. File formats can
  still change before the first release.
- **Save often.** Not every app autosaves yet, so a crash can lose edits
  since the last save.
- **Some tools are dimmed.** A tool or menu item that can't act yet says why
  in its tooltip.
- **Halo's viewer and render can differ.** The viewer blends layer opacity
  differently from the render, so a frame can look slightly different on
  screen and in the file ([#1185](https://github.com/qbtrix/creative-apps/issues/1185)).
- **Imported PSD files** with layer opacity or blend modes can draw
  differently from the app that made them ([#3500](https://github.com/qbtrix/creative-apps/issues/3500)).
- **Some checks still fail on the Mac.** Drags and text scale in Design,
  dragging in Halo's viewer, very large Halo compositions, and the home at
  some window widths ([#3261](https://github.com/qbtrix/creative-apps/issues/3261) [#3263](https://github.com/qbtrix/creative-apps/issues/3263) [#1283](https://github.com/qbtrix/creative-apps/issues/1283) [#1262](https://github.com/qbtrix/creative-apps/issues/1262) [#3258](https://github.com/qbtrix/creative-apps/issues/3258)).
- **Photo selects rectangles only.** Ellipse, lasso and the rest come after
  the beta.
- **No layer groups in Photo, no video clips in Halo, no local adjustments in
  Library** (gradient or brush) in the beta.
- **No updater.** To update, download the new build.
- **Settings is undecided.** The beta may ship a small Settings window or
  none. The rendering choice is in the View menu.

## 4. After the beta, in order

### 4.1 Weekly features (tier 2)

| App | Next |
|---|---|
| Flare | Symbols and instances, onion skin and motion paths, the curve editor |
| Design | Components and instances, variables with light and dark modes, PDF export |
| Photo | Ellipse and lasso selections, add, subtract, invert and feather; layer groups |
| Library | Filter by flag or rating, collections, a metadata panel, compare two photos |
| Halo | Effects (blur, fill, levels), precompose, footage layers, per-property lanes |
| Suite | Library to Photo and back, shared colour and asset libraries, a Settings window, the updater |

### 4.2 Plugins

Every AfterGlow action is already a command the `afterglow` CLI and MCP can
reach. Plugins start there: people and AI agents build them on the fly by
combining commands, with no code loaded into the app. Publishing them to an
AfterGlow marketplace comes later. Until then the command catalog keeps
growing, because it is the plugin base.

### 4.3 Paid modules

| Module | Adds | Price |
|---|---|---|
| Team | Hosted sync, live co-editing over the internet, shared libraries, comments, version history | A small subscription that funds the suite |
| AI | AI features in every app, through a Paw OS account | Included with Paw OS |
| Enterprise | Single sign-on, fleet deployment, admin and policy controls | A contract per company |

The core stays open source under the GPL, free, with no account. A paid
module adds a service, such as a server, a model or an admin console. No
module takes a tool away from the core. Details: [docs/licensing.md](docs/licensing.md).

## 5. Later apps

Research only. Each has a blueprint and no code yet.

| App | Working name | What it would do | Plan |
|---|---|---|---|
| 3D | Prism | Scenes, models, materials, lights, cameras and keys; renders stills and frame sequences for Halo, Flare and Design | [docs/blueprints/3d.md](docs/blueprints/3d.md) |
| PDF | Folio | Read, mark up, fill, sign, organize, lightly edit and export PDFs | [docs/blueprints/pdf.md](docs/blueprints/pdf.md) |

## 6. After the beta, by tier

**Next, right after the beta:**

- Photo magic wand.
- Photo skew, distort and perspective.
- Halo masks and track mattes.
- Halo motion blur.
- Design Auto Layout.

**Later:**

- Photo print setup.
- Halo expressions, keying, tracking and 3D layers.

**Not planned:**

- One shared window or menu bar for all apps. Each app keeps its own windows
  inside the one AfterGlow app.
- Cloud sync or accounts in the free core. Hosted sync comes as the paid Team
  module.
- Third-party code running inside an app. Plugins work through commands, the
  CLI and MCP.
- iPad, iPhone and a sandboxed App Store build, for now.

## 7. Progress log

Dates are merge dates of pull requests (from git) or close dates of feature
issues.

| Date | Milestone |
|---|---|
| 2026-10-12 | App shells, the shared UI kit and CI in place (PR [#1](https://github.com/qbtrix/creative-apps/issues/1)) |
| 2026-10-14 | Photo v1, the first raster editor build for daily use (PR [#581](https://github.com/qbtrix/creative-apps/issues/581)) |
| 2026-10-17 | AfterGlow.app assembled from all five apps (PR [#1445](https://github.com/qbtrix/creative-apps/issues/1445)); beta plans for Flare and Design export, onboarding and Halo playback (PR [#1968](https://github.com/qbtrix/creative-apps/issues/1968)) |
| 2026-10-18 | Flare draw, key and save loop ([#1365](https://github.com/qbtrix/creative-apps/issues/1365)); Halo render to files ([#1505](https://github.com/qbtrix/creative-apps/issues/1505)); Photo adjustment layers ([#1501](https://github.com/qbtrix/creative-apps/issues/1501)) |
| 2026-10-19 | The home ([#1503](https://github.com/qbtrix/creative-apps/issues/1503)), onboarding ([#1972](https://github.com/qbtrix/creative-apps/issues/1972)), the `afterglow` CLI ([#2998](https://github.com/qbtrix/creative-apps/issues/2998)), Design window ([#1494](https://github.com/qbtrix/creative-apps/issues/1494)) |
| 2026-10-20 | Flare export ([#1973](https://github.com/qbtrix/creative-apps/issues/1973)), Library develop and export ([#1527](https://github.com/qbtrix/creative-apps/issues/1527) [#1554](https://github.com/qbtrix/creative-apps/issues/1554)), app switching ([#1507](https://github.com/qbtrix/creative-apps/issues/1507)), MCP ([#3000](https://github.com/qbtrix/creative-apps/issues/3000)) |
| 2026-10-21 | Design export ([#1970](https://github.com/qbtrix/creative-apps/issues/1970)); Halo playback keeps up at the composition rate ([#1971](https://github.com/qbtrix/creative-apps/issues/1971)) |
| 2026-10-22 | Every action a command with its state ([#3771](https://github.com/qbtrix/creative-apps/issues/3771)); Report a Problem and Beta Notes ([#3772](https://github.com/qbtrix/creative-apps/issues/3772)) |
