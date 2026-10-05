# FitNut

FitNut is a small Flask and MySQL app for keeping track of food, activity, and sleep. It includes account registration, login, logout, saved sessions, and an administrator page. The website pages and the Postman requests use the same backend.

## Start FitNut

Open PowerShell in this project folder and run:

```powershell
.\scripts\run.ps1
```

The first run makes a Python environment and installs the packages. The script starts the already-set-up local MySQL server, then starts FitNut. Open [http://127.0.0.1:5000](http://127.0.0.1:5000) in a browser. Press **Ctrl+C** in PowerShell to stop FitNut. MySQL can be stopped separately with `scripts\stop-mysql.ps1`.

On a new Windows computer, install Python 3.12+ and MySQL Server first. If MySQL is installed in a different folder, change the path near the top of `scripts\mysql-common.ps1`. Then run `scripts\setup-mysql.ps1` once before `scripts\run.ps1`.

If PowerShell says that scripts are disabled, run this once in that same PowerShell window, then start FitNut again:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
```

## Use the website

1. Choose **Create account** and enter your name, email, and password.
2. Log in with that email and password.
3. Use **Food**, **Activity**, and **Sleep** in the top menu to add, edit, and delete your own records.
4. Choose **Log out** when you are done.

Each account sees its own records. New accounts have the regular `user` role. To make a separate administrator account, run this in another PowerShell window while MySQL is running:

```powershell
.\.venv\Scripts\python.exe .\scripts\create_admin.py
```

It asks for a new name, email, and password in the terminal. Then log into that account and open **Users** to manage roles or suspend accounts.

## What is in the database?

The main file, `database\schema.sql`, creates the `users` table. `database\other-tables.sql` adds `sessions`, `food_logs`, `activity_logs`, and `sleep_logs`. The setup script applies both files. The database uses a local MySQL account; its settings live in `.env.local` and are not part of the Postman collection.

| Table | What it keeps |
| --- | --- |
| `users` | Name, email, password hash, role, account status, join date, and last online time |
| `sessions` | A protected login token and when that login expires or is ended |
| `food_logs` | Food name, amount, meal, and optional calories and nutrition values |
| `activity_logs` | Activity, minutes, optional calories burned, date, and notes |
| `sleep_logs` | Start and end times, optional 1–5 quality rating, and notes |

Passwords are stored as one-way hashes. The confirmation field is only used during registration and is not saved.

## Try the API in Postman

The prepared collection is `postman\FitNut.postman_collection.json`. See [the Postman guide](postman\README.md) for import steps and the order to try requests. For the browser version, no Postman setup is needed.

## Project files

- `app.py` starts the website and connects the page routes.
- `accounts.py` handles registration, login, sessions, and administrator actions.
- `logs.py` handles food, activity, and sleep records.
- `db.py` contains the small set of MySQL helper functions.
- `templates` contains the HTML pages; `static` contains the page styling and browser behavior.
- `scripts` contains setup and run helpers for Windows.

The project targets Python 3.12 or newer. The `screenshots` folder contains the current home and registration pages. Screenshots of login, overview, food, activity, sleep, and user administration are still needed for the final Sprint 2 report.
