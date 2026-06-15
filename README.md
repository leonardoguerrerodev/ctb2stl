# ctb2stl

> Convert resin 3D print files (`.ctb`) to printable meshes (`.stl`) using layer extraction and marching cubes reconstruction.

**Languages / Idiomas:** [English](#english) · [Español](#español)

---

<a name="english"></a>

## Overview

`ctb2stl` extracts the per-layer images embedded in a `.ctb` file (Chitubox / Anycubic resin printers) and reconstructs them into a 3D surface mesh using the marching cubes algorithm. The result is a standard binary `.stl` file with real-world millimeter coordinates.

This is useful for archiving print-ready geometry, inspecting sliced models, or re-importing a finalized layout back into a slicer or CAD tool.

> **Note:** The output STL represents the *printed geometry*, including supports. It is not a clean parametric model.

---

## Requirements

| Dependency | Version | Purpose |
|---|---|---|
| Python | 3.8+ | Runtime |
| numpy | latest | 3D array operations |
| Pillow | latest | PNG layer loading |
| scikit-image | latest | Marching cubes algorithm |
| [UVtools](https://github.com/sn4k3/UVtools) | latest | `.ctb` layer extraction |

Install Python dependencies:

```bash
pip install -r requirements.txt
```

See [INSTALL.md](INSTALL.md) for full system setup instructions including UVtools.

---

## Quick Start

### Batch conversion (recommended)

Copy both `convertir_ctb.sh` and `ctb2stl.py` to the folder containing your `.ctb` files, then run:

```bash
chmod +x convertir_ctb.sh
./convertir_ctb.sh
```

All `.ctb` files in the current directory are converted. A progress bar is shown per file.

If your system language is Spanish, the script will ask whether you want Spanish output. Otherwise English is used by default.

### Single file

```bash
python3 ctb2stl.py model.ctb model.stl
```

---

## How It Works

```
.ctb file
   │
   ▼
UVtools extract      →  layer0000.png … layerNNNN.png  +  Configuration.ini
   │
   ▼
Stack PNGs into 3D numpy array  (downscaled x4 by default to reduce RAM)
   │
   ▼
Marching cubes (scikit-image)   →  vertex + face arrays
   │
   ▼
Scale vertices to mm            →  binary STL
```

---

## Configuration

Edit the `SCALE` constant at the top of `ctb2stl.py` to trade quality for memory:

| `SCALE` | Mesh quality | Approximate RAM |
|---------|-------------|-----------------|
| `2`     | High        | ~8 GB           |
| `4`     | Balanced    | ~2 GB  ← default |
| `8`     | Low         | ~512 MB         |

---

## Attribution

Layer extraction is powered by [UVtools](https://github.com/sn4k3/UVtools) by sn4k3, used here as an external binary dependency.

---
---

<a name="español"></a>

# ctb2stl (Español)

> Convierte archivos de impresión en resina (`.ctb`) a mallas imprimibles (`.stl`) mediante extracción de capas y reconstrucción con marching cubes.

---

## Descripción

`ctb2stl` extrae las imágenes por capa incrustadas en un archivo `.ctb` (impresoras de resina Chitubox / Anycubic) y las reconstruye en una malla 3D usando el algoritmo de marching cubes. El resultado es un archivo `.stl` binario estándar con coordenadas en milímetros reales.

Útil para archivar geometría lista para imprimir, inspeccionar modelos laminados o reimportar un diseño finalizado en un slicer o herramienta CAD.

> **Nota:** El STL resultante representa la *geometría de impresión*, soportes incluidos. No es un modelo paramétrico limpio.

---

## Requisitos

| Dependencia | Versión | Uso |
|---|---|---|
| Python | 3.8+ | Intérprete |
| numpy | última | Operaciones con arrays 3D |
| Pillow | última | Carga de capas PNG |
| scikit-image | última | Algoritmo marching cubes |
| [UVtools](https://github.com/sn4k3/UVtools) | última | Extracción de capas `.ctb` |

Instalar dependencias Python:

```bash
pip install -r requirements.txt
```

Consulta [INSTALL.md](INSTALL.md) para las instrucciones completas incluyendo UVtools.

---

## Inicio rápido

### Conversión masiva (recomendado)

Copia `convertir_ctb.sh` y `ctb2stl.py` a la carpeta con tus archivos `.ctb` y ejecuta:

```bash
chmod +x convertir_ctb.sh
./convertir_ctb.sh
```

Se convierten todos los `.ctb` del directorio actual. Se muestra una barra de progreso por archivo.

Si el idioma del sistema es español, el script preguntará si deseas la salida en español. De lo contrario, se usa inglés por defecto.

### Archivo individual

```bash
python3 ctb2stl.py modelo.ctb modelo.stl
```

---

## Cómo funciona

```
Archivo .ctb
   │
   ▼
UVtools extract      →  layer0000.png … layerNNNN.png  +  Configuration.ini
   │
   ▼
Apilar PNGs en array 3D numpy  (downscale x4 por defecto para reducir RAM)
   │
   ▼
Marching cubes (scikit-image)  →  vértices y caras
   │
   ▼
Escalar vértices a mm          →  STL binario
```

---

## Configuración

Modifica la constante `SCALE` al inicio de `ctb2stl.py` para ajustar calidad vs. memoria:

| `SCALE` | Calidad de malla | RAM aproximada |
|---------|-----------------|----------------|
| `2`     | Alta            | ~8 GB           |
| `4`     | Equilibrada     | ~2 GB  ← por defecto |
| `8`     | Baja            | ~512 MB         |

---

## Atribución

La extracción de capas usa [UVtools](https://github.com/sn4k3/UVtools) de sn4k3 como dependencia binaria externa.
