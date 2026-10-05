-- Extra tables for FitNut sessions, food, activity, and sleep records.
USE fitnut;

CREATE TABLE IF NOT EXISTS sessions (
  session_id INT NOT NULL AUTO_INCREMENT,
  user_id INT NOT NULL,
  token_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  expires_at DATETIME(6) NOT NULL,
  revoked_at DATETIME(6) NULL DEFAULT NULL,
  PRIMARY KEY (session_id),
  UNIQUE KEY uq_sessions_token_hash (token_hash),
  KEY idx_sessions_user (user_id),
  KEY idx_sessions_expiration (expires_at),
  CONSTRAINT fk_sessions_user FOREIGN KEY (user_id)
    REFERENCES users(user_id) ON DELETE CASCADE,
  CONSTRAINT chk_sessions_expiration CHECK (expires_at > created_at),
  CONSTRAINT chk_sessions_revocation CHECK
    (revoked_at IS NULL OR revoked_at >= created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS food_logs (
  food_log_id INT NOT NULL AUTO_INCREMENT,
  user_id INT NOT NULL,
  food_name VARCHAR(150) NOT NULL,
  quantity DECIMAL(10,3) NOT NULL,
  quantity_unit VARCHAR(30) NOT NULL,
  meal_type ENUM('breakfast', 'lunch', 'dinner', 'snack') NOT NULL,
  calories DECIMAL(10,2) NULL,
  protein_g DECIMAL(10,2) NULL,
  carbs_g DECIMAL(10,2) NULL,
  fat_g DECIMAL(10,2) NULL,
  logged_at DATETIME(6) NOT NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (food_log_id),
  KEY idx_food_logs_user_date (user_id, logged_at),
  CONSTRAINT fk_food_logs_user FOREIGN KEY (user_id)
    REFERENCES users(user_id) ON DELETE CASCADE,
  CONSTRAINT chk_food_name CHECK (CHAR_LENGTH(TRIM(food_name)) > 0),
  CONSTRAINT chk_food_unit CHECK (CHAR_LENGTH(TRIM(quantity_unit)) > 0),
  CONSTRAINT chk_food_quantity CHECK (quantity > 0),
  CONSTRAINT chk_food_calories CHECK (calories IS NULL OR calories >= 0),
  CONSTRAINT chk_food_protein CHECK (protein_g IS NULL OR protein_g >= 0),
  CONSTRAINT chk_food_carbs CHECK (carbs_g IS NULL OR carbs_g >= 0),
  CONSTRAINT chk_food_fat CHECK (fat_g IS NULL OR fat_g >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS activity_logs (
  activity_log_id INT NOT NULL AUTO_INCREMENT,
  user_id INT NOT NULL,
  activity_name VARCHAR(100) NOT NULL,
  duration_minutes DECIMAL(10,2) NOT NULL,
  calories_burned DECIMAL(10,2) NULL,
  performed_at DATETIME(6) NOT NULL,
  notes TEXT NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (activity_log_id),
  KEY idx_activity_logs_user_date (user_id, performed_at),
  CONSTRAINT fk_activity_logs_user FOREIGN KEY (user_id)
    REFERENCES users(user_id) ON DELETE CASCADE,
  CONSTRAINT chk_activity_name CHECK (CHAR_LENGTH(TRIM(activity_name)) > 0),
  CONSTRAINT chk_activity_duration CHECK (duration_minutes > 0),
  CONSTRAINT chk_activity_calories CHECK
    (calories_burned IS NULL OR calories_burned >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS sleep_logs (
  sleep_log_id INT NOT NULL AUTO_INCREMENT,
  user_id INT NOT NULL,
  sleep_start DATETIME(6) NOT NULL,
  sleep_end DATETIME(6) NOT NULL,
  sleep_quality TINYINT UNSIGNED NULL,
  notes TEXT NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (sleep_log_id),
  KEY idx_sleep_logs_user_date (user_id, sleep_start),
  CONSTRAINT fk_sleep_logs_user FOREIGN KEY (user_id)
    REFERENCES users(user_id) ON DELETE CASCADE,
  CONSTRAINT chk_sleep_dates CHECK (sleep_end > sleep_start),
  CONSTRAINT chk_sleep_quality CHECK
    (sleep_quality IS NULL OR sleep_quality BETWEEN 1 AND 5)
) ENGINE=InnoDB;
