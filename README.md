# About

This tool was built to visualize technical debt - find and track refactoring candidates.

It represents Dart classes as blocks, focusing on two dimensions for each:
* size (lines of code) - represented as block size
* change frequency (number of commits that changed it in the last 3 months) - represented as color intensity

Refactoring candidates could be **big blocks with strong color**.
These classes usually do not respect single-responsibility principle and have too many responsibilities and reasons to change.

In the `example` Attached you can find how it looks being run against [the Flutter codebase](https://github.com/flutter/flutter/tree/master/packages/flutter/lib).

This is inspired by the book [Your Code as a Crime Scene](https://learning.oreilly.com/library/view/your-code-as/9798888650837/) which I highly recommend.

# CLI

Run instructions:

```bash
git clone https://github.com/madicd/code_visualizer.git
dart pub global activate -spath code_visualizer
cd <APP_TO_ANALYZE_PATH>
code_visualizer lib # generates code_model.json
cp <CODE_VISUALIZER_PATH>/index.html . # copy index.html next to code_model.json so you can visualize it
```

Now open index.html with LiveServer VSCode extension, or any local server that can serve both index.html and code_model.json.

index.html imports code_model.json and visualizes it using [D3.js](https://d3js.org/).

# Limitations

* It only supports Git repositories. Other version control systems are not supported.
* If you want to change the time period, you need to change the `getCommitCounts` method. It is hardcoded to 3 months.
* It only supports Dart. Other programming languages are not supported.