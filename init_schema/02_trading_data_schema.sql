CREATE EXTENSION IF NOT EXISTS timescaledb;

-- =========================
-- 1. 스키마 생성
-- =========================
CREATE SCHEMA IF NOT EXISTS trading_data;

-- =========================
-- 2. 캔들 데이터 스키마 (OHLCV)
-- =========================
CREATE TABLE IF NOT EXISTS trading_data.ohlcv_1m (
    symbol      VARCHAR(30)   NOT NULL REFERENCES metadata.crypto_info(symbol) ON DELETE CASCADE,
    "timestamp" TIMESTAMPTZ   NOT NULL,
    open        NUMERIC(20,7) NOT NULL,
    high        NUMERIC(20,7) NOT NULL,
    low         NUMERIC(20,7) NOT NULL,
    close       NUMERIC(20,7) NOT NULL,
    volume      NUMERIC(20,3) NOT NULL,
    is_ended    BOOLEAN       NOT NULL DEFAULT FALSE,
    CONSTRAINT ohlcv_1m_pk PRIMARY KEY (symbol, "timestamp")
);

SELECT create_hypertable(
  'trading_data.ohlcv_1m',
  'timestamp',
  partitioning_column => 'symbol',
  number_partitions   => 32,
  chunk_time_interval => INTERVAL '7 days',
  if_not_exists       => TRUE
);

CREATE INDEX IF NOT EXISTS idx_ohlcv_1m_symbol_ts_desc
  ON trading_data.ohlcv_1m (symbol, "timestamp" DESC);

DO $$
DECLARE
    rec RECORD;
    tbl_name TEXT;
    qname TEXT;
    idxname TEXT;
BEGIN
    FOR rec IN
        SELECT * FROM (VALUES
            ('3m',  INTERVAL '21 days',   'CHECK ( (EXTRACT(EPOCH FROM "timestamp")::bigint % 180) = 0 )'),
            ('5m',  INTERVAL '60 days',   'CHECK ( (EXTRACT(EPOCH FROM "timestamp")::bigint % 300) = 0 )'),
            ('15m', INTERVAL '120 days',  'CHECK ( (EXTRACT(EPOCH FROM "timestamp")::bigint % 900) = 0 )'),
            ('30m', INTERVAL '180 days',  'CHECK ( (EXTRACT(EPOCH FROM "timestamp")::bigint % 1800) = 0 )'),
            ('1h',  INTERVAL '180 days',  'CHECK ( (EXTRACT(EPOCH FROM "timestamp")::bigint % 3600) = 0 )'),
            ('4h',  INTERVAL '365 days',  'CHECK ( (EXTRACT(EPOCH FROM "timestamp")::bigint % 14400) = 0 )'),
            ('1d',  INTERVAL '5 years',   'CHECK ( (EXTRACT(EPOCH FROM "timestamp")::bigint % 86400) = 0 )'),
            ('1w',  INTERVAL '10 years',  'CHECK ( (EXTRACT(ISODOW FROM "timestamp") = 1) AND ("timestamp"::time = ''00:00:00'') )'),
            ('1M',  INTERVAL '50 years',  'CHECK ( (EXTRACT(DAY FROM "timestamp") = 1) AND ("timestamp"::time = ''00:00:00'') )')
        ) AS t(tf, chunk, align_sql)
    LOOP
        tbl_name := 'ohlcv_' || rec.tf;
        qname := format('%I.%I', 'trading_data', tbl_name);
        idxname := format('idx_%s_symbol_ts_desc', tbl_name);

        EXECUTE format(
            $fmt$
            CREATE TABLE IF NOT EXISTS %s (
                symbol      VARCHAR(30)   NOT NULL REFERENCES metadata.crypto_info(symbol) ON DELETE CASCADE,
                "timestamp" TIMESTAMPTZ   NOT NULL,
                open        NUMERIC(20,7) NOT NULL,
                high        NUMERIC(20,7) NOT NULL,
                low         NUMERIC(20,7) NOT NULL,
                close       NUMERIC(20,7) NOT NULL,
                volume      NUMERIC(20,3) NOT NULL,
                is_ended    BOOLEAN       NOT NULL DEFAULT FALSE,
                CONSTRAINT %I PRIMARY KEY (symbol, "timestamp"),
                CONSTRAINT %I %s
            );
            $fmt$,
            qname,
            tbl_name || '_pk',
            tbl_name || '_bucket_align',
            rec.align_sql
        );

        PERFORM create_hypertable(
            qname,
            'timestamp',
            partitioning_column => 'symbol',
            number_partitions   => 32,
            chunk_time_interval => rec.chunk,
            if_not_exists       => TRUE
        );

        EXECUTE format(
            'CREATE INDEX IF NOT EXISTS %I ON %s (symbol, "timestamp" DESC);',
            idxname, qname
        );
    END LOOP;
