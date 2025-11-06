CREATE SCHEMA IF NOT EXISTS users;

-- =======================
-- 1. 사용자 계정 테이블
-- =======================
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

CREATE INDEX IF NOT EXISTS idx_users_accounts_email ON users.accounts(email);



-- ===========================
-- 2. 백테스트 실행 결과 테이블
-- ===========================
CREATE TABLE IF NOT EXISTS users.backtest_results (
    id SERIAL PRIMARY KEY,
    google_id VARCHAR(256) NOT NULL REFERENCES users.accounts(google_id) ON DELETE CASCADE,

    -- 실행 파라미터
    symbol VARCHAR(30) NOT NULL,
    interval VARCHAR(10) NOT NULL,
    strategy_sql TEXT NOT NULL,
    risk_reward_ratio NUMERIC(5,2) NOT NULL,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,

    -- 백테스트 결과
    entry_time TIMESTAMPTZ NOT NULL,
    exit_time TIMESTAMPTZ,
    result TEXT,                        -- TP / SL / None
    profit_rate NUMERIC(10,4),
    cum_profit_rate NUMERIC(10,4),

    -- 실행 메타데이터
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE (google_id, symbol, interval, start_time, entry_time)
);

-- updated_at 자동 갱신 트리거
CREATE OR REPLACE FUNCTION users.touch_backtest_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := NOW();
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_backtest_touch ON users.backtest_results;
CREATE TRIGGER trg_backtest_touch
BEFORE UPDATE ON users.backtest_results
FOR EACH ROW EXECUTE FUNCTION users.touch_backtest_updated_at();


-- 인덱스 생성 (조회 성능 향상)
CREATE INDEX IF NOT EXISTS idx_backtest_results_user ON users.backtest_results(google_id);
CREATE INDEX IF NOT EXISTS idx_backtest_results_symbol ON users.backtest_results(symbol);
CREATE INDEX IF NOT EXISTS idx_backtest_results_interval ON users.backtest_results(interval);
CREATE INDEX IF NOT EXISTS idx_backtest_results_entry_time ON users.backtest_results(entry_time);
