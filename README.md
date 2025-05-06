# Example

Example against Flutter codebase, looking 3 months back: https://grand-horse-a19d0e.netlify.app/ 

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
code_visualizer lib # generates self-contained index.html
open index.html
```

Now open index.html in your browser to see the visualization. The file is self-contained and includes all necessary data and visualization code.

# Limitations

* It only supports Git repositories. Other version control systems are not supported.
* If you want to change the time period, you need to change the `getCommitCounts` method. It is hardcoded to 3 months.
* It only supports Dart. Other programming languages are not supported.