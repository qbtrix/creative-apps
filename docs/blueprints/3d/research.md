# Prism research notes (3D app blueprint, part 1)

Gathered 2026-10-15 from public sources only. Nothing was installed, run or reverse engineered.
Product, site and survey names are replaced by the ids in the source key below. URLs are kept verbatim, even when they contain a name.

## Source key

### Sources

| Id | Description | URL(s) |
|---|---|---|
| S-OSS | The most-used open-source 3D suite. "The suite" below means S-OSS. | (see the rows below) |
| S-OSS-SURVEY-2025 | That suite's 2025 user feedback survey. 5,102 responses. Raw data is CC BY 4.0. Percentages computed from the raw jsonl. | https://opendata.blender.org/snapshots/blender_feedback_survey_2025.zip , https://survey.blender.org/ |
| S-OSS-SURVEY-2024 | That suite's 2024 user feedback survey. 7,012 responses, fielded Oct 2024. Computed from the raw jsonl. | https://opendata.blender.org/snapshots/blender_feedback_survey_2024.zip , https://survey.blender.org/feedback/2024/ |
| S-QA | The Q&A site for that suite. Tag counts from its public API. | https://api.stackexchange.com/2.3/tags?site=blender&sort=popular , https://blender.stackexchange.com/tags?tab=popular |
| S-DESIGN-QA | The Q&A site for graphic design (same network as S-QA). | https://graphicdesign.stackexchange.com/tags |
| S-FORUM | That suite's largest user forum. | https://blenderartists.org/categories.json |
| S-DEVTALK | That suite's developer discussion forum. | https://devtalk.blender.org/ (threads linked below) |
| S-IDEAS | That suite's feature-idea voting board. Now retired and read-only. | https://blender.community/c/rightclickselect/ , https://blender.community/pagefind/ |
| S-TRACKER | That suite's own issue tracker. | https://projects.blender.org/blender/blender/issues |
| S-EXT | That suite's official extensions (add-on) platform. 1,533 extensions in its API. | https://extensions.blender.org/add-ons/?sort_by=-download_count |
| S-ASSETS | A free CC0 asset library (HDRIs, textures, models). | https://api.polyhaven.com/assets?t=hdris , https://polyhaven.com/stats , https://api.polyhaven.com/assets?type=models |
| S-MARKET | A large 3D model sharing marketplace. | https://help.sketchfab.com/en/articles/16152669-gltf-glb-and-usdz |
| S-WEBLIB | The most-starred open-source web 3D library. | https://github.com/mrdoob/three.js |
| S-ENGINE | An open-source game engine. | https://github.com/godotengine/godot |
| S-ENGINE-PROP | S-ENGINE's public proposals repo. | https://github.com/godotengine/godot-proposals |
| S-GLTF-EXP | The glTF importer/exporter add-on for S-OSS, kept by the glTF standards body. | https://github.com/KhronosGroup/glTF-Blender-IO |
| S-CAD-OSS | An open-source parametric CAD app. | (code host repo; no URL in the notes) |
| S-MESHTOOL | An open-source mesh processing and viewing tool. | https://github.com/cnr-isti-vclab/meshlab |
| S-SKETCHMOD | An open-source sketch-to-3D modeler. | https://github.com/huxingyi/dust3d/issues |
| S-MATNODES | An open-source procedural material node editor. | (code host repo; no URL in the notes) |
| S-PAINT3D | An open-source 3D texture painting tool. | (code host repo; no URL in the notes) |
| S-ENGINE-OSS2 | An open-source game engine built on S-OSS. | (code host repo; no URL in the notes) |
| S-BOXMOD | An open-source subdivision box modeler. | (code host repo; no URL in the notes) |
| S-FORK | A fork of S-OSS with a reworked UI. | (code host repo; no URL in the notes) |
| S-GLTF-LIB | An open-source glTF processing library. | (code host repo; no URL in the notes) |
| S-OPENUSD | The OpenUSD reference implementation repo. | https://github.com/PixarAnimationStudios/OpenUSD |
| S-MATSURVEY | A texture-library vendor's annual 3D artist survey (2025 and 2024 editions). Primary pages returned 403; figures come from press coverage and search snippets. | https://www.poliigon.com/state-of-3d , https://www.poliigon.com/articles/state-of-3d-2024 , https://80.lv/articles/despite-the-hype-only-22-of-3d-artists-regularly-use-ai , https://www.creativebloq.com/ai/3d-artists-are-shunning-ai-generators-survey-suggests |
| S-MOTION-EDU | A motion-design training company's industry surveys (2017, 2019, 2021, 2025). | https://schoolofmotion.com/blog/a-look-ahead-to-2022-industry-trends-report , https://schoolofmotion.com/blog/2019-motion-design-survey , https://schoolofmotion.com/blog/eoy2025 |
| S-JOBS | US occupational database job-posting data, 2025, via a third-party statistics page. | https://www.markstudios.com/research/motion-graphics-statistics , https://www.onetonline.org/link/demand/27-1014.00 |
| S-ARCHVIZ | A rendering-software vendor's 2025 architectural visualization report. More than 1,000 architects/designers, Nov 2024. | https://blog.chaos.com/2025-state-of-archviz-report-insights |
| S-ARCHVIZ-RENDER | An archviz site's 2021 renderer survey. 2,526 responses. Read via search snippet. | https://www.cgchannel.com/?p=133417 |
| S-HERITAGE | An EU cultural-heritage research project's 2022 survey on 3D web infrastructure. | https://pure3d.eu/wp-content/uploads/2022/02/3D-Infrastructure-Survey-Report_PURE3D-1.pdf |
| S-NEWS | A tech news aggregator. Counts from its public search API. | https://news.ycombinator.com/ (items linked below) |
| S-SOCIAL | A link-sharing site's subforum for P-MOTION3D, read through a mirror. | https://reddit.birdcat.cafe/r/Cinema4D/comments/1j9ibis/c4d_or_blender/ |
| S-WEB3D | A browser-based 3D design tool aimed at designers. | https://community.spline.design/ , https://docs.spline.design/llms.txt , https://docs.spline.design/basics/faq.md , https://hunted.space/product/spline/launches/spline-alpha |
| S-CAD-MAC | A Mac/iPad direct-modeling CAD tool. Its user forum. | https://discourse.shapr3d.com/top.json , https://discourse.shapr3d.com/t/9546 |
| S-APPLE | Apple developer documentation, WWDC sessions and developer forums. | (per row in section F) |

### Products and features named inside the sources

| Id | Description |
|---|---|
| R-PT | S-OSS's built-in path-tracing renderer |
| R-RT | S-OSS's built-in real-time renderer |
| T-2D | S-OSS's built-in 2D drawing and animation tool |
| P-RASTER | a commercial raster editor |
| P-RASTER-OSS | an open-source raster editor |
| P-PAINT-OSS | an open-source digital painting app |
| P-VECTOR | a commercial vector editor |
| P-VECTOR-OSS | an open-source vector editor |
| P-LAYOUT | a commercial page-layout app |
| P-DESIGN-SUITE | a commercial design suite (raster, vector, layout) |
| P-COMPOSITE | a commercial compositing and motion-graphics tool |
| P-MOTION3D | a commercial 3D motion tool |
| P-ANIM3D | a commercial 3D animation suite |
| P-PROC-VFX | a commercial procedural VFX tool |
| P-SCULPT | a commercial digital sculpting tool |
| P-TEXPAINT | a commercial 3D texture painting tool |
| P-ENGINE-A | a commercial game engine (the more-listed one) |
| P-ENGINE-B | a second commercial game engine |
| P-VIDEO-GRADE | a commercial video editor with color grading |
| P-VIDEO | a commercial video editor |
| P-RENDER-A, P-RENDER-B | two commercial render engines |

