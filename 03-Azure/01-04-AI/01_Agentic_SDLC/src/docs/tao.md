# TypeScript API Observability Framework (TAO)

TAO is our lightweight, powerful observability framework designed specifically for TypeScript-based APIs. It provides seamless integration of metrics, traces, and logs with minimal configuration.

## Features

- 🔄 Auto-instrumentation for Express.js routes
- 📊 Built-in metrics collection (response times, error rates, request counts)
- 🔍 Distributed tracing with OpenTelemetry compatibility
- 📝 Structured logging with context correlation
- 🎯 Custom metric decorators
- 🔌 Pluggable backend support (Prometheus, Jaeger, ELK)

## Quick Start

```typescript
import { initTAO, observe } from '@tao/core';
import express from 'express';

// Initialize TAO with default settings
initTAO({
  serviceName: 'my-api',
  environment: 'production'
});

const app = express();

// Automatically instrument all routes
app.use(observe());
```

## Decorators

TAO provides decorators for fine-grained observability:

```typescript
import { Measure, Trace, Log } from '@tao/core';

class UserService {
  @Measure('user.creation.time')
  @Trace('user-creation')
  @Log('debug')
  async createUser(userData: UserData): Promise<User> {
    // Your implementation
  }
}
```

## Custom Metrics

```typescript
import { MetricRegistry } from '@tao/core';

// Create a custom counter
const requestCounter = MetricRegistry.counter({
  name: 'api_requests_total',
  labels: ['endpoint', 'status']
});

// Increment the counter
requestCounter.inc({ endpoint: '/api/users', status: '200' });
```

## Trace Context

TAO automatically propagates trace context across service boundaries using W3C Trace Context headers:

```typescript
import { getTraceContext, withContext } from '@tao/core';

async function makeDownstreamCall() {
  const context = getTraceContext();
  
  return await fetch('http://other-service/api', {
    headers: withContext(context)
  });
}
```

## Configuration

```typescript
initTAO({
  serviceName: 'my-api',
  environment: 'production',
  metrics: {
    backend: 'prometheus',
    endpoint: '/metrics'
  },
  tracing: {
    backend: 'jaeger',
    samplingRate: 0.1
  },
  logging: {
    level: 'info',
    format: 'json'
  }
});
```

## Best Practices

1. **Use Meaningful Names**: Choose descriptive names for metrics and traces
2. **Add Labels**: Include relevant labels for better filtering and aggregation
3. **Sample Wisely**: Configure appropriate sampling rates for high-traffic services
4. **Correlate Data**: Use trace IDs in logs for better debugging
5. **Monitor Resource Usage**: Enable built-in resource metrics collection