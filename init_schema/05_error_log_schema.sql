-- 05_error_log_schema.sql
-- 에러 로그 테이블 (Current / History)

-- 1. error_logs_current
-- 현재 실행 중인 파이프라인 세션에서 발생한 에러를 임시 저장
CREATE TABLE IF NOT EXISTS trading_data.error_logs_current (
    id SERIAL PRIMARY KEY,
    component VARCHAR(50) NOT NULL,
    symbol VARCHAR(20),
    interval VARCHAR(10),
    error_message TEXT NOT NULL,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_error_logs_current_occurred_at ON trading_data.error_logs_current(occurred_at);

-- 2. error_logs_history
-- 파이프라인 종료 시 error_logs_current의 내용을 이관하여 보관
CREATE TABLE IF NOT EXISTS trading_data.error_logs_history (
    id SERIAL PRIMARY KEY,
    component VARCHAR(50) NOT NULL,
    symbol VARCHAR(20),
    interval VARCHAR(10),
    error_message TEXT NOT NULL,
    occurred_at TIMESTAMPTZ NOT NULL,
    archived_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_error_logs_history_occurred_at ON trading_data.error_logs_history(occurred_at);
CREATE INDEX IF NOT EXISTS idx_error_logs_history_archived_at ON trading_data.error_logs_history(archived_at);
