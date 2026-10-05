# FitNut requests in Postman

Start FitNut first by running `.\scripts\run.ps1` from the project folder. Keep that PowerShell window open. Then open Postman and import `postman\FitNut.postman_collection.json`.

## Use the collection

1. In the collection, open **Variables**. Set `demo_email` to an email address you can use and `demo_password` to a password of at least 8 characters. Save the collection. These are FitNut login details, not MySQL details.
2. Send **Check FitNut server**. It should return **200 OK**.
3. Send **Register** once to make a new account. If that email already exists, choose a different email or skip to Login.
4. Send **Login**. Postman saves the login cookie and the collection saves the `csrf_token` returned by FitNut.
5. Send **Current user**. This confirms which account is signed in and refreshes the token used for changes.
6. Try **Add food**, **List food**, **Update food**, and **Delete food** in order. Do the same for Activity and Sleep. The add request saves the new record number for the later requests.
7. Send **Logout**, then **Check session ended**. The last request should report that you are signed out.

The collection groups admin requests at the end. Those only work when `demo_email` and `demo_password` belong to an administrator. To create one, use the terminal command in the main [FitNut guide](../README.md#use-the-website).

## If you are using Postman without signing in

Postman's lightweight API Client can send individual requests, but it does not import collections. First try the website at [http://127.0.0.1:5000](http://127.0.0.1:5000), or make requests using these settings:

| What to do | Method and URL | Body |
| --- | --- | --- |
| Check the server | `GET http://127.0.0.1:5000/health` | None |
| Register | `POST http://127.0.0.1:5000/register` | JSON with `full_name`, `email`, `password`, and `password_confirmation` |
| Log in | `POST http://127.0.0.1:5000/login` | JSON with `email` and `password` |
| See signed-in account | `GET http://127.0.0.1:5000/me` | None |

For JSON, choose **Body → raw → JSON**. After login, Postman must keep the `fitnut_session` cookie to access private pages and requests. To add, edit, or delete records, send the `X-CSRF-Token` header with the `csrf_token` from the Login or Current user response. The matching API paths are `/food-logs`, `/activity-logs`, and `/sleep-logs`.

## Common responses

- **200 OK**: request worked.
- **201 Created**: account or record was added.
- **400 Bad Request**: check the field names and values in the JSON body.
- **401 Unauthorized**: log in first, or check the email and password.
- **403 Forbidden**: an administrator is required, the account is suspended, or the request needs a fresh `X-CSRF-Token` header.
- **409 Conflict**: that email is already registered.
- **503 Service Unavailable**: start MySQL and FitNut with `scripts\run.ps1`.
