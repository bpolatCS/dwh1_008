"""Small orchestration helpers for the DWH1 assignment notebook.

The notebook shows the assignment workflow; this module keeps repetitive
Python plumbing out of the notebook so that student work remains focused on
DDL, ETL, validation, and other SQL artefacts.

The helpers deliberately stay simple and explicit. They handle connection
setup, schema resets, CSV loading, SQL execution, validation summaries, and
creation of the final warehouse dump.
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import time
from getpass import getpass
from pathlib import Path
from typing import Iterable, Sequence
from urllib.parse import quote_plus

import pandas as pd
import sqlparse
from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine, make_url


_GROUP_RE = re.compile(r"^\d{3}$")
_IDENTIFIER_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
_DATE_SUFFIXES = ("from", "to", "at")

_CHECK_PASS_VALUES = {"PASS"}
_CHECK_FAIL_VALUES = {"FAIL"}


DEFAULT_DDL_FILES = (
    "airq_create_stg1.sql",
    "airq_create_ext.sql",
    "airq_create_dwh1.sql",
)


# The 15 original snapshot tables are fixed; two more names come from the
# students' Table X and Table Y extension files.
STANDARD_CSV_TABLES = (
    "tb_servicetype", "tb_role", "tb_employee", "tb_country", "tb_city",
    "tb_readingmode", "tb_alert", "tb_param", "tb_paramalert",
    "tb_sensortype", "tb_paramsensortype", "tb_sensordevice", "tb_weather",
    "tb_serviceevent", "tb_readingevent",
)


def _single_group_csv(root_dir: str | Path, prefix: str, group: str | None = None) -> tuple[Path, str]:
    """Find one strictly named group CSV without guessing between candidates."""
    root = Path(root_dir).resolve()
    if not root.is_dir():
        raise FileNotFoundError(f"Assignment directory does not exist: {root}")

    candidates = sorted(
        p for p in root.iterdir()
        if p.is_file() and p.name.lower().startswith(prefix.lower())
        and p.suffix.lower() == ".csv"
    )
    if not candidates:
        expected = f"{prefix}{group}.csv" if group else f"{prefix}NNN.csv"
        raise FileNotFoundError(f"Missing {expected} in the assignment folder: {root}")
    if len(candidates) != 1:
        names = ", ".join(p.name for p in candidates)
        raise ValueError(f"Expected exactly one {prefix}NNN.csv; found: {names}. Remove leftover templates/copies.")

    path = candidates[0]
    pattern = re.compile(rf"{re.escape(prefix)}([0-9]{{3}})\.csv")
    match = pattern.fullmatch(path.name)
    if match is None:
        if path.name == f"{prefix}NNN.csv":
            raise ValueError(
                f"Rename {path.name}: replace NNN with your three-digit group number (e.g. 007)."
            )
        raise ValueError(f"Invalid filename {path.name!r}; expected {prefix}NNN.csv (exactly three digits).")

    file_group = match.group(1)
    if group is not None and file_group != validate_group(group):
        raise ValueError(
            f"{path.name} does not match group_{group}.csv. Both files must use the same group number."
        )
    return path, file_group


def read_group_roster(root_dir: str | Path) -> dict[str, object]:
    """Load/validate the A/B roster; derive group ID solely from its filename."""
    path, group = _single_group_csv(root_dir, "group_")
    try:
        rows = pd.read_csv(path, dtype=str, keep_default_na=False, encoding="utf-8-sig")
    except (pd.errors.ParserError, pd.errors.EmptyDataError, UnicodeError) as exc:
        raise ValueError(f"Cannot read {path.name} as a valid CSV: {exc}") from exc

    columns = ["student_role", "student_number", "student_name"]
    if list(rows.columns) != columns:
        raise ValueError(f"{path.name}: expected exactly these columns, in order: {', '.join(columns)}.")
    if len(rows) != 2:
        raise ValueError(f"{path.name}: expected exactly two rows, one for A and one for B; got {len(rows)}.")

    people: dict[str, dict[str, str]] = {}
    for record in rows.to_dict("records"):
        role = str(record["student_role"]).strip()
        if role not in ("A", "B") or role in people:
            raise ValueError(f"{path.name}: student_role must contain exactly one A row and one B row.")
        people[role] = {
            "student_role": role,
            "student_number": str(record["student_number"]).strip(),
            "student_name": str(record["student_name"]).strip(),
        }
    if set(people) != {"A", "B"}:
        raise ValueError(f"{path.name}: exactly one A row and one B row are required.")

    a, b = people["A"], people["B"]
    for person in (a, b):
        role = person["student_role"]
        number = person["student_number"]
        name = person["student_name"]
        if not number:
            raise ValueError(
                f"{path.name}: Student {role}'s student_number is required. "
                "For a one-student group, enter the same number and name in both A and B rows."
            )
        if not (number.isascii() and number.isdigit()):
            raise ValueError(f"{path.name}: Student {role}'s student_number must contain digits only.")
        if not name:
            raise ValueError(f"{path.name}: Student {role}'s student_name is required.")

    if a["student_name"].casefold() == "anton chekhov":
        raise ValueError(f"{path.name}: replace Anton Chekhov with Student A's real name.")
    if b["student_name"].casefold() == "agatha christie":
        raise ValueError(f"{path.name}: replace Agatha Christie with Student B's real name.")

    if a["student_number"] == b["student_number"]:
        if a["student_name"] != b["student_name"]:
            raise ValueError(
                f"{path.name}: A and B have the same student number, so their names "
                "must also be identical for a one-student group."
            )
        # Keep both completed CSV rows intact; display the actual student once.
        members = [a]
        membership = "One-student group"
    else:
        members = [a, b]
        membership = "Two-student group"

    return {"group": group, "members": members, "membership": membership, "path": path}


def read_csv_load_order(root_dir: str | Path, *, group: str) -> list[str]:
    """Read a student-specified 17-table CSV sequence without reordering it."""
    path, _ = _single_group_csv(root_dir, "csv_load_order_", group=group)
    try:
        rows = pd.read_csv(path, dtype=str, keep_default_na=False, encoding="utf-8-sig")
    except (pd.errors.ParserError, pd.errors.EmptyDataError, UnicodeError) as exc:
        raise ValueError(f"Cannot read {path.name} as a valid CSV: {exc}") from exc
    if list(rows.columns) != ["table_name"]:
        raise ValueError(f"{path.name}: expected exactly one column named table_name.")
    if len(rows) != 17:
        raise ValueError(f"{path.name}: expected exactly 17 table rows, got {len(rows)}.")

    order = [str(value).strip() for value in rows["table_name"]]
    for table in order:
        _validate_identifier(table, "table name")
    duplicates = sorted({table for table in order if order.count(table) > 1})
    if duplicates:
        raise ValueError(f"{path.name}: duplicate table name(s): {', '.join(duplicates)}.")

    expected = set(STANDARD_CSV_TABLES)
    missing = sorted(expected - set(order))
    if missing:
        raise ValueError(f"{path.name}: missing standard table(s): {', '.join(missing)}.")
    extensions = [table for table in order if table not in expected]
    if len(extensions) != 2:
        raise ValueError(f"{path.name}: expected exactly two Table X/Y extension names, got {len(extensions)}.")
    return order


def validate_group(group: str) -> str:
    """Return a validated three-digit group number."""
    value = str(group).strip()
    if not _GROUP_RE.fullmatch(value):
        raise ValueError(
            f"Group number must contain exactly three digits (for example '007'); got {group!r}."
        )
    return value


def _validate_identifier(value: str, label: str = "identifier") -> str:
    """Validate an identifier before it is interpolated into SQL."""
    if not _IDENTIFIER_RE.fullmatch(value):
        raise ValueError(f"Invalid SQL {label}: {value!r}")
    return value


def _quote_identifier(value: str) -> str:
    """Return a safely quoted PostgreSQL identifier."""
    _validate_identifier(value)
    return f'"{value}"'


def schema_names(group: str) -> tuple[str, str]:
    """Return (staging_schema, warehouse_schema) for a group."""
    group = validate_group(group)
    return f"stg1_{group}", f"dwh1_{group}"


def database_user(group: str) -> str:
    """Return the PostgreSQL login role for a group."""
    return f"grp_{validate_group(group)}"


def connect_database(
    group: str,
    *,
    database: str = "airq",
    host: str = "localhost",
    port: int = 5432,
    password: str | None = None,
) -> tuple[Engine, dict[str, object]]:
    """Connect as grp_<group> and return (SQLAlchemy engine, connection settings).

    If ``password`` is omitted, it is requested once without echoing it.
    The returned settings dictionary is intended only for the later pg_dump call;
    the password is never printed.
    """
    group = validate_group(group)
    user = database_user(group)

    if password is None:
        password = getpass(
            f"Password for {user}@{host}:{port}/{database} "
            "(leave empty if not needed): "
        )

    if password:
        dsn = (
            f"postgresql+psycopg2://{user}:{quote_plus(password)}"
            f"@{host}:{port}/{database}"
        )
    else:
        dsn = f"postgresql+psycopg2://{user}@{host}:{port}/{database}"

    masked = str(make_url(dsn).set(password="***" if password else None))
    print("Connecting via:", masked)

    # Verify the connection immediately so configuration problems fail early.
    engine = create_engine(dsn, future=True, pool_pre_ping=True)
    with engine.begin() as conn:
        row = conn.exec_driver_sql(
            "SELECT current_user, current_database()"
        ).one()

    current_user, current_database = row
    if current_user != user:
        engine.dispose()
        raise RuntimeError(
            f"Connected as {current_user!r}, but DWH1 expects {user!r}. "
            "Run the bootstrap and connect with the group role."
        )
    if current_database != database:
        engine.dispose()
        raise RuntimeError(
            f"Connected to database {current_database!r}, expected {database!r}."
        )

    print(f"Connected as {current_user} to database {current_database}.")

    db_settings: dict[str, object] = {
        "user": user,
        "password": password,
        "database": database,
        "host": host,
        "port": int(port),
    }
    return engine, db_settings


# This is intentionally a narrow SQL check, not a general SQL parser.
# We inspect executable tokens, ignoring comments and string literals, so
# table aliases, SQL examples in comments and pg_catalog metadata remain valid.
_ASSIGNMENT_SCHEMA_RE = re.compile(
    r"^(?:stg|dwh)(?:1|2)?_(?:[0-9]{3}|[A-Za-z]{3})$", re.IGNORECASE
)
_DOLLAR_QUOTE_RE = re.compile(r"\$[A-Za-z_][A-Za-z_0-9]*\$|\$\$")


def _sql_policy_tokens(source: str) -> list[tuple[str, str, int]]:
    """Read identifiers, punctuation and strings without interpreting SQL comments.

    Entries are (kind, value, character_offset). SQL quoted identifiers are
    identifiers, whereas string constants never count as identifiers.
    """
    tokens: list[tuple[str, str, int]] = []
    i, n = 0, len(source)
    while i < n:
        char = source[i]
        if char.isspace():
            i += 1
            continue
        if source.startswith("--", i):
            end = source.find("\n", i + 2)
            i = n if end < 0 else end + 1
            continue
        if source.startswith("/*", i):
            depth = 1
            i += 2
            while i < n and depth:
                if source.startswith("/*", i):
                    depth += 1
                    i += 2
                elif source.startswith("*/", i):
                    depth -= 1
                    i += 2
                else:
                    i += 1
            continue
        tag = _DOLLAR_QUOTE_RE.match(source, i) if char == '$' else None
        if tag:
            marker = tag.group(0)
            end = source.find(marker, tag.end())
            if end >= 0:
                tokens.append(("string", source[tag.end():end], i))
                i = end + len(marker)
                continue
        if char == "'":
            start = i
            i += 1
            value = []
            # E'...' escapes backslashes; for ordinary strings PostgreSQL's
            # doubled-quote convention is sufficient.
            escape_mode = start > 0 and source[start-1] in "Ee" and (start == 1 or not source[start-2].isalnum())
            while i < n:
                if escape_mode and source[i] == "\\" and i + 1 < n:
                    value.append(source[i + 1])
                    i += 2
                elif source[i] == "'":
                    if i + 1 < n and source[i+1] == "'":
                        value.append("'")
                        i += 2
                    else:
                        i += 1
                        break
                else:
                    value.append(source[i])
                    i += 1
            tokens.append(("string", "".join(value), start))
            continue
        if char == '"':
            start = i
            i += 1
            value = []
            while i < n:
                if source[i] == '"':
                    if i + 1 < n and source[i+1] == '"':
                        value.append('"')
                        i += 2
                    else:
                        i += 1
                        break
                else:
                    value.append(source[i])
                    i += 1
            tokens.append(("identifier", "".join(value), start))
            continue
        if char.isalpha() or char == '_':
            start = i
            i += 1
            while i < n and (source[i].isalnum() or source[i] in '_$'):
                i += 1
            tokens.append(("identifier", source[start:i], start))
            continue
        if char in '.();,=':
            tokens.append(("punct", char, i))
        i += 1
    return tokens


def schema_neutrality_issues(source: str) -> list[tuple[int, str]]:
    """Return (SQL line, student-facing explanation) for prohibited schema use.

    The orchestrator owns assignment schemas and the search_path. Qualified
    column references like c.id and metadata sources like pg_catalog are valid.
    """
    tokens = _sql_policy_tokens(source)
    issues: list[tuple[int, str]] = []
    seen: set[tuple[int, str]] = set()

    def add(position: int, message: str) -> None:
        line = source.count('\n', 0, position) + 1
        entry = (line, message)
        if entry not in seen:
            seen.add(entry)
            issues.append(entry)

    def key(token: tuple[str, str, int]) -> str:
        return token[1].casefold() if token[0] == 'identifier' else ''

    for i, token in enumerate(tokens):
        kind, value, position = token
        name = key(token)
        if kind == 'identifier' and _ASSIGNMENT_SCHEMA_RE.fullmatch(value):
            # A schema.table reference, including quoted/multiline variants.
            if i+1 < len(tokens) and tokens[i+1][1] == '.':
                add(position, f"remove the '{value}.' schema prefix; use the table name directly")
            # Bare assignment schema names in CREATE/DROP/ALTER SCHEMA,
            # GRANT/REVOKE ... ON SCHEMA, including IF [NOT] EXISTS variants.
            elif (
                i >= 2 and key(tokens[i-1]) == 'schema'
                and key(tokens[i-2]) in ('create', 'drop', 'alter', 'on')
            ) or (
                i >= 3 and key(tokens[i-3]) == 'schema'
                and key(tokens[i-2]) == 'if' and key(tokens[i-1]) == 'exists'
            ) or (
                i >= 4 and key(tokens[i-4]) == 'schema'
                and key(tokens[i-3]) == 'if'
                and key(tokens[i-2]) == 'not'
                and key(tokens[i-1]) == 'exists'
            ):
                add(position, f"do not manage the assignment schema '{value}' in a SQL file")

        if name == 'set_config' and i+2 < len(tokens):
            # Includes SELECT pg_catalog.set_config('search_path', ...).
            if tokens[i+1][1] == '(' and tokens[i+2][0] == 'string' and tokens[i+2][1].casefold() == 'search_path':
                add(position, "remove set_config('search_path', ...); the notebook sets the search path")

    # SET and RESET at the beginning of a statement, as well as ALTER ROLE,
    # DATABASE, FUNCTION or SYSTEM ... SET search_path forms.
    segments: list[list[tuple[str, str, int]]] = [[]]
    for token in tokens:
        if token[1] == ';' and token[0] == 'punct':
            segments.append([])
        else:
            segments[-1].append(token)
    for seg in segments:
        if not seg:
            continue
        first = key(seg[0])
        if first in ('set', 'reset'):
            j = 1
            if j < len(seg) and key(seg[j]) in ('local', 'session'):
                j += 1
            if j < len(seg) and key(seg[j]) in ('search_path', 'schema'):
                add(seg[0][2], 'remove SET/RESET search_path or SET SCHEMA; the notebook selects schemas automatically')
        if first == 'alter':
            for i, token in enumerate(seg):
                if key(token) != 'set':
                    continue
                j = i + 1
                if j < len(seg) and key(seg[j]) in ('local', 'session'):
                    j += 1
                if j < len(seg) and key(seg[j]) == 'search_path':
                    add(token[2], 'remove ALTER ... SET search_path; the notebook selects schemas automatically')
    return sorted(issues)


def ensure_schema_neutral(path: Path, source: str) -> None:
    """Block group-specific SQL before it is sent to PostgreSQL."""
    issues = schema_neutrality_issues(source)
    if issues:
        detail = '\n'.join(f"  {path.name}, line {line}: {message}" for line, message in issues[:12])
        extra = f"\n  ... and {len(issues)-12} more issue(s)" if len(issues) > 12 else ''
        raise ValueError(
            f"Schema-neutral SQL is required. Please correct:\n{detail}{extra}\n"
            'Use plain table names (for example, FROM tb_city). Normal aliases '
            '(for example, c.cityname) and pg_catalog references are allowed.'
        )


def preflight(
    root_dir: str | Path,
    *,
    group: str,
    csv_load_order: Sequence[str],
    ddl_files: Sequence[str] = DEFAULT_DDL_FILES,
    etl_pattern: str = "a1_etl*.sql",
    post_pattern: str = "a1_check*.sql",
) -> dict[str, object]:
    """Check all required input files before any database reset or loading.

    Group roster and 17-row load order must already have passed startup checks.
    Any explicit assignment-schema qualification or attempt to change the
    SQL search path is a hard preflight error, before database work begins.
    """
    group = validate_group(group)
    root = Path(root_dir).resolve()
    dirs = {
        "csv": root / "csv", "data": root / "data", "ddl": root / "ddl",
        "etl": root / "etl", "post": root / "post", "sqldump": root / "sqldump",
        "src": root / "src",
    }
    missing_dirs = [key for key in ("csv", "data", "ddl", "etl", "post", "src") if not dirs[key].is_dir()]
    if missing_dirs:
        raise FileNotFoundError("Missing DWH1 folder(s): " + ", ".join(missing_dirs))

    missing: list[Path] = []
    for table in csv_load_order:
        folder = dirs["csv"] if table in STANDARD_CSV_TABLES else dirs["data"]
        path = folder / f"{table}.csv"
        if not path.is_file():
            missing.append(path)
    for filename in ddl_files:
        path = dirs["ddl"] / filename
        if not path.is_file():
            missing.append(path)
    if missing:
        rel = [str(path.relative_to(root)) for path in missing]
        raise FileNotFoundError("Preflight missing required file(s):\n  - " + "\n  - ".join(rel))

    etl_files = sorted(dirs["etl"].glob(etl_pattern))
    post_files = sorted(dirs["post"].glob(post_pattern))
    if not etl_files:
        raise FileNotFoundError(f"No ETL files found matching etl/{etl_pattern}")
    if not post_files:
        raise FileNotFoundError(f"No validation SQL found matching post/{post_pattern}")

    # Validate every student SQL file (including spare .sql files) before
    # altering database schemas. Collect errors so students can fix them once.
    sql_issues = []
    for folder_name in ("ddl", "etl", "post"):
        for path in sorted(dirs[folder_name].glob("*.sql")):
            relative = path.relative_to(root)
            try:
                sql_source = path.read_text(encoding="utf-8-sig")
            except UnicodeDecodeError:
                sql_issues.append(f"  {relative}: save this file as UTF-8 text")
                continue
            for line, message in schema_neutrality_issues(sql_source):
                sql_issues.append(f"  {relative}, line {line}: {message}")
    if sql_issues:
        detail = "\n".join(sql_issues[:20])
        rest = f"\n  ... and {len(sql_issues)-20} more issue(s)" if len(sql_issues) > 20 else ""
        raise ValueError(
            "Schema-neutral SQL check FAILED. Update these external SQL files "
            "before running the notebook:\n" + detail + rest +
            "\nUse plain table names and remove statements changing search_path. "
            "The notebook manages the correct schema automatically. "
            "No database schemas have been reset."
        )

    dirs["sqldump"].mkdir(parents=True, exist_ok=True)
    standard_n = sum(table in STANDARD_CSV_TABLES for table in csv_load_order)
    extension_n = len(csv_load_order) - standard_n
    print(f"Preflight PASS for DWH1_{group}")
    print(f"  Source CSV order : {len(csv_load_order)} rows ({standard_n} standard + {extension_n} extensions)")
    print(f"  DDL files        : {len(ddl_files)}")
    print(f"  ETL files        : {len(etl_files)}")
    print(f"  Post-check files : {len(post_files)}")
    print("  Schema-neutral SQL: PASS")
    return {"root": root, "etl_files": etl_files, "post_files": post_files}



def verify_load_order_dependencies(
    engine: Engine, *, schema: str, csv_load_order: Sequence[str]
) -> None:
    """Check FK dependencies in the actual staging DDL before inserting any CSV rows.

    This validates dependency ordering, not equality to a reference sequence.
    Student extension tables are checked using their *declared* foreign keys.
    """
    schema = _validate_identifier(schema, "schema name")
    positions = {table: i for i, table in enumerate(csv_load_order)}
    with engine.connect() as conn:
        present = set(conn.execute(
            text("SELECT tablename FROM pg_catalog.pg_tables WHERE schemaname = :schema"),
            {"schema": schema},
        ).scalars())
        missing = sorted(set(csv_load_order) - present)
        if missing:
            raise ValueError(
                f"Staging DDL is missing table(s) listed in csv_load_order: {', '.join(missing)}. "
                "The notebook will not create missing tables automatically."
            )
        foreign_keys = conn.execute(text("""
            SELECT child.relname AS child_table,
                   parent.relname AS parent_table,
                   constraint_row.conname AS constraint_name
            FROM pg_catalog.pg_constraint AS constraint_row
            JOIN pg_catalog.pg_class AS child ON child.oid = constraint_row.conrelid
            JOIN pg_catalog.pg_namespace AS child_ns ON child_ns.oid = child.relnamespace
            JOIN pg_catalog.pg_class AS parent ON parent.oid = constraint_row.confrelid
            JOIN pg_catalog.pg_namespace AS parent_ns ON parent_ns.oid = parent.relnamespace
            WHERE constraint_row.contype = 'f'
              AND child_ns.nspname = :schema
              AND parent_ns.nspname = :schema
            ORDER BY child.relname, parent.relname
        """), {"schema": schema}).all()

    issues = []
    for child, parent, constraint in foreign_keys:
        if child not in positions or child == parent:
            continue
        if parent not in positions:
            issues.append(f"{child} references {parent}, which is not in the 17-row load order")
        elif positions[parent] > positions[child]:
            issues.append(f"{child} needs {parent} first (foreign key {constraint})")
    if issues:
        raise ValueError(
            "The 17-row CSV loading order violates staging foreign keys:\n  - "
            + "\n  - ".join(issues)
            + "\nMove each referenced parent table before its dependent table."
        )
    print(f"CSV loading-order check PASS ({len(foreign_keys)} staging foreign keys inspected).")


def reset_schema(engine: Engine, schema: str, *, owner: str | None = None) -> None:
    """Drop and recreate one schema, optionally assigning its owner.

    The reset runs in one transaction so each notebook stage starts from a
    predictable schema state.
    """
    schema = _validate_identifier(schema, "schema name")
    if owner is not None:
        owner = _validate_identifier(owner, "role name")

    q_schema = _quote_identifier(schema)
    create_sql = f"CREATE SCHEMA {q_schema}"
    if owner:
        create_sql += f" AUTHORIZATION {_quote_identifier(owner)}"

    with engine.begin() as conn:
        conn.exec_driver_sql(f"DROP SCHEMA IF EXISTS {q_schema} CASCADE")
        conn.exec_driver_sql(create_sql)

    print(f"Reset schema: {schema}")


def _set_local_search_path(conn, search_path: Sequence[str] | None) -> None:
    """Set a transaction-local search path for the current SQL operation.

    ``SET LOCAL`` limits the schema context to the current transaction and
    avoids hard-coded group-specific schema names inside student SQL files.
    """
    if not search_path:
        return
    quoted = [_quote_identifier(_validate_identifier(s, "schema name")) for s in search_path]
    conn.exec_driver_sql("SET LOCAL search_path TO " + ", ".join(quoted))


def run_sql_file(
    path: str | Path,
    *,
    engine: Engine,
    search_path: Sequence[str] | None = None,
    progress: bool = False,
    title: str | None = None,
    strip_psql_meta: bool = True,
) -> pd.DataFrame | None:
    """Execute a SQL file in one transaction and return its last result set.

    ``search_path`` is established by the orchestrator for this transaction, so
    ordinary DDL/ETL/post SQL files do not need hard-coded group schemas.
    """
    path = Path(path)
    if not path.is_file():
        raise FileNotFoundError(f"SQL file not found: {path}")

    raw = path.read_text(encoding="utf-8-sig")
    ensure_schema_neutral(path, raw)
    if strip_psql_meta:
        raw = "\n".join(
            line for line in raw.splitlines()
            if not line.lstrip().startswith("\\")
        )

    # Split multi-statement SQL files so failures can be reported precisely.
    statements = [
        statement.strip()
        for statement in sqlparse.split(raw)
        if statement and statement.strip(" ;\n\t")
    ]
    if not statements:
        raise ValueError(f"SQL file contains no executable statements: {path}")

    label = title or path.name
    if progress:
        print(f"Running {label} ({len(statements)} statement(s))")

    started = time.time()
    last_df: pd.DataFrame | None = None

    # Keep each SQL file atomic: all statements commit together or roll back.
    with engine.begin() as conn:
        _set_local_search_path(conn, search_path)

        for index, statement in enumerate(statements, start=1):
            statement_started = time.time()
            try:
                cursor = conn.exec_driver_sql(statement)
                if cursor.returns_rows:
                    rows = cursor.fetchall()
                    last_df = pd.DataFrame(rows, columns=cursor.keys())
            except Exception as exc:
                preview = " ".join(statement.split())[:180]
                raise RuntimeError(
                    f"SQL error in {path.name}, statement #{index}: {preview}"
                ) from exc

            if progress:
                preview = " ".join(statement.split())[:100]
                print(
                    f"  {index:>2}/{len(statements)} OK "
                    f"({time.time() - statement_started:.3f}s)  {preview}"
                )

    if progress:
        print(f"Finished {label} in {time.time() - started:.2f}s")

    return last_df


def run_sql_folder(
    folder: str | Path,
    pattern: str,
    *,
    engine: Engine,
    search_path: Sequence[str] | None = None,
    progress: bool = False,
) -> dict[str, pd.DataFrame | None]:
    """Run matching SQL files in lexicographic order.

    The filename order therefore defines the execution order for ETL and
    validation scripts.
    """
    folder = Path(folder)
    files = sorted(folder.glob(pattern))
    if not files:
        raise FileNotFoundError(f"No SQL files found matching {folder / pattern}")

    results: dict[str, pd.DataFrame | None] = {}
    for path in files:
        results[path.name] = run_sql_file(
            path,
            engine=engine,
            search_path=search_path,
            progress=progress,
        )

    print(f"Executed {len(files)} SQL file(s) from {folder.name}/")
    return results


def _normalise_check_status(value: object) -> str:
    """Normalise a DWH1 validation status to PASS / FAIL / INVALID."""
    text = str(value).strip().upper()
    if text in _CHECK_PASS_VALUES:
        return "PASS"
    if text in _CHECK_FAIL_VALUES:
        return "FAIL"
    return "INVALID"


def evaluate_check_results(
    results: dict[str, pd.DataFrame | None],
) -> pd.DataFrame:
    """Evaluate machine-readable post-ETL check outputs.

    Required output format for every ``a1_check*.sql`` file:
    - the final SELECT returns exactly one row;
    - it contains ``check_name`` and ``status`` columns;
    - ``status`` is PASS or FAIL (case-insensitive);
    - any additional columns are diagnostics and are left untouched in the
      displayed raw result set.
    """
    rows: list[dict[str, object]] = []

    for filename, result in results.items():
        row: dict[str, object] = {
            "file": filename,
            "check_name": Path(filename).stem,
            "status": "INVALID",
            "note": "",
        }

        if result is None:
            row["note"] = "No result set returned."
            rows.append(row)
            continue

        if result.empty:
            row["note"] = "Result set is empty."
            rows.append(row)
            continue

        if len(result) != 1:
            row["note"] = (
                f"Expected one summary row, got {len(result)}. "
                "Return diagnostics as columns, not extra rows."
            )
            rows.append(row)
            continue

        columns_lower = {str(column).lower(): column for column in result.columns}
        first = result.iloc[0]

        if "status" not in columns_lower:
            row["note"] = "Missing required status column (expected: check_name + status)."
            rows.append(row)
            continue

        if "check_name" not in columns_lower:
            row["note"] = "Missing required check_name column."
            rows.append(row)
            continue

        status_col = columns_lower["status"]
        check_name_col = columns_lower["check_name"]

        status = _normalise_check_status(first[status_col])
        check_name = str(first[check_name_col]).strip()

        row["status"] = status

        if check_name:
            row["check_name"] = check_name
        else:
            row["status"] = "INVALID"
            row["note"] = "check_name must not be empty."
            rows.append(row)
            continue

        if status == "INVALID":
            row["note"] = (
                f"Unrecognised status value {first[status_col]!r}; "
                "use PASS or FAIL."
            )

        rows.append(row)

    return pd.DataFrame(
        rows,
        columns=["file", "check_name", "status", "note"],
    )

def post_check_run_status(summary: pd.DataFrame) -> str:
    """Summarise evaluated student checks for the notebook run summary."""
    if summary.empty:
        return "FAIL (no checks evaluated)"

    counts = summary["status"].value_counts().to_dict()
    fail_count = int(counts.get("FAIL", 0))
    invalid_count = int(counts.get("INVALID", 0))
    pass_count = int(counts.get("PASS", 0))
    total = len(summary)

    if fail_count:
        return f"FAIL ({fail_count} failed, {pass_count} passed, {total} total)"
    if invalid_count:
        return (
            f"CHECK FORMAT ({invalid_count} invalid, "
            f"{pass_count} passed, {total} total)"
        )
    return f"PASS ({pass_count}/{total} checks)"


def load_csv_tables(
    folder: str | Path,
    table_order: Sequence[str],
    *,
    engine: Engine,
    schema: str,
    extension_folder: str | Path | None = None,
    if_exists: str = "append",
    chunksize: int = 20_000,
) -> dict[str, int]:
    """Load all 17 CSV files in *one* caller-specified interleaved sequence.

    Standard snapshot tables come from ``folder`` (csv/); extension tables
    come from ``extension_folder`` (data/). The supplied sequence is unchanged.
    ``\\N`` is SQL NULL; columns ending in from/to/at are parsed as dates.
    """
    folder = Path(folder)
    schema = _validate_identifier(schema, "schema name")
    if not folder.is_dir():
        raise FileNotFoundError(f"CSV folder not found: {folder}")
    if not table_order:
        raise ValueError("CSV load order is empty")
    extension_dir = Path(extension_folder) if extension_folder is not None else None
    if extension_dir is not None and not extension_dir.is_dir():
        raise FileNotFoundError(f"Extension CSV folder not found: {extension_dir}")

    row_counts: dict[str, int] = {}
    started = time.time()
    for table in table_order:
        _validate_identifier(table, "table name")
        if extension_dir is None or table in STANDARD_CSV_TABLES:
            csv_path = folder / f"{table}.csv"
        else:
            csv_path = extension_dir / f"{table}.csv"
        if not csv_path.is_file():
            raise FileNotFoundError(f"Required CSV file not found: {csv_path}")

        df = pd.read_csv(
            csv_path,
            na_values=["\\N"],
            keep_default_na=False,
            low_memory=False,
        )
        for column in df.columns:
            if column.lower().endswith(_DATE_SUFFIXES):
                df[column] = pd.to_datetime(
                    df[column], format="%Y-%m-%d", errors="coerce"
                ).dt.date
        df.to_sql(
            table, con=engine, schema=schema, if_exists=if_exists,
            index=False, method="multi", chunksize=chunksize,
        )
        row_counts[table] = len(df)
        print(f"Loaded {len(df):,} rows -> {schema}.{table}")

    total = sum(row_counts.values())
    print(f"Loaded {len(row_counts)} CSV tables, {total:,} rows in {time.time() - started:.2f}s")
    return row_counts


def _postgres_version_key(path: Path) -> tuple[int, ...]:
    """Return a sortable PostgreSQL version tuple derived from an install path."""
    # Expected Windows/Debian layouts contain the version two directories above
    # pg_dump, e.g. PostgreSQL/18/bin/pg_dump.exe or postgresql/18/bin/pg_dump.
    version_text = path.parent.parent.name
    numbers = re.findall(r"\d+", version_text)
    return tuple(int(value) for value in numbers) if numbers else (0,)


def find_pg_dump() -> Path:
    """Locate pg_dump without requiring students to edit PATH manually.

    Search order:
    1. explicit PG_DUMP environment variable;
    2. pg_dump already available on PATH;
    3. standard PostgreSQL installation locations on Windows/Linux/macOS.

    The highest-version installation is preferred when several standard
    PostgreSQL installations are present.
    """
    explicit = os.environ.get("PG_DUMP", "").strip()
    if explicit:
        explicit_path = Path(explicit).expanduser()
        if explicit_path.is_file():
            return explicit_path.resolve()
        raise FileNotFoundError(
            f"PG_DUMP points to a file that does not exist: {explicit_path}"
        )

    on_path = shutil.which("pg_dump") or shutil.which("pg_dump.exe")
    if on_path:
        return Path(on_path).resolve()

    candidates: list[Path] = []

    if os.name == "nt":
        roots: list[Path] = []
        for env_name in ("ProgramW6432", "ProgramFiles", "ProgramFiles(x86)"):
            value = os.environ.get(env_name)
            if value:
                root = Path(value)
                if root not in roots:
                    roots.append(root)
        default_root = Path(r"C:\Program Files")
        if default_root not in roots:
            roots.append(default_root)

        for root in roots:
            candidates.extend((root / "PostgreSQL").glob("*/bin/pg_dump.exe"))
    else:
        candidates.extend(Path("/usr/lib/postgresql").glob("*/bin/pg_dump"))
        candidates.extend(
            Path(path)
            for path in (
                "/opt/homebrew/bin/pg_dump",
                "/usr/local/bin/pg_dump",
            )
            if Path(path).is_file()
        )

    candidates = [path for path in candidates if path.is_file()]
    if candidates:
        return max(candidates, key=_postgres_version_key).resolve()

    raise FileNotFoundError(
        "pg_dump could not be located. PostgreSQL must be installed with its "
        "command-line tools. If it is installed in a non-standard location, set "
        "the PG_DUMP environment variable to the full path of pg_dump."
    )


def create_sql_dump(
    output_dir: str | Path,
    *,
    group: str,
    db_settings: dict[str, object],
    schema: str | None = None,
) -> Path:
    """Create a portable SQL dump of the populated DWH schema.

    Ownership and privilege statements are omitted so the dump can later be
    restored cleanly in the grading environment.
    """
    group = validate_group(group)
    schema = schema or f"dwh1_{group}"
    _validate_identifier(schema, "schema name")

    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    outfile = output_dir / f"sqldump_airq_dwh1_{group}.sql"

    pg_dump = find_pg_dump()

    user = str(db_settings["user"])
    host = str(db_settings["host"])
    port = str(db_settings["port"])
    database = str(db_settings["database"])
    password = str(db_settings.get("password") or "")

    cmd = [
        str(pg_dump),
        "-h", host,
        "-p", port,
        "-U", user,
        "-d", database,
        "-n", schema,
        "--no-owner",
        "--no-privileges",
        "-f", str(outfile),
    ]

    # Pass the password only to the pg_dump subprocess; never print it.
    env = dict(os.environ)
    if password:
        env["PGPASSWORD"] = password

    print(f"Using pg_dump: {pg_dump}")
    print(f"Creating SQL dump for schema {schema} ...")
    try:
        subprocess.run(cmd, check=True, env=env, capture_output=True, text=True)
    except subprocess.CalledProcessError as exc:
        detail = (exc.stderr or exc.stdout or str(exc)).strip()
        raise RuntimeError(f"pg_dump failed: {detail}") from exc

    if not outfile.is_file() or outfile.stat().st_size == 0:
        raise RuntimeError(f"pg_dump did not create a non-empty file: {outfile}")

    print(f"Dump created: {outfile}")
    return outfile


def print_run_summary(status: dict[str, str], *, group: str) -> None:
    """Print a compact end-of-notebook summary of all orchestration stages."""
    group = validate_group(group)
    heading = "DWH1 orchestration summary"
    print("\n" + heading)
    print("-" * len(heading))

    width = max((len(step) for step in status), default=0)
    for step, result in status.items():
        print(f"{step:<{width}}  {result}")

    needs_attention = [
        (step, result)
        for step, result in status.items()
        if not str(result).upper().startswith("PASS")
    ]

    if needs_attention:
        print(f"\nDWH1_{group} orchestration completed with items requiring attention.")
    else:
        print(f"\nDWH1_{group} completed successfully.")
