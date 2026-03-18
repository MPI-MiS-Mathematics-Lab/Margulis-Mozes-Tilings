# Hyperbolic Curve Text Demo

## Files

- `index.html`: main demo page
- `scripts/extract_outline_data.py`: shape outline generator
- `requirements.txt`: dependencies for the generator
- `fonts/`: local font inputs
- `data/`: generated outline/layout data files consumed by `index.html`

## Setup

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

## Regenerate Data

The generator is text-specific.

Blaka Ink:

```bash
.venv/bin/python scripts/extract_outline_data.py \
  --font fonts/BlakaInk-Regular.ttf \
  --text "The fence curves in toward the side of the house." \
  --direction ltr \
  --script Latn \
  --language en \
  --output data/blaka-ink-outline-data.js
```

Arabic Blaka Ink:

```bash
.venv/bin/python scripts/extract_outline_data.py \
  --font fonts/BlakaInk-Regular.ttf \
  --text "النص العربي يمكنه اتباع منحنى جيوديسي." \
  --direction rtl \
  --script Arab \
  --language ar \
  --output data/blaka-ink-arabic-outline-data.js
```

Regular Computer Modern:

```bash
.venv/bin/python scripts/extract_outline_data.py \
  --font fonts/cmunrm.ttf \
  --text "The fence curves in toward the side of the house." \
  --direction ltr \
  --script Latn \
  --language en \
  --output data/computer-modern-outline-data.js
```

Bold Computer Modern:

```bash
.venv/bin/python scripts/extract_outline_data.py \
  --font fonts/cmunbx.ttf \
  --text "The fence curves in toward the side of the house." \
  --direction ltr \
  --script Latn \
  --language en \
  --output data/computer-modern-bold-outline-data.js
```

Regular Arabic Noto Naskh:

```bash
.venv/bin/python scripts/extract_outline_data.py \
  --font fonts/NotoNaskhArabic-Regular.ttf \
  --text "النص العربي يمكنه اتباع منحنى جيوديسي." \
  --direction rtl \
  --script Arab \
  --language ar \
  --output data/noto-naskh-arabic-outline-data.js
```

Bold Arabic Noto Naskh:

```bash
.venv/bin/python scripts/extract_outline_data.py \
  --font fonts/NotoNaskhArabic-Bold.ttf \
  --text "النص العربي يمكنه اتباع منحنى جيوديسي." \
  --direction rtl \
  --script Arab \
  --language ar \
  --output data/noto-naskh-arabic-bold-outline-data.js
```

Arabic Noto Naskh With Tashkeel:

```bash
.venv/bin/python scripts/extract_outline_data.py \
  --font fonts/NotoNaskhArabic-Regular.ttf \
  --text "الخَيْلُ وَاللّيْلُ وَالبَيْداءُ تَعرِفُني   وَالسّيفُ وَالرّمحُ والقرْطاسُ وَالقَلَمُ" \
  --direction rtl \
  --script Arab \
  --language ar \
  --output data/noto-naskh-arabic-tashkeel-outline-data.js
```

Useful knobs:

- `--flatness-em`: outline flattening tolerance in em units. Lower is more accurate and more expensive. The current default is `0.0015`.
- `--direction`, `--script`, `--language`: shaping controls passed to HarfBuzz.
- `--reuse-layout-js`: reuse the shaped run from an existing generated JS file and only rebuild the glyph outlines.

## Run

```bash
index.html
```