END
$$;

-- =========================
-- 3. 보조지표 스키마 (Indicators)
-- =========================
CREATE TABLE IF NOT EXISTS trading_data.indicators_1m (
    symbol      VARCHAR(30)   NOT NULL REFERENCES metadata.crypto_info(symbol) ON DELETE CASCADE,
    "timestamp" TIMESTAMPTZ   NOT NULL,
    rsi_14      NUMERIC(20,7) NOT NULL,
    ema_7       NUMERIC(20,7) NOT NULL,
    ema_21      NUMERIC(20,7) NOT NULL,
    ema_99      NUMERIC(20,7),
    macd        NUMERIC(20,7) NOT NULL,
    macd_signal NUMERIC(20,7) NOT NULL,
    macd_hist   NUMERIC(20,7) NOT NULL,
    bb_upper    NUMERIC(20,7) NOT NULL,
    bb_middle   NUMERIC(20,7) NOT NULL,
    bb_lower    NUMERIC(20,7) NOT NULL,
    volume_20   NUMERIC(20,3) NOT NULL,
    CONSTRAINT indicators_1m_pk PRIMARY KEY (symbol, "timestamp")
);

SELECT create_hypertable(
  'trading_data.indicators_1m',
  'timestamp',
  partitioning_column => 'symbol',
  number_partitions   => 32,
  chunk_time_interval => INTERVAL '7 days',
  if_not_exists       => TRUE
);

CREATE INDEX IF NOT EXISTS idx_indicators_1m_symbol_ts_desc
  ON trading_data.indicators_1m (symbol, "timestamp" DESC);

DO $$
DECLARE
    rec RECORD;
    tbl_name TEXT;
    qname TEXT;
    idxname TEXT;
