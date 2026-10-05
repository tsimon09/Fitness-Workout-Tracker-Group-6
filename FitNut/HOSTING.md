# Put FitNut online with Railway

Railway hosts the website and a separate MySQL database. Anyone with the website link can register and log in. Records stay in the hosted MySQL database when the website restarts or is updated. Local accounts and records are not automatically copied online.

## Set up the project

1. Sign into [Railway](https://railway.com/) and create a new project.
2. Add a **MySQL** database service. Keep its name `MySQL` for the variable references below. Keep its persistent volume attached and its database networking private.
3. Add a service from the GitHub repository `tsimon09/Fitness-Workout-Tracker-Group-6`.
4. In that website service's settings, select branch **sprint2-fitnut-app** and set **Root Directory** to `/FitNut`.
5. Railway will use the Dockerfile in that folder. Leave the start command empty so the Dockerfile supplies it.

## Connect the website to MySQL

In the website service's **Variables**, add these settings. Use references to the MySQL service, rather than copying its passwords into GitHub.

| Variable | Value |
| --- | --- |
| `MYSQL_HOST` | `${{MySQL.MYSQLHOST}}` |
| `MYSQL_PORT` | `${{MySQL.MYSQLPORT}}` |
| `MYSQL_USER` | `${{MySQL.MYSQLUSER}}` |
| `MYSQL_PASSWORD` | `${{MySQL.MYSQLPASSWORD}}` |
| `MYSQL_DATABASE` | `${{MySQL.MYSQLDATABASE}}` |
| `COOKIE_SECURE` | `true` |
| `TRUST_PROXY` | `true` |

Deploy the website service. It creates missing FitNut tables in the hosted database and then starts the web server. It does not run the backup SQL file or delete existing records.

## Get the website link

Under the website service's **Settings → Networking**, choose **Generate Domain**. Railway supplies an HTTPS address. Redeploy after generating the domain so the app receives `RAILWAY_PUBLIC_DOMAIN` and accepts that address.

Set **Healthcheck Path** to `/health`. If you add a custom domain later, set `TRUSTED_HOSTS` to `localhost,127.0.0.1,your-domain.example`; Railway's generated domain is also added automatically.

Open the HTTPS link, register a new account, log in, and save a record. Open the same link on another device to confirm the same account's record is there.

## Administrator account

In a Railway SSH session for the website service, run `python scripts/create_admin.py`. Enter a new administrator's name, email, and password in that session. Sign into the website with those details to manage account roles and statuses.

## Costs and data

The [trial](https://docs.railway.com/pricing/free-trial) offers $5 of credit for up to 30 days. It ends earlier if the credit is used up. The [Hobby plan](https://docs.railway.com/pricing/plans) is $5/month with $5 of included usage; usage above that costs extra. Trial data is not kept indefinitely after the trial ends. Check Railway's current terms before relying on it for long-term storage, and download a database backup before stopping hosting.

References: [Flask deployment](https://docs.railway.com/guides/flask), [MySQL](https://docs.railway.com/databases/mysql), [public domains](https://docs.railway.com/networking/public-networking).
