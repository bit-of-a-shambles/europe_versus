# Common Values — brand guidelines

**Status:** Canonical  
**Version:** 1.4  
**Last updated:** 13 September 2026 (second pass)  
**Applies to:** the website, weekly editions, Substack, chart exports, social images and editorial partnerships

Common Values is an editorial data publication, not a dashboard and not a campaign. Every edition makes one consequential claim about Europe with one carefully reported chart.

The canonical website theme is `design-review`. The `design-graphic` and `design-atlas` themes are earlier explorations and are not part of the brand.

## 1. Core identity

### Name

**Common Values**

Always write the name in full in editorial copy. The wordmark may stand alone once the context is clear.

The name has two meanings: the numerical values used to measure Europe and the values Europeans claim to hold in common. This is an editorial tension, not a predetermined conclusion. The publication tests both against the evidence.

### Proposition

> One chart a week on Europe’s progress.

### Editorial promise

> Progress when the evidence shows it. Problems when it doesn't.

### Cadence

One chart every Friday. An edition may contain annotations, a short methodology and supporting prose, but it has one primary visual argument.

### Point of view

Common Values is pro-progress and pro-Europe. That is a direction of interest, not permission to distort the evidence.

- Show improvements without turning them into victory laps.
- Show weaknesses without treating decline as inevitable.
- Prefer a progress-oriented interpretation only when the evidence genuinely permits more than one reading.
- Name uncertainty, revisions, missing observations and reasonable competing explanations.
- Compare Europe with the relevant benchmark, not merely the benchmark that makes Europe look best.

## 2. Brand principles

### Evidence leads

The data determines the story. Start with a testable claim, preserve the chain from source to transformation to chart, and make limitations visible.

### One idea at a time

One edition, one finding, one primary chart and one highlighted subject. Remove anything that does not help a reader understand that finding.

### Editorial, not institutional

The publication should feel independent, literate and European. Avoid EU-institutional visual language, corporate product design and advocacy-campaign rhetoric.

### Optimism with friction

Progress is interesting because it is difficult, uneven and reversible. Good stories explain both the gain and what still resists improvement.

### Designed for a phone

The smallest intended screen is the design constraint, not an afterthought. A reader must be able to understand the claim, labels, caveat and source without zooming or hovering.

## 3. Editorial voice

The voice is confident, plain-spoken, curious and empirically honest. It is warmer than a statistical bulletin and more restrained than a campaign.

| Prefer | Avoid |
| --- | --- |
| Specific, active claims | Vague topic labels |
| Short, concrete sentences | Abstract throat-clearing |
| Measured confidence | Breathless certainty |
| Proportion and comparison | Isolated large numbers |
| Named sources and mechanisms | Vague attribution |
| Useful caveats near the claim | Caveats buried in a footnote |
| European context | Institutional jargon |

### Headline

The headline states the main finding in sentence case. It should be defensible from the chart without relying on the article body.

Good patterns:

- “Poland has closed 43% of its productivity gap with Italy”
- “Denmark made the largest low-carbon leap”
- “Europe's fertility decline is not one story”

Avoid:

- Question headlines
- “Why X matters”
- A topic followed by a colon and a generic promise
- Unqualified superlatives
- Clickbait, urgency and excessive punctuation

### Deck

The deck adds the metric, unit, comparison, geography or time period that the headline cannot carry cleanly. It does not repeat the headline.

### Story structure

Most editions should follow this arc:

1. State the finding in two or three sentences.
2. Define exactly what the measure captures.
3. Explain the most plausible mechanism or context.
4. Present the strongest limitation or counter-evidence.
5. Say what the result changes about how we should understand Europe.

The prose after the chart will usually be 300–600 words. Longer editions need a reporting reason, not a desire to appear comprehensive.

### Language to remove

Do not publish stock AI phrasing or synthetic enthusiasm. In particular, cut:

- “In a world where…”
- “It's not just X—it's Y”
- “Unlock”, “reimagine”, “transform” and similar promotional verbs
- Empty claims that something is “crucial”, “pivotal” or “a testament to”
- Rhetorical triplets added for rhythm rather than meaning
- Repeated em dashes, canned transitions and generic concluding summaries

## 4. Visual character

The visual language combines the serious economy of *The Economist* and the *Financial Times*, the clarity of *Our World in Data*, and the editorial confidence of *Works in Progress*. These are reference points, not templates to imitate.

The page should feel like a well-edited weekly review: vellum paper, carbon ink, decisive typography, thin structural rules and one passport-burgundy signal.

### Never use

