# Brand assets - Baqueano Natales

Assets oficiales de marca, versionados para evitar perder el fuente.

## Archivos

### Fuentes vectoriales (SVG)

| Archivo | Dimensiones | Uso |
|---|---|---|
| `baqueano_icono.svg` | 512×512 | **Icono principal** de la app (fondo gradiente azul + estrellas doradas) |
| `baqueano_icono_mono.svg` | 512×512 | Version monocromatica (notifs FCM, favicons) |
| `baqueano_logo.svg` | 1100×320 | Wordmark con texto "Baqueano Natales" |
| `baqueano_logo_oscuro.svg` | 1100×320 | Wordmark dark mode |

### PNGs generados

| Archivo | Dimensiones | Uso |
|---|---|---|
| `play_store_icon_512.png` | 512×512, 24-bit sin alpha | **Play Console** - icono de la ficha de Play Store |
| `app_icon_master_1024.png` | 1024×1024 | Master para futuras exportaciones (iOS, web, etc.) |

## Como regenerar los PNGs desde el SVG

Con Chrome headless (funciona sin instalar nada):

    $svg = Get-Content baqueano_icono.svg -Raw
    $svgSquare = $svg -replace '(<svg[^>]*>)', '$1<rect width="512" height="512" fill="#091625"/>'
    $tempSvg = "$env:TEMP\icon_square.svg"
    [System.IO.File]::WriteAllText($tempSvg, $svgSquare, [System.Text.UTF8Encoding]::new($false))

    & "C:\Program Files\Google\Chrome\Application\chrome.exe" `
        --headless=new --disable-gpu --hide-scrollbars `
        --force-device-scale-factor=1 --virtual-time-budget=5000 `
        "--screenshot=$PWD\play_store_icon_512.png" `
        "--window-size=512,512" `
        "file:///$($tempSvg -replace '\\','/')"

**Por que el `<rect>` inyectado**: el SVG original tiene esquinas redondeadas (rx=114) que quedan transparentes. Play Console exige sin transparencia, asi que rellenamos con el color mas oscuro del gradiente (`#091625`).

## Colores de marca (extraidos del SVG)

| Uso | Hex |
|---|---|
| Gradiente fondo (inicio) | `#143F5C` |
| Gradiente fondo (medio) | `#0E2B41` |
| Gradiente fondo (fin) | `#091625` |
| Dorado estrellas (inicio) | `#FFEBB0` |
| Dorado estrellas (medio) | `#FFC738` |
| Dorado estrellas (fin) | `#F0A200` |

## Pendientes

- [ ] Exportar feature graphic 1024×500 (para Play Store production)
- [ ] Exportar screenshots 1080×1920 (min 2, recomendado 4)
- [ ] Favicon para web (32×32, 192×192)
- [ ] Copiar a `flutter/assets/brand/` si la app lo necesita en runtime