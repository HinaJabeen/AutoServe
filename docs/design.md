# AutoServe — UI/UX & Design System

## 1. Philosophy

The dashboard app (the furthest-along surface) reads as a dense, dark-first "control room" for dealership operations — ambient background glow, glassmorphism sidebar, cyan accent on near-black surfaces — rather than a flat enterprise CRUD UI. The intent is that a salesperson staring at this screen for a full shift should feel like they're driving something, not filling out forms. That tone should be preserved in new screens: generous use of `AppPalette.accent` for state (active nav, focused input, live badges), low-opacity glow/shadow for depth, and restraint elsewhere — most of the UI is neutral surface and muted text so the accent actually reads as a signal.

The public customer portal (`apps/customer`) is intentionally a separate visual register: it's a consumer storefront (target UX: a swipeable "Tinder for Cars" card deck, see `docs/architecture.md` §6 Module 2 / §8.2), not an operations console. **Both the CRM and the consumer app must support a full light/dark toggle** — this is a hard requirement, not just a CRM nicety; a long-standing read of §1 that treated the consumer app as "light-only" was wrong and is corrected here (see §5 for the target palette, which gives both apps real dark-mode values, not just a lighter tint of the CRM's). It is currently only scaffolded (`main.dart` renders a `Placeholder()`); no screens exist yet to extend.

## 2. Responsive strategy: desktop web vs. mobile

AutoServe targets Flutter Web first for the dashboard (dealership staff work at a desk) and must still degrade sensibly to mobile/tablet for on-lot use. The patterns already in place:

- **Fixed-width sidebar + flexible content** (`DashboardShell`, `apps/dashboard/lib/layout/dashboard_shell.dart`): a `264px` sidebar via `Row` + `Expanded`. This is a desktop-oriented layout; it has no mobile breakpoint yet. When adapting a screen for narrow viewports, collapse the sidebar into a drawer below a width threshold rather than letting it squeeze the content pane — do not hardcode new `SizedBox(width: 264)` style layouts without a responsive fallback.
- **`Expanded` + `Row`/`Column` over fixed pixel grids**: the Kanban board (`lead_inbox_screen.dart`) lays out its four stage columns as `Expanded` children of a `Row`, so column width scales with window size instead of being hardcoded. Follow this pattern for any new multi-column layout — fixed widths are the exception, not the default.
- **`LayoutBuilder`/`MediaQuery` for breakpoints**: use these (not device checks) when a screen genuinely needs different structure on narrow vs. wide — e.g. collapsing the Kanban board's four columns into a vertical stack or tab view below a width threshold. No such breakpoint exists yet in the inventory/leads screens; this is a known gap to fill rather than a pattern to copy.
- **Dense, fixed-size UI chrome** (11–13px type, 32–36px controls) is deliberate for the dashboard's "fits a lot on one screen" density goal — don't scale these up for mobile by just bumping font sizes everywhere; redesign the layout (e.g. cards instead of a 4-column board) for small screens instead.

## 3. State management: Riverpod

Riverpod (`flutter_riverpod: ^2.5.1`) is the only state management approach in this codebase — do not introduce `Provider`, `Bloc`, `GetX`, or raw `setState`-driven app state alongside it. The patterns already established:

| Pattern | When used | Example |
|---|---|---|
| `Provider` | Deriving a read-only value from other providers (service instances, computed booleans) | `inventoryServiceProvider`, `isAuthenticatedProvider` |
| `StateProvider` | Simple mutable UI state (search text, a selected filter) | `inventorySearchProvider`, `inventoryStatusFilterProvider` |
| `StateNotifierProvider` | Hand-rolled state machine with explicit async methods (sign in, sign out, resolve role) | `authProvider` (`AuthNotifier extends StateNotifier<AuthState>`) |
| `AsyncNotifierProvider` | Paginated/async-loaded collections that need `loadMore()`, `refresh()`, optimistic patch/remove | `inventoryListProvider` (`InventoryListNotifier extends AsyncNotifier<InventoryPageState>`) |
| `ref.watch(x.select((s) => s.field))` | A widget only cares about one field of a larger state object and must not rebuild on unrelated changes | `RoleGate` watches `authProvider.select((s) => s.role)` |
| `.stream(...)` wrapped as a `StreamProvider`/`AsyncValue` | Realtime Supabase subscriptions (leads list, dealer vehicles) | `dealerLeadsStreamProvider`, `dealerVehiclesStreamProvider` |

**Flow for a typical screen**: a presentation widget (`ConsumerWidget`/`ConsumerStatefulWidget`) watches one or more providers → providers call into a `*Service` class that wraps `SupabaseService.client` → mutations go through a `*NotifierProvider`'s methods, never directly from the widget calling Supabase. Keep Supabase calls inside services/notifiers, not inside `build()` methods.

