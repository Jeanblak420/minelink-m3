"""Flag `ref` / BuildContext use that happens after an `await` without a
`mounted` guard.

Why this needs its own checker
------------------------------
`flutter analyze` cannot see this class of fault, in either of its two shapes:

1. `ref.invalidate` / `ref.read` / `ref.refresh` on a `WidgetRef` call riverpod's
   `_assertNotDisposed()`, which is a real `throw StateError`, not a debug-only
   assert — so it crashes release builds. No lint covers `ref` at all.

2. `use_build_context_synchronously` does cover `BuildContext`, but only when the
   context is used *directly* in the async body. When the use is one method-call
   deep — `_snack(...)` reaching `ScaffoldMessenger.of(context)` — the lint sees
   nothing.

3. `setState` on a disposed State throws "setState() called after dispose()".
   No lint covers it either. This one is the nastiest of the three when it lands
   in a `catch` block: the dispose error replaces the error being reported, so
   the user loses the actual reason their save failed.

Both fire in an ordinary window: a handler awaits a Supabase round-trip, and
before it returns the user hits back, taps a notification, or the router
redirects to `/login` because the session expired. Across this app the tell was
consistent — the snackbar under the call was `mounted`-guarded while the
`ref.invalidate` above it was not.

What is deliberately NOT flagged
--------------------------------
- Provider bodies. In `FutureProvider((ref, id) async { ... })` the `ref` is a
  provider `Ref`, not a `WidgetRef`; it has no widget to be disposed with and no
  mounted check. Detected by `ref` being a parameter of the enclosing closure.
- Anything inside an `if (mounted) { ... }` block, or after an early return
  whose condition mentions `mounted` — including compound ones such as
  `if (result == null || !context.mounted) return;`.
- Call sites that guard inline: `if (mounted) _snack(...)`.
"""
import os
import re
import sys

ASYNC_HEADER = re.compile(r"\basync\b")
# `(ref, x) async {` / `(ref) async {` -- a provider body, not a widget.
PROVIDER_BODY = re.compile(r"\(\s*ref\s*[,)]")
AWAIT = re.compile(r"\bawait\b")
MOUNTED = re.compile(r"\bmounted\b")
# `if (<anything mentioning mounted>) return;` -- guards the rest of the block.
EARLY_RETURN = re.compile(r"if\s*\(.*\bmounted\b.*\)\s*\{?\s*return\b")
# `if (<anything mentioning mounted>) {` -- guards until the block closes.
GUARD_BLOCK = re.compile(r"if\s*\(.*\bmounted\b.*\)\s*\{\s*$")

REF_USE = re.compile(
    r"(?<![A-Za-z0-9_])ref\s*\.\s*(invalidate|read|refresh)\s*\(|"
    r"(?<![A-Za-z0-9_])(setState)\s*\("
)
# `onChanged: (v) => setState(...)` and `onSelected: (v) =>\n  setState(...)`.
# A widget callback fires on user interaction, which cannot happen once the
# widget is gone. It sits lexically after the await that opened the dialog, but
# it does not run there. Matched with a short lookback because the `onX:` and
# the `setState(` are often on different lines.
CALLBACK_POS = re.compile(r"\bon[A-Z][A-Za-z]*\s*:")
HELPER_DECL = re.compile(
    r"^[ \t]+(?:void|Future<void>|Future<[^>]*>)\s+(_[A-Za-z0-9_]*)\s*\([^)]*\)\s*"
    r"(?:async\s*)?\{"
)
CONTEXT_TOUCH = re.compile(
    r"\b(?:ScaffoldMessenger|Navigator|Theme|MediaQuery|MlSemantic|FocusScope|"
    r"Scaffold)\s*\.\s*of\s*\(\s*context|"
    r"(?<![A-Za-z0-9_])ref\s*\.\s*(?:invalidate|read|refresh|watch)\b"
)
# The safe spelling; never a finding.
SAFE_CALL = re.compile(r"ref\s*\.\s*invalidateIfMounted\s*\(")


def block(lines, start):
    """Body lines of the brace-block opening on line index `start`."""
    depth = 0
    out = []
    for i in range(start, len(lines)):
        out.append(lines[i])
        depth += lines[i].count("{") - lines[i].count("}")
        if depth <= 0 and i > start:
            break
    return out


def in_callback(body, off, lookback=2):
    """True if this line sits in a widget callback (`onChanged:` &c.)."""
    for k in range(max(0, off - lookback), off + 1):
        if CALLBACK_POS.search(body[k]):
            return True
    return False


def scan_body(body):
    """Yield (offset, kind, source) for unguarded post-await uses in `body`."""
    seen_await = False
    guard_depth = None
    depth = 0
    for off, raw in enumerate(body):
        line = raw.split("//")[0]

        if guard_depth is not None and depth <= guard_depth:
            guard_depth = None

        if EARLY_RETURN.search(line):
            return  # everything below is guarded
        if GUARD_BLOCK.search(line) and guard_depth is None:
            guard_depth = depth

        opened = depth
        depth += line.count("{") - line.count("}")

        if AWAIT.search(line):
            seen_await = True
            continue
        if not seen_await or guard_depth is not None or MOUNTED.search(line):
            continue
        if SAFE_CALL.search(line):
            continue
        if in_callback(body, off):
            continue
        m = REF_USE.search(line)
        if m:
            kind = "setState" if m.group(2) else "ref." + m.group(1)
            yield off, kind, raw.strip()[:88]
        _ = opened


