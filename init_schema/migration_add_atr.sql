DO $$
DECLARE
    intervals TEXT[] := ARRAY['1m', '5m', '15m', '1h', '4h', '1d'];
    interval TEXT;
    table_name TEXT;
BEGIN
    FOREACH interval IN ARRAY intervals
    LOOP
        table_name := 'indicators_' || interval;
        EXECUTE format('ALTER TABLE trading_data.%I ADD COLUMN IF NOT EXISTS atr NUMERIC(20,7)', table_name);
    END LOOP;
END $$;
