---
type: concept
domain: modeling
source: personal-bsbres/examples
created: '2026-06-15'
---
# HP cross-DB pipeline — biomech data plumbing

The SQL/SQLAlchemy data layer that feeds the [[dsproj-data-science-examples]] models — two MySQL databases, a cross-DB outer join, and the per-athlete "best test" reduction. Scripts: `sql_setup.py`, `SQL_pull_test.py`, `expanded_sql.py`, `90plus.sql`.

## The two databases

| Engine | Host | DB | Holds |
|---|---|---|---|
| `engine_hp_data` | `computer-vision-cluster-do-user-286562-0...ondigitalocean.com:25060` | `hp_data.hp_tests` | force-plate aggregates + `pitch_speed_mph` + `bat_speed_mph` + `athlete_name` |
| `engine_statcast` | `10.200.200.107:3306` | `theia_hitting_db` | Theia markerless biomech: `poi` / `trials` / `sessions` / `users`, `blast_bat_speed_mph`, `level` |

Connection idiom (SQLAlchemy + pymysql): `create_engine("mysql+pymysql://user:pass@host:port/db")`, then `pd.read_sql(query, con=engine)`. `SQL_pull_test.py` uses a raw `pymysql.connect(...)` instead and closes the conn after the fetch.

## `90plus.sql` / `sql_setup.py` — the 90+ HP query

The canonical force-plate pull, gated to MLB-velo arms:
```sql
SELECT athlete, test_date, athlete_name,
    `body_weight_[lbs]`, `peak_power_[w]_mean_cmj`, `peak_power_[w]_mean_sj`,
    `best_rsi_(flight/contact_time)_mean_ht`, `peak_takeoff_force_[n]_mean_pp`,
    `net_peak_vertical_force_[n]_max_imtp`, pitching_max_hss, pitch_speed_mph
FROM `hp_data`.`hp_tests`
WHERE pitch_speed_mph >= 90;     -- (90plus.sql uses > 89.9)
```
Backtick-quoted column names because they contain `[ ]`, `( )`, `/` — these are HumanTrak/ForceDecks export names carried verbatim. This same name set is why every Python script keeps the awkward `peak_power_[w]_mean_cmj` literals.

## `expanded_sql.py` — cross-DB merge (the interesting one)

Joins **Theia bat speed** ↔ **HP peak power** across the two databases by athlete name, after reducing each to one row per player:

```python
# Theia: keep best blast bat speed per name
statcastdb = statcastdb[statcastdb["blast_bat_speed_mph"] >= 1]
statcastdb = statcastdb.loc[statcastdb.groupby("name")["blast_bat_speed_mph"].idxmax()]

# HP: keep best CMJ peak power per athlete
full_data = full_data[full_data["peak_power_[w]_mean_cmj"] >= 1]
full_data = full_data.loc[full_data.groupby("athlete_name")["peak_power_[w]_mean_cmj"].idxmax()]

combined = pd.merge(statcastdb[["name","blast_bat_speed_mph","level"]],
                    full_data[["athlete_name","peak_power_[w]_mean_cmj","playing_level"]],
                    how="outer", left_on="name", right_on="athlete_name")
```

Two reusable techniques:
- **`groupby(key)[metric].idxmax()` "best row per player" reduction** — collapse multiple tests to each athlete's peak, in `.loc[...]` form.
- **Full outer join across separate DB engines in pandas** — pull each DB into its own DataFrame, then `pd.merge(how="outer")` on the name key (handling the `name` vs `athlete_name` column mismatch).

## Cleaning convention

Every consumer runs `df.replace('\\N', pd.NA)` — MySQL's `\N` null sentinel comes through as a literal string and has to be converted before `dropna`/numeric ops. (Mirror of the BSB production `replace('\\N', ...)` habit.)

## Links

- [[dsproj-data-science-examples]] (parent index)
- [[velo-prediction-rf]] · [[support-vector-regression-baseball]] (consumers of these pulls)
- [[statcast-pipeline]] (the Astros production data-pull analogue)
- [[biomech-scores]] · [[hitting-biomechanics]]
