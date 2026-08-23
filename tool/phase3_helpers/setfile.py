"""Put a file into the page's <input type=file> without a native dialog.

Flutter web's image picker creates an `<input type="file" accept="image/*">`
and clicks it. `Page.setInterceptFileChooserDialog` stops Chrome opening the OS
picker, and `DOM.setFileInputFiles` hands the bytes straight to the element.

  py -3 setfile.py <abs-path-to-image> [index]
"""
import asyncio, json, sys, urllib.request

import websockets

import os
PORT = int(os.environ.get('CDP_PORT', '9222'))


def page_ws():
    with urllib.request.urlopen(f"http://127.0.0.1:{PORT}/json") as r:
        ts = json.load(r)
    for t in ts:
        if t.get("type") == "page" and "8123" in (t.get("url") or ""):
            return t["webSocketDebuggerUrl"]
    raise SystemExit("no page target")


async def main():
    path = sys.argv[1]
    idx = int(sys.argv[2]) if len(sys.argv) > 2 else 0
    async with websockets.connect(page_ws(), max_size=32 * 1024 * 1024) as ws:
        n = [0]

        async def send(method, params=None):
            n[0] += 1
            await ws.send(json.dumps({"id": n[0], "method": method,
                                      "params": params or {}}))
            while True:
                m = json.loads(await ws.recv())
                if m.get("id") == n[0]:
                    if "error" in m:
                        raise RuntimeError(method + ": " + str(m["error"]))
                    return m.get("result", {})

        await send("DOM.enable")
        await send("Runtime.enable")
        await send("Page.enable")
        await send("Page.setInterceptFileChooserDialog", {"enabled": True})

        doc = await send("DOM.getDocument", {"depth": -1, "pierce": True})
        root = doc["root"]["nodeId"]
        found = await send("DOM.querySelectorAll",
                           {"nodeId": root, "selector": "input[type=file]"})
        ids = found["nodeIds"]
        if not ids:
            print("no file input on the page")
            sys.exit(2)
        await send("DOM.setFileInputFiles",
                   {"files": [path], "nodeId": ids[idx]})
        print("set", path, "on file input", idx, "of", len(ids))


asyncio.run(main())
