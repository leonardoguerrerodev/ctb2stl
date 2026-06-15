#!/usr/bin/env python3
"""
ctb2stl — Convert .ctb resin print files to .stl via UVtools + marching cubes.

Usage:
    python3 ctb2stl.py <input.ctb> <output.stl>

Environment:
    CTB2STL_LANG   'en' (default) or 'es' — output language
"""
import sys, os, struct, glob, shutil, configparser, subprocess
from shutil import which
import numpy as np
from PIL import Image
from skimage import measure

# Downscale factor per XY axis applied before building the 3D volume.
# Higher values reduce RAM usage at the cost of mesh resolution.
#   2 → high quality  (~8 GB RAM)
#   4 → balanced      (~2 GB RAM)  ← default
#   8 → low quality   (~512 MB RAM)
SCALE = 2

# Candidate paths where UVtools is expected to be installed
_UVTOOLS_SEARCH = [
    "/opt/UVtools/UVtoolsCmd",
    "/usr/local/bin/UVtoolsCmd",
]

# ── Localization ──────────────────────────────────────────────────────────────

_LANG = os.environ.get("CTB2STL_LANG", "en").lower()

_STRINGS = {
    "en": {
        "uvtools_missing": "UVTools is not installed or could not be found in known paths.",
        "uvtools_download": "Download it from: https://github.com/sn4k3/UVtools/releases",
        "hint_arch":     "On Arch Linux, install from AUR:\n  yay -S uvtools",
        "hint_fedora":   "On Fedora/RHEL, no official dnf package is available.\n"
                         "Download the Linux .tar.gz and run:\n"
                         "  sudo mkdir -p /opt/UVtools && sudo tar -xzf UVtools*.tar.gz -C /opt/UVtools",
        "hint_debian":   "On Debian/Ubuntu, no official apt package is available.\n"
                         "Download the Linux .tar.gz and run:\n"
                         "  sudo mkdir -p /opt/UVtools && sudo tar -xzf UVtools*.tar.gz -C /opt/UVtools",
        "hint_suse":     "On openSUSE, no official zypper package is available.\n"
                         "Download the Linux .tar.gz and run:\n"
                         "  sudo mkdir -p /opt/UVtools && sudo tar -xzf UVtools*.tar.gz -C /opt/UVtools",
        "hint_generic":  "Download the Linux package and extract it to /opt/UVtools/",
        "extracting":    "  Extracting layers...",
        "uvtools_fail":  "  ERROR: UVtools failed to extract layers",
        "no_images":     "  ERROR: No layer images found after extraction",
        "building":      "  Building volume (downscale x{scale})...",
        "marching":      "  Running marching cubes...",
        "stl_saved":     "  STL saved: {name} ({ntri} triangles)",
        "loading":       "  Loading layers: {i}/{n}",
        "layer_info":    "  {count} layers, {rx}x{ry}px, LayerHeight={lh}mm",
        "volume_info":   "  Volume: {shape}, voxel: {voxel}",
    },
    "es": {
        "uvtools_missing": "UVTools no está instalado o no se encontró en las rutas conocidas.",
        "uvtools_download": "Descárgalo desde: https://github.com/sn4k3/UVtools/releases",
        "hint_arch":     "En Arch Linux puedes instalarlo desde AUR:\n  yay -S uvtools",
        "hint_fedora":   "En Fedora/RHEL no hay paquete oficial en dnf.\n"
                         "Descarga el .tar.gz para Linux y ejecuta:\n"
                         "  sudo mkdir -p /opt/UVtools && sudo tar -xzf UVtools*.tar.gz -C /opt/UVtools",
        "hint_debian":   "En Debian/Ubuntu no hay paquete oficial en apt.\n"
                         "Descarga el .tar.gz para Linux y ejecuta:\n"
                         "  sudo mkdir -p /opt/UVtools && sudo tar -xzf UVtools*.tar.gz -C /opt/UVtools",
        "hint_suse":     "En openSUSE no hay paquete oficial en zypper.\n"
                         "Descarga el .tar.gz para Linux y ejecuta:\n"
                         "  sudo mkdir -p /opt/UVtools && sudo tar -xzf UVtools*.tar.gz -C /opt/UVtools",
        "hint_generic":  "Descarga el archivo para Linux y extráelo en /opt/UVtools/",
        "extracting":    "  Extrayendo capas...",
        "uvtools_fail":  "  ERROR: UVtools falló al extraer las capas",
        "no_images":     "  ERROR: No se encontraron imágenes de capas tras la extracción",
        "building":      "  Construyendo volumen (downscale x{scale})...",
        "marching":      "  Ejecutando marching cubes...",
        "stl_saved":     "  STL guardado: {name} ({ntri} triángulos)",
        "loading":       "  Cargando capas: {i}/{n}",
        "layer_info":    "  {count} capas, {rx}x{ry}px, LayerHeight={lh}mm",
        "volume_info":   "  Volumen: {shape}, voxel: {voxel}",
    },
}

def _(key, **kwargs):
    """Return the localized string for key, formatted with kwargs."""
    lang = _LANG if _LANG in _STRINGS else "en"
    s = _STRINGS[lang].get(key, _STRINGS["en"].get(key, key))
    return s.format(**kwargs) if kwargs else s

# ── UVtools detection ─────────────────────────────────────────────────────────

def _find_uvtools():
    """Search known paths and PATH for UVtoolsCmd binary."""
    for p in _UVTOOLS_SEARCH:
        if os.path.isfile(p) and os.access(p, os.X_OK):
            return p
    return which("UVtoolsCmd")

