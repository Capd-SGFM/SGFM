
-- =========================
-- ATR 전용 테이블 스키마
-- =========================

DO $$
DECLARE
    rec RECORD;
    tbl_name TEXT;
    qname TEXT;
    idxname TEXT;
BEGIN
    FOR rec IN 
        SELECT * FROM (VALUES
            ('1m',  INTERVAL '7 days',    NULL),
            ('5m',  INTERVAL '60 days',   'CHECK ( (EXTRACT(EPOCH FROM "timestamp")::bigint % 300) = 0 )'),
            ('15m', INTERVAL '120 days',  'CHECK ( (EXTRACT(EPOCH FROM "timestamp")::bigint % 900) = 0 )'),
            ('1h',  INTERVAL '180 days',  'CHECK ( (EXTRACT(EPOCH FROM "timestamp")::bigint % 3600) = 0 )'),
            ('4h',  INTERVAL '365 days',  'CHECK ( (EXTRACT(EPOCH FROM "timestamp")::bigint % 14400) = 0 )'),
            ('1d',  INTERVAL '5 years',   'CHECK ( (EXTRACT(EPOCH FROM "timestamp")::bigint % 86400) = 0 )')
        ) AS t(tf, chunk, align_sql)
    LOOP
        tbl_name := 'atr_' || rec.tf;
        qname := format('%I.%I', 'trading_data', tbl_name);
        idxname := format('idx_%s_symbol_ts_desc', tbl_name);

        -- 1. Create Table
        EXECUTE format(
            $fmt$
            CREATE TABLE IF NOT EXISTS %s (
                symbol      VARCHAR(30)   NOT NULL REFERENCES metadata.crypto_info(symbol) ON DELETE CASCADE,
                "timestamp" TIMESTAMPTZ   NOT NULL,
                atr         NUMERIC(20,7) NOT NULL,
                CONSTRAINT %I PRIMARY KEY (symbol, "timestamp")
            );
            $fmt$,
            qname,
            tbl_name || '_pk'
        );

        -- 2. Add Constraints if needed (Alignment)
        IF rec.align_sql IS NOT NULL THEN
             EXECUTE format(
                $fmt$
                ALTER TABLE %s ADD CONSTRAINT %I %s;
                $fmt$,
                qname,
                tbl_name || '_bucket_align',
                rec.align_sql
             );
        END IF;

        -- 3. Create Hypertable
        PERFORM create_hypertable(
            qname,
            'timestamp',
            partitioning_column => 'symbol',
            number_partitions   => 32,
            chunk_time_interval => rec.chunk,
            if_not_exists       => TRUE
        );

        -- 4. Create Index
        EXECUTE format(
            'CREATE INDEX IF NOT EXISTS %I ON %s (symbol, "timestamp" DESC);',
            idxname, qname
        );
    END LOOP;
END
$$;
