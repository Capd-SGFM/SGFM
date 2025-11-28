import { FC, useEffect, useState } from 'react'

interface CurrentPriceProps {
  currentPrice: number;
  previousPrice: number;
}

const CurrentPrice: FC<CurrentPriceProps> = ({ currentPrice, previousPrice }) => {
  const [priceClass, setPriceClass] = useState<string>('');

  useEffect(() => {
    if (previousPrice > 0 && currentPrice !== previousPrice) {
      setPriceClass(currentPrice > previousPrice ? 'price-up' : 'price-down');
      
      const timer = setTimeout(() => {
        setPriceClass('');
      }, 500);

      return () => clearTimeout(timer);
    }
  }, [currentPrice, previousPrice]);

  const formatPrice = (price: number): string => {
    if (price === 0) return '--';
    return price.toLocaleString('en-US', {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    });
  };

  return (
    <div className="current-price">
      <div className={`price-value ${priceClass}`}>
        {formatPrice(currentPrice)}
      </div>
      <div className="price-usdt">≈ ${formatPrice(currentPrice)}</div>
    </div>
  )
}

export default CurrentPrice
