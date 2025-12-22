-- =========================
-- 8. Backtesting Features Schema
-- =========================
CREATE TABLE IF NOT EXISTS trading_data.backtesting_features_1m (
    symbol      VARCHAR(30)   NOT NULL REFERENCES metadata.crypto_info(symbol) ON DELETE CASCADE,
    "timestamp" TIMESTAMPTZ   NOT NULL,
    log_return  NUMERIC(20,7),
    ema_ratio   NUMERIC(20,7),
    macd_hist   NUMERIC(20,7),
    bandwidth   NUMERIC(20,7),
    pct_b       NUMERIC(20,7),
    rsi         NUMERIC(20,7),
    mfi         NUMERIC(20,7),
    CONSTRAINT backtesting_features_1m_pk PRIMARY KEY (symbol, "timestamp")
);

SELECT create_hypertable(
  'trading_data.backtesting_features_1m',
  'timestamp',
  partitioning_column => 'symbol',
  number_partitions   => 32,
  chunk_time_interval => INTERVAL '7 days',
  if_not_exists       => TRUE
);

CREATE INDEX IF NOT EXISTS idx_backtesting_features_1m_symbol_ts_desc
  ON trading_data.backtesting_features_1m (symbol, "timestamp" DESC);

DO $$
DECLARE
    rec RECORD;
    tbl_name TEXT;
    qname TEXT;
    idxname TEXT;
BEGIN
    FOR rec IN
        SELECT * FROM (VALUES
            ('5m',  INTERVAL '60 days',   'CHECK ( (EXTRACT(EPOCH FROM "timestamp")::bigint % 300) = 0 )'),
            ('15m', INTERVAL '120 days',  'CHECK ( (EXTRACT(EPOCH FROM "timestamp")::bigint % 900) = 0 )'),
            ('1h',  INTERVAL '180 days',  'CHECK ( (EXTRACT(EPOCH FROM "timestamp")::bigint % 3600) = 0 )'),
            ('4h',  INTERVAL '365 days',  'CHECK ( (EXTRACT(EPOCH FROM "timestamp")::bigint % 14400) = 0 )'),
            ('1d',  INTERVAL '5 years',   'CHECK ( (EXTRACT(EPOCH FROM "timestamp")::bigint % 86400) = 0 )')
        ) AS t(tf, chunk, align_sql)
    LOOP
        tbl_name := 'backtesting_features_' || rec.tf;
        qname := format('%I.%I', 'trading_data', tbl_name);
        idxname := format('idx_%s_symbol_ts_desc', tbl_name);

        EXECUTE format(
            $fmt$
            CREATE TABLE IF NOT EXISTS %s (
                symbol      VARCHAR(30)   NOT NULL REFERENCES metadata.crypto_info(symbol) ON DELETE CASCADE,
                "timestamp" TIMESTAMPTZ   NOT NULL,
                log_return  NUMERIC(20,7),
                ema_ratio   NUMERIC(20,7),
                macd_hist   NUMERIC(20,7),
                bandwidth   NUMERIC(20,7),
                pct_b       NUMERIC(20,7),
                rsi         NUMERIC(20,7),
                mfi         NUMERIC(20,7),
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
