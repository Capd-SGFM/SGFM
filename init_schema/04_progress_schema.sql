-- =====================================================
-- 파이프라인 진행률 추적 테이블들
-- =====================================================
-- 이 파일은 데이터 수집 파이프라인의 각 엔진별 진행 상태를 추적하는 테이블들을 정의합니다.
-- - backfill_progress: 과거 데이터 백필 진행률
-- - rest_progress: REST 유지보수 진행률
-- - indicator_progress: 보조지표 계산 진행률
-- - websocket_progress: WebSocket 실시간 연결 상태
-- =====================================================

-- =====================================================
-- 1. Backfill 진행 상태 테이블
-- =====================================================
CREATE TABLE IF NOT EXISTS trading_data.backfill_progress (
    run_id          VARCHAR(64) NOT NULL,
    symbol          VARCHAR(30) NOT NULL REFERENCES metadata.crypto_info(symbol) ON DELETE CASCADE,
    interval        VARCHAR(10) NOT NULL,
    state           VARCHAR(20) NOT NULL,    -- PENDING / PROGRESS / SUCCESS / FAILURE
    pct_time        NUMERIC(5,2) NOT NULL DEFAULT 0,
    last_candle_ts  TIMESTAMPTZ,
    last_error      TEXT,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (run_id, symbol, interval)
);

CREATE INDEX IF NOT EXISTS idx_backfill_progress_symbol_interval
  ON trading_data.backfill_progress(symbol, interval);

CREATE INDEX IF NOT EXISTS idx_backfill_progress_run
  ON trading_data.backfill_progress(run_id);

CREATE INDEX IF NOT EXISTS idx_backfill_progress_updated
  ON trading_data.backfill_progress(updated_at DESC);

COMMENT ON TABLE trading_data.backfill_progress IS '과거 데이터 백필 진행률 추적';
COMMENT ON COLUMN trading_data.backfill_progress.run_id IS '백필 실행 ID';
COMMENT ON COLUMN trading_data.backfill_progress.symbol IS '종목명';
COMMENT ON COLUMN trading_data.backfill_progress.interval IS '시간봉 (1h, 4h, 1d, 1w, 1M)';
COMMENT ON COLUMN trading_data.backfill_progress.state IS '진행 상태 (PENDING/PROGRESS/SUCCESS/FAILURE)';
COMMENT ON COLUMN trading_data.backfill_progress.pct_time IS '시간 기준 진행률 (0~100%)';
COMMENT ON COLUMN trading_data.backfill_progress.last_candle_ts IS '마지막 처리된 캔들 타임스탬프';
COMMENT ON COLUMN trading_data.backfill_progress.last_error IS '에러 메시지';
COMMENT ON COLUMN trading_data.backfill_progress.updated_at IS '업데이트 시각';

-- =====================================================
-- 2. REST 유지보수 진행 상태 테이블
-- =====================================================
CREATE TABLE IF NOT EXISTS trading_data.rest_progress (
    run_id          VARCHAR(64) NOT NULL,
    symbol          VARCHAR(30) NOT NULL REFERENCES metadata.crypto_info(symbol) ON DELETE CASCADE,
    interval        VARCHAR(10) NOT NULL,
    state           VARCHAR(20) NOT NULL CHECK (state IN ('PENDING','PROGRESS','SUCCESS','FAILURE')),
    last_candle_ts  TIMESTAMPTZ,
    last_error      TEXT,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (run_id, symbol, interval)
);

CREATE INDEX IF NOT EXISTS idx_rest_progress_symbol_interval
  ON trading_data.rest_progress(symbol, interval);

CREATE INDEX IF NOT EXISTS idx_rest_progress_run
  ON trading_data.rest_progress(run_id);

CREATE INDEX IF NOT EXISTS idx_rest_progress_updated
  ON trading_data.rest_progress(updated_at DESC);

COMMENT ON TABLE trading_data.rest_progress IS 'REST API 유지보수 진행률 추적 (is_ended=False 캔들 보정)';
COMMENT ON COLUMN trading_data.rest_progress.run_id IS '유지보수 실행 ID';
COMMENT ON COLUMN trading_data.rest_progress.symbol IS '종목명';
COMMENT ON COLUMN trading_data.rest_progress.interval IS '시간봉 (1h, 4h, 1d, 1w, 1M)';
COMMENT ON COLUMN trading_data.rest_progress.state IS '진행 상태 (PENDING/PROGRESS/SUCCESS/FAILURE)';
COMMENT ON COLUMN trading_data.rest_progress.last_candle_ts IS '마지막 처리된 캔들 타임스탬프';
COMMENT ON COLUMN trading_data.rest_progress.last_error IS '에러 메시지';
COMMENT ON COLUMN trading_data.rest_progress.updated_at IS '업데이트 시각';

