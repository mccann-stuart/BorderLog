import datetime

class Day:
    def __init__(self, date_str, is_disputed, is_manual):
        self.date = datetime.datetime.strptime(date_str, "%Y-%m-%d")
        self.isDisputed = is_disputed
        self.isManuallyModified = is_manual

# Mock data reverse sorted
days = [
    Day("2026-03-01", False, False), # Future
    Day("2026-02-15", True, False),  # Inside, disputed
    Day("2025-10-01", True, True),   # Inside, disputed but manual
    Day("2025-01-01", False, False), # Inside
    Day("2023-10-01", True, False),  # Outside, disputed
    Day("2020-01-01", False, False)  # Outside
]

start_date = datetime.datetime.strptime("2024-02-17", "%Y-%m-%d")
end_date = datetime.datetime.strptime("2026-02-17", "%Y-%m-%d")

# Old approach
recent_count_old = len([d for d in days if start_date <= d.date <= end_date])
disputed_count_old = len([d for d in days if start_date <= d.date <= end_date and d.isDisputed and not d.isManuallyModified])

# New approach
recent_count_new = 0
disputed_count_new = 0

for d in days:
    if d.date > end_date:
        continue
    if d.date < start_date:
        break
    recent_count_new += 1
    if d.isDisputed and not d.isManuallyModified:
        disputed_count_new += 1

print(f"Old: recent={recent_count_old}, disputed={disputed_count_old}")
print(f"New: recent={recent_count_new}, disputed={disputed_count_new}")

assert recent_count_old == recent_count_new
assert disputed_count_old == disputed_count_new
print("Tests passed!")
