---
name: frontend-design
description: Create distinctive, production-grade frontend interfaces with high design quality. Use this skill when the user asks to build web components, pages, artifacts, posters, or applications (examples include websites, landing pages, dashboards, React components, HTML/CSS layouts, or when styling/beautifying any web UI). Guides creative, polished implementation that avoids generic AI aesthetics.
license: Apache-2.0
compatibility: "Works with any frontend stack (HTML/CSS/JS, React, Vue, Svelte, Flutter). No external dependencies required."
---

# Frontend Design

Create distinctive, production-grade frontend interfaces that avoid generic "AI slop" aesthetics. Implement real working code with exceptional attention to aesthetic details and creative choices.

## Workflow

### 1. Understand the Context

Gather requirements from the user:
- **Purpose**: What problem does this interface solve? Who uses it?
- **Audience**: Technical, casual, enterprise, creative?
- **Tone**: Pick a clear direction — brutally minimal, maximalist chaos, retro-futuristic, organic/natural, luxury/refined, playful/toy-like, editorial/magazine, brutalist/raw, art deco/geometric, soft/pastel, industrial/utilitarian. Use these for inspiration, but design something true to the requested product and audience.
- **Constraints**: Framework, performance budgets, accessibility requirements, routing, state management, existing design system boundaries.
- **Differentiation**: What makes this unforgettable? What is the one visual or interaction detail someone will remember?

**Critical:** Choose a clear conceptual direction and execute it with precision. Bold maximalism and refined minimalism both work — the key is intentionality, not intensity.

### 2. Commit to a Design Direction

Before writing code, decide on:
- **Typography**: Choose fonts that are beautiful, unique, and interesting. Avoid generic fonts like Arial, Inter, Roboto, Space Grotesk, and default system stacks unless the existing product explicitly requires them. Prefer characterful font choices. Pair a distinctive display font with a refined body font when appropriate.
- **Color & Theme**: Commit to a cohesive aesthetic. Use CSS variables or equivalent tokens for consistency. Dominant colors with sharp accents outperform timid, evenly distributed palettes.
- **Motion**: Plan high-impact moments. One well-orchestrated page load with staggered reveals (`animation-delay`) creates more delight than scattered micro-interactions. Use CSS-only solutions for static HTML. Use the Motion library for React when available.
- **Spatial Composition**: Consider unexpected layouts — asymmetry, overlap, diagonal flow, grid-breaking elements, generous negative space, or controlled density. Match composition to the product's tone.
- **Backgrounds & Visual Details**: Create atmosphere and depth rather than defaulting to solid colors. Add contextual effects: gradient meshes, noise textures, geometric patterns, layered transparencies, dramatic shadows, decorative borders, custom cursors, grain overlays — or whatever serves the concept.

### 3. Implement

Write production-grade, functional code (HTML/CSS/JS, React, Vue, Svelte, Flutter, or the user's stack) that is:

- Visually striking and memorable
- Cohesive with a clear aesthetic point of view
- Meticulously refined in every detail
- Accessible (semantic HTML, ARIA where needed, keyboard navigation, sufficient contrast)
- Responsive (mobile-first or fluid layouts)

**Match implementation complexity to the aesthetic vision.** Maximalist designs need elaborate code with extensive animations and effects. Minimalist or refined designs need restraint, precision, and careful attention to spacing, typography, and subtle details.

### 4. Verify

- **Visual coherence**: Does every element belong to the same aesthetic world?
- **No generic AI patterns**: Check against the anti-patterns list below
- **Functional**: All interactions work, no broken states
- **Responsive**: Test mental model at mobile, tablet, desktop breakpoints
- **Accessible**: Colors have contrast, focus states are visible, semantic structure is correct

## Anti-Patterns

| ❌ Avoid | ✅ Instead |
|---|---|
| Purple gradients on white backgrounds | Commit to a palette with character |
| Inter, Roboto, Space Grotesk as default | Choose fonts with personality |
| Predictable card grids | Break the grid — asymmetry, overlap, masonry |
| Cookie-cutter SaaS layouts | Design for the specific product context |
| Timid, evenly distributed colors | Dominant color with sharp accents |
| Generic shadows and borders | Decorative details that serve the concept |
| Same safe aesthetic every time | Vary between light/dark, different visual languages |
| Over-animated everything | One or two high-impact moments > scattered micro-interactions |

## Design Quick Reference

### Typography Pairings (non-generic)

| Display | Body | Vibe |
|---------|------|------|
| Playfair Display | Source Sans 3 | Editorial, refined |
| Space Mono | IBM Plex Sans | Technical, precise |
| DM Serif Display | DM Sans | Warm, editorial |
| Syne | Plus Jakarta Sans | Bold, contemporary |
| Fraunces | Sora | Soft, expressive |
| Clash Display | Geist | Modern, clean |
| Alegreya | Lato | Literary, classic |
| Outfit | Work Sans | Geometric, friendly |

### Animation Timing Tokens

```css
--instant: 0ms;
--fast: 150ms;
--normal: 300ms;
--slow: 500ms;
--stagger: 50ms; /* per-item delay for lists */
```

### Background Atmosphere Techniques

- **Gradient mesh**: Multiple overlapping radial gradients with low opacity
- **Noise texture**: SVG filter with `feTurbulence` for grain
- **Dot grid**: CSS `radial-gradient` as repeating background
- **Geometric shapes**: Large blurred circles/squares for depth
- **Line patterns**: Subtle CSS repeating gradients for texture

## Output Format

Present the design as working code. Structure your response:

```
## Design Direction

<Name the aesthetic direction in one sentence. e.g., "Editorial minimalism — generous whitespace, serif display headings, muted earth tones with a single warm accent.">

## Implementation

<Full working code — HTML/CSS/JS or framework components. Self-contained and runnable.>

## Key Details

- <Typography choices and rationale>
- <Color palette and why it fits>
- <Motion/interaction highlights>
- <Any intentional asymmetry or layout choices>
```

If the user requested a specific framework or integrated into an existing project, provide code that fits that context rather than a standalone file.

## Usage

- **"Design a landing page for X"** — full page with hero, sections, footer
- **"Build a dashboard component"** — data-dense, information hierarchy focused
- **"Make this look better"** — audit existing code, propose aesthetic improvements
- **"Create a <component> in <framework>"** — framework-specific component
- **"Redesign this with a <tone> feel"** — apply specific aesthetic direction

## Notes

- **NEVER** use generic AI-generated aesthetics. Interpret creatively and make unexpected choices.
- If the user provides an existing design system, respect its tokens and constraints — elevate within those boundaries.
- When in doubt, read `references/aesthetics.md` for more inspiration on avoiding common AI design patterns.
- Remember: a coding agent can produce extraordinary creative frontend work. Do not hold back.
