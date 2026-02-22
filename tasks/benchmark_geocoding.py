
import asyncio
import time
import datetime

# Simulation Parameters
ASSET_COUNT = 20
LATENCY = 0.1  # 100ms per request
BATCH_SIZE = 5

async def resolve_country(location):
    await asyncio.sleep(LATENCY)
    return {"countryCode": "US", "timeZone": "America/New_York"}

def make_day_key(date, timezone):
    # Simulate synchronous work
    return date.strftime("%Y-%m-%d")

async def run_sequential(assets):
    start = time.time()
    for asset in assets:
        resolution = await resolve_country(asset['location'])
        day_key = make_day_key(asset['creationDate'], resolution['timeZone'])
    duration = time.time() - start
    print(f"Sequential finished in {duration:.3f}s")

async def run_concurrent(assets):
    start = time.time()

    # Process in batches
    for i in range(0, len(assets), BATCH_SIZE):
        batch = assets[i:i + BATCH_SIZE]
        tasks = []
        for asset in batch:
            tasks.append(process_asset(asset))
        await asyncio.gather(*tasks)

    duration = time.time() - start
    print(f"Concurrent (Batch Size {BATCH_SIZE}) finished in {duration:.3f}s")

async def process_asset(asset):
    resolution = await resolve_country(asset['location'])
    day_key = make_day_key(asset['creationDate'], resolution['timeZone'])
    return day_key

async def main():
    print(f"Benchmarking with {ASSET_COUNT} assets, {LATENCY}s latency per request...")

    assets = [{
        'creationDate': datetime.datetime.now(),
        'location': (0, 0),
        'id': i
    } for i in range(ASSET_COUNT)]

    print("\n--- Sequential Run ---")
    await run_sequential(assets)

    print("\n--- Concurrent Run ---")
    await run_concurrent(assets)

if __name__ == "__main__":
    asyncio.run(main())
