#!/bin/sh
# apply-usb3-fixes.sh — Routerich AX3000-V1 USB 3.0 fixes
# Применяется поверх chasey-dev версии 117-complete-mt7981b-dtsi.patch
#   1. compatible = "mediatek,mt7981" → "mediatek,mt7981-tphy" (u3port0)
#   2. Добавляет nvmem-cells (comb_intr_p0, comb_rx_imp_p0, comb_tx_imp_p0)
#   3. Добавляет nvmem-cell-names
#   4. recountdiff — пересчёт счётчиков ханков
set -e

PATCH="${1:-target/linux/mediatek/patches-6.12/117-complete-mt7981b-dtsi.patch}"

if [ ! -f "$PATCH" ]; then
    echo "ERROR: $PATCH not found"
    exit 1
fi

# Уже есть фикс? Ничего не делаем.
if grep -q 'mediatek,mt7981-tphy' "$PATCH" && grep -q 'nvmem-cell-names = "intr", "rx_imp", "tx_imp"' "$PATCH"; then
    echo "OK: USB 3.0 fixes already present in $PATCH (chasey-dev upstream has them)"
    exit 0
fi

cp "$PATCH" /tmp/117.orig

# --- Модификация через awk (структурная, не по номерам строк) ---
awk '
BEGIN { found_compat = 0; fixed = 0; }
/^\+[[:space:]]*compatible = "mediatek,mt7981",$/ && !found_compat {
    match($0, /^\+[[:space:]]*/)
    indent = substr($0, 2, RLENGTH - 1)
    sub(/mediatek,mt7981",$/, "mediatek,mt7981-tphy\",")
    found_compat = 1
    print
    next
}
found_compat && !fixed && /^\+[[:space:]]+"mediatek,generic-tphy-v2";$/ {
    print
    match($0, /^\+[[:space:]]*/)
    cont_indent = substr($0, 2, RLENGTH - 1)
    print "+" indent "nvmem-cells = <&comb_intr_p0>,"
    print "+" cont_indent "<&comb_rx_imp_p0>,"
    print "+" cont_indent "<&comb_tx_imp_p0>;"
    print "+" indent "nvmem-cell-names = \"intr\", \"rx_imp\", \"tx_imp\";"
    fixed = 1
    next
}
{ print }
' /tmp/117.orig > "$PATCH"

# --- Пересчёт счётчиков ханков (@@ -X,Y +Z,W @@) ---
if command -v recountdiff >/dev/null 2>&1; then
    recountdiff "$PATCH" > /tmp/117.fixed
    mv /tmp/117.fixed "$PATCH"
    echo "OK: recountdiff applied"
else
    echo "ERROR: recountdiff not found (install patchutils)"
    cp /tmp/117.orig "$PATCH"
    exit 1
fi

# --- Валидация ---
if ! grep -q 'mediatek,mt7981-tphy' "$PATCH"; then
    echo "ERROR: compatible = mediatek,mt7981-tphy not found after fix"
    cp /tmp/117.orig "$PATCH"
    exit 1
fi
if ! grep -q 'nvmem-cell-names = "intr", "rx_imp", "tx_imp"' "$PATCH"; then
    echo "ERROR: nvmem-cell-names not found after fix"
    cp /tmp/117.orig "$PATCH"
    exit 1
fi

echo "OK: USB 3.0 fixes applied to $PATCH"
grep -n 'mediatek,mt7981-tphy\|nvmem-cell\|^@@' "$PATCH" | head -20
