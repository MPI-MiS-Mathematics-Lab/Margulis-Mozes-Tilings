import * as THREE from "three";
import { OrbitControls } from "three/addons/controls/OrbitControls.js";


const DEFAULT_FIELD_LABELS = {
  curveDistance: "Curve Heat Distance",
  curveDistanceHybrid: "Curve Hybrid Distance",
  signedCurveDistance: "Signed Curve Distance"
};

const APP = document.getElementById("app");
const fieldSelect = document.getElementById("field-select");
const overlayOpacity = document.getElementById("overlay-opacity");
const showCenterline = document.getElementById("show-centerline");
const showIsolines = document.getElementById("show-isolines");
const showText = document.getElementById("show-text");
const wireframe = document.getElementById("wireframe");
const flatShading = document.getElementById("flat-shading");
const summary = document.getElementById("summary");

const sceneData = await fetch("/api/scene").then((response) => {
  if (!response.ok) {
    throw new Error(`Failed to load scene: ${response.status}`);
  }
  return response.json();
});
const fieldLabels = sceneData.fieldLabels || DEFAULT_FIELD_LABELS;
const divergingFields = new Set(sceneData.divergingFields || ["signedCurveDistance"]);

document.title = sceneData.solverName
  ? `${sceneData.solverName} - ${sceneData.name}`
  : "Stanford Bunny Curve Typography";

const positions = new Float32Array(sceneData.positions);
const faces = new Uint32Array(sceneData.faces);
const vertexNormals = sceneData.vertexNormals ? new Float32Array(sceneData.vertexNormals) : null;
const centerlinePositions = new Float32Array(sceneData.centerlinePositions);
const chartU = new Float32Array(sceneData.chartU);
const chartV = new Float32Array(sceneData.chartV);
const fields = Object.fromEntries(
  Object.entries(sceneData.fields).map(([name, values]) => [name, new Float32Array(values)])
);

for (const [value, label] of Object.entries(fieldLabels)) {
  const option = document.createElement("option");
  option.value = value;
  option.textContent = label;
  fieldSelect.appendChild(option);
}
const availableFieldKeys = Object.keys(fieldLabels);
fieldSelect.value = availableFieldKeys.includes(sceneData.defaultField)
  ? sceneData.defaultField
  : availableFieldKeys[0];

const renderer = new THREE.WebGLRenderer({ antialias: true, powerPreference: "high-performance" });
renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
renderer.setSize(window.innerWidth, window.innerHeight);
renderer.outputColorSpace = THREE.SRGBColorSpace;
APP.appendChild(renderer.domElement);

const maxTextureSize = renderer.capabilities.maxTextureSize || 4096;
const textTextureWidth = Math.min(4096, maxTextureSize);
const textTextureHeight = Math.max(320, Math.min(Math.round(textTextureWidth * (320 / 2048)), maxTextureSize));
const textTextureAnisotropy = renderer.capabilities.getMaxAnisotropy
  ? Math.max(1, Math.min(renderer.capabilities.getMaxAnisotropy(), 8))
  : 1;

const scene = new THREE.Scene();
scene.background = new THREE.Color(0xf3f1ea);

const camera = new THREE.PerspectiveCamera(45, window.innerWidth / window.innerHeight, 0.01, 100.0);

const controls = new OrbitControls(camera, renderer.domElement);
controls.enableDamping = true;

const keyLight = new THREE.DirectionalLight(0xffffff, 2.2);
keyLight.position.set(3.0, 4.5, 5.0);
scene.add(keyLight);

const fillLight = new THREE.DirectionalLight(0xffffff, 1.1);
fillLight.position.set(-4.0, 3.0, 2.0);
scene.add(fillLight);

scene.add(new THREE.AmbientLight(0xffffff, 0.45));

const geometry = new THREE.BufferGeometry();
geometry.setAttribute("position", new THREE.BufferAttribute(positions, 3));
geometry.setIndex(new THREE.BufferAttribute(faces, 1));

