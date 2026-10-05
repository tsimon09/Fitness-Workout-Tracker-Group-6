. (Join-Path $PSScriptRoot 'mysql-common.ps1')
Start-FitNutMySql
$testEmail = 'schema-test-' + [Guid]::NewGuid().ToString('N') + '@example.invalid'
$testHash = 'database-constraint-test-only-not-a-login-password'
$createTestUser = @"
START TRANSACTION;
INSERT INTO fitnut.users (full_name, email, password_hash)
VALUES ('Schema Test', '$testEmail', '$testHash');
SET @test_user_id = LAST_INSERT_ID();
"@

function Assert-FitNutQuery([string] $Name, [string] $Sql, [string] $Expected) {
    $result = Invoke-FitNutSql -Sql $Sql
    if ($result.ExitCode -ne 0 -or $result.Output.Trim() -ne $Expected) {
        throw "$Name failed: $($result.Output)"
    }
    Write-Output "PASS: $Name"
}

function Assert-FitNutRejection([string] $Name, [string] $Sql, [int] $ErrorNumber) {
    # The connection closes after failure, rolling back the uncommitted test user.
    $result = Invoke-FitNutSql -Sql ($createTestUser + "`n" + $Sql + "`nROLLBACK;")
    if ($result.ExitCode -eq 0 -or $result.Output -notmatch "ERROR $ErrorNumber ") {
        throw "$Name failed: expected MySQL error $ErrorNumber; got $($result.Output)"
    }
    Write-Output "PASS: $Name"
}

Assert-FitNutQuery 'Five starter tables exist' @"
SELECT COUNT(*) FROM information_schema.tables
WHERE table_schema = 'fitnut' AND table_name IN
('users','sessions','food_logs','activity_logs','sleep_logs');
"@ '5'

Assert-FitNutQuery 'last_online exists and updated_at is absent' @"
SELECT CONCAT(
 SUM(column_name = 'last_online'), ':', SUM(column_name = 'updated_at'))
FROM information_schema.columns WHERE table_schema='fitnut' AND table_name='users';
"@ '1:0'

Assert-FitNutQuery 'Default role and status; last_online does not change on profile edits' ($createTestUser + @"
UPDATE fitnut.users SET full_name = 'Updated Schema Test' WHERE user_id = @test_user_id;
SELECT CONCAT(role, ':', status, ':', IF(last_online IS NULL, 'NULL', 'unexpected'))
FROM fitnut.users WHERE user_id = @test_user_id;
ROLLBACK;
"@) 'user:active:NULL'

Assert-FitNutQuery 'Valid logs, session creation/revocation, and last_online update' ($createTestUser + @"
INSERT INTO fitnut.food_logs
(user_id, food_name, quantity, quantity_unit, meal_type, calories, logged_at)
VALUES (@test_user_id, 'Apple', 1, 'piece', 'snack', 95, UTC_TIMESTAMP(6));
INSERT INTO fitnut.activity_logs (user_id, activity_name, duration_minutes, performed_at)
VALUES (@test_user_id, 'Walking', 30, UTC_TIMESTAMP(6));
INSERT INTO fitnut.sleep_logs (user_id, sleep_start, sleep_end, sleep_quality)
VALUES (@test_user_id, '2026-10-01 23:00:00', '2026-10-02 07:00:00', 4);
INSERT INTO fitnut.sessions (user_id, token_hash, expires_at)
VALUES (@test_user_id, SHA2('$testEmail', 256), UTC_TIMESTAMP(6) + INTERVAL 1 HOUR);
UPDATE fitnut.users SET last_online = UTC_TIMESTAMP(6) WHERE user_id = @test_user_id;
UPDATE fitnut.sessions SET revoked_at = UTC_TIMESTAMP(6) WHERE user_id = @test_user_id;
SELECT CONCAT(
 (SELECT COUNT(*) FROM fitnut.food_logs WHERE user_id=@test_user_id), ':',
 (SELECT COUNT(*) FROM fitnut.activity_logs WHERE user_id=@test_user_id), ':',
 (SELECT COUNT(*) FROM fitnut.sleep_logs WHERE user_id=@test_user_id), ':',
 (SELECT COUNT(*) FROM fitnut.sessions WHERE user_id=@test_user_id AND revoked_at IS NOT NULL), ':',
 (SELECT COUNT(*) FROM fitnut.users WHERE user_id=@test_user_id AND last_online IS NOT NULL));
ROLLBACK;
"@) '1:1:1:1:1'

Assert-FitNutRejection 'Duplicate email is rejected ignoring case' @"
INSERT INTO fitnut.users (full_name, email, password_hash)
VALUES ('Duplicate', UPPER('$testEmail'), '$testHash');
"@ 1062

Assert-FitNutRejection 'Missing password hash is rejected' @"
INSERT INTO fitnut.users (full_name, email, password_hash)
VALUES ('Missing Password', 'other-$testEmail', NULL);
"@ 1048

Assert-FitNutRejection 'Invalid role is rejected' @"
UPDATE fitnut.users SET role='owner' WHERE user_id=@test_user_id;
"@ 1265

Assert-FitNutRejection 'Food records cannot reference a missing user' @"
SET @missing_user_id = (SELECT COALESCE(MAX(user_id),0)+1 FROM fitnut.users);
INSERT INTO fitnut.food_logs
(user_id,food_name,quantity,quantity_unit,meal_type,logged_at)
VALUES (@missing_user_id,'Apple',1,'piece','snack',UTC_TIMESTAMP(6));
"@ 1452

Assert-FitNutRejection 'Negative food quantities are rejected' @"
INSERT INTO fitnut.food_logs
(user_id,food_name,quantity,quantity_unit,meal_type,logged_at)
VALUES (@test_user_id,'Apple',-1,'piece','snack',UTC_TIMESTAMP(6));
"@ 3819

Assert-FitNutRejection 'Negative activity duration is rejected' @"
INSERT INTO fitnut.activity_logs (user_id,activity_name,duration_minutes,performed_at)
VALUES (@test_user_id,'Walking',-10,UTC_TIMESTAMP(6));
"@ 3819

Assert-FitNutRejection 'Sleep ending before it starts is rejected' @"
INSERT INTO fitnut.sleep_logs (user_id,sleep_start,sleep_end)
VALUES (@test_user_id,'2026-10-02 07:00:00','2026-10-01 23:00:00');
"@ 3819

Assert-FitNutRejection 'Session expiration before creation is rejected' @"
INSERT INTO fitnut.sessions (user_id,token_hash,expires_at)
VALUES (@test_user_id,SHA2('$testEmail',256),UTC_TIMESTAMP(6)-INTERVAL 1 HOUR);
"@ 3819

Assert-FitNutQuery 'Test account was rolled back' @"
SELECT COUNT(*) FROM fitnut.users WHERE email='$testEmail';
"@ '0'
Write-Output 'Database checks passed. No test accounts or logs were retained.'
