# Frontend Aesthetics Reference

## Generic AI Design Patterns to Avoid

These are the most common generic AI-generated aesthetics. If your design looks like any of these, pivot:

### The "Purple Gradient on White" Pattern
- Linear gradient from `#7c3aed` to `#a855f7` on hero sections
- White background, purple accent, gray text
- Rounded cards with subtle shadows
- **Why it's bad**: Every AI model converges on this. It signals "generated" instantly.

### The "SaaS Starter Kit" Pattern
- Inter font, blue primary color (`#2563eb`), card-based layout
- "Features" section with 3-4 icon cards in a row
- Hero with "Get Started" CTA, gradient text headline
- **Why it's bad**: It's the default output of every template generator. Zero personality.

### The "Dark Mode Dashboard" Pattern
- `#111827` background, `#1f2937` cards, `#60a5fa` accents
- Sidebar navigation, data tables with zebra striping
- **Why it's bad**: Functional but forgettable. No visual identity.

### The "Bento Grid" Pattern
- Everything in rounded rectangles, tightly packed
- Every card has a subtle border and shadow
- **Why it's bad**: Trendy but overused. Feels like a component library demo.

## What Makes Design Memorable

### 1. Unexpected Typography
- Use a font nobody expects in that context
- Mix serif display with monospace body (or vice versa)
- Size contrast: massive headlines next to small, tight body text
- Letter-spacing as a design tool (tight for headlines, wide for labels)

### 2. Color with Intent
- **Dominant + accent**: One color takes 70% of the space, one accent gets 10%
- **Unusual pairings**: Terracotta + sage, navy + mustard, charcoal + coral
- **Avoid**: Blue + white, purple + white, green + white (the "default" trio)

### 3. Spatial Boldness
- **Asymmetry**: Off-center alignment, uneven column widths
- **Overlap**: Elements that break their container boundaries
- **Negative space**: Generous margins that create breathing room
- **Scale**: One element dramatically larger than everything else

### 4. Texture and Atmosphere
- Grain/noise overlays (subtle, 3-5% opacity)
- Gradient meshes (multiple overlapping gradients)
- Geometric patterns (dots, lines, crosses as backgrounds)
- Layered transparencies (glass morphism done well, not the 2021 version)

### 5. Motion with Purpose
- **Staggered reveals**: Elements appear sequentially with `animation-delay`
- **Scroll-triggered**: Elements react to viewport position
- **Hover states**: Surprising but smooth transitions
- **Micro-interactions**: One delightful detail (e.g., a button that morphs)

## Framework-Specific Tips

### React
- Use `framer-motion` for animations (not raw CSS when complex)
- `useMemo` for derived state, `useCallback` for stable references
- Keep components small — one visual concern per component
- Use CSS-in-JS (Tailwind, styled-components) or CSS modules — be consistent

### Vue
- Leverage `<style scoped>` with CSS variables for theming
- Use `<Transition>` and `<TransitionGroup>` for built-in animations
- Composables for shared logic

### Svelte
- Use built-in `transition:` and `animate:` directives
- Leverage reactive declarations (`$:`) for derived values
- Keep stores simple — prefer props when possible

### Plain HTML/CSS
- CSS custom properties for all design tokens
- `@media` queries for responsive breakpoints
- CSS `@keyframes` for animations with `prefers-reduced-motion` fallback
- Semantic HTML: `<header>`, `<main>`, `<section>`, `<article>`, `<nav>`, `<aside>`

## Accessibility Checklist

- [ ] Color contrast meets WCAG AA (4.5:1 for text, 3:1 for large text)
- [ ] Focus states are visible and styled (don't remove `outline` without replacement)
- [ ] Interactive elements are keyboard accessible
- [ ] Images have `alt` text
- [ ] Form inputs have associated `<label>` elements
- [ ] `prefers-reduced-motion` is respected
- [ ] Semantic HTML structure (headings in order, landmarks)
- [ ] Touch targets are at least 44x44px

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
