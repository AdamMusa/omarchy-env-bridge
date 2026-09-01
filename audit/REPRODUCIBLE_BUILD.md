# Reproducible QML build

The exact generated QML build input for the shipped native module is retained in
`audit/qml-source/`. It includes the tree-shaken Zui/Omarchy host graph and the generated
`CMakeLists.txt`; no regeneration from a moving dependency is part of reproduction.

## Pinned inputs

- Omarchy UI `v0.0.9` at `12d40f6cff76d2a89b391ffe40ce7839f83825ea`
- Zui `0.0.10` at `74b48f047d5811b53667e5cc0fb7f0bb63548764`
- Qt `6.11.2`, GCC `16.2.1`, binutils `2.47`, CMake `4.4.2`, and Ninja `1.13.2`
- Arch Linux package snapshot `2026/08/23`
- Quickshell package `quickshell-git-0.3.0.r20.g28771c7-2-x86_64.pkg.tar.zst`,
  SHA-256 `048cc4a3d54bd164b8589f756eb075f0688d9bd24949b734a5edb4e217b8ba30`
- Arch Linux container image
  `docker.io/library/archlinux@sha256:818793c894d94534c22f2149154a39ebaee57e4e67321023b0866a1d5722036c`
- `LC_ALL=C.UTF-8`, `TZ=UTC`, and `SOURCE_DATE_EPOCH=1`

The Quickshell package supplies the QML type descriptions used by Qt's AOT compiler.
CI verifies its digest before extracting it.

## Verify locally

On an environment with the pinned toolchain and Quickshell QML module:

```bash
audit/rebuild-qml-bundle.sh
```

The script independently recomputes the source fingerprint, source count, and source
byte count from `audit/qml-source/`; builds the module in a fresh directory; verifies each
reported SHA-256 digest; and byte-compares each rebuilt ELF with its checked-in copy.

The `reproduce_qml` CI job performs the same check in the pinned container and
Arch snapshot. After a successful push to `main`, GitHub creates signed build
provenance for both plugin-specific ELF artifacts. The separate runtime verification
job checks the shared `omarchy-ui-runtime` against its immutable release asset and
GitHub attestation.

To verify an ELF attestation after the workflow has completed:

```bash
gh attestation verify path/to/library.so --repo AdamMusa/REPOSITORY
```
