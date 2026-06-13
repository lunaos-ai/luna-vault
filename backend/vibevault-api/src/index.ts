import { Router } from './router';
import { AuthHandler } from './auth';
import { BackupHandler } from './backup';
import { SubscriptionHandler } from './subscription';
import { corsHeaders, jsonResponse, errorResponse } from './utils';

export interface Env {
  DB: D1Database;
  JWT_SECRET: string;
  ENCRYPTION_KEY: string;
}

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    const router = new Router();
    const auth = new AuthHandler(env);
    const backup = new BackupHandler(env);
    const subscription = new SubscriptionHandler(env);

    // Auth routes
    router.post('/api/auth/register', (req) => auth.register(req));
    router.post('/api/auth/login', (req) => auth.login(req));
    router.post('/api/auth/verify', (req) => auth.verify(req));
    router.post('/api/auth/logout', (req) => auth.logout(req));
    router.post('/api/auth/refresh', (req) => auth.refresh(req));

    // Backup routes (require auth)
    router.post('/api/backup/create', (req) => backup.create(req));
    router.get('/api/backup/list', (req) => backup.list(req));
    router.get('/api/backup/:id', (req) => backup.get(req));
    router.post('/api/backup/:id/restore', (req) => backup.restore(req));
    router.delete('/api/backup/:id', (req) => backup.delete(req));

    // Scheduled backup routes
    router.get('/api/backup/schedule', (req) => backup.getSchedule(req));
    router.post('/api/backup/schedule', (req) => backup.setSchedule(req));
    router.post('/api/backup/schedule/enable', (req) => backup.enableSchedule(req));
    router.post('/api/backup/schedule/disable', (req) => backup.disableSchedule(req));

    // Subscription/IAP routes
    router.get('/api/subscription/status', (req) => subscription.status(req));
    router.post('/api/subscription/verify-receipt', (req) => subscription.verifyReceipt(req));
    router.post('/api/subscription/cancel', (req) => subscription.cancel(req));

    // Health check
    router.get('/api/health', () => jsonResponse({ status: 'ok', timestamp: new Date().toISOString() }));

    try {
      return await router.handle(request);
    } catch (err) {
      console.error('Unhandled error:', err);
      return errorResponse('Internal server error', 500);
    }
  },

  // Scheduled backup worker
  async scheduled(event: ScheduledEvent, env: Env, ctx: ExecutionContext) {
    const backup = new BackupHandler(env);
    await backup.processScheduledBackups();
  },
};