const uvBuffer = new Float32Array(chartU.length * 2);
for (let i = 0; i < chartU.length; i++) {
  uvBuffer[2 * i] = chartU[i];
  uvBuffer[2 * i + 1] = chartV[i];
}
geometry.setAttribute("uv", new THREE.BufferAttribute(uvBuffer, 2));

const colorBuffer = new Float32Array(chartU.length * 3);
geometry.setAttribute("color", new THREE.BufferAttribute(colorBuffer, 3));
geometry.computeVertexNormals();
geometry.computeBoundingSphere();

const bounds = geometry.boundingSphere;
const sceneRadius = Math.max(bounds?.radius || 1.0, 1e-3);
const sceneCenter = bounds?.center ? bounds.center.clone() : new THREE.Vector3();
const viewDirection = new THREE.Vector3(0.85, 0.7, 1.45).normalize();
const cameraDistance = Math.max(sceneRadius * 3.15, 0.45);
camera.position.copy(sceneCenter.clone().addScaledVector(viewDirection, cameraDistance));
camera.near = Math.max(sceneRadius / 200.0, 0.001);
camera.far = Math.max(sceneRadius * 40.0, 20.0);
camera.updateProjectionMatrix();
controls.target.copy(sceneCenter);
controls.update();

const meshMaterial = new THREE.MeshStandardMaterial({
  vertexColors: true,
  side: THREE.DoubleSide,
  roughness: 0.58,
  metalness: 0.05
});

const mesh = new THREE.Mesh(geometry, meshMaterial);
scene.add(mesh);

const textTexture = await buildTextTexture(sceneData);
textTexture.wrapS = THREE.ClampToEdgeWrapping;
textTexture.wrapT = THREE.ClampToEdgeWrapping;
textTexture.colorSpace = THREE.SRGBColorSpace;
textTexture.anisotropy = textTextureAnisotropy;
textTexture.generateMipmaps = false;
textTexture.minFilter = THREE.LinearFilter;
textTexture.magFilter = THREE.LinearFilter;
textTexture.needsUpdate = true;

const textGeometry = buildTextOverlayGeometry(positions, faces, chartU, chartV, sceneData) || geometry;

const textMaterial = new THREE.MeshBasicMaterial({
  map: textTexture,
  transparent: true,
  alphaTest: 0.18,
  depthWrite: false,
  side: THREE.DoubleSide,
  polygonOffset: true,
  polygonOffsetFactor: -1,
  polygonOffsetUnits: -2,
  opacity: Number(overlayOpacity.value)
});

const textMesh = new THREE.Mesh(textGeometry, textMaterial);
scene.add(textMesh);

const centerlineGeometry = new THREE.BufferGeometry();
centerlineGeometry.setAttribute("position", new THREE.BufferAttribute(centerlinePositions, 3));
const centerline = new THREE.Line(
  centerlineGeometry,
  new THREE.LineBasicMaterial({ color: 0x10243d, linewidth: 2 })
);
scene.add(centerline);

let isolines = null;

updateField(fieldSelect.value);
rebuildIsolines(fieldSelect.value);
updateSummary(fieldSelect.value);

fieldSelect.addEventListener("change", () => {
  updateField(fieldSelect.value);
  rebuildIsolines(fieldSelect.value);
  updateSummary(fieldSelect.value);
});

overlayOpacity.addEventListener("input", () => {
  textMaterial.opacity = Number(overlayOpacity.value);
});

showCenterline.addEventListener("change", () => {
  centerline.visible = showCenterline.checked;
});

showIsolines.addEventListener("change", () => {
  if (isolines) {
    isolines.visible = showIsolines.checked;
  }
});

showText.addEventListener("change", () => {
  textMesh.visible = showText.checked;
});

wireframe.addEventListener("change", () => {
  meshMaterial.wireframe = wireframe.checked;
});

flatShading.addEventListener("change", () => {
  meshMaterial.flatShading = flatShading.checked;
  meshMaterial.needsUpdate = true;
});

window.addEventListener("resize", onResize);

renderer.setAnimationLoop(() => {
  controls.update();
  renderer.render(scene, camera);
});


