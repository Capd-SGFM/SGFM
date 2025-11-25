-- =====================================================
-- TimescaleDB Compression Policies
-- =====================================================
-- This file configures automatic compression for hypertables
-- to achieve 90% storage savings and 2-10x faster queries
-- =====================================================

-- =====================================================
-- 1. Enable Compression for OHLCV Tables
-- =====================================================

-- Compress all intervals after 30 days
-- segmentby = 'symbol' groups data by symbol for better compression

ALTER TABLE IF EXISTS trading_data.ohlcv_1m SET (
  timescaledb.compress,
  timescaledb.compress_segmentby = 'symbol',
  timescaledb.compress_orderby = 'timestamp DESC'
);

ALTER TABLE IF EXISTS trading_data.ohlcv_3m SET (
  timescaledb.compress,
  timescaledb.compress_segmentby = 'symbol',
  timescaledb.compress_orderby = 'timestamp DESC'
);

ALTER TABLE IF EXISTS trading_data.ohlcv_5m SET (
  timescaledb.compress,
  timescaledb.compress_segmentby = 'symbol',
  timescaledb.compress_orderby = 'timestamp DESC'
);

ALTER TABLE IF EXISTS trading_data.ohlcv_15m SET (
  timescaledb.compress,
  timescaledb.compress_segmentby = 'symbol',
  timescaledb.compress_orderby = 'timestamp DESC'
);

ALTER TABLE IF EXISTS trading_data.ohlcv_30m SET (
  timescaledb.compress,
  timescaledb.compress_segmentby = 'symbol',
  timescaledb.compress_orderby = 'timestamp DESC'
);

ALTER TABLE IF EXISTS trading_data.ohlcv_1h SET (
  timescaledb.compress,
  timescaledb.compress_segmentby = 'symbol',
  timescaledb.compress_orderby = 'timestamp DESC'
);

ALTER TABLE IF EXISTS trading_data.ohlcv_4h SET (
  timescaledb.compress,
  timescaledb.compress_segmentby = 'symbol',
  timescaledb.compress_orderby = 'timestamp DESC'
);

ALTER TABLE IF EXISTS trading_data.ohlcv_1d SET (
  timescaledb.compress,
  timescaledb.compress_segmentby = 'symbol',
  timescaledb.compress_orderby = 'timestamp DESC'
);

ALTER TABLE IF EXISTS trading_data.ohlcv_1w SET (
  timescaledb.compress,
  timescaledb.compress_segmentby = 'symbol',
  timescaledb.compress_orderby = 'timestamp DESC'
);

ALTER TABLE IF EXISTS trading_data.ohlcv_1M SET (
  timescaledb.compress,
  timescaledb.compress_segmentby = 'symbol',
  timescaledb.compress_orderby = 'timestamp DESC'
);

-- =====================================================
-- 2. Enable Compression for Indicators Tables
-- =====================================================

ALTER TABLE IF EXISTS trading_data.indicators_1m SET (
  timescaledb.compress,
  timescaledb.compress_segmentby = 'symbol',
  timescaledb.compress_orderby = 'timestamp DESC'
);

ALTER TABLE IF EXISTS trading_data.indicators_3m SET (
  timescaledb.compress,
  timescaledb.compress_segmentby = 'symbol',
  timescaledb.compress_orderby = 'timestamp DESC'
);

ALTER TABLE IF EXISTS trading_data.indicators_5m SET (
  timescaledb.compress,
  timescaledb.compress_segmentby = 'symbol',
  timescaledb.compress_orderby = 'timestamp DESC'
);

ALTER TABLE IF EXISTS trading_data.indicators_15m SET (
  timescaledb.compress,
  timescaledb.compress_segmentby = 'symbol',
  timescaledb.compress_orderby = 'timestamp DESC'
);

ALTER TABLE IF EXISTS trading_data.indicators_30m SET (
  timescaledb.compress,
  timescaledb.compress_segmentby = 'symbol',
  timescaledb.compress_orderby = 'timestamp DESC'
);

