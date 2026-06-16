---
paths:
  - "**/database.py"
  - "**/src/database.py"
---

# Database Connection

## Server
- **Host:** GCSQL02.ASTROS.COM
- **Database:** GroundControl2
- **Driver (work laptop):** ODBC Driver 17 for SQL Server (Windows Auth)
- **Driver (Posit Connect):** FreeTDS (`/usr/lib/x86_64-linux-gnu/odbc/libtdsodbc.so`)

## Posit Connect (Linux) — FreeTDS
```python
DRIVER = '/usr/lib/x86_64-linux-gnu/odbc/libtdsodbc.so'
# Domain auth: UID=BASEBALL\zbridger, PWD="" (not needed)
# TDS_VERSION=7.4, Trusted_Connection=no
# Env vars DB_USER/DB_PASS set in Posit Connect Vars tab
```
> Full connection code block: `docs/ARCHIVED_REFERENCES.md`

## Work Laptop (Windows)
```python
DRIVER = '{ODBC Driver 17 for SQL Server}'
# Windows Auth (Trusted_Connection=yes), no UID/PWD needed
```

## Dual-Mode Pattern (all 4 database.py files)
Each project's `database.py` detects environment (Linux vs Windows) and picks the right driver + auth automatically. Lives in: `barrelsville/src/database.py`, `bullpen-report/src/database.py`, `intangibles/src/database.py`, `pd-goals/src/database.py`.
