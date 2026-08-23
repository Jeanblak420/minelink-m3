#!/usr/bin/env py -3
"""Tiny CDP driver for driving the Flutter web app in Chrome on 127.0.0.1:9222.

Commands:
  py -3 cdp.py sem                      # semantics LEAF labels (descendant filter)
  py -3 cdp.py semall                   # every semantics node label, with rects
  py -3 cdp.py eval "<js expr>"         # Runtime.evaluate, JSON out
  py -3 cdp.py click <x> <y>            # REAL pointer events at CSS px
  py -3 cdp.py clicklabel "<label>"     # find semantics node by aria-label, click its centre
  py -3 cdp.py type "<text>"            # insertText into the focused field
  py -3 cdp.py key <Key>                # e.g. Enter, Tab, Escape
  py -3 cdp.py shot <path> [full]       # screenshot
  py -3 cdp.py go <url>                 # navigate
  py -3 cdp.py url                      # current url
  py -3 cdp.py publish                  # click the flt-semantics-placeholder
  py -3 cdp.py wait <seconds>
  py -3 cdp.py console                  # drain console messages captured since attach

Reads DEFAULT target = the first page target whose url contains 127.0.0.1:8123.
"""
import asyncio, json, sys, time, base64, urllib.request

import websockets

import os
PORT = int(os.environ.get('CDP_PORT', '9222'))


def targets():
    with urllib.request.urlopen(f"http://127.0.0.1:{PORT}/json") as r:
        return json.load(r)


def page_ws():
    for t in targets():
        if t.get("type") == "page" and "8123" in (t.get("url") or ""):
            return t["webSocketDebuggerUrl"]
    for t in targets():
        if t.get("type") == "page":
            return t["webSocketDebuggerUrl"]
    raise SystemExit("no page target")


class C:
    def __init__(self, ws):
        self.ws = ws
        self.i = 0

    async def send(self, method, params=None):
        self.i += 1
        mid = self.i
        await self.ws.send(json.dumps({"id": mid, "method": method, "params": params or {}}))
        while True:
            msg = json.loads(await self.ws.recv())
            if msg.get("id") == mid:
                if "error" in msg:
                    raise RuntimeError(msg["error"])
                return msg.get("result", {})

    async def js(self, expr):
        r = await self.send("Runtime.evaluate", {
            "expression": expr, "returnByValue": True, "awaitPromise": True,
        })
        if r.get("exceptionDetails"):
            return {"__error": r["exceptionDetails"].get("text"),
                    "detail": str(r["exceptionDetails"])[:600]}
        return r.get("result", {}).get("value")

    async def click(self, x, y):
        await self.send("Input.dispatchMouseEvent",
                        {"type": "mouseMoved", "x": x, "y": y, "buttons": 0})
        await asyncio.sleep(0.08)
        await self.send("Input.dispatchMouseEvent", {
            "type": "mousePressed", "x": x, "y": y, "button": "left",
            "clickCount": 1, "buttons": 1})
        await asyncio.sleep(0.09)
        await self.send("Input.dispatchMouseEvent", {
            "type": "mouseReleased", "x": x, "y": y, "button": "left",
            "clickCount": 1, "buttons": 0})
        await asyncio.sleep(0.08)

    async def move(self, x, y):
        await self.send("Input.dispatchMouseEvent",
                        {"type": "mouseMoved", "x": x, "y": y, "buttons": 0})


SEM_LEAVES = """
(() => [...document.querySelectorAll('flt-semantics')]
  .filter(e => !e.querySelector('flt-semantics'))
  .map(e => (e.getAttribute('aria-label') || e.textContent || '').trim())
  .filter(Boolean))()
"""

SEM_ALL = """
(() => [...document.querySelectorAll('flt-semantics')].map(e => {
  const r = e.getBoundingClientRect();
  const leaf = !e.querySelector('flt-semantics');
  return {l: (e.getAttribute('aria-label') || e.textContent || '').trim().split(/\\s*\\n\\s*/).join(' | '),
          leaf, role: e.getAttribute('role') || '',
          x: Math.round(r.x), y: Math.round(r.y),
          w: Math.round(r.width), h: Math.round(r.height)};
}).filter(o => o.l))()
"""


