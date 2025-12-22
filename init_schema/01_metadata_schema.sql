CREATE SCHEMA IF NOT EXISTS metadata;

-- 기본 종목 정보 (symbol, pair만 저장)
-- 거래 조건은 futures.symbol_trading_rules 테이블에서 관리
CREATE TABLE IF NOT EXISTS metadata.crypto_info (
    symbol VARCHAR(30) PRIMARY KEY,
    pair   VARCHAR(30) NOT NULL UNIQUE,
    is_backtesting_only BOOLEAN DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_crypto_info_symbol ON metadata.crypto_info (symbol);
CREATE INDEX IF NOT EXISTS idx_crypto_info_pair ON metadata.crypto_info (pair);