def scan(root):
    lib = os.path.join(root, "lib")
    findings = []
    for dirpath, _dirs, files in os.walk(lib):
        for fn in sorted(files):
            if not fn.endswith(".dart"):
                continue
            path = os.path.join(dirpath, fn)
            rel = os.path.relpath(path, root).replace("\\", "/")
            with open(path, encoding="utf-8", errors="replace") as fh:
                lines = fh.read().splitlines()

            # Helper methods in this file that touch context/ref unguarded.
            helpers = {}
            for idx, line in enumerate(lines):
                m = HELPER_DECL.match(line)
                if not m:
                    continue
                body = block(lines, idx)
                joined = "\n".join(body)
                if CONTEXT_TOUCH.search(joined) and not MOUNTED.search(joined):
                    helpers[m.group(1)] = True

            for idx, line in enumerate(lines):
                if not ASYNC_HEADER.search(line) or "{" not in line:
                    continue
                if PROVIDER_BODY.search(line):
                    continue  # provider Ref, not WidgetRef
                body = block(lines, idx)
                for off, kind, src in scan_body(body):
                    findings.append((rel, idx + off + 1, kind, src))
                # Unguarded helper calls after an await, same block.
                seen_await = False
                for off, raw in enumerate(body):
                    line2 = raw.split("//")[0]
                    if EARLY_RETURN.search(line2):
                        break
                    if AWAIT.search(line2):
                        seen_await = True
                        continue
                    if not seen_await or MOUNTED.search(line2):
                        continue
                    for name in helpers:
                        if re.search(
                            r"(?<![A-Za-z0-9_])" + re.escape(name) + r"\s*\(", line2
                        ):
                            findings.append(
                                (rel, idx + off + 1, name + "()", raw.strip()[:88])
                            )

    seen = set()
    uniq = []
    for f in findings:
        key = (f[0], f[1], f[2])
        if key not in seen:
            seen.add(key)
            uniq.append(f)
    return uniq


SELFTEST_CASES = [
    (
        "bare ref.invalidate after await",
        """
class X extends ConsumerState<Y> {
  Future<void> go() async {
    await svc.save();
    ref.invalidate(thingProvider);
  }
}
""",
        True,
    ),
    (
        "guarded by early return",
        """
class X extends ConsumerState<Y> {
  Future<void> go() async {
    await svc.save();
    if (!mounted) return;
    ref.invalidate(thingProvider);
  }
}
""",
        False,
    ),
    (
        "guarded by compound early return",
        """
class X extends ConsumerState<Y> {
  Future<void> go() async {
    final r = await svc.save();
    if (r == null || !context.mounted) return;
    ref.invalidate(thingProvider);
  }
}
""",
        False,
    ),
    (
        "guarded by an if (mounted) block",
        """
class X extends ConsumerState<Y> {
  Future<void> go() async {
    await svc.save();
    if (mounted) {
      ref.invalidate(thingProvider);
    }
  }
}
""",
        False,
    ),
    (
        "provider body is not a widget",
        """
final p = FutureProvider.autoDispose.family<A, B>((ref, id) async {
  final b = await ref.watch(other.future);
  return ref.read(svcProvider).load(b);
});
""",
        False,
    ),
    (
        "bare setState after await",
        """
class X extends State<Y> {
  Future<void> go() async {
    await svc.save();
    setState(() => _busy = false);
  }
}
""",
        True,
    ),
    (
        "setState in a widget callback is not post-await code",
        """
class X extends State<Y> {
  Future<void> go() async {
    await showDialog(context: context, builder: (ctx) => Switch(
      onChanged: (v) => setState(() => on = v),
    ));
  }
}
""",
        False,
    ),
    (
        "setState in a callback whose onX: is on the line above",
        """
class X extends State<Y> {
  Future<void> go() async {
    await showDialog(context: context, builder: (ctx) => Menu(
      onSelected: (value) =>
          setState(() => choice = value),
    ));
  }
}
""",
        False,
    ),
    (
        "guarded setState",
        """
class X extends State<Y> {
  Future<void> go() async {
    await svc.save();
    if (mounted) {
      setState(() => _busy = false);
    }
  }
}
""",
        False,
    ),
    (
        "invalidateIfMounted is the safe spelling",
        """
class X extends ConsumerState<Y> {
  Future<void> go() async {
    await svc.save();
    ref.invalidateIfMounted(thingProvider);
  }
}
""",
        False,
    ),
]


def selftest():
    import tempfile

    ok = True
    for name, src, should_bite in SELFTEST_CASES:
        with tempfile.TemporaryDirectory() as td:
            os.makedirs(os.path.join(td, "lib"))
            with open(os.path.join(td, "lib", "s.dart"), "w", encoding="utf-8") as fh:
                fh.write(src)
            bit = bool(scan(td))
        if bit == should_bite:
            print("SELFTEST  %-42s %s" % (name, "BITES" if bit else "clean (correct)"))
        else:
            ok = False
            print(
                "SELFTEST  %-42s DID NOT BEHAVE: expected %s, got %s"
                % (name, "a finding" if should_bite else "clean",
                   "a finding" if bit else "clean")
            )
    print("\nall checks bite" if ok else "\nSELFTEST FAILED")
    return 0 if ok else 1


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if "--selftest" in sys.argv:
        return selftest()
    findings = scan(root)
    for rel, line, kind, src in findings:
        print("POST-AWAIT  %s:%d  %-22s %s" % (rel, line, kind, src))
    print("\nref-after-await: %d unguarded site(s)" % len(findings))
    if findings:
        print(
            "Each of these throws once the widget is gone — StateError from "
            "riverpod, or a deactivated-ancestor FlutterError. Use "
            "`ref.invalidateIfMounted` (core/utils/safe_ref.dart), hoist the "
            "read above the await, or add an explicit `mounted` guard."
        )
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
