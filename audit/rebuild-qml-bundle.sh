#!/usr/bin/env bash
set -euo pipefail

repo_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source_root="$repo_root/audit/qml-source"
report="$repo_root/audit/omarchy-ui-qml-bundle.json"
qt_cmake=${QT_CMAKE:-/usr/lib/qt6/bin/qt-cmake}
qtpaths=${QTPATHS:-/usr/lib/qt6/bin/qtpaths}
cmake_command=${CMAKE:-cmake}
jq_command=${JQ:-jq}

if [[ $# -gt 1 ]]; then
  echo "usage: $0 [BUILD_DIRECTORY]" >&2
  exit 2
fi

for command in "$qt_cmake" "$qtpaths" "$cmake_command" "$jq_command" sha256sum cmp find stat; do
  command -v "$command" >/dev/null || {
    echo "required build tool not found: $command" >&2
    exit 1
  }
done

[[ -f "$source_root/CMakeLists.txt" ]] || {
  echo "retained QML source snapshot is missing" >&2
  exit 1
}

expected_qt=$("$jq_command" -r '.qt_version' "$report")
actual_qt=$("$qtpaths" --query QT_VERSION)
[[ "$actual_qt" == "$expected_qt" ]] || {
  echo "Qt version mismatch: expected $expected_qt, found $actual_qt" >&2
  exit 1
}

mapfile -t source_files < <(
  cd "$source_root"
  find . -type f \( -name '*.qml' -o -path './Fonts/*' -o -path './Controls/qmldir' -o -path './Theme/qmldir' \) \
    -printf '%P\n' | LC_ALL=C sort
)

qml_count=$(printf '%s\n' "${source_files[@]}" | grep -c '\.qml$')
expected_qml_count=$("$jq_command" -r '.source_files' "$report")
[[ "$qml_count" == "$expected_qml_count" ]] || {
  echo "QML source count mismatch: expected $expected_qml_count, found $qml_count" >&2
  exit 1
}

source_bytes=0
for relative in "${source_files[@]}"; do
  source_bytes=$((source_bytes + $(stat -c '%s' "$source_root/$relative")))
done
expected_source_bytes=$("$jq_command" -r '.source_bytes' "$report")
[[ "$source_bytes" == "$expected_source_bytes" ]] || {
  echo "QML source size mismatch: expected $expected_source_bytes, found $source_bytes" >&2
  exit 1
}

fingerprint=$(
  {
    printf 'omarchy-ui-qml-bundle\0%s\0qt\0%s\0' \
      "$("$jq_command" -r '.format_version' "$report")" "$actual_qt"
    for relative in "${source_files[@]}"; do
      printf '%s\0' "$relative"
      command cat "$source_root/$relative"
      printf '\0'
    done
  } | sha256sum | cut -d ' ' -f 1
)
expected_fingerprint=$("$jq_command" -r '.source_fingerprint' "$report")
[[ "$fingerprint" == "$expected_fingerprint" ]] || {
  echo "QML source fingerprint mismatch: expected $expected_fingerprint, found $fingerprint" >&2
  exit 1
}

temporary_build=false
if [[ $# -eq 1 ]]; then
  build_root=$1
  mkdir -p "$build_root"
else
  build_root=$(mktemp -d)
  temporary_build=true
fi

cleanup() {
  if [[ "$temporary_build" == true ]]; then
    rm -r -- "$build_root"
  fi
}
trap cleanup EXIT

export LC_ALL=C.UTF-8
export SOURCE_DATE_EPOCH=1
export TZ=UTC

"$qt_cmake" -S "$source_root" -B "$build_root" -G Ninja -DCMAKE_BUILD_TYPE=Release
"$cmake_command" --build "$build_root" --parallel

while IFS=$'\t' read -r relative expected_sha; do
  built="$build_root/$relative"
  shipped="$repo_root/$relative"
  [[ -f "$built" && -f "$shipped" ]] || {
    echo "missing built or shipped artifact: $relative" >&2
    exit 1
  }
  [[ "$(sha256sum "$built" | cut -d ' ' -f 1)" == "$expected_sha" ]] || {
    echo "rebuilt artifact digest mismatch: $relative" >&2
    exit 1
  }
  cmp "$built" "$shipped"
done < <("$jq_command" -r '.artifacts[] | [.path, .sha256] | @tsv' "$report")

(
  cd "$repo_root"
  sha256sum --check audit/omarchy-ui-qml-bundle.sha256
)

echo "Reproduced the checked-in QML bundle from audit/qml-source with Qt $actual_qt."