- Gradient backgrounds, glows, glass effects or neon colour
- Decorative blobs, fake depth or floating interface shapes
- Rounded card grids as the default page structure
- Chart panels inside grey boxes
- Drop shadows used to manufacture hierarchy
- All-caps subheadings or widely tracked labels
- Monospace metadata as a visual gimmick
- Generic technology-logo typography
- Decorative AI imagery, synthetic European skylines or flag montages
- Badges and pills for ordinary categories or metadata

The subscribe control may be a restrained pill because it is an action. That exception does not extend to editorial content.

**Gradient-text exception (v1.5, September 2026, owner-directed).** The
subscribe labels alone may carry the "gradient text" treatment recreated
from transitions.dev's pro-gradient-text effect: a large rainbow colour
field clipped to the glyphs, orbiting in two dimensions over ~10 seconds
(a deepened-stop variant runs on light backgrounds for legibility). This
is the publication's single gradient exception — it applies to the
Subscribe word only, sits behind `prefers-reduced-motion` (reduced motion
freezes a static frame), and never extends to headlines, body copy, charts
or navigation. Implementation: `gradient_text_controller.js` and
`.gradient-text` in `application.css`.

## 5. Colour

| Token | Value | Use |
| --- | --- | --- |
| Vellum | `#F3EFE5` | Page and chart background |
| Carbon | `#1B1D1E` | Primary text, principal rules and neutral chart marks |
| Graphite | `#67635D` | Secondary text, sources and non-primary labels |
| Passport burgundy | `#71394D` | One editorial highlight, links on interaction and focus rings |
| Stone rule | `#CEC5B7` | Quiet separators and restrained gridlines |
| Vellum wash | `#E8E0D3` | Rare background distinction where spacing alone is insufficient |

Ink, muted text and accent all meet WCAG AA for normal text on paper: approximately 14.7:1, 5.2:1 and 7.6:1 respectively.

The palette takes its character from European civic print—burgundy passports, clothbound reference books, vellum paper and carbon lettering—rather than literal flag colours. Passport burgundy is a publication accent, not a positive or negative data code. Do not add EU cobalt or yellow as supporting decoration.

### Colour rules

- Use the accent once per visual argument. It identifies the editorial subject; it does not mean “good”, “bad” or “Europe”.
- Render comparison series in ink, muted grey or tints with sufficient contrast.
- Never require colour alone to distinguish a mark. Add a direct label, shape, line style or position.
- Do not invent extra category colours for decoration. A chart that needs several categories should use a tested accessible palette and explain why.
- Keep charts on paper. White plotting rectangles and grey plot frames create an unnecessary box and are not part of the brand.

## 6. Typography

The type system has two families and clear jobs.

### Instrument Serif — editorial voice

Use Instrument Serif for the wordmark, major headlines, chart headlines and considered long-form emphasis. It replaced Besley in September 2026 (v1.4); Besley is retired from the system.

- The family ships a single weight: 400 roman and 400 italic. Never ask it for 500, 600 or 700 — browsers would synthesise an ugly faux bold. Hierarchy comes from scale, spacing and position alone.
- Use the italic for kickers and literary emphasis.
- Instrument Serif is drawn for large display sizes; keep it out of running body text.

### Public Sans — information voice

Use Public Sans for navigation, decks, body copy, metadata, chart axes, direct labels, values, sources and interface controls.

- Default text weight: 400
- Use 500 for active navigation, small emphasis and important chart labels
- Use 600 sparingly for controls or tabular values

### Type hierarchy

These are starting ranges, not a licence to create many styles.

| Role | Typeface | Desktop | Phone | Line height |
| --- | --- | ---: | ---: | ---: |
| Publication wordmark | Instrument Serif 400 | 25px | 22–24px | 1.0 |
| Edition headline | Instrument Serif 400 | 44–88px | 35–43px | 0.99–1.08 |
| Section heading | Instrument Serif 400 | 28–36px | 26–32px | 1.1–1.2 |
| Deck | Public Sans 400 | 16–19px | 16–18px | 1.45–1.6 |
| Article body | Public Sans 400 | 18–21px | 17–19px | 1.6–1.75 |
| Navigation | Public Sans 500 | 12–13px | 13–15px | 1.3 |
| Source / metadata | Public Sans 400 | 12–14px | 12–14px | 1.4–1.55 |

### Typography rules

