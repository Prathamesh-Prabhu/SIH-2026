---
name: Serene Institutional Resilience
colors:
  surface: '#f8faf9'
  surface-dim: '#d8dada'
  surface-bright: '#f8faf9'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f2f4f3'
  surface-container: '#eceeed'
  surface-container-high: '#e6e9e8'
  surface-container-highest: '#e1e3e2'
  on-surface: '#191c1c'
  on-surface-variant: '#414846'
  inverse-surface: '#2e3131'
  inverse-on-surface: '#eff1f0'
  outline: '#717976'
  outline-variant: '#c1c8c5'
  surface-tint: '#45645e'
  primary: '#02241f'
  on-primary: '#ffffff'
  primary-container: '#1a3a34'
  on-primary-container: '#83a49c'
  inverse-primary: '#abcec5'
  secondary: '#37675b'
  on-secondary: '#ffffff'
  secondary-container: '#b7eadb'
  on-secondary-container: '#3b6b60'
  tertiary: '#18221f'
  on-tertiary: '#ffffff'
  tertiary-container: '#2d3734'
  on-tertiary-container: '#95a09c'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#c7eae1'
  primary-fixed-dim: '#abcec5'
  on-primary-fixed: '#00201b'
  on-primary-fixed-variant: '#2d4d46'
  secondary-fixed: '#baedde'
  secondary-fixed-dim: '#9ed1c3'
  on-secondary-fixed: '#00201a'
  on-secondary-fixed-variant: '#1d4f44'
  tertiary-fixed: '#dae5e0'
  tertiary-fixed-dim: '#bec9c4'
  on-tertiary-fixed: '#141d1b'
  on-tertiary-fixed-variant: '#3f4945'
  background: '#f8faf9'
  on-background: '#191c1c'
  surface-variant: '#e1e3e2'
typography:
  display-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 34px
    fontWeight: '700'
    lineHeight: 42px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 26px
    fontWeight: '600'
    lineHeight: 34px
    letterSpacing: -0.015em
  headline-lg-mobile:
    fontFamily: Plus Jakarta Sans
    fontSize: 22px
    fontWeight: '600'
    lineHeight: 30px
    letterSpacing: -0.01em
  headline-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  headline-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '600'
    lineHeight: 22px
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  body-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 18px
  label-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 15px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: 0.01em
  label-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.02em
  label-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 11px
    fontWeight: '500'
    lineHeight: 14px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  space-2xs: 0.25rem
  space-xs: 0.5rem
  space-sm: 0.75rem
  space-md: 1rem
  space-lg: 1.25rem
  space-xl: 1.5rem
  space-2xl: 2rem
  space-3xl: 2.5rem
  gutter-mobile: 1rem
  gutter-desktop: 1.5rem
  margin-mobile: 1.25rem
  margin-desktop: 3rem
---

## Brand & Style

This design system is tailored for personnel stress, mental resilience, and welfare monitoring within disciplined forces and demanding institutions. It balances institutional authority with psychological safety, calm empathy, and unwavering discretion. 

The aesthetic sits at the intersection of modern clinical healthcare and restorative nature-based minimalism. The interface avoids aggressive visual stimulation, loud alert colors, or cognitive overload. Instead, it relies on expansive breathing room, deep forest greens, soothing eucalyptus undertones, and gentle rounded surfaces that inspire trust, confidential reflection, and daily calm.

## Colors

The palette draws deeply from restorative botanical hues and muted institutional neutrals:

- **Primary (`#1A3A34`)**: Deep Pine / Forest Slate. Used for primary interactive actions, dominant typography, selected states, and core brand presence. Exudes authority, seriousness, and quiet stability.
- **Secondary (`#4A7A6E`)**: Muted Eucalyptus. Acts as an accent for active icons, secondary indicators, interactive highlights, and balanced emphasis.
- **Tertiary (`#DCE7E2`)**: Soft Sage Tint. Reserved for badge fills, interactive selection containers, progress track backgrounds, and gentle tinted banners.
- **Neutral Canvas (`#F8FAF9`)**: Crisp Warm Off-White base background that prevents retinal fatigue while maintaining surgical cleanliness.
- **Neutral Elevate (`#FFFFFF`)**: Pure White for cards, input surfaces, bottom sheets, and elevated tiles.
- **Border Neutral (`#E3E8E5`)**: Soft bone-grey for subtle structure and hairline separators.
- **Status & Feedback**: Subdued mood markers use gentle desaturated steps (e.g., `#E88C7D` for high distress indicators, `#F2BA74` for caution, and `#7FB59B` for positive status) avoiding alarming starkness.

## Typography

Typography relies entirely on **Plus Jakarta Sans**, chosen for its crisp geometric legibility paired with approachable, softened terminals. 

- **Headlines**: Weighted at SemiBold (600) and Bold (700). Set with tightened negative tracking to establish an authoritative, dignified posture without feeling sterile.
- **Body**: Regular (400) weight set with generous line heights to minimize eye strain during mood reporting, clinical screening, and reading self-help content.
- **Labels & Microcopy**: Medium (500) and SemiBold (600) ensure instant scanning for critical state markers, confidentiality notices, and time trackers.

