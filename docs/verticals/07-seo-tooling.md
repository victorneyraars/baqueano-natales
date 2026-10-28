# 07 - SEO Tooling y Automatizacion

Sistema de auditoria SEO centralizado en el servidor.

## Stack

| Herramienta | Funcion |
|---|---|
| PageSpeed Insights API | Performance, LCP, CLS, SEO, A11y |
| Pa11y | Accesibilidad WCAG 2.1 AA |
| Unlighthouse | Lighthouse completo (--full) |
| broken-link-checker | Enlaces rotos internos |
| html-validate | Validacion HTML5 |

## Configuracion

- PATH: ~/.npm-global/bin y ~/seo-tools/bin
- API Key: PAGESPEED_API_KEY en .bashrc
- Chrome Pa11y: PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

## Uso

seo-audit <url>              Modo fast (~30s)
seo-audit <url> --full       Modo completo (~3min)
seo-audit <url> --pagespeed  Solo PageSpeed
seo-audit <url> --a11y       Solo Pa11y
seo-audit <url> --links      Solo enlaces
seo-audit <url> --lighthouse Solo Unlighthouse
seo-audit-all                Audita los 3 sitios

## Estado actual (2026-10-28)

| Site | Perf | A11y | BP | SEO | LCP | CLS |
|---|---|---|---|---|---|---|
| rentacarvasquez.com | 97 | 95 | 100 | 100 | 2109ms | 0.000 |
| baqueanonatales.com | Pendiente | - | - | - | - | - |
| sealquilamarido.com | Pendiente | - | - | - | - | - |

## Reports

/home/deploy/seo-tools/reports/YYYY-MM-DD_HH-MM/:
- pagespeed.json, accessibility.json, links.txt
- unlighthouse/ (solo --full)

## Cron

Diario a las 3 AM: seo-audit-all >> reports/cron.log