**Cache invalidation on sign-out** is a deliberate, security-relevant pattern: `AuthNotifier.signOut()` invalidates every per-dealership provider family (`dealerVehiclesStreamProviderFamily`, `dealerLeadsStreamProviderFamily`, etc.) *before* calling `_c.auth.signOut()`, so a stale provider can't fire one more read with the outgoing user's JWT. Any new per-dealership stream/list provider must be added to that invalidation list, or a signed-out session can leak the previous tenant's cached data for a frame.

## 4. Theming: `ThemeExtension` dual-mode system

Colors are never hardcoded in widgets. The dashboard defines its palette as a single `ThemeExtension`:

- **`AppPalette`** (`apps/dashboard/lib/theme/app_palette.dart`) extends `ThemeExtension<AppPalette>`, declaring every semantic color the UI needs (`background`, `surface`, `card`, `border`, `accent`, `accentSecondary`, `textPrimary`/`Secondary`/`Tertiary`/`Muted`, `success`/`warning`/`error`, plus glow/badge variants) with two `static const` instances: `AppPalette.dark` (near-black + cyan `#00E5FF`) and `AppPalette.light` (warm cream + amber `#E59235`). It implements `copyWith` and `lerp` so Flutter can animate between the two on theme switch.
- **`AppTheme`** (`theme/app_theme.dart`) builds a full `ThemeData` per mode by registering the palette via `extensions: [p]` and mapping it onto `ColorScheme`, `AppBarTheme`, `InputDecorationTheme`, `ElevatedButtonTheme`, `ChipTheme`, and `TextTheme`. This is the one place Material theming and the custom palette are reconciled — new global style decisions belong here, not scattered across widgets.
- **Access pattern**: `context.palette` (an extension getter on `BuildContext`, `AppPaletteContext`) returns `Theme.of(context).extension<AppPalette>() ?? AppPalette.dark`. Every widget that needs a themed color calls `context.palette.xxx` — never `Colors.xxx` or a raw hex literal. This is how `_LeadCard`, `DashboardShell`, `_KanbanColumn`, etc. stay correct in both modes without an `if (isDark)` branch per color.
- **Switching modes**: `themeProvider` (`theme_provider.dart`) is a `NotifierProvider<ThemeNotifier, ThemeMode>` that persists the choice to `SharedPreferences` under `autoserve_theme_mode` and restores it on `build()`. It exposes `toggle()` plus explicit `setLight()`/`setDark()` (used by `ThemeToggleButton`, which sets a mode directly rather than flipping it).
- **Two root-widget implementations exist; only one is live.** `apps/dashboard/lib/main.dart`'s `main()` actually runs `AutoServeDashboard` (defined in that same file, with its own inline `_buildTheme()`). `app.dart`'s `AutoServeDashboardApp` — which wires `themeProvider`/`AppTheme.light()`/`AppTheme.dark()` into `MaterialApp.router` — is never invoked by `runApp()` anywhere; it's dead code left over from an earlier wiring attempt (only the widget test exercises it). If you're changing how theme/router get wired into the app root, change `AutoServeDashboard` in `main.dart` — that's the one that actually runs. Don't assume a fix to `app.dart`/`AppTheme` reaches the running app.
- **Adding a new color**: add the field to `AppPalette` (constructor, both static instances, `copyWith`, `lerp`), then read it via `context.palette` — never add a one-off `Color` constant in a widget file. Current fields (as of this pass) include `shadowColor`, `statusAvailable`, `statusReserved`, `glassFill`, and `glassBorder` alongside the original surface/text/accent set — several screens (`lead_inbox_screen.dart`, `dashboard_shell.dart`, `appointment_scheduler_screen.dart`, `theme_toggle_button.dart`, etc.) referenced these before they existed on `AppPalette`, which was a compile error; they're now part of the palette.

`shared/lib/theme/` (`AppColors`, `AppDimensions`, `AppTextStyles`) holds the cross-app design tokens (spacing scale, radii, type scale) that both `AppTheme` and any future customer-app theme build on top of. The customer app's current theme in `main.dart` uses `AppColors` directly rather than a `ThemeExtension` — if/when it grows real screens, give it its own `ThemeExtension` (its own palette, per §5) rather than reusing `AppPalette`, which is dashboard-specific and dark-first by default.

## 5. Target premium palette (design spec — not yet applied to `AppPalette`)

This is the approved target color system for the next visual pass. **It has not been implemented yet** — `AppPalette.dark`/`.light` in `apps/dashboard/lib/theme/app_palette.dart` still hold the original cyan (`#00E5FF`) / amber (`#E59235`) values described in §4. Don't assume the colors below are live until `app_palette.dart` is actually updated to match; this section is the spec to implement against, not a description of current code.

