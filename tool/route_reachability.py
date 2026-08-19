#!/usr/bin/env python3
"""S7-5 — which declared routes is nothing in the app able to navigate to?

    python tool/route_reachability.py            # report
    python tool/route_reachability.py --selftest # prove the matcher bites
    python tool/route_reachability.py --json     # machine-readable

WHY THIS IS A FILE AND NOT A ONE-OFF
------------------------------------
Three earlier versions of this check were written ad hoc and two of them were
**wrong in the direction that looks clean**:

  v1 reported 0 orphans out of 143 routes. It let a route be "covered" by its
     own `path:` declaration in the router, so every route matched itself. A
     48 -> 0 swing in one edit is the shape of a broken matcher, not of a
     clean codebase.
  v2 reported 20. Better, but a canary route that nothing referenced was also
     reported covered: a reference like `'/$x'` normalised to `/*` and matched
     any single-segment route, silently swallowing real orphans.
  v3 reports 25 and its canary is correctly flagged.

The lesson is not "be careful". It is that a reachability check degrades into
"everything is fine" when it breaks, so it must **prove it can still fail**
every time it runs. `--selftest` plants both an unreferenced route and a
referenced one and requires the first to be flagged and the second not to be.
The main run also plants a canary internally and aborts if it comes back
covered.

WHAT "COVERED" MEANS
--------------------
Some file in `lib/` other than the router itself contains a string literal
that could navigate to the route. Redirect targets inside the router DO count
as references — a redirect is a real way to arrive.

Matching is segment-wise. A route's `:param` segment matches any reference
segment. A reference's `$interpolation` segment matches only a route's
`:param` segment, never a literal — that is the v2 bug, and it is the one that
matters, because `'/$x'` otherwise matches every one-segment route in the app.
`/portal/$org/...` is the single structural interpolation in the nav tree and
is expanded to its four concrete values instead.

A route being uncovered is NOT automatically a defect. `/reset-password` is
opened from an email link and `/super-admin/dashboard-v2` is a deliberate
redirect kept so old browser history resolves. The point of the list is that
each entry gets a judgement; `docs/route-reachability-verdicts.md` records
them.
"""
import json
import os
import re
import sys

ROUTER = 'lib/core/routing/app_router.dart'
ORG_SECTIONS = ['mine', 'buyer', 'transporter', 'driver']

_PATH_DECL = re.compile(r"""\bpath\s*:\s*(['"])(/[^'"]*)\1""")
_STRING = re.compile(r"""(['"])((?:/|\$)[^'"\n]*)\1""")


# `static const String basePath = '/super-admin/targets/company';` and friends.
# Without this, a navigation written as `'$basePath/${c['id']}'` looks like an
# interpolation with an unknown prefix and its route is reported unreachable —
# a false positive that costs a real judgement call, which is the expensive
# kind. Resolved per file, because these constants are file-local by
# convention and a global map would let one file's `basePath` cover another's.
_CONST_PATH = re.compile(
    r"""\bconst\s+String\s+(\w+)\s*=\s*(['"])(/[^'"]*)\2""")


def _declared_routes(src):
    """Every `path: '/...'` in the router, in declaration order."""
    return [m.group(2) for m in _PATH_DECL.finditer(src)]


def _redirect_targets(src):
    """`redirect:` targets inside the router — arriving by redirect is arriving."""
    out = []
    for m in re.finditer(r'redirect\s*:', src):
        window = src[m.end():m.end() + 400]
        out.extend(s.group(2) for s in _STRING.finditer(window))
    return out


def _resolve_consts(ref, consts):
    """Substitute file-local `const String x = '/...'` into a reference.

    Handles the bare form (`$basePath`, `${basePath}`) and the class-qualified
    one (`${TargetsCompanyScreen.basePath}`), which is how these constants are
    actually written at most call sites — the screen names its own base path
    and then interpolates it through the class. Missing that form left
    `/super-admin/targets/company/:companyId` on the unreachable list when a
    `context.go` two files away builds exactly it.
    """
    for name, value in consts.items():
        ref = re.sub(r'\$\{[\w.]*\b%s\}' % re.escape(name), value, ref)
        ref = ref.replace('$' + name, value)
    return ref


def _expand(ref):
    """One reference string -> the concrete paths it could produce."""
    # The nav tree's single structural interpolation.
    if '/portal/$org' in ref or '/portal/${org}' in ref:
        return [ref.replace('${org}', o).replace('$org', o) for o in ORG_SECTIONS]
    return [ref]


def _segments(path):
    return [s for s in path.strip('/').split('/') if s != '']


