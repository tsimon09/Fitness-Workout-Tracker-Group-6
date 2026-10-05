"""Integration checks against MySQL. Only accounts created here are removed."""
import unittest
import uuid
from datetime import datetime, timedelta, timezone
from werkzeug.security import check_password_hash
from app import app
from accounts import COOKIE, token_hash
from db import execute, fetch_one, get_db

PASSWORD = "TestPassword123!"
FOOD = {"food_name": "Oatmeal", "quantity": 1, "quantity_unit": "cup", "meal_type": "breakfast", "calories": 150}
ACTIVITY = {"activity_name": "Walking", "duration_minutes": 30, "calories_burned": 100, "notes": "Morning walk"}
SLEEP = {"sleep_start": "2026-10-01T22:00:00Z", "sleep_end": "2026-10-02T06:00:00Z", "sleep_quality": 4}


class FitNutTests(unittest.TestCase):
    def setUp(self):
        app.config.update(TESTING=True)
        self.ids = []
        self.addCleanup(self.clean_accounts)
        self.client = app.test_client()
        self.email, self.user_id = self.signup(self.client)

    def clean_accounts(self):
        with app.app_context():
            for user_id in self.ids:
                execute("DELETE FROM users WHERE user_id = %s", (user_id,))
            get_db().commit()

    def signup(self, client, **extra):
        email = "fitnut-test-" + uuid.uuid4().hex + "@example.com"
        body = {"full_name": "Test Person", "email": email, "password": PASSWORD,
                "password_confirmation": PASSWORD, **extra}
        response = client.post("/register", json=body)
        self.assertEqual(response.status_code, 201, response.json)
        user_id = response.json["user_id"]
        self.ids.append(user_id)
        return email, user_id

    def login(self, client=None, email=None):
        client = client or self.client
        response = client.post("/login", json={"email": email or self.email, "password": PASSWORD})
        self.assertEqual(response.status_code, 200, response.json)
        return {"X-CSRF-Token": response.json["csrf_token"]}

    def test_registration_hash_and_duplicate(self):
        with app.app_context():
            user = fetch_one("SELECT * FROM users WHERE user_id = %s", (self.user_id,))
            self.assertNotEqual(user["password_hash"], PASSWORD)
            self.assertTrue(check_password_hash(user["password_hash"], PASSWORD))
            self.assertEqual((user["role"], user["status"]), ("user", "active"))
        response = self.client.post("/register", json={"full_name": "Other", "email": self.email,
                                     "password": PASSWORD, "password_confirmation": PASSWORD})
        self.assertEqual(response.status_code, 409)
        _, user_id = self.signup(self.client, role="admin")
        with app.app_context():
            self.assertEqual(fetch_one("SELECT role FROM users WHERE user_id = %s", (user_id,))["role"], "user")

    def test_login_logout_and_revocation(self):
        self.assertEqual(self.client.get("/me").status_code, 401)
        self.assertEqual(self.client.post("/login", json={"email": self.email, "password": "wrong"}).status_code, 401)
        headers = self.login()
        token = self.client.get_cookie(COOKIE).value
        response = self.client.get("/me")
        self.assertEqual(response.status_code, 200)
        self.assertNotIn("password_hash", response.json["user"])
        self.assertIsNotNone(response.json["user"]["last_online"])
        with app.app_context():
            row = fetch_one("SELECT token_hash FROM sessions WHERE user_id = %s", (self.user_id,))
            self.assertEqual(row["token_hash"], token_hash(token))
            self.assertNotEqual(row["token_hash"], token)
        self.assertEqual(self.client.post("/logout", json={}, headers=headers).status_code, 200)
        self.assertEqual(self.client.get("/me").status_code, 401)
        self.client.set_cookie(COOKIE, token)
        self.assertEqual(self.client.get("/me").status_code, 401)
        with app.app_context():
            self.assertIsNotNone(fetch_one("SELECT revoked_at FROM sessions WHERE user_id = %s", (self.user_id,))["revoked_at"])

    def test_session_expiry_and_rotation(self):
        self.login()
        old_token = self.client.get_cookie(COOKIE).value
        self.login()
        fresh_token = self.client.get_cookie(COOKIE).value
        self.assertNotEqual(old_token, fresh_token)
        self.client.set_cookie(COOKIE, old_token)
        self.assertEqual(self.client.get("/me").status_code, 401)
        self.client.set_cookie(COOKIE, fresh_token)
        with app.app_context():
            now = datetime.now(timezone.utc).replace(tzinfo=None)
            execute("UPDATE sessions SET created_at = %s, expires_at = %s WHERE token_hash = %s",
                    (now - timedelta(days=2), now - timedelta(days=1), token_hash(fresh_token)))
            get_db().commit()
        self.assertEqual(self.client.get("/me").status_code, 401)

    def test_csrf_and_origin(self):
        headers = self.login()
        self.assertEqual(self.client.post("/food-logs", json=FOOD).status_code, 403)
        self.assertEqual(self.client.post("/food-logs", json=FOOD, headers={"X-CSRF-Token": "é" * 64}).status_code, 403)
        self.assertEqual(self.client.post("/food-logs", json=FOOD, headers={**headers, "Origin": "https://other.example"}).status_code, 403)
        self.assertEqual(self.client.post("/food-logs", json=FOOD, headers=headers).status_code, 201)

    def test_private_log_crud(self):
        headers = self.login()
        other = app.test_client()
        other_email, _ = self.signup(other)
        other_headers = self.login(other, other_email)
        for kind, body in (("food", FOOD), ("activity", ACTIVITY), ("sleep", SLEEP)):
            url = "/" + kind + "-logs"
            response = self.client.post(url, json={**body, "user_id": 999999}, headers=headers)
            self.assertEqual(response.status_code, 201, response.json)
            log_id = response.json["id"]
            items = self.client.get(url).json["items"]
            self.assertEqual(len(items), 1)
            self.assertEqual(items[0]["user_id"], self.user_id)
            self.assertEqual(other.get(url).json["items"], [])
            self.assertEqual(other.put(url + "/" + str(log_id), json=body, headers=other_headers).status_code, 404)
            self.assertEqual(other.delete(url + "/" + str(log_id), headers=other_headers).status_code, 404)
            self.assertEqual(self.client.put(url + "/" + str(log_id), json=body, headers=headers).status_code, 200)
            self.assertEqual(self.client.delete(url + "/" + str(log_id), headers=headers).status_code, 200)
            self.assertEqual(self.client.get(url).json["items"], [])

    def test_bad_log_values(self):
        headers = self.login()
        for body in ({**FOOD, "quantity": -1}, {**FOOD, "calories": "NaN"}, {**FOOD, "quantity": True}):
            self.assertEqual(self.client.post("/food-logs", json=body, headers=headers).status_code, 400)
        self.assertEqual(self.client.post("/activity-logs", json={**ACTIVITY, "duration_minutes": 0}, headers=headers).status_code, 400)
        self.assertEqual(self.client.post("/sleep-logs", json={**SLEEP, "sleep_end": SLEEP["sleep_start"]}, headers=headers).status_code, 400)
        self.assertEqual(self.client.post("/sleep-logs", json={**SLEEP, "sleep_quality": 6}, headers=headers).status_code, 400)
        self.assertEqual(self.client.get("/food-logs").json["items"], [])

    def test_admin_permissions_and_suspension(self):
        user_headers = self.login()
        self.assertEqual(self.client.get("/admin/users").status_code, 403)
        admin = app.test_client()
        admin_email, admin_id = self.signup(admin)
        with app.app_context():
            execute("UPDATE users SET role = 'admin' WHERE user_id = %s", (admin_id,))
            get_db().commit()
        headers = self.login(admin, admin_email)
        response = admin.get("/admin/users")
        self.assertEqual(response.status_code, 200)
        self.assertTrue(all("password_hash" not in user for user in response.json["users"]))
        self.assertEqual(admin.patch("/admin/users/" + str(self.user_id), json={"status": "suspended"}, headers=headers).status_code, 200)
        self.assertEqual(self.client.get("/me").status_code, 401)
        self.assertEqual(self.client.post("/login", json={"email": self.email, "password": PASSWORD}).status_code, 403)
        self.assertEqual(admin.patch("/admin/users/" + str(self.user_id), json={"status": "active", "role": "admin"}, headers=headers).status_code, 200)
        self.login()
        self.assertEqual(self.client.get("/admin/users").status_code, 200)
        self.assertEqual(admin.patch("/admin/users/" + str(admin_id), json={"role": "user"}, headers=headers).status_code, 400)

    def test_pages_and_safe_rendering(self):
        for page in ("/", "/login", "/register"):
            self.assertEqual(self.client.get(page).status_code, 200)
        self.assertEqual(self.client.get("/dashboard").status_code, 302)
        headers = self.login()
        self.client.post("/food-logs", json={**FOOD, "food_name": "<script>alert(1)</script>"}, headers=headers)
        for page in ("/dashboard", "/food", "/activity", "/sleep"):
            response = self.client.get(page)
            self.assertEqual(response.status_code, 200, response.data)
        page = self.client.get("/food").get_data(as_text=True)
        self.assertIn("&lt;script&gt;", page)
        self.assertNotIn("<script>alert(1)</script>", page)

    def test_invalid_registration_and_injection(self):
        self.assertEqual(self.client.post("/register", json=[]).status_code, 400)
        self.assertEqual(self.client.post("/register", json={"full_name": "Name", "email": "bad", "password": PASSWORD, "password_confirmation": PASSWORD}).status_code, 400)
        self.assertEqual(self.client.post("/login", json={"email": "' OR '1'='1", "password": PASSWORD}).status_code, 401)
        self.assertEqual(self.client.get("/food-logs").status_code, 401)


if __name__ == "__main__":
    unittest.main()
