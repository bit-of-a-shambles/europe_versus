# Common Values — design influences

**Status:** Canonical
**Version:** 1.0
**Last updated:** 13 September 2026
**Companion to:** [BRAND_GUIDELINES.md](BRAND_GUIDELINES.md)

This pass refined the website's interface by studying seven design-inpiration
galleries and translating their strongest ideas into the Common Values visual
system. Nothing was imported wholesale: every adoption below had to survive the
brand's own rules (vellum and carbon ink, Besley and Public Sans, one
passport-burgundy accent, no gradients, glows, shadows, rounded-card grids or
all-caps labels — see `BRAND_GUIDELINES.md` §4 and §5).

The galleries mostly showcase product and landing-page work. The value in them,
for an editorial data publication, is structural: how they organise navigation,
sections, closing statements and feedback. That is what was taken.

## What each gallery contributed

### transitions.dev — effects

A library of copy-and-paste UI transitions. Adopted, softened to editorial
restraint:

- **Texts reveal** (two lines rising with offset stagger) → the homepage lead
  gets one orchestrated entrance: kicker, chart, then the headline block rise
  9px with 60ms stagger offsets, 500ms ease-out, once per load. No bounce, no
  springs, no blur.
- **Menu dropdown** (origin-aware open/close) → the mobile menu opens with a
  180ms fade-and-drop from its masthead origin, and the toggle morphs into a
  close affordance while `aria-expanded` tracks state.
- **Icon swap** (simplified) → CTA arrows ("Read the evidence", "Subscribe on
  Substack", "Get the weekly chart") take one 3px forward step on hover via
  `.link-arrow`.
- **Card resize** (simplified) → hover colour changes across navigation, index
  rows and footer links ease over 150ms instead of snapping.

Rejected: number pop-ins, confetti, gooey physics, shimmer and skeleton
effects — they signal interface, not evidence.

**Where:** `app/assets/stylesheets/application.css` ("Motion vocabulary"
block), `app/javascript/controllers/mobile_menu_controller.js`.

### navbar.gallery — navigation ideas

A curated navbar collection. Adopted:

- **Sticky topic navigation** → the section nav (Latest / Archive / Data
  library / Method) is now sticky below the masthead, on solid vellum with a
  hairline rule, so wayfinding survives the long edition pages.
- **Active state** → the current section link carries `aria-current="page"`
  and renders in burgundy at weight 600.
- **Progress bar** (their navbar category) → canonical editions carry a 2px
  burgundy reading-progress rule fixed to the top of the viewport. It is
  scroll-linked feedback for a 2,000-word edition, not decoration, and never
  appears on index pages.
- **Announcement strip** → the masthead note ("One chart a week on Europe's
  progress") already plays this role and was kept as-is.

**Where:** `app/views/layouts/application.html.erb`,
`app/javascript/controllers/reading_progress_controller.js`.

### a1.gallery — structure ideas

A hand-picked website gallery whose strongest entries are editorial and
typographic. Adopted:

- **One dominant claim per page** → the homepage hero keeps a single Besley
  headline at display scale beside the chart; nothing competes with it.
- **Collection grids** → "Earlier charts" stays a two-column numbered index
  (an a1-style collection list) with a full-width header rule.
- **Big-type closing band** → the subscribe block is now the page's closing
  statement on a full-bleed vellum-wash band.

**Where:** `app/views/home/index.html.erb`.

### sectionmaster.com — section structure

A section gallery organised by a fixed taxonomy (hero, features, blog-list,
CTA, footer…). Adopted:

- **Section-first composition** → the homepage arc is now explicit and each
  section has one job: hero (latest edition) → evidence strip → blog-list
  (earlier charts) → CTA (subscribe band) → footer (colophon).
- **CTA as a section** → the subscribe band gets full-section padding and the
  publication's only background wash.

**Where:** `app/views/home/index.html.erb`, `application.css`
(".headline-subscribe").

### supahero.io — hero patterns

A hero-section library. The lesson across its best entries: one confident
claim, generous whitespace, no chrome. Adopted:

- The hero's entrance choreography (see transitions.dev) focuses attention on
  the claim; the chart arrives 70ms later as the co-star.
- Kicker, headline, deck and byline rhythm was audited rather than restyled —
  the existing Besley 500 clamp(40–61px) headline already follows this
  discipline and stays.

**Where:** homepage lead block, unchanged markup, new entrance motion.

### footer.design — footer patterns

A footer gallery whose editor's choices favour oversized wordmarks, grouped
links and colophons. Adopted:

- **Big wordmark** → "Common Values" closes the page at up to 104px Besley —
  the publication signing its work.
- **Tagline beside link groups** → the editorial promise sits left of three
  small groups: Read, Method and data, Project.
- **Colophon** → a bottom rule with copyright, cadence ("One chart every
  Friday") and the data-provenance line.

**Where:** `app/views/layouts/application.html.erb`, `application.css`
(".site-footer" system).

### unsection.com — section-first inspiration and hover effects

A section gallery with a dedicated hover-effects collection. Adopted:

- **Hover as feedback** → titles shift to burgundy with a 150ms ease on
  navigation, archive rows, data-library rows and footer links; arrows step
  forward. Hover confirms intent; it never reveals essential information
  (per §8 of the brand guidelines).
- **Section discipline** → confirmed the one-job-per-section composition and
  the closing band treatment.

**Where:** `application.css` (hover transitions, `.link-arrow`).

## Guardrails that governed the pass

- Motion explains or confirms; it never decorates. All entrances sit behind
  `prefers-reduced-motion: no-preference` and the global reduce override
  already in the stylesheet.
- No gradients, glows, glass, shadows, pills (beyond the subscribe action) or
  card grids were introduced.
- The burgundy accent still marks exactly one editorial subject per argument;
  hover states are its interaction role, per §5.
- The chart system was not touched — it is fully specified in §9 and already
  audited.

## Verification

- Phone captures at 390×844 and desktop at 1440px for home, edition, archive
  and data-library pages.
- Full minitest suite plus rubocop, brakeman and importmap audit (CI parity).
- Reduced-motion check: entrances and menu animation disabled under
  `prefers-reduced-motion: reduce`.