def _distro_install_hint():
    """Print a distro-specific install suggestion and exit."""
    info = {}
    try:
        with open("/etc/os-release") as f:
            for line in f:
                if "=" in line:
                    k, v = line.strip().split("=", 1)
                    info[k] = v.strip('"')
    except FileNotFoundError:
        pass

    did   = info.get("ID",       "").lower()
    dlike = info.get("ID_LIKE",  "").lower()
    combo = f"{did} {dlike}"

    print(_("uvtools_missing"))
    print(_("uvtools_download"))
    print()

    if "arch" in combo:
        print(_("hint_arch"))
    elif any(x in combo for x in ("fedora", "rhel", "centos")):
        print(_("hint_fedora"))
    elif any(x in combo for x in ("debian", "ubuntu")):
        print(_("hint_debian"))
    elif any(x in combo for x in ("opensuse", "suse")):
        print(_("hint_suse"))
    else:
        print(_("hint_generic"))

UVTOOLS = _find_uvtools()
if UVTOOLS is None:
    _distro_install_hint()
    sys.exit(1)

# ── Core functions ────────────────────────────────────────────────────────────

def extract_layers(ctb_path, tmp_dir):
    """Run UVtools to extract per-layer PNG images from the .ctb file."""
    os.makedirs(tmp_dir, exist_ok=True)
    subprocess.run(
        [UVTOOLS, "extract", ctb_path, tmp_dir],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
    )
    # UVtools exits with code 1 even on success; check for output files instead
    return len(glob.glob(os.path.join(tmp_dir, "layer*.png"))) > 0

def read_config(tmp_dir):
    """Parse the Configuration.ini that UVtools writes alongside the layer images."""
    cfg = configparser.ConfigParser()
    cfg.read(os.path.join(tmp_dir, "Configuration.ini"))
    s = cfg["SlicerSettings"]
    return {
        "layer_height": float(s.get("LayerHeight",   0.05)),
        "display_w":    float(s.get("DisplayWidth",  143.43)),
        "display_h":    float(s.get("DisplayHeight", 89.6)),
        "res_x":        int(s.get("ResolutionX",     4098)),
        "res_y":        int(s.get("ResolutionY",     2560)),
        "layer_count":  int(s.get("LayerCount",      0)),
    }

def build_volume(tmp_dir, cfg, scale):
    """
    Stack all layer PNGs into a 3D numpy array.
    Images are downscaled by `scale` on each XY axis to reduce memory usage.
    Returns (volume, voxel_sizes) where voxel_sizes are in millimeters.
    """
    pngs = sorted(glob.glob(os.path.join(tmp_dir, "layer*.png")))
    if not pngs:
        return None, None

    w = cfg["res_x"] // scale
    h = cfg["res_y"] // scale
    n = len(pngs)

    volume = np.zeros((n, h, w), dtype=np.uint8)
    for i, path in enumerate(pngs):
        img = Image.open(path).resize((w, h), Image.LANCZOS)
        volume[i] = np.array(img, dtype=np.uint8)
        if i % 100 == 0:
            print(_("loading", i=i, n=n), flush=True)

    # Real-world size of each voxel in mm (Z, Y, X order to match volume axes)
    voxel_sizes = (
        cfg["layer_height"],
        cfg["display_h"] / cfg["res_y"] * scale,
        cfg["display_w"] / cfg["res_x"] * scale,
    )
    return volume, voxel_sizes

def volume_to_stl(volume, voxel_sizes, stl_path):
    """
    Run marching cubes on the binary volume and write a binary STL file.
    Vertex coordinates are scaled from voxel units to real-world millimeters.
    """
    binary = volume > 127
    verts, faces, _, _ = measure.marching_cubes(binary.astype(np.float32), level=0.5)

    # Scale voxel-space coordinates to millimeters
    verts[:, 0] *= voxel_sizes[0]
    verts[:, 1] *= voxel_sizes[1]
    verts[:, 2] *= voxel_sizes[2]

    triangles = verts[faces]
    n_tri = len(faces)

    with open(stl_path, "wb") as f:
        f.write(b"\x00" * 80)              # 80-byte STL header (unused)
        f.write(struct.pack("<I", n_tri))
        for tri in triangles:
            v0, v1, v2 = tri
            normal = np.cross(v1 - v0, v2 - v0)
            norm = np.linalg.norm(normal)
            if norm > 0:
                normal /= norm
            f.write(struct.pack("<fff", *normal))
            f.write(struct.pack("<fff", *v0))
            f.write(struct.pack("<fff", *v1))
            f.write(struct.pack("<fff", *v2))
            f.write(b"\x00\x00")           # attribute byte count (unused)

    return n_tri

def convert(ctb_path, stl_path):
    name    = os.path.basename(ctb_path)
    tmp_dir = f"/tmp/ctb_layers_{os.getpid()}"
    print(f"\n=== {name} ===")
    try:
        print(_("extracting"), flush=True)
        if not extract_layers(ctb_path, tmp_dir):
            print(_("uvtools_fail"))
            return False

        cfg = read_config(tmp_dir)
        print(_("layer_info", count=cfg["layer_count"], rx=cfg["res_x"],
                ry=cfg["res_y"], lh=cfg["layer_height"]))

        print(_("building", scale=SCALE), flush=True)
        volume, voxel_sizes = build_volume(tmp_dir, cfg, SCALE)
        if volume is None:
            print(_("no_images"))
            return False

        print(_("volume_info", shape=volume.shape, voxel=voxel_sizes))
        print(_("marching"), flush=True)
        n_tri = volume_to_stl(volume, voxel_sizes, stl_path)
        print(_("stl_saved", name=os.path.basename(stl_path), ntri=n_tri))
        return True
    finally:
        shutil.rmtree(tmp_dir, ignore_errors=True)

if __name__ == "__main__":
    ctb = sys.argv[1]
    stl = sys.argv[2]
    sys.exit(0 if convert(ctb, stl) else 1)