function onResize() {
  camera.aspect = window.innerWidth / window.innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(window.innerWidth, window.innerHeight);
}


function updateField(fieldName) {
  const values = fields[fieldName];
  const range = sceneData.ranges[fieldName];
  const diverging = divergingFields.has(fieldName);
  const [minValue, maxValue] = diverging
    ? symmetricRange(range)
    : range;

  for (let i = 0; i < values.length; i++) {
    const c = diverging
      ? sampleDivergingColor(values[i], maxValue)
      : sampleSequentialColor(values[i], minValue, maxValue);
    colorBuffer[3 * i] = c.r;
    colorBuffer[3 * i + 1] = c.g;
    colorBuffer[3 * i + 2] = c.b;
  }

  geometry.attributes.color.needsUpdate = true;
}


function updateSummary(fieldName) {
  const range = sceneData.ranges[fieldName];
  const sourceVertices = sceneData.summary.sourceVertices;
  const sourceGapMedian = sceneData.summary.sourceGapMedian;
  const hybridBlendInner = sceneData.summary.hybridBlendInner;
  const hybridBlendOuter = sceneData.summary.hybridBlendOuter;
  summary.innerHTML =
    `<strong>${fieldLabels[fieldName] || fieldName}</strong><br>` +
    `${sceneData.solverName ? `${sceneData.solverName}<br>` : ""}` +
    `Vertices: ${sceneData.summary.nVertices.toLocaleString()} · ` +
    `Faces: ${sceneData.summary.nFaces.toLocaleString()}<br>` +
    `Range: ${range[0].toFixed(4)} to ${range[1].toFixed(4)}` +
    (Number.isFinite(sourceVertices)
      ? `<br>Centerline vertices: ${sceneData.summary.curveVertices.toLocaleString()} · ` +
        `Heat sources: ${sourceVertices.toLocaleString()}`
      : "") +
    (Number.isFinite(sourceGapMedian)
      ? `<br>Median source gap: ${sourceGapMedian.toFixed(5)}`
      : "") +
    (Number.isFinite(hybridBlendInner) && Number.isFinite(hybridBlendOuter)
      ? `<br>Hybrid band: ${hybridBlendInner.toFixed(5)} to ${hybridBlendOuter.toFixed(5)}`
      : "");
}


function rebuildIsolines(fieldName) {
  if (isolines) {
    scene.remove(isolines);
    disposeObject3D(isolines);
    isolines = null;
  }
  const chartBand = computeDiagnosticChartBand(sceneData);
  const faceMask = buildChartVFaceMask(faces, chartV, chartBand);
  const overlay = new THREE.Group();
  const offsetAmount = Math.max(sceneRadius * 0.0018, 0.00035);

  const transverseLines = buildIsolineSegments(
    positions,
    vertexNormals,
    faces,
    chartV,
    {
      levels: buildChartVLevels(sceneData, chartBand),
      offsetAmount,
      faceMask,
      opacity: 0.96,
      colorForLevel: (level) => sampleChartVLineColor(level, sceneData.textBand?.vCenter ?? 0.5)
    }
  );
  if (transverseLines) {
    overlay.add(transverseLines);
  }

  const orthogonalLines = buildIsolineSegments(
    positions,
    vertexNormals,
    faces,
    chartU,
    {
      levels: buildChartULevels(),
      offsetAmount: offsetAmount * 1.25,
      faceMask,
      opacity: 0.78,
      colorForLevel: (level) => sampleChartULineColor(level)
    }
  );
  if (orthogonalLines) {
    overlay.add(orthogonalLines);
  }

  isolines = overlay.children.length > 0 ? overlay : null;

  if (!isolines) {
    return;
  }

  isolines.visible = showIsolines.checked;
  scene.add(isolines);
}


