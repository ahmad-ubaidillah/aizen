#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-dev}"
OUTDIR="${2:-release}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PKG_DIR="${OUTDIR}/aizen-dashboard-ui"

cd "${ROOT_DIR}"
rm -rf "${OUTDIR}"
mkdir -p "${PKG_DIR}/bin"

cp -R build "${PKG_DIR}/build"
cp bin/aizen-dashboard-ui.js "${PKG_DIR}/bin/aizen-dashboard-ui.js"
cp package.json "${PKG_DIR}/package.json"
cp README.md "${PKG_DIR}/README.md"

cat > "${PKG_DIR}/aizen-dashboard-ui" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  if [[ "$SOURCE" != /* ]]; then
    SOURCE="$DIR/$SOURCE"
  fi
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
exec node "${SCRIPT_DIR}/bin/aizen-dashboard-ui.js" "$@"
EOF
chmod +x "${PKG_DIR}/aizen-dashboard-ui"

cat > "${PKG_DIR}/aizen-dashboard-ui.cmd" <<'EOF'
@echo off
set SCRIPT_DIR=%~dp0
node "%SCRIPT_DIR%bin\aizen-dashboard-ui.js" %*
EOF

tar -czf "${OUTDIR}/aizen-dashboard-ui-${VERSION}.tar.gz" -C "${OUTDIR}" aizen-dashboard-ui
(cd "${OUTDIR}" && zip -qr "aizen-dashboard-ui-${VERSION}.zip" aizen-dashboard-ui)

echo "Created:"
echo "  ${OUTDIR}/aizen-dashboard-ui-${VERSION}.tar.gz"
echo "  ${OUTDIR}/aizen-dashboard-ui-${VERSION}.zip"
