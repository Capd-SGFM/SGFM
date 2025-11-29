-- =====================================
-- 선물 거래 스키마 (Futures Trading)
-- =====================================
-- 바이낸스 선물 거래와 유사한 기능 구현을 위한 테이블 설계
-- 사용자별 고유 계좌, 포지션 관리, 주문 처리, 거래 내역 등을 관리

CREATE SCHEMA IF NOT EXISTS futures;

-- =====================================
-- 1. 종목별 거래 조건 테이블
-- =====================================
-- 각 종목의 선물 거래 조건 (최소/최대 주문량, 소수점, 증거금 등)
CREATE TABLE IF NOT EXISTS futures.symbol_trading_rules (
    symbol VARCHAR(30) PRIMARY KEY REFERENCES metadata.crypto_info(symbol) ON DELETE CASCADE,
    
    -- 소수점 정밀도
    price_precision      INT NOT NULL,              -- 가격 소수점 자릿수 (예: BTC = 1 → 0.1)
    quantity_precision   INT NOT NULL,              -- 수량 소수점 자릿수 (예: BTC = 3 → 0.001)
    
    -- 가격 관련
    tick_size            NUMERIC(30, 15) NOT NULL,  -- 가격 틱 (호가 단위, 예: 0.1, 0.01)
    
    -- 수량 제한 (지정가 주문)
    min_qty              NUMERIC(30, 15) NOT NULL,  -- 최소 주문 수량
    max_qty              NUMERIC(30, 15) NOT NULL,  -- 최대 주문 수량
    step_size            NUMERIC(30, 15) NOT NULL,  -- 수량 스텝 (주문 단위, 0.001 등)
    
    -- 수량 제한 (시장가 주문)
    market_min_qty       NUMERIC(30, 15) NOT NULL,  -- 시장가 최소 주문 수량
    market_max_qty       NUMERIC(30, 15) NOT NULL,  -- 시장가 최대 주문 수량
    market_step_size     NUMERIC(30, 15) NOT NULL,  -- 시장가 수량 스텝
    
    -- 금액 제한
    min_notional         NUMERIC(30, 15) NOT NULL,  -- 최소 주문 금액 (가격 × 수량, USDT 기준)
    
    -- 주문 개수 제한
    max_num_orders       INT NOT NULL DEFAULT 200,  -- 최대 미체결 주문 수
    max_num_algo_orders  INT NOT NULL DEFAULT 10,   -- 최대 알고 주문 수 (STOP, TP)
    
    -- 증거금 및 레버리지
    required_margin_percent NUMERIC(10, 5) NOT NULL, -- 개시 증거금 비율 (최대 레버리지 계산용)
    maint_margin_percent    NUMERIC(10, 5) NOT NULL, -- 유지 증거금 비율 (청산 기준)
    
    max_leverage         INT NOT NULL DEFAULT 125,   -- 최대 레버리지
    
    -- 수수료
    maker_commission_rate NUMERIC(10, 5) NOT NULL DEFAULT 0.0002,  -- Maker 수수료 (0.02%)
    taker_commission_rate NUMERIC(10, 5) NOT NULL DEFAULT 0.0004,  -- Taker 수수료 (0.04%)
    liquidation_fee       NUMERIC(10, 5) NOT NULL DEFAULT 0.005,   -- 청산 수수료 (0.5%)
    
    -- 메타 정보
    is_trading_enabled   BOOLEAN NOT NULL DEFAULT TRUE,  -- 거래 가능 여부
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT positive_tick_size CHECK (tick_size > 0),
    CONSTRAINT positive_min_qty CHECK (min_qty > 0),
    CONSTRAINT valid_qty_range CHECK (max_qty >= min_qty),
    CONSTRAINT valid_leverage CHECK (max_leverage >= 1 AND max_leverage <= 125)
);

CREATE INDEX IF NOT EXISTS idx_symbol_trading_rules_symbol ON futures.symbol_trading_rules(symbol);
CREATE INDEX IF NOT EXISTS idx_symbol_trading_rules_enabled ON futures.symbol_trading_rules(is_trading_enabled);

COMMENT ON TABLE futures.symbol_trading_rules IS '종목별 선물 거래 조건 (주문 수량, 가격, 레버리지, 수수료 등)';


-- =====================================
-- 실시간 시장 데이터 테이블들
-- =====================================

-- =====================================
-- 1-A. 실시간 오더북 테이블
-- =====================================
-- 거래소에서 받아온 실시간 호가 정보 (매수/매도 호가)
CREATE TABLE IF NOT EXISTS futures.orderbook (
    symbol         VARCHAR(30) NOT NULL REFERENCES metadata.crypto_info(symbol) ON DELETE CASCADE,
    side           VARCHAR(4) NOT NULL CHECK (side IN ('BID', 'ASK')),  -- BID: 매수호가, ASK: 매도호가
    price          NUMERIC(20, 7) NOT NULL,
    quantity       NUMERIC(30, 8) NOT NULL,
    
    -- 메타 정보
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    PRIMARY KEY (symbol, side, price),
    CONSTRAINT positive_price CHECK (price > 0),
    CONSTRAINT positive_quantity CHECK (quantity > 0)
);