- Use sentence case everywhere, including section headings, chart labels and navigation.
- Never simulate hierarchy with all caps or excessive tracking.
- Balance display headlines and prevent orphaned final words where the browser permits it.
- Use a target prose measure of 55–65 characters; never exceed 75 characters.
- Use tabular numerals for aligned values and tables.
- Keep weights mostly at 400 and 500. Hierarchy should come from scale, spacing and position.
- Self-host the approved WOFF2 files from `app/assets/fonts`; do not depend on Google Fonts or another third-party font CDN at render time.
- Load only the weights used in production, use `font-display: swap`, and keep the combined webfont payload under 200 KB where practical. The current Latin and Latin Extended files total approximately 92 KB.
- The fallback stack must remain usable if webfonts fail.

### Production font delivery

- Instrument Serif and Public Sans are the approved production faces. Besley is retired (September 2026); Inter, Lora, Space Mono and browser-default substitutes remain outside the publication identity.
- Ship both Latin and Latin Extended WOFF2 subsets so names and labels retain European diacritics.
- Preload the Latin roman files for Instrument Serif and Public Sans in the document head. Load Instrument Serif italic and the Latin Extended subsets only when the page uses them.
- Serve browser fonts through the Rails asset pipeline with fingerprinted filenames and a one-year immutable cache policy.
- Use `font-display: swap`. The fallback stacks are `Instrument Serif, Georgia, serif` and `Public Sans, Helvetica Neue, Arial, sans-serif`.
- Generated chart and social-image HTML must embed the same font files as data URIs; image exports must never depend on a remote font request.
- Keep `-webkit-text-size-adjust: 100%` on the root element so iOS Safari does not silently inflate selected text and alter editorial line breaks.
- Every production typography change requires a phone capture at 390×844 and a direct-font request check. Before launch, also open the live URL in current iOS Safari on physical hardware.

### Current typography audit

**Score: 9/10.** Typeface intent, hierarchy, sentence casing, contrast, self-hosted loading, fallback stacks and 320px reflow pass. The remaining diagnostic rows are a physical-device check in current iOS Safari and explicit browser testing at 200% zoom; complete both before declaring the implementation fully verified.

## 7. Wordmark

The wordmark is the text **Common Values** set in Instrument Serif 400.

- Use ink on paper or paper on ink.
- Preserve the original proportions and letter spacing.
- Keep clear space around it equal to at least the cap height of the “C”.
- Keep taglines separate from the wordmark, especially on small screens.
- Do not add a symbol, gradient, outline, shadow or flag treatment.
- Do not compress, stretch, arc or rearrange the words.

## 8. Layout

### Page structure

- Maximum shell: 1200px
- Desktop side gutters: at least 24px
- Phone side gutters: 16px
- Long-form prose: 55–65 characters wide
- Use generous blank space between editorial sections.
- Use horizontal rules to separate levels of information. Do not outline entire content regions.
- Place the headline before the chart on phones.
- The chart should occupy the available content width; explanatory prose should remain narrower.

### Rhythm

Spacing should communicate editorial hierarchy: headline to deck is close, deck to chart is deliberate, and chart to source is close. Do not distribute elements evenly as if they were interface cards.

### Responsive behaviour

- Design and review at 320px, 360px and 390px widths before desktop polish.
- Never require horizontal scrolling to read the weekly edition.
- Do not hide essential values behind hover.
- Navigation may collapse; the publication name and subscribe action must remain legible.
- Touch targets should be at least 44×44 CSS pixels.

## 9. Chart system

Every chart should answer one sentence: **What should the reader notice?**

### Chart anatomy

Use this order:

1. Claim-led headline
2. Explanatory subtitle with metric, unit and time period
3. A sentence-style key, only if the encoding cannot be directly labelled
4. Plot
5. Source and revision caveat
6. Methodology or download link where needed

### Choosing a chart

| Question | Default form | Rules |
| --- | --- | --- |
| How has something changed over time? | Line chart | Direct-label the lines; emphasise one series; use no legend when labels fit |
| How do places rank? | Sorted horizontal bars | Start a quantitative scale at zero; put values on or beside bars |
| How did two points change? | Dumbbell | Label endpoints; explain hollow/filled marks in a sentence below the subtitle |
| Are two measures related? | Scatterplot | Label the subject and notable outliers; include a trend only when analytically justified |
| Do many places follow different paths? | Small multiples | Use shared scales; use identical structure; highlight one panel rather than every line |
| Is geography itself the finding? | Map | Use only when spatial pattern matters; pair with a ranked list or phone-safe fallback |

### Marks, labels and axes

- Put important values next to the marks they describe.
- Direct-label series at their endpoints. Use a conventional legend only when direct labels are genuinely impossible.
- If a key is necessary, write it as a short sentence beneath the subtitle. Never float a legend on top of the plot.
- Remove the grey plot outline. A baseline and subtle horizontal gridlines are enough.
- Avoid vertical gridlines unless they answer a specific reading task.
- Show no more than four x-axis ticks on a narrow phone chart.
- Use zero baselines for bars. A non-zero line-chart baseline is acceptable when disclosed and analytically appropriate.
- Use honest scale intervals and preserve comparable scales across small multiples.
- Annotate the event or inflection, not every point.
- Do not smooth or interpolate a line unless the method is explained.

