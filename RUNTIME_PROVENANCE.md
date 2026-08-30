# Omarchy UI runtime provenance

The bundled `omarchy-ui-runtime` is byte-for-byte the artifact published by an
independently attested Omarchy UI release. It is verified separately from the
earlier runtime bundled by the marketplace-approved Omarchy Phone plugin.

- Release: [`runtime-v0.1.4`](https://github.com/AdamMusa/omarchy-ui/releases/tag/runtime-v0.1.4)
- Runtime source revision: [`acc8938cda6298e946a2f63aaf00c67b1d402787`](https://github.com/AdamMusa/omarchy-ui/tree/acc8938cda6298e946a2f63aaf00c67b1d402787)
- Adapter release: [`omarchy-ui` `0.0.5`](https://rubygems.org/gems/omarchy-ui/versions/0.0.5) (`zui ~> 0.0.10`)
- Adapter gem SHA-256: `5f058fa53143dd56e79688a059465bc9837c85f5520214d6ef04edcb65a39fbe`
- Zui release: [`zui` `0.0.10`](https://rubygems.org/gems/zui/versions/0.0.10)
- Zui gem SHA-256: `ceec71d836c396b9944c85d5f472d34f14596a28a6dbf0c0b4687a01031627c0`
- Remote build: [GitHub Actions run `33296176108`](https://github.com/AdamMusa/omarchy-ui/actions/runs/33296176108)
- Signed provenance: [GitHub artifact attestation `43928397`](https://github.com/AdamMusa/omarchy-ui/attestations/43928397)
- SHA-256: `721e023e7868a0f2a85c9b63250042a97d981943d9e60b8d98cf7c781a87de6e`
- Size: `1,880,680` bytes
- Target: x86-64 Linux

Verify independently:

```bash
sha256sum --check omarchy-ui-runtime.sha256
gh attestation verify omarchy-ui-runtime --repo AdamMusa/omarchy-ui

verify_dir=$(mktemp -d)
gh release download runtime-v0.1.4 --repo AdamMusa/omarchy-ui   --pattern omarchy-ui-runtime --dir "$verify_dir"
cmp omarchy-ui-runtime "$verify_dir/omarchy-ui-runtime"
```

The release workflow pins all external source revisions, performs two clean builds,
requires byte-identical output, and signs the resulting artifact through GitHub attestations.
