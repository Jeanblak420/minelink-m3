import asyncio, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import websockets
from cdp import page_ws, C
x, y = float(sys.argv[1]), float(sys.argv[2])
async def main():
    async with websockets.connect(page_ws(), max_size=64*1024*1024) as ws:
        c = C(ws); await c.send("Runtime.enable")
        await c.move(x-30, y-30); await asyncio.sleep(0.1); await c.move(x, y); await asyncio.sleep(0.6)
        print("hovered", x, y)
asyncio.run(main())
