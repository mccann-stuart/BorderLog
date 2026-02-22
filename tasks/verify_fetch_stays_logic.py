import datetime

# Define a minimal Stay class
class Stay:
    def __init__(self, entered_on, exited_on=None):
        self.entered_on = entered_on
        self.exited_on = exited_on

    def __repr__(self):
        exit_str = self.exited_on.strftime('%Y-%m-%d') if self.exited_on else "None"
        return f"Stay(start={self.entered_on.strftime('%Y-%m-%d')}, end={exit_str})"

def verify_logic():
    # Helper to create dates
    def d(str_date):
        return datetime.datetime.strptime(str_date, '%Y-%m-%d')

    # Constants
    DISTANT_FUTURE = datetime.datetime.max

    # Test Cases
    stays = [
        Stay(d('2023-01-01'), d('2023-01-10')), # 0: Completely before
        Stay(d('2023-01-25'), d('2023-02-05')), # 1: Overlaps start
        Stay(d('2023-02-10'), d('2023-02-20')), # 2: Completely inside
        Stay(d('2023-02-25'), d('2023-03-05')), # 3: Overlaps end
        Stay(d('2023-03-10'), d('2023-03-20')), # 4: Completely after
        Stay(d('2023-01-01'), d('2023-04-01')), # 5: Encloses range
        Stay(d('2023-02-28'), None),            # 6: Starts inside, open ended (overlaps end)
        Stay(d('2023-01-01'), None),            # 7: Starts before, open ended (encloses range)
        Stay(d('2023-03-05'), None),            # 8: Starts after, open ended (no overlap)
        Stay(d('2023-03-01'), None),            # 9: Starts exactly on end date (overlap if inclusive)
    ]

    # Query Range
    start = d('2023-02-01')
    end = d('2023-03-01')

    print(f"Query Range: {start.strftime('%Y-%m-%d')} to {end.strftime('%Y-%m-%d')}")

    # Ground Truth: Calculate overlaps manually
    expected_indices = []
    for i, stay in enumerate(stays):
        stay_end = stay.exited_on if stay.exited_on else DISTANT_FUTURE
        # Logic: Overlap if (StartA <= EndB) and (EndA >= StartB)
        # Here A=Stay, B=Query
        # StayStart <= QueryEnd AND StayEnd >= QueryStart
        if stay.entered_on <= end and stay_end >= start:
            expected_indices.append(i)

    print(f"Expected Overlapping Indices: {expected_indices}")

    # Predicate Logic Simulation
    # Swift Predicate: stay.enteredOn <= end && (stay.exitedOn ?? distantFuture) >= start
    matched_indices = []
    for i, stay in enumerate(stays):
        term1 = stay.entered_on <= end
        stay_end_val = stay.exited_on if stay.exited_on else DISTANT_FUTURE
        term2 = stay_end_val >= start

        if term1 and term2:
            matched_indices.append(i)

    print(f"Matched Indices (Predicate): {matched_indices}")

    # Assertions
    assert expected_indices == matched_indices, f"Mismatch! Expected {expected_indices}, got {matched_indices}"

    # Specific assertions for clarity
    assert 0 not in matched_indices # Completely before
    assert 1 in matched_indices     # Overlaps start
    assert 2 in matched_indices     # Completely inside
    assert 3 in matched_indices     # Overlaps end
    assert 4 not in matched_indices # Completely after
    assert 5 in matched_indices     # Encloses
    assert 6 in matched_indices     # Open ended starts inside
    assert 7 in matched_indices     # Open ended starts before
    assert 8 not in matched_indices # Open ended starts after
    assert 9 in matched_indices     # Boundary check (starts on end day)

    print("\n✅ Verification Successful: Predicate logic matches expected overlap logic.")

if __name__ == "__main__":
    verify_logic()
