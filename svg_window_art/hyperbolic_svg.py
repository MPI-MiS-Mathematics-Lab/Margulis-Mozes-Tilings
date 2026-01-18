"""
Hyperbolic SVG Renderer - A wrapper for the 'hyperbolic' library by cduck

This module provides a UHP-native interface for describing hyperbolic geometry
using complex numbers, with rendering to the Poincare disc model.

================================================================================
NOTES FOR AI AGENTS AND FUTURE DEVELOPERS
================================================================================

MATHEMATICAL TRANSFORMATIONS
-----------------------------

The underlying 'hyperbolic' library by cduck works natively in the Poincare disc
model. We use Mobius transformations to convert UHP coordinates to disc.

The library's Transform class implements Mobius transformations of the form:

    w = (a*z + b) / (c*z + d)

UHP TO DISC TRANSFORMATION (Transform.disk_to_half().inverted()):
-----------------------------------------------------------------
    w = (i*z + 1) / (z + i)

    Key mappings (UHP -> disc):
        i      ->  0        (i to disc center)
        1      ->  1        (1 on real line to right of disc)
        -1     ->  -1       (-1 on real line to left of disc)
        0      ->  -i       (origin to bottom of disc)
        infinity ->  i      (infinity to top of disc)

ARCHITECTURE:
-------------

User describes in UHP (complex numbers)
         |
         v
    [uhp_to_disc transform]
         |
         v
Library primitives (disc coordinates)
         |
         v
SVG output (Poincare disc model)

================================================================================
"""

import math
from typing import List, Optional, Union
from dataclasses import dataclass, field

import drawsvg as draw
from hyperbolic import poincare


# =============================================================================
# COORDINATE TRANSFORMATION
# =============================================================================

def get_uhp_to_disc_transform() -> poincare.Transform:
    """Get the Mobius transformation from Upper Half-Plane to Poincare disc."""
    return poincare.Transform.disk_to_half().inverted()


def uhp_to_disc(z: complex) -> tuple:
    """Convert a complex number in UHP to disc coordinates."""
    transform = get_uhp_to_disc_transform()
    return transform.apply_to_tuple((z.real, z.imag))


# =============================================================================
# ELEMENT TYPES
# =============================================================================

@dataclass
class PointElement:
    """A point in the hyperbolic plane."""
    z: complex
    radius: float = 0.02
    hradius: Optional[float] = None
    style: dict = field(default_factory=dict)


@dataclass
class SegmentElement:
    """A geodesic segment between two points."""
    z1: complex
    z2: complex
    hwidth: Optional[float] = None
    style: dict = field(default_factory=dict)


@dataclass
class GeodesicElement:
    """A geodesic (infinite line) through two points."""
    z1: complex
    z2: complex
    hwidth: Optional[float] = None
    style: dict = field(default_factory=dict)


@dataclass
class PolygonElement:
    """A geodesic polygon defined by vertices."""
    vertices: List[complex]
    hwidth: Optional[float] = None
    style: dict = field(default_factory=dict)


@dataclass
class PolylineElement:
    """An open geodesic path through multiple points (not closed)."""
    vertices: List[complex]
    hwidth: Optional[float] = None
    style: dict = field(default_factory=dict)


@dataclass
class CircleElement:
    """A hyperbolic circle with center and radius."""
    center: complex
    hradius: float
    hwidth: Optional[float] = None
    style: dict = field(default_factory=dict)


@dataclass
class HorocycleTangentElement:
    """A horocycle tangent to the real axis at a point, passing through another."""
    tangent_point: float
    through_point: complex
    hwidth: Optional[float] = None
    style: dict = field(default_factory=dict)


@dataclass
class HorizontalHorocycleElement:
    """A horizontal horocycle at height y (tangent to infinity in UHP)."""
    height: float
    hwidth: Optional[float] = None
    style: dict = field(default_factory=dict)


@dataclass
class HorocycleTileElement:
    """
    A quadrilateral tile with horocycle edges (top/bottom) and geodesic edges (left/right).

    In UHP: a rectangle with corners at (x_left, y_bottom), (x_right, y_bottom),
    (x_right, y_top), (x_left, y_top).

    Top and bottom edges are arcs of horocycles (tangent to infinity).
    Left and right edges are geodesic arcs (vertical lines in UHP).
    """
    x_left: float
    x_right: float
    y_bottom: float
    y_top: float
    style: dict = field(default_factory=dict)


@dataclass
class RayElement:
    """A geodesic ray from a point toward an ideal point."""
    start: complex
    toward_ideal: Union[float, complex]
    hwidth: Optional[float] = None
    style: dict = field(default_factory=dict)


SceneElement = Union[PointElement, SegmentElement, GeodesicElement,
                     PolygonElement, PolylineElement, CircleElement,
                     HorocycleTangentElement, HorizontalHorocycleElement,
                     HorocycleTileElement, RayElement]


# =============================================================================
# SCENE CLASS
# =============================================================================

