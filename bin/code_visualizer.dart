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

  ClassModel({
    required this.className,
    required this.linesOfCode,
    required this.methodCount,
    required this.commitCount,
  });

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
    return {'classModels': classModels.map((model) => model.toJson()).toList()};
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

    classModels.add(
      ClassModel(
        className: className,
        linesOfCode: linesOfCode,
        methodCount: methodCount,
        commitCount: commitCount,
      ),
    );
    super.visitClassDeclaration(node);
  }

  int _countLinesOfCode(ClassDeclaration node) {
    return content.substring(node.offset, node.end).split('\n').length;
  }
}

Map<String, int> getCommitCounts(String directoryPath) {
  final result = Process.runSync('git', [
    'log',
    '--since="3 months ago"',
    '--pretty=format:',
    '--name-only',
    '--diff-filter=AM',
    '--no-merges',
  ], workingDirectory: directoryPath);

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
  final result = Process.runSync('git', [
    'rev-parse',
    '--show-toplevel',
  ], workingDirectory: directoryPath);

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
  final jsonData = jsonEncode(codeModel);

  // Generate self-contained index.html
  final indexHtml = '''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Interactive Tree Map Visualization</title>
    <script src="https://d3js.org/d3.v7.min.js"></script>
    <style>
        body, html {
          margin: 0;
          padding: 0;
          width: 100%;
          height: 100%;
          overflow: hidden;
        }
        .node {
          stroke: #fff;
          stroke-width: 1px;
          fill-opacity: 0.9;
        }
        .tooltip {
          position: absolute;
          text-align: center;
          padding: 5px;
          font: 12px sans-serif;
          background: lightsteelblue;
          border: 1px solid #000;
          border-radius: 5px;
          pointer-events: none;
          opacity: 0;
        }
        svg {
          display: block;
        }
    </style>
</head>
<body>
<div class="tooltip"></div>
<svg></svg>
<script>
    const width = window.innerWidth;
    const height = window.innerHeight;

    const color = d3.scaleSequential(d3.interpolateBlues)
      .domain([0, 50]);

    const tooltip = d3.select(".tooltip");

    const svg = d3.select("svg")
      .attr("width", width)
      .attr("height", height)
      .attr("viewBox", \`0 0 \${width} \${height}\`)
      .attr("preserveAspectRatio", "xMidYMid meet");

    const g = svg.append("g").attr("class", "zoomable");

    const treemap = d3.treemap()
      .size([width, height])
      .paddingInner(1);

    // Embedded JSON data
    const data = $jsonData;

    const root = d3.hierarchy({children: data.classModels})
      .sum(d => d.linesOfCode)
      .sort((a, b) => b.linesOfCode - a.linesOfCode);

    treemap(root);

    const nodes = g.selectAll(".node")
      .data(root.leaves())
      .enter().append("rect")
        .attr("class", "node")
        .attr("x", d => d.x0)
        .attr("y", d => d.y0)
        .attr("width", d => d.x1 - d.x0)
        .attr("height", d => d.y1 - d.y0)
        .attr("fill", d => color(d.data.commitCount))
        .on("mouseover", function(event, d) {
          tooltip.transition()
            .duration(200)
            .style("opacity", .9);
          tooltip.html(\`Class: \${d.data.className}<br>Lines of Code: \${d.data.linesOfCode}<br>Method Count: \${d.data.methodCount}<br>Commits in last 3 months: \${d.data.commitCount}\`)
            .style("left", (event.pageX + 5) + "px")
            .style("top", (event.pageY - 28) + "px");
        })
        .on("mouseout", function() {
          tooltip.transition()
            .duration(500)
            .style("opacity", 0);
        });

    // Zoom and pan
    const zoom = d3.zoom()
      .scaleExtent([1, 10])
      .translateExtent([[0, 0], [width, height]])
      .on("zoom", (event) => {
        g.attr("transform", event.transform);
      });

    svg.call(zoom);

    // Resize the SVG element when the window is resized
    window.addEventListener('resize', () => {
      const newWidth = window.innerWidth;
      const newHeight = window.innerHeight;
      svg.attr("width", newWidth)
         .attr("height", newHeight)
         .attr("viewBox", \`0 0 \${newWidth} \${newHeight}\`);
      treemap.size([newWidth, newHeight]);
      g.selectAll(".node")
        .attr("x", d => d.x0)
        .attr("y", d => d.y0)
        .attr("width", d => d.x1 - d.x0)
        .attr("height", d => d.y1 - d.y0);
    });
</script>
</body>
</html>''';

  File('index.html').writeAsStringSync(indexHtml);
  print(
    'Self-contained index.html generated after ${stopwatch.elapsedMilliseconds} ms',
  );
}
