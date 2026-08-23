"""Attach the stand-in photo to every 'Take picture' control still empty.

Re-reads the semantics between each one, because the card grows when a picture
lands and every later control moves.
"""
import asyncio, json, subprocess, sys, urllib.request, os

import websockets

PORT = 9222
HERE = os.path.dirname(os.path.abspath(__file__))
IMG = os.path.join(HERE, "seal.png")

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

        for attempt in range(8):
            nodes = await js(SEM)
            # A "Take picture" whose card still says "No picture yet" directly
            # above it. Pair by proximity: the empty label sits ~23px higher.
            empties = [o for o in nodes if o["l"] == "No picture yet"]
            takers = [o for o in nodes if o["l"] == "Take picture"]
            target = None
            for e in empties:
                for t in takers:
                    if 0 < t["y"] - e["y"] < 60 and 0 <= t["y"] <= 890:
                        target = t
                        break
                if target:
                    break
            if target is None:
                remaining = len(empties)
                print("nothing more to attach in view; %d still empty" % remaining)
                return
            await click(target["x"], target["y"])
            await asyncio.sleep(1.2)
            doc = await send("DOM.getDocument", {"depth": -1, "pierce": True})
            found = await send("DOM.querySelectorAll",
                               {"nodeId": doc["root"]["nodeId"],
                                "selector": "input[type=file]"})
            ids = found["nodeIds"]
            if not ids:
                print("no file input appeared")
                return
            await send("DOM.setFileInputFiles",
                       {"files": [IMG], "nodeId": ids[0]})
            await asyncio.sleep(1.5)
            print("attached one (round %d)" % (attempt + 1))


asyncio.run(main())
