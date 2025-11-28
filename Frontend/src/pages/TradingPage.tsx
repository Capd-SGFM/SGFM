import { useState, useEffect, useRef } from 'react'
import OrderbookDisplay from '../components/orderbook_websocket/OrderbookDisplay.tsx'
import Header from '../components/orderbook_websocket/Header.tsx'
import Footer from '../components/orderbook_websocket/Footer.tsx'
import '../style.css'

interface OrderbookLevel {
  price: string;
  quantity: string;
}

interface OrderbookData {
  lastUpdateId: number;
  bids: OrderbookLevel[];
  asks: OrderbookLevel[];
}

interface BinanceDepthMessage {
  e: string;
  E: number;
  s: string;
  U: number;
  u: number;
  pu?: number;
  b: [string, string][];
  a: [string, string][];
}

type ConnectionStatus = 'connecting' | 'connected' | 'disconnected';

function TradingPage() {
  const [orderbook, setOrderbook] = useState<OrderbookData | null>(null);
  const [status, setStatus] = useState<ConnectionStatus>('connecting');
  const [lastUpdate, setLastUpdate] = useState<string>('--');
  const wsRef = useRef<WebSocket | null>(null);
  const reconnectAttemptsRef = useRef(0);
  const maxReconnectAttempts = 5;
  const reconnectDelay = 3000;

  const connect = () => {
    try {
      const symbol = 'btcusdt';
      const wsUrl = `wss://fstream.binance.com/ws/${symbol}@depth20@100ms`;

      wsRef.current = new WebSocket(wsUrl);

      wsRef.current.onopen = () => {
        console.log('WebSocket connected');
        setStatus('connected');
        reconnectAttemptsRef.current = 0;
      };

      wsRef.current.onmessage = (event) => {
        try {
          const raw = JSON.parse(event.data) as BinanceDepthMessage;

          if (!raw.b || !raw.a) {
            console.warn('Unexpected depth message format', raw);
            return;
          }

          const bids: OrderbookLevel[] = raw.b.map(([price, quantity]) => ({
            price,
            quantity,
          }));

          const asks: OrderbookLevel[] = raw.a.map(([price, quantity]) => ({
            price,
            quantity,
          }));

          const normalized: OrderbookData = {
            lastUpdateId: raw.u,
            bids,
            asks,
          };

          setOrderbook(normalized);

          const now = new Date();
          setLastUpdate(now.toLocaleTimeString('ko-KR'));
        } catch (error) {
          console.error('Error parsing message:', error);
        }
      };

      wsRef.current.onerror = (error) => {
        console.error('WebSocket error:', error);
        setStatus('disconnected');
      };

      wsRef.current.onclose = () => {
        console.log('WebSocket disconnected');
        setStatus('disconnected');
        attemptReconnect();
      };
    } catch (error) {
      console.error('Failed to create WebSocket:', error);
      setStatus('disconnected');
      attemptReconnect();
    }
  };

  const attemptReconnect = () => {
    if (reconnectAttemptsRef.current >= maxReconnectAttempts) {
      console.log('Max reconnection attempts reached');
      setStatus('disconnected');
      return;
    }

    reconnectAttemptsRef.current++;
    setStatus('connecting');

    setTimeout(() => {
      console.log(`Reconnection attempt ${reconnectAttemptsRef.current}`);
      connect();
    }, reconnectDelay);
  };

  useEffect(() => {
    connect();

    return () => {
      if (wsRef.current) {
        wsRef.current.close();
        wsRef.current = null;
      }
    };
  }, []);

  return (
    <div className="trading-wrapper">
      <div className="container">
        <Header
          status={status}
          reconnectAttempt={reconnectAttemptsRef.current}
          maxAttempts={maxReconnectAttempts}
        />

        <main>
          <OrderbookDisplay orderbook={orderbook} />
        </main>

        <Footer lastUpdate={lastUpdate} />
      </div>
    </div>
  );
}

export default TradingPage;