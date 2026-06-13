import { Env } from './index';
import { jsonResponse, errorResponse, requireAuth, encryptData, decryptData, generateUUID } from './utils';

export class BackupHandler {
  constructor(private env: Env) {}

  async create(request: Request): Promise<Response> {
    const auth = await requireAuth(request, this.env);
    if (auth instanceof Response) return auth;
    const { userId } = auth;

    try {
      const { backupData, checksum, deviceName } = await request.json();
      
      if (!backupData) {
        return errorResponse('Backup data required');
      }

      // Check if backups are enabled
      const user = await this.env.DB.prepare(
        'SELECT backup_enabled, subscription_status FROM users WHERE id = ?'
      ).bind(userId).first();

      if (!user || !user.backup_enabled) {
        return errorResponse('Cloud backup not enabled. Subscribe to enable backups.', 403);
      }

      const backupId = generateUUID();
      const size = new Blob([backupData]).size;

      await this.env.DB.prepare(
        `INSERT INTO backups (id, user_id, backup_data, backup_size, checksum, device_name, created_at)
         VALUES (?, ?, ?, ?, ?, ?, datetime('now'))`
      ).bind(backupId, userId, backupData, size, checksum || null, deviceName || 'Unknown').run();

      // Update last backup time in schedule
      await this.env.DB.prepare(
        `UPDATE backup_schedules SET last_backup_at = datetime('now') WHERE user_id = ?`
      ).bind(userId).run();

      // Log the action
      await this.env.DB.prepare(
        `INSERT INTO cloud_audit (user_id, action, details, ip_address, user_agent)
         VALUES (?, 'backup_created', ?, ?, ?)`
      ).bind(userId, JSON.stringify({ backupId, size }), request.headers.get('CF-Connecting-IP') || 'unknown', request.headers.get('User-Agent') || 'unknown').run();

      return jsonResponse({
        success: true,
        backupId,
        size,
        createdAt: new Date().toISOString(),
      });
    } catch (err) {
      console.error('Backup create error:', err);
      return errorResponse('Backup creation failed', 500);
    }
  }

  async list(request: Request): Promise<Response> {
    const auth = await requireAuth(request, this.env);
    if (auth instanceof Response) return auth;
    const { userId } = auth;

    try {
      const { results } = await this.env.DB.prepare(
        `SELECT id, backup_size, checksum, device_name, created_at 
         FROM backups 
         WHERE user_id = ? 
         ORDER BY created_at DESC`
      ).bind(userId).all();

      return jsonResponse({
        backups: results || [],
        count: results?.length || 0,
      });
    } catch (err) {
      console.error('Backup list error:', err);
      return errorResponse('Failed to list backups', 500);
    }
  }

  async get(request: Request): Promise<Response> {
    const auth = await requireAuth(request, this.env);
    if (auth instanceof Response) return auth;
    const { userId } = auth;

    const backupId = (request as any).params?.id;
    if (!backupId) {
      return errorResponse('Backup ID required');
    }

    try {
      const backup = await this.env.DB.prepare(
        `SELECT id, backup_data, backup_size, checksum, device_name, created_at 
         FROM backups 
         WHERE id = ? AND user_id = ?`
      ).bind(backupId, userId).first();

      if (!backup) {
        return errorResponse('Backup not found', 404);
      }

      // Log the action
      await this.env.DB.prepare(
        `INSERT INTO cloud_audit (user_id, action, details, ip_address, user_agent)
         VALUES (?, 'backup_accessed', ?, ?, ?)`
      ).bind(userId, JSON.stringify({ backupId }), request.headers.get('CF-Connecting-IP') || 'unknown', request.headers.get('User-Agent') || 'unknown').run();

      return jsonResponse({
        backup: {
          id: backup.id,
          data: backup.backup_data,
          size: backup.backup_size,
          checksum: backup.checksum,
          deviceName: backup.device_name,
          createdAt: backup.created_at,
        },
      });
    } catch (err) {
      console.error('Backup get error:', err);
      return errorResponse('Failed to get backup', 500);
    }
  }

  async restore(request: Request): Promise<Response> {
    const auth = await requireAuth(request, this.env);
    if (auth instanceof Response) return auth;
    const { userId } = auth;

    const backupId = (request as any).params?.id;
    if (!backupId) {
      return errorResponse('Backup ID required');
    }

    try {
      const backup = await this.env.DB.prepare(
        `SELECT id, backup_data, device_name, created_at 
         FROM backups 
         WHERE id = ? AND user_id = ?`
      ).bind(backupId, userId).first();

      if (!backup) {
        return errorResponse('Backup not found', 404);
      }

      // Log the restore action
      await this.env.DB.prepare(
        `INSERT INTO cloud_audit (user_id, action, details, ip_address, user_agent)
         VALUES (?, 'backup_restored', ?, ?, ?)`
      ).bind(userId, JSON.stringify({ backupId, restoredFrom: backup.device_name }), request.headers.get('CF-Connecting-IP') || 'unknown', request.headers.get('User-Agent') || 'unknown').run();

      return jsonResponse({
        success: true,
        backupId: backup.id,
        data: backup.backup_data,
        restoredFrom: backup.device_name,
        createdAt: backup.created_at,
      });
    } catch (err) {
      console.error('Backup restore error:', err);
      return errorResponse('Restore failed', 500);
    }
  }

