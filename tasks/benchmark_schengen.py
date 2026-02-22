
import datetime
import random
import time

# Mocking data structures
class Stay:
    def __init__(self, entered_on, exited_on):
        self.entered_on = entered_on
        self.exited_on = exited_on

def start_of_day(dt):
    return dt.replace(hour=0, minute=0, second=0, microsecond=0)

def original_summary(stays, reference_date):
    window_end = start_of_day(reference_date)
    window_start = window_end - datetime.timedelta(days=179)

    count = 0
    # Simulate reversed iteration of descending sorted stays -> ascending order
    for stay in reversed(stays):
        stay_start = start_of_day(stay.entered_on)
        stay_end = start_of_day(stay.exited_on if stay.exited_on else reference_date)

        if stay_end < window_start or stay_start > window_end:
            continue

        count += 1 # Dummy processing
    return count

def optimized_summary(stays, reference_date):
    window_end = start_of_day(reference_date)
    window_start = window_end - datetime.timedelta(days=179)

    # Precompute cutoff for future stays
    # window_end is 00:00:00. The day includes up to 23:59:59.
    # stay_start > window_end means stay_start >= window_end + 1 day
    # stay_start is start_of_day(entered_on).
    # start_of_day(entered_on) >= window_end + 1 day
    # <=> entered_on >= window_end + 1 day
    window_end_next_day = window_end + datetime.timedelta(days=1)

    count = 0
    for stay in reversed(stays):
        # Optimization: Check without start_of_day

        # 1. Past check
        # stay_end < window_start
        # stay_end is start_of_day(exited_on).
        # start_of_day(exited_on) < window_start
        # <=> exited_on < window_start (since window_start is 00:00:00)
        eff_exited_on = stay.exited_on if stay.exited_on else reference_date

        if eff_exited_on < window_start:
            continue

        # 2. Future check
        if stay.entered_on >= window_end_next_day:
            # Since we iterate ascendingly, all future stays are also out of window
            break

        stay_start = start_of_day(stay.entered_on)
        stay_end = start_of_day(eff_exited_on)

        # Redundant check?
        # If we passed the checks above:
        # eff_exited_on >= window_start => stay_end >= window_start (approx)
        # entered_on < window_end_next_day => stay_start <= window_end

        # Wait, strictly speaking:
        # If eff_exited_on >= window_start.
        # If eff_exited_on is 2023-01-01 01:00:00 and window_start is 2023-01-01 00:00:00.
        # stay_end is 2023-01-01 00:00:00.
        # stay_end < window_start is False.
        # So "eff_exited_on < window_start" is safe replacement for "stay_end < window_start".

        # If entered_on < window_end_next_day.
        # entered_on < 2023-01-02 00:00:00.
        # So entered_on is at most 2023-01-01 23:59:59.
        # stay_start is at most 2023-01-01 00:00:00.
        # window_end is 2023-01-01 00:00:00.
        # So stay_start <= window_end.
        # So stay_start > window_end is False.

        # So the original check `if stay_end < window_start or stay_start > window_end: continue`
        # is fully covered by the new checks.
        # We don't need to repeat it.

        # But we DO need to calculate stay_start and stay_end for subsequent logic (merging intervals)
        # In the real code, we use stay_start and stay_end.
        # Here we simulate processing.

        count += 1
    return count

def run_benchmark():
    reference_date = datetime.datetime.now()

    stays = []
    # 5000 Past
    for i in range(5000):
        start = reference_date - datetime.timedelta(days=300 + i)
        end = start + datetime.timedelta(days=1)
        stays.append(Stay(start, end))

    # 100 Window
    for i in range(100):
        start = reference_date - datetime.timedelta(days=50 - i)
        end = start + datetime.timedelta(days=1)
        stays.append(Stay(start, end))

    # 5000 Future
    for i in range(5000):
        start = reference_date + datetime.timedelta(days=200 + i)
        end = start + datetime.timedelta(days=1)
        stays.append(Stay(start, end))

    # Sort descending
    stays.sort(key=lambda s: s.entered_on, reverse=True)

    print(f"Total stays: {len(stays)}")

    iterations = 100

    start_time = time.time()
    for _ in range(iterations):
        original_summary(stays, reference_date)
    end_time = time.time()
    print(f"Original: {end_time - start_time:.4f}s")

    start_time = time.time()
    for _ in range(iterations):
        optimized_summary(stays, reference_date)
    end_time = time.time()
    print(f"Optimized: {end_time - start_time:.4f}s")

if __name__ == "__main__":
    run_benchmark()
