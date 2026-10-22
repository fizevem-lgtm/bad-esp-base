# DEVIN — SWE-2 HIGH — COMBINED PROJECT SUMMARY + EXECUTION PROMPT

## PROJECT SUMMARY (READ FIRST)

You are working on **Gorilla / Fieldnotes**, an independent, French-language technical resource archive currently built as a lightweight static multi-page website and intended for Netlify. The visual identity is understated, near-black/graphite, with restrained electric blue and an original gorilla emblem. It must not look like a stereotypical hacker template.

The site has five target informational pages:

- https://rain.tailb80876.ts.net/pages/linux.html
- https://rain.tailb80876.ts.net/pages/pentest.html
- https://rain.tailb80876.ts.net/pages/opsec.html
- https://rain.tailb80876.ts.net/pages/geoint.html
- https://rain.tailb80876.ts.net/pages/osint.html

This repository now includes a shared-access-key login backed by a Netlify Edge Function, a signed short-lived HttpOnly session cookie, a Gorilla identity, and starter resource lists. **The current content is not yet in exact parity with the references.** Do not mistake the current 69 curated items for a complete port.

## MISSION

Inspect the existing repository, research and inventory all five reference pages, then improve the code directly. Deliver a working, tested, secure, Netlify-deployable implementation. Do not stop after writing a plan or recommendations. Keep a concise progress log and continue through implementation and verification.

The non-negotiable inventory requirement is **exact parity with the supplied reference pages: the same resource entries, names, categories, order, official destinations, labels/metadata, and visible utilities — no missing items and no additional items.** Do not substitute resources you personally prefer or inflate the collection with invented entries. Reproduce factual inventory metadata faithfully, but do not copy long descriptive prose from the reference pages verbatim: write concise, original descriptions that preserve meaning. Treat this as an auditable port of the resource inventory and behavior, not a new directory or a verbatim reproduction of editorial text.

---

# EXECUTION INSTRUCTIONS

## 1. Inspect before editing

1. Inspect all files, routes, scripts, tests, Netlify configuration, and current resource markup/data before changing architecture.
2. Preserve working features and the existing lightweight approach unless a specific requirement cannot be met with it.
3. Identify the true source of the resources on each reference page. Inspect rendered DOM and linked JavaScript/data sources when legitimately accessible; do not rely only on a truncated search-result excerpt or the first visible screen.
4. Use current official Netlify documentation to verify Edge Function routing, runtime environment variables, session behavior, deploy requirements, and security headers before changing the deployment configuration.
5. Never claim an inspection, link check, test, or browser run occurred unless it actually did.

## 2. Exact source-parity audit — highest priority

For every reference page, produce a machine-readable, ordered snapshot under `reference-data/` and a report named `SOURCE-PARITY-REPORT.md`.

For every resource entry preserve the source's:
- exact display name, including punctuation and accents;
- exact category and subcategory label;
- original position/order within its category;
- exact outbound `href` / destination URL, including its real path and parameters;
- badges, tags, ranking/evaluation labels, and other factual displayed metadata; preserve the description's meaning in concise original wording rather than copying source prose verbatim;
- any meaningful source-provided grouping or annotation.

Preserve intentional duplicates if the source displays the same destination more than once or in multiple categories. Do not silently deduplicate, normalize away distinct query parameters, change categories, reorder by personal preference, rewrite factual labels, or add resources not present in the snapshot. Match the source inventory and information architecture exactly; write any explanatory prose in original wording. Optional UI improvements must not change the resource inventory.

Create a script/test that compares the implemented content against the captured reference snapshot, category by category and in order. The final diff must report:
- missing resources: **0**;
- unexpected resources: **0**;
- category/group mismatches: **0**;
- order mismatches: **0**;
- URL mismatches: **0**;
- missing interactive utilities: **0**.

Store the source capture timestamp and how the content was retrieved. Do not treat advertised totals as a substitute for parsing and comparing the actual entries.

### Reference counts/behaviors known from an initial public inspection

