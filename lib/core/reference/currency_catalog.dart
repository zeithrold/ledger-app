// Currency labels are generated from pinned CLDR, independently of UI messages.
// ignore_for_file: public_member_api_docs
import 'dart:convert';

import 'package:flutter/services.dart';

typedef CurrencyJson = Map<String, dynamic>;

/// A language-neutral catalog and the locale bundles loaded for this view.
class CurrencyCatalog {
  CurrencyCatalog(this.manifest, this.metadata, this.rules, this.bundles);

  final CurrencyJson manifest;
  final CurrencyJson metadata;
  final CurrencyJson rules;
  final Map<String, CurrencyJson> bundles;

  Iterable<String> get codes => (metadata['currencies'] as Map).keys.cast();
  bool containsKey(String? code) =>
      (metadata['currencies'] as Map).containsKey(code);

  String resolve(String requested) {
    final aliases = Map<String, String>.from(
      manifest['legacy_locale_aliases'] as Map,
    );
    var tag = _canonical(requested);
    tag = aliases[tag] ?? tag;
    final wantedScript = _maximize(tag).script;
    final available = manifest['locales'] as Map;
    final visited = <String>{};
    while (tag != 'und' && visited.add(tag)) {
      final expanded = _maximize(tag);
      final candidates = <String>{
        tag,
        expanded.tag,
        if (expanded.region != null) '${expanded.language}-${expanded.region}',
        if (expanded.script != null) '${expanded.language}-${expanded.script}',
      };
      for (final candidate in candidates) {
        if (available.containsKey(candidate) &&
            _maximize(candidate).script == wantedScript) {
          return candidate;
        }
      }
      final parent = (rules['parent_locales'] as Map)[tag] as String?;
      final last = tag.lastIndexOf('-');
      tag = parent ?? (last < 0 ? 'und' : tag.substring(0, last));
    }
    return manifest['default_locale'] as String;
  }

  String _canonical(String value) {
    final aliases = rules['language_aliases'] as Map;
    final normalized = value.replaceAll('_', '-');
    final wholeAlias = aliases.entries
        .where(
          (entry) =>
              (entry.key as String).toLowerCase() == normalized.toLowerCase(),
        )
        .firstOrNull;
    var parsed = _Tag.parse(wholeAlias?.value as String? ?? normalized);
    final replacement = aliases[parsed.tag] ?? aliases[parsed.language];
    if (replacement is String) {
      final alias = _Tag.parse(replacement);
      parsed = _Tag(
        alias.language,
        parsed.script ?? alias.script,
        parsed.region ?? alias.region,
      );
    }
    final regions = rules['territory_aliases'] as Map;
    return _Tag(
      parsed.language,
      parsed.script,
      regions[parsed.region] as String? ?? parsed.region,
    ).tag;
  }

  _Tag _maximize(String value) {
    final p = _Tag.parse(value);
    final likely = rules['likely_subtags'] as Map;
    for (final key in [
      p.tag,
      if (p.script != null) '${p.language}-${p.script}',
      if (p.region != null) '${p.language}-${p.region}',
      p.language,
    ]) {
      if (likely[key] case final String tag) {
        final inferred = _Tag.parse(tag);
        return _Tag(
          p.language,
          p.script ?? inferred.script,
          p.region ?? inferred.region,
        );
      }
    }
    return p;
  }

  CurrencyLabel label(String code, String locale) {
    final resolved = resolve(locale);
    final fallback = manifest['default_locale'] as String;
    final item = bundles[resolved]?[code] ?? bundles[fallback]?[code];
    if (item is! Map) return CurrencyLabel(code, code);
    return CurrencyLabel(
      item['display_name'] as String? ?? code,
      item['symbol'] as String? ?? code,
    );
  }

  static Future<CurrencyCatalog> load(
    AssetBundle assets,
    String requested,
  ) async {
    const base = 'assets/reference/currencies/';
    Future<CurrencyJson> read(String path) async =>
        jsonDecode(await assets.loadString('$base$path')) as CurrencyJson;
    final manifest = await read('manifest.json');
    final data = await Future.wait([
      read(manifest['catalog'] as String),
      read(manifest['rules'] as String),
    ]);
    final result = CurrencyCatalog(manifest, data[0], data[1], {});
    for (final locale in {
      result.resolve(requested),
      manifest['default_locale'] as String,
    }) {
      final entry = (manifest['locales'] as Map)[locale] as Map;
      final path = entry['path'] as String;
      // Only paths declared in the bundled manifest can be loaded.
      final bundle = await read(path);
      result.bundles[locale] = bundle['currencies'] as CurrencyJson;
    }
    return result;
  }
}

class CurrencyLabel {
  CurrencyLabel(this.name, this.symbol);
  final String name;
  final String symbol;
}

class _Tag {
  _Tag(this.language, this.script, this.region);
  factory _Tag.parse(String value) {
    final parts = value.replaceAll('_', '-').split('-');
    final language = parts.first.toLowerCase();
    if (!RegExp(r'^[a-z]{2,8}$').hasMatch(language)) {
      return _Tag('und', null, null);
    }
    String? script;
    String? region;
    for (final part in parts.skip(1)) {
      if (part.length == 1) break; // Extensions do not select a name bundle.
      if (script == null && RegExp(r'^[a-zA-Z]{4}$').hasMatch(part)) {
        script = '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}';
      } else if (region == null &&
          RegExp(r'^([a-zA-Z]{2}|[0-9]{3})$').hasMatch(part)) {
        region = part.toUpperCase();
      }
    }
    return _Tag(language, script, region);
  }
  final String language;
  final String? script;
  final String? region;
  String get tag => [language, ?script, ?region].join('-');
}
