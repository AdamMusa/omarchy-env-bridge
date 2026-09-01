# Verification evidence

This directory groups the non-runtime material required to audit the bundled executable
artifacts while keeping the plugin package at the repository root compact.

- [Compiled QML provenance](QML_PROVENANCE.md)
- [Pinned reproducible build](REPRODUCIBLE_BUILD.md)
- [Shared runtime provenance](RUNTIME_PROVENANCE.md)
- [Exact generated QML and CMake source](qml-source/)
- [Independent rebuild and byte-comparison script](rebuild-qml-bundle.sh)

The GitHub workflow rebuilds both plugin-specific ELF files from this retained source,
requires byte equality with the shipped artifacts, verifies the shared runtime release,
and publishes signed artifact provenance for the exact commit.
