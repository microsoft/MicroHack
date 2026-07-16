// Add runtime config type definition
declare global {
  interface Window {
    RUNTIME_CONFIG?: {
      API_URL: string;
    };
  }
}

const getBaseUrl = () => {
  // First check runtime configuration (from runtime-config.js)
  if (typeof window !== 'undefined' && window.RUNTIME_CONFIG?.API_URL) {
    console.log('Using runtime config API_URL:', window.RUNTIME_CONFIG.API_URL);
    return window.RUNTIME_CONFIG.API_URL;
  }

  // During local dev, make targets set VITE_API_URL to the chosen backend port.
  const viteApiUrl = import.meta.env.VITE_API_URL;
  if (viteApiUrl) {
    console.log(`Using Vite API URL: ${viteApiUrl}`);
    return viteApiUrl;
  }

  const protocol = typeof window !== 'undefined' ? window.location.protocol : 'https:';
  const protocolToUse = protocol.includes('https') ? 'https' : 'http';
  const url = `${protocolToUse}://localhost:3000`;
  console.log(`Using default URL: ${url}`);
  return url;
};

export const API_BASE_URL = getBaseUrl();

export const api = {
  baseURL: API_BASE_URL,
  endpoints: {
    products: '/api/products',
    suppliers: '/api/suppliers',
    orders: '/api/orders',
    branches: '/api/branches',
    headquarters: '/api/headquarters',
    deliveries: '/api/deliveries',
    orderDetails: '/api/order-details',
    orderDetailDeliveries: '/api/order-detail-deliveries',
  },
};
