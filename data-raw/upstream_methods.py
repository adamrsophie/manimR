# Lists the public methods and properties each upstream class defines in its
# own body, for the method coverage check in tests/testthat/test-api-coverage.R.
# Run: python -I data-raw/upstream_methods.py documentation/manim/manim tests/testthat/fixtures/upstream_exports.txt OUT.txt
import ast, pathlib, sys

root = pathlib.Path(sys.argv[1])
exports = dict(line.rstrip("\n").split("\t") for line in open(sys.argv[2]))
classes = {}
for path in root.rglob("*.py"):
    if "_config" in path.parts or "cli" in path.parts:
        continue
    tree = ast.parse(path.read_text())
    for node in tree.body:
        if isinstance(node, ast.ClassDef) and node.name in exports:
            methods = []
            for b in node.body:
                if isinstance(b, (ast.FunctionDef, ast.AsyncFunctionDef)) and not b.name.startswith("_"):
                    if any(isinstance(d, ast.Name) and d.id == "overload" for d in b.decorator_list):
                        continue
                    methods.append(b.name)
            bases = [ast.unparse(x) for x in node.bases]
            classes[node.name] = (sorted(set(methods)), bases)
with open(sys.argv[3], "w") as f:
    for name in sorted(classes):
        methods, bases = classes[name]
        f.write(f"{name}\t{','.join(bases)}\t{','.join(methods)}\n")
print(len(classes), "classes")