CREATE INDEX IF NOT EXISTS idx_orderbook_symbol ON futures.orderbook(symbol);
CREATE INDEX IF NOT EXISTS idx_orderbook_symbol_side ON futures.orderbook(symbol, side);
CREATE INDEX IF NOT EXISTS idx_orderbook_symbol_side_price ON futures.orderbook(symbol, side, price DESC);

COMMENT ON TABLE futures.orderbook IS '실시간 오더북 (매수/매도 호가)';


-- =====================================
-- 1-B. 실시간 체결 내역 테이블
-- =====================================
-- 거래소에서 발생한 실시간 거래 체결 내역 (최근 거래 기록)
CREATE TABLE IF NOT EXISTS futures.market_trades (
    id             BIGSERIAL PRIMARY KEY,
    symbol         VARCHAR(30) NOT NULL REFERENCES metadata.crypto_info(symbol) ON DELETE CASCADE,
    
    -- 체결 정보
    price          NUMERIC(20, 7) NOT NULL,
    quantity       NUMERIC(30, 8) NOT NULL,
    side           VARCHAR(4) NOT NULL CHECK (side IN ('BUY', 'SELL')),  -- 매수/매도 구분
    
    -- 체결 시간
    trade_time     TIMESTAMPTZ NOT NULL,
    trade_id       VARCHAR(64),                                          -- 거래소의 trade ID (중복 방지)
    
    -- 메타 정보
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT positive_price CHECK (price > 0),
    CONSTRAINT positive_quantity CHECK (quantity > 0)
);

CREATE INDEX IF NOT EXISTS idx_market_trades_symbol ON futures.market_trades(symbol);
CREATE INDEX IF NOT EXISTS idx_market_trades_symbol_time ON futures.market_trades(symbol, trade_time DESC);
CREATE INDEX IF NOT EXISTS idx_market_trades_trade_id ON futures.market_trades(trade_id);
CREATE INDEX IF NOT EXISTS idx_market_trades_created_at ON futures.market_trades(created_at DESC);

-- 오래된 데이터 자동 삭제를 위한 인덱스 (24시간 이상 지난 데이터)
CREATE INDEX IF NOT EXISTS idx_market_trades_cleanup ON futures.market_trades(created_at) 
WHERE created_at < NOW() - INTERVAL '24 hours';

COMMENT ON TABLE futures.market_trades IS '실시간 거래소 체결 내역 (최근 거래)';


-- =====================================
-- 1-C. 현재가 캐시 테이블 (Ticker)
-- =====================================
-- 각 심볼의 현재가 및 시장 정보 (빠른 조회용 캐시)
CREATE TABLE IF NOT EXISTS futures.market_ticker (
    symbol              VARCHAR(30) PRIMARY KEY REFERENCES metadata.crypto_info(symbol) ON DELETE CASCADE,
    
    -- 현재가 정보
    last_price          NUMERIC(20, 7) NOT NULL,                    -- 최종 체결가
    mark_price          NUMERIC(20, 7),                             -- 마크 가격
    
    -- 최우선 호가
    best_bid_price      NUMERIC(20, 7),                             -- 최고 매수 호가
    best_bid_qty        NUMERIC(30, 8),                             -- 최고 매수 호가 수량
    best_ask_price      NUMERIC(20, 7),                             -- 최저 매도 호가
    best_ask_qty        NUMERIC(30, 8),                             -- 최저 매도 호가 수량
    
    -- 24시간 통계
    high_price_24h      NUMERIC(20, 7),                             -- 24시간 최고가
    low_price_24h       NUMERIC(20, 7),                             -- 24시간 최저가
    volume_24h          NUMERIC(30, 8),                             -- 24시간 거래량
    quote_volume_24h    NUMERIC(30, 8),                             -- 24시간 거래대금 (USDT)
    price_change_24h    NUMERIC(20, 7),                             -- 24시간 가격 변동
    price_change_pct_24h NUMERIC(10, 4),                            -- 24시간 변동률 (%)
    
    -- 펀딩
    funding_rate        NUMERIC(10, 8),                             -- 현재 펀딩 비율
    next_funding_time   TIMESTAMPTZ,                                -- 다음 펀딩 시간
    
    -- Open Interest (미결제 약정)
    open_interest       NUMERIC(30, 8),
    
    -- 업데이트 시간
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT positive_last_price CHECK (last_price > 0)
);

CREATE INDEX IF NOT EXISTS idx_market_ticker_symbol ON futures.market_ticker(symbol);
CREATE INDEX IF NOT EXISTS idx_market_ticker_updated ON futures.market_ticker(updated_at DESC);

COMMENT ON TABLE futures.market_ticker IS '실시간 현재가 및 시장 정보 캐시';


