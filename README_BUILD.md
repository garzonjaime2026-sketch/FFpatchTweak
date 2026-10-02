# FFPatchTweak build

Este proyecto contiene el tweak arm64 que añade a Black Manager el flujo de parche de una sola selección.

## Flujo
- CONFIGURAR PARCHE: selecciona el archivo una sola vez y lo guarda.
- APLICAR: guarda el original solo si todavía no existe y copia el parche al destino.
- RESTAURAR ORIGINAL: restaura la copia limpia sin sobrescribirla.

Destino: `Documents/contentcache/Compulsory/ios/gameassetbundles/avatar/assetindexer.U6Zffc4YIR3DslNj3cXvYGAqz58~3D`

## Compilación
Requiere Theos y un SDK de iOS. El workflow de GitHub Actions intenta instalar ambos y genera un `.deb` arm64.

**Importante:** el `.deb` es el tweak, no una IPA. Para obtener una IPA funcional hay que integrarlo en Black Manager con un método de inyección compatible con el jailbreak/loader del dispositivo y después firmar/empaquetar la app.