function buildChartVLevels(sceneData, chartBand) {
  const center = sceneData.textBand?.vCenter ?? 0.5;
  const offsets = [
    -0.22, -0.20, -0.18, -0.16, -0.14, -0.12, -0.10, -0.08, -0.06, -0.04, -0.02,
     0.00,
     0.02,  0.04,  0.06,  0.08,  0.10,  0.12,  0.14,  0.16,  0.18,  0.20,  0.22
  ];
  const levels = offsets
    .filter((offset) => Math.abs(offset) <= chartBand + 1e-8)
    .map((offset) => Number((center + offset).toFixed(3)));
  return levels;
}


function buildIsolineSegments(positions, vertexNormals, faces, values, options = {}) {
  if (!values) {
    return null;
  }

  const {
    levels = [],
    offsetAmount = 0.0,
    faceMask = null,
    opacity = 0.95,
    colorForLevel = null
  } = options;

  if (!levels.length) {
    return null;
  }

  const segmentPositions = [];
  const segmentColors = [];
  const eps = 1e-8;
  const maxAbsLevel = Math.max(...levels.map((value) => Math.abs(value)), 1e-6);

  for (let faceIndex = 0; faceIndex < faces.length; faceIndex += 3) {
    if (faceMask && !faceMask[faceIndex / 3]) {
      continue;
    }
    const ids = [faces[faceIndex], faces[faceIndex + 1], faces[faceIndex + 2]];
    const triPos = ids.map((id) => new THREE.Vector3(
      positions[3 * id],
      positions[3 * id + 1],
      positions[3 * id + 2]
    ));
    const triNormals = ids.map((id) => {
      if (vertexNormals) {
        return new THREE.Vector3(
          vertexNormals[3 * id],
          vertexNormals[3 * id + 1],
          vertexNormals[3 * id + 2]
        ).normalize();
      }
      const faceNormal = new THREE.Vector3()
        .subVectors(triPos[1], triPos[0])
        .cross(new THREE.Vector3().subVectors(triPos[2], triPos[0]))
        .normalize();
      return faceNormal;
    });
    const triVals = ids.map((id) => values[id]);

    for (const level of levels) {
      const intersections = [];
      appendIsolineIntersection(intersections, triPos, triNormals, triVals, 0, 1, level, eps);
      appendIsolineIntersection(intersections, triPos, triNormals, triVals, 1, 2, level, eps);
      appendIsolineIntersection(intersections, triPos, triNormals, triVals, 2, 0, level, eps);

      const uniqueIntersections = [];
      for (const intersection of intersections) {
        const duplicate = uniqueIntersections.some(
          (other) => other.position.distanceToSquared(intersection.position) <= 1e-12
        );
        if (!duplicate) {
          uniqueIntersections.push(intersection);
        }
      }

      if (uniqueIntersections.length < 2) {
        continue;
      }

      let pointA = uniqueIntersections[0];
      let pointB = uniqueIntersections[1];
      if (uniqueIntersections.length > 2) {
        let bestDist2 = -1.0;
        for (let i = 0; i < uniqueIntersections.length; i++) {
          for (let j = i + 1; j < uniqueIntersections.length; j++) {
            const dist2 = uniqueIntersections[i].position.distanceToSquared(uniqueIntersections[j].position);
            if (dist2 > bestDist2) {
              bestDist2 = dist2;
              pointA = uniqueIntersections[i];
              pointB = uniqueIntersections[j];
            }
          }
        }
      }

      const color = colorForLevel
        ? colorForLevel(level, maxAbsLevel)
        : sampleDivergingColor(level, maxAbsLevel);
      for (const point of [pointA, pointB]) {
        const offsetPosition = point.position.clone().addScaledVector(point.normal, offsetAmount);
        segmentPositions.push(offsetPosition.x, offsetPosition.y, offsetPosition.z);
        segmentColors.push(color.r, color.g, color.b);
      }
    }
  }

  if (segmentPositions.length === 0) {
    return null;
  }

  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute("position", new THREE.Float32BufferAttribute(segmentPositions, 3));
  geometry.setAttribute("color", new THREE.Float32BufferAttribute(segmentColors, 3));
  return new THREE.LineSegments(
    geometry,
    new THREE.LineBasicMaterial({
      vertexColors: true,
      transparent: true,
      opacity
    })
  );
}