-- =====================================
-- 2. 사용자 선물 계좌 테이블 (Multi Sub-Account)
-- =====================================
-- 각 사용자가 여러 개의 독립적인 서브 계좌를 운영할 수 있음
-- 같은 종목에 대해 여러 전략을 동시에 테스트 가능
CREATE TABLE IF NOT EXISTS futures.accounts (
    id                  BIGSERIAL PRIMARY KEY,                   -- 서브 계좌 고유 ID
    google_id           VARCHAR(256) NOT NULL REFERENCES users.accounts(google_id) ON DELETE CASCADE,
    
    -- 계좌 식별
    account_name        VARCHAR(50) NOT NULL,                    -- 계좌 이름 (예: "기본 계좌", "공격적 전략")
    is_default          BOOLEAN NOT NULL DEFAULT FALSE,          -- 기본 계좌 여부
    
    -- 잔고 정보
    total_balance       NUMERIC(30, 8) NOT NULL DEFAULT 0,       -- 총 잔고 (USDT)
    available_balance   NUMERIC(30, 8) NOT NULL DEFAULT 0,       -- 사용 가능 잔고
    margin_balance      NUMERIC(30, 8) NOT NULL DEFAULT 0,       -- 증거금으로 사용 중인 잔고
    unrealized_pnl      NUMERIC(30, 8) NOT NULL DEFAULT 0,       -- 미실현 손익
    
    -- 거래 설정
    max_positions       INTEGER NOT NULL DEFAULT 10,             -- 최대 포지션 개수
    
    -- 통계 정보
    total_trades        INTEGER NOT NULL DEFAULT 0,              -- 총 거래 횟수
    winning_trades      INTEGER NOT NULL DEFAULT 0,              -- 수익 거래 횟수
    total_pnl           NUMERIC(30, 8) NOT NULL DEFAULT 0,       -- 총 실현 손익
    
    -- 메타 정보
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT positive_total_balance CHECK (total_balance >= 0),
    CONSTRAINT positive_available_balance CHECK (available_balance >= 0),
    CONSTRAINT positive_margin_balance CHECK (margin_balance >= 0),
    CONSTRAINT unique_account_name_per_user UNIQUE (google_id, account_name),
    CONSTRAINT unique_default_account UNIQUE (google_id, is_default) WHERE is_default = TRUE
);

CREATE INDEX IF NOT EXISTS idx_futures_accounts_user ON futures.accounts(google_id);
CREATE INDEX IF NOT EXISTS idx_futures_accounts_default ON futures.accounts(google_id, is_default);

-- 계좌 정보 업데이트 트리거
CREATE OR REPLACE FUNCTION futures.touch_account_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := NOW();
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_futures_accounts_touch ON futures.accounts;
CREATE TRIGGER trg_futures_accounts_touch
BEFORE UPDATE ON futures.accounts
FOR EACH ROW EXECUTE FUNCTION futures.touch_account_updated_at();


-- =====================================
-- 3. 포지션 테이블
-- =====================================
-- 서브 계좌별 포지션 관리 (ISOLATED 마진만 지원)
-- 바이낸스 방식: 같은 계좌, 종목, 방향에는 하나의 포지션만 허용 (추가 진입 시 통합)
CREATE TABLE IF NOT EXISTS futures.positions (
    id                  BIGSERIAL PRIMARY KEY,
    account_id          BIGINT NOT NULL REFERENCES futures.accounts(id) ON DELETE CASCADE,  -- 서브 계좌 ID
    google_id           VARCHAR(256) NOT NULL REFERENCES users.accounts(google_id) ON DELETE CASCADE,  -- 사용자 ID (참조용)
    symbol              VARCHAR(30) NOT NULL REFERENCES metadata.crypto_info(symbol) ON DELETE CASCADE,
    
    -- 포지션 기본 정보
    position_side       VARCHAR(10) NOT NULL CHECK (position_side IN ('LONG', 'SHORT')),
    quantity            NUMERIC(30, 8) NOT NULL,                -- 현재 포지션 수량
    initial_quantity    NUMERIC(30, 8) NOT NULL,                -- 최초 진입 수량 (부분 청산 추적용)
    leverage            INTEGER NOT NULL DEFAULT 1,              -- 레버리지 배수 (1~125)
    
    -- 가격 정보
    entry_price         NUMERIC(20, 7) NOT NULL,                -- 평균 진입 가격 (추가 진입 시 재계산)
    mark_price          NUMERIC(20, 7),                         -- 마크 가격 (현재가, 캐시용)
    liquidation_price   NUMERIC(20, 7),                         -- 청산 가격
    
    -- 마진 정보 (ISOLATED만 지원)
    margin              NUMERIC(30, 8) NOT NULL,                -- 사용 증거금
    margin_type         VARCHAR(10) NOT NULL DEFAULT 'ISOLATED' CHECK (margin_type = 'ISOLATED'),
    
    -- 손익 정보
    unrealized_pnl      NUMERIC(30, 8) NOT NULL DEFAULT 0,      -- 미실현 손익
    roe_percent         NUMERIC(10, 4) NOT NULL DEFAULT 0,      -- 수익률 (%)
    
    -- Stop Loss / Take Profit
    stop_loss           NUMERIC(20, 7),                         -- 손절가
    take_profit         NUMERIC(20, 7),                         -- 익절가
    
    -- 상태
    status              VARCHAR(20) NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'CLOSED', 'LIQUIDATED')),
    
    -- 펀딩 비용 누적
    accumulated_funding NUMERIC(30, 8) NOT NULL DEFAULT 0,      -- 누적 펀딩 비용
    
    -- 메타 정보
    opened_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    closed_at           TIMESTAMPTZ,
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT positive_quantity CHECK (quantity > 0),
    CONSTRAINT valid_leverage CHECK (leverage >= 1 AND leverage <= 125),
    CONSTRAINT positive_margin CHECK (margin > 0),
    -- 바이낸스 방식: 같은 계좌에서 같은 종목, 같은 방향은 하나의 포지션만
    CONSTRAINT unique_position_per_account UNIQUE (account_id, symbol, position_side, status)
);

