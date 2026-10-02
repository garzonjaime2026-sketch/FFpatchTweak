# FFPatchTweak

Theos/Logos tweak source for Black Manager (`blackios`). Adds a one-time patch setup and persistent APLICAR / RESTAURAR ORIGINAL controls.

Target filename: `assetindexer.U6Zffc4YIR3DslNj3cXvYGAqz58~3D`

The tweak stores the selected patch and original backup in Application Support and calls Black Manager's existing `RootHelper` copy primitive. It attempts to resolve Free Fire's container dynamically from MobileContainerManager metadata.

Build requires Theos + iOS SDK. This repository is source only; it is not a signed IPA.