class HyperbolicScene:
    """
    A scene for describing hyperbolic geometry using UHP coordinates.
    Renders to the Poincare disc model.

    All coordinates are specified as complex numbers in the Upper Half-Plane:
    - Real axis (Im(z) = 0) represents the boundary at infinity
    - Upper half-plane (Im(z) > 0) represents the hyperbolic plane

    Example:
        scene = HyperbolicScene()
        scene.add_segment(1j, 1+1j, hwidth=0.1, fill='blue')
        svg = scene.render()
    """

    def __init__(self):
        self.elements: List[SceneElement] = []
        self._uhp_to_disc = get_uhp_to_disc_transform()

    def clear(self):
        """Remove all elements from the scene."""
        self.elements = []

    def add_point(self, z: complex, radius: float = 0.02,
                  hradius: Optional[float] = None, **style) -> 'HyperbolicScene':
        """Add a point at complex coordinate z in UHP."""
        self.elements.append(PointElement(z=z, radius=radius, hradius=hradius, style=style))
        return self

    def add_segment(self, z1: complex, z2: complex,
                    hwidth: Optional[float] = None, **style) -> 'HyperbolicScene':
        """Add a geodesic segment between two UHP points."""
        self.elements.append(SegmentElement(z1=z1, z2=z2, hwidth=hwidth, style=style))
        return self

    def add_geodesic(self, z1: complex, z2: complex,
                     hwidth: Optional[float] = None, **style) -> 'HyperbolicScene':
        """Add an infinite geodesic through two UHP points."""
        self.elements.append(GeodesicElement(z1=z1, z2=z2, hwidth=hwidth, style=style))
        return self

    def add_polygon(self, vertices: List[complex],
                    hwidth: Optional[float] = None, **style) -> 'HyperbolicScene':
        """Add a geodesic polygon with vertices in UHP."""
        self.elements.append(PolygonElement(vertices=vertices, hwidth=hwidth, style=style))
        return self

    def add_polyline(self, vertices: List[complex],
                     hwidth: Optional[float] = None, **style) -> 'HyperbolicScene':
        """Add an open geodesic path through vertices in UHP (not closed)."""
        self.elements.append(PolylineElement(vertices=vertices, hwidth=hwidth, style=style))
        return self

    def add_circle(self, center: complex, hradius: float,
                   hwidth: Optional[float] = None, **style) -> 'HyperbolicScene':
        """Add a hyperbolic circle with center in UHP and hyperbolic radius."""
        self.elements.append(CircleElement(center=center, hradius=hradius, hwidth=hwidth, style=style))
        return self

    def add_horocycle(self, tangent_point: float, through_point: complex,
                      hwidth: Optional[float] = None, **style) -> 'HyperbolicScene':
        """
        Add a horocycle tangent to the real axis.

        Args:
            tangent_point: Real number where horocycle touches the real axis
            through_point: Complex number in UHP that the horocycle passes through
        """
        self.elements.append(HorocycleTangentElement(
            tangent_point=tangent_point, through_point=through_point,
            hwidth=hwidth, style=style
        ))
        return self

    def add_horizontal_horocycle(self, height: float,
                                  hwidth: Optional[float] = None, **style) -> 'HyperbolicScene':
        """
        Add a horizontal horocycle at height y (tangent to infinity).

        In UHP, this appears as the horizontal line y = height.
        In the disc, it maps to a circle tangent to the top of the boundary.

        Args:
            height: The y-coordinate (must be > 0)
        """
        if height <= 0:
            raise ValueError("height must be positive")
        self.elements.append(HorizontalHorocycleElement(
            height=height, hwidth=hwidth, style=style
        ))
        return self

    def add_horocycle_tile(self, x_left: float, x_right: float,
                           y_bottom: float, y_top: float, **style) -> 'HyperbolicScene':
        """
        Add a quadrilateral tile with horocycle and geodesic edges.

        In UHP, this is a rectangle with:
        - Bottom edge: horocycle arc at y = y_bottom
        - Top edge: horocycle arc at y = y_top
        - Left edge: geodesic (vertical) at x = x_left
        - Right edge: geodesic (vertical) at x = x_right

        Args:
            x_left, x_right: x-coordinates of left and right edges
            y_bottom, y_top: y-coordinates of bottom and top edges (must be > 0)
        """
        if y_bottom <= 0 or y_top <= 0:
            raise ValueError("y_bottom and y_top must be positive")
        self.elements.append(HorocycleTileElement(
            x_left=x_left, x_right=x_right,
            y_bottom=y_bottom, y_top=y_top, style=style
        ))
        return self

    def add_ray(self, start: complex, toward_ideal: Union[float, complex],
                hwidth: Optional[float] = None, **style) -> 'HyperbolicScene':
        """
        Add a geodesic ray from start toward an ideal point.

        Args:
            start: Starting point in UHP
            toward_ideal: Real number (point on real axis) or float('inf') for up
        """
        self.elements.append(RayElement(
            start=start, toward_ideal=toward_ideal, hwidth=hwidth, style=style
        ))
        return self

    # -------------------------------------------------------------------------
    # BUILD LIBRARY PRIMITIVES
    # -------------------------------------------------------------------------

    def _to_disc(self, z: complex) -> tuple:
        """Convert UHP point to disc coordinates."""
        return self._uhp_to_disc.apply_to_tuple((z.real, z.imag))

    def _build_point(self, z: complex) -> poincare.Point:
        """Convert UHP point to library Point."""
        x, y = self._to_disc(z)
        return poincare.Point.from_euclid(x, y)

    def _build_line(self, z1: complex, z2: complex, segment: bool) -> poincare.Line:
        """Convert UHP line/segment to library Line."""
        x1, y1 = self._to_disc(z1)
        x2, y2 = self._to_disc(z2)
        return poincare.Line.from_points(x1, y1, x2, y2, segment=segment)

    def _build_polygon(self, vertices: List[complex]) -> poincare.Polygon:
        """Convert UHP polygon to library Polygon."""
        disc_verts = [self._build_point(z) for z in vertices]
        return poincare.Polygon.from_vertices(disc_verts)

    def _build_polyline_drawables(self, elem: 'PolylineElement') -> tuple:
        """
        Render a polyline as connected segments.

        For now, renders each segment separately. The overlapping joints
        work well for most cases, especially horizontal chains.
        """
        vertices = elem.vertices
        if len(vertices) < 2:
            return ()

        drawables = []
        for i in range(len(vertices) - 1):
            line = self._build_line(vertices[i], vertices[i+1], segment=True)
            drawables.extend(line.to_drawables(hwidth=elem.hwidth, **elem.style))

        return tuple(drawables)

    def _build_circle(self, center: complex, hradius: float) -> poincare.Circle:
        """Convert UHP circle to library Circle."""
        pt = self._build_point(center)
        return poincare.Circle.from_center_radius(pt, hradius)

    def _build_horocycle(self, tangent_point: float, through_point: complex) -> poincare.Horocycle:
        """
        Build a horocycle from tangent point and through point.

        In UHP, horocycle tangent at t passing through z = x + iy:
        - Circle with center (t, r) and radius r
        - r = ((x-t)² + y²) / (2y)
        - Closest point to disc center is at (t, 2r)
        """
        t = tangent_point
        x, y = through_point.real, through_point.imag

        if y <= 0:
            raise ValueError("through_point must be in upper half-plane")

        r = ((x - t) ** 2 + y ** 2) / (2 * y)
        disc_x, disc_y = self._to_disc(complex(t, 2 * r))

        # Handle case when closest point is at disc center
        if math.hypot(disc_x, disc_y) < 1e-6:
            ideal_x, ideal_y = self._to_disc(complex(t, 0))
            theta = math.atan2(ideal_y, ideal_x)
            disc_x = 1e-6 * math.cos(theta)
            disc_y = 1e-6 * math.sin(theta)

        pt = poincare.Point.from_euclid(disc_x, disc_y)
        return poincare.Horocycle.from_closest_point(pt)

    def _build_horizontal_horocycle_params(self, height: float) -> tuple:
        """
        Compute parameters for a horizontal horocycle at y = height.

        Returns (d, cy, r) where:
        - d: disc y-coordinate of point (0, height)
        - cy: center y-coordinate of the horocycle circle
        - r: radius of the horocycle circle

        The horocycle is always tangent to (0, 1) - the image of infinity.
        """
        # Map (0, height) to disc
        _, d = self._to_disc(complex(0, height))
        # Horocycle tangent to (0, 1) passing through (0, d):
        # Center at (0, cy), radius r = 1 - cy
        # |d - cy| = r  =>  cy - d = 1 - cy  =>  cy = (1 + d) / 2
        cy = (1 + d) / 2
        r = (1 - d) / 2
        return d, cy, r

    def _render_horizontal_horocycle(self, elem: 'HorizontalHorocycleElement') -> tuple:
        """
        Render a horizontal horocycle with optional hyperbolic width.

        For hwidth: creates two concentric horocycles and fills between them.
        """
        d, cy, r = self._build_horizontal_horocycle_params(elem.height)

        if elem.hwidth is None:
            # Simple circle, no hwidth
            return (draw.Circle(0, cy, r, **elem.style),)

        # With hwidth: create inner and outer horocycles
        # The "radial" hyperbolic distance from disc center to point (0, d)
        # h_dist = 2 * atanh(|d|), but we need signed distance
        # For points with d > 0: closer to top (infinity)
        # For points with d < 0: closer to bottom

        hwidth = float(elem.hwidth)

        # Hyperbolic distance from origin to the horocycle (at closest point)
        # The closest point on the horocycle to origin is at (0, d)
        # But we need the distance along the geodesic toward infinity
        # Actually, for horocycles, we measure distance perpendicular to the horocycle

        # Simpler approach: offset the horocycle by adjusting d
        # Inner horocycle: passes through point closer to infinity
        # Outer horocycle: passes through point farther from infinity

        # Convert d to hyperbolic distance, offset, convert back
        # h = 2 * atanh(d) for d in (-1, 1)
        # But atanh is only defined for |d| < 1

        # For horizontal horocycles, hyperbolic distance from y=1 to y=h in UHP is log(h)
        # So we can offset by hwidth/2 in this log scale
        h = elem.height
        h_inner = h * math.exp(hwidth / 2)
        h_outer = h * math.exp(-hwidth / 2)

        _, cy_inner, r_inner = self._build_horizontal_horocycle_params(h_inner)
        _, cy_outer, r_outer = self._build_horizontal_horocycle_params(h_outer)

        # Create path that goes around outer circle, then inner circle (reversed)
        path = draw.Path(**elem.style)

        # Outer circle (counterclockwise)
        path.M(r_outer, cy_outer)
        path.A(r_outer, r_outer, 0, True, True, -r_outer, cy_outer)
        path.A(r_outer, r_outer, 0, True, True, r_outer, cy_outer)

        # Inner circle (clockwise to create hole)
        path.M(r_inner, cy_inner)
        path.A(r_inner, r_inner, 0, True, False, -r_inner, cy_inner)
        path.A(r_inner, r_inner, 0, True, False, r_inner, cy_inner)

        path.Z()

        return (path,)

    def _render_horocycle_tile(self, elem: 'HorocycleTileElement') -> tuple:
        """
        Render a quadrilateral tile with horocycle (top/bottom) and geodesic (left/right) edges.
        """
        x_left, x_right = elem.x_left, elem.x_right
        y_bottom, y_top = elem.y_bottom, elem.y_top

        # Get the 4 corners in disc coordinates
        bl = self._to_disc(complex(x_left, y_bottom))   # bottom-left
        br = self._to_disc(complex(x_right, y_bottom))  # bottom-right
        tr = self._to_disc(complex(x_right, y_top))     # top-right
        tl = self._to_disc(complex(x_left, y_top))      # top-left

        # Get horocycle parameters for bottom and top edges
        _, cy_bottom, r_bottom = self._build_horizontal_horocycle_params(y_bottom)
        _, cy_top, r_top = self._build_horizontal_horocycle_params(y_top)

        # Get geodesic parameters for left and right edges
        # Vertical geodesic at x = x0 passes through (x0, 0) and infinity
        # In disc: boundary point and (0, 1)
        left_geodesic = self._compute_vertical_geodesic_circle(x_left)
        right_geodesic = self._compute_vertical_geodesic_circle(x_right)

        # Build the path
        path = draw.Path(**elem.style)

        # Start at bottom-left
        path.M(bl[0], bl[1])

        # Bottom edge: horocycle arc from bl to br (going right)
        self._add_horocycle_arc(path, bl, br, cy_bottom, r_bottom)

        # Right edge: geodesic arc from br to tr (going up)
        self._add_geodesic_arc(path, br, tr, right_geodesic)

        # Top edge: horocycle arc from tr to tl (going left)
        self._add_horocycle_arc(path, tr, tl, cy_top, r_top)

        # Left edge: geodesic arc from tl to bl (going down)
        self._add_geodesic_arc(path, tl, bl, left_geodesic)

        path.Z()

        return (path,)

    def _compute_vertical_geodesic_circle(self, x0: float) -> tuple:
        """
        Compute the circle parameters for a vertical geodesic at x = x0 in UHP.

        Returns (cx, cy, r) for the circle in disc coordinates.
        Returns None if the geodesic is a diameter (x0 = 0).
        """
        # Vertical geodesic connects (x0, 0) on real axis to infinity
        # In disc: boundary point b and top (0, 1)
        b = self._to_disc(complex(x0, 1e-10))  # approximate boundary point
        top = (0.0, 1.0)

        # If x0 = 0, the geodesic is a diameter (straight line)
        if abs(x0) < 1e-10:
            return None  # Diameter case

        # Find circle through b and top, orthogonal to unit circle
        # Circle center is at (cx, 0) for vertical geodesics through (0, 1)
        # Actually, for geodesics through (0, 1), the center lies on the line
        # perpendicular to the chord from b to (0, 1)

        bx, by = b
        # Midpoint of chord
        mx, my = (bx + 0) / 2, (by + 1) / 2

        # For a circle orthogonal to unit disc: cx^2 + cy^2 = 1 + r^2
        # Circle passes through (bx, by) and (0, 1)
        # (bx - cx)^2 + (by - cy)^2 = r^2
        # (0 - cx)^2 + (1 - cy)^2 = r^2

        # From these: bx^2 - 2*bx*cx + by^2 - 2*by*cy = -2*cx + 1 - 2*cy
        # bx^2 + by^2 - 2*bx*cx - 2*by*cy = 1 - 2*cx - 2*cy
        # Since (bx, by) is on unit circle: bx^2 + by^2 = 1
        # 1 - 2*bx*cx - 2*by*cy = 1 - 2*cx - 2*cy
        # -2*bx*cx - 2*by*cy = -2*cx - 2*cy
        # cx*(1 - bx) + cy*(1 - by) = 0
        # cy = -cx * (1 - bx) / (1 - by)

        # Also, orthogonality: cx^2 + cy^2 = 1 + r^2
        # And r^2 = cx^2 + (1 - cy)^2

        # Let's solve: cy = -cx * (1 - bx) / (1 - by) = cx * (bx - 1) / (1 - by)
        # r^2 = cx^2 + (1 - cy)^2
        # cx^2 + cy^2 = 1 + r^2 = 1 + cx^2 + (1 - cy)^2
        # cy^2 = 1 + 1 - 2*cy + cy^2
        # 0 = 2 - 2*cy
        # cy = 1  ... but this can't be right for all cases

        # Let me use a different approach: use the library
        line = poincare.Line.from_points(bx, by, 0, 1, segment=True)
        shape = line.proj_shape  # This is the underlying circle/line

        if hasattr(shape, 'cx'):
            return (shape.cx, shape.cy, shape.r)
        else:
            return None  # It's a straight line (diameter)

    def _add_horocycle_arc(self, path, p1: tuple, p2: tuple, cy: float, r: float):
        """Add a horocycle arc from p1 to p2 on circle centered at (0, cy) with radius r."""
        x1, y1 = p1
        x2, y2 = p2

        # Compute angles
        theta1 = math.atan2(y1 - cy, x1)
        theta2 = math.atan2(y2 - cy, x2)

        # Determine arc direction (we want the shorter arc on the correct side)
        # For horocycles tangent to top, we go along the bottom of the circle
        dtheta = theta2 - theta1
        while dtheta > math.pi:
            dtheta -= 2 * math.pi
        while dtheta < -math.pi:
            dtheta += 2 * math.pi

        large_arc = 1 if abs(dtheta) > math.pi else 0
        sweep = 1 if dtheta > 0 else 0

        path.A(r, r, 0, large_arc, sweep, x2, y2)

    def _add_geodesic_arc(self, path, p1: tuple, p2: tuple, geodesic_circle: tuple):
        """Add a geodesic arc from p1 to p2 along the geodesic circle."""
        x1, y1 = p1
        x2, y2 = p2

        if geodesic_circle is None:
            # Diameter case - straight line
            path.L(x2, y2)
            return

        cx, cy, r = geodesic_circle

        # Compute angles
        theta1 = math.atan2(y1 - cy, x1 - cx)
        theta2 = math.atan2(y2 - cy, x2 - cx)

        dtheta = theta2 - theta1
        while dtheta > math.pi:
            dtheta -= 2 * math.pi
        while dtheta < -math.pi:
            dtheta += 2 * math.pi

        large_arc = 1 if abs(dtheta) > math.pi else 0
        sweep = 1 if dtheta > 0 else 0

        path.A(r, r, 0, large_arc, sweep, x2, y2)

    def _build_ray(self, start: complex, toward_ideal: Union[float, complex]) -> poincare.Line:
        """Build a geodesic ray from start toward an ideal point."""
        x1, y1 = self._to_disc(start)

        if toward_ideal == float('inf'):
            x2, y2 = 0, 1  # Top of disc (infinity in UHP)
        else:
            t = float(toward_ideal.real if isinstance(toward_ideal, complex) else toward_ideal)
            x2, y2 = self._to_disc(complex(t, 0))

        return poincare.Line.from_points(x1, y1, x2, y2, segment=True)

    # -------------------------------------------------------------------------
    # RENDERING
    # -------------------------------------------------------------------------

    def render(self, width: float = 400, height: float = 400,
               background: Optional[str] = None,
               boundary: bool = True,
               boundary_style: Optional[dict] = None) -> draw.Drawing:
        """
        Render the scene to an SVG Drawing in Poincare disc model.

        Args:
            width, height: SVG dimensions in pixels
            background: Background color (e.g., 'white')
            boundary: If True, draw the unit circle boundary
            boundary_style: Styling for boundary
        """
        margin = 0.1
        d = draw.Drawing(width, height)
        d.set_pixel_scale(1)
        d.view_box = (-1-margin, -1-margin, 2+2*margin, 2+2*margin)

        g = draw.Group(transform='scale(1, -1)')

        if background:
            g.append(draw.Rectangle(-1-margin, -1-margin, 2+2*margin, 2+2*margin, fill=background))

        clip = draw.ClipPath(id='disc-clip')
        clip.append(draw.Circle(0, 0, 1))
        d.append(clip)

        content = draw.Group(clip_path='url(#disc-clip)')

        if boundary:
            bstyle = boundary_style or {'stroke': 'gray', 'stroke_width': 0.01, 'fill': 'none'}
            content.append(draw.Circle(0, 0, 1, **bstyle))

        for elem in self.elements:
            for drawable in self._element_to_drawables(elem):
                content.append(drawable)

        g.append(content)
        d.append(g)
        return d

    def render_uhp(self, width: float = 400, height: float = 400,
                   x_min: float = -5, x_max: float = 5,
                   y_min: float = 0.01, y_max: float = 10,
                   background: Optional[str] = None,
                   boundary: bool = True,
                   boundary_style: Optional[dict] = None,
                   log_scale: bool = False) -> draw.Drawing:
        """
        Render the scene to an SVG Drawing in Upper Half-Plane model.

        Args:
            width, height: SVG dimensions in pixels
            x_min, x_max: horizontal extent of viewport
            y_min, y_max: vertical extent of viewport (y > 0)
            background: Background color (e.g., 'white')
            boundary: If True, draw the real axis (boundary)
            boundary_style: Styling for boundary line
            log_scale: If True, use logarithmic y-axis (recommended for self-similar tilings)
        """
        d = draw.Drawing(width, height)
        d.set_pixel_scale(1)

        if log_scale:
            # Transform: x stays same, y -> log(y)
            # Viewport in log space
            log_y_min = math.log(y_min)
            log_y_max = math.log(y_max)
            d.view_box = (x_min, log_y_min, x_max - x_min, log_y_max - log_y_min)
        else:
            d.view_box = (x_min, y_min, x_max - x_min, y_max - y_min)

        # Flip y-axis so y increases upward
        g = draw.Group(transform=f'translate(0, {d.view_box[1] + d.view_box[3]}) scale(1, -1)')

        if background:
            g.append(draw.Rectangle(d.view_box[0], d.view_box[1],
                                    d.view_box[2], d.view_box[3], fill=background))

        # Clip to viewport
        clip = draw.ClipPath(id='uhp-clip')
        clip.append(draw.Rectangle(d.view_box[0], d.view_box[1],
                                   d.view_box[2], d.view_box[3]))
        d.append(clip)

        content = draw.Group(clip_path='url(#uhp-clip)')

        if boundary:
            # Draw real axis (y = 0 line, or log(y) = -inf, so at bottom of viewport)
            bstyle = boundary_style or {'stroke': 'gray', 'stroke_width': 0.02, 'fill': 'none'}
            if log_scale:
                content.append(draw.Line(x_min, log_y_min, x_max, log_y_min, **bstyle))
            else:
                content.append(draw.Line(x_min, 0, x_max, 0, **bstyle))

        for elem in self.elements:
            for drawable in self._element_to_drawables_uhp(elem, log_scale, x_min, x_max, y_min, y_max):
                content.append(drawable)

        g.append(content)
        d.append(g)
        return d

    def _element_to_drawables_uhp(self, elem: SceneElement, log_scale: bool,
                                   x_min: float, x_max: float,
                                   y_min: float, y_max: float) -> tuple:
        """Convert a scene element to drawable objects in UHP coordinates."""

        if isinstance(elem, HorizontalHorocycleElement):
            return self._render_horizontal_horocycle_uhp(elem, log_scale, x_min, x_max)

        elif isinstance(elem, HorocycleTileElement):
            return self._render_horocycle_tile_uhp(elem, log_scale)

        elif isinstance(elem, RayElement):
            return self._render_ray_uhp(elem, log_scale, y_min, y_max)

        elif isinstance(elem, PointElement):
            return self._render_point_uhp(elem, log_scale)

        elif isinstance(elem, SegmentElement):
            return self._render_segment_uhp(elem, log_scale)

        elif isinstance(elem, PolygonElement):
            return self._render_polygon_uhp(elem, log_scale)

        else:
            # Skip unsupported elements in UHP view
            return ()

    def _render_horizontal_horocycle_uhp(self, elem: 'HorizontalHorocycleElement',
                                          log_scale: bool, x_min: float, x_max: float) -> tuple:
        """Render horizontal horocycle in UHP (horizontal strip)."""
        h = elem.height

        if elem.hwidth is None:
            # Simple line
            if log_scale:
                y = math.log(h)
                return (draw.Line(x_min, y, x_max, y, **elem.style),)
            else:
                return (draw.Line(x_min, h, x_max, h, **elem.style),)

        # With hwidth: horizontal strip
        hwidth = float(elem.hwidth)
        h_top = h * math.exp(hwidth / 2)
        h_bottom = h * math.exp(-hwidth / 2)

        if log_scale:
            y_top = math.log(h_top)
            y_bottom = math.log(h_bottom)
            rect = draw.Rectangle(x_min, y_bottom, x_max - x_min, y_top - y_bottom, **elem.style)
        else:
            rect = draw.Rectangle(x_min, h_bottom, x_max - x_min, h_top - h_bottom, **elem.style)

        return (rect,)

    def _render_horocycle_tile_uhp(self, elem: 'HorocycleTileElement', log_scale: bool) -> tuple:
        """Render horocycle tile in UHP (rectangle)."""
        x_left, x_right = elem.x_left, elem.x_right
        y_bottom, y_top = elem.y_bottom, elem.y_top

        if log_scale:
            log_y_bottom = math.log(y_bottom)
            log_y_top = math.log(y_top)
            rect = draw.Rectangle(x_left, log_y_bottom,
                                  x_right - x_left, log_y_top - log_y_bottom,
                                  **elem.style)
        else:
            rect = draw.Rectangle(x_left, y_bottom,
                                  x_right - x_left, y_top - y_bottom,
                                  **elem.style)

        return (rect,)

    def _render_ray_uhp(self, elem: 'RayElement', log_scale: bool,
                        y_min: float, y_max: float) -> tuple:
        """Render ray in UHP (vertical line or wedge with hwidth)."""
        start = elem.start
        x0 = start.real
        y0 = start.imag

        # Ray goes from start toward ideal point (on real axis or infinity)
        if elem.toward_ideal == float('inf'):
            # Ray going up (toward infinity)
            x_end = x0
            y_end = y_max * 2  # extend beyond viewport
        else:
            # Ray going down toward ideal point on real axis
            x_end = float(elem.toward_ideal.real if isinstance(elem.toward_ideal, complex) else elem.toward_ideal)
            y_end = y_min / 2  # extend beyond viewport

        if elem.hwidth is None:
            # Simple line
            if log_scale:
                return (draw.Line(x0, math.log(y0), x_end, math.log(max(y_end, 1e-10)), **elem.style),)
            else:
                return (draw.Line(x0, y0, x_end, y_end, **elem.style),)

        # With hwidth: wedge shape
        # For vertical geodesic at x = x0, hyperbolic width w at height y
        # corresponds to Euclidean width w * y
        hwidth = float(elem.hwidth)
        half_w = hwidth / 2

        if elem.toward_ideal == float('inf'):
            # Wedge going up - gets wider
            if log_scale:
                # In log scale, the wedge edges are curves, but approximate with polygon
                path = draw.Path(**elem.style)
                y_start = y0
                y_stop = y_max * 2
                # Sample points along the wedge
                n_points = 50
                for i in range(n_points + 1):
                    t = i / n_points
                    y = y_start * ((y_stop / y_start) ** t)
                    x_offset = half_w * y
                    log_y = math.log(y)
                    if i == 0:
                        path.M(x0 - x_offset, log_y)
                    else:
                        path.L(x0 - x_offset, log_y)
                for i in range(n_points, -1, -1):
                    t = i / n_points
                    y = y_start * ((y_stop / y_start) ** t)
                    x_offset = half_w * y
                    log_y = math.log(y)
                    path.L(x0 + x_offset, log_y)
                path.Z()
                return (path,)
            else:
                # Linear wedge
                path = draw.Path(**elem.style)
                path.M(x0 - half_w * y0, y0)
                path.L(x0 - half_w * y_end, y_end)
                path.L(x0 + half_w * y_end, y_end)
                path.L(x0 + half_w * y0, y0)
                path.Z()
                return (path,)
        else:
            # Wedge going down toward ideal point - gets narrower
            ideal_x = float(elem.toward_ideal.real if isinstance(elem.toward_ideal, complex) else elem.toward_ideal)

            if log_scale:
                path = draw.Path(**elem.style)
                y_start = y0
                y_stop = max(y_min / 2, 1e-6)
                n_points = 50
                for i in range(n_points + 1):
                    t = i / n_points
                    y = y_start * ((y_stop / y_start) ** t)
                    x_offset = half_w * y
                    log_y = math.log(max(y, 1e-10))
                    if i == 0:
                        path.M(x0 - x_offset, log_y)
                    else:
                        path.L(ideal_x - x_offset, log_y)
                for i in range(n_points, -1, -1):
                    t = i / n_points
                    y = y_start * ((y_stop / y_start) ** t)
                    x_offset = half_w * y
                    log_y = math.log(max(y, 1e-10))
                    path.L(ideal_x + x_offset, log_y)
                path.Z()
                return (path,)
            else:
                path = draw.Path(**elem.style)
                path.M(x0 - half_w * y0, y0)
                path.L(ideal_x, 0)  # converges to ideal point
                path.L(x0 + half_w * y0, y0)
                path.Z()
                return (path,)

    def _render_point_uhp(self, elem: 'PointElement', log_scale: bool) -> tuple:
        """Render point in UHP."""
        x, y = elem.z.real, elem.z.imag
        r = elem.radius

        if log_scale:
            return (draw.Circle(x, math.log(y), r, **elem.style),)
        else:
            return (draw.Circle(x, y, r, **elem.style),)

    def _render_segment_uhp(self, elem: 'SegmentElement', log_scale: bool) -> tuple:
        """Render geodesic segment in UHP."""
        z1, z2 = elem.z1, elem.z2
        x1, y1 = z1.real, z1.imag
        x2, y2 = z2.real, z2.imag

        # In UHP, geodesics are either vertical lines or semicircles
        if abs(x1 - x2) < 1e-10:
            # Vertical geodesic
            if log_scale:
                return (draw.Line(x1, math.log(y1), x2, math.log(y2), **elem.style),)
            else:
                return (draw.Line(x1, y1, x2, y2, **elem.style),)
        else:
            # Semicircle geodesic - center on real axis
            # Circle through (x1, y1) and (x2, y2) with center on x-axis
            # Center: (cx, 0), radius r
            # (x1 - cx)^2 + y1^2 = r^2
            # (x2 - cx)^2 + y2^2 = r^2
            # Solving: cx = ((x1^2 + y1^2) - (x2^2 + y2^2)) / (2*(x1 - x2))
            cx = ((x1**2 + y1**2) - (x2**2 + y2**2)) / (2 * (x1 - x2))
            r = math.sqrt((x1 - cx)**2 + y1**2)

            if log_scale:
                # Arc in log scale is complex - approximate with polyline
                path = draw.Path(**elem.style)
                theta1 = math.atan2(y1, x1 - cx)
                theta2 = math.atan2(y2, x2 - cx)
                if theta1 > theta2:
                    theta1, theta2 = theta2, theta1
                n_points = 30
                for i in range(n_points + 1):
                    theta = theta1 + (theta2 - theta1) * i / n_points
                    x = cx + r * math.cos(theta)
                    y = r * math.sin(theta)
                    if y > 0:
                        if i == 0:
                            path.M(x, math.log(y))
                        else:
                            path.L(x, math.log(y))
                return (path,)
            else:
                # SVG arc
                theta1 = math.atan2(y1, x1 - cx)
                theta2 = math.atan2(y2, x2 - cx)
                dtheta = theta2 - theta1
                large_arc = 0
                sweep = 1 if dtheta > 0 else 0
                path = draw.Path(**elem.style)
                path.M(x1, y1)
                path.A(r, r, 0, large_arc, sweep, x2, y2)
                return (path,)

    def _render_polygon_uhp(self, elem: 'PolygonElement', log_scale: bool) -> tuple:
        """Render polygon in UHP (geodesic edges)."""
        vertices = elem.vertices
        if len(vertices) < 3:
            return ()

        # For simplicity, draw as polyline connecting vertices
        # (This ignores the geodesic curvature - for proper rendering would need arcs)
        path = draw.Path(**elem.style)
        for i, v in enumerate(vertices):
            x, y = v.real, v.imag
            if log_scale:
                y = math.log(y) if y > 0 else -10
            if i == 0:
                path.M(x, y)
            else:
                path.L(x, y)
        path.Z()
        return (path,)

    def _element_to_drawables(self, elem: SceneElement) -> tuple:
        """Convert a scene element to drawable objects."""
        if isinstance(elem, PointElement):
            pt = self._build_point(elem.z)
            return pt.to_drawables(radius=elem.radius, hradius=elem.hradius, **elem.style)

        elif isinstance(elem, SegmentElement):
            line = self._build_line(elem.z1, elem.z2, segment=True)
            return line.to_drawables(hwidth=elem.hwidth, **elem.style)

        elif isinstance(elem, GeodesicElement):
            line = self._build_line(elem.z1, elem.z2, segment=False)
            return line.to_drawables(hwidth=elem.hwidth, **elem.style)

        elif isinstance(elem, PolygonElement):
            poly = self._build_polygon(elem.vertices)
            return poly.to_drawables(hwidth=elem.hwidth, **elem.style)

        elif isinstance(elem, PolylineElement):
            return self._build_polyline_drawables(elem)

        elif isinstance(elem, CircleElement):
            circle = self._build_circle(elem.center, elem.hradius)
            return circle.to_drawables(hwidth=elem.hwidth, **elem.style)

        elif isinstance(elem, HorocycleTangentElement):
            horo = self._build_horocycle(elem.tangent_point, elem.through_point)
            return horo.to_drawables(hwidth=elem.hwidth, **elem.style)

        elif isinstance(elem, HorizontalHorocycleElement):
            return self._render_horizontal_horocycle(elem)

        elif isinstance(elem, HorocycleTileElement):
            return self._render_horocycle_tile(elem)

        elif isinstance(elem, RayElement):
            ray = self._build_ray(elem.start, elem.toward_ideal)
            return ray.to_drawables(hwidth=elem.hwidth, **elem.style)

        else:
            raise ValueError(f"Unknown element type: {type(elem)}")