def _is_wildcard_ref_seg(seg):
    """A reference segment that came from interpolation."""
    return '$' in seg


def _matches(route, ref):
    """Could a navigation to `ref` land on `route`?"""
    r, f = _segments(route), _segments(ref)
    if len(r) != len(f):
        return False
    for rs, fs in zip(r, f):
        if rs.startswith(':'):
            # A path parameter accepts a literal or an interpolation.
            continue
        if _is_wildcard_ref_seg(fs):
            # v2's bug: an interpolated segment must NOT match a literal one,
            # or `'/$x'` matches every single-segment route in the app.
            return False
        if rs != fs:
            return False
    return True


def _references(root, extra_files=None):
    refs = []
    for dirpath, _, names in os.walk(os.path.join(root, 'lib')):
        for n in names:
            if not n.endswith('.dart'):
                continue
            rel = os.path.relpath(os.path.join(dirpath, n), root).replace('\\', '/')
            if rel == ROUTER:
                continue  # its own declarations are not references
            try:
                with open(os.path.join(dirpath, n), encoding='utf-8') as fh:
                    src = fh.read()
            except (OSError, UnicodeDecodeError):
                continue
            consts = {m.group(1): m.group(3) for m in _CONST_PATH.finditer(src)}
            for m in _STRING.finditer(src):
                refs.extend(_expand(_resolve_consts(m.group(2), consts)))
    for f in (extra_files or []):
        refs.extend(_expand(f))
    return refs


def scan(root, canary_route='/zz-canary-unreferenced/:id',
         canary_ref='/zz-canary-referenced/x'):
    with open(os.path.join(root, ROUTER), encoding='utf-8') as fh:
        router_src = fh.read()

    routes = _declared_routes(router_src)
    refs = _references(root, extra_files=_redirect_targets(router_src))

    # Canaries, always, in the main run too. A matcher that has degraded into
    # "everything is covered" fails here rather than reporting a clean tree.
    probe_routes = routes + [canary_route, '/zz-canary-referenced/:id']
    refs = refs + [canary_ref]

    covered, uncovered = [], []
    for route in probe_routes:
        if any(_matches(route, r) for r in refs):
            covered.append(route)
        else:
            uncovered.append(route)

    if canary_route not in uncovered:
        raise SystemExit(
            'MATCHER BROKEN: the unreferenced canary %s came back covered. '
            'Every result from this run is untrustworthy.' % canary_route)
    if '/zz-canary-referenced/:id' not in covered:
        raise SystemExit(
            'MATCHER BROKEN: the referenced canary was reported uncovered. '
            'Every result from this run is untrustworthy.')

    covered = [r for r in covered if not r.startswith('/zz-canary')]
    uncovered = [r for r in uncovered if not r.startswith('/zz-canary')]
    return routes, covered, uncovered


def selftest(root):
    ok = True
    routes, covered, uncovered = scan(root)
    print('SELFTEST  canaries: unreferenced flagged, referenced not — OK')

    # The v2 bug, explicitly: an interpolated segment must not match a literal.
    if _matches('/reset-password', '/$x'):
        ok = False
        print("SELFTEST  v2 REGRESSION: '/$x' matches /reset-password")
    else:
        print("SELFTEST  '/$x' does not match a literal route — OK")

    # A route parameter must accept a concrete reference.
    if not _matches('/employees/:companyId', '/employees/abc-123'):
        ok = False
        print('SELFTEST  a :param no longer accepts a literal reference')
    else:
        print('SELFTEST  a :param accepts a concrete reference — OK')

    # Depth must matter.
    if _matches('/portal/mine/trips', '/portal/mine/trips/x/waybill'):
        ok = False
        print('SELFTEST  segment count is not being compared')
    else:
        print('SELFTEST  segment count is compared — OK')

    print('\nall checks bite' if ok else '\nSELFTEST FAILED')
    return 0 if ok else 1


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if '--selftest' in sys.argv:
        return selftest(root)
    routes, covered, uncovered = scan(root)
    if '--json' in sys.argv:
        print(json.dumps({'declared': len(routes), 'covered': len(covered),
                          'uncovered': sorted(uncovered)}, indent=2))
        return 0
    print('declared routes : %d' % len(routes))
    print('reachable       : %d' % len(covered))
    print('no reference    : %d' % len(uncovered))
    for r in sorted(uncovered):
        print('  %s' % r)
    print('\nA route with no reference is not automatically a defect — see '
          'docs/route-reachability-verdicts.md for the per-route judgement.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
