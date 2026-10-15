# Licensing and editions

How AfterGlow is licensed and paid for: the open-core model the captain
decided on 2026-10-15. This page says what is free, what each paid module
adds and why, what the GPL covers, how the official build is put together,
and what contributors sign. The seams the code needs for it are designed in
`docs/blueprints/suite/editions.md`.

This page describes the plan in plain words. It is not legal advice, and the
legal texts (the license, the CLA, any module terms) are what bind. Anything
marked **legal review** must be checked by a lawyer before it is relied on.

## The short version

- **The core is free and open source, forever.** Every app (Flare, Design,
  Photo, Library, Halo) and the AfterGlow shell, with every manual tool in
  every app, is GPL-3.0. You never need an account to use it.
- **Three paid modules sit next to the core**, closed source, shipped only in
  the official build: **Team**, **AI** and **Enterprise**.
- **No module takes a tool away from the core.** A paid module adds a service
  (a server, a model, an admin console); it never locks a manual tool that the
  core already has.
- **One owner holds the copyright of the core**, which is what makes the
  combination legal. So every outside contributor signs a CLA (below).

## The editions

| Edition | Who it is for | What it is | Price |
|---|---|---|---|
| Core | Everyone | The five apps and the AfterGlow shell, every manual tool, local files, local co-editing between Macs on the same network (see Team). GPL-3.0, built from this repo and creative-core. | Free. No account. |
| Core + Team | People who work with others | Core plus the Team module | A small subscription, openly described as "this funds the suite" |
| Core + AI | People with a Paw OS subscription | Core plus the AI module | Included with Paw OS |
| Core + Enterprise | Large companies | Core plus the Enterprise module (usually with Team, often with AI) | A contract per company |

Modules combine: one install can carry Team and AI, or all three.

### Core (free, GPL-3.0)

Everything you need to do the work by hand, in every app:

- Open, create, edit, undo and save documents in all five apps, with every
  tool the palettes show.
- The AfterGlow home, recents, switching, hand-offs between apps, the shared
  asset library, settings, onboarding and the updater.
- Import and export in every format the apps support.
- **Local co-editing:** two or more Macs on the same network may edit one
  document together with no server in between. This may stay free; the
  captain keeps it in the core unless a later decision moves it.

What the core never does: ask you to sign in, phone home for a license,
count seats, or switch a tool off because you didn't pay.

### Team (paid, closed)

What it adds:

- **Hosted sync:** your documents and asset libraries on our servers, the
  same on every Mac you sign in on.
- **Live co-editing over the internet:** several people in one document at
  once, with presence (who is here, where their cursor is).
- **Shared libraries:** colours, vector art, images and animations shared by a
  team, kept in step.
- **Comments:** on a document, a layer, a frame or a region.
- **Version history:** every saved state on the server, browsable and
  restorable.

Why it is paid: it needs servers that cost money to run every month. The
subscription is small and says what it is for: **this funds the suite**.
The people who pay for Team are paying for the free core too, and we say so.

### AI (comes with Paw OS)

What it adds: AI features in every app (for example generating, selecting,
masking, describing or cleaning up), reached through the user's Paw OS
account. A Paw OS subscription unlocks AI in every AfterGlow app; there is
no separate AfterGlow AI price.

Why it is separate: the models and the compute live behind the Paw OS
account, not in the app. Every manual tool stays in the core; AI is an extra
way to do some jobs faster, never the only way to do a job.

### Enterprise (paid, closed)

What it adds:

- **Single sign-on (SSO)** with the company's identity provider.
- **Fleet deployment:** install, configure and update AfterGlow across many
  Macs from a management tool.
- **Admin and policy controls:** which modules and features are on, where
  documents may be stored, which accounts may sign in.
- **Audit logs:** who did what, when, for the company's records.
- **Support:** a support agreement with response times.

Why it is paid: this is how large companies pay for the suite. They need the
controls and the support, and they can afford them. **There is no
revenue-based license:** a company of any size may use the free core under
the GPL, and pays only if it wants Enterprise (or Team, or AI).

## What the GPL covers, and what it doesn't

**Covered by GPL-3.0** (the `LICENSE` file in this repo and in creative-core):

- All source in qbtrix/creative-apps and qbtrix/creative-core: the five
  apps, SuiteUI, the Models, the AfterGlow shell, the engines, the tests and
  the scripts.
- The **edition protocols** (the seams in
  `docs/blueprints/suite/editions.md`) and their free defaults. They live in
  this repo, so anyone can read exactly what a paid module can and cannot
  reach.
- The public build you make from these repos. You may run it, study it,
  change it, and share it, changed or not, under the GPL's terms (above all:
  pass on the source and the same freedoms).

**Not covered by the GPL:**

- **The paid modules** (Team, AI, Enterprise). They are closed source, owned
  by the copyright owner, and shipped under their own terms in the official
  build only.
- **The hosted services** (Team's servers, Paw OS). The GPL is about software
  you receive, not a service you use over the network.
- **The names and marks** "AfterGlow", "Flare", "Design", "Photo", "Library",
  "Halo" and "Paw OS", and the official icons. The GPL licenses code, not
  trademarks. A fork must use its own name and icons. **Legal review:** a
  written trademark policy.
- **Your documents.** Files you make with the apps are yours; the GPL does
  not reach them.

## How the official build combines the core with the closed modules

1. **The core is the same in both builds.** The official build compiles the
   core from the same public commit as the public build, with the same
   project files. Nothing in the core is different, hidden or removed.
2. **Each paid module is a separate, signed bundle** placed inside
   `AfterGlow.app` next to the core (`Contents/PlugIns/`). It conforms to
   the public edition protocols and registers itself when AfterGlow starts.
   The editions blueprint says how.
3. **Without a module, the core runs complete.** Every control that needs a
   missing module is disabled and its tooltip says why (for example "Comments
   need AfterGlow Team."), so no control is ever dead. The core's own tools
   never depend on a module.
4. **Why this is allowed.** The GPL binds people who receive the core under
   it. The copyright owner, who holds the copyright of the whole core, can
   also license the core to itself on other terms, and so may ship it next to
   closed modules that load into the same process. That is only true while
   one owner holds all the copyright, which is why contributors sign the CLA.
   **Legal review:** confirm this for the exact build shape (modules loaded
   in-process from `Contents/PlugIns/`).
5. **What this means for others.** Someone else who builds a closed module
   that loads into the GPL core is not the copyright owner, so the GPL's
   terms apply to that combination. Modules built by others for their own
   copy should be GPL-compatible. **Legal review:** state this precisely in
   the trademark and module terms.

## Contributing: the CLA

Every outside contribution (code, docs, art, tests) to qbtrix/creative-apps
or qbtrix/creative-core needs a signed Contributor License Agreement before
it is merged. The agreement is in `CLA.md`; how to sign is in
`CONTRIBUTING.md`.

Why: the open-core model works only while one owner holds the right to
license all of the core, both as GPL to everyone and on other terms in the
official build. Without a CLA, each contributor would hold the copyright of
their part under the GPL alone, and the official build could no longer ship
it next to the paid modules.

What the CLA does not do: it does not take your copyright away (you keep
it, and may use your contribution however you like), and it does not change
the core's license. Everything you contribute is still released to everyone
under GPL-3.0.

The CLA is a draft based on a standard individual agreement and needs legal
review before it is used (see the top of `CLA.md`).
