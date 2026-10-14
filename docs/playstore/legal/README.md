# Legal pages - Baqueano Natales

Paginas legales requeridas por Google Play Store y la Ley 21.719 de Chile.

## URLs publicas

- https://api.baqueanonatales.com/legal/privacidad
- https://api.baqueanonatales.com/legal/terminos
- https://api.baqueanonatales.com/legal/eliminar-cuenta

## Como se deployan

1. Editar los `.html` en este directorio.
2. Copiarlos al server:

       scp docs/playstore/legal/*.html deploy@104.129.59.151:/home/deploy/baqueano-natales/deploy/legal/

3. nginx los sirve automaticamente (bind mount + location /legal/).

**No requiere restart de nginx** — el bind mount refleja los cambios al instante.

## Documentos

| Archivo | Contenido |
|---|---|
| `privacidad.html` | Politica de Privacidad (Ley 19.628 + 21.719) |
| `terminos.html` | Terminos y Condiciones de Servicio |
| `eliminar-cuenta.html` | Instrucciones para eliminacion de cuenta |

## Compliance

- **Ley N 19.628**: sobre Proteccion de la Vida Privada
- **Ley N 21.719**: regula proteccion y tratamiento de datos personales (vigencia plena: 1 dic 2026)
- **Google Play**: politica de privacidad + mecanismo de eliminacion de cuenta