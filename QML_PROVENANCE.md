# Compiled QML provenance

Omarchy UI generated this package's native Qt module from the tree-shaken Zui and
Omarchy host QML graph. The exact generated source graph and CMake build definition are
retained in `qml-source/` for independent audit and byte-for-byte reproduction.

- Format: `qt-aot-qml-module` version 1
- Qt: `6.11.2`
- Module: `OmarchyUI.Bundles.B4048fb4d5d26cc368994`
- Source fingerprint: `4048fb4d5d26cc368994c1c1f349de512154a69e7a93dbcfc678f60c4c716b78`

## Artifacts

- `OmarchyUI/Bundles/B4048fb4d5d26cc368994/libomarchy_ui_bundle_b4048fb4d5d26cc368994.so` — `6013fbc761207ab38ad324cf399a156989073f218d0a2a73c4ae92919f11bb33`
- `OmarchyUI/Bundles/B4048fb4d5d26cc368994/libomarchy_ui_bundle_b4048fb4d5d26cc368994plugin.so` — `dca45911081f1ec14ab10386910034bf787df37ee824ac3f3449cad9ce7b072a`

Verify the packaged libraries from the plugin directory:

```bash
sha256sum --check omarchy-ui-qml-bundle.sha256
```

Rebuild the checked-in libraries from the retained sources and compare every byte:

```bash
scripts/rebuild-qml-bundle.sh
```

The pinned toolchain, CI process, and GitHub artifact-attestation flow are documented in
[`REPRODUCIBLE_BUILD.md`](REPRODUCIBLE_BUILD.md).

`Service.qml`, `Panel.qml`, and `BarWidget.qml` are the minimal loader shims required for the
plugin kinds declared in `manifest.json`. Application UI lives in the compiled
module recorded by `omarchy-ui-qml-bundle.json`.