### Numbers and units

- Use the unit in the subtitle or axis, then avoid repeating it on every mark.
- Use one decimal only when it changes the interpretation.
- Distinguish `%` from percentage-point change; write the latter as `pp` in charts and spell it out in prose on first use.
- Use thin-space or locale-appropriate thousands grouping consistently.
- State whether currency is nominal, real, market exchange rate or purchasing-power adjusted.
- State whether an aggregate is weighted and how.

### Chart colour

- Accent: the single subject the edition asks the reader to follow.
- Ink: the strongest comparator or a structural baseline.
- Muted: context series, prior values and non-featured countries.
- Line: gridlines only.
- Do not use red to imply failure by default; the publication accent is editorial, not semantic.

### Accessibility

- Pair colour with a label, mark shape or line style.
- Supply concise alt text that states the finding and includes the most important values.
- Provide the underlying CSV and a text interpretation.
- Ensure the reading order works without the SVG or image.
- Avoid patterns so dense that they shimmer or obscure labels.

### Phone and Substack rendering

The web chart is a responsive SVG. The Substack chart is a static, phone-first image generated from the same edition data.

- Standard export width: 1200px. Height follows the chart; use a tall portrait canvas for rankings or small multiples rather than shrinking type. Launch editions range from 1800px to 3900px high.
- Treat 1200px as a high-density export of an approximately 360px-wide phone composition.
- In the exported source image, use roughly 58–68px for the chart headline, 40–48px for data labels and 36–42px for subtitles, keys and sources. Verify the final rendered result rather than relying on these numbers mechanically.
- Keep essential detail inside safe side margins of at least 48px on the source canvas.
- Test the actual image at 320px and 360px CSS widths. Nothing essential may depend on pinch-to-zoom.
- Prefer fewer labelled observations over smaller type.
- The social/OG image may use a separate crop, but it must preserve the same claim and values.

The maintained examples for the five chart families are in [`work/europe-chart-format-guide.html`](work/europe-chart-format-guide.html).

## 10. Sources and methodology

Every edition must preserve:

- Original publisher and dataset title
- Direct source URL
- Access date
- Geographic scope
- Unit and price basis where applicable
- Time period
- Aggregation and transformation method
- Treatment of missing data and revisions
- The exact observations plotted, downloadable as CSV
- Material caveats

Prefer primary statistical agencies, Eurostat, national offices, peer-reviewed datasets and transparent international sources. An aggregator such as Our World in Data may provide access and useful documentation, but retain the identity of the original data producer.

Do not choose an old observation merely because it strengthens the story. If countries use meaningfully different definitions, say so near the chart.

### Source-line pattern

> Source: ILOSTAT modelled estimates, accessed 24 August 2026. Values may be revised.

Keep this readable. A source is editorial evidence, not legal fine print.

## 11. Substack and email

The website is the canonical edition. Substack receives a native draft and chart image from the same source file.

### Publication identity on Substack

- Display name: **Common Values**
- One-line description: **One chart a week on Europe's progress.**
- About text: **A weekly data letter about Europe's progress, trade-offs and shortcomings. One carefully reported chart, every Friday.**
- Accent: passport burgundy `#71394D`
- Background, where the platform permits it: vellum `#F3EFE5`
- Header and title treatment: editorial serif, sentence case
- Body and information treatment: neutral sans serif, sentence case

Substack cannot reproduce a self-hosted web type system exactly inside every email client. Choose its closest restrained editorial serif for the publication title and post titles, and a plain sans serif for body text. Do not introduce a third display face, all-caps headings or decorative cover art to compensate for the platform limits. The Common Values wordmark and exported charts carry the exact Instrument Serif/Public Sans system.

### Native issue structure

1. Direct subject line in sentence case
2. Preview text that adds context rather than repeats the subject
3. Two- or three-sentence hook
4. Full-width chart image with alt text
5. 300–600 words explaining what changed, why it matters and the main caveat
6. Methodology/data link
7. One restrained subscribe or forward prompt

### Subject and preview text

- State the result; do not tease it.
- Keep preview text to roughly 50–90 characters.
- Avoid all caps, “urgent”, “free”, excessive punctuation and manufactured curiosity.
- Do not put an emoji in every subject line. Use one only when it conveys information.

### Platform constraints

