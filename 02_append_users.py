"""
02_append_users.py
-------------------
Reads all users CSV files from data/raw/users/,
cleans column types, and appends the combined table
to data/processed/analytics.db (same database as orders).

Schema produced (users table):
    id                       TEXT      -- user identifier
    createdat                DATETIME  -- registration date
    birthdate                TEXT      -- date of birth (kept as string)
    gender                   CATEGORY  -- user gender
    source                   TEXT      -- registration source / channel
    historysources           TEXT      -- prior channel touchpoints
    type                     TEXT      -- user account type
    verificationstatus       INT       -- KYC verification level (0/1/2…)
    ordercount               INT       -- total lifetime orders placed
    totaldeposit             REAL      -- lifetime deposit amount
    totalwithdraw            REAL      -- lifetime withdrawal amount
    totalwithdrawgoldenvalue REAL      -- lifetime gold withdrawal value
    source_file              TEXT      -- original CSV filename (audit trail)
"""

import os
import glob
import sqlite3
import pandas as pd

# ── Paths ────────────────────────────────────────────────────────────────────
BASE_DIR  = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW_PATH  = os.path.join(BASE_DIR, "data", "raw", "users")
DB_PATH   = os.path.join(BASE_DIR, "data", "processed", "analytics.db")

# ── 1. Discover CSV files ─────────────────────────────────────────────────────
all_files = glob.glob(os.path.join(RAW_PATH, "*.csv"))

if not all_files:
    raise FileNotFoundError(
        f"No CSV files found in: {RAW_PATH}\n"
        "Place your users CSVs inside data/raw/users/ and re-run."
    )

print(f"📂  Found {len(all_files)} users file(s)")

# ── 2. Read & stack ───────────────────────────────────────────────────────────
frames = []
for path in all_files:
    df = pd.read_csv(path, low_memory=False)
    df["source_file"] = os.path.basename(path)
    frames.append(df)
    print(f"   ✓ {os.path.basename(path):40s}  {len(df):>7,} rows")

# Align columns
all_cols = sorted(set().union(*[df.columns for df in frames]))
frames   = [df.reindex(columns=all_cols) for df in frames]

combined = pd.concat(frames, ignore_index=True)
print(f"\n✅  Combined: {len(combined):,} rows × {len(combined.columns)} columns")

# ── 3. Parse registration date ────────────────────────────────────────────────
if "CreatedAt" in combined.columns:
    combined["CreatedAt"] = pd.to_datetime(
        combined["CreatedAt"].astype(str).str.strip(),
        errors="coerce",
    )
    invalid = combined["CreatedAt"].isna().sum()
    print(f"🕒  Registration range: {combined['CreatedAt'].min().date()} → {combined['CreatedAt'].max().date()}")
    if invalid:
        print(f"⚠️   {invalid:,} rows with unparseable registration dates")

# ── 4. Clean numeric columns ──────────────────────────────────────────────────
numeric_cols = [
    "OrderCount",
    "TotalDeposit",
    "TotalWithdraw",
    "TotalWithdrawGoldenValue",
    "VerificationStatus",
]

for col in numeric_cols:
    if col in combined.columns:
        combined[col] = pd.to_numeric(
            combined[col].astype(str).str.replace(",", "", regex=False).str.strip(),
            errors="coerce",
        )

# ── 5. Guard birthdate (keep as string, replace nullish values with None) ─────
if "Birthdate" in combined.columns:
    combined["Birthdate"] = (
        combined["Birthdate"]
        .astype(str)
        .str.strip()
        .replace(["nan", "None", "NaT", ""], pd.NA)
    )

# ── 6. Memory optimisation for low-cardinality columns ───────────────────────
cat_cols = ["Gender", "Source", "HistorySources", "Type", "source_file"]
for col in cat_cols:
    if col in combined.columns:
        combined[col] = combined[col].astype("category")

# ── 7. Summary ────────────────────────────────────────────────────────────────
print("\n🧪  Column dtypes:")
print(combined.dtypes.to_string())

# ── 8. Save to SQLite ─────────────────────────────────────────────────────────
conn = sqlite3.connect(DB_PATH)
combined.to_sql("users", conn, if_exists="replace", index=False)

if "CreatedAt" in combined.columns:
    conn.execute("CREATE INDEX IF NOT EXISTS idx_users_createdat ON users(CreatedAt)")
conn.commit()
conn.close()

print(f"\n🎯  users table saved → {DB_PATH}")
print(    "    Index created on: CreatedAt")