## A. What people do

All from S-OSS-SURVEY-2025 unless marked. Self-selected. Multi-select. Percentages are of people who answered that question.

### A1. Tasks ("What do you do", answered 4,987)

| Share | Task |
|---|---|
| 77.5% | modeling |
| 76.9% | 3D animation |
| 52.1% | generalist |
| 46.1% | lighting |
| 44.3% | texturing |
| 40.7% | sculpting |
| 39.5% | rigging |
| 38.2% | environment art |
| 37.7% | character art |
| 33.1% | compositing |
| 26.1% | concept art |
| 25.5% | motion graphics (1,273 people) |
| 25.1% | simulation/FX |
| 23.6% | video editing |
| 20.2% | archviz |
| 19.0% | 2D animation |
| 18.0% | technical art |
| 17.3% | look-dev |
| 13.0% | add-on dev |
| 11.6% | previz |
| 11.4% | storyboarding |
| 8.5% | pipeline TD |

- Professionals only (paid, employed or own business, n=1,041): 82% modeling, 80% 3D animation, 67% generalist, 56% lighting, 47% texturing, 45% rigging, 43% sculpting, 32% motion graphics.

### A2. Kinds of work ("Kind of work", answered 4,952)

| Share | Kind of work |
|---|---|
| 39.8% | graphic design |
| 35.7% | game dev |
| 32.6% | product visualization |
| 31.9% | film/TV |
| 23.7% | advertising/marketing |
| 23.6% | VFX |
| 22.2% | social-media content |
| 22.1% | archviz |
| 16.5% | game cutscenes (story sequences) |
| 15.2% | CAD/engineering |
| 11.9% | education |
| 9.1% | music videos |
| 7.7% | data viz |
| 7.6% | VR/AR |
| 5.8% | scientific viz |
| 4.2% | UI/UX design |
| 2.4% | medical |

- "What describes you": 69.0% artist, 35.2% designer, 23.6% developer, 22.0% content creator, 21.0% student.
- S-OSS-SURVEY-2024 kind of work (answered 6,459; it had no per-task question): 56.1% film/animation, 39.5% graphic design, 36.6% game dev, 27.9% advertising/marketing, 27.2% VFX, 22.3% archviz, 14.4% CAD, 10.2% VR/AR, 5.0% UI/UX.

### A3. Motion-graphics and designer subgroups (cross-tabs)

- Motion-graphics doers (n=1,273) also do: 94% 3D animation, 85% modeling, 67% lighting, 66% generalist, 60% texturing, 52% compositing, 50% rigging, 45% simulation/FX, 35% 2D animation.
  - Their kind of work: 66% graphic design, 51% product viz, 46% advertising, 44% VFX, 39% social media.
  - Their software alongside: 44% P-RASTER, 42% P-VIDEO-GRADE, 39% P-COMPOSITE, 22% P-VECTOR.
  - Area they want the suite to focus on: 34% physics, 33% animation, 32% geometry nodes, 29% R-PT, 17% modeling only.
- Graphic-design workers (n=1,973): 85.2% 3D animation, 84.4% modeling, 54.1% lighting, 53.7% texturing, 42.4% motion graphics, 42.2% compositing.
- Advertising/marketing workers (n=1,175): 88.6% 3D animation, 81.6% modeling, 69.3% generalist, 63.7% lighting, 52.2% texturing, 49.3% motion graphics. Top focus wish: 39.8% R-PT.
- Product-viz workers (n=1,614): 87% modeling, 82% 3D animation, 60% lighting, 53% texturing, 40% motion graphics. Top focus wish: 37% R-PT.
- Self-described designers (n=1,769): 81% modeling, 78% 3D animation, 51% lighting, 48% texturing, 37% motion graphics. Kind of work: 58% graphic design, 50% product viz.
- S-OSS-SURVEY-2024, people who also use P-COMPOSITE (n=1,289): 76% film/animation, 54% advertising, 52% graphic design. Their #1 focus wish is animation (41%). Their #1 project wish is animation/rigging tools (39%).

### A4. Priorities wanted

Area the suite should focus on (pick up to 3, answered 4,657):

| 2025 | Area |
|---|---|
| 29.0% | animation |
| 27.2% | R-PT |
| 24.7% | modeling |
| 24.0% | paint |
| 23.7% | physics |
| 23.5% | geometry nodes |
| 17.2% | R-RT |
| 13.5% | sculpt |
| 10.9% | compositor |
| 10.9% | rigging |
| 9.7% | UV |
| 9.6% | sequencer |
| 9.3% | UI |
| 7.5% | T-2D |

- S-OSS-SURVEY-2024 areas: 34.3% animation, 25.5% R-PT, 24.3% modeling, 22.7% paint, 22.1% physics, 21.5% geometry nodes, 17.2% R-RT, 13.6% sculpt, 12.6% UV, 11.5% rigging.

Project to focus on (2025):

| 2025 | Project |
|---|---|
| 42.2% | texturing tools |
| 33.3% | animation/rigging tools |
| 25.7% | handling complexity |
| 24.4% | stylized rendering |
| 22.3% | touch |
| 21.1% | baking tools |
| 17.2% | interactive mode |
| 15.8% | USD |
| 15.4% | color management |
| 13.8% | NURBS modeling |
| 11.3% | SDF modeling |

- S-OSS-SURVEY-2024 projects: 41.5% texturing tools, 34.9% animation/rigging tools, 27.4% complexity, 21.7% baking, 20.6% stylized rendering, 14.5% USD.

### A5. Software used alongside (2025, answered 4,517)

| 2025 | Category |
|---|---|
| 34.8% | P-RASTER (commercial raster editor) |
| 28.4% | P-VIDEO-GRADE (commercial video editor with grading) |
| 23.5% | P-TEXPAINT (commercial texture painting) |
| 21.7% | P-ENGINE-A (commercial game engine) |
| 20.1% | P-COMPOSITE (commercial compositing tool) |
| 18.6% | P-PAINT-OSS (open-source painting app) |
| 14.4% | P-RASTER-OSS (open-source raster editor) |
| 12.9% | P-DESIGN-SUITE (commercial design suite) |
| 12.8% | P-ENGINE-B (second commercial game engine) |
| 12.4% | S-ENGINE (open-source game engine) |
| 11.8% | P-VECTOR (commercial vector editor) |
| 10.8% | P-VECTOR-OSS (open-source vector editor) |
| 9.9% | P-SCULPT (commercial sculpting tool) |
| 8.7% | P-VIDEO (commercial video editor) |
| 8.1% | P-PROC-VFX (commercial procedural VFX tool) |
| 5.3% | P-ANIM3D (commercial 3D animation suite) |
| 3.3% | P-MOTION3D (commercial 3D motion tool) |

- S-OSS-SURVEY-2024 alongside: 37.7% P-RASTER, 25.2% P-VIDEO-GRADE, 22.7% P-COMPOSITE, 22.6% P-TEXPAINT, 22.4% P-ENGINE-A, 13.6% P-VECTOR, 3.4% P-MOTION3D.
- S-OSS-SURVEY-2024 enabled add-ons (free text): dominated by add-ons that ship enabled, so a weak signal. FBX import/export 2,321; a node-editing helper 2,298; glTF import/export 2,264; SVG curve import 2,257; R-PT also listed (no count in the notes). It shows FBX, glTF and SVG import/export are among the most-listed enabled add-ons.

