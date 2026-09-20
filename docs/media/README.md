# README artwork

The README uses original Far artwork and actual native views rendered with synthetic test state. These images contain no user desktop, personal activity, or live call data.

| Asset | Description |
| --- | --- |
| `hero.png` | Far's original Soft pause app icon and project introduction, composed at twice the README display size. |
| `break-flow.gif` | Countdown, look-away rest, and completion views, shown in sequence with accelerated timing. This is a synthetic native UI preview, not a screen recording. |
| `break-preview.png` | A still version of the rest preview for readers who prefer no animation. |
| `fixtures/*.png` | Unmodified native fixture renders used in the composition. |

The source icon is [`Resources/FarIconSource.png`](../../Resources/FarIconSource.png). Its original vector geometry and authorship are documented in [iconography](../../Resources/ICONOGRAPHY.md). Typography is rendered with the macOS Avenir Next system font; the font itself is not distributed.

The fixture PNGs came from `VisualFixtureTests.testRenderVisualFixturesWhenRequested`, using the light appearance and opaque accessibility surface. The fixture values are synthetic. The compositor used for these images does not reproduce Liquid Glass or desktop dimming. See [validation](../../VALIDATION.md) for the distinction between fixture rendering and live desktop validation.

Regenerate the compositions on macOS with Python 3 and Pillow:

```sh
python3 scripts/render-readme-assets.py
```

To refresh source fixtures, run the optional visual tests with `FAR_PREVIEW_DIR` set to an absolute output directory, then copy `countdown-light.png`, `rest-light.png`, and `completion-light.png` into `docs/media/fixtures/` before regenerating. These fixtures use offscreen native views; separate live checks require a desktop-connected session.

Suggested GIF caption: **Synthetic native UI preview, with accelerated timing.**
