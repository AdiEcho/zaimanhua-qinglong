#!/usr/bin/env sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CACHE_DIR="${ROOT_DIR}/.cache"
MARKER_FILE="${CACHE_DIR}/playwright_chromium.ready"
DEPS_MARKER_FILE="${CACHE_DIR}/playwright_system_deps.ready"
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

can_install_system_deps() {
  [ "${PLAYWRIGHT_INSTALL_SYSTEM_DEPS:-1}" = "1" ] || return 1
  [ "$(uname -s 2>/dev/null || echo unknown)" = "Linux" ] || return 1
  [ "$(id -u 2>/dev/null || echo 1)" = "0" ] || return 1
  command -v apt-get >/dev/null 2>&1 || return 1
  return 0
}

deps_ready() {
  if can_install_system_deps; then
    if [ -f "${DEPS_MARKER_FILE}" ]; then
      return 0
    fi
    return 1
  fi
  return 0
}

if [ -f "${MARKER_FILE}" ] && has_chromium_dir && deps_ready; then
  exit 0
fi

if has_chromium_dir && deps_ready; then
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
  if [ -f "${MARKER_FILE}" ] && has_chromium_dir && deps_ready; then
    exit 0
  fi
  mkdir "${LOCK_DIR}"
  trap 'rmdir "${LOCK_DIR}"' EXIT
fi

if [ -f "${MARKER_FILE}" ] && has_chromium_dir && deps_ready; then
  exit 0
fi

if has_chromium_dir && deps_ready; then
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

if can_install_system_deps && [ ! -f "${DEPS_MARKER_FILE}" ] && has_chromium_dir; then
  echo "[INIT] 检测到 Linux(root+apt)，开始安装 Playwright 系统依赖..."
  if "${PYTHON_BIN}" -m playwright install-deps chromium; then
    touch "${DEPS_MARKER_FILE}"
    echo "[INIT] Playwright 系统依赖安装完成"
  else
    echo "[WARN] Playwright 系统依赖安装失败，可手动执行:"
    echo "       ${PYTHON_BIN} -m playwright install --with-deps chromium"
  fi
fi

if ! has_chromium_dir; then
  if can_install_system_deps; then
    echo "[INIT] 首次执行，开始安装 Playwright Chromium（含系统依赖）..."
    if "${PYTHON_BIN}" -m playwright install --with-deps chromium; then
      touch "${DEPS_MARKER_FILE}"
    else
      echo "[WARN] 带系统依赖安装失败，回退为仅安装 Chromium..."
      "${PYTHON_BIN}" -m playwright install chromium
    fi
  else
    echo "[INIT] 首次执行，开始安装 Playwright Chromium..."
    "${PYTHON_BIN}" -m playwright install chromium
  fi
else
  echo "[INIT] Playwright Chromium 已存在，跳过浏览器下载"
fi

if ! has_chromium_dir; then
  echo "[ERROR] Playwright Chromium 安装失败，未检测到 chromium-* 目录"
  exit 1
fi

touch "${MARKER_FILE}"
echo "[INIT] Playwright Chromium 安装完成"
