# Omarchy UI runtime provenance

The bundled `omarchy-ui-runtime` is byte-for-byte the artifact published by an
independently attested Omarchy UI release. It is verified separately from the
earlier runtime bundled by the marketplace-approved Omarchy Phone plugin.

- Release: [`runtime-v0.1.0`](https://github.com/AdamMusa/omarchy-ui/releases/tag/runtime-v0.1.0)
- Source revision: [`9e102e14cdc90e1b077ec37a0646d43f104eb9e3`](https://github.com/AdamMusa/omarchy-ui/tree/9e102e14cdc90e1b077ec37a0646d43f104eb9e3)
- Remote build: [GitHub Actions run `32762173432`](https://github.com/AdamMusa/omarchy-ui/actions/runs/32762173432)
- Signed provenance: [GitHub artifact attestation `42660584`](https://github.com/AdamMusa/omarchy-ui/attestations/42660584)
- SHA-256: `c5a5aec0078465a14af991e7de90a13fe4294d120032a2519e1979ec8b1d6d8f`
- Size: `1,859,816` bytes
- Target: x86-64 Linux

Verify independently:

```bash
sha256sum --check omarchy-ui-runtime.sha256
gh attestation verify omarchy-ui-runtime --repo AdamMusa/omarchy-ui

verify_dir=$(mktemp -d)
gh release download runtime-v0.1.0 --repo AdamMusa/omarchy-ui   --pattern omarchy-ui-runtime --dir "$verify_dir"
cmp omarchy-ui-runtime "$verify_dir/omarchy-ui-runtime"
```

The release workflow pins all external source revisions, performs two clean builds,
requires byte-identical output, and signs the resulting artifact through GitHub attestations.