CREATE INDEX IF NOT EXISTS idx_futures_positions_account ON futures.positions(account_id);
CREATE INDEX IF NOT EXISTS idx_futures_positions_user ON futures.positions(google_id);
CREATE INDEX IF NOT EXISTS idx_futures_positions_symbol ON futures.positions(symbol);
CREATE INDEX IF NOT EXISTS idx_futures_positions_status ON futures.positions(status);
CREATE INDEX IF NOT EXISTS idx_futures_positions_account_status ON futures.positions(account_id, status);

-- 포지션 업데이트 트리거
CREATE OR REPLACE FUNCTION futures.touch_position_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := NOW();
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_futures_positions_touch ON futures.positions;
CREATE TRIGGER trg_futures_positions_touch
BEFORE UPDATE ON futures.positions
FOR EACH ROW EXECUTE FUNCTION futures.touch_position_updated_at();


-- =====================================
-- 4. 주문 테이블
-- =====================================
-- 모든 주문 내역 관리 (지정가, 시장가, 조건부 주문)
CREATE TABLE IF NOT EXISTS futures.orders (
    id                  BIGSERIAL PRIMARY KEY,
    account_id          BIGINT NOT NULL REFERENCES futures.accounts(id) ON DELETE CASCADE,  -- 서브 계좌 ID
    google_id           VARCHAR(256) NOT NULL REFERENCES users.accounts(google_id) ON DELETE CASCADE,  -- 사용자 ID (참조용)
    symbol              VARCHAR(30) NOT NULL REFERENCES metadata.crypto_info(symbol) ON DELETE CASCADE,
    position_id         BIGINT REFERENCES futures.positions(id) ON DELETE SET NULL,
    
    -- 주문 기본 정보
    order_type          VARCHAR(20) NOT NULL CHECK (order_type IN ('MARKET', 'LIMIT', 'STOP_MARKET', 'STOP_LIMIT', 'TAKE_PROFIT_MARKET', 'TAKE_PROFIT_LIMIT')),
    position_side       VARCHAR(10) NOT NULL CHECK (position_side IN ('LONG', 'SHORT')),
    side                VARCHAR(10) NOT NULL CHECK (side IN ('BUY', 'SELL')),  -- 실제 주문 방향
    
    -- 수량 및 가격
    quantity            NUMERIC(30, 8) NOT NULL,                -- 주문 수량
    executed_quantity   NUMERIC(30, 8) NOT NULL DEFAULT 0,      -- 체결된 수량
    price               NUMERIC(20, 7),                         -- 주문 가격 (시장가는 NULL)
    avg_price           NUMERIC(20, 7),                         -- 평균 체결가
    
    -- 조건부 주문 (Stop/TP)
    stop_price          NUMERIC(20, 7),                         -- 스탑 가격 (트리거 가격)
    
    -- 레버리지
    leverage            INTEGER NOT NULL DEFAULT 1,
    
    -- 주문 상태
    status              VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'PARTIALLY_FILLED', 'FILLED', 'CANCELLED', 'REJECTED', 'EXPIRED')),
    
    -- Time In Force (GTC 고정)
    time_in_force       VARCHAR(10) NOT NULL DEFAULT 'GTC' CHECK (time_in_force = 'GTC'),  -- Good Till Cancel 만 지원
    
    -- 포지션 감소 전용 (Close Only)
    reduce_only         BOOLEAN NOT NULL DEFAULT FALSE,
    
    -- 주문 목적 및 처리 방식
    order_purpose       VARCHAR(20) DEFAULT 'USER_ORDER' 
                        CHECK (order_purpose IN ('USER_ORDER', 'STOP_LOSS', 'TAKE_PROFIT', 'LIQUIDATION', 'AUTO_DELEVERAGE')),
    max_slippage_pct    NUMERIC(5, 2),                          -- 최대 허용 슬리피지 (%) - 시장가 주문용
    actual_slippage_pct NUMERIC(10, 4),                         -- 실제 발생한 슬리피지 (%) - 체결 후 기록
    
    -- 수수료
    commission          NUMERIC(30, 8) NOT NULL DEFAULT 0,      -- 거래 수수료
    
    -- 메타 정보
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    filled_at           TIMESTAMPTZ,
    trigger_time        TIMESTAMPTZ,                            -- 조건부 주문 트리거 시간
    
    CONSTRAINT positive_quantity CHECK (quantity > 0),
    CONSTRAINT positive_executed_quantity CHECK (executed_quantity >= 0),
    CONSTRAINT executed_lte_quantity CHECK (executed_quantity <= quantity)
);

