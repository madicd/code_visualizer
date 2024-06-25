import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:path/path.dart' as path;

class ClassModel {
  final String className;
  final int linesOfCode;
  final int methodCount;
  final int commitCount; // Number of commits in the past 3 months

  ClassModel(
      {required this.className,
      required this.linesOfCode,
      required this.methodCount,
      required this.commitCount});

  Map<String, dynamic> toJson() {
    return {
      'className': className,
      'linesOfCode': linesOfCode,
      'methodCount': methodCount,
      'commitCount': commitCount,
    };
  }
}

class CodeModel {
  final List<ClassModel> classModels;

  CodeModel({required this.classModels});

  Map<String, dynamic> toJson() {
    return {
      'classModels': classModels.map((model) => model.toJson()).toList(),
    };
  }
}

class ClassVisitor extends GeneralizingAstVisitor<void> {
  final List<ClassModel> classModels = [];
  final String content;
  final int commitCount;

  ClassVisitor(this.content, this.commitCount);

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final className = node.name.lexeme;
    final linesOfCode = _countLinesOfCode(node);
    final methodCount = node.members.whereType<MethodDeclaration>().length;

    classModels.add(ClassModel(
        className: className,
        linesOfCode: linesOfCode,
        methodCount: methodCount,
        commitCount: commitCount));
    super.visitClassDeclaration(node);
  }

  int _countLinesOfCode(ClassDeclaration node) {
    return content.substring(node.offset, node.end).split('\n').length;
  }
}

Map<String, int> getCommitCounts(String directoryPath) {
  final result = Process.runSync(
      'git',
      [
        'log',
        '--since="3 months ago"',
        '--pretty=format:',
        '--name-only',
        '--diff-filter=AM',
        '--no-merges'
      ],
      workingDirectory: directoryPath);

  if (result.exitCode != 0) {
    return {};
  }

  final commitCounts = <String, int>{};
  final files = result.stdout.toString().split('\n');

  for (var file in files) {
    if (file.trim().isNotEmpty) {
      // adapt file name to platform separator
      final relativePath = path.normalize(file.trim());
      commitCounts[relativePath] = (commitCounts[relativePath] ?? 0) + 1;
    }
  }

  return commitCounts;
}

String getGitRootDirectory(String directoryPath) {
  final result = Process.runSync('git', ['rev-parse', '--show-toplevel'],
      workingDirectory: directoryPath);

  if (result.exitCode != 0) {
    print('Error: ${result.stderr}');
    exit(1);
  }

  var trim = result.stdout.toString().trim();
  // adapt to platform separator
  return trim.replaceAll('/', Platform.pathSeparator);
}

void main(List<String> arguments) {
  if (arguments.isEmpty) {
    print('Usage: dart visualizer.dart <directory>');
    exit(1);
  }
  print('Starting code visualizer...');

  final stopwatch = Stopwatch()..start();
  final directoryPath = arguments.first;
  final directory = Directory(directoryPath);
  if (!directory.existsSync()) {
    print('Directory does not exist');
    exit(1);
  }

  print('Searching for git root directory...');
  final gitRootDirectory = getGitRootDirectory(directoryPath);
  print('Git root directory: $gitRootDirectory');

  print('Loading commit counts...');
  final commitCounts = getCommitCounts(directoryPath);

  final dartFiles = directory
      .listSync(recursive: true)
      .where((file) => file.path.endsWith('.dart'));

  print('Processing ${dartFiles.length} files...');
  final List<ClassModel> allClassModels = [];
  for (var file in dartFiles) {
    final relativePath = path.relative(file.path, from: gitRootDirectory);
    final content = File(file.path).readAsStringSync();
    final result = parseString(content: content);
    final commitCount = commitCounts[relativePath] ?? 0;
    final visitor = ClassVisitor(content, commitCount);
    result.unit.visitChildren(visitor);
    allClassModels.addAll(visitor.classModels);
  }

  final codeModel = CodeModel(classModels: allClassModels);

  File('code_model.json').writeAsStringSync(jsonEncode(codeModel));
  print(
      'Code model saved to code_model.json after ${stopwatch.elapsedMilliseconds} ms');
}
