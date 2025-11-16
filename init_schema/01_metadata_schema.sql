CREATE SCHEMA IF NOT EXISTS metadata;

CREATE TABLE IF NOT EXISTS metadata.crypto_info (
    symbol VARCHAR(30) PRIMARY KEY,
    
    pair VARCHAR(30) NOT NULL UNIQUE,

    price_precision INT,           -- 가격 소수점 자릿수
    quantity_precision INT,        -- 수량 소수점 자릿수

    required_margin_percent NUMERIC(10, 5), -- 개시 증거금 비율 (최대 레버리지 계산용)
    maint_margin_percent NUMERIC(10, 5),    -- 유지 증거금 비율
    liquidation_fee NUMERIC(10, 5),       -- 청산 수수료

    tick_size NUMERIC(30, 15),          -- 가격 틱 (호가 단위)

    min_qty NUMERIC(30, 15),            -- 최소 주문 수량
    max_qty NUMERIC(30, 15),            -- 최대 주문 수량
    step_size NUMERIC(30, 15),          -- 수량 스텝 (주문 단위)

    market_min_qty NUMERIC(30, 15),     -- 시장가 최소 주문 수량
    market_max_qty NUMERIC(30, 15),     -- 시장가 최대 주문 수량
    market_step_size NUMERIC(30, 15),   -- 시장가 수량 스텝

    min_notional NUMERIC(30, 15),       -- 최소 주문 금액 (가격 * 수량)
    max_num_orders INT                  -- 최대 미체결 주문 수
);

CREATE INDEX IF NOT EXISTS idx_crypto_info_symbol ON metadata.crypto_info (symbol);
CREATE INDEX IF NOT EXISTS idx_crypto_info_pair ON metadata.crypto_info (pair);