BEGIN
    FOR rec IN 
        SELECT * FROM (VALUES
            ('3m',  INTERVAL '21 days',   'CHECK ( (EXTRACT(EPOCH FROM "timestamp")::bigint % 180) = 0 )'),
            ('5m',  INTERVAL '60 days',   'CHECK ( (EXTRACT(EPOCH FROM "timestamp")::bigint % 300) = 0 )'),
            ('15m', INTERVAL '120 days',  'CHECK ( (EXTRACT(EPOCH FROM "timestamp")::bigint % 900) = 0 )'),
            ('30m', INTERVAL '180 days',  'CHECK ( (EXTRACT(EPOCH FROM "timestamp")::bigint % 1800) = 0 )'),
            ('1h',  INTERVAL '180 days',  'CHECK ( (EXTRACT(EPOCH FROM "timestamp")::bigint % 3600) = 0 )'),
            ('4h',  INTERVAL '365 days',  'CHECK ( (EXTRACT(EPOCH FROM "timestamp")::bigint % 14400) = 0 )'),
            ('1d',  INTERVAL '5 years',   'CHECK ( (EXTRACT(EPOCH FROM "timestamp")::bigint % 86400) = 0 )'),
            ('1w',  INTERVAL '10 years',  'CHECK ( (EXTRACT(ISODOW FROM "timestamp") = 1) AND ("timestamp"::time = ''00:00:00'') )'),
            ('1M',  INTERVAL '50 years',  'CHECK ( (EXTRACT(DAY FROM "timestamp") = 1) AND ("timestamp"::time = ''00:00:00'') )')
        ) AS t(tf, chunk, align_sql)
    LOOP
        tbl_name := 'indicators_' || rec.tf;
        qname := format('%I.%I', 'trading_data', tbl_name);
        idxname := format('idx_%s_symbol_ts_desc', tbl_name);

        EXECUTE format(
            $fmt$
            CREATE TABLE IF NOT EXISTS %s (
                symbol      VARCHAR(30)   NOT NULL REFERENCES metadata.crypto_info(symbol) ON DELETE CASCADE,
                "timestamp" TIMESTAMPTZ   NOT NULL,
                rsi_14      NUMERIC(20,7) NOT NULL,
                ema_7       NUMERIC(20,7) NOT NULL,
                ema_21      NUMERIC(20,7) NOT NULL,
                ema_99      NUMERIC(20,7),
                macd        NUMERIC(20,7) NOT NULL,
                macd_signal NUMERIC(20,7) NOT NULL,
                macd_hist   NUMERIC(20,7) NOT NULL,
                bb_upper    NUMERIC(20,7) NOT NULL,
                bb_middle   NUMERIC(20,7) NOT NULL,
                bb_lower    NUMERIC(20,7) NOT NULL,
                volume_20   NUMERIC(20,3) NOT NULL,
                CONSTRAINT %I PRIMARY KEY (symbol, "timestamp"),
                CONSTRAINT %I %s
            );
            $fmt$,
            qname,
            tbl_name || '_pk',
            tbl_name || '_bucket_align',
            rec.align_sql
        );

        PERFORM create_hypertable(
            qname,
            'timestamp',
            partitioning_column => 'symbol',
            number_partitions   => 32,
            chunk_time_interval => rec.chunk,
            if_not_exists       => TRUE
        );

        EXECUTE format(
            'CREATE INDEX IF NOT EXISTS %I ON %s (symbol, "timestamp" DESC);',
            idxname, qname
        );
    END LOOP;
END
$$;

-- =========================
-- 4. 파이프라인 상태 테이블 (싱글톤, ON/OFF 플래그)
-- =========================
CREATE TABLE IF NOT EXISTS trading_data.pipeline_state (
    id         SMALLINT    PRIMARY KEY,
    is_active  BOOLEAN     NOT NULL DEFAULT FALSE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_error TEXT,
    current_backfill_run_id VARCHAR(64)
);

INSERT INTO trading_data.pipeline_state (id, is_active)
VALUES
    (1, FALSE),  -- 전체 파이프라인
    (2, FALSE),  -- WebSocket
    (3, FALSE),  -- Backfill
    (4, FALSE),  -- REST 유지보수
    (5, FALSE)   -- 보조지표
ON CONFLICT (id) DO NOTHING;


-- =========================
-- 5. 엔진 상태 테이블 (실제 상태 + 에러 로그용)
-- =========================
-- 시간 기준 필터링을 위해 updated_at을 사용
-- status: WAIT / PROGRESS / FAIL
CREATE TABLE IF NOT EXISTS trading_data.engine_status (
    id         SMALLINT    PRIMARY KEY,           -- 2,3,4,5 (pipeline_state.id와 매칭)
    name       VARCHAR(32) NOT NULL UNIQUE,       -- 'websocket', 'backfill', 'rest_maint', 'indicator'
    status     VARCHAR(16) NOT NULL DEFAULT 'WAIT',  -- WAIT / PROGRESS / FAIL
    last_error TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT engine_status_status_chk
        CHECK (status IN ('WAIT','PROGRESS','FAIL'))
);

INSERT INTO trading_data.engine_status (id, name, status)
VALUES
    (2, 'websocket', 'WAIT'),
    (3, 'backfill',  'WAIT'),
    (4, 'rest_maint','WAIT'),
    (5, 'indicator', 'WAIT')
ON CONFLICT (id) DO NOTHING;

CREATE INDEX IF NOT EXISTS idx_engine_status_status
  ON trading_data.engine_status (status);

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

-- ============================
-- REST 유지보수 상태 테이블
-- ============================
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

-- =========================
-- 6. 보조지표 계산 진행 테이블
-- =========================
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

