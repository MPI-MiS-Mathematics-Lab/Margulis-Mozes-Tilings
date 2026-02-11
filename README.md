# Margulis–Mozes Tilings

Interactive visualizations of hyperbolic aperiodic tilings, inspired by the Margulis–Mozes construction.

Two visualization approaches:
1. **WebGL shader viewer** — real-time GPU-rendered tilings (Three.js + GLSL)
2. **SVG notebook** — precise vector tilings via Python/Jupyter

## Installation

### Prerequisites

- [Node.js](https://nodejs.org/) (v18+)
- Python 3.13+ (for notebooks)

### Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/MPI-MiS-Mathematics-Lab/Margulis-Mozes-Tilings.git
   cd Margulis-Mozes-Tilings
   ```

2. **Install JavaScript dependencies**
   ```bash
   npm install
   ```

3. **Install Python dependencies (for notebooks)**
   ```bash
   cd svg_window_art
   python -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt
   ```

## WebGL Shader Viewer

```bash
npm run dev
```

Opens `viewer.html` at `http://localhost:5173/viewer.html`. The viewer provides:

- **Shader selection** dropdown with all available tilings
- **Parameter controls** (thickness, children count) for applicable shaders
- **Texture selection/upload** for texture-mapped shaders
- **Save as PNG** export

URL parameters customize the view, e.g.:
```
viewer.html?shader=binarytilingbasicdisc3tex
viewer.html?shader=binarycapshypthickuhpgeodesic&T=0.04&C=3
```

### Available Shaders

| Key | Description |
|-----|-------------|
| `binarycapshypthickuhpgeodesic` | N-ary tiling with caps (geodesic thickness, UHP) |
| `binarycapshypthick` | N-ary tiling with caps (hyp. thickness, disk) |
| `binarycapshypthickuhp` | N-ary tiling with caps (hyp. thickness, UHP) |
| `binarytilingbasicuhp` | Binary tiling (basic, UHP) |
| `binarytilingbasicdisc` | Binary tiling (basic, disk) |
| `binarytilingbasicuhp3tex` | Binary tiling (3 textures, UHP) |
| `binarytilingbasicdisc3tex` | Binary tiling (3 textures, disk) |
| `binarytilingbasicuhp3texrandom` | Binary tiling (3 textures, UHP, random per tile) |
| `binarytilingbasicdisc3texrandom` | Binary tiling (3 textures, disk, random per tile) |
| `binarytilingtexturedisc` | Texture tiling (Poincaré disk) |
| `binarytilingtexture` | Texture tiling (UHP) |
| `binarysquare` | Conformal Poincaré square |

### Production Build

```bash
npm run build
npm run preview
```

## SVG Notebook

```bash
cd svg_window_art
jupyter lab
```

Open `Margulis-Mozes_hwidth.ipynb` to generate self-similar hyperbolic tilings with:
- Horocycle scenes at multiple scale levels
- Bump structures with geodesic segments and rays
- Full polygon tilings with 3-coloring algorithm
- Renderings in both Poincaré disc and upper half-plane models

The notebook uses `hyperbolic_svg.py`, a wrapper around the [`hyperbolic`](https://github.com/cduck/hyperbolic) library that provides a UHP-native interface.

## Project Structure

```
├── viewer.html              # Main interactive shader viewer
├── vite.config.mts          # Vite build config
├── package.json             # JS dependencies (Three.js, Vite)
├── shaders/                 # Active GLSL fragment shaders
│   ├── *.frag.glsl          # Fragment shaders
│   └── common.vert.glsl     # Shared vertex shader
├── textures/                # Texture files for shader mapping
├── svg_window_art/          # Python SVG generation
│   ├── Margulis-Mozes_hwidth.ipynb  # Main notebook
│   ├── hyperbolic_svg.py    # Hyperbolic geometry library
│   ├── requirements.txt     # Python dependencies
│   └── output/              # Generated SVGs/PNGs (gitignored)
└── legacy/                  # Archived older versions
    ├── shaders/             # Retired shader files
    └── *.html               # Old standalone viewers
```

## Contributing

Contributions are welcome! Please ensure:
- Shaders compile without errors
- Code follows the existing style
- New features are documented

## License

See LICENSE file for details.