- Do not fight Substack's native body typography with fragile workarounds.
- Carry the brand through the wordmark, chart, title, colour, spacing and editorial voice.
- Use a single-column structure and no dashboard-style card layout.
- Do not depend on custom JavaScript, hover, animation or webfont loading inside email.
- Use descriptive links, not “click here”.

### Publishing operations

Maintain explicit consent, a visible unsubscribe route and an accurate privacy notice. Configure SPF, DKIM, DMARC and one-click unsubscribe before scaling distribution. Never use purchased lists.

## 12. Photography, illustration and motion

Data is the primary visual material. Photography should be rare and reportorial: real European people, places, infrastructure, science and industry, with a clear relationship to the story.

Avoid stock handshakes, heroic flag imagery, generic skylines, decorative maps and AI-generated documentary scenes. Credit all commissioned or licensed work.

Use icons only when they improve navigation or comprehension. Motion, where the web supports it, should explain a transition in the data and respect reduced-motion preferences. Never animate merely to signal modernity.

The approved motion vocabulary (September 2026) covers two passes. The first: one orchestrated homepage entrance (kicker, chart and headline block rising 9px with a 60ms stagger), a 2px burgundy reading-progress rule on canonical editions, a 180ms origin-aware open for the mobile menu, 150ms colour eases on hover states, and one 3px forward step for CTA arrows. The second (transitions.dev suite): masthead taglines cycling with a blur text-swap, provenance values popping in with a stagger, chart series drawing themselves and bars growing from zero, every page visit rising softly into place, a burgundy pill that glides between data-library categories, archive rows stepping toward the reader on hover, an arrow sliding into the subscribe pill, and archive rows revealing in stagger as they scroll into view. Everything sits behind `prefers-reduced-motion: no-preference`, and the global reduce override also zeroes delays and iteration counts so no content is ever hidden. The origins are documented in [`DESIGN_INFLUENCES.md`](DESIGN_INFLUENCES.md).

## 13. Pre-publication checklist

### Evidence

- [ ] The headline is true from the displayed data.
- [ ] The comparison is relevant and not cherry-picked.
- [ ] The latest defensible observation is used.
- [ ] Units, geography and time period are explicit.
- [ ] Transformations and aggregate weights are reproducible.
- [ ] The strongest caveat appears near the finding.
- [ ] Source URL, publisher, access date and CSV are present.

### Chart

- [ ] There is one primary chart and one editorial highlight.
- [ ] The form matches the question.
- [ ] Series and important values are directly labelled.
- [ ] Any key sits beneath the subtitle and outside the plot.
- [ ] There is no grey plot outline or decorative chart frame.
- [ ] Gridlines are necessary and quiet.
- [ ] Colour is not the only differentiator.
- [ ] Alt text states the finding and important values.

### Design

- [ ] Headings and labels use sentence case.
- [ ] Instrument Serif and Public Sans are performing their defined roles.
- [ ] No gradient, glow, shadow, generic card or decorative pill has appeared.
- [ ] Headline wrapping and prose measure are deliberate.
- [ ] Focus states and contrast remain visible.

### Phone and email

- [ ] Web edition passes at 320px, 360px and 390px.
- [ ] Live production URL has been opened in current iOS Safari at 390px or narrower.
- [ ] Instrument Serif roman, Instrument Serif italic and Public Sans return as local WOFF2 assets; no request is made to Google Fonts.
- [ ] The exported chart is legible at 320px without zoom.
- [ ] No information depends on hover.
- [ ] Substack subject and preview text do different jobs.
- [ ] The issue contains one restrained call to action.
- [ ] The 200% browser-zoom check has been completed.

## 14. Implementation source of truth

| Concern | Current source |
| --- | --- |
| Colour, type, spacing and responsive styles | `app/assets/stylesheets/application.css` |
| Font loading and global layout | `app/views/layouts/application.html.erb` |
| Font binaries and OFL licences | `app/assets/fonts/` |
| Embedded fonts for chart and social exports | `app/helpers/brand_fonts_helper.rb` |
| Canonical homepage theme | `app/views/home/index.html.erb` (`design-review`) |
| Edition data and editorial copy | `content/editions/` |
| Web and export chart rendering | `app/views/editions/` |
| Chart-family examples | `work/europe-chart-format-guide.html` |
| Substack draft publishing | `app/services/edition_substack_publisher.rb` |
| Design-influence research and motion vocabulary | `DESIGN_INFLUENCES.md` |
| Reading progress on canonical editions | `app/javascript/controllers/reading_progress_controller.js` |

If implementation and this document disagree, treat this document as the design decision and open a deliberate implementation change. Do not silently introduce a third pattern.
