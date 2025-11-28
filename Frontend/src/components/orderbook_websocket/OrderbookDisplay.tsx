import { FC, useMemo, useState, useEffect } from 'react'
import OrderRow from './OrderRow.tsx'
import CurrentPrice from './CurrentPrice.tsx'

interface OrderbookLevel {
  price: string;
  quantity: string;
}

interface OrderbookData {
  lastUpdateId: number;
  bids: OrderbookLevel[];
  asks: OrderbookLevel[];
}

interface OrderbookDisplayProps {
  orderbook: OrderbookData | null;
}

const OrderbookDisplay: FC<OrderbookDisplayProps> = ({ orderbook }) => {
  const [currentPrice, setCurrentPrice] = useState<number>(0);
  const [previousPrice, setPreviousPrice] = useState<number>(0);

  useEffect(() => {
    if (orderbook && orderbook.bids.length > 0) {
      const newPrice = parseFloat(orderbook.bids[0].price);
      setPreviousPrice(currentPrice);
      setCurrentPrice(newPrice);
    }
  }, [orderbook]);

  const { displayAsks, displayBids, maxBidTotal, maxAskTotal } = useMemo(() => {
    if (!orderbook) {
      return {
        displayAsks: [],
        displayBids: [],
        maxBidTotal: 0,
        maxAskTotal: 0
      };
    }

    const calculateMaxTotal = (orders: OrderbookLevel[]): number => {
      let maxTotal = 0;
      let runningTotal = 0;
      
      for (const order of orders) {
        runningTotal += parseFloat(order.quantity);
        maxTotal = Math.max(maxTotal, runningTotal);
      }
      
      return maxTotal;
    };

    const maxBidTotal = calculateMaxTotal(orderbook.bids);
    const maxAskTotal = calculateMaxTotal(orderbook.asks);

    const displayBids = orderbook.bids.slice(0, 10);
    const displayAsks = [...orderbook.asks].reverse().slice(0, 10);

    return { displayAsks, displayBids, maxBidTotal, maxAskTotal };
  }, [orderbook]);

  return (
    <div className="orderbook-container">
      <div className="orderbook-section">
        <div className="section-header">
          <div className="header-cell">Price (USDT)</div>
          <div className="header-cell">Amount (BTC)</div>
          <div className="header-cell">Total (USDT)</div>
        </div>
        <div className="orderbook-asks">
          {displayAsks.length > 0 ? (
            displayAsks.map((order, index) => (
              <OrderRow
                key={`ask-${index}`}
                order={order}
                type="ask"
                index={index}
                maxTotal={maxAskTotal}
                orders={displayAsks}
              />
            ))
          ) : (
            <div className="loading-message">Waiting for data...</div>
          )}
        </div>
      </div>

      <CurrentPrice 
        currentPrice={currentPrice} 
        previousPrice={previousPrice}
      />

      <div className="orderbook-section">
        <div className="orderbook-bids">
          {displayBids.length > 0 ? (
            displayBids.map((order, index) => (
              <OrderRow
                key={`bid-${index}`}
                order={order}
                type="bid"
                index={index}
                maxTotal={maxBidTotal}
                orders={displayBids}
              />
            ))
          ) : (
            <div className="loading-message">Waiting for data...</div>
          )}
        </div>
      </div>
    </div>
  )
}

export default OrderbookDisplay