Use these as sanity checks, then verify them against the current pages:
- Linux states that it contains **301 active/notable distributions grouped by family**.
- OPSEC states that it contains **42 tools/resources** organized into sections.
- GEOINT states that it contains **9 geospatial tools plus 23 external platforms/services**. The page also exposes operational utilities such as IP intelligence, an interactive map, coordinate conversion (DD/DMS/UTM), distance/bearing, timezone/weather lookup, altitude/horizon, reverse geocoding, sun position, and bulk IP geolocation. Verify the exact count and full behavior from the current source rather than copying this list blindly.
- OSINT states that it contains **100+ tools**, with multiple topical categories and target-aware workflows.
- Pentest redirected an unauthenticated visitor to a login page during the initial audit. Its private resource list could not be verified publicly.

### Authorized-access blocker — do not bypass

Do not brute-force, evade, exploit, or bypass the source site's Pentest login. If the existing Devin/browser session already has legitimate access, inspect it through that session. Otherwise continue completing the four publicly accessible inventories, mark Pentest parity as **BLOCKED — authorized source content unavailable**, and identify the exact permitted artifact needed (for example, an owner-provided HTML/data export or authorized access). Never fabricate the hidden categories or resource list. Do not claim 100% parity while Pentest remains blocked.

## 3. Gorilla visual identity

Remove all Sonic/SEGA branding and all obsolete Sonic references from UI, metadata, CSS comments, manifest, README, favicon paths, and page copy. The project should consistently be branded **Gorilla / Fieldnotes** (or the existing established project lockup if the repository already uses another gorilla name consistently).

Use the original gorilla emblem in the header, login page, favicon, manifest, and footer. Keep the brand understated, credible, and technically editorial.

Visual requirements:
- near-black/graphite base, warm-white text, muted gray secondary text, restrained electric blue;
- clear typography and compact, useful metadata;
- subtle separators and functional hover/focus states;
- no Matrix rain, skulls, anonymous masks, hooded stock photos, random hex, fake terminal logs, excessive neon, unnecessary particles, or theatrical hacker copy;
- no generic AI template cards where a compact categorized index is more appropriate;
- no unnecessary animation, and respect reduced-motion preferences.

## 4. Access-key authentication — security is server-side

The archive must only serve the homepage, protected HTML pages, and all content data to a visitor with a valid access key. The frontend-only gate is unacceptable.

Keep the one-shared-key model (no accounts, email sign-up, or user database), but describe it honestly: it proves possession of a shared key, not an individual's identity.

Audit and improve the existing implementation. At minimum:
- All protected HTML routes and any content API/data source must be checked server-side at Netlify Edge before content is returned.
- `/login.html` and only necessary non-sensitive static assets may be unauthenticated.
- Store `ACCESS_KEY_SHA256` and an independent, high-entropy `SESSION_SECRET` as Netlify environment variables in the scope required by Edge Functions. Never commit either secret; never place secrets in `netlify.toml`, JS, HTML, localStorage, sessionStorage, query strings, client-visible build variables, or logs.
- Hash the candidate key with Web Crypto SHA-256 and compare the digest safely against `ACCESS_KEY_SHA256`. Validate the configured digest format and fail closed if variables are absent/malformed.
- Create a cryptographically signed, short-lived session cookie. Use `HttpOnly`, `SameSite=Strict`, `Path=/`, and `Secure` in HTTPS deployments. Use the `__Host-` prefix on HTTPS only when its required cookie rules are all satisfied. No `Domain` attribute.
- Protect against open redirects; `next` must be a same-origin relative path only.
- Validate same-origin login/logout requests and content type/size. Avoid leaking whether a secret/config is correct in server logs or client messages.
- Ensure logout invalidates the cookie and returns to the login page.
- Add no-store headers for authenticated HTML, noindex headers, a robots policy appropriate for a private archive, a strict CSP, frame protection, `nosniff`, referrer policy, and HSTS where appropriate.
- Missing or invalid server configuration must return a closed/blocked response, never silently serve protected pages.
- Add or document provider-level rate limiting/WAF on the login endpoint if available. Do not claim a module-local counter is global or durable. Use a randomly generated high-entropy access key.
- Do not expose resource HTML or content data in public JS/assets/source maps.
- Do not add third-party analytics, trackers, or unnecessary external auth dependencies.

