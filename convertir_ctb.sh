#!/bin/bash
# ctb2stl — Batch convert all .ctb files in the current directory to .stl
#
# Usage:
#   ./convertir_ctb.sh
#
# Requirements:
#   - python3 with numpy, Pillow, scikit-image  (pip install -r requirements.txt)
#   - UVtools installed in /opt/UVtools/         (see INSTALL.md)
#   - ctb2stl.py in the same directory as this script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY="$SCRIPT_DIR/ctb2stl.py"

RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[0;33m'
NC='\033[0m'; BOLD='\033[1m'

# ── Language detection ────────────────────────────────────────────────────────
# Reads $LANG / $LANGUAGE from the environment. If Spanish is detected the user
# is offered a choice; otherwise English is used silently as the default.

CTB2STL_LANG="en"
_sys_lang="${LANG:-${LANGUAGE:-en}}"

if [[ "$_sys_lang" == es* ]]; then
    printf "${YELLOW}System language / Idioma del sistema: Español${NC}\n"
    printf "¿Desea usar el programa en español? [S/n]: "
    read -r _reply
    if [[ -z "$_reply" || "$_reply" =~ ^[SsYy] ]]; then
        CTB2STL_LANG="es"
    fi
fi
export CTB2STL_LANG   # read by ctb2stl.py via os.environ

# ── Messages ──────────────────────────────────────────────────────────────────
# All user-facing strings are defined here so the rest of the script stays
# language-agnostic. PAT_* variables are regex patterns matched against Python
# output lines to drive the progress bar.

if [[ "$CTB2STL_LANG" == "es" ]]; then
    MSG_NO_PY="Error: no se encuentra ctb2stl.py en"
    MSG_NO_CTB="No se encontraron archivos .ctb en"
    MSG_CONVERTING="Convirtiendo %d archivo(s) CTB → STL"
    MSG_COMPLETED="Completado: %d de %d archivo(s) convertido(s)"
    MSG_CONV_FAILED="Conversión fallida (código de salida: %d)"
    MSG_FAILED_LABEL="Fallido"
    MSG_MARCHING="Calculando geometría (marching cubes)..."
    MSG_UVTOOLS_MISSING="Error: UVTools no está instalado o no se encontró."
    MSG_UVTOOLS_DOWNLOAD="Descárgalo desde: https://github.com/sn4k3/UVtools/releases"
    MSG_HINT_ARCH="En Arch Linux puedes instalarlo desde AUR:\n  yay -S uvtools"
    MSG_HINT_DNF="En Fedora/RHEL no hay paquete oficial en dnf.\nDescarga el .tar.gz para Linux y ejecuta:\n  sudo mkdir -p /opt/UVtools && sudo tar -xzf UVtools*.tar.gz -C /opt/UVtools"
    MSG_HINT_APT="En Debian/Ubuntu no hay paquete oficial en apt.\nDescarga el .tar.gz para Linux y ejecuta:\n  sudo mkdir -p /opt/UVtools && sudo tar -xzf UVtools*.tar.gz -C /opt/UVtools"
    MSG_HINT_ZYPPER="En openSUSE no hay paquete oficial en zypper.\nDescarga el .tar.gz para Linux y ejecuta:\n  sudo mkdir -p /opt/UVtools && sudo tar -xzf UVtools*.tar.gz -C /opt/UVtools"
    MSG_HINT_GENERIC="Descarga el archivo para Linux y extráelo en /opt/UVtools/"
    # Patterns to parse Python script output (must match _STRINGS["es"] in ctb2stl.py)
    PAT_LOADING="Cargando capas: ([0-9]+)/([0-9]+)"
    PAT_EXTRACT="Extrayendo capas"
    PAT_LAYERS="capas,.*px"
    PAT_STL="STL guardado"
else
    MSG_NO_PY="Error: ctb2stl.py not found in"
    MSG_NO_CTB="No .ctb files found in"
    MSG_CONVERTING="Converting %d file(s) CTB → STL"
    MSG_COMPLETED="Completed: %d of %d file(s) converted"
    MSG_CONV_FAILED="Conversion failed (exit code: %d)"
    MSG_FAILED_LABEL="Failed"
    MSG_MARCHING="Computing geometry (marching cubes)..."
    MSG_UVTOOLS_MISSING="Error: UVTools is not installed or could not be found."
    MSG_UVTOOLS_DOWNLOAD="Download it from: https://github.com/sn4k3/UVtools/releases"
    MSG_HINT_ARCH="On Arch Linux, install from AUR:\n  yay -S uvtools"
    MSG_HINT_DNF="On Fedora/RHEL, no official dnf package is available.\nDownload the Linux .tar.gz and run:\n  sudo mkdir -p /opt/UVtools && sudo tar -xzf UVtools*.tar.gz -C /opt/UVtools"
    MSG_HINT_APT="On Debian/Ubuntu, no official apt package is available.\nDownload the Linux .tar.gz and run:\n  sudo mkdir -p /opt/UVtools && sudo tar -xzf UVtools*.tar.gz -C /opt/UVtools"
    MSG_HINT_ZYPPER="On openSUSE, no official zypper package is available.\nDownload the Linux .tar.gz and run:\n  sudo mkdir -p /opt/UVtools && sudo tar -xzf UVtools*.tar.gz -C /opt/UVtools"
    MSG_HINT_GENERIC="Download the Linux package and extract it to /opt/UVtools/"
    # Patterns to parse Python script output (must match _STRINGS["en"] in ctb2stl.py)
    PAT_LOADING="Loading layers: ([0-9]+)/([0-9]+)"
    PAT_EXTRACT="Extracting layers"
    PAT_LAYERS="layers,.*px"
    PAT_STL="STL saved"
fi

# ── UVtools check ─────────────────────────────────────────────────────────────
# Verifies UVtoolsCmd is available before starting any conversion.
# Falls back to PATH if not found in the standard install locations.

check_uvtools() {
    local bin=""
    for path in "/opt/UVtools/UVtoolsCmd" "/usr/local/bin/UVtoolsCmd"; do
        if [[ -x "$path" ]]; then bin="$path"; break; fi
    done
    [[ -z "$bin" ]] && bin=$(command -v UVtoolsCmd 2>/dev/null)

    if [[ -z "$bin" ]]; then
        echo -e "${RED}${MSG_UVTOOLS_MISSING}${NC}"
        echo "$MSG_UVTOOLS_DOWNLOAD"

        # Read /etc/os-release to suggest the right install method
        local did="" dlike=""
        if [[ -f /etc/os-release ]]; then
            did=$(grep -oP '(?<=^ID=).+' /etc/os-release | tr -d '"' | tr '[:upper:]' '[:lower:]')
            dlike=$(grep -oP '(?<=^ID_LIKE=).+' /etc/os-release | tr -d '"' | tr '[:upper:]' '[:lower:]')
        fi
        local combo="$did $dlike"

        echo ""
        if   [[ "$combo" == *"arch"* ]];                                              then echo -e "$MSG_HINT_ARCH"
        elif [[ "$combo" == *"fedora"* || "$combo" == *"rhel"* || "$combo" == *"centos"* ]]; then echo -e "$MSG_HINT_DNF"
        elif [[ "$combo" == *"debian"* || "$combo" == *"ubuntu"* ]];                  then echo -e "$MSG_HINT_APT"
        elif [[ "$combo" == *"opensuse"* || "$combo" == *"suse"* ]];                  then echo -e "$MSG_HINT_ZYPPER"
        else echo "$MSG_HINT_GENERIC"
        fi
        exit 1
    fi
}

check_uvtools

if [[ ! -f "$PY" ]]; then
    echo "$MSG_NO_PY $SCRIPT_DIR"
    exit 1
fi

# ── Progress display ──────────────────────────────────────────────────────────

SPIN=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')

draw_bar() {
    local cur=$1 tot=$2 width=40
    (( tot == 0 )) && return
    local pct=$(( cur * 100 / tot ))
    local filled=$(( cur * width / tot ))
    local bar=""
    for ((j=0; j<filled;  j++)); do bar+="█"; done
    for ((j=filled; j<width; j++)); do bar+="░"; done
    printf "\r  [%s] %3d%% (%d/%d)" "$bar" "$pct" "$cur" "$tot"
}

# Parses a single line from the Python process output and updates the display.
# Uses PAT_* variables set in the messages block so patterns stay in sync with
# the selected language.
handle_line() {
    local line="$1"
    local trimmed="${line#"${line%%[![:space:]]*}"}"

    if [[ "$line" =~ $PAT_LOADING ]]; then
        phase="loading"
        draw_bar "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
    elif [[ "$line" =~ $PAT_EXTRACT || "$line" =~ $PAT_LAYERS ]]; then
        printf "  %s\n" "$trimmed"
    elif [[ "$line" =~ "marching cubes" ]]; then
        # "marching cubes" is the same in both languages (technical term)
        [[ "$phase" == "loading" ]] && printf "\n"
        phase="marching"
    elif [[ "$line" =~ $PAT_STL ]]; then
        [[ "$phase" == "marching" ]] && printf "\r%-70s\r" " "
        [[ "$phase" == "loading"  ]] && printf "\n"
        echo -e "  ${GREEN}✓${NC} $trimmed"
        phase="done"
    elif [[ "$line" =~ "ERROR" ]]; then
        [[ "$phase" == "loading" || "$phase" == "marching" ]] && printf "\n"
        echo -e "  ${RED}✗${NC} $trimmed"
        phase="error"
    fi
}

# ── Main ──────────────────────────────────────────────────────────────────────

shopt -s nullglob
CTB_FILES=( *.ctb )
shopt -u nullglob

if (( ${#CTB_FILES[@]} == 0 )); then
    echo "$MSG_NO_CTB $(pwd)"
    exit 1
fi

TOTAL=${#CTB_FILES[@]}
echo -e "${BOLD}$(printf "$MSG_CONVERTING" "$TOTAL")${NC}"
echo ""

OK=0; FAIL=0

for i in "${!CTB_FILES[@]}"; do
    ctb="${CTB_FILES[$i]}"
    stl="${ctb%.ctb}.stl"
    num=$((i + 1))

    echo -e "${BLUE}[$num/$TOTAL]${NC} ${BOLD}$ctb${NC}"

    # Run Python in the background and tail its log file in real time
    tmplog=$(mktemp)
    python3 "$PY" "$ctb" "$stl" >"$tmplog" 2>&1 &
    py_pid=$!

    phase="init"
    spin_i=0
    exec 3<"$tmplog"   # open log on fd 3 to avoid subshell variable loss

    while kill -0 "$py_pid" 2>/dev/null; do
        # Drain any new lines without blocking (0.05s timeout)
        while IFS= read -r -t 0.05 line <&3; do
            handle_line "$line"
        done
        # Show spinner during the slow marching cubes phase
        if [[ "$phase" == "marching" ]]; then
            printf "\r  %s %s" "${SPIN[$spin_i]}" "$MSG_MARCHING"
            spin_i=$(( (spin_i + 1) % 10 ))
        fi
        sleep 0.1
    done

    # Drain any remaining lines after the process exits
    while IFS= read -r line <&3; do
        handle_line "$line"
    done
    exec 3<&-

    wait "$py_pid"
    py_exit=$?
    rm -f "$tmplog"

    if [[ -f "$stl" && $py_exit -eq 0 ]]; then
        ((OK++))
    else
        ((FAIL++))
        if [[ "$phase" != "error" && "$phase" != "done" ]]; then
            printf "\n"
            echo -e "  ${RED}✗${NC} $(printf "$MSG_CONV_FAILED" "$py_exit")"
        fi
    fi
    echo ""
done

echo "═══════════════════════════════════════════════════"
if (( FAIL == 0 )); then
    echo -e "  ${GREEN}${BOLD}$(printf "$MSG_COMPLETED" "$OK" "$TOTAL")${NC}"
else
    echo -e "  ${GREEN}OK: $OK${NC}  ${RED}${MSG_FAILED_LABEL}: $FAIL${NC}  Total: $TOTAL"
fi