### A6. AI use and how often (2025)

- AI: 30.7% not interested, 29.6% no but interested, 19.0% occasionally, 7.0% regularly.
- Of AI users (n=1,243): 49.4% scripting, 47.4% concept art, 34.2% modeling reference, 30.2% texture.
- Frequency: 52.9% daily, 30.2% weekly.
- Make money: 50.3% no, 28.7% a little, 13.0% employed, 8.0% own business.

## B. What people ask about

### B1. S-QA tag counts, all-time (fetched 2026-10-15; site total 123,167 questions)

Top 30:

| Questions | Tag |
|---|---|
| 15,583 | modeling |
| 13,632 | python |
| 11,198 | rendering |
| 11,118 | animation |
| 9,495 | mesh |
| 9,251 | R-PT render engine |
| 8,463 | texturing |
| 7,206 | materials |
| 6,738 | scripting |
| 6,127 | modifiers |
| 5,968 | geometry-nodes |
| 5,816 | rigging |
| 5,594 | uv |
| 4,499 | node-editor |
| 4,062 | objects |
| 3,757 | shaders |
| 3,673 | 3d-view |
| 3,560 | armature |
| 3,288 | particles |
| 3,003 | interface |
| 2,946 | edit-mode |
| 2,875 | bones |
| 2,850 | add-on |
| 2,799 | export |
| 2,782 | bezier-curves |
| 2,489 | vertices |
| 2,414 | camera |
| 2,275 | R-RT |
| 2,245 | transforms |
| 2,235 | physics |

Other tags of interest: 2,077 compositing-nodes; 1,903 transparency; 1,771 lighting; 1,764 import; 1,651 sculpting; 1,603 video-sequence-editor; 1,547 keyframes; 1,496 light; 1,455 texture-painting; 1,407 weight-painting; 1,381 texture-baking; 1,299 shader-nodes; 1,280 constraints; 1,277 baking; 1,227 fluid-simulation; 1,159 rigid-body; 1,156 cloth; 1,047 T-2D; 1,006 drivers; 809 shadows; 785 normal-map; 758 shape-keys; 686 .fbx; 575 text-object; 387 gltf; 379 graph-editor; 351 hdri; 293 svg; 260 dopesheet; 226 obj; 126 depth-of-field; 122 motion-blur; 107 alembic.

### B2. S-QA tag counts since 2024-01-01 (site total 13,585)

Via the API `/questions?tagged=X&fromdate=2024-01-01&filter=total`.

| Questions | Tag |
|---|---|
| 2,441 | geometry-nodes |
| 1,726 | modeling |
| 1,251 | animation |
| 1,102 | python |
| 889 | rendering |
| 889 | rigging |
| 774 | texturing |
| 723 | materials |
| 617 | modifiers |
| 557 | uv |
| 525 | R-PT |
| 482 | shader-nodes |
| 403 | bezier-curves |
| 305 | lighting |
| 254 | export |
| 252 | R-RT |
| 237 | compositing-nodes |
| 227 | T-2D |
| 197 | sculpting |
| 192 | camera |
| 186 | keyframes |
| 165 | physics |
| 152 | import |
| 104 | .fbx |
| 67 | text-object |
| 55 | gltf |

- 18%: geometry nodes is now the #1 tag of recent questions. 12.7% modeling, 9.2% animation.

### B3. Formats named in S-QA question titles (all-time)

Via the API `/search?intitle=X`. Word match on title, so rough.

- 820 fbx
- 612 obj
- 302 svg
- 297 gltf
- 247 stl
- 134 glb
- 119 collada
- 82 alembic
- 81 dae
- 49 ply
- 15 usd

### B4. S-FORUM category topic counts (fetched 2026-10-15)

Support categories:

- 54,684 Basics & Interface
- 42,099 Modeling
- 35,596 Materials and Textures
- 35,525 Animation and Rigging
- 24,909 Python Support
- 14,807 Technical Support
- 14,615 Lighting and Rendering
- 12,213 Compositing and Post Processing
- 10,699 Particles and Physics
- 10,272 Tutorials/Tips
- 234 Geometry Nodes (new category)

Other: 42,835 Game Engine Support; 110,020 Finished Projects; 45,157 WIP; 11,538 Animations (artwork).

### B5. S-DESIGN-QA: the 3d tag against the rest (fetched 2026-10-15)

- 9,362 P-VECTOR
- 8,600 P-RASTER
- 2,793 P-LAYOUT
- 2,302 P-VECTOR-OSS
- 603 3d
- 570 animation
- So 3D is a small slice of graphic designers' questions: about 600 against 9,362 for P-VECTOR.

## C. What people download

### C1. S-ASSETS downloads by asset type (fetched 2026-10-15)

- 74,143,032 downloads of HDRIs: 997 assets, mean 74,366 per asset.
- 41,290,229 downloads of textures: 869 assets, mean 47,514.
- 8,700,037 downloads of models: 521 assets, mean 16,698.
- 60%: HDRIs' share of all downloads. Lighting environments are the most-wanted free asset.
- HDRI categories: outdoor 705 assets / 59.0M; indoor 301 / 15.7M; studio 96 / 7.0M; skies 299 / 34.0M.
- Top items: HDRI kloofendal_48d_partly_cloudy_puresky 878,774; texture plywood 732,132; model grass_medium_01 243,838.
- Stats page, monthly: 1.4M downloads, 11.0M users, 394 TB bandwidth.
- Each model's files come as S-OSS native, glTF, USD and FBX (no OBJ). Downloads per format: not found.

### C2. S-EXT most-downloaded add-ons by kind of tool (fetched 2026-10-15)

| Downloads | Kind of tool |
|---|---|
| 2M | a loop-editing modeling helper |
| 1M | extra mesh primitives |
| 1M | a boolean modeling helper |
| 856K | extra curve primitives |
| 652K | a 3D-print checking toolbox |
| 593K | an importer for a dance-animation model format |
| 497K | a landscape/terrain generator |
| 421K | a quick face-fill modeling helper |
| 371K | a cell fracture (shatter) tool |
| 325K | an architectural mesh generator |
| 318K | a bolt and nut generator |
| 314K | VRM avatar format support |
| 308K | an automatic mirror modeling helper |
| 304K | a UV editing helper |
| 302K | a layer-based texture painting add-on |
| 284K | a tree generator |

- Modeling helpers dominate the top. 1,533 extensions are listed in the API.

## D. Industry surveys

- S-MATSURVEY 2025: 3,779 responses. 79% use S-OSS, 56% P-RASTER, 29% P-TEXPAINT, 27% P-ENGINE-A.
  - "Advertising remains the dominant source of 3D work" (no % in coverage).
  - AI: 68% never use AI 3D model generators. AI image generators: 26% never, 15% weekly, 7% daily.
  - Coverage dated 2025-11-12. The primary page returned 403; industry % not found.