function appendIsolineIntersection(out, triPos, triNormals, triVals, ia, ib, level, eps) {
  const valueA = triVals[ia];
  const valueB = triVals[ib];
  const deltaA = valueA - level;
  const deltaB = valueB - level;

  if (Math.abs(deltaA) <= eps && Math.abs(deltaB) <= eps) {
    return;
  }
  if ((deltaA < -eps && deltaB < -eps) || (deltaA > eps && deltaB > eps)) {
    return;
  }
  if (Math.abs(valueB - valueA) <= eps) {
    return;
  }

  const t = clamp01((level - valueA) / (valueB - valueA));
  const position = triPos[ia].clone().lerp(triPos[ib], t);
  const normal = triNormals[ia].clone().lerp(triNormals[ib], t).normalize();
  out.push({ position, normal });
}


function symmetricRange(range) {
  const maxAbs = Math.max(Math.abs(range[0]), Math.abs(range[1]), 1e-6);
  return [-maxAbs, maxAbs];
}


function sampleSequentialColor(value, minValue, maxValue) {
  const t = clamp01((value - minValue) / Math.max(maxValue - minValue, 1e-6));
  const stops = [
    [0.0, new THREE.Color("#132b43")],
    [0.22, new THREE.Color("#176d9c")],
    [0.5, new THREE.Color("#4bc0c8")],
    [0.78, new THREE.Color("#f7d34b")],
    [1.0, new THREE.Color("#c94b2c")]
  ];
  return mixStops(stops, t);
}


function sampleDivergingColor(value, maxAbs) {
  const t = clamp01(0.5 + 0.5 * (value / Math.max(maxAbs, 1e-6)));
  const stops = [
    [0.0, new THREE.Color("#1f4a8a")],
    [0.5, new THREE.Color("#8a8378")],
    [1.0, new THREE.Color("#a53024")]
  ];
  return mixStops(stops, t);
}


function mixStops(stops, t) {
  for (let i = 1; i < stops.length; i++) {
    const [t1, c1] = stops[i];
    const [t0, c0] = stops[i - 1];
    if (t <= t1) {
      const f = (t - t0) / Math.max(t1 - t0, 1e-6);
      return c0.clone().lerp(c1, clamp01(f));
    }
  }
  return stops[stops.length - 1][1].clone();
}


function clamp01(value) {
  return Math.min(1.0, Math.max(0.0, value));
}


function buildChartULevels() {
  return [
    0.01, 0.02, 0.03, 0.04,
    0.06, 0.08, 0.10, 0.12, 0.16, 0.20,
    0.24, 0.28, 0.32, 0.36, 0.40, 0.44,
    0.48, 0.52, 0.56, 0.60, 0.64, 0.68,
    0.72, 0.76, 0.80, 0.84, 0.88, 0.92, 0.96
  ];
}


function computeDiagnosticChartBand(sceneData) {
  const fitHeight = sceneData.textFitHeight ?? 0.05;
  return Math.max(fitHeight * 4.5, 0.18);
}


function buildChartVFaceMask(faces, chartV, chartBand) {
  if (!chartV || !Number.isFinite(chartBand)) {
    return null;
  }

  const center = sceneData.textBand?.vCenter ?? 0.5;
  const minV = center - chartBand;
  const maxV = center + chartBand;
  const faceMask = new Uint8Array(faces.length / 3);
  for (let faceIndex = 0; faceIndex < faces.length; faceIndex += 3) {
    const a = faces[faceIndex];
    const b = faces[faceIndex + 1];
    const c = faces[faceIndex + 2];
    const minValue = Math.min(chartV[a], chartV[b], chartV[c]);
    const maxValue = Math.max(chartV[a], chartV[b], chartV[c]);
    if (maxValue < minV || minValue > maxV) {
      continue;
    }
    faceMask[faceIndex / 3] = 1;
  }
  return faceMask;
}


