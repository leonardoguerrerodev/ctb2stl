# Installation Guide

**Languages / Idiomas:** [English](#english) · [Español](#español)

---

<a name="english"></a>

## System Requirements

- Linux x86_64
- Python 3.8 or later
- UVtools (external binary, see below)

---

## Step 1 — Install Python 3

### Fedora / RHEL / CentOS
```bash
sudo dnf install python3 python3-pip
```

### Debian / Ubuntu
```bash
sudo apt install python3 python3-pip
```

### Arch Linux
```bash
sudo pacman -S python python-pip
```

### openSUSE
```bash
sudo zypper install python3 python3-pip
```

---

## Step 2 — Install Python Dependencies

```bash
pip install -r requirements.txt
```

This installs: `numpy`, `Pillow`, `scikit-image`.

---

## Step 3 — Install UVtools

UVtools is not available in the official repositories of most distributions.

### Arch Linux (AUR)
```bash
yay -S uvtools
```

### All other distributions

1. Download `UVtools_linux-x64_*.zip` from the releases page:
   **https://github.com/sn4k3/UVtools/releases**

2. Extract to `/opt/UVtools/`:
   ```bash
   sudo mkdir -p /opt/UVtools
   sudo unzip UVtools_linux-x64_*.zip -d /opt/UVtools
   ```
   Or if you downloaded a `.tar.gz`:
   ```bash
   sudo mkdir -p /opt/UVtools
   sudo tar -xzf UVtools_linux-x64_*.tar.gz -C /opt/UVtools
   ```

3. Ensure the binaries are executable:
   ```bash
   sudo chmod +x /opt/UVtools/UVtoolsCmd /opt/UVtools/UVtools
   ```

4. *(Optional)* Create a symlink to launch from anywhere:
   ```bash
   sudo ln -s /opt/UVtools/UVtools /usr/local/bin/uvtools
   ```

---

## Step 4 — Make the Script Executable

```bash
chmod +x convertir_ctb.sh
```

---

## Verify Installation

```bash
/opt/UVtools/UVtoolsCmd --version
python3 -c "import numpy, PIL, skimage; print('OK')"
```

---
---

<a name="español"></a>

# Guía de instalación (Español)

---

## Requisitos del sistema

- Linux x86_64
- Python 3.8 o superior
- UVtools (binario externo, ver más abajo)

---

## Paso 1 — Instalar Python 3

### Fedora / RHEL / CentOS
```bash
sudo dnf install python3 python3-pip
```

### Debian / Ubuntu
```bash
sudo apt install python3 python3-pip
```

### Arch Linux
```bash
sudo pacman -S python python-pip
```

### openSUSE
```bash
sudo zypper install python3 python3-pip
```

---

## Paso 2 — Instalar dependencias Python

```bash
pip install -r requirements.txt
```

Instala: `numpy`, `Pillow`, `scikit-image`.

---

## Paso 3 — Instalar UVtools

UVtools no está disponible en los repositorios oficiales de la mayoría de distros.

### Arch Linux (AUR)
```bash
yay -S uvtools
```

### Todas las demás distros

1. Descarga `UVtools_linux-x64_*.zip` desde la página de releases:
   **https://github.com/sn4k3/UVtools/releases**

2. Extrae en `/opt/UVtools/`:
   ```bash
   sudo mkdir -p /opt/UVtools
   sudo unzip UVtools_linux-x64_*.zip -d /opt/UVtools
   ```
   O si descargaste un `.tar.gz`:
   ```bash
   sudo mkdir -p /opt/UVtools
   sudo tar -xzf UVtools_linux-x64_*.tar.gz -C /opt/UVtools
   ```

3. Asegúrate de que los binarios sean ejecutables:
   ```bash
   sudo chmod +x /opt/UVtools/UVtoolsCmd /opt/UVtools/UVtools
   ```

4. *(Opcional)* Crea un enlace simbólico para usarlo desde cualquier terminal:
   ```bash
   sudo ln -s /opt/UVtools/UVtools /usr/local/bin/uvtools
   ```

---

## Paso 4 — Dar permisos al script

```bash
chmod +x convertir_ctb.sh
```

---

## Verificar instalación

```bash
/opt/UVtools/UVtoolsCmd --version
python3 -c "import numpy, PIL, skimage; print('OK')"
```
