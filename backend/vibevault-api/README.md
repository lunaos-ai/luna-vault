# Vibe Vault Cloud API

Cloudflare Worker backend for Vibe Vault providing authentication, cloud backups, and in-app purchase verification.

## Features

- **User Authentication**: JWT-based auth with registration, login, and session management
- **Encrypted Cloud Backups**: AES-GCM encrypted secret backups to D1
- **Scheduled Backups**: Automated daily/weekly/monthly backup scheduling
- **In-App Purchase Verification**: App Store receipt validation
- **Audit Logging**: Track all cloud operations per user

## Setup

### 1. Create D1 Database

```bash
cd backend/vibevault-api
wrangler d1 create vibevault-db
```

Update `wrangler.toml` with the database ID.

### 2. Apply Database Schema

```bash
wrangler d1 execute vibevault-db --file=./schema.sql
```

### 3. Set Secrets

```bash
wrangler secret put JWT_SECRET
# Generate a secure random string

wrangler secret put ENCRYPTION_KEY
# 32-character key for backup encryption
```

### 4. Deploy

```bash
npm install
wrangler deploy
```

## API Endpoints

### Authentication
- `POST /api/auth/register` - Create new account
- `POST /api/auth/login` - Sign in
- `POST /api/auth/verify` - Verify JWT token
- `POST /api/auth/refresh` - Refresh access token
- `POST /api/auth/logout` - Sign out

### Backups
- `POST /api/backup/create` - Create encrypted backup
- `GET /api/backup/list` - List user's backups
- `GET /api/backup/:id` - Get specific backup
- `POST /api/backup/:id/restore` - Restore backup
- `DELETE /api/backup/:id` - Delete backup

### Backup Scheduling
- `GET /api/backup/schedule` - Get schedule settings
- `POST /api/backup/schedule` - Set schedule
- `POST /api/backup/schedule/enable` - Enable scheduled backups
- `POST /api/backup/schedule/disable` - Disable scheduled backups

### Subscription
- `GET /api/subscription/status` - Get subscription status
- `POST /api/subscription/verify-receipt` - Verify App Store receipt
- `POST /api/subscription/cancel` - Cancel subscription

## Architecture

```
┌─────────────┐      ┌─────────────────┐      ┌──────────┐
│  Vibe Vault │──────▶  Cloudflare     │──────▶   D1     │
│     App     │      │    Worker       │      │ Database │
└─────────────┘      └─────────────────┘      └──────────┘
                            │
                            ▼
                     ┌──────────────┐
                     │  App Store   │
                     │   Server     │
                     └──────────────┘
```

## Security

- All backups encrypted with AES-GCM before storage
- JWT tokens for authentication (expires after 24 hours)
- PBKDF2 password hashing with 100k iterations
- HTTPS-only API
- Audit logging of all operations

## Scheduled Backups

Configure a cron trigger in Cloudflare Dashboard:

```
0 * * * *  # Run every hour to check for due backups
```

## Environment Variables

| Variable | Description |
|----------|-------------|
| `JWT_SECRET` | Secret for signing JWT tokens |
| `ENCRYPTION_KEY` | Master key for backup encryption |

## Development

```bash
# Local development
wrangler dev

# Test API
curl http://localhost:8787/api/health
```

## License

MIT
