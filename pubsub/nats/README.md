# NATS Authentication Setup Guide

## Overview
This guide shows you how to set up secure authentication and authorization for NATS.

## Authentication Methods

### 1. **User/Password Authentication** (Current Setup)
- Uses bcrypt-hashed passwords
- Account-based permissions
- Subject-level authorization

### 2. **Token-based Authentication** (Alternative)
- JWT tokens
- More scalable for microservices
- Decentralized management

### 3. **TLS Client Certificates** (Enterprise)
- Certificate-based authentication
- Highest security level
- Complex setup

## Setup Steps

### Step 1: Generate Password Hashes

Run the provided script to generate bcrypt hashes:

```bash
./pubsub/nats/generate-auth.sh
```

Or manually using NATS CLI:
```bash
# Install NATS CLI first
docker run --rm -i natsio/nats-box:latest nats server passwd "your-password"
```

### Step 2: Update Environment Variables

Copy the example file and update with your hashes:
```bash
cp .env.nats.example .env.nats
# Edit .env.nats with the generated hashes
```

Add to your main `.env` file:
```bash
cat .env.nats >> .env
```

### Step 3: Choose Configuration

**Option A: Static Configuration (current nats-server.conf)**
- Passwords hardcoded in config file
- Simpler setup
- Less flexible

**Option B: Environment-based Configuration**
- Use `nats-server-env.conf` instead
- Passwords from environment variables
- More secure and flexible

To use environment-based config, update docker-compose.yaml:
```yaml
volumes:
  - ./pubsub/nats/nats-server-env.conf:/etc/nats/nats-server.conf
```

## Account Structure

### $SYS Account (System)
- **Purpose**: Server administration and monitoring
- **Users**: admin
- **Permissions**: Full access to all subjects

### APP Account (Applications)
- **Purpose**: Regular application services
- **Users**: backend-service, web-service, analytics-service
- **Permissions**: Subject-based restrictions

## Subject Patterns & Permissions

### Backend Service
- **Publish**: `events.*`, `commands.*`, `requests.*`, `logs.*`
- **Subscribe**: `events.*`, `responses.*`, `notifications.*`, `commands.*`
- **Denied**: `system.*`, `admin.*`

### Web Service
- **Publish**: `requests.*`, `user.actions.*`, `notifications.*`
- **Subscribe**: `responses.*`, `notifications.user.*`, `events.user.*`
- **Denied**: `system.*`, `admin.*`, `commands.*`, `events.internal.*`

### Analytics Service
- **Publish**: `analytics.*`, `metrics.*`
- **Subscribe**: `events.*`, `user.*`, `logs.*`
- **Denied**: `system.*`, `admin.*`, `commands.*`

## Connection Examples

### Using Go
```go
import "github.com/nats-io/nats.go"

nc, err := nats.Connect("nats://localhost:4222", 
    nats.UserInfo("backend-service", "backend-service-password-2024"))
```

### Using Node.js
```javascript
import { connect } from 'nats';

const nc = await connect({
    servers: 'nats://localhost:4222',
    user: 'web-service',
    pass: 'web-service-password-2024'
});
```

### Using Python
```python
import asyncio
import nats

async def main():
    nc = await nats.connect("nats://localhost:4222",
                           user="analytics-service",
                           password="analytics-service-password-2024")
```

### Using NATS CLI
```bash
# Set credentials
export NATS_URL=nats://backend-service:backend-service-password-2024@localhost:4222

# Publish message
nats pub events.user.login '{"user_id": "123", "timestamp": "2024-01-01T00:00:00Z"}'

# Subscribe to events
nats sub "events.>"
```

## Security Best Practices

1. **Use Strong Passwords**: Minimum 20 characters with mixed case, numbers, symbols
2. **Regular Rotation**: Change passwords quarterly
3. **Principle of Least Privilege**: Grant minimal required permissions
4. **Monitor Access**: Use NATS monitoring to track connections
5. **Use TLS**: Enable TLS for production environments
6. **Secrets Management**: Store credentials in secure vaults (not .env files)

## Monitoring

Access NATS monitoring dashboard:
- URL: `http://localhost:8222`
- Shows active connections, subjects, and account usage

## Troubleshooting

### Common Issues

1. **Authentication Failed**
   - Verify username/password combination
   - Check bcrypt hash generation
   - Ensure correct account assignment

2. **Permission Denied**
   - Check subject patterns in permissions
   - Verify account-level access
   - Review allow/deny rules

3. **Connection Refused**
   - Check NATS server is running
   - Verify port accessibility
   - Check network configuration

### Debug Commands

```bash
# Check NATS server status
docker logs nats

# Test connection
nats --server=nats://admin:admin-password@localhost:4222 server info

# Monitor real-time
nats --server=nats://admin:admin-password@localhost:4222 server report conns
```

## Advanced Features

### JetStream (Persistent Messaging)
- Enabled by default in configuration
- Provides message persistence and replay
- Account-level stream permissions

### Clustering
- Configuration ready for multi-node setup
- Shared authentication across cluster
- High availability setup

### Metrics Integration
- Prometheus metrics endpoint: `http://localhost:8222/metrics`
- Integration with your existing observability stack