-- =====================================================
-- 3. 보조지표 계산 진행 상태 테이블
-- =====================================================
CREATE TABLE IF NOT EXISTS trading_data.indicator_progress (
    run_id          VARCHAR(64) NOT NULL,
    symbol          VARCHAR(30) NOT NULL REFERENCES metadata.crypto_info(symbol) ON DELETE CASCADE,
    interval        VARCHAR(10) NOT NULL,
    state           VARCHAR(20) NOT NULL,    -- PENDING / PROGRESS / SUCCESS / FAILURE
    pct_time        NUMERIC(5,2) NOT NULL DEFAULT 0,
    last_candle_ts  TIMESTAMPTZ,
    last_error      TEXT,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (run_id, symbol, interval)
);

CREATE INDEX IF NOT EXISTS idx_indicator_progress_symbol_interval
  ON trading_data.indicator_progress(symbol, interval);

CREATE INDEX IF NOT EXISTS idx_indicator_progress_run
  ON trading_data.indicator_progress(run_id);

CREATE INDEX IF NOT EXISTS idx_indicator_progress_updated
  ON trading_data.indicator_progress(updated_at DESC);

COMMENT ON TABLE trading_data.indicator_progress IS '보조지표 계산 진행률 추적';
COMMENT ON COLUMN trading_data.indicator_progress.run_id IS '지표 계산 실행 ID';
COMMENT ON COLUMN trading_data.indicator_progress.symbol IS '종목명';
COMMENT ON COLUMN trading_data.indicator_progress.interval IS '시간봉 (1h, 4h, 1d, 1w, 1M)';
COMMENT ON COLUMN trading_data.indicator_progress.state IS '진행 상태 (PENDING/PROGRESS/SUCCESS/FAILURE)';
COMMENT ON COLUMN trading_data.indicator_progress.pct_time IS '시간 기준 진행률 (0~100%)';
COMMENT ON COLUMN trading_data.indicator_progress.last_candle_ts IS '마지막 처리된 캔들 타임스탬프';
COMMENT ON COLUMN trading_data.indicator_progress.last_error IS '에러 메시지';
COMMENT ON COLUMN trading_data.indicator_progress.updated_at IS '업데이트 시각';

-- =====================================================
-- 4. WebSocket 실시간 연결 상태 테이블
-- =====================================================
CREATE TABLE IF NOT EXISTS trading_data.websocket_progress (
    run_id           VARCHAR(64) NOT NULL,
    symbol           VARCHAR(30) NOT NULL REFERENCES metadata.crypto_info(symbol) ON DELETE CASCADE,
    interval         VARCHAR(10) NOT NULL,
    state            VARCHAR(20) NOT NULL,    -- CONNECTED / DISCONNECTED / ERROR
    last_message_ts  TIMESTAMPTZ,
    message_count    INTEGER DEFAULT 0 NOT NULL,
    last_error       TEXT,
    updated_at       TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    PRIMARY KEY (run_id, symbol, interval)
);

CREATE INDEX IF NOT EXISTS idx_ws_progress_symbol_interval
  ON trading_data.websocket_progress(symbol, interval);

CREATE INDEX IF NOT EXISTS idx_ws_progress_run_id 
  ON trading_data.websocket_progress(run_id);

CREATE INDEX IF NOT EXISTS idx_ws_progress_updated 
  ON trading_data.websocket_progress(updated_at DESC);

COMMENT ON TABLE trading_data.websocket_progress IS 'WebSocket 실시간 연결 상태 추적';
COMMENT ON COLUMN trading_data.websocket_progress.run_id IS 'WebSocket 세션 ID';
COMMENT ON COLUMN trading_data.websocket_progress.symbol IS '종목명';
COMMENT ON COLUMN trading_data.websocket_progress.interval IS '시간봉 (1h, 4h, 1d, 1w, 1M)';
COMMENT ON COLUMN trading_data.websocket_progress.state IS '연결 상태 (CONNECTED/DISCONNECTED/ERROR)';
COMMENT ON COLUMN trading_data.websocket_progress.last_message_ts IS '마지막 메시지 수신 시각';
COMMENT ON COLUMN trading_data.websocket_progress.message_count IS '수신된 메시지 개수';
COMMENT ON COLUMN trading_data.websocket_progress.last_error IS '에러 메시지';
COMMENT ON COLUMN trading_data.websocket_progress.updated_at IS '업데이트 시각';