async def main():
    argv = sys.argv[1:]
    if not argv:
        print(__doc__)
        return
    cmd = argv[0]
    url = page_ws()
    async with websockets.connect(url, max_size=64 * 1024 * 1024) as ws:
        c = C(ws)
        await c.send("Runtime.enable")
        await c.send("Page.enable")

        if cmd == "sem":
            out = await c.js(SEM_LEAVES)
            print(json.dumps(out, indent=0, ensure_ascii=False))
        elif cmd == "semall":
            out = await c.js(SEM_ALL)
            for o in out:
                print(f"{'L' if o['leaf'] else ' '} [{o['x']:>4},{o['y']:>4} {o['w']:>4}x{o['h']:>3}] {o['role']:<10} {o['l']}")
        elif cmd == "eval":
            out = await c.js(argv[1])
            print(json.dumps(out, indent=1, ensure_ascii=False)[:20000])
        elif cmd == "click":
            await c.click(float(argv[1]), float(argv[2]))
            print("clicked", argv[1], argv[2])
        elif cmd == "clicklabel":
            want = argv[1]
            nodes = await c.js(SEM_ALL)
            hits = [n for n in nodes if n["l"] == want] or \
                   [n for n in nodes if want.lower() in n["l"].lower()]
            if not hits:
                print("NOT FOUND:", want)
                sys.exit(2)
            hits.sort(key=lambda n: n["w"] * n["h"])
            n = hits[0]
            await c.move(n["x"] + n["w"] / 2, n["y"] + n["h"] / 2)
            await asyncio.sleep(0.05)
            await c.click(n["x"] + n["w"] / 2, n["y"] + n["h"] / 2)
            print(f"clicked {n['l']!r} at {n['x']+n['w']//2},{n['y']+n['h']//2}")
        elif cmd == "type":
            await c.send("Input.insertText", {"text": argv[1]})
            print("typed")
        elif cmd == "key":
            k = argv[1]
            codes = {"Enter": (13, "Enter", "Enter"), "Tab": (9, "Tab", "Tab"),
                     "Escape": (27, "Escape", "Escape"),
                     "Backspace": (8, "Backspace", "Backspace")}
            vk, key, code = codes.get(k, (0, k, k))
            for t in ("keyDown", "keyUp"):
                await c.send("Input.dispatchKeyEvent", {
                    "type": t, "windowsVirtualKeyCode": vk, "nativeVirtualKeyCode": vk,
                    "key": key, "code": code})
            print("key", k)
        elif cmd == "shot":
            params = {"format": "png"}
            if len(argv) > 2 and argv[2] == "full":
                params["captureBeyondViewport"] = True
            r = await c.send("Page.captureScreenshot", params)
            open(argv[1], "wb").write(base64.b64decode(r["data"]))
            print("shot", argv[1])
        elif cmd == "go":
            await c.send("Page.navigate", {"url": argv[1]})
            print("navigating", argv[1])
        elif cmd == "url":
            print(await c.js("location.href"))
        elif cmd == "publish":
            # The placeholder sits at (-1,-1) 1x1, so a real pointer event cannot
            # land on it. Its click handler does fire from a synthetic click().
            out = await c.js("""(() => {const p=document.querySelector('flt-semantics-placeholder');
              if(!p) return 'already published'; p.click(); return 'published';})()""")
            await asyncio.sleep(1.5)
            n = await c.js("document.querySelectorAll('flt-semantics').length")
            print(out, "->", n, "nodes")
        elif cmd == "scroll":
            # scroll <dy> [x] [y]
            dy = float(argv[1])
            x = float(argv[2]) if len(argv) > 2 else 800
            y = float(argv[3]) if len(argv) > 3 else 500
            await c.send("Input.dispatchMouseEvent", {
                "type": "mouseWheel", "x": x, "y": y, "deltaX": 0, "deltaY": dy})
            await asyncio.sleep(0.5)
            print("scrolled", dy)
        elif cmd == "scrollx":
            # scrollx <dx> [x] [y]  — horizontal wheel
            dx = float(argv[1])
            x = float(argv[2]) if len(argv) > 2 else 800
            y = float(argv[3]) if len(argv) > 3 else 500
            await c.send("Input.dispatchMouseEvent", {
                "type": "mouseWheel", "x": x, "y": y, "deltaX": dx, "deltaY": 0})
            await asyncio.sleep(0.5)
            print("scrolled x", dx)
        elif cmd == "keys":
            # real per-character key events into whatever is focused
            await c.send("Page.bringToFront")
            for ch in argv[1]:
                await c.send("Input.dispatchKeyEvent",
                             {"type": "keyDown", "text": ch, "unmodifiedText": ch})
                await c.send("Input.dispatchKeyEvent", {"type": "keyUp"})
                await asyncio.sleep(0.012)
            print("keys sent:", len(argv[1]))
        elif cmd == "login":
            # login <email> <password> [emailXY] [passXY] [signinXY]
            email, pw = argv[1], argv[2]
            ex, ey = (map(float, argv[3].split(","))) if len(argv) > 3 else (1156, 338)
            px, py_ = (map(float, argv[4].split(","))) if len(argv) > 4 else (1156, 429)
            sx, sy = (map(float, argv[5].split(","))) if len(argv) > 5 else (1156, 550)
            async def clear():
                await c.send("Input.dispatchKeyEvent", {
                    "type": "keyDown", "modifiers": 2, "windowsVirtualKeyCode": 65,
                    "key": "a", "code": "KeyA"})
                await c.send("Input.dispatchKeyEvent", {"type": "keyUp", "modifiers": 2,
                                                       "windowsVirtualKeyCode": 65,
                                                       "key": "a", "code": "KeyA"})
                await asyncio.sleep(0.2)
                for _ in range(2):
                    await c.send("Input.dispatchKeyEvent", {
                        "type": "keyDown", "windowsVirtualKeyCode": 8,
                        "key": "Backspace", "code": "Backspace"})
                    await c.send("Input.dispatchKeyEvent", {
                        "type": "keyUp", "windowsVirtualKeyCode": 8,
                        "key": "Backspace", "code": "Backspace"})
                    await asyncio.sleep(0.15)

            await c.send("Page.bringToFront")
            await c.click(ex, ey)
            await asyncio.sleep(0.8)
            await clear()
            for ch in email:
                await c.send("Input.dispatchKeyEvent",
                             {"type": "keyDown", "text": ch, "unmodifiedText": ch})
                await c.send("Input.dispatchKeyEvent", {"type": "keyUp"})
                await asyncio.sleep(0.01)
            await asyncio.sleep(0.5)
            await c.click(px, py_)
            await asyncio.sleep(0.8)
            await clear()
            for ch in pw:
                await c.send("Input.dispatchKeyEvent",
                             {"type": "keyDown", "text": ch, "unmodifiedText": ch})
                await c.send("Input.dispatchKeyEvent", {"type": "keyUp"})
                await asyncio.sleep(0.01)
            await asyncio.sleep(0.8)
            await c.click(sx, sy)
            print("submitted")
        elif cmd == "wait":
            await asyncio.sleep(float(argv[1]))
            print("waited")
        elif cmd == "clear":
            # Ctrl+A then Backspace into the focused field.
            await c.send("Input.dispatchKeyEvent", {
                "type": "keyDown", "modifiers": 2, "windowsVirtualKeyCode": 65,
                "key": "a", "code": "KeyA"})
            await c.send("Input.dispatchKeyEvent", {"type": "keyUp", "modifiers": 2,
                                                   "windowsVirtualKeyCode": 65,
                                                   "key": "a", "code": "KeyA"})
            await asyncio.sleep(0.2)
            for _ in range(2):
                await c.send("Input.dispatchKeyEvent", {
                    "type": "keyDown", "windowsVirtualKeyCode": 8,
                    "key": "Backspace", "code": "Backspace"})
                await c.send("Input.dispatchKeyEvent", {
                    "type": "keyUp", "windowsVirtualKeyCode": 8,
                    "key": "Backspace", "code": "Backspace"})
                await asyncio.sleep(0.15)
            print("cleared")
        else:
            print("unknown", cmd)


asyncio.run(main())
