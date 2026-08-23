"""Click ONE 'Take picture' control (the one nearest a 'No picture yet' label,
or the first one if none is labelled empty) with the file-chooser intercepted,
then hand it the given image. Intercept is enabled BEFORE the click, which is
the part setfile.py cannot do on its own.

  py -3 takepic.py <abs-path-to-image> [button-label]
"""
import asyncio, json, sys, urllib.request

import websockets

import os
PORT = int(os.environ.get('CDP_PORT', '9222'))

SEM = """
(() => [...document.querySelectorAll('flt-semantics')]
  .filter(e => !e.querySelector('flt-semantics'))
  .map(e => {const r = e.getBoundingClientRect();
             return {l:(e.getAttribute('aria-label')||e.textContent||'').trim(),
                     x:r.x+r.width/2, y:r.y+r.height/2};})
  .filter(o => o.l))()
"""


def page_ws():
    with urllib.request.urlopen(f"http://127.0.0.1:{PORT}/json") as r:
        ts = json.load(r)
    for t in ts:
        if t.get("type") == "page" and "8123" in (t.get("url") or ""):
            return t["webSocketDebuggerUrl"]
    raise SystemExit("no page target")


async def main():
    img = sys.argv[1]
    label = sys.argv[2] if len(sys.argv) > 2 else "Take picture"
    async with websockets.connect(page_ws(), max_size=32 * 1024 * 1024) as ws:
        n = [0]

        async def send(m, p=None):
            n[0] += 1
            await ws.send(json.dumps({"id": n[0], "method": m, "params": p or {}}))
            while True:
                x = json.loads(await ws.recv())
                if x.get("id") == n[0]:
                    if "error" in x:
                        raise RuntimeError(m + ": " + str(x["error"]))
                    return x.get("result", {})

        async def js(e):
            r = await send("Runtime.evaluate",
                           {"expression": e, "returnByValue": True})
            return r.get("result", {}).get("value")

        async def click(x, y):
            await send("Input.dispatchMouseEvent",
                       {"type": "mouseMoved", "x": x, "y": y, "buttons": 0})
            await asyncio.sleep(0.06)
            await send("Input.dispatchMouseEvent",
                       {"type": "mousePressed", "x": x, "y": y,
                        "button": "left", "clickCount": 1, "buttons": 1})
            await asyncio.sleep(0.08)
            await send("Input.dispatchMouseEvent",
                       {"type": "mouseReleased", "x": x, "y": y,
                        "button": "left", "clickCount": 1, "buttons": 0})

        await send("DOM.enable")
        await send("Runtime.enable")
        await send("Page.enable")
        await send("Page.setInterceptFileChooserDialog", {"enabled": True})

        nodes = await js(SEM)
        takers = [o for o in nodes if o["l"] == label] or \
                 [o for o in nodes if label.lower() in o["l"].lower()]
        if not takers:
            print("NOT FOUND:", label)
            sys.exit(2)
        empties = [o for o in nodes if o["l"] == "No picture yet"]
        target = None
        for e in empties:
            for t in takers:
                if abs(t["y"] - e["y"]) < 60:
                    target = t
                    break
            if target:
                break
        if target is None:
            target = takers[0]
        await click(target["x"], target["y"])
        await asyncio.sleep(1.2)
        doc = await send("DOM.getDocument", {"depth": -1, "pierce": True})
        found = await send("DOM.querySelectorAll",
                           {"nodeId": doc["root"]["nodeId"],
                            "selector": "input[type=file]"})
        ids = found["nodeIds"]
        if not ids:
            print("no file input appeared")
            sys.exit(3)
        await send("DOM.setFileInputFiles",
                   {"files": img.split(";"), "nodeId": ids[0]})
        await asyncio.sleep(1.5)
        print("attached", img, "via", label, "at", int(target["x"]), int(target["y"]))


asyncio.run(main())
