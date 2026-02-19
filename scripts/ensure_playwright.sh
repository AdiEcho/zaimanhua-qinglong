#!/usr/bin/env sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CACHE_DIR="${ROOT_DIR}/.cache"
MARKER_FILE="${CACHE_DIR}/playwright_chromium.ready"
LOCK_DIR="${CACHE_DIR}/playwright_install.lock"

mkdir -p "${CACHE_DIR}"
export PLAYWRIGHT_BROWSERS_PATH="${PLAYWRIGHT_BROWSERS_PATH:-${CACHE_DIR}/ms-playwright}"

has_chromium_dir() {
  for dir in "${PLAYWRIGHT_BROWSERS_PATH}"/chromium-*; do
    if [ -d "${dir}" ]; then
      return 0
    fi
  done
  return 1
}

if [ -f "${MARKER_FILE}" ]; then
  exit 0
fi

if has_chromium_dir; then
  touch "${MARKER_FILE}"
  exit 0
fi

if mkdir "${LOCK_DIR}" 2>/dev/null; then
  trap 'rmdir "${LOCK_DIR}"' EXIT
else
  echo "[INIT] 等待其他任务完成 Playwright 初始化..."
  while [ -d "${LOCK_DIR}" ]; do
    sleep 1
  done
  if [ -f "${MARKER_FILE}" ]; then
    exit 0
  fi
  mkdir "${LOCK_DIR}"
  trap 'rmdir "${LOCK_DIR}"' EXIT
fi

if [ -f "${MARKER_FILE}" ]; then
  exit 0
fi

if has_chromium_dir; then
  touch "${MARKER_FILE}"
  exit 0
fi

if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN="python3"
elif command -v python >/dev/null 2>&1; then
  PYTHON_BIN="python"
else
  echo "[ERROR] 未找到 python3/python，无法执行 playwright install"
  exit 1
fi

echo "[INIT] 首次执行，开始安装 Playwright Chromium..."
"${PYTHON_BIN}" -m playwright install chromium
touch "${MARKER_FILE}"
echo "[INIT] Playwright Chromium 安装完成"
