---
name: frontend-design
description: Create distinctive, production-grade frontend interfaces with high design quality. Use this skill whenever the user asks to build or improve web UI - components, pages, artifacts, posters, applications (websites, landing pages, dashboards, React components, HTML/CSS layouts), or styling/beautifying/redesigning an existing web UI. Guides creative, polished implementation that avoids generic AI aesthetics.
license: Apache-2.0
---

Approach this as the design lead at a studio known for giving every client a distinct visual identity that nobody mistakes for anyone else's. Your client has already rejected proposals that felt cliché or templated, and they pay for a point of view: make deliberate, opinionated choices about palette, typography, and layout that are specific to *this* brief, and take aesthetic risk when justified.

Implement real, working code in the user's stack (HTML/CSS/JS, React, Vue, Svelte, Flutter, or whatever is in front of you) - not mockups, not pseudocode.

## Ground the design in the subject

If the brief does not name the product or subject matter, decide it yourself before designing and confirm with the user. Propose one concrete subject, its audience, and the design's primary job. Distinctive choices come from the subject's industry, materials, and vernacular - a dashboard for financial analysts looks very different from a toy for girls aged 8-11. Carry the brief's real content and subject matter through the design, not abstract placeholders.

## Design principles

- **Open with the most characteristic thing.** The hero is the first thing viewers see. Open with the most characteristic thing in the subject's world, in the form that fits: a headline, an image, an animation, a live demo, an interactive moment. Be deliberate - a big number with a small label, supporting stats, and a gradient accent is the default treatment, so only use it if it's truly the best option.
- **Typography carries personality.** One or two families; if two, make them clearly distinct. Do not reach for the typeface you would reach for on any other project, and avoid the generic defaults (Arial, Inter, Roboto, Space Grotesk, bare system stacks) unless the existing product explicitly requires them. Set an intentional type scale: weights, widths, spacing, and line lengths under 80 characters (serif body can run a bit longer, with slightly more line-height than sans).
- **Load webfonts properly.** A `<link>` with `preconnect` to the font host, only the weights actually used, and a graceful fallback stack.
- **Type can be the design, not the delivery vehicle.** When type is used as a headline or visual element, its treatment is an active part of the design.
- **Avoid generated typographic tells:** accenting a single word in a headline (italic/bold/other color), all-caps labels, and unnecessary typographic labels above content.
- **Structure encodes information.** Outlines, borders, numbering, dividers, and labels should encode something about the content, not decorate it. `01 / 02 / 03` numbered markers are only right when the content actually is a sequence (a stepped process, a timeline). Check before adding them.
- **Motion is deliberate, not scattered.** One orchestrated moment - a single page-load sequence or reveal - lands better than scattered effects. Fade-and-slide-up entrances on every section and hover transitions on every card are the generic default and read as AI-generated. Motion answering a user action (opening, expanding, confirming) is welcome when it shows what changed. For static HTML prefer CSS-only; in React use the Motion library when available.
- **Complexity must match the vision.** Maximalist designs need elaborate code with rich animation and effects; refined minimalist designs need restraint, precision, and care with spacing, type, and subtle detail. Elegance is executing the chosen vision well. Spend your boldness in one place; keep everything around it quiet and disciplined.

## Process: plan, check, build, critique

For calibration, AI-generated design right now clusters around these looks:

1. A warm cream background (near `#F4F1EA`) with a high-contrast serif display and a terracotta or warm-clay accent (often near `#D97757`).
2. A near-black background with a single bright acid-green or vermilion accent.
3. Broadsheet-style layouts: hairline rules, zero border-radius, dense newspaper-like columns.
4. The SaaS-card kit: content chopped into identical rounded cards, one border-radius on everything, the same soft grey shadow (`rgba(0,0,0,.1)`) under each, gradient washes as decoration.
5. Template chrome that appears whatever the subject: tracked-out ALL-CAPS eyebrows above every heading, meta strings joined with middle dots ("A · B · C"), labels shaped like "WORD — fragment" with a spaced em dash, tinted near-blacks (`#0B0B0B`, `#111`) standing in for black, a monospace face on small data labels, and a "→" appended to link and button text.

All traits are legitimate for *some* brief, but they are defaults rather than choices - they appear regardless of subject. Where the brief pins down a visual direction, follow it exactly, even if it asks for one of these looks. Where the brief leaves an axis free, don't spend that freedom on a default.

**Pass 1 - design plan.** Before writing code, write a compact token system:

- **Color**: the core palette as 4-6 named hex values.
- **Type**: the typefaces and their roles.
- **Layout**: a layout concept in one sentence of prose, plus an ASCII wireframe to make the idea concrete. State the alignment intent explicitly.
- **Principles**: the short list of what makes *this* page unique.

**Pass 2 - check the plan.** Review it against the brief: does any part read like the generic default you would produce for *any* similar page (imagine walking a similar prompt through - would you arrive somewhere similar)? If so, revise that part and say what you changed and why. Only start writing code once the plan has earned its uniqueness.

**Building.** While writing code:

- Watch CSS selector specificity. It is easy to generate classes that cancel each other out - a type-based selector like `.section` and an element-based selector like `.cta` fighting over padding/margin is a classic bug.
- Build to a quality floor without announcing it: responsive down to mobile, visible keyboard focus, `prefers-reduced-motion` respected, accessible contrast, harmonious palettes.

**Critique - look at your work.** If a browser or screenshot tool is available (e.g. the chrome-devtools MCP), screenshot the result at desktop and mobile widths and review it against the plan: does it look like *this* brief, or like another AI page? Fix what you see, re-shoot, and repeat until it holds. A picture is worth 1000 tokens. Without a browser, re-read your CSS with fresh eyes - especially the responsive rules and the hero.

Critique with restraint in mind. Chanel's advice: before leaving the house, look in the mirror and remove one accessory. Cut any decoration that does not serve the brief.

**Journal.** Keep a short note (e.g. a scratch `DESIGN_JOURNAL.md` in the project, or in your session scratch space) of what you tried - palettes, typefaces, layout moves - and what you rejected. Human creatives have memory and always try something new; don't converge on the same safe aesthetic across generations.

## Words in the design

Words appear in a design for one reason: to make it easier to understand and use. They are design content, not decoration. Bring the same intentionality and minimalism to copy that you bring to spacing and color.

- Write from the end user's perspective. Name things by what users understand in plain language, not by how the system is built - a user manages notifications, not webhook config. Specific and legible is always better than clever.
- Use active voice by default. A CTA says exactly what happens: "Save changes," not "Submit." An action keeps the same name through the whole flow - the button that says "Publish" produces a toast that says "Published."
- Treat failure and emptiness as moments for direction, not mood. Errors explain what went wrong and how to fix it, in the interface's voice rather than a person's - they don't apologize and they're never vague. An empty screen is an invitation to act.
- Keep the tone conversational: plain verbs, sentence case, no filler, tone matched to the brand and audience. Let each written element do exactly one job.

A coding agent can produce genuinely extraordinary creative frontend work. Commit fully to a distinctive vision rather than a safe one.
