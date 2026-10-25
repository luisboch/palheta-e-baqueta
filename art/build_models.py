"""Modelos 3D do jogo, construídos do zero no Blender e exportados em glTF (.glb).

Tudo sai deste script, sem .blend guardado: o diff de um modelo é um diff de código, e qualquer
um refaz os arquivos com a mesma versão do Blender (scripts/versions.env).

    scripts/build_models.sh                       # exporta para godot/game/models/
    blender -b --factory-startup --python art/build_models.py -- <pasta de saída>

Os modelos são low-poly e de cor chapada: o visual de quadrinho (sombra em faixas, retícula e
contorno de tinta) é feito pelos shaders do Godot (godot/game/comic/). Cada material tem o nome
da cor da paleta, que o Godot lê para montar o material toon. Nomes especiais:
- `screen`: a tela do palco, onde o jogo põe a capa da música (precisa de UV 0..1).
- `glow_<cor>`: brilha sozinho (lentes, faixas de luz).
- `mirror`: as facetas do globo espelhado.

Convenção de eixos: Z para cima e a frente virada para -Y (vista frontal do Blender). O
exportador converte para o Y para cima do glTF; no Godot a frente fica virada para +Z.
"""

from __future__ import annotations

import math
import random
import sys
from collections.abc import Callable, Sequence
from pathlib import Path

import bmesh
import bpy

# Paleta de quadrinho: cores primárias fortes, creme no lugar do branco, "tinta" no lugar do preto.
PALETTE = {
    "red": (0.902, 0.224, 0.275),
    "yellow": (1.0, 0.824, 0.247),
    "blue": (0.153, 0.392, 0.851),
    "cyan": (0.231, 0.808, 0.675),
    "orange": (1.0, 0.549, 0.259),
    "purple": (0.482, 0.173, 0.749),
    "cream": (1.0, 0.953, 0.839),
    "ink": (0.102, 0.102, 0.122),
    "steel": (0.553, 0.6, 0.682),
    "wood": (0.788, 0.478, 0.251),
    "mirror": (0.86, 0.88, 0.95),
    "screen": (1.0, 1.0, 1.0),
}
SHARP_ANGLE = math.radians(35)  # arestas mais vivas que isso ficam duras (e ganham contorno)
CITY_SEED = 7  # a mesma cidade a cada exportação
Point = tuple[float, float]


# --- materiais e malhas -------------------------------------------------------------------


def material(name: str) -> bpy.types.Material:
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    color = PALETTE[name.removeprefix("glow_")]
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.6
    if name.startswith("glow_"):
        bsdf.inputs["Emission Color"].default_value = (*color, 1.0)
        bsdf.inputs["Emission Strength"].default_value = 2.0
    mat.diffuse_color = (*color, 1.0)
    return mat


def _object(name: str, bm: bmesh.types.BMesh, mat: str) -> bpy.types.Object:
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(material(mat))
    mesh.shade_smooth()
    mesh.set_sharp_from_angle(angle=SHARP_ANGLE)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def _place(obj: bpy.types.Object, loc: Sequence[float], rot: Sequence[float] = (0, 0, 0)) -> bpy.types.Object:
    obj.location = loc
    obj.rotation_euler = [math.radians(a) for a in rot]
    return obj


def box(
    name: str,
    size: Sequence[float],
    loc: Sequence[float],
    mat: str,
    rot: Sequence[float] = (0, 0, 0),
) -> bpy.types.Object:
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    return _place(_object(name, bm, mat), loc, rot)


def cylinder(
    name: str,
    radius: float,
    depth: float,
    loc: Sequence[float],
    mat: str,
    rot: Sequence[float] = (0, 0, 0),
    top: float | None = None,
    segments: int = 24,
) -> bpy.types.Object:
    """Cilindro (ou cone, com `top`) em pé no eixo Z, centrado em `loc`."""
    bm = bmesh.new()
    bmesh.ops.create_cone(
        bm,
        cap_ends=True,
        segments=segments,
        radius1=radius,
        radius2=radius if top is None else top,
        depth=depth,
    )
    return _place(_object(name, bm, mat), loc, rot)


def sphere(
    name: str, radius: float, loc: Sequence[float], mat: str, subdivisions: int = 2
) -> bpy.types.Object:
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdivisions, radius=radius)
    return _place(_object(name, bm, mat), loc)


