import { FC, useMemo } from 'react'

interface OrderbookLevel {
  price: string;
  quantity: string;
}

interface OrderRowProps {
  order: OrderbookLevel;
  type: 'bid' | 'ask';
  index: number;
  maxTotal: number;
  orders: OrderbookLevel[];
}

const OrderRow: FC<OrderRowProps> = ({ order, type, index, maxTotal, orders }) => {
  const { price, quantity, total, depthPercentage } = useMemo(() => {
    const price = parseFloat(order.price);
    const quantity = parseFloat(order.quantity);
    const total = price * quantity;

    let cumulativeQty = 0;
    for (let i = 0; i <= index; i++) {
      cumulativeQty += parseFloat(orders[i].quantity);
    }
    const depthPercentage = maxTotal > 0 ? (cumulativeQty / maxTotal) * 100 : 0;

    return { price, quantity, total, depthPercentage };
  }, [order, index, maxTotal, orders]);

  const formatPrice = (value: number): string => {
    return value.toLocaleString('en-US', {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    });
  };

  const formatQuantity = (value: number): string => {
    return value.toLocaleString('en-US', {
      minimumFractionDigits: 3,
      maximumFractionDigits: 3
    });
  };

  const formatTotal = (value: number): string => {
    return value.toLocaleString('en-US', {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    });
  };

  return (
    <div 
      className={`order-row ${type}-row`}
      style={{ '--depth': `${depthPercentage}%` } as React.CSSProperties}
    >
      <div className="price">{formatPrice(price)}</div>
      <div className="amount">{formatQuantity(quantity)}</div>
      <div className="total">{formatTotal(total)}</div>
    </div>
  )
}

export default OrderRow