# =============================================================================
# POLYGON FACTORY
# =============================================================================

def make_hyperbolic_polygon_from_params(N: int = 5, a: float = 0.55) -> List[complex]:
    """
    Create polygon vertices from SDF definition.

    m = N - 3
    Bottom chain: (k*a, 1) for k = 0..m
    Top right: (m*a, m)
    Top left: (0, m)

    Returns vertices in counterclockwise order as complex numbers.
    """
    if N < 5:
        raise ValueError("N must be >= 5")

    m = N - 3
    vertices = [complex(k * a, 1) for k in range(m + 1)]
    vertices.append(complex(m * a, m))
    vertices.append(complex(0, m))
    return vertices


# =============================================================================
# VERIFICATION
# =============================================================================

def verify_transformations():
    """Verify UHP -> disc transformation."""
    transform = get_uhp_to_disc_transform()

    test_cases = [
        (1j, (0, 0)),
        (0, (0, -1)),
        (1, (1, 0)),
        (-1, (-1, 0)),
    ]

    print("Verifying UHP -> disc transformation:")
    for uhp_pt, expected_disc in test_cases:
        z = uhp_pt if isinstance(uhp_pt, complex) else complex(uhp_pt, 0)
        result = transform.apply_to_tuple((z.real, z.imag))
        match = abs(result[0] - expected_disc[0]) < 1e-10 and abs(result[1] - expected_disc[1]) < 1e-10
        print(f"  {uhp_pt} -> ({result[0]:.6f}, {result[1]:.6f}), expected {expected_disc}, match: {match}")


if __name__ == '__main__':
    verify_transformations()
