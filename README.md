# Margulis–Mozes Tilings (WebGL)

Interactive hyperbolic polygon tilings rendered with Three.js and custom GLSL shaders.

## Installation

### Prerequisites

- [Node.js](https://nodejs.org/) (v18 or higher recommended)
- npm (comes with Node.js)
- Python 3.13+ (for the SVG/notebook tools)

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
   pip install -r requirements.txt
   cd ..
   ```

## Running the WebGL Viewer

### Development Mode

Start the development server with hot-reload:

```bash
npm run dev
```

This will:
- Start a local development server (typically at `http://localhost:5173`)
- Open the default viewer in your browser
- Watch for changes and automatically reload

You can access different viewers:
- `http://localhost:5173/viewer.html` - Main shader viewer with menu
- `http://localhost:5173/UHP.html` - Upper Half-Plane model
- `http://localhost:5173/PoincareDisc.html` - Poincaré Disc model
- `http://localhost:5173/UHP4Colored.html` - 4-colored UHP tiling

### Production Build

Build optimized production files:

```bash
npm run build
```

Preview the production build:

```bash
npm run preview
```

### Using the Shader Viewer

The main `viewer.html` provides an interactive interface to:

- **Switch shaders**: Choose from multiple hyperbolic tiling visualizations
- **Adjust parameters**: Modify N (polygon sides) and a (scale parameter) in real-time
- **Load textures**: Drag and drop PNG files or select from the textures folder
- **Save images**: Click "💾 Save as PNG" to export the current visualization

URL parameters can customize the view:
```
viewer.html?shader=uhp&N=6&a=0.8
viewer.html?shader=binarytiling1&texture=./textures/example.png
```

## Working with Notebooks

The `svg_window_art/` directory contains Jupyter notebooks for generating SVG tilings:

1. **Start Jupyter**
   ```bash
   cd svg_window_art
   jupyter lab
   ```

2. **Open a notebook** (e.g., `Marguli-Mozes_hwidth.ipynb` or `Margulis-Mozes-SVG.ipynb`)

3. **Run cells** to generate SVG tilings in the `output/` directory

4. **Convert to PNG**: Run the last cell in the notebook to batch-convert all SVGs to PNGs

## Project Structure

```
├── viewer.html           # Main interactive shader viewer
├── UHP.html             # Upper Half-Plane standalone viewer
├── PoincareDisc.html    # Poincaré Disc standalone viewer
├── shaders/             # GLSL shader programs
│   ├── *.frag.glsl      # Fragment shaders
│   └── common.vert.glsl # Shared vertex shader
├── textures/            # Texture files for shader mapping
├── svg_window_art/      # Python notebooks for SVG generation
│   ├── *.ipynb          # Jupyter notebooks
│   ├── hyperbolic_svg.py # Helper library
│   └── output/          # Generated SVG/PNG files
└── legacy/              # Older standalone HTML versions
```

## Available Shaders

- **disc**: Hyperbolic Polygon Tiling (Poincaré Disk)
- **uhp**: Hyperbolic Polygon Tiling (Upper Half-Plane)
- **uhp4colored**: 4-colored UHP tiling
- **binarysquare**: Conformal Poincaré Square
- **binarytiling1/2/3**: Binary tiling variants
- **binarycaps**: Binary tiling with caps
- **binarytilingtexture**: Texture-mapped binary tiling

Shaders live in `shaders/` and are imported via Vite `?raw` for syntax highlighting in editors.

## Contributing

Contributions are welcome! Please ensure:
- Shaders compile without errors
- Code follows the existing style
- New features are documented

## License

See LICENSE file for details.