def prism(
    name: str,
    outline: Sequence[Point],
    depth: float,
    loc: Sequence[float],
    mat: str,
    rot: Sequence[float] = (0, 0, 0),
) -> bpy.types.Object:
    """Contorno 2D (x, z) no plano da frente, com espessura `depth` em Y."""
    bm = bmesh.new()
    front = [bm.verts.new((x, -depth / 2, z)) for x, z in outline]
    back = [bm.verts.new((x, depth / 2, z)) for x, z in outline]
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    n = len(outline)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((front[j], front[i], back[i], back[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _place(_object(name, bm, mat), loc, rot)


def screen_plane(name: str, width: float, height: float, loc: Sequence[float]) -> bpy.types.Object:
    """Retângulo virado para a frente (-Y), com UV 0..1: a capa ocupa a tela inteira."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    corners = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
    verts = [bm.verts.new((u * width / 2, 0.0, v * height / 2)) for u, v in corners]
    face = bm.faces.new(verts)
    for loop, (u, v) in zip(face.loops, corners, strict=True):
        loop[uv].uv = ((u + 1) / 2, (v + 1) / 2)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if face.normal.y > 0:
        face.normal_flip()
    return _place(_object(name, bm, "screen"), loc)


# --- contornos 2D -------------------------------------------------------------------------


def convex_hull(points: Sequence[Point]) -> list[Point]:
    """Cadeia monótona de Andrew; devolve no sentido anti-horário."""
    pts = sorted(set(points))

    def cross(o: Point, a: Point, b: Point) -> float:
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

    lower: list[Point] = []
    upper: list[Point] = []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    for p in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]


def circle(cx: float, cz: float, r: float, n: int = 32) -> list[Point]:
    return [
        (cx + r * math.cos(2 * math.pi * i / n), cz + r * math.sin(2 * math.pi * i / n)) for i in range(n)
    ]


def pick_outline(scale: float = 1.0) -> list[Point]:
    """A palheta: um triângulo arredondado, de ponta para baixo (o escudo do emblema)."""
    corners = [(0.0, -1.05, 0.22), (-0.85, 0.55, 0.6), (0.85, 0.55, 0.6)]
    points = [p for cx, cz, r in corners for p in circle(cx, cz, r, 40)]
    return [(x * scale, z * scale) for x, z in convex_hull(points)]


def star_outline(outer: float, inner: float, tips: int = 5) -> list[Point]:
    points = []
    for i in range(tips * 2):
        r = outer if i % 2 == 0 else inner
        a = math.pi / 2 + math.pi * i / tips
        points.append((r * math.cos(a), r * math.sin(a)))
    return points


def body_outline(lobes: Sequence[tuple[float, float, float, float]], n: int = 64) -> list[Point]:
    """Corpo de guitarra: união de elipses (cx, cz, rx, rz), ordenada pelo ângulo do centro."""

    def inside(x: float, z: float, lobe: tuple[float, float, float, float]) -> bool:
        cx, cz, rx, rz = lobe
        return ((x - cx) / rx) ** 2 + ((z - cz) / rz) ** 2 < 0.999

    points = []
    for lobe in lobes:
        cx, cz, rx, rz = lobe
        for i in range(n):
            a = 2 * math.pi * i / n
            x, z = cx + rx * math.cos(a), cz + rz * math.sin(a)
            if not any(inside(x, z, other) for other in lobes if other is not lobe):
                points.append((x, z))
    mx = sum(p[0] for p in points) / len(points)
    mz = sum(p[1] for p in points) / len(points)
    return sorted(points, key=lambda p: math.atan2(p[1] - mz, p[0] - mx))


BOLT = [(-0.05, 0.8), (0.4, 0.8), (0.1, 0.15), (0.38, 0.15), (-0.25, -0.85), (-0.02, -0.1), (-0.3, -0.1)]


# --- modelos ------------------------------------------------------------------------------


def emblem() -> None:
    """Escudo do herói: uma palheta com borda, um raio e duas baquetas cruzadas atrás."""
    prism("Rim", pick_outline(1.12), 0.2, (0, 0.06, 0), "yellow")
    prism("Pick", pick_outline(), 0.26, (0, 0, 0), "red")
    prism("Bolt", [(x * 0.95, z * 0.95) for x, z in BOLT], 0.36, (0, -0.02, 0.02), "yellow")
    for side in (-1, 1):
        cylinder("Stick", 0.06, 3.4, (0, 0.2, 0.1), "wood", rot=(0, side * 40, 0), top=0.035, segments=12)
        tip_x = math.sin(math.radians(side * 40)) * 1.7
        tip_z = math.cos(math.radians(side * 40)) * 1.7 + 0.1
        sphere("Tip", 0.07, (tip_x, 0.2, tip_z), "cream", subdivisions=1)


def _stringed(
    body_color: str, lobes: Sequence[tuple[float, float, float, float]], neck: float, strings: int
) -> None:
    """Guitarra ou baixo de frente, em pé (o braço para cima)."""
    outline = body_outline(lobes)
    prism("Body", outline, 0.14, (0, 0, 0), body_color)
    top = max(z for _, z in outline)
    prism(
        "Guard",
        body_outline([(lobes[0][0], lobes[0][1] - 0.05, lobes[0][2] * 0.55, lobes[0][3] * 0.5)]),
        0.02,
        (0.12, -0.08, 0),
        "cream",
    )
    box("Neck", (0.17, 0.08, neck), (0, -0.03, top + neck / 2 - 0.15), "wood")
    head = top + neck - 0.15
    prism("Head", [(-0.11, 0), (0.11, 0), (0.16, 0.34), (-0.07, 0.4)], 0.07, (0, -0.03, head), "ink")
    for i in range(1, 9):  # trastes
        box("Fret", (0.17, 0.09, 0.012), (0, -0.04, top + neck * (1 - 0.9**i) * 0.9), "steel")
    for i in range(2):  # captadores
        box("Pickup", (0.3, 0.05, 0.08), (0, -0.09, -0.05 + i * 0.22), "ink")
    box("Bridge", (0.3, 0.05, 0.06), (0, -0.09, -0.3), "steel")
    width = 0.12
    for i in range(strings):
        x = -width / 2 + width * i / (strings - 1)
        box("String", (0.008, 0.008, neck + 0.45), (x, -0.1, top + (neck - 0.45) / 2 - 0.3), "cream")


def guitar() -> None:
    # Dois cortes, com as pontas quase iguais.
    lobes = [(0, -0.25, 0.55, 0.45), (0, 0.3, 0.42, 0.36), (-0.3, 0.55, 0.13, 0.25), (0.3, 0.5, 0.13, 0.22)]
    _stringed("red", lobes, neck=1.25, strings=6)


def bass() -> None:
    # Corpo um pouco torto e braço mais longo: o baixo se reconhece de longe.
    lobes = [
        (0, -0.25, 0.5, 0.45),
        (-0.04, 0.32, 0.38, 0.4),
        (-0.3, 0.75, 0.12, 0.32),
        (0.28, 0.5, 0.12, 0.2),
    ]
    _stringed("blue", lobes, neck=1.65, strings=4)


def drums() -> None:
    """Bateria de frente: bumbo com estrela, caixa, tons, surdo, chimbal e pratos."""

    def drum(name: str, radius: float, depth: float, loc: Sequence[float], tilt: float = 90) -> None:
        cylinder(name, radius, depth, loc, "red", rot=(tilt, 0, 0))
        cylinder(name + "Rim", radius * 1.04, depth * 0.12, loc, "steel", rot=(tilt, 0, 0))

    cylinder("Kick", 0.55, 0.45, (0, 0, 0.55), "red", rot=(90, 0, 0))
    cylinder("KickHead", 0.52, 0.47, (0, 0, 0.55), "cream", rot=(90, 0, 0))
    prism("KickStar", star_outline(0.32, 0.14), 0.04, (0, -0.25, 0.55), "yellow")
    drum("TomL", 0.2, 0.18, (-0.25, -0.05, 1.22), tilt=60)
    drum("TomR", 0.22, 0.2, (0.27, -0.05, 1.24), tilt=60)
    drum("Snare", 0.28, 0.16, (-0.75, -0.35, 0.78), tilt=15)
    drum("Floor", 0.32, 0.38, (0.85, -0.2, 0.55), tilt=0)
    for x, z, r in ((-1.05, 1.5, 0.36), (1.1, 1.62, 0.4)):  # pratos de ataque e condução
        cylinder("Stand", 0.02, z, (x, 0.1, z / 2), "steel", segments=8)
        cylinder("Cymbal", r, 0.05, (x, 0.1, z), "yellow", rot=(-20 if x < 0 else 20, 0, 0), top=0.04)
    cylinder("HatStand", 0.02, 1.0, (-1.25, -0.3, 0.5), "steel", segments=8)
    for dz in (0.0, 0.05):
        cylinder("HiHat", 0.24, 0.035, (-1.25, -0.3, 1.0 + dz), "yellow", top=0.03)
    cylinder("SnareStand", 0.025, 0.7, (-0.75, -0.35, 0.35), "steel", segments=8)


def pedestal() -> None:
    cylinder("Base", 1.1, 0.3, (0, 0, 0.15), "ink", segments=32)
    cylinder("Ring", 1.14, 0.06, (0, 0, 0.3), "glow_yellow", segments=32)
    cylinder("Top", 1.0, 0.08, (0, 0, 0.34), "steel", segments=32)
    prism("Star", star_outline(0.22, 0.09), 0.04, (0, -1.1, 0.15), "yellow")


def stage() -> None:
    """Palco: tablado, telão quadrado (a capa), torres de treliça e caixas de som."""
    box("Floor", (12, 6, 0.8), (0, 0, 0.4), "ink")
    box("Edge", (12.1, 0.12, 0.12), (0, -3.0, 0.78), "glow_yellow")
    box("Frame", (5.0, 0.4, 5.0), (0, 2.6, 3.4), "ink")
    box("FrameRim", (5.3, 0.3, 5.3), (0, 2.7, 3.4), "yellow")
    for side in (-1, 1):
        x = side * 5.4
        for dx in (-0.35, 0.35):  # torre de treliça: 4 postes e degraus em X
            for dy in (-0.35, 0.35):
                box("Post", (0.1, 0.1, 6.5), (x + dx, 1.8 + dy, 4.05), "steel")
        for k in range(8):
            z = 1.2 + k * 0.8
            box("Rung", (0.8, 0.06, 0.06), (x, 1.45, z), "steel", rot=(0, 30 if k % 2 else -30, 0))
            box("RungB", (0.06, 0.8, 0.06), (x - side * 0.35, 1.8, z), "steel")
        for k, z in enumerate((1.4, 2.6)):  # caixas de som empilhadas
            box("Speaker", (1.4, 1.0, 1.2), (side * 3.9, 1.6, z), "ink")
            for cone_z, r in ((z + 0.22, 0.32), (z - 0.32, 0.16)):
                cylinder("Cone", r, 0.06, (side * 3.9, 1.08, cone_z), "steel", rot=(90, 0, 0))
            box("SpeakerRim", (1.44, 0.04, 0.06), (side * 3.9, 1.08, z + 0.6 - k * 0.0), "red")
    box("Truss", (11.6, 0.5, 0.5), (0, 1.8, 7.4), "steel")
    screen_plane("Screen", 4.6, 4.6, (0, 2.38, 3.4))


def mirror_ball() -> None:
    sphere("Ball", 0.7, (0, 0, 0), "mirror", subdivisions=2)
    cylinder("Rod", 0.03, 2.0, (0, 0, 1.6), "steel", segments=8)
    cylinder("Cap", 0.12, 0.12, (0, 0, 0.7), "steel", segments=12)


def spotlight() -> None:
    """Refletor móvel: base e garfo num objeto, cabeça (que gira) noutro, de lente para baixo."""
    box("Base", (0.6, 0.6, 0.25), (0, 0, 0), "ink")
    for side in (-1, 1):
        box("Yoke", (0.08, 0.2, 0.55), (side * 0.32, 0, -0.38), "red")
    cylinder("Head", 0.24, 0.55, (0, 0, -0.62), "ink", segments=16)
    cylinder("Lens", 0.2, 0.04, (0, 0, -0.9), "glow_cream", segments=16)


def usb_stick() -> None:
    """Pendrive gigante (a estação de Gerenciar músicas)."""
    box("Body", (0.8, 0.35, 1.8), (0, 0, 0.9), "blue")
    box("Band", (0.82, 0.37, 0.12), (0, 0, 1.55), "yellow")
    box("Plug", (0.55, 0.22, 0.6), (0, 0, 2.1), "steel")
    for x in (-0.12, 0.12):
        box("Hole", (0.1, 0.24, 0.1), (x, 0, 2.2), "ink")
    sphere("Led", 0.06, (0.25, -0.18, 0.3), "glow_red", subdivisions=1)


def vinyl() -> None:
    cylinder("Disc", 1.0, 0.04, (0, 0, 0), "ink", segments=48)
    cylinder("Label", 0.34, 0.05, (0, 0, 0), "red", segments=32)
    cylinder("Hole", 0.04, 0.06, (0, 0, 0), "cream", segments=12)


def city() -> None:
    """Anel de prédios em volta das estações, com janelas e caixas d'água. Sempre a mesma
    cidade (semente fixa); a frente de cada prédio olha para o centro."""
    rng = random.Random(CITY_SEED)
    walls = ["blue", "purple", "cream", "red", "cyan", "orange"]
    count = 34
    for i in range(count):
        angle = 2 * math.pi * (i + rng.uniform(-0.25, 0.25)) / count
        dist = rng.uniform(34, 46)
        w, d, h = rng.uniform(5, 8), rng.uniform(4, 7), rng.uniform(7, 24)
        x, y = math.cos(angle) * dist, math.sin(angle) * dist
        facing = math.degrees(angle) - 90  # a face -Y do prédio olha para a origem
        parts = [box("Building", (w, d, h), (0, 0, h / 2), rng.choice(walls))]
        floors, cols = int(h // 2.2), max(2, int(w // 1.7))
        lit = rng.choice(["cream", "yellow"])
        for f in range(1, floors):
            for c in range(cols):
                wx = -w / 2 + w * (c + 0.5) / cols
                parts.append(box("Window", (0.7, 0.1, 0.9), (wx, -d / 2 - 0.02, f * 2.2), lit))
        if rng.random() < 0.35:  # caixa d'água no telhado
            parts.append(cylinder("Tank", 0.9, 1.4, (w / 4, 0, h + 1.5), "wood", segments=12))
            parts.append(cylinder("TankRoof", 1.0, 0.6, (w / 4, 0, h + 2.5), "ink", top=0.1, segments=12))
            parts.append(box("TankLeg", (0.15, 0.15, 0.8), (w / 4, 0, h + 0.4), "steel"))
        elif rng.random() < 0.4:  # antena
            parts.append(cylinder("Antenna", 0.08, 3.0, (-w / 4, 0, h + 1.5), "steel", segments=6))
            parts.append(sphere("Beacon", 0.18, (-w / 4, 0, h + 3.1), "glow_red", subdivisions=1))
        for part in parts:  # monta o prédio no lugar dele
            px, py, pz = part.location
            a = math.radians(facing)
            part.location = (
                x + px * math.cos(a) - py * math.sin(a),
                y + px * math.sin(a) + py * math.cos(a),
                pz,
            )
            part.rotation_euler[2] += a


# Modelo → construtor. Cada um vira godot/game/models/<nome>.glb, com as peças juntas numa malha
# só (menos chamadas de desenho), exceto as peças listadas em KEEP_APART.
MODELS: dict[str, Callable[[], None]] = {
    "emblem": emblem,
    "guitar": guitar,
    "bass": bass,
    "drums": drums,
    "pedestal": pedestal,
    "stage": stage,
    "mirror_ball": mirror_ball,
    "spotlight": spotlight,
    "usb_stick": usb_stick,
    "vinyl": vinyl,
    "city": city,
}
# Peças que o jogo mexe ou troca sozinhas: a tela recebe a capa; a cabeça do refletor gira.
KEEP_APART = {"stage": {"Screen"}, "spotlight": {"Head", "Lens"}}
SPOT_PIVOT = (0.0, 0.0, -0.38)  # eixo do garfo: a cabeça do refletor gira em volta dele


def _join(objects: list[bpy.types.Object], name: str) -> bpy.types.Object:
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    if len(objects) > 1:
        bpy.ops.object.join()
    joined = bpy.context.view_layer.objects.active
    joined.name = name
    joined.data.name = name
    return joined


def build(name: str, out_dir: Path) -> Path:
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj)
    MODELS[name]()
    apart = KEEP_APART.get(name, set())
    loose = [o for o in bpy.data.objects if o.name.split(".")[0] not in apart]
    keep = [o for o in bpy.data.objects if o.name.split(".")[0] in apart]
    exported = [_join(loose, name)]
    if name == "spotlight":  # a cabeça e a lente giram juntas, em volta do eixo do garfo
        head = _join(keep, "Head")
        bpy.context.scene.cursor.location = SPOT_PIVOT
        bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
        exported.append(head)
    else:
        exported += keep
    for obj in exported:
        obj.name = obj.name.split(".")[0]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in exported:
        obj.select_set(True)
    path = out_dir / f"{name}.glb"
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_cameras=False,
        export_lights=False,
        export_animations=False,
    )
    return path


def main() -> None:
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    out_dir = Path(args[0] if args else "godot/game/models").resolve()
    only = set(args[1:])
    out_dir.mkdir(parents=True, exist_ok=True)
    for name in MODELS:
        if not only or name in only:
            print("modelo:", build(name, out_dir))


if __name__ == "__main__":
    main()
