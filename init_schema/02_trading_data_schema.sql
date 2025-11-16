CREATE EXTENSION IF NOT EXISTS timescaledb;

CREATE SCHEMA IF NOT EXISTS trading_data;
-- 캔들 데이터 스키마
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

-- 보조지표 스키마
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
