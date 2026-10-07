# Swappy visual foundation

This document is the implementation contract for Swappy's visual language.
New mobile UI should consume `SwappyTheme`, standard themed Material widgets,
and `SwappyVisualTokens` instead of introducing feature-local colors, radii,
glass recipes, or animation timings.

## Design intent

Swappy combines two modes:

- **Event energy** for discovery, venue context, seat browsing and completed
  swap celebrations.
- **Calm trust** for ticket evidence, requests, conversation, agreement and
  recovery states.

Vibrancy must never reduce the clarity of seat information or imply that a
ticket, provider inventory, transfer, or agreement has been verified.

## Core palette

| Role | Light | Dark | Use |
|---|---|---|---|
| Canvas | `#F8F6FF` | `#070B18` | Application background |
| Surface | `#FFFFFF` | `#10162A` | Standard cards and sheets |
| Raised surface | `#FFFFFF` | `#171E38` | Elevated content surfaces |
| Brand violet | `#6D28D9` | `#A970FF` | Primary actions and energy |
| Neon cyan | `#00AFC8` | `#46DCEB` | Connections and secondary energy |
| Energy coral | `#FF5C73` | `#FF667F` | Live and time-sensitive accents |
| Celebration gold | `#FFB648` | `#FFC857` | Completed milestones only |

Error, warning, success, disabled and focus states remain semantic Material
states. Do not replace an error with coral or a success with celebration gold.

## Event combinations

| Event family | Primary | Secondary |
|---|---|---|
| Music | Violet | Cyan |
| Sports | Cobalt blue | Lime |
| Arts | Magenta | Coral |
| Family | Amber | Sky blue |
| Neutral/mixed | Violet | Coral |

Use one event combination per composed surface. Do not combine all event
palettes in the same card or screen.

## Surfaces and gloss

Glass is a functional top layer, not a default card style.

Approved glass uses:

- one clipped backdrop blur;
- a translucent surface fill;
- one violet-to-cyan outer rim;
- a restrained top-left specular highlight;
- a soft shadow to separate navigation from scrolling content.

Use glass for floating navigation, transient top-level controls and a small
number of overlays. Use standard surfaces for forms, ticket information,
conversation, request comparison, dialogs and long content.

Never stack multiple blurred surfaces. Pause or remove nonessential effects
when performance drops, and keep text contrast independent of content behind
the glass.

## Shape

| Token | Value | Use |
|---|---:|---|
| Compact | 10 | Small tags and dense controls |
| Control | 14 | Inputs and buttons |
| Card | 18 | Content cards and dialogs |
| Sheet | 28 | Modal and bottom sheets |
| Dock | 32 | Floating navigation dock |
| Pill | 999 | Chips only |

The dock has one rounded-rectangle silhouette. A selected destination does not
receive an inner circle or pill. Selection is shown with a violet-to-cyan
stroke on the outlined icon, a mild glow, stronger label weight and selected
semantics.

## Spacing

Use the 4-based scale exposed by `SwappySpacing`:

`4, 8, 12, 16, 24, 32, 48`

The default horizontal screen inset is 16. Interactive targets remain at least
44 logical pixels even when their visible glyph is smaller.

## Typography

Inter remains the operational typeface. Event titles may use heavier weights
and larger scale, but seat labels, dates, venue details, trust messages and
agreement copy must prioritize readability and scalable text.

Do not render important text inside generated imagery or video.

## Motion

| Token | Duration | Use |
|---|---:|---|
| Quick | 160 ms | Icon, color and pressed feedback |
| Standard | 260 ms | Dock selection and ordinary transitions |
| Emphasized | 420 ms | Event hero and completed milestone motion |

Use `SwappyMotion.fluid` for ordinary transformations and
`SwappyMotion.expressive` for a small number of elastic transitions. Operating
system reduced-motion settings must reduce these durations to zero and retain
all state information without animation.

Motion should explain a state change:

- event card expands into event detail;
- selected dock icon changes stroke;
- two seat cards align after mutual agreement;
- the completed swap receives one short celebration.

Do not loop decorative motion in forms, conversations or agreement screens.

## Floating dock behavior

- The expanded dock is the default on the three primary destinations.
- It may compact or move offscreen during deliberate scroll behavior later,
  using the component's `visible` input.
- It may be hidden in focused ticket capture, full-screen seat map,
  authentication and agreement flows.
- It must return predictably and must not hide merely because data is loading.
- Labels and selected semantics remain available to assistive technology.

## Implementation entry points

- `SwappyTheme.light` and `SwappyTheme.dark`: application-wide Material theme.
- `context.swappyVisual`: expressive color and gradient tokens.
- `SwappySpacing`, `SwappyRadii`, `SwappyMotion`: layout and motion primitives.
- `SwappyGlassSurface`: bounded glossy control/navigation layer.
- `SwappyFloatingDock`: primary participant navigation.

Import `package:swappy_mobile/core/theme/swappy_theme.dart` as the public entry
point. The older Medusa-named file and tokens remain only as a compatibility
bridge while existing screens migrate.

Server configuration may select only approved, versioned event tones and
assets. It must never send executable styling or animation code.
