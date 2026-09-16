/// AST-backed architecture and executable-source inventory for governance.
library;

import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// An explicit dependency edge, including conditional imports and exports.
typedef Dependency = ({String source, String target});

/// Converts native separators to a stable repository path.
String repositoryPath(String path) =>
    path.replaceAll(String.fromCharCode(92), '/');

/// Returns every URI-bearing directive using the Dart parser.
List<String> directiveUris(String source) {
  final unit = parseString(content: source).unit;
  final uris = <String>[];
  for (final directive in unit.directives) {
    if (directive is UriBasedDirective) {
      final value = directive.uri.stringValue;
      if (value != null) uris.add(value);
    }
    if (directive is NamespaceDirective) {
      for (final configuration in directive.configurations) {
        final value = configuration.uri.stringValue;
        if (value != null) uris.add(value);
      }
    }
  }
  return uris;
}

/// Normalizes relative and package imports to a repository path.
String resolveDependency(String source, String target) {
  const package = 'package:ledger_app/';
  if (target.startsWith(package)) {
    return Uri(
      path: 'lib/${target.substring(package.length)}',
    ).normalizePath().path;
  }
  if (Uri.parse(target).hasScheme) return target;
  return Uri(path: source).resolve(target).normalizePath().path;
}

/// Finds feature dependency cycles even when all edges use public entrypoints.
List<String> featureCycles(Iterable<Dependency> edges) {
  final graph = <String, Set<String>>{};
  for (final edge in edges) {
    if (!edge.source.startsWith('lib/features/') ||
        !edge.target.startsWith('lib/features/')) {
      continue;
    }
    final from = edge.source.split('/')[2];
    final to = edge.target.split('/')[2];
    if (from != to) (graph[from] ??= {}).add(to);
  }
  final cycles = <String>{};
  final complete = <String>{};
  void visit(String node, List<String> path) {
    final existing = path.indexOf(node);
    if (existing >= 0) {
      cycles.add([...path.sublist(existing), node].join(' -> '));
      return;
    }
    if (complete.contains(node)) return;
    for (final next in (graph[node] ?? {}).toList()..sort()) {
      visit(next, [...path, node]);
    }
    complete.add(node);
  }

  for (final node in graph.keys.toList()..sort()) {
    visit(node, []);
  }
  return cycles.toList()..sort();
}

/// Returns a stable rule identifier when an edge crosses an owned boundary.
String? violation(Dependency edge) {
  final source = edge.source;
  final target = edge.target;
  if (source.startsWith('lib/core/') &&
      (target.startsWith('lib/features/') ||
          target.startsWith('lib/shared/') ||
          target.startsWith('lib/app/'))) {
    return 'core-presentation';
  }
  if (source.startsWith('lib/shared/') && target.startsWith('lib/features/')) {
    return 'shared-feature';
  }
  if ((source.startsWith('lib/features/') ||
          source.startsWith('lib/shared/')) &&
      (target.startsWith('package:http/') ||
          target.startsWith('package:flutter_secure_storage/') ||
          target == 'dart:io')) {
    return 'presentation-io';
  }
  if (source != 'lib/main.dart' &&
      !source.startsWith('lib/app/') &&
      target.startsWith('lib/app/') &&
      !target.startsWith('lib/app/theme/') &&
      !target.startsWith('lib/app/locale/') &&
      target != 'lib/app/preferences.dart') {
    return 'composition-root';
  }
  if (source.startsWith('lib/features/') &&
      target.startsWith('lib/features/')) {
    final from = source.split('/')[2];
    final to = target.split('/')[2];
    if (from != to && target != 'lib/features/$to/$to.dart') {
      return 'feature-private-import';
    }
  }
  return null;
}

/// Collects executable line candidates, including unimported source files.
List<int> executableLines(String source) {
  final parsed = parseString(content: source);
  final collector = _ExecutableLines(
    (offset) => parsed.lineInfo.getLocation(offset).lineNumber,
  );
  parsed.unit.accept(collector);
  return collector.lines.toList()..sort();
}

class _ExecutableLines extends GeneralizingAstVisitor<void> {
  _ExecutableLines(this.lineAt);
  final int Function(int) lineAt;
  final Set<int> lines = {};

  @override
  void visitExpressionFunctionBody(ExpressionFunctionBody node) {
    lines.add(lineAt(node.expression.offset));
    super.visitExpressionFunctionBody(node);
  }

  @override
  void visitStatement(Statement node) {
    if (node is! Block && node is! EmptyStatement) {
      lines.add(lineAt(node.offset));
    }
    super.visitStatement(node);
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    if (node.initializer != null) lines.add(lineAt(node.initializer!.offset));
    super.visitVariableDeclaration(node);
  }
}

/// Runs the architecture check or writes a coverage inventory.
void main(List<String> args) {
  if (args.contains('--clean-tool-coverage')) {
    final output = Directory('coverage/tool');
    if (output.existsSync()) output.deleteSync(recursive: true);
    return;
  }
  final inventory = args.contains('--inventory');
  final files =
      ['lib', 'tool/governance']
          .map(Directory.new)
          .where((directory) => directory.existsSync())
          .expand(
            (directory) => directory.listSync(
              recursive: true,
              followLinks: false,
            ),
          )
          .whereType<File>()
          .where(
            (file) =>
                file.path.endsWith('.dart') &&
                !repositoryPath(file.path).startsWith('lib/l10n/generated/'),
          )
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  final sources = <String, List<int>>{};
  final found = <String>{};
  final edges = <Dependency>[];
  for (final file in files) {
    final path = repositoryPath(file.path);
    final content = file.readAsStringSync();
    sources[path] = executableLines(content);
    for (final uri in directiveUris(content)) {
      final target = resolveDependency(path, uri);
      edges.add((source: path, target: target));
      final rule = violation((source: path, target: target));
      if (rule != null) found.add('$rule|$path|$target');
    }
  }
  if (inventory) {
    Directory('coverage').createSync(recursive: true);
    File('coverage/source-inventory.json').writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert({'files': sources})}\n',
    );
    stdout.writeln('Inventoried ${sources.length} handwritten Dart files.');
    return;
  }
  final policy =
      jsonDecode(
            File(
              'tool/governance/architecture-exceptions.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final exceptions = policy['exceptions'] as List<dynamic>;
  var failed = false;
  for (final cycle in featureCycles(edges)) {
    stderr.writeln('Feature dependency cycle: $cycle');
    failed = true;
  }
  final today = DateTime.now().toUtc();
  for (final raw in exceptions) {
    final item = raw as Map<String, dynamic>;
    final key = item['edge'] as String;
    final expiry = DateTime.parse(
      item['expires'] as String,
    ).add(const Duration(days: 1));
    if ((item['owner'] as String).isEmpty ||
        (item['reason'] as String).isEmpty ||
        !today.isBefore(expiry)) {
      stderr.writeln('Expired or incomplete architecture exception: $key');
      failed = true;
    }
    if (!found.remove(key)) {
      stderr.writeln('Stale architecture exception must be removed: $key');
      failed = true;
    }
  }
  for (final edge in found.toList()..sort()) {
    stderr.writeln('Architecture violation: $edge');
    failed = true;
  }
  if (failed) exitCode = 1;
  stdout.writeln(
    'Architecture: ${files.length} files, ${exceptions.length} explicit '
    'migration exceptions, ${found.length} new violations.',
  );
}