**Brand accent (decided): Mercedes Ambient Blue, `#0066FF`**, used consistently across both apps and both theme modes — the CRM's "neon control room" energy and the consumer app's "trust-building CTA" both run on the same accent, not two different brand colors. (The alternative considered was a Porsche Carmine Red `#D5001C`; rejected for this pass because red conventionally reads as error/destructive elsewhere in the UI and would clash with `AppPalette.error`.)

### 5.1 Dealership CRM ("Control Room" theme)

High-density, professional, dark-first, minimizing eye strain over long shifts — glassmorphism sidebar, neon accents on near-black surfaces. This is a refinement of the existing `AppPalette.dark`/`.light`, not a replacement of its structure.

| Token | Dark mode | Light mode |
|---|---|---|
| `background` | Deep Obsidian Black `#050505` | Pearl White `#FAFAFA` |
| `surface` / sidebar | Graphite `#121212`–`#1A1A1A` | Matte Silver `#F3F4F6` |
| `card` | Slightly elevated above `surface`, subtle border | Pearl White card on silver surface, soft drop shadow for depth |
| `accent` / `accentSecondary` | Ambient Blue `#0066FF` (+ a slightly deeper/lighter shade for secondary/hover) | Ambient Blue `#0066FF` (same hue — brand consistency, not relightened per-theme) |
| `textPrimary` | Matte White `#F5F5F7` | Jet Black `#111111` |
| `textSecondary`/`textMuted` | Metallic Grey `#8E8E93` | Charcoal `#4B5563` |
| `success`/`warning`/`error` | unchanged from current `AppPalette` — don't reuse the new accent blue for these; it needs to stay visually distinct from state colors | unchanged |

Implementation note: this maps directly onto existing `AppPalette` fields (`background`, `surface`, `card`, `accent`, `textPrimary`, `textSecondary`, `textMuted`, plus the `shadowColor`/`glassFill`/`glassBorder`/`statusAvailable`/`statusReserved` fields added in the prior schema-reconciliation pass) — no new fields are needed on the class itself, just new color values.

### 5.2 Consumer app ("Tinder for Cars" theme)

Warm, inviting, highly visual, optimized for mobile touch targets and swipe gestures — **with full light and dark support**, not light-only as earlier drafts of this doc implied. Large edge-to-edge vehicle imagery, soft shadows on swipeable cards, rounded corners throughout.

**Implemented — and the accent is a deep jewel emerald, not Ambient Blue.** The table below is the earlier spec, kept for its layout/shape guidance; its color values are superseded. The brand color is a dark, slightly bluish gemstone green — `#006A4E` in light mode, lifted one step to `#00755E` in dark mode — deliberately *not* a bright or neon green (an earlier `#00C853` "Electric Emerald" pass was rejected as too light). The live palettes are `AppPalette.emeraldLight` (pearl white surfaces) and `AppPalette.emeraldDark` (charcoal/slate surfaces) in `shared/lib/theme/app_palette.dart`, bound into `ThemeData` by `apps/customer/lib/core/theme/app_theme.dart`; `themeProvider` there persists Auto/Light/Dark. They are two more instances of the shared `AppPalette` class rather than a separate `ConsumerPalette` extension, so `context.palette` and the shared widgets work unchanged in both apps. Usage rules: fills use `accent` with `onAccent` (white) on top; emerald *text, icons and focus rings* on the page background use `accentSecondary`, because the deep `accent` is too dark to read against the charcoal dark-mode background (`accentSecondary` is `#00755E` in light mode and a soft jewel tint `#3DBE98` in dark mode).

| Token | Light mode | Dark mode |
|---|---|---|
| `background` | warm off-white, not the CRM's clinical Pearl White — slightly warmer undertone to feel "showroom," not "spreadsheet" | a genuinely dark background (not just a dim-grey tint of the light mode) — exact value TBD during implementation, kept dark enough to match the CRM's obsidian-black register for visual family consistency across the product |
| `accent` | Ambient Blue `#0066FF` for primary CTAs (Swipe/Book); consider a secondary warm coral accent for lighter-weight affordances (e.g. a "favorite" heart) if product wants a second signal color — not required | same Ambient Blue, adjusted luminance for dark-background contrast |
| cards | edge-to-edge vehicle photo, rounded corners (`AppDimensions.radiusL`+), soft elevation shadow | same shapes; shadow softened/reduced per standard dark-mode elevation practice (shadows read as muddy on dark backgrounds — prefer a subtle border or lighter-surface elevation instead, consistent with how the CRM's `AppPalette.card` already differs from `surface` only by a lightness step, not a shadow) |

(Superseded: this originally called for a separate `ConsumerPalette` extension — see the implementation note at the top of this section.)
