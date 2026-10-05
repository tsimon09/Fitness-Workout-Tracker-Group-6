# Fitness Workout Tracker — Group 6

The Sprint 2 Flask application is in [FitNut](FitNut/README.md). It includes registration, login, logout, database sessions, user/admin roles, and food, activity, and sleep records with a basic HTML interface.

## Run the application

Follow the Windows setup and run instructions in [FitNut/README.md](FitNut/README.md). Python 3.12+ and MySQL Server are required. The database setup scripts create local credentials; credentials and local database files are excluded from Git.

## Separate database for this application

`fitness_tracker_schema.sql` is the team's backup SQL file. It is preserved unchanged on this branch.

This application uses a separate `fitnut` database and the scripts in `FitNut/database`. Its tables are `users`, `sessions`, `food_logs`, `activity_logs`, and `sleep_logs`. Its setup does not apply the backup SQL file.

The `sprint2-fitnut-app` branch adds this application as an option for the team to review and choose. It has not been merged into `main`.
