# Zakat Tracker design system

The generated broad design-system match suggested a marketing demo, handwritten type and glass effects, which do not fit this private financial tool. Explicit product/style searches verified financial dashboards and Minimalism & Swiss Style (full RTL compatibility). The following is the implementation synthesis, not an unmodified generated recommendation.

## Direction
Content-first personal finance, inspired by Apple clarity and Google Material interaction. Keep the existing emerald identity. Soft neutral canvas, opaque white cards, dark ink, generous space, thin borders, no decorative charts or fake financial metrics. Use bundled Inter with Noto Sans Arabic fallback and a consistent outline icon family. The emerald desktop rail and gradient overview card establish hierarchy; a circular progress indicator represents actual recorded Zakat payments.

## Tokens
- Primary emerald #146356; dark emerald #103F36; ink #172C27
- Canvas #F4F6F5; surface #FFFFFF; muted #52655F; border #DDE5E1
- Destructive #B3261E; amber #9A6500 (statuses also use words/icons)
- Spacing 4/8/12/16/24/32; cards 16px radius; controls >=48px
- Body 14–15px with 1.4 line height, secondary 12px, page title 25px, financial total 34px

## Navigation and behavior
Five stable destinations: Dashboard, Records, Tracker, Monthly Giving, Profile. Bottom navigation on phones; labeled rail on tablets/desktop. Dashboard is the default landing view. Record creation is a named primary action. Keep submitted financial calculations locked. Record removal is always a confirmed move to the recycle bin, with an undo action and a 60-day restore window. Never rely on swipe to expose essential actions.

## Financial semantics
Keep currencies separate. Show due Zakat separately from future estimates. Dashboard totals exclude recycled records; Sadaqah never reduces Zakat. Loading and error states must not masquerade as zero balances. No imaginary chart trends. Monthly obligations linked to recycled records cannot create payments or email reminders.

## Responsive/accessibility
Use LayoutBuilder, full available desktop width with a two-column dashboard, wrapping actions and stats, visible labels, keyboard-accessible controls, tooltips on icon actions, high-contrast text. Respect safe areas and reduced-motion preferences; do not animate financial values. Validate at 375, 768 and 1440 CSS pixels and with enlarged text.

Default records stay above search and filters, use a bordered emerald card and explicit badge, and show a clear warning before deletion, with no typing requirement. Other records retain a simple confirmation and 60-day recovery. All essential actions are visible.

Mobile profile groups related settings into a shared surface rather than one large card per row. Security details open on a dedicated route. Use static font weights 400/500/600/700 for predictable rendering; short navigation labels stay on one line. Keep 48px tap targets even as visual density increases.

Use CSS safe-area insets as a fallback for standalone Safari and keep controls above the home indicator. Hide bottom navigation while the keyboard is open. Startup uses one small loading indicator rather than a large logo followed by a smaller one. The app icon shows an elderly sheikh giving a gift to a seated recipient, using burgundy, cream and warm brown. Calculation setup keeps Nisab pricing and Hijri display in More details.