function sampleChartVLineColor(level, center) {
  if (Math.abs(level - center) <= 1e-6) {
    return new THREE.Color("#cf522c");
  }
  const distance = Math.abs(level - center);
  const t = clamp01(distance / 0.22);
  const stops = [
    [0.0, new THREE.Color("#d26a3d")],
    [0.5, new THREE.Color("#8d5d74")],
    [1.0, new THREE.Color("#345c93")]
  ];
  return mixStops(stops, t);
}


function sampleChartULineColor(level) {
  const majorLine = Math.abs(level * 10.0 - Math.round(level * 10.0)) < 1e-6;
  return new THREE.Color(majorLine ? "#0f6b5d" : "#2f8a76");
}


function disposeObject3D(object) {
  object.traverse((child) => {
    if (child.geometry) {
      child.geometry.dispose();
    }
    if (Array.isArray(child.material)) {
      child.material.forEach((material) => material?.dispose?.());
      return;
    }
    child.material?.dispose?.();
  });
}


function buildTextOverlayGeometry(positions, faces, chartU, chartV, sceneData) {
  const bandCenter = sceneData.textBand?.vCenter ?? 0.5;
  const fitHeight = sceneData.textFitHeight ?? 0.05;
  const bandHalfHeight = Math.max(0.5 * fitHeight * 1.2, 0.02);
  const bandMin = bandCenter - bandHalfHeight;
  const bandMax = bandCenter + bandHalfHeight;
  const minAbsUvArea = 1e-7;
  const textIndices = [];

  for (let faceIndex = 0; faceIndex < faces.length; faceIndex += 3) {
    const a = faces[faceIndex];
    const b = faces[faceIndex + 1];
    const c = faces[faceIndex + 2];
    const vMin = Math.min(chartV[a], chartV[b], chartV[c]);
    const vMax = Math.max(chartV[a], chartV[b], chartV[c]);
    if (vMax < bandMin || vMin > bandMax) {
      continue;
    }

    const du1x = chartU[b] - chartU[a];
    const du1y = chartV[b] - chartV[a];
    const du2x = chartU[c] - chartU[a];
    const du2y = chartV[c] - chartV[a];
    const uvArea = 0.5 * (du1x * du2y - du1y * du2x);
    if (uvArea <= minAbsUvArea) {
      continue;
    }

    textIndices.push(a, b, c);
  }

  if (textIndices.length === 0) {
    return null;
  }

  const textGeometry = new THREE.BufferGeometry();
  textGeometry.setAttribute("position", new THREE.BufferAttribute(positions, 3));
  textGeometry.setAttribute(
    "uv",
    new THREE.BufferAttribute(
      new Float32Array(Array.from(chartU, (u, index) => [u, chartV[index]]).flat()),
      2
    )
  );
  textGeometry.setIndex(textIndices);
  textGeometry.computeVertexNormals();
  return textGeometry;
}


async function buildTextTexture(sceneData) {
  if (sceneData.textOutlineData) {
    return buildOutlineTextTexture(sceneData.textOutlineData, {
      fitWidth: sceneData.textFitWidth,
      fitHeight: sceneData.textFitHeight
    });
  }
  return buildBrowserTextTexture(sceneData.text, {
    fontUrl: sceneData.fontUrl,
    textDirection: sceneData.textDirection,
    textFontFamily: sceneData.textFontFamily,
    textFontStack: sceneData.textFontStack,
    textFontSize: sceneData.textFontSize,
    fitWidth: sceneData.textFitWidth,
    fitHeight: sceneData.textFitHeight
  });
}


async function buildBrowserTextTexture(text, options = {}) {
  const {
    fontUrl,
    textDirection = "ltr",
    textFontFamily = "CMU Heat Demo",
    textFontStack = `'${textFontFamily}', serif`,
    textFontSize = 128,
    fitWidth = 0.94,
    fitHeight = 0.72
  } = options;

  await loadFont(fontUrl, textFontFamily);

  const canvas = document.createElement("canvas");
  canvas.width = textTextureWidth;
  canvas.height = textTextureHeight;
  const ctx = canvas.getContext("2d");

  ctx.clearRect(0, 0, canvas.width, canvas.height);
  ctx.direction = textDirection;
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillStyle = "rgba(92, 255, 113, 0.98)";
  ctx.font = `${textFontSize}px ${textFontStack}`;
  ctx.fillText(text, canvas.width * 0.5, canvas.height * 0.5, canvas.width * fitWidth);

  const texture = new THREE.CanvasTexture(canvas);
  texture.needsUpdate = true;
  return texture;
}