  async delete(request: Request): Promise<Response> {
    const auth = await requireAuth(request, this.env);
    if (auth instanceof Response) return auth;
    const { userId } = auth;

    const backupId = (request as any).params?.id;
    if (!backupId) {
      return errorResponse('Backup ID required');
    }

    try {
      const result = await this.env.DB.prepare(
        'DELETE FROM backups WHERE id = ? AND user_id = ?'
      ).bind(backupId, userId).run();

      if (result.meta?.changes === 0) {
        return errorResponse('Backup not found', 404);
      }

      // Log the action
      await this.env.DB.prepare(
        `INSERT INTO cloud_audit (user_id, action, details, ip_address, user_agent)
         VALUES (?, 'backup_deleted', ?, ?, ?)`
      ).bind(userId, JSON.stringify({ backupId }), request.headers.get('CF-Connecting-IP') || 'unknown', request.headers.get('User-Agent') || 'unknown').run();

      return jsonResponse({ success: true, message: 'Backup deleted' });
    } catch (err) {
      console.error('Backup delete error:', err);
      return errorResponse('Delete failed', 500);
    }
  }

  // Schedule management
  async getSchedule(request: Request): Promise<Response> {
    const auth = await requireAuth(request, this.env);
    if (auth instanceof Response) return auth;
    const { userId } = auth;

    try {
      const schedule = await this.env.DB.prepare(
        `SELECT * FROM backup_schedules WHERE user_id = ?`
      ).bind(userId).first();

      if (!schedule) {
        return jsonResponse({ enabled: false });
      }

      return jsonResponse({
        enabled: schedule.enabled,
        frequency: schedule.frequency,
        dayOfWeek: schedule.day_of_week,
        hourOfDay: schedule.hour_of_day,
        lastBackupAt: schedule.last_backup_at,
        nextBackupAt: schedule.next_backup_at,
      });
    } catch (err) {
      console.error('Get schedule error:', err);
      return errorResponse('Failed to get schedule', 500);
    }
  }

  async setSchedule(request: Request): Promise<Response> {
    const auth = await requireAuth(request, this.env);
    if (auth instanceof Response) return auth;
    const { userId } = auth;

    try {
      const { frequency, dayOfWeek, hourOfDay } = await request.json();

      if (!frequency || !['daily', 'weekly', 'monthly'].includes(frequency)) {
        return errorResponse('Valid frequency required (daily, weekly, monthly)');
      }

      // Calculate next backup time
      const nextBackup = this.calculateNextBackup(frequency, dayOfWeek, hourOfDay);

      await this.env.DB.prepare(
        `INSERT INTO backup_schedules (id, user_id, frequency, day_of_week, hour_of_day, next_backup_at, enabled)
         VALUES (?, ?, ?, ?, ?, ?, TRUE)
         ON CONFLICT(user_id) DO UPDATE SET
         frequency = excluded.frequency,
         day_of_week = excluded.day_of_week,
         hour_of_day = excluded.hour_of_day,
         next_backup_at = excluded.next_backup_at`
      ).bind(generateUUID(), userId, frequency, dayOfWeek || 0, hourOfDay || 2, nextBackup.toISOString()).run();

      return jsonResponse({
        success: true,
        frequency,
        dayOfWeek,
        hourOfDay,
        nextBackupAt: nextBackup.toISOString(),
      });
    } catch (err) {
      console.error('Set schedule error:', err);
      return errorResponse('Failed to set schedule', 500);
    }
  }

  async enableSchedule(request: Request): Promise<Response> {
    const auth = await requireAuth(request, this.env);
    if (auth instanceof Response) return auth;
    const { userId } = auth;

    await this.env.DB.prepare(
      `UPDATE backup_schedules SET enabled = TRUE WHERE user_id = ?`
    ).bind(userId).run();

    return jsonResponse({ success: true, enabled: true });
  }

  async disableSchedule(request: Request): Promise<Response> {
    const auth = await requireAuth(request, this.env);
    if (auth instanceof Response) return auth;
    const { userId } = auth;

    await this.env.DB.prepare(
      `UPDATE backup_schedules SET enabled = FALSE WHERE user_id = ?`
    ).bind(userId).run();

    return jsonResponse({ success: true, enabled: false });
  }

  // Process scheduled backups (called by cron trigger)
  async processScheduledBackups(): Promise<void> {
    const now = new Date();
    
    const { results } = await this.env.DB.prepare(
      `SELECT s.*, u.email FROM backup_schedules s
       JOIN users u ON s.user_id = u.id
       WHERE s.enabled = TRUE 
       AND s.next_backup_at <= datetime('now')`
    ).all();

    if (!results || results.length === 0) return;

    for (const schedule of results) {
      try {
        // Update next backup time
        const nextBackup = this.calculateNextBackup(
          schedule.frequency, 
          schedule.day_of_week, 
          schedule.hour_of_day
        );

        await this.env.DB.prepare(
          `UPDATE backup_schedules 
           SET next_backup_at = ? 
           WHERE id = ?`
        ).bind(nextBackup.toISOString(), schedule.id).run();

        console.log(`Scheduled backup triggered for user ${schedule.user_id}`);
        // The actual backup would be initiated by the client via push notification
        // or the client would check on next launch
      } catch (err) {
        console.error(`Failed to process backup for ${schedule.user_id}:`, err);
      }
    }
  }

  private calculateNextBackup(frequency: string, dayOfWeek: number, hourOfDay: number): Date {
    const now = new Date();
    const next = new Date(now);
    next.setHours(hourOfDay, 0, 0, 0);

    switch (frequency) {
      case 'daily':
        if (next <= now) {
          next.setDate(next.getDate() + 1);
        }
        break;
      case 'weekly':
        const daysUntilTarget = (dayOfWeek - now.getDay() + 7) % 7;
        next.setDate(now.getDate() + daysUntilTarget);
        if (next <= now) {
          next.setDate(next.getDate() + 7);
        }
        break;
      case 'monthly':
        next.setDate(1);
        if (next <= now) {
          next.setMonth(next.getMonth() + 1);
        }
        break;
    }

    return next;
  }
}