Keep the Netlify deploy flow honest: test this project through Git-connected Netlify deployment or Netlify CLI with the Edge Function enabled. A plain static drag-and-drop publish must not be described as fully protected if Edge Functions are not deployed. Review the current official Netlify docs, because runtime env scope and deploy behavior can change.

## 5. User-facing behavior

- French UI and explanatory copy; keep canonical technical names in their normal form.
- Login view consistent with Gorilla branding, accessible input, show/hide key button, inline error/status messages, keyboard support, and no “remember me” or client-side key storage.
- Logout control available from protected pages.
- After successful authentication, return to the validated originally requested route.
- Search, filters, copy-link actions, compact view, expandable tools, map/calculation utilities, and input-to-resource workflows must behave like the reference pages where they exist. Do not add controls that do nothing.
- Retain source content and ordering while applying the site’s own understated visual design.

## 6. Engineering and compatibility

- Keep the site lightweight and maintainable.
- Reuse existing architecture where it works. Avoid introducing React or a database merely for fashion.
- Split resource data into clear, validated machine-readable files when this improves exact parity and maintenance.
- Use semantic HTML, keyboard navigation, visible focus rings, ARIA labels, responsive layouts, accessible empty states, and reduced-motion support.
- Do not invent URLs or replace broken source destinations. Record link health separately; preserving the original snapshot and reporting a dead source URL is preferable to silently changing the inventory.
- Preserve necessary metadata and correct direct route/refresh behavior.
- Make sure deploy configuration does not accidentally publish source-only files or secret files.

## 7. Verification — required before declaring completion

Run all checks that the environment supports:

1. Unit tests for key hashing, wrong key, correct key, missing environment variables, tampered/expired cookie, same-origin validation, safe redirect, logout, and protection of every HTML route.
2. Static audit of production application files (excluding this prompt and the historical reference report) that finds any Sonic/SEGA leftovers and any committed secret/key values.
3. Data diff for each source page, reporting the exact counts, categories, order, URL parity, missing/unexpected entries, and blockers.
4. HTML/link checks, duplicate `id` checks, JS syntax and project build/tests.
5. Verify that a logged-out direct request to `/`, `/index.html`, and each `/pages/*.html` returns a redirect or denial before the original resource markup can be retrieved.
6. Verify that login and required assets load while logged out; wrong key is rejected; correct key receives a valid HttpOnly cookie; the cookie does not work after expiry or tampering; logout removes it; no secrets appear in client responses.
7. Use a real browser/Netlify CLI if available to exercise responsive navigation, search/filter combinations, keyboard accessibility, and all copied source utilities.
8. Check security headers and cache behavior in a deployed-like environment.
9. Update README with precise setup commands, Netlify environment variables, deployment instructions, and known limitations.

## 8. Delivery format

Commit the actual code changes into this repository. Do not respond with only a plan, code snippets, or advice.

Deliver:
- the modified, deployable project;
- machine-readable source inventories and parity test/report;
- tests and their actual results;
- `SOURCE-PARITY-REPORT.md` listing verified counts and URLs, with any blocker explicit;
- clear deployment instructions;
- a brief final summary of changed files, test results, remaining limitations, and whether exact parity is genuinely achieved.

### Stop condition

The task is **not complete** until the accessible pages have zero inventory diff and all interactions/testable behaviors pass. If the Pentest source remains unavailable through authorized access, clearly mark overall exact parity as **not achieved** and list the required authorized input. Do not falsely declare success to satisfy the request.

Now begin: inspect the repo, inventory the reference sources, implement the required changes directly, run the tests, and report verified results only.