function buildOutlineTextTexture(textOutlineData, options = {}) {
  const {
    fitWidth = 0.94,
    fitHeight = 0.72
  } = options;
  const canvas = document.createElement("canvas");
  canvas.width = textTextureWidth;
  canvas.height = textTextureHeight;
  const ctx = canvas.getContext("2d");

  ctx.clearRect(0, 0, canvas.width, canvas.height);
  ctx.fillStyle = "rgba(92, 255, 113, 0.98)";

  const placedGlyphs = [];
  let penX = 0.0;
  let minX = Infinity;
  let minY = Infinity;
  let maxX = -Infinity;
  let maxY = -Infinity;

  for (const entry of textOutlineData.run || []) {
    const glyph = textOutlineData.glyphs?.[entry.glyphKey];
    const offsetX = penX + (entry.xOffsetEm || 0.0);
    const offsetY = entry.yOffsetEm || 0.0;

    if (glyph && glyph.segments && glyph.segments.length > 0) {
      const bounds = glyph.sampleBounds || [0, 0, 0, 0];
      minX = Math.min(minX, offsetX + bounds[0]);
      minY = Math.min(minY, offsetY + bounds[1]);
      maxX = Math.max(maxX, offsetX + bounds[2]);
      maxY = Math.max(maxY, offsetY + bounds[3]);
      placedGlyphs.push({
        segments: glyph.segments,
        offsetX,
        offsetY
      });
    }

    penX += entry.advanceEm || 0.0;
  }

  if (!Number.isFinite(minX) || !Number.isFinite(minY) || !Number.isFinite(maxX) || !Number.isFinite(maxY)) {
    return new THREE.CanvasTexture(canvas);
  }

  minX = Math.min(minX, 0.0);
  maxX = Math.max(maxX, penX);
  const widthEm = Math.max(maxX - minX, 1e-6);
  const heightEm = Math.max(maxY - minY, 1e-6);
  const scale = Math.min((canvas.width * fitWidth) / widthEm, (canvas.height * fitHeight) / heightEm);
  const centerX = 0.5 * (minX + maxX);
  const centerY = 0.5 * (minY + maxY);
  const epsilon = 1e-6;

  ctx.beginPath();
  for (const glyph of placedGlyphs) {
    let prevEndX = NaN;
    let prevEndY = NaN;
    for (const segment of glyph.segments) {
      const x0 = glyph.offsetX + segment[0];
      const y0 = glyph.offsetY + segment[1];
      const x1 = glyph.offsetX + segment[2];
      const y1 = glyph.offsetY + segment[3];
      const sx0 = 0.5 * canvas.width + scale * (x0 - centerX);
      const sy0 = 0.5 * canvas.height - scale * (y0 - centerY);
      const sx1 = 0.5 * canvas.width + scale * (x1 - centerX);
      const sy1 = 0.5 * canvas.height - scale * (y1 - centerY);

      if (
        !Number.isFinite(prevEndX) ||
        Math.abs(sx0 - prevEndX) > epsilon ||
        Math.abs(sy0 - prevEndY) > epsilon
      ) {
        ctx.moveTo(sx0, sy0);
      }
      ctx.lineTo(sx1, sy1);
      prevEndX = sx1;
      prevEndY = sy1;
    }
  }
  ctx.fill("nonzero");

  const texture = new THREE.CanvasTexture(canvas);
  texture.needsUpdate = true;
  return texture;
}


async function loadFont(fontUrl, fontFamily) {
  try {
    const font = new FontFace(fontFamily, `url(${fontUrl})`);
    await font.load();
    document.fonts.add(font);
    await document.fonts.ready;
  } catch (error) {
    console.warn("Font load failed, using fallback serif font.", error);
  }
}
