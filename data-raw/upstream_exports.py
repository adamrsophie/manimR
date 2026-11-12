# Lists every public name that `from manim import *` provides, read from the
# upstream source tree in documentation/manim without importing it, for
# tests/testthat/test-api-coverage.R.
# Run: python -I data-raw/upstream_exports.py documentation/manim/manim tests/testthat/fixtures/upstream_exports.txt
import ast, pathlib, sys

root = pathlib.Path(sys.argv[1])


def module_path(base, level, mod):
    """Path of a module imported relatively from package directory `base`."""
    pkg = base
    for _ in range(level - 1):
        pkg = pkg.parent
    target = pkg / mod.replace(".", "/") if mod else pkg
    if target.with_suffix(".py").exists():
        return target.with_suffix(".py")
    return target / "__init__.py"


def public_names(path, seen=None):
    """Names `from module import *` brings in, following nested star imports."""
    seen = seen or set()
    if path in seen or not path.exists():
        return {}
    seen.add(path)
    tree = ast.parse(path.read_text())
    for node in tree.body:
        if isinstance(node, ast.Assign) and any(getattr(t, "id", None) == "__all__" for t in node.targets):
            return {n: path for n in ast.literal_eval(node.value)}
    names = {}
    for node in ast.walk(tree) if path.name == "__init__.py" else tree.body:
        if isinstance(node, ast.ImportFrom) and node.level and any(a.name == "*" for a in node.names):
            names.update(public_names(module_path(path.parent, node.level, node.module), seen))
    for node in tree.body:
        if isinstance(node, (ast.FunctionDef, ast.ClassDef)) and not node.name.startswith("_"):
            names[node.name] = path
        elif isinstance(node, ast.Assign):
            for t in node.targets:
                if isinstance(t, ast.Name) and not t.id.startswith("_"):
                    names[t.id] = path
        elif isinstance(node, ast.ImportFrom) and node.level and path.name == "__init__.py":
            for a in node.names:
                if a.name != "*" and not (a.asname or a.name).startswith("_"):
                    names[a.asname or a.name] = path
    return names


init = root / "__init__.py"
tree = ast.parse(init.read_text())
names = {}
for node in tree.body:
    if isinstance(node, ast.ImportFrom) and node.level == 1:
        if any(a.name == "*" for a in node.names):
            names.update(public_names(module_path(root, 1, node.module)))
        elif node.module == "utils":
            for a in node.names:
                names[a.name] = root / "utils" / a.name
for key in ["np", "annotations"]:
    names.pop(key, None)
with open(sys.argv[2], "w") as f:
    for name in sorted(names):
        f.write(f"{name}\t{pathlib.Path(names[name]).relative_to(root).with_suffix('')}\n")
print(len(names), "names")