CREATE INDEX IF NOT EXISTS idx_futures_orders_account ON futures.orders(account_id);
CREATE INDEX IF NOT EXISTS idx_futures_orders_user ON futures.orders(google_id);
CREATE INDEX IF NOT EXISTS idx_futures_orders_symbol ON futures.orders(symbol);
CREATE INDEX IF NOT EXISTS idx_futures_orders_status ON futures.orders(status);
CREATE INDEX IF NOT EXISTS idx_futures_orders_position ON futures.orders(position_id);
CREATE INDEX IF NOT EXISTS idx_futures_orders_created_at ON futures.orders(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_futures_orders_purpose ON futures.orders(order_purpose);  -- 주문 목적별 조회

-- 주문 업데이트 트리거
CREATE OR REPLACE FUNCTION futures.touch_order_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := NOW();
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_futures_orders_touch ON futures.orders;
CREATE TRIGGER trg_futures_orders_touch
BEFORE UPDATE ON futures.orders
FOR EACH ROW EXECUTE FUNCTION futures.touch_order_updated_at();


-- =====================================
-- 5. 거래 내역 테이블 (Trades)
-- =====================================
-- 실제 체결된 거래 내역 (주문의 부분 체결 포함)
CREATE TABLE IF NOT EXISTS futures.trades (
    id                  BIGSERIAL PRIMARY KEY,
    order_id            BIGINT NOT NULL REFERENCES futures.orders(id) ON DELETE CASCADE,
    account_id          BIGINT NOT NULL REFERENCES futures.accounts(id) ON DELETE CASCADE,  -- 서브 계좌 ID
    google_id           VARCHAR(256) NOT NULL REFERENCES users.accounts(google_id) ON DELETE CASCADE,  -- 사용자 ID (참조용)
    symbol              VARCHAR(30) NOT NULL REFERENCES metadata.crypto_info(symbol) ON DELETE CASCADE,
    position_id         BIGINT REFERENCES futures.positions(id) ON DELETE SET NULL,
    
    -- 거래 정보
    side                VARCHAR(10) NOT NULL CHECK (side IN ('BUY', 'SELL')),
    quantity            NUMERIC(30, 8) NOT NULL,                -- 체결 수량
    price               NUMERIC(20, 7) NOT NULL,                -- 체결 가격
    
    -- 손익 (포지션 청산 시)
    realized_pnl        NUMERIC(30, 8),                         -- 실현 손익
    commission          NUMERIC(30, 8) NOT NULL DEFAULT 0,      -- 수수료
    
    -- 거래 시간
    traded_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT positive_quantity CHECK (quantity > 0),
    CONSTRAINT positive_price CHECK (price > 0)
);

CREATE INDEX IF NOT EXISTS idx_futures_trades_user ON futures.trades(google_id);
CREATE INDEX IF NOT EXISTS idx_futures_trades_order ON futures.trades(order_id);
CREATE INDEX IF NOT EXISTS idx_futures_trades_position ON futures.trades(position_id);
CREATE INDEX IF NOT EXISTS idx_futures_trades_symbol ON futures.trades(symbol);
CREATE INDEX IF NOT EXISTS idx_futures_trades_traded_at ON futures.trades(traded_at DESC);


-- =====================================
-- 6. 포지션 히스토리 테이블
-- =====================================
-- 종료된 포지션의 전체 내역 (분석용)
CREATE TABLE IF NOT EXISTS futures.position_history (
    id                  BIGINT PRIMARY KEY,                     -- positions 테이블의 id 복사
    google_id           VARCHAR(256) NOT NULL REFERENCES users.accounts(google_id) ON DELETE CASCADE,
    symbol              VARCHAR(30) NOT NULL REFERENCES metadata.crypto_info(symbol) ON DELETE CASCADE,
    
    -- 포지션 정보
    position_side       VARCHAR(10) NOT NULL,
    quantity            NUMERIC(30, 8) NOT NULL,
    leverage            INTEGER NOT NULL,
    
    -- 가격 정보
    entry_price         NUMERIC(20, 7) NOT NULL,
    exit_price          NUMERIC(20, 7),                         -- 종료 가격
    liquidation_price   NUMERIC(20, 7),
    
    -- 마진 정보
    margin              NUMERIC(30, 8) NOT NULL,
    margin_type         VARCHAR(10) NOT NULL,
    
    -- 손익 정보
    realized_pnl        NUMERIC(30, 8) NOT NULL,                -- 실현 손익
    roe_percent         NUMERIC(10, 4) NOT NULL,                -- 최종 수익률
    
    -- 종료 사유
    close_reason        VARCHAR(20) NOT NULL CHECK (close_reason IN ('MANUAL', 'STOP_LOSS', 'TAKE_PROFIT', 'LIQUIDATED')),
    
    -- 펀딩 비용
    accumulated_funding NUMERIC(30, 8) NOT NULL DEFAULT 0,
    
    -- 시간 정보
    opened_at           TIMESTAMPTZ NOT NULL,
    closed_at           TIMESTAMPTZ NOT NULL,
    
    -- 거래 통계
    total_trades        INTEGER NOT NULL DEFAULT 0,             -- 해당 포지션의 총 거래 횟수
    total_commission    NUMERIC(30, 8) NOT NULL DEFAULT 0       -- 총 수수료
);

CREATE INDEX IF NOT EXISTS idx_futures_position_history_user ON futures.position_history(google_id);
CREATE INDEX IF NOT EXISTS idx_futures_position_history_symbol ON futures.position_history(symbol);
CREATE INDEX IF NOT EXISTS idx_futures_position_history_closed_at ON futures.position_history(closed_at DESC);


-- =====================================
-- 7. 펀딩 비율 히스토리 테이블
-- =====================================
-- 각 심볼의 펀딩 비율 기록 (8시간마다 발생)
CREATE TABLE IF NOT EXISTS futures.funding_rate_history (
    symbol              VARCHAR(30) NOT NULL REFERENCES metadata.crypto_info(symbol) ON DELETE CASCADE,
    funding_time        TIMESTAMPTZ NOT NULL,
    funding_rate        NUMERIC(10, 8) NOT NULL,                -- 펀딩 비율 (0.01% = 0.0001)
    
    PRIMARY KEY (symbol, funding_time)
);

CREATE INDEX IF NOT EXISTS idx_funding_rate_symbol ON futures.funding_rate_history(symbol);
CREATE INDEX IF NOT EXISTS idx_funding_rate_time ON futures.funding_rate_history(funding_time DESC);


-- =====================================
-- 8. 청산 이벤트 테이블
-- =====================================
-- 청산 발생 시 상세 기록
CREATE TABLE IF NOT EXISTS futures.liquidation_events (
    id                  BIGSERIAL PRIMARY KEY,
    position_id         BIGINT NOT NULL,                        -- 청산된 포지션 ID (히스토리 참조)
    google_id           VARCHAR(256) NOT NULL REFERENCES users.accounts(google_id) ON DELETE CASCADE,
    symbol              VARCHAR(30) NOT NULL REFERENCES metadata.crypto_info(symbol) ON DELETE CASCADE,
    
    -- 청산 정보
    position_side       VARCHAR(10) NOT NULL,
    quantity            NUMERIC(30, 8) NOT NULL,
    entry_price         NUMERIC(20, 7) NOT NULL,
    liquidation_price   NUMERIC(20, 7) NOT NULL,
    mark_price          NUMERIC(20, 7) NOT NULL,                -- 청산 시점의 마크 가격
    
    -- 손실 정보
    loss_amount         NUMERIC(30, 8) NOT NULL,                -- 청산으로 인한 손실
    liquidation_fee     NUMERIC(30, 8) NOT NULL,                -- 청산 수수료
    
    -- 시간
    liquidated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT positive_loss CHECK (loss_amount >= 0)
);

CREATE INDEX IF NOT EXISTS idx_liquidation_events_user ON futures.liquidation_events(google_id);
CREATE INDEX IF NOT EXISTS idx_liquidation_events_symbol ON futures.liquidation_events(symbol);
CREATE INDEX IF NOT EXISTS idx_liquidation_events_time ON futures.liquidation_events(liquidated_at DESC);


-- =====================================
-- 9. 입출금 내역 테이블
-- =====================================
-- 선물 계좌 입출금 기록
CREATE TABLE IF NOT EXISTS futures.transactions (
    id                  BIGSERIAL PRIMARY KEY,
    google_id           VARCHAR(256) NOT NULL REFERENCES users.accounts(google_id) ON DELETE CASCADE,
    
    -- 거래 정보
    transaction_type    VARCHAR(20) NOT NULL CHECK (transaction_type IN ('DEPOSIT', 'WITHDRAWAL', 'REALIZED_PNL', 'COMMISSION', 'FUNDING')),
    amount              NUMERIC(30, 8) NOT NULL,                -- 금액 (양수: 입금, 음수: 출금)
    
    -- 잔고 정보 (거래 후)
    balance_after       NUMERIC(30, 8) NOT NULL,
    
    -- 관련 정보
    related_order_id    BIGINT REFERENCES futures.orders(id) ON DELETE SET NULL,
    related_position_id BIGINT REFERENCES futures.positions(id) ON DELETE SET NULL,
    
    -- 메모
    note                TEXT,
    
    -- 시간
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_futures_transactions_user ON futures.transactions(google_id);
CREATE INDEX IF NOT EXISTS idx_futures_transactions_type ON futures.transactions(transaction_type);
CREATE INDEX IF NOT EXISTS idx_futures_transactions_created_at ON futures.transactions(created_at DESC);


-- =====================================
-- 10. 레버리지 설정 테이블
-- =====================================
-- 사용자별 심볼별 레버리지 설정
CREATE TABLE IF NOT EXISTS futures.leverage_settings (
    google_id           VARCHAR(256) NOT NULL REFERENCES users.accounts(google_id) ON DELETE CASCADE,
    symbol              VARCHAR(30) NOT NULL REFERENCES metadata.crypto_info(symbol) ON DELETE CASCADE,
    leverage            INTEGER NOT NULL DEFAULT 1,
    margin_type         VARCHAR(10) NOT NULL DEFAULT 'ISOLATED' CHECK (margin_type IN ('ISOLATED', 'CROSS')),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    PRIMARY KEY (google_id, symbol),
    CONSTRAINT valid_leverage CHECK (leverage >= 1 AND leverage <= 125)
);

CREATE INDEX IF NOT EXISTS idx_futures_leverage_user ON futures.leverage_settings(google_id);


-- =====================================
-- 11. 마진 호출 경고 테이블
-- =====================================
-- 마진 비율이 위험 수준에 도달했을 때 경고 기록
CREATE TABLE IF NOT EXISTS futures.margin_calls (
    id                  BIGSERIAL PRIMARY KEY,
    position_id         BIGINT NOT NULL REFERENCES futures.positions(id) ON DELETE CASCADE,
    google_id           VARCHAR(256) NOT NULL REFERENCES users.accounts(google_id) ON DELETE CASCADE,
    symbol              VARCHAR(30) NOT NULL REFERENCES metadata.crypto_info(symbol) ON DELETE CASCADE,
    
    -- 경고 정보
    margin_ratio        NUMERIC(10, 4) NOT NULL,                -- 현재 마진 비율 (%)
    mark_price          NUMERIC(20, 7) NOT NULL,
    liquidation_price   NUMERIC(20, 7) NOT NULL,
    
    -- 상태
    is_resolved         BOOLEAN NOT NULL DEFAULT FALSE,         -- 해소 여부
    
    -- 시간
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at         TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_margin_calls_position ON futures.margin_calls(position_id);
CREATE INDEX IF NOT EXISTS idx_margin_calls_user ON futures.margin_calls(google_id);
CREATE INDEX IF NOT EXISTS idx_margin_calls_resolved ON futures.margin_calls(is_resolved);


-- =====================================
-- 12. 레버리지 브래킷 테이블 (Binance Tiered Leverage)
-- =====================================
-- 각 심볼의 레버리지별 최대 포지션 제한 정보
-- Binance API: GET /fapi/v1/leverageBracket
CREATE TABLE IF NOT EXISTS futures.leverage_brackets (
    symbol              VARCHAR(30) NOT NULL REFERENCES metadata.crypto_info(symbol) ON DELETE CASCADE,
    bracket_id          INTEGER NOT NULL,                       -- 브래킷 레벨 (1, 2, 3...)
    
    initial_leverage    INTEGER NOT NULL,                       -- 해당 구간의 최대 허용 레버리지 (예: 125)
    max_notional        NUMERIC(30, 8) NOT NULL,                -- 해당 구간의 최대 포지션 금액 (USDT)
    min_notional        NUMERIC(30, 8) NOT NULL DEFAULT 0,      -- 해당 구간의 최소 포지션 금액
    
    maint_margin_rate   NUMERIC(10, 5) NOT NULL,                -- 유지 증거금 비율 (예: 0.004 = 0.4%)
    cum_fast_maint_amount NUMERIC(30, 8) NOT NULL DEFAULT 0,    -- 빠른 유지 증거금 계산을 위한 누적액 (cum)
    
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    PRIMARY KEY (symbol, bracket_id),
    CONSTRAINT valid_leverage_bracket CHECK (initial_leverage >= 1)
);

CREATE INDEX IF NOT EXISTS idx_leverage_brackets_symbol ON futures.leverage_brackets(symbol);


-- =====================================
-- 13. 심볼별 통계 테이블 (선택 사항)
-- =====================================
-- 각 심볼의 24시간 통계 정보 캐시 (바이낸스 UI의 통계 표시용)
CREATE TABLE IF NOT EXISTS futures.symbol_stats_24h (
    symbol              VARCHAR(30) PRIMARY KEY REFERENCES metadata.crypto_info(symbol) ON DELETE CASCADE,
    
    -- 가격 정보
    last_price          NUMERIC(20, 7) NOT NULL,
    mark_price          NUMERIC(20, 7) NOT NULL,
    index_price         NUMERIC(20, 7) NOT NULL,
    
    -- 24시간 변동
    price_change_24h    NUMERIC(20, 7) NOT NULL,
    price_change_pct_24h NUMERIC(10, 4) NOT NULL,
    
    -- 거래량
    volume_24h          NUMERIC(30, 8) NOT NULL,
    quote_volume_24h    NUMERIC(30, 8) NOT NULL,               -- USDT 기준 거래량
    
    -- 고가/저가
    high_price_24h      NUMERIC(20, 7) NOT NULL,
    low_price_24h       NUMERIC(20, 7) NOT NULL,
    
    -- 펀딩
    funding_rate        NUMERIC(10, 8) NOT NULL,
    next_funding_time   TIMESTAMPTZ NOT NULL,
    
    -- Open Interest
    open_interest       NUMERIC(30, 8) NOT NULL DEFAULT 0,      -- 미결제 약정
    
    -- 업데이트 시간
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_symbol_stats_updated ON futures.symbol_stats_24h(updated_at);


-- =====================================
-- 초기 데이터 및 헬퍼 뷰
-- =====================================

-- 사용자의 현재 포지션 요약 뷰
CREATE OR REPLACE VIEW futures.user_positions_summary AS
SELECT
    p.google_id,
    p.symbol,
    p.position_side,
    p.quantity,
    p.leverage,
    p.entry_price,
    p.mark_price,
    p.liquidation_price,
    p.unrealized_pnl,
    p.roe_percent,
    p.margin,
    p.margin_type,
    p.stop_loss,
    p.take_profit,
    p.accumulated_funding,
    p.opened_at,
    p.updated_at
FROM futures.positions p
WHERE p.status = 'OPEN';

-- 사용자의 미체결 주문 뷰
CREATE OR REPLACE VIEW futures.user_open_orders AS
SELECT
    o.id,
    o.google_id,
    o.symbol,
    o.order_type,
    o.position_side,
    o.side,
    o.quantity,
    o.executed_quantity,
    o.quantity - o.executed_quantity AS remaining_quantity,
    o.price,
    o.avg_price,
    o.stop_price,
    o.leverage,
    o.status,
    o.time_in_force,
    o.reduce_only,
    o.created_at
FROM futures.orders o
WHERE o.status IN ('PENDING', 'PARTIALLY_FILLED');

-- 사용자 계좌 전체 요약 뷰
CREATE OR REPLACE VIEW futures.user_account_summary AS
SELECT
    a.google_id,
    a.total_balance,
    a.available_balance,
    a.margin_balance,
    a.unrealized_pnl,
    a.total_balance + a.unrealized_pnl AS total_equity,
    CASE
        WHEN a.total_balance > 0 THEN
            (a.margin_balance / a.total_balance) * 100
        ELSE 0
    END AS margin_ratio_percent,
    a.total_trades,
    a.winning_trades,
    CASE
        WHEN a.total_trades > 0 THEN
            (a.winning_trades::NUMERIC / a.total_trades * 100)
        ELSE 0
    END AS win_rate_percent,
    a.total_pnl
FROM futures.accounts a;

COMMENT ON SCHEMA futures IS '선물 거래 스키마: 사용자별 선물 거래 계좌, 포지션, 주문, 거래 내역 관리';
COMMENT ON TABLE futures.symbol_trading_rules IS '종목별 거래 조건 (주문 수량, 가격, 레버리지, 수수료 등)';
COMMENT ON TABLE futures.orderbook IS '실시간 오더북 (매수/매도 호가)';
COMMENT ON TABLE futures.market_trades IS '실시간 거래소 체결 내역 (최근 거래)';
COMMENT ON TABLE futures.market_ticker IS '실시간 현재가 및 시장 정보 캐시';
COMMENT ON TABLE futures.accounts IS '사용자별 선물 거래 계좌 정보';
COMMENT ON TABLE futures.positions IS '사용자의 열린 포지션 (롱/숏)';
COMMENT ON TABLE futures.orders IS '모든 주문 내역 (지정가, 시장가, 조건부)';
COMMENT ON TABLE futures.trades IS '실제 체결된 거래 내역';
COMMENT ON TABLE futures.position_history IS '종료된 포지션의 전체 내역';
COMMENT ON TABLE futures.funding_rate_history IS '펀딩 비율 히스토리';
COMMENT ON TABLE futures.liquidation_events IS '청산 이벤트 로그';
COMMENT ON TABLE futures.transactions IS '계좌 입출금 내역';
COMMENT ON TABLE futures.leverage_settings IS '사용자별 심볼별 레버리지 설정';
COMMENT ON TABLE futures.margin_calls IS '마진 호출 경고 내역';
COMMENT ON TABLE futures.symbol_stats_24h IS '심볼별 24시간 통계 (캐시)';
