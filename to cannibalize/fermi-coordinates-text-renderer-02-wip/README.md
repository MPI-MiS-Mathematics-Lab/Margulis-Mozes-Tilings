# Mesh Typography

## Run

```bash
pip install -r requirements-potpourri.txt
python scripts/mesh_heat_bunny_potpourri_server.py
```

Then open `http://127.0.0.1:8013/`.

## Required Asset

The server expects:

```text
assets/bunny/reconstruction/bun_zipper.ply
```

If the bunny mesh is missing, download it once:

```bash
mkdir -p assets
curl -L --max-time 60 https://graphics.stanford.edu/pub/3Dscanrep/bunny.tar.gz -o assets/bunny.tar.gz
tar -xzf assets/bunny.tar.gz -C assets bunny/reconstruction
```
## Current Limitation

The heat field is currently based on a curve represented using a discrete sampling, and looks jagged/pinned near the curve. The code currently approximates that near curve neighborhood with extrinsic distances.

## Related Work

- Shape from Metric: direct paper on recovering an embedding in R^3 from prescribed intrinsic metric / edge lengths
  https://cseweb.ucsd.edu/~alchern/projects/ShapeFromMetric/
- Geometric Modeling in Shape Space: classic geodesic framework for approximately isometric deformations of meshes
  https://graphics.stanford.edu/~niloy/research/shape_space/shape_space_sig_07.html
- Time-Discrete Geodesics in the Space of Shells: thin-shell geodesics with membrane and bending terms
  https://doi.org/10.1111/j.1467-8659.2012.03180.x
- Exploring the Geometry of the Space of Shells: more complete shell-space geometry with exponential map and parallel transport
  https://doi.org/10.1111/cgf.12450
- Geometric Optimization Using Nonlinear Rotation-Invariant Coordinates: optimization in edge-length and dihedral-angle coordinates, useful for
  near-isometric problems
  https://doi.org/10.1016/j.cagd.2020.101829
- Repulsive Surfaces: collision-avoiding surface optimization via tangent-point energy and fractional Sobolev preconditioning
  https://www.cs.cmu.edu/~kmcrane/Projects/RepulsiveSurfaces/index.html
- Repulsive Shells: collision-aware shell shape space for geodesic interpolation / embedding without self-intersection
  https://www.cs.cmu.edu/~kmcrane/Projects/RepulsiveShells/index.html
- GeoText: geodesic-based 3D text generation on triangular meshes  
  https://www.mdpi.com/2073-8994/17/10/1727
- geoTangle: interactive geodesic tangle patterns on surfaces  
  https://ggg.dibris.unige.it/papers/TOG22_geoTangle/TOG22.html
- BoolSurf: boolean operations on surfaces with geodesic lines and surface Bezier curves  
  https://research.adobe.com/publication/boolsurf-boolean-operations-on-surfaces/
- b/Surf: interactive Bezier splines on surface meshes  
  https://ggg.dibris.unige.it/papers/TVCG22_bSurf/TVCG22.html
- Vector graphics on surfaces using straightedge and compass constructions  
  https://doi.org/10.1016/j.cag.2022.04.007
- Generative Escher Meshes: tileable mesh-based 2D art under wallpaper symmetries  
  https://research.adobe.com/publication/generative-escher-meshes/
- Regular Meshes from Polygonal Patterns: geometry from user-specified polygonal combinatorics  
  https://doi.org/10.1145/3072959.3073593
- Re-Tiling Polygonal Surfaces: classic SIGGRAPH work on re-tessellating surfaces  
  https://faculty.cc.gatech.edu/~turk/retile/retile.html
- Fabric Tessellation: realizing freeform surfaces with smocking patterns  
  https://segaviv.github.io/papers/3d_smocking/
