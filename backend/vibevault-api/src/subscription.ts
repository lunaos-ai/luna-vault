import { Env } from './index';
import { jsonResponse, errorResponse, requireAuth } from './utils';

export class SubscriptionHandler {
  constructor(private env: Env) {}

  async status(request: Request): Promise<Response> {
    const auth = await requireAuth(request, this.env);
    if (auth instanceof Response) return auth;
    const { userId } = auth;

    try {
      const user = await this.env.DB.prepare(
        'SELECT subscription_status, subscription_expires_at, backup_enabled FROM users WHERE id = ?'
      ).bind(userId).first();

      if (!user) {
        return errorResponse('User not found', 404);
      }

      // Check if subscription is expired
      let status = user.subscription_status;
      if (user.subscription_expires_at && new Date(user.subscription_expires_at) < new Date()) {
        status = 'expired';
        // Update user status
        await this.env.DB.prepare(
          'UPDATE users SET subscription_status = ?, backup_enabled = FALSE WHERE id = ?'
        ).bind('expired', userId).run();
      }

      return jsonResponse({
        status,
        expiresAt: user.subscription_expires_at,
        backupEnabled: status === 'active' && user.backup_enabled,
        features: {
          cloudBackup: status === 'active',
          scheduledBackups: status === 'active',
          unlimitedDevices: status === 'active',
          prioritySupport: status === 'active',
        },
      });
    } catch (err) {
      console.error('Status error:', err);
      return errorResponse('Failed to get status', 500);
    }
  }

  async verifyReceipt(request: Request): Promise<Response> {
    const auth = await requireAuth(request, this.env);
    if (auth instanceof Response) return auth;
    const { userId } = auth;

    try {
      const { receiptData, productId } = await request.json();
      
      if (!receiptData) {
        return errorResponse('Receipt data required');
      }

      // In production, verify with Apple's App Store Server API
      // For now, we simulate a successful verification
      
      // Determine subscription period based on product
      const now = new Date();
      let expiresAt = new Date(now);
      
      if (productId?.includes('yearly')) {
        expiresAt.setFullYear(expiresAt.getFullYear() + 1);
      } else if (productId?.includes('monthly')) {
        expiresAt.setMonth(expiresAt.getMonth() + 1);
      } else {
        // Default to monthly
        expiresAt.setMonth(expiresAt.getMonth() + 1);
      }

      await this.env.DB.prepare(
        `UPDATE users SET 
         subscription_status = 'active', 
         subscription_expires_at = ?,
         backup_enabled = TRUE
         WHERE id = ?`
      ).bind(expiresAt.toISOString(), userId).run();

      // Log the action
      await this.env.DB.prepare(
        `INSERT INTO cloud_audit (user_id, action, details, ip_address, user_agent)
         VALUES (?, 'subscription_changed', ?, ?, ?)`
      ).bind(userId, JSON.stringify({ status: 'active', productId, expiresAt }), request.headers.get('CF-Connecting-IP') || 'unknown', request.headers.get('User-Agent') || 'unknown').run();

      return jsonResponse({
        success: true,
        status: 'active',
        expiresAt: expiresAt.toISOString(),
        backupEnabled: true,
      });
    } catch (err) {
      console.error('Verify receipt error:', err);
      return errorResponse('Receipt verification failed', 500);
    }
  }

  async cancel(request: Request): Promise<Response> {
    const auth = await requireAuth(request, this.env);
    if (auth instanceof Response) return auth;
    const { userId } = auth;

    try {
      await this.env.DB.prepare(
        `UPDATE users SET 
         subscription_status = 'cancelled',
         backup_enabled = FALSE
         WHERE id = ?`
      ).bind(userId).run();

      // Log the action
      await this.env.DB.prepare(
        `INSERT INTO cloud_audit (user_id, action, details, ip_address, user_agent)
         VALUES (?, 'subscription_cancelled', ?, ?, ?)`
      ).bind(userId, '{}', request.headers.get('CF-Connecting-IP') || 'unknown', request.headers.get('User-Agent') || 'unknown').run();

      return jsonResponse({
        success: true,
        message: 'Subscription cancelled. You will retain access until the end of your billing period.',
      });
    } catch (err) {
      console.error('Cancel error:', err);
      return errorResponse('Cancellation failed', 500);
    }
  }
}
