# Offline reference data

Currency names, symbols and Chinese exemplar-city names are derived from
[Unicode CLDR JSON 48.0.0](https://github.com/unicode-org/cldr-json/tree/48.0.0),
under the accompanying `UNICODE-LICENSE.txt`.

Sources within that release:

- `cldr-json/cldr-numbers-full/main/{en,en-CA,zh,zh-Hant}/currencies.json`
- `cldr-json/cldr-core/supplemental/currencyData.json`
- `cldr-json/cldr-dates-full/main/zh/timeZoneNames.json`

The generated `currencies/` directory separates `catalog.json` accounting metadata
from `locales/{locale}.json` display labels. `manifest.json` registers schema and
CLDR versions, source hashes and a content digest; `locale_rules.json` contains
pinned lookup data. The old code-to-en/zh file has been retired.

Authoritative inputs and the offline generator live in the backend's `reference/`
directory. Export with `python3 tool/currencies.py --app <app-path>` from that
checkout, or copy its versioned `reference/currencies/` artifact here. Run
`python3 tool/check_currencies.py` to verify this independent copy. Do not hand-edit
generated files. The App has no runtime dependency on the backend checkout.

The currency allowlist originally selected current legal tender (a region entry without `_to`
and without `_tender: false`). SLE, VES, XCG, ZWG and MRU are excluded because the
current Ledger backend's `golang.org/x/text/currency.ParseISO` rejects them.
The resulting 148 codes were checked against that validator. Recheck the list
when the backend upgrades its currency data. Label updates must preserve the
reviewed allowlist and accounting precision.

The Chinese city file flattens CLDR `zone` entries with `exemplarCity` to IANA
identifiers. Unknown names fall back to the readable IANA city name. Timezone
identifiers and date-sensitive offsets come from the pinned Dart `timezone`
package's bundled IANA database. `UTC` is explicitly available as the fallback.
No reference-data request is made at application runtime.
