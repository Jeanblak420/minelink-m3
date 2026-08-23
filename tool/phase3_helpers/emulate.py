import asyncio, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import websockets
from cdp import page_ws, C
mode = sys.argv[1]
async def main():
    async with websockets.connect(page_ws(), max_size=64*1024*1024) as ws:
        c = C(ws); await c.send("Runtime.enable")
        if mode == "phone":
            await c.send("Emulation.setDeviceMetricsOverride", {"width": 412, "height": 915, "deviceScaleFactor": 1, "mobile": True})
            await c.send("Emulation.setTouchEmulationEnabled", {"enabled": True})
        else:
            await c.send("Emulation.setDeviceMetricsOverride", {"width": 1600, "height": 1000, "deviceScaleFactor": 1, "mobile": False})
            await c.send("Emulation.setTouchEmulationEnabled", {"enabled": False})
        await asyncio.sleep(1.0)
        print(await c.js("[innerWidth, innerHeight]"))
asyncio.run(main())
