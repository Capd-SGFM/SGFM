import { FC } from 'react'

type ConnectionStatus = 'connecting' | 'connected' | 'disconnected';

interface HeaderProps {
  status: ConnectionStatus;
  reconnectAttempt: number;
  maxAttempts: number;
}

const Header: FC<HeaderProps> = ({ status, reconnectAttempt, maxAttempts }) => {
  const getStatusText = () => {
    if (status === 'connected') return 'Connected';
    if (status === 'connecting' && reconnectAttempt > 0) {
      return `Reconnecting... (${reconnectAttempt}/${maxAttempts})`;
    }
    if (status === 'connecting') return 'Connecting...';
    if (reconnectAttempt >= maxAttempts) return 'Failed - Refresh page';
    return 'Disconnected';
  };

  return (
    <header>
      <div className="header-content">
        <h1>BTCUSDT Orderbook</h1>
        <div className="connection-status">
          <span className={`status-dot ${status}`}></span>
          <span className="status-text">{getStatusText()}</span>
        </div>
      </div>
    </header>
  )
}

export default Header
