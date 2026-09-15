#!/usr/bin/env python3
"""Verify the exported currency pack independently of the backend checkout."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / 'assets/reference/currencies'
manifest = json.loads((ROOT / 'manifest.json').read_text())
assert manifest['schema_version'] == 1
assert manifest['cldr_version'] == '48.0.0'
hashes = manifest['files']
encoded = (json.dumps(hashes, ensure_ascii=False, indent=2, sort_keys=True) + '\n').encode()
assert hashlib.sha256(encoded).hexdigest() == manifest['content_sha256']
for path, expected in hashes.items():
    target = (ROOT / path).resolve()
    assert target.is_relative_to(ROOT.resolve())
    assert hashlib.sha256(target.read_bytes()).hexdigest() == expected, path
actual = {str(p.relative_to(ROOT)) for p in ROOT.rglob('*') if p.is_file()}
assert actual == set(hashes) | {'manifest.json'}
catalog = json.loads((ROOT / manifest['catalog']).read_text())['currencies']
assert len(catalog) == 148
for locale, info in manifest['locales'].items():
    data = json.loads((ROOT / info['path']).read_text())
    assert data['locale'] == locale
    assert set(data['currencies']) == set(catalog)
    assert all(v['display_name'] and v['symbol'] for v in data['currencies'].values())
assert not (ROOT.parent / 'currencies.json').exists(), 'Remove the retired bilingual catalog'
print(f'Currency pack verified: {len(catalog)} currencies, {len(manifest["locales"])} locale bundles')