## Layout & Spacing

The layout embraces calm containment and generous breathing space, reducing visual tension for users under cognitive or operational stress:

- **Base Unit**: Strict 4px/8px incremental rhythm governing all padding, margins, and component internal heights.
- **Mobile Paradigm**: Primary operational views are vertically stacked within a single-column layout spanning standard mobile safe areas (padding horizontal: `1.25rem` / `20px`). Key actions anchor firmly to the bottom edge.
- **Tablet & Desktop Adaptation**: Reflows into structured 4-column (tablet) and 12-column (desktop) grids with maximum reading container widths of 640px for single-flow assessments, and 1120px for multi-column dashboards.
- **Form & Flow Rhythm**: Inter-card spacing defaults to `space-md` (16px), while distinct thematic groups use `space-2xl` (32px).

## Elevation & Depth

Visual hierarchy is maintained via gentle tonal stacking and low-contrast borders rather than deep or aggressive drop shadows:

- **Surface Layering**: The primary foundation is the `#F8FAF9` neutral tint. Active cards and elevated interactive panels rise using pure white `#FFFFFF` fills accented by hairline borders in `#E3E8E5`.
- **Shadow System**: When elevated tiles require separation (such as fixed headers, persistent action footers, or bottom sheets), use soft ambient diffusion:
  - `shadow-sm`: `0px 1px 3px rgba(26, 58, 52, 0.04), 0px 1px 2px rgba(26, 58, 52, 0.02)`
  - `shadow-md`: `0px 4px 12px rgba(26, 58, 52, 0.06), 0px 2px 4px rgba(26, 58, 52, 0.03)`
- **Selected States**: Elevated elements do not rise physically on selection; instead, they shift tonally into `#EFF5F2` with an inner or outline tint of `#4A7A6E`.

## Shapes

The design system incorporates intentional, gentle curves to evoke psychological comfort and accessibility:

- **Cards & Content Blocks**: Built with `rounded-2xl` (`16px` to `20px`), softening the structural borders and projecting approachable warmth.
- **Primary Buttons & Action Bars**: Rendered as pill shapes (`rounded-full`) or soft-rounded blocks (`rounded-xl` / `14px`) to create clear, inviting affordances.
- **Badges, Tags, and Pill Counters**: Strict pill format (`rounded-full`) with balanced horizontal padding.
- **Inputs & Radio Panels**: Contoured with `rounded-xl` (`12px` to `14px`) providing smooth touch targets.

## Components

### Buttons
- **Primary**: Deep Pine background (`#1A3A34`), text in crisp white (`#FFFFFF`), full width on mobile, height 52px, `rounded-xl` or `rounded-full`. Hover/Pressed state subtly deepens to `#142E29`. Accompanied by right-aligned trailing icons (e.g., `arrow-right`) where progressing flows.
- **Secondary / Ghost**: Transparent fill, muted pine text (`#1A3A34`), no border, utilized for skip, back, or secondary actions.
- **Icon Buttons**: Circle containers (`40px x 40px`) with subtle border `#E3E8E5` or muted sage background `#EFF3F1`.

### Assessment & Choice List Cards
- **Unselected State**: Solid `#FFFFFF` or pale tint `#F3F6F5` fill, `1px` border in `#E8ECE9`, height 56px–64px, `rounded-2xl`, radio ring outline right-aligned.
- **Selected State**: Light sage container background `#E1ECE7`, border shifted to `#4A7A6E`, trailing radio dot filled with `#1A3A34` and an interior white checkmark.
- **Mood Rating Items**: Vertical stack cards with soft sentiment emoji indicators, distinct pastel icon backgrounds, clear typography, and tactile row selection.

### Badges & Status Chips
- **Institutional Badges**: Compact pill layout with tertiary fill `#DCE7E2`, text `#1A3A34` at `label-sm` SemiBold.
- **Status Tags**: Required tags tinted in subtle muted rose (`#FBEBE8`, text `#9C3C2D`); optional tags in soft eucalyptus (`#E2EDE8`, text `#2D5D51`).

### Input Fields
- **Container**: White `#FFFFFF` background, 52px height, `1px` border in `#D4DDD8`, rounded `14px`.
- **Typography & Icons**: Leading utility icon (ID, badge, lock) in `#7A948C`, value text in `#1A3A34`. Focus state utilizes a `1.5px` border in `#1A3A34` with zero aggressive glows.

### Privacy & Trust Panels
- **Informational Banners**: Low-contrast tinted cards `#F1F5F3` with delicate shield/lock iconography in `#4A7A6E`, reassurance microcopy in `#526E65`, reinforcing that inputs remain anonymous and confidential.

### Progress Bars
- Linear horizontal tracks: Track background `#E2E8E5`, active bar filled with Primary Deep Pine `#1A3A34`, height 4px, `rounded-full`.