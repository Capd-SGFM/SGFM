import { FC } from 'react'

interface FooterProps {
  lastUpdate: string;
}

const Footer: FC<FooterProps> = ({ lastUpdate }) => {
  return (
    <footer>
      <p>Real-time data from Binance WebSocket API</p>
      <p className="update-time">Last update: <span>{lastUpdate}</span></p>
    </footer>
  )
}

export default Footer
