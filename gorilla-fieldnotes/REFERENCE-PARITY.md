# Reference parity — mandatory audit before calling the project complete

## Reference pages

- https://rain.tailb80876.ts.net/pages/linux.html
- https://rain.tailb80876.ts.net/pages/pentest.html
- https://rain.tailb80876.ts.net/pages/opsec.html
- https://rain.tailb80876.ts.net/pages/geoint.html
- https://rain.tailb80876.ts.net/pages/osint.html

## What was verifiable during the initial audit (2026-10-22)

- Linux states that it contains 301 active/notable distributions grouped by family. The current starter implementation contains only 15 Linux resources and is not at parity.
- OPSEC states that it contains 42 tools/resources. The current starter implementation contains only 13 OPSEC resources and uses a different category structure.
- GEOINT states that it has 9 geospatial tools and 23 external platforms/services. The page also includes interactive utilities (IP intelligence, interactive map, coordinate conversion, distance/bearing, timezone/weather, altitude/horizon, reverse geocoding, sun position, and bulk IP geolocation). The current starter implementation contains only 13 GEOINT resources and does not implement those tools; it is not at parity.
- OSINT states that it contains 100+ tools. The current starter implementation contains only 15 OSINT resources and is not at parity.
- Pentest redirected an unauthenticated visitor to the reference website's login page. Its underlying directory and categories could not be inspected in the initial public audit. Do not bypass this login or invent its contents; use an authorized session or ask the project owner for a permitted export.

## Hard rule

The current website is a UI/authentication starter, not a verified content clone. Do not describe it as an exact replica until a machine-readable inventory of each accessible reference has been captured and the diff reports zero missing and zero unexpected entries. Record the exact categories, item order, titles, official URLs, metadata and interactive utilities. Preserve the source snapshot date. If the Pentest inventory cannot be obtained with authorized access, report it as a blocking dependency rather than guessing.
