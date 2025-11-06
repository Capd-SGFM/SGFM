CREATE SCHEMA IF NOT EXISTS users;

CREATE TABLE IF NOT EXISTS users.accounts (
    google_id        VARCHAR(256) PRIMARY KEY,
    username         VARCHAR(12)  NOT NULL,
    email            VARCHAR(100) NOT NULL UNIQUE,
    email_opt_in     BOOLEAN      NOT NULL DEFAULT FALSE,
    is_admin         BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    last_login       TIMESTAMPTZ  NULL
);

-- updated_at 자동 갱신 트리거
CREATE OR REPLACE FUNCTION users.touch_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := NOW();
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_users_accounts_touch ON users.accounts;
CREATE TRIGGER trg_users_accounts_touch
BEFORE UPDATE ON users.accounts
FOR EACH ROW EXECUTE FUNCTION users.touch_updated_at();

-- 조회 자주 쓰는 키 인덱스(이메일 로그인 조회 최적화)
CREATE INDEX IF NOT EXISTS idx_users_accounts_email ON users.accounts(email);
