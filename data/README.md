# Source data and transformation notes

Original filename: `CX_Testdata_v1.7.0_PartInstance-reduced.json`

Source supplied by the user, associated with the Eclipse Tractus-X Item Relationship Service repository:
https://github.com/eclipse-tractusx/item-relationship-service/blob/main/local/testing/testdata/CX_Testdata_v1.7.0_PartInstance-reduced.json

This package copies the uploaded bytes unchanged to `CX_Testdata_v1.7.0_PartInstance-reduced.json`.

- Size: 6,064,253 bytes
- SHA-256: `3513041264793ae81d8e4a21cb9fd6127d7f484ec4b3b98f2425d0963dbd48af`
- Original upstream commit: not provided with the upload; not inferred from the current main branch.
- This is upstream test data; the original content remains attributed to its upstream contributors.
- Upstream license and notices: https://github.com/eclipse-tractusx/item-relationship-service
  The upload did not include the repository license/notice files. Verify and include
  the applicable upstream notices before publishing a redistribution; this package
  does not assert a new license over the supplied data.

The source contains 494 items, 465 described by SerialPart 3.0.0 and 29 by Batch 3.0.0.
The loader extracts 765 relationships from SingleLevelBomAsBuilt 3.0.0 only.
Five referenced child IDs are absent from the item list and become explicitly marked
placeholder rows. Source country codes and dates are retained literally.

The top-level policies and all other aspect models remain in the source file but
are not implemented as access controls or mapped into the two demonstration tables.