-- =========================
-- 7. Stop Loss 스키마 (Stop Loss)
-- =========================
CREATE TABLE IF NOT EXISTS trading_data.stop_loss_1m (
    symbol            VARCHAR(30)   NOT NULL REFERENCES metadata.crypto_info(symbol) ON DELETE CASCADE,
    "timestamp"       TIMESTAMPTZ   NOT NULL,
    long_min_low_5    NUMERIC(20,7),
    long_min_low_20   NUMERIC(20,7),
    short_max_high_5  NUMERIC(20,7),
    short_max_high_20 NUMERIC(20,7),
    CONSTRAINT stop_loss_1m_pk PRIMARY KEY (symbol, "timestamp")
);

SELECT create_hypertable(
  'trading_data.stop_loss_1m',
  'timestamp',
  partitioning_column => 'symbol',
  number_partitions   => 32,
  chunk_time_interval => INTERVAL '7 days',
  if_not_exists       => TRUE
);

CREATE INDEX IF NOT EXISTS idx_stop_loss_1m_symbol_ts_desc
  ON trading_data.stop_loss_1m (symbol, "timestamp" DESC);

DO $$
DECLARE
    rec RECORD;
    tbl_name TEXT;
    qname TEXT;
    idxname TEXT;
BEGIN
    FOR rec IN 
        SELECT * FROM (VALUES
            ('3m',  INTERVAL '21 days',   'CHECK ( (EXTRACT(EPOCH FROM "timestamp")::bigint % 180) = 0 )'),
            ('5m',  INTERVAL '60 days',   'CHECK ( (EXTRACT(EPOCH FROM "timestamp")::bigint % 300) = 0 )'),
            ('15m', INTERVAL '120 days',  'CHECK ( (EXTRACT(EPOCH FROM "timestamp")::bigint % 900) = 0 )'),
            ('30m', INTERVAL '180 days',  'CHECK ( (EXTRACT(EPOCH FROM "timestamp")::bigint % 1800) = 0 )'),
            ('1h',  INTERVAL '180 days',  'CHECK ( (EXTRACT(EPOCH FROM "timestamp")::bigint % 3600) = 0 )'),
            ('4h',  INTERVAL '365 days',  'CHECK ( (EXTRACT(EPOCH FROM "timestamp")::bigint % 14400) = 0 )'),
            ('1d',  INTERVAL '5 years',   'CHECK ( (EXTRACT(EPOCH FROM "timestamp")::bigint % 86400) = 0 )'),
            ('1w',  INTERVAL '10 years',  'CHECK ( (EXTRACT(ISODOW FROM "timestamp") = 1) AND ("timestamp"::time = ''00:00:00'') )'),
            ('1M',  INTERVAL '50 years',  'CHECK ( (EXTRACT(DAY FROM "timestamp") = 1) AND ("timestamp"::time = ''00:00:00'') )')
        ) AS t(tf, chunk, align_sql)
    LOOP
        tbl_name := 'stop_loss_' || rec.tf;
        qname := format('%I.%I', 'trading_data', tbl_name);
        idxname := format('idx_%s_symbol_ts_desc', tbl_name);

        EXECUTE format(
            $fmt$
            CREATE TABLE IF NOT EXISTS %s (
                symbol            VARCHAR(30)   NOT NULL REFERENCES metadata.crypto_info(symbol) ON DELETE CASCADE,
                "timestamp"       TIMESTAMPTZ   NOT NULL,
                long_min_low_5    NUMERIC(20,7),
                long_min_low_20   NUMERIC(20,7),
                short_max_high_5  NUMERIC(20,7),
                short_max_high_20 NUMERIC(20,7),
                CONSTRAINT %I PRIMARY KEY (symbol, "timestamp"),
                CONSTRAINT %I %s
            );
            $fmt$,
            qname,
            tbl_name || '_pk',
            tbl_name || '_bucket_align',
            rec.align_sql
        );

        PERFORM create_hypertable(
            qname,
            'timestamp',
            partitioning_column => 'symbol',
            number_partitions   => 32,
            chunk_time_interval => rec.chunk,
            if_not_exists       => TRUE
        );

        EXECUTE format(
            'CREATE INDEX IF NOT EXISTS %I ON %s (symbol, "timestamp" DESC);',
            idxname, qname
        );
    END LOOP;
END
$$;