- S-MATSURVEY 2024: 6,251 respondents, 7 apps x 13 questions. 83% voted P-MOTION3D best for advertising; 98% voted P-PROC-VFX best for VFX. From search snippets; page returned 403. The sample skews toward S-OSS users (a popular S-OSS tutorial channel's audience).
- S-MOTION-EDU 2021 (run with two commercial software vendors, more than 2,000 surveyed): "nearly 17% of artists surveyed also work in" P-MOTION3D.
- S-MOTION-EDU 2019 (1,065 respondents, 95 countries): about 8 in 10 primarily work in P-COMPOSITE. "3D" ranked #1 most exciting prospect and "Shift to 3D" #4 concern (no %).
- S-MOTION-EDU 2017: about 1,300 responses. 3D charts are images; numbers not found.
- S-MOTION-EDU 2025 year-end page: no 3D % in the text. Not found.
- S-JOBS 2025, US job postings for special effects artists and animators: 32% P-COMPOSITE, 15% P-ANIM3D, 8% P-MOTION3D, 7% P-ENGINE-A, 5% P-PROC-VFX.
- The best number for 3D in motion design is the cross-tab in A3: 25.5% of S-OSS users do motion graphics.
- S-ARCHVIZ 2025: 26% use animations frequently; 43% say slow rendering is a major challenge; 11% use AI in their viz workflow.
- S-ARCHVIZ-RENDER 2021 (2,526 responses, via search snippet): about 60.6% P-RENDER-A, 37.2% P-RENDER-B.
- S-HERITAGE 2022 (mostly cultural-heritage researchers; niche sample), formats used: 85% OBJ, 42% STL, 35% S-OSS native, 33% FBX, 29% glTF, 27% GLB, 21% PLY, 17% DAE.
- S-OSS-SURVEY-2025: 15.8% want USD as a focus project (2024: 14.5%).
- Format adoption % from the glTF standards body, a commercial game engine vendor or the wider industry: not found (only unverifiable blog claims).

## E. What open-source users ask for and say is missing

Fetched 2026-10-15 unless another date is given. Code host numbers came from a repo search tool and from public repo pages, because the CLI API was blocked for unattached repos. S-SOCIAL's own API was blocked, so that material is secondary.

### E1. S-IDEAS feature board

- The board is retired and read-only. Its page says voting, commenting and posting are closed, and points to S-FORUM, S-TRACKER and a newer forum.
- 17,379 ideas listed ("top voted first, page 1 of 348"). The site's static search index holds 17,749 entries.
- Status counts: 16,055 Open, 830 Done, 241 Incomplete, 217 Archived, 205 Duplicate, 193 In Development, 8 Rejected. About 4.7% are Done.

Ideas per category (one idea can carry several, so these add up to more than the total):

| Ideas | Category |
|---|---|
| 6,287 | User Interface |
| 5,430 | General |
| 3,272 | Modeling |
| 1,813 | Rendering |
| 1,694 | Shading and Textures |
| 1,521 | Animation |
| 1,457 | Geometry Nodes |
| 797 | Compositing |
| 777 | T-2D |
| 733 | Rigging |
| 730 | Sculpting |
| 634 | Interoperability (import/export) |
| 493 | 3D Viewport |
| 492 | Video Sequencer |
| 464 | Painting |
| 461 | Scripting |
| 405 | Simulation |
| 258 | Meta |
| 251 | Particles |
| 232 | Asset Browser |
| 175 | UV Editing |
| 143 | Outliner |
| 105 | Game Engine |
| 103 | Motion Tracking |
| 49 | Extensions |
| 41 | Library Overrides |
| 31 | Text Editor |
| 16 | Benchmark |

- Keyword hits in the index (fuzzy full-text, so rough): 598 "Mac", 299 "beginner", 208 "FBX", 133 "Metal", 92 "USD", 52 "glTF".

### E2. S-IDEAS top ideas by votes

Up / down / comments, category, status, date. Parsed from pages 1 and 2.

1. 740/12/71: Add more noise type nodes. Shading, In Development, 2019-05-13. https://blender.community/c/rightclickselect/V8bbbc/
2. 648/5/58: Tension/Stress Maps. General, Open, 2020-07-07. https://blender.community/c/rightclickselect/zQfbbc/
3. 555/7/80: CAD-like snapping objects (by basepoint). Modeling, In Dev, 2020-03-04. https://blender.community/c/rightclickselect/3Dbbbc/
4. 510/9/68: Destructive Extrude (Push and Pull). Modeling, In Dev, 2020-06-09. https://blender.community/c/rightclickselect/Qlcbbc/
5. 470/5/14: Better UV visualization (random colors, checker overlay). Shading, Open, 2018-11-20. https://blender.community/c/rightclickselect/Dpcbbc/
6. 438/6/33: Retain previous render while rendering with render border. Rendering, Open. https://blender.community/c/rightclickselect/7cbbbc/
7. 426: Open menu and search after dragging a noodle. Done. https://blender.community/c/rightclickselect/bMbbbc/
8. 403: Parallax Occlusion Mapping. Open. https://blender.community/c/rightclickselect/t9bbbc/
9. 395: Drag n Drop Modifier Stack. UI, Done. https://blender.community/c/rightclickselect/fbbbbc/
10. 377: Add Randomness in Array Modifier. Done. https://blender.community/c/rightclickselect/XQcbbc/
11. 364/12/53: A Container Object (Real Grouping System). General, Open. https://blender.community/c/rightclickselect/Rcbbbc/
12. 322: Edit-Mesh Modifier. Open. https://blender.community/c/rightclickselect/Gscbbc/
13. 321: Improve bezier tools. Done. https://blender.community/c/rightclickselect/zpdbbc/
14. 321: Curve resolution based on tangent angle. Open. https://blender.community/c/rightclickselect/mkbbbc/
15. 313: Volumetric fog like another renderer's. Open. https://blender.community/c/rightclickselect/rmQw/
16. 309: Boolean for T-2D in Draw mode. Open.
17. 306: Improve Undo System. Done. https://blender.community/c/rightclickselect/6mdbbc/
18. 306: Highlight UV selection in 3D view. Done.

Further down:

- 246 New Render Window.
- 234 Full CAD drawing toolset (Open).
- 210 Drag and drop import for standard file formats (Open). https://blender.community/c/rightclickselect/WVcbbc/
- 169 Editable Motion Path for animating (Open). https://blender.community/c/rightclickselect/VDbbbc/
- 158 Manipulate origin in Edit mode.
- 153 Align and Distribute (Open). https://blender.community/c/rightclickselect/qgcbbc/
- 139 Visual Hotkey Input Editor.
- 136 Drag and Drop Import for OBJ/FBX/DAE/glTF (Done). https://blender.community/c/rightclickselect/zgcbbc/
- 119 Show UV distortion heat map in 3D view.
- 107 A "panic button" for the suite. https://blender.community/c/rightclickselect/2rfbbc/

Themes in the top 100: precise snapping and CAD-style direct modeling (push/pull, base-point snap, align/distribute); grouping and containers; UV visibility; curve/bezier tools; drag-and-drop import; undo; non-destructive modifiers.

### E3. S-TRACKER open issues by module

- 6,876 open issues in total. https://projects.blender.org/blender/blender/issues
- Counts from the tracker API's issue total per label.

| Open | Module |
|---|---|
| 896 | User Interface |
| 825 | Nodes & Physics |
| 801 | Modeling |
| 728 | Viewport & R-RT |
| 612 | Render & R-PT |
| 383 | Animation & Rigging |
| 335 | T-2D |
| 270 | Python API |
| 262 | VFX & Video |
| 237 | Core |
| 220 | Pipeline & IO (import/export) |
| 136 | Asset System |
| 92 | Platforms & Builds |
| 6 | Triaging |

- Sculpt, Paint & Texture: not measurable, because the comma in the label name breaks the API filter.
- By type: 4,022 Bug; 1,103 Known Issue; 1,002 To Do; 738 Design.
- By platform: 82 macOS, 67 Windows, 49 Linux.
- By interest: 185 R-RT, 137 R-PT, 94 Performance, 47 USD, 38 Import Export, 35 FBX, 19 Metal.

### E4. Other open-source 3D projects (stars / open issues incl. PRs, 2026-10-15)

- 118,413 / 18,852: S-ENGINE.
- 116,427 / 400: S-WEBLIB.
- 34,299 / 3,991: S-CAD-OSS.
- 20,910 stars, issues disabled: the S-OSS mirror on the code host.
- 7,538 / 1,005: S-OPENUSD.
- 5,988 / 306: S-MATNODES.
- 5,868 / 196: S-MESHTOOL.
- 3,584 / 8: S-SKETCHMOD.
- 3,350 / 398: S-ENGINE-OSS2.
- 1,987 / 80: S-GLTF-LIB.
- 1,664 / 248: S-GLTF-EXP.
- 1,459 / 6,518: S-ENGINE-PROP.
- 810 / 198: S-FORK.
- 669 / 18: S-BOXMOD.
- S-PAINT3D: not returned by search; its issues page shows 1,754 issues in total.

### E5. Big threads and complaints

UI and learning curve (S-DEVTALK, forum JSON, 2026-10-15):

- 4,020 posts, 211,239 views, 10,568 likes: "[S-OSS] UI paper cuts", 2018-10-31 to 2020-07-01. https://devtalk.blender.org/t/blender-ui-paper-cuts/2596
- 1,409 posts, 127,332 views: "[S-OSS] user interface design", 2018-2022. https://devtalk.blender.org/t/505
- 314 posts, 14,484 views, 603 likes: "An Open Letter to the [S-OSS] Foundation", 2020-08. https://devtalk.blender.org/t/an-open-letter-to-the-blender-foundation/14801
  - One commenter says that for many designers and photographers who want to add 3D, the suite "is rather complicated and has a steep learning curve".
- 77 posts: "'Lock Camera To View'... It was torture to find it!" https://devtalk.blender.org/t/5473
- 123 posts, 86,367 views: "[S-OSS] and Tablets", 2025-07. https://devtalk.blender.org/t/41558

Apple Silicon and Metal:

- 440 posts, 90,507 views, 675 likes: "[R-PT] Apple Metal device feedback", 2021-12 to 2024-02. https://devtalk.blender.org/t/cycles-apple-metal-device-feedback/21868
  - Users report M1 GPU renders slower than CPU in some cases, version 3.3 slower than 3.1, and Apple's first Metal pass focusing on correctness over speed.
- 9,990 posts, 988,514 views, 12,065 likes: S-FORUM "Mac: M3 - Hardware accelerated RT (Part 1)", 2020-11 to 2023-06. One of the largest threads on that forum. https://blenderartists.org/t/1264658
- 2-3x slower: R-PT GPU in the 4.2 alpha on an AMD Mac (regression). https://projects.blender.org/blender/blender/issues/120006. AMD/Intel GPU support was later removed from the Metal backend.

USD/USDZ pipeline (Apple developer forums):

- S-OSS USDZ exports not compatible with Reality Converter / Reality Composer Pro; MaterialX unsupported. https://developer.apple.com/forums/thread/734220
- "Multiple root level objects" error, fixed by setting the default prim. The fix became the default in S-OSS 4.1. https://developer.apple.com/forums/thread/743515
- Textures missing on import. https://developer.apple.com/forums/thread/745874
- Only one animation shows; joints are not read. (No URL in the notes.)

S-NEWS (search API, 2026-10-15):

- 1,053 points, 361 comments: S-OSS 5.0 release (2025-11-18). https://news.ycombinator.com/item?id=45972519
- 848 points, 249 comments: S-OSS 3.0.
- 826 points, 280 comments: Apple joins the S-OSS development fund (2021-10). https://news.ycombinator.com/item?id=28865011
- 680 points, 228 comments: S-OSS 4.0 release notes. https://news.ycombinator.com/item?id=38262315
- 455 points, 124 comments: a mapping service's 3D models as glTF. https://news.ycombinator.com/item?id=35896176
- 171 points, 47 comments: "Ask: recommend me a course" for S-OSS. https://news.ycombinator.com/item?id=33273022
- 78 points, 41 comments: USDZ File Format Spec (2018). https://news.ycombinator.com/item?id=17229971
- 60 points, 10 comments: a browser 3D design tool launch (2020-12). https://news.ycombinator.com/item?id=25288266
- 3 points, 6 comments: "Why Are Most 3D Design Tools So Difficult for Beginners?" (2024-05). https://news.ycombinator.com/item?id=40436447
  - Replies: the suite "relied on shortcuts a lot"; suggestions of a browser 3D design tool and of a kids' CAD tool.
- "How did you overcome the steep learning curve of 3D design tools?" https://news.ycombinator.com/item?id=40449359
- Two "Show" posts (2025-11 and 2025-09): an AI tutor that points to the right buttons in S-OSS, and a tutor that answers with visual cues. People build learning aids just to help others find the suite's buttons. https://news.ycombinator.com/item?id=45945890
- Comment-search counts are fuzzy and unreliable (for example "USDZ" returns 71k), so they are not used.

S-SOCIAL, "[P-MOTION3D] or [S-OSS]" thread (2025-03-12, via a mirror):

- "doing mograph type stuff in [S-OSS] takes many more clicks and steps than it does in [P-MOTION3D]".
- Studios stay on the commercial tool for file sharing.
- Cost (about $800/yr) pushes people to S-OSS.
- Thread and comment counts were not obtained. No counts were found for motion-design or 3D-modeling subforums.

### E6. S-WEBLIB requests

Top-reacted issues of all time (thumbs-up). https://github.com/mrdoob/three.js/issues?q=is%3Aissue+sort%3Areactions-%2B1-desc

- 339 examples/js to modules
- 109 Selective lighting
- 88 Material onBeforeCompile
- 84 WebGL2Renderer
- 74 IFC importer
- 74 Loaders #5524 (open)
- 73 Add support for USD and USDZ formats #14219. https://github.com/mrdoob/three.js/issues/14219
- 72 BatchedMesh
- 71 transform origin / "pivot point" #15965. https://github.com/mrdoob/three.js/issues/15965

Only 6 open issues carry the Editor label. https://github.com/mrdoob/three.js/issues?q=is%3Aissue+is%3Aopen+label%3AEditor

- 19 comments, 9 hearts: "Editor should have most of THREE's features" #16234. https://github.com/mrdoob/three.js/issues/16234
- "Editor Local Mode: File-open/save and Folder-browser-tab" #24766. https://github.com/mrdoob/three.js/issues/24766
- "Allow adding URLs instead of files for textures" #32306.
- CubeTexture support #13880.
- Freezes after every change #15853.
- One browser overflows when publishing 1.5M+ polygons #9187.
- 5 thumbs-up (closed): "Editor as a stand-alone project?" #10610. https://github.com/mrdoob/three.js/issues/10610
- The editor gets few requests. The library's users ask for formats (USD/USDZ, IFC, loaders) and for pivot points.

### E7. S-ENGINE-PROP

- 895 open proposals under topic:3d. https://github.com/godotengine/godot-proposals/issues?q=is%3Aissue+is%3Aopen+label%3Atopic%3A3d+sort%3Areactions-%2B1-desc
  - 167 Terrain #6121
  - 117 Custom Camera3D projection #2713
  - 69 Built-in terrain #445
  - 57 Viewport G-buffer #798
  - 51 Mesh streaming
  - 44 Changes to S-OSS to improve engine export support #2422
  - 40 Virtualized geometry
  - 36 Import USD scenes #7744. https://github.com/godotengine/godot-proposals/issues/7744
  - 33 Line3D node
  - 30 Motion blur
  - 22 Import a model as a mesh resource #7494
  - 9 Outlines instead of boxes for selection #2795
- 2,388 open proposals under topic:editor. 208 thumbs-up for Global plugins #831. 70 for "Improve Run bar".

### E8. S-GLTF-EXP issues

- 226 open issues: 98 labelled enhancement, 28 labelled bug. The repo has 28 labels; open counts for the others were not collected.

Top open issues by reactions:

- EXT_meshopt_compression import #1460
- KTX/KTX2 #1896
- KHR_texture_basisu import #1920
- Export with built-in environment map #335 (9 thumbs-up, 7 comments)
- Export Vertex Groups #1232 (32 comments). https://github.com/KhronosGroup/glTF-Blender-IO/issues/1232
- Segmented ("bendy") bones #708
- Export T-2D strokes #925. https://github.com/KhronosGroup/glTF-Blender-IO/issues/925
- KHR_node_visibility #2597
- KHR_texture_procedurals / MaterialX #2582
- Batch export of selected objects as separate GLBs #1900

Most-commented issues of all time:

- 42 occlusionTexture #123
- 41 glTF-Embedded feedback #2148
- 37 Multiple Animations Not Working #219
- 36 Export image used in extension #845
- 35 Vertex colors as non-color #542
- 33 Exporter performance #203
- 26 Alternate materials export #231

Pain points: animation export, material fidelity (the suite's main PBR shader inputs, MaterialX), compressed textures (KTX2/Basis, meshopt), batch export and performance.

### E9. Smaller tools (tiny reaction counts, so weak signals)

- S-MESHTOOL (1,117 issues in total):
  - glTF2 format support #441 (open). https://github.com/cnr-isti-vclab/meshlab/issues/441
  - "[Usability] Make it possible to Undo" #376 (open). https://github.com/cnr-isti-vclab/meshlab/issues/376
  - 3MF import/export #1032 (closed).
  - Draco #720 (open).
- S-SKETCHMOD (137 issues in total). https://github.com/huxingyi/dust3d/issues
  - 12 thumbs-up: UI scaling #40.
  - fbx/gltf2 import #55.
  - Use on a laptop / touchpad #4 and #83.
- S-MATNODES (528 issues in total): mute/disable nodes #687; FPS limit for battery #249; "Add simple export option" #769.
- S-PAINT3D (1,754 issues in total): edge wear; match S-OSS nodes; preset library; paint normal/height; camera rotate around cursor #251.
- S-BOXMOD (161 issues in total): mostly macOS/Linux build and hotkey problems; "macOS app has incorrect versions" #479.
- S-FORK (5,385 issues in total): mostly the maintainer's own UI and icon tasks; "Default Library - Add Smart Primitives" #5008.

### E10. Designer-side tool requests

S-WEB3D:

- Public feature board: not found. Its feedback subdomains serve the marketing site, and feedback goes to a chat server.
- 18 gallery collections: Interactive Website; Gamified Experiences; Brand and Marketing; Product Design; Interactive Design; Industrial; Learning; Immersive; Mobile Apps; 3D Mockups; 3D Logos; Character Animation; 3D Icons; Materials; Particles; Shape Blend; 3D Data Viz; 3D Keyboards.
- 190 help-center articles. By section:
  - 50 interaction states/events/actions
  - 26 materials/shading (a layer-based material stack: color, image, noise, toon, glass, normal, cavity...)
  - 22 exporting (web embed, code export, native iOS embed, SwiftUI code API, Android, video, USDZ)
  - 21 designing in 3D (extrude 2D to 3D, 3D paths, sculpting, timeline animation, particles, library, version history)
  - 12 integrations (site builders, e-commerce)
  - 12 a second canvas product for interactivity
  - 9 basics
  - 7 collaboration
  - 7 codegen tools
  - 6 lighting
  - 5 cameras
  - 4 importing
  - 3 AI generate
  - 3 account
  - 2 AI
  - So the help effort goes to interactivity/states, materials, and export/embed, not to modeling.
- FAQ imports: OBJ, FBX (with animation and rigs), STL, glTF, GLB, PNG/JPG, partial SVG, MP4, MP3/WAV, Gaussian splats.
- FAQ exports: glTF, GLB, STL, USDZ, PNG/JPG, WebM/MP4/image sequence, web/code/native embeds.
- 423 upvotes, 72 comments: a product launch site's page for the alpha launch of a 3D vector design tool (2021-03-17). The notes call it a different tool from S-WEB3D.

S-CAD-MAC forum, top topics by likes (all-time):

- 776 likes, 14.7k views: "Materials are here!"
- 353: Thread tool
- 188: History-based parametric
- 159: UI refresh
- 66 likes, 6.9k views: Animation
- 62 likes, 8.5k views: SVG/PDF import as sketch vectors
- 59 likes, 7.6k views: "Feature Request: Import .svg Files". https://discourse.shapr3d.com/t/9546
- 50: Array feature
- Signal: designers want materials, SVG import and simple animation.
- Other browser 3D tools: no public vote board found.

### E11. S-MARKET and format notes

- S-MARKET converts every downloadable model to glTF and USDZ when it can. It offers GLB in up to three texture sizes (original, 4K, 1K). https://help.sketchfab.com/en/articles/16152669-gltf-glb-and-usdz
  - USDZ limits there: no vertex colors, no morph animations, one animation track only, first UV channel only, no double-sided rendering.
  - Apple guidance quoted there: textures ≤2048 px, ≤100k polygons, animations ≤10 s.
- "Nearly 1 million" downloadable models available as USDZ (a post about a commercial 3D collaboration platform). https://sketchfab.com/blogs/community/sketchfab-3d-models-ready-to-use-in-nvidia-omniverse/
- 400,000+ USDZ at launch (2018). https://sketchfab.com/blogs/community/sketchfab-adds-usdz-3d-file-conversion
- 5M models, 1M free CC downloads, 10M members (undated post). https://sketchfab.com/blogs/community/sketchfab-celebrates-10-million-members
- 500k free models (Dec 2020, a news site for S-OSS). https://www.blendernation.com/2020/12/10/over-half-a-million-free-creative-commons-3d-models-on-sketchfab/
- Per-format counts of original uploads (OBJ/FBX/STL): not found. The public API returns cursors, not totals.
- Apple AR Quick Look takes USDZ in Safari, Messages, Mail, News and Notes on iPhone, iPad and Vision Pro. Reality Converter turns OBJ/glTF/USD into USDZ. The HTML `<model>` element is available in Safari on visionOS 26. https://developer.apple.com/augmented-reality/quick-look/
- Format demand across the trackers above:
  - glTF: S-MESHTOOL #441, S-SKETCHMOD #55, KTX2/meshopt in S-GLTF-EXP.
  - USD/USDZ: 73 thumbs-up S-WEBLIB #14219; 36 S-ENGINE-PROP #7744; 47 open S-TRACKER issues with the USD interest label.
  - Drag-and-drop import: 210 + 136 S-IDEAS votes.
  - SVG import: designer tools (E10).

## F. Platform facts (Apple)

Verified 2026-10-15 against developer.apple.com (docs MCP mirror and the DocC JSON that holds availability). The docs already list OS 27 symbols (macOS 27.0, tvOS 27.1), so macOS 27 is the current release line. Items marked 27.0+ are not on macOS 26.

### F1. RealityKit on macOS

| macOS | API | URL |
|---|---|---|
| 15.0+ | RealityView | https://developer.apple.com/documentation/realitykit/realityview |
| 15.0+ | RealityViewCameraContent ("On macOS ... always displays its content in a non-AR mode") | https://developer.apple.com/documentation/realitykit/realityviewcameracontent |
| 10.15+ | ModelComponent | https://developer.apple.com/documentation/realitykit/modelcomponent |
| 10.15+ | MeshResource | https://developer.apple.com/documentation/realitykit/meshresource |
| 12.0+ | MeshDescriptor | https://developer.apple.com/documentation/realitykit/meshdescriptor |
| 15.0+ | LowLevelMesh (own vertex format, CPU or Metal compute updates; MeshResource keeps a reference and picks up changes) | https://developer.apple.com/documentation/realitykit/lowlevelmesh |
| 15.0+ | LowLevelTexture | https://developer.apple.com/documentation/realitykit/lowleveltexture |
| 12.0+ | PhysicallyBasedMaterial (baseColor, roughness, metallic, normal, AO, specular, clearcoat, sheen, anisotropy, emissive, subsurface, blending/opacity; "includes all material properties supported by USDZ") | https://developer.apple.com/documentation/realitykit/physicallybasedmaterial |
| 10.15+ | DirectionalLightComponent (+ .Shadow) | https://developer.apple.com/documentation/realitykit/directionallightcomponent |
| 10.15+ | PointLightComponent | https://developer.apple.com/documentation/realitykit/pointlightcomponent |
| 10.15+ | SpotLightComponent (+ .Shadow, ProjectiveTexture) | https://developer.apple.com/documentation/realitykit/spotlightcomponent |
| 15.0+ | ImageBasedLightComponent | https://developer.apple.com/documentation/realitykit/imagebasedlightcomponent |
| 10.15+ | PerspectiveCameraComponent (near, far, fieldOfViewInDegrees) | https://developer.apple.com/documentation/realitykit/perspectivecameracomponent |
| 15.0+ | OrthographicCameraComponent (near, far, scale, scaleDirection). Orthographic exists. | https://developer.apple.com/documentation/realitykit/orthographiccameracomponent |
| 15.0+ | Entity(contentsOf:withName:): loads .usd/.usda/.usdc/.usdz/.reality only | https://developer.apple.com/documentation/realitykit/entity/init(contentsof:withname:) |
| 27.0+ | Entity(from:named:contentType:): load from Data | https://developer.apple.com/documentation/realitykit/entity/init(from:named:contenttype:) |
| 15.0+ | Entity.write(to:): writes a .reality file (not USD) | https://developer.apple.com/documentation/realitykit/entity/write(to:) |
| 27.0+ | Entity.write(to:options:) | https://developer.apple.com/documentation/realitykit/entity/write(to:options:) |
| 26.0+ | Entity.WriteOptions (preferFastExport, preferSmallTextureFiles; for .reality) | https://developer.apple.com/documentation/realitykit/entity/writeoptions |
| 15.0+ | RealityRenderer ("displays a RealityKit scene in an existing Metal workflow") | https://developer.apple.com/documentation/realitykit/realityrenderer |
| 15.0+ | RealityRenderer.updateAndRender(deltaTime:cameraOutput:...) | https://developer.apple.com/documentation/realitykit/realityrenderer/updateandrender(deltatime:cameraoutput:whenscheduled:oncomplete:actionsbeforerender:actionsafterrender:) |
| 15.0+ | RealityRenderer.CameraOutput (`colorTextures: [any MTLTexture]`, Descriptor.singleProjection(colorTexture:)) | https://developer.apple.com/documentation/realitykit/realityrenderer/cameraoutput |
| 10.15+ | AnimationResource | https://developer.apple.com/documentation/realitykit/animationresource |
| 12.0+ | FromToByAnimation | https://developer.apple.com/documentation/realitykit/fromtobyanimation |
| 12.0+ | SampledAnimation (frames of Float/SIMD/quat/Transform/joint transforms at constant frameInterval) | https://developer.apple.com/documentation/realitykit/sampledanimation |
| 15.0+ | BlendShapeWeightsComponent | https://developer.apple.com/documentation/realitykit/blendshapeweightscomponent |
| 26.0+ | MeshInstancesComponent (GPU instancing), new 2025 | https://developer.apple.com/documentation/realitykit/meshinstancescomponent |
| 26.0+ | PostProcessEffect / RealityViewRenderingEffects.customPostProcessing, new 2025 | https://developer.apple.com/documentation/realitykit/postprocesseffect , https://developer.apple.com/documentation/realitykit/realityviewrenderingeffects/custompostprocessing |

- No USD/USDZ export in RealityKit on macOS 26 was found. `write(to:)` produces `.reality`.
- No keyframe-curve (bezier tangent) animation type was found. SampledAnimation is constant-interval samples. FromToByAnimation is a two-value tween. An app keyframe model would bake to SampledAnimation or drive transforms per frame. (Inference, not an Apple statement.)
- WWDC25 "What's new in RealityKit" (https://developer.apple.com/videos/play/wwdc2025/287/): tvOS support; ManipulationComponent; AnchorStateEvents/ARKitAnchorComponent; scene understanding flags (visionOS); EnvironmentBlendingComponent; MeshInstancesComponent with LowLevelInstanceData ("On iOS, iPadOS, macOS, and tvOS you can use a LowLevelBuffer to pass render data to your CustomMaterial"); ImagePresentationComponent; VideoPlayerComponent immersive formats; ViewAttachmentComponent, PresentationComponent, GestureComponent; Entity attach-to-pin; AVIF textures; HoverEffect GroupID; customPostProcessing on iOS/iPadOS/macOS/tvOS.
- Entity init from in-memory Data: `init(from:named:)` is macOS 26.0+, deprecated in macOS 27.2 in favor of `init(from:named:contentType:)` (27.0+). https://developer.apple.com/documentation/realitykit/entity/init(from:named:)

### F2. SceneKit status

- Deprecated in macOS 26.0 (all platforms 26.0). Summary: "SceneKit is deprecated, use RealityKit instead. For more information, see WWDC25 session 288." https://developer.apple.com/documentation/scenekit
- SCNView and SceneView pages carry "Deprecated". https://developer.apple.com/documentation/scenekit/scnview , https://developer.apple.com/documentation/scenekit/sceneview
- WWDC25 session 288 "Bring your SceneKit project to RealityKit" (https://developer.apple.com/videos/play/wwdc2025/288/): "Apple is officially deprecating SceneKit across all platforms ... This is a soft deprecation ... existing applications ... will continue to work. However, if you're planning a new app ... SceneKit is not recommended ... SceneKit is now entering maintenance mode. Apple will only fix critical bugs ... no plan to hard deprecate".
- Xcode 26 converter: `xcrun scntool --convert x.scn --format usdz --append-animation`.

### F3. Model I/O

- MDLAsset (macOS 10.11+): timed data (frameInterval/startTime/endTime), `animations`, `upAxis`, `loadTextures()`. https://developer.apple.com/documentation/modelio/mdlasset
- canImportFileExtension lists `.abc` (Alembic), `.usd/.usda/.usdc`, `.usdz`, `.ply`, `.obj`, `.stl`; "Additional formats may be supported as well." https://developer.apple.com/documentation/modelio/mdlasset/canimportfileextension(_:)
- canExportFileExtension names only `.obj` and `.stl`; "Additional formats may be supported as well." https://developer.apple.com/documentation/modelio/mdlasset/canexportfileextension(_:)
  - USD export via Model I/O is commonly reported to work: *unverified* in the docs.
- export(to:) infers the format from the path extension. https://developer.apple.com/documentation/modelio/mdlasset/export(to:)
- Asset File Types UTIs: Alembic, OBJ, PLY, STL, USD. https://developer.apple.com/documentation/modelio/asset-file-types
- MDLMesh: https://developer.apple.com/documentation/modelio/mdlmesh
- MDLMaterial: https://developer.apple.com/documentation/modelio/mdlmaterial
- MDLPhysicallyPlausibleScatteringFunction (PBR BRDF params 0..1): https://developer.apple.com/documentation/modelio/mdlphysicallyplausiblescatteringfunction
- glTF: an Apple docs search for "glTF" returned no framework API. No native glTF import/export was found in the Model I/O, RealityKit or USDKit topic lists. Absence of evidence; treat as none.

### F4. Metal

- MTKView (macOS 10.11+; timed, setNeedsDisplay and explicit draw modes). https://developer.apple.com/documentation/metalkit/mtkview
- Metal 4, macOS 26.0+:
  - MTL4CommandQueue. https://developer.apple.com/documentation/metal/mtl4commandqueue
  - MTL4Compiler. https://developer.apple.com/documentation/metal/mtl4compiler
  - MTLGPUFamily.metal4. https://developer.apple.com/documentation/metal/mtlgpufamily/metal4
  - Overview: MTL4 types are independent of MTL types; runtime detection; incremental adoption; interop via MTLEvent/MTLSharedEvent. https://developer.apple.com/documentation/metal/understanding-the-metal-4-core-api
- Ray tracing:
  - MTLAccelerationStructure, macOS 11.0+ (triangle, bounding-box, primitive and instance descriptors). https://developer.apple.com/documentation/metal/mtlaccelerationstructure
  - MTL4AccelerationStructureGeometryDescriptor, macOS 26.0+ (also curve, motion triangle and motion curve descriptors). https://developer.apple.com/documentation/metal/mtl4accelerationstructuregeometrydescriptor
- MetalFX, macOS 13.0+ (temporal and spatial upscaling). https://developer.apple.com/documentation/metalfx
  - MTLFXTemporalScaler, macOS 13.0+. https://developer.apple.com/documentation/metalfx/mtlfxtemporalscaler
  - MTLFXTemporalDenoisedScaler, macOS 26.0+ (denoise plus upscale; relevant to a real-time path-traced preview). https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscaler
  - MTLFXFrameInterpolator, macOS 26.0+. https://developer.apple.com/documentation/metalfx/mtlfxframeinterpolator

### F5. AVFoundation video out

- AVAssetWriter, macOS 10.7+ (QuickTime / MPEG-4, single use per file). https://developer.apple.com/documentation/avfoundation/avassetwriter
- AVAssetWriterInputPixelBufferAdaptor: deprecated in macOS 27.0, "Use AVAssetWriter.inputPixelBufferReceiver(for:pixelBufferAttributes:) instead". https://developer.apple.com/documentation/avfoundation/avassetwriterinputpixelbufferadaptor
- inputPixelBufferReceiver(for:pixelBufferAttributes:), macOS 26.0+. https://developer.apple.com/documentation/avfoundation/avassetwriter/inputpixelbufferreceiver(for:pixelbufferattributes:)
- Codecs:
  - .h264 (10.13+). https://developer.apple.com/documentation/avfoundation/avvideocodectype/h264
  - .hevc (10.13+). https://developer.apple.com/documentation/avfoundation/avvideocodectype/hevc
  - .hevcWithAlpha (10.15+). https://developer.apple.com/documentation/avfoundation/avvideocodectype/hevcwithalpha
  - .proRes4444 (10.13+). https://developer.apple.com/documentation/avfoundation/avvideocodectype/prores4444
- Sample "Using HEVC video with alpha" (write and export HEVC with alpha). https://developer.apple.com/documentation/avfoundation/using-hevc-video-with-alpha
- ProRes 4444 carrying alpha: *unverified* on Apple's page (the abstract only says "Apple ProRes 4444").

### F6. USD from Swift

- USD overview: "Where possible, use USDKit ... USDKit is Apple's system API for working with USD, available in version 27 of Apple operating systems and later." Built on OpenUSD (S-OPENUSD). https://developer.apple.com/documentation/usd
- USDKit framework, macOS 27.0+. https://developer.apple.com/documentation/usdkit
  - USDStage, USDPrim, USDLayer, USDValue, USDToken, USDTransformOperation.
  - USDStage.exportPackage(to:options:) writes USDZ; exportFlattened(to:).
  - USDLayer.export(to:), importContents(from:) (USDA string).
  - USDStageComponent (renders a stage as RealityKit entities, 27.0+); USDPlayer (timeline playback).
  - https://developer.apple.com/documentation/usdkit/usdstage , https://developer.apple.com/documentation/usdkit/usdlayer , https://developer.apple.com/documentation/usdkit/usdstagecomponent
- On macOS 26 no Apple Swift USD authoring API was found. Options there: Model I/O export (USD export *unverified* in the docs), writing USDA text yourself, or bundling OpenUSD (C++).
- An Apple-published "OpenUSD Swift package": *unverified* / not found.

## G. What could not be found

- S-MOTION-EDU: the recent % of motion designers who use 3D at all.
- S-MOTION-EDU 2017 3D numbers (charts are images) and any 3D % in the 2025 page.
- S-MATSURVEY 2025 industry % (primary page returned 403).
- S-OSS manual page-view stats (not public).
- Tutorial sites' course counts by topic (not attempted in depth).
- A credible survey % of graphic/UI designers who use 3D.
- Format adoption % from the glTF standards body, a commercial game engine vendor or the wider industry.
- S-MARKET per-format counts of original uploads (the API returns cursors, not totals).
- S-ASSETS downloads per format.
- S-TRACKER count for the Sculpt, Paint & Texture module (the label comma breaks the filter).
- S-GLTF-EXP open counts for labels other than enhancement and bug.
- S-WEB3D public feature board, and vote boards for other browser 3D tools.
- S-SOCIAL thread and comment counts; motion-design and 3D-modeling subforum counts.
- RealityKit USD/USDZ export on macOS 26; native glTF in any Apple framework; a keyframe-curve animation type in RealityKit.

## H. Caveats

- S-OSS-SURVEY-2025 and -2024 are self-selected and need an account with the suite. They describe that suite's users only, not 3D users in general.
- Survey questions are multi-select, so shares add up to more than 100%. Percentages are of people who answered each question.
- S-OSS-SURVEY-2024 had no per-task question, so 2024 and 2025 task shares can't be compared.
- S-MATSURVEY skews toward S-OSS users (a tutorial channel's audience), and its figures come from press coverage and search snippets, not the primary page.
- S-ARCHVIZ-RENDER and the S-MATSURVEY 2024 "best tool" votes come from search snippets.
- S-HERITAGE is a niche sample of mostly cultural-heritage researchers.
- S-QA title-format counts are word matches on titles, so rough. S-IDEAS keyword hits are fuzzy full-text matches, so rough.
- The S-OSS-SURVEY-2024 add-ons field is dominated by add-ons that ship enabled, so it is a weak signal.
- S-IDEAS is retired; its counts are frozen and old ideas carry more votes.
- Code host star and open-issue counts include PRs. Reaction counts on the smaller tools are tiny.
- S-NEWS comment-search counts were unreliable and are not used. S-SOCIAL was read through a mirror.
- The S-OSS-SURVEY-2025 motion-graphics share (25.5%) is the best motion-design 3D signal found, but it covers that suite's users only.
- Apple items marked 27.0+ are not on macOS 26. "Not found" in F means absence of evidence in the docs, not a confirmed absence.
