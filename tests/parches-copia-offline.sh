#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 The Azerothcore-Single-Player contributors
# SPDX-License-Identifier: AGPL-3.0-or-later
# Un módulo restaurado desde mirrors/ (sin .git) recibe sus parches: aplicar, reaplicar sin duplicar y
# rechazar uno que no encaja. Antes se abortaba con «no está clonado» (CI-A, 09/11/2026), y la compilación
# mensual de GitHub fallaba justo en el caso para el que existen las copias: un upstream que ya no está.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_PARENT=$(cd "${TMPDIR:-/tmp}" && pwd -P)
TEST_DIR=$(mktemp -d "$TEST_PARENT/azeroth-parches-offline.XXXXXX")
cleanup() {
    case "$TEST_DIR" in "$TEST_PARENT"/azeroth-parches-offline.*) rm -rf -- "$TEST_DIR" ;; esac
}
trap cleanup EXIT
export AC_DIR="$TEST_DIR/core"
mkdir -p "$AC_DIR/modules/mod-prueba/src"
source "$ROOT/lib/utils.sh"
# El core de verdad es un repositorio git que CONTIENE modules/: la prueba lo reproduce, porque
# `git apply` tomaría ahí las rutas del parche como relativas a su raíz.
git -C "$AC_DIR" init -q
DIR="$AC_DIR/modules/mod-prueba"
printf 'original\n' > "$DIR/src/a.cpp"
# Se escribe el parche contra un repositorio auxiliar y se deja la copia SIN .git.
ORIGEN="$TEST_DIR/origen"
mkdir -p "$ORIGEN/src"
printf 'original\n' > "$ORIGEN/src/a.cpp"
git -C "$ORIGEN" init -q
git -C "$ORIGEN" add -A
git -C "$ORIGEN" -c user.name=Test -c user.email=test@localhost commit -qm base
printf 'parcheado\n' > "$ORIGEN/src/a.cpp"
git -C "$ORIGEN" diff > "$TEST_DIR/01-fix.patch"
test ! -e "$DIR/.git"

apply_module_patches mod-prueba "$TEST_DIR/01-fix.patch"
test "$(cat "$DIR/src/a.cpp")" = parcheado
apply_module_patches mod-prueba "$TEST_DIR/01-fix.patch"          # idempotente
test "$(cat "$DIR/src/a.cpp")" = parcheado

printf 'otra cosa\n' > "$DIR/src/a.cpp"
if apply_module_patches mod-prueba "$TEST_DIR/01-fix.patch"; then
    echo 'ERROR: aceptó un parche que no encaja con la copia' >&2
    exit 1
fi
if apply_module_patches mod-ausente "$TEST_DIR/01-fix.patch"; then
    echo 'ERROR: aceptó parches para un módulo que no está' >&2
    exit 1
fi
echo 'Parches sobre copia offline sin git: aplicación, idempotencia, rechazo y módulo ausente OK'
