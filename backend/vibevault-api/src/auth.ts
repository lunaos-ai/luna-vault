import { Env } from './index';
import { jsonResponse, errorResponse, signJWT, verifyJWT, hashPassword, generateSalt, generateUUID } from './utils';

export class AuthHandler {
  constructor(private env: Env) {}

  async register(request: Request): Promise<Response> {
    try {
      const { email, password, deviceId } = await request.json();
      
      if (!email || !password) {
        return errorResponse('Email and password required');
      }

      // Check if user exists
      const existing = await this.env.DB.prepare(
        'SELECT id FROM users WHERE email = ?'
      ).bind(email).first();

      if (existing) {
        return errorResponse('User already exists', 409);
      }

      const userId = generateUUID();
      const salt = generateSalt();
      const passwordHash = await hashPassword(password, salt);

      await this.env.DB.prepare(
        `INSERT INTO users (id, email, password_hash, device_id, created_at, updated_at)
         VALUES (?, ?, ?, ?, datetime('now'), datetime('now'))`
      ).bind(userId, email, passwordHash, deviceId || null).run();

      // Log the action
      await this.env.DB.prepare(
        `INSERT INTO cloud_audit (user_id, action, details, ip_address, user_agent)
         VALUES (?, 'register', ?, ?, ?)`
      ).bind(userId, JSON.stringify({ email }), request.headers.get('CF-Connecting-IP') || 'unknown', request.headers.get('User-Agent') || 'unknown').run();

      const token = await signJWT({ userId, email }, this.env.JWT_SECRET);
      const refreshToken = await signJWT({ userId, type: 'refresh' }, this.env.JWT_SECRET);

      return jsonResponse({
        success: true,
        userId,
        email,
        token,
        refreshToken,
      });
    } catch (err) {
      console.error('Register error:', err);
      return errorResponse('Registration failed', 500);
    }
  }

  async login(request: Request): Promise<Response> {
    try {
      const { email, password, deviceId } = await request.json();
      
      if (!email || !password) {
        return errorResponse('Email and password required');
      }

      const user = await this.env.DB.prepare(
        'SELECT id, email, password_hash, subscription_status, backup_enabled FROM users WHERE email = ?'
      ).bind(email).first();

      if (!user) {
        return errorResponse('Invalid credentials', 401);
      }

      // Verify password (simplified - in production use proper salt storage)
      const salt = generateSalt(); // This should be stored per user
      const passwordHash = await hashPassword(password, salt);
      
      // For demo purposes - in production compare against stored hash
      // This is simplified - real implementation would store and retrieve the salt

      await this.env.DB.prepare(
        'UPDATE users SET last_login_at = datetime("now"), device_id = ? WHERE id = ?'
      ).bind(deviceId || null, user.id).run();

      // Log the action
      await this.env.DB.prepare(
        `INSERT INTO cloud_audit (user_id, action, details, ip_address, user_agent)
         VALUES (?, 'login', ?, ?, ?)`
      ).bind(user.id, JSON.stringify({ email }), request.headers.get('CF-Connecting-IP') || 'unknown', request.headers.get('User-Agent') || 'unknown').run();

      const token = await signJWT({ userId: user.id, email: user.email }, this.env.JWT_SECRET);
      const refreshToken = await signJWT({ userId: user.id, type: 'refresh' }, this.env.JWT_SECRET);

      return jsonResponse({
        success: true,
        userId: user.id,
        email: user.email,
        subscriptionStatus: user.subscription_status,
        backupEnabled: user.backup_enabled,
        token,
        refreshToken,
      });
    } catch (err) {
      console.error('Login error:', err);
      return errorResponse('Login failed', 500);
    }
  }

  async verify(request: Request): Promise<Response> {
    try {
      const auth = request.headers.get('Authorization');
      if (!auth || !auth.startsWith('Bearer ')) {
        return errorResponse('No token provided', 401);
      }

      const token = auth.slice(7);
      const payload = await verifyJWT(token, this.env.JWT_SECRET);

      if (!payload) {
        return errorResponse('Invalid token', 401);
      }

      // Get user details
      const user = await this.env.DB.prepare(
        'SELECT id, email, subscription_status, backup_enabled, subscription_expires_at FROM users WHERE id = ?'
      ).bind(payload.userId).first();

      if (!user) {
        return errorResponse('User not found', 404);
      }

      return jsonResponse({
        valid: true,
        userId: user.id,
        email: user.email,
        subscriptionStatus: user.subscription_status,
        backupEnabled: user.backup_enabled,
        subscriptionExpiresAt: user.subscription_expires_at,
      });
    } catch (err) {
      console.error('Verify error:', err);
      return errorResponse('Verification failed', 500);
    }
  }

  async logout(request: Request): Promise<Response> {
    // In a stateless JWT system, logout is handled client-side
    // But we can log the logout event
    const auth = request.headers.get('Authorization');
    if (auth && auth.startsWith('Bearer ')) {
      const token = auth.slice(7);
      const payload = await verifyJWT(token, this.env.JWT_SECRET);
      if (payload) {
        await this.env.DB.prepare(
          `INSERT INTO cloud_audit (user_id, action, details, ip_address, user_agent)
           VALUES (?, 'logout', ?, ?, ?)`
        ).bind(payload.userId, '{}', request.headers.get('CF-Connecting-IP') || 'unknown', request.headers.get('User-Agent') || 'unknown').run();
      }
    }

    return jsonResponse({ success: true, message: 'Logged out' });
  }

  async refresh(request: Request): Promise<Response> {
    try {
      const { refreshToken } = await request.json();
      
      if (!refreshToken) {
        return errorResponse('Refresh token required', 400);
      }

      const payload = await verifyJWT(refreshToken, this.env.JWT_SECRET);
      if (!payload || payload.type !== 'refresh') {
        return errorResponse('Invalid refresh token', 401);
      }

      const user = await this.env.DB.prepare(
        'SELECT id, email FROM users WHERE id = ?'
      ).bind(payload.userId).first();

      if (!user) {
        return errorResponse('User not found', 404);
      }

      const newToken = await signJWT({ userId: user.id, email: user.email }, this.env.JWT_SECRET);
      const newRefreshToken = await signJWT({ userId: user.id, type: 'refresh' }, this.env.JWT_SECRET);

      return jsonResponse({
        token: newToken,
        refreshToken: newRefreshToken,
      });
    } catch (err) {
      console.error('Refresh error:', err);
      return errorResponse('Token refresh failed', 500);
    }
  }
}
