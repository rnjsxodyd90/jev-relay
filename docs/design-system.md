# Jev Relay design system

## Direction

Jev Relay is an interpreter decision workbench, not a dashboard or launch page. The interface should feel like a careful bilingual editor: the utterance occupies the desk, evidence sits close at hand, and the four decisions form one precise inspection rail.

## Tokens

### Color

- **Workspace** `#F4F7FB`: cool blue-white page ground.
- **Paper** `#FFFFFF`: primary editing and evidence surfaces.
- **Slate** `#17233B`: main text and strong controls.
- **Muted slate** `#62708A`: supporting text and metadata.
- **Indigo** `#4F5FD7`: active state, focus, and decision confidence.
- **Rule** `#D7DEEA`: structural borders; success and error use restrained `#237A57` and `#B54444` only when semantic.

### Type

Use **Avenir Next** for its open, technical-but-human drawing, falling back to **Segoe UI**, **Helvetica Neue**, and sans-serif. Use **SFMono-Regular** / **Cascadia Mono** only for code and identifiers, never as decorative dashboard labeling. Body copy is 15–16px with a maximum reading width near 72 characters; controls and headings stay sentence case.

### Layout

Desktop is left aligned. A narrow product/navigation mast anchors a wide working surface. In Workbench, the source editor owns two-thirds of the width and one vertical four-decision rail owns the remaining third. Evidence uses one compact table rather than repeated metric cards. Mobile collapses to a single column with navigation and selectors wrapping naturally.

```text
┌──────────────┬──────────────────────────────────────────────────┐
│ Jev Relay    │ Workbench   Evidence   Integration              │
│ brief note   ├──────────────────────────────────────────────────┤
│              │ replay/live + case controls                     │
│              ├─────────────────────────────┬────────────────────┤
│              │ source utterance            │ action             │
│              │ context                     │ memory             │
│              │ voice tools / execute       │ register           │
│              │                             │ sense              │
│              ├─────────────────────────────┴────────────────────┤
│              │ Jev result compared directly with Qwen           │
└──────────────┴──────────────────────────────────────────────────┘
```

```text
Mobile
┌──────────────────────────────┐
│ Jev Relay                    │
│ Workbench Evidence Integr.   │
├──────────────────────────────┤
│ mode + case controls         │
│ source                       │
│ context                      │
│ voice / execute              │
│ four-decision rail           │
│ provider comparison          │
└──────────────────────────────┘
```

## Principles

1. **The work is the focal point.** Open on a real recorded utterance, not a marketing hero or aggregate number.
2. **One memorable device.** The connected four-decision rail is the visual signature; surrounding surfaces remain quiet.
3. **Structure earns every line.** Borders separate editor, decisions, and evidence; no decorative gradients, floating blobs, or cloned stat cards.
4. **Recorded and live never blur.** Recorded replay shows measured benchmark rows. Live mode is opt-in, names the services receiving text, and never invents a result.
5. **Evidence stays inspectable.** Preserve raw case IDs, rounds, provider latency, exact correctness, and semantic sense correctness.
6. **Interaction is explicit.** Voice preparation starts only after a gesture, transcription remains editable, sending is separate, playback is manual, and status text is announced.

## Brief review and revision

An early idea used a top row of summary tiles. That is the generic benchmark-dashboard pattern the brief rejected, so it was removed. The replacement is a workbench-first composition with one compact evidence table and a case ledger. A second idea made every panel equally rounded; that flattened hierarchy, so only primary work surfaces receive a modest radius while rows and decision steps rely on rules. Indigo is reserved for selection, focus, and confidence rather than decoration. No oversized number, repeated eyebrow, warm editorial palette, near-black theme, gradient, or nonessential motion remains.
