
import sqlite3
import time
import random
from datetime import datetime, timedelta

def setup_database():
    conn = sqlite3.connect(":memory:")
    cursor = conn.cursor()
    cursor.execute("""
        CREATE TABLE DayOverride (
            id INTEGER PRIMARY KEY,
            date TEXT,
            countryName TEXT,
            region TEXT
        )
    """)

    # Populate 10,000 records
    base_date = datetime.now()
    records = []
    for i in range(10000):
        date = base_date + timedelta(days=i - 5000)
        date_str = date.strftime("%Y-%m-%d")
        records.append((date_str, f"Country {i}", "Schengen"))

    cursor.executemany("INSERT INTO DayOverride (date, countryName, region) VALUES (?, ?, ?)", records)
    conn.commit()
    return conn

def benchmark_fetch_all(conn, start_date, end_date):
    start_time = time.time()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM DayOverride")
    all_overrides = cursor.fetchall()

    # Application-level filtering
    filtered_overrides = [
        row for row in all_overrides
        if start_date <= row[1] <= end_date
    ]
    duration = time.time() - start_time
    return duration, len(filtered_overrides)

def benchmark_fetch_predicate(conn, start_date, end_date):
    start_time = time.time()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM DayOverride WHERE date >= ? AND date <= ?", (start_date, end_date))
    filtered_overrides = cursor.fetchall()
    duration = time.time() - start_time
    return duration, len(filtered_overrides)

def main():
    conn = setup_database()

    start_date = (datetime.now() + timedelta(days=10)).strftime("%Y-%m-%d")
    end_date = (datetime.now() + timedelta(days=40)).strftime("%Y-%m-%d")

    print(f"Benchmarking with range: {start_date} to {end_date}")

    duration_all, count_all = benchmark_fetch_all(conn, start_date, end_date)
    print(f"Fetch All + Filter: {duration_all:.6f} seconds. Count: {count_all}")

    duration_predicate, count_predicate = benchmark_fetch_predicate(conn, start_date, end_date)
    print(f"Fetch Predicate: {duration_predicate:.6f} seconds. Count: {count_predicate}")

    improvement = duration_all / duration_predicate
    print(f"Improvement Factor: {improvement:.2f}x")

    conn.close()

if __name__ == "__main__":
    main()
