"""Create missing tables in the configured database. Existing records are kept."""
import os
import sys
import time
from pathlib import Path

import mysql.connector
from dotenv import load_dotenv

PROJECT = Path(__file__).resolve().parents[1]
load_dotenv(PROJECT / ".env.local")


def table_statements():
    # The hosting provider chooses the database name, so skip CREATE DATABASE/USE.
    for filename in ("schema.sql", "other-tables.sql"):
        sql = (PROJECT / "database" / filename).read_text(encoding="utf-8")
        sql = "\n".join(line for line in sql.splitlines() if not line.lstrip().startswith("--"))
        for statement in sql.split(";"):
            statement = statement.strip()
            if statement.upper().startswith("CREATE TABLE IF NOT EXISTS"):
                yield statement


def main():
    connection = None
    for attempt in range(12):
        try:
            connection = mysql.connector.connect(
                host=os.environ["MYSQL_HOST"], port=int(os.environ["MYSQL_PORT"]),
                user=os.environ["MYSQL_USER"], password=os.environ["MYSQL_PASSWORD"],
                database=os.environ["MYSQL_DATABASE"], time_zone="+00:00", connection_timeout=5,
            )
            break
        except mysql.connector.Error as error:
            if attempt == 11:
                print("Cannot connect to MySQL. Check the hosting database settings. Error code:", error.errno,
                      file=sys.stderr)
                return 1
            time.sleep(2)
    try:
        cursor = connection.cursor()
        try:
            for statement in table_statements():
                cursor.execute(statement)
            connection.commit()
        finally:
            cursor.close()
    finally:
        connection.close()
    print("FitNut database tables are ready.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
