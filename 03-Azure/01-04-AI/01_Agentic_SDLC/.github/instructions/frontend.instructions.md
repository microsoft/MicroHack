---
description: "Guidance for editing and reviewing frontend code changes in the React + Vite + Tailwind stack."
applyTo: "src/frontend/src/**, src/frontend/index.html, src/frontend/vite.config.ts, src/frontend/tailwind.config.js"
---
# Frontend Review Guidance
Focus on UX quality, accessibility, performance, and maintainability of the React + Vite + Tailwind stack.

## Key Principles
- Accessibility first: semantic HTML, proper labels, ARIA only when semantics insufficient, maintain focus order.
- State management: Prefer React Query for server cache; keep local UI state local; avoid prop drilling with context sparingly.
- Performance: Split lazy routes/components, avoid large bundle additions, prefer dynamic import for rarely used views.
- Styling: Tailwind utility classes preferred; abstract repeated class groups into small components or `clsx` helpers rather than custom CSS.
- Types: Avoid `any`; type API responses with shared DTO types; infer with generics where possible.

## Review Checklist
1. Data fetching uses React Query (staleTime, error handling, loading states) not ad-hoc `useEffect` + `axios`.
2. Components remain small & focused (< ~150 LOC). Suggest extraction when crossing concerns (data + complex layout + formatting).
3. Responsive: verify critical views at mobile (≤640px), md (~768px), lg (≥1024px).
4. Form inputs: keyboard accessible, visible focus ring, validation feedback with text, not only color.
5. Images: optimized (correct size, `alt` text), avoid layout shift (width/height or aspect-ratio set).
6. Routing: use `react-router-dom` v7 patterns (data routers if adopted) and avoid nested suspense waterfalls.
7. Security: never interpolate untrusted HTML; sanitize if unavoidable.

## Testing Guidance
- Encourage React Testing Library tests for complex logic (conditional rendering, form validation, custom hooks).
- Snapshot tests only for stable presentational components.

## Performance Flags
- Re-render hotspots (large lists) should use `memo` or windowing (e.g., `react-window`) when count > ~200.
- Avoid anonymous inline functions in large list children where measurable.

## Anti-Patterns to Nudge
- Overuse of context for simple prop passing.
- Mixing data fetching + presentational markup in one large component.
- Custom CSS files duplicating Tailwind utilities.

## Example Feedback Style
"Consider extracting the price formatting into a `formatCurrency()` utility because it's duplicated in ProductCard and OrderSummary and risks divergence."