ALTER TABLE IF EXISTS trading_data.indicators_1h SET (
  timescaledb.compress,
  timescaledb.compress_segmentby = 'symbol',
  timescaledb.compress_orderby = 'timestamp DESC'
);

ALTER TABLE IF EXISTS trading_data.indicators_4h SET (
  timescaledb.compress,
  timescaledb.compress_segmentby = 'symbol',
  timescaledb.compress_orderby = 'timestamp DESC'
);

ALTER TABLE IF EXISTS trading_data.indicators_1d SET (
  timescaledb.compress,
  timescaledb.compress_segmentby = 'symbol',
  timescaledb.compress_orderby = 'timestamp DESC'
);

ALTER TABLE IF EXISTS trading_data.indicators_1w SET (
  timescaledb.compress,
  timescaledb.compress_segmentby = 'symbol',
  timescaledb.compress_orderby = 'timestamp DESC'
);

ALTER TABLE IF EXISTS trading_data.indicators_1M SET (
  timescaledb.compress,
  timescaledb.compress_segmentby = 'symbol',
  timescaledb.compress_orderby = 'timestamp DESC'
);

-- =====================================================
-- 3. Add Compression Policies (Automatic Background Compression)
-- =====================================================

-- Compress OHLCV data older than 30 days
SELECT add_compression_policy('trading_data.ohlcv_1m', INTERVAL '30 days', if_not_exists => true);
SELECT add_compression_policy('trading_data.ohlcv_3m', INTERVAL '30 days', if_not_exists => true);
SELECT add_compression_policy('trading_data.ohlcv_5m', INTERVAL '30 days', if_not_exists => true);
SELECT add_compression_policy('trading_data.ohlcv_15m', INTERVAL '30 days', if_not_exists => true);
SELECT add_compression_policy('trading_data.ohlcv_30m', INTERVAL '30 days', if_not_exists => true);
SELECT add_compression_policy('trading_data.ohlcv_1h', INTERVAL '30 days', if_not_exists => true);
SELECT add_compression_policy('trading_data.ohlcv_4h', INTERVAL '30 days', if_not_exists => true);
SELECT add_compression_policy('trading_data.ohlcv_1d', INTERVAL '30 days', if_not_exists => true);
SELECT add_compression_policy('trading_data.ohlcv_1w', INTERVAL '30 days', if_not_exists => true);
SELECT add_compression_policy('trading_data.ohlcv_1M', INTERVAL '30 days', if_not_exists => true);

-- Compress indicators data older than 30 days
SELECT add_compression_policy('trading_data.indicators_1m', INTERVAL '30 days', if_not_exists => true);
SELECT add_compression_policy('trading_data.indicators_3m', INTERVAL '30 days', if_not_exists => true);
SELECT add_compression_policy('trading_data.indicators_5m', INTERVAL '30 days', if_not_exists => true);
SELECT add_compression_policy('trading_data.indicators_15m', INTERVAL '30 days', if_not_exists => true);
SELECT add_compression_policy('trading_data.indicators_30m', INTERVAL '30 days', if_not_exists => true);
SELECT add_compression_policy('trading_data.indicators_1h', INTERVAL '30 days', if_not_exists => true);
SELECT add_compression_policy('trading_data.indicators_4h', INTERVAL '30 days', if_not_exists => true);
SELECT add_compression_policy('trading_data.indicators_1d', INTERVAL '30 days', if_not_exists => true);
SELECT add_compression_policy('trading_data.indicators_1w', INTERVAL '30 days', if_not_exists => true);
SELECT add_compression_policy('trading_data.indicators_1M', INTERVAL '30 days', if_not_exists => true);

-- =====================================================
-- 4. Verify Compression Settings
-- =====================================================

-- You can check compression stats with:
-- SELECT * FROM timescaledb_information.compression_settings;
-- SELECT * FROM timescaledb_information.jobs WHERE proc_name = 'policy_compression';

COMMENT ON SCHEMA trading_data IS 'Trading data schema with TimescaleDB compression enabled for 90% storage savings';
