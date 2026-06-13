export type RouteHandler = (request: Request) => Promise<Response>;

export class Router {
  private routes: Map<string, Map<string, RouteHandler>> = new Map();

  get(path: string, handler: RouteHandler) {
    this.addRoute('GET', path, handler);
  }

  post(path: string, handler: RouteHandler) {
    this.addRoute('POST', path, handler);
  }

  put(path: string, handler: RouteHandler) {
    this.addRoute('PUT', path, handler);
  }

  delete(path: string, handler: RouteHandler) {
    this.addRoute('DELETE', path, handler);
  }

  private addRoute(method: string, path: string, handler: RouteHandler) {
    if (!this.routes.has(method)) {
      this.routes.set(method, new Map());
    }
    this.routes.get(method)!.set(path, handler);
  }

  async handle(request: Request): Promise<Response> {
    const method = request.method;
    const url = new URL(request.url);
    const path = url.pathname;

    const methodRoutes = this.routes.get(method);
    if (!methodRoutes) {
      return new Response('Method not allowed', { status: 405 });
    }

    // Check for exact match first
    if (methodRoutes.has(path)) {
      return await methodRoutes.get(path)!(request);
    }

    // Check for parameterized routes
    for (const [routePath, handler] of methodRoutes) {
      const params = this.matchRoute(path, routePath);
      if (params) {
        // Attach params to request for handlers to use
        (request as any).params = params;
        return await handler(request);
      }
    }

    return new Response('Not found', { status: 404 });
  }

  private matchRoute(path: string, route: string): Record<string, string> | null {
    const pathParts = path.split('/').filter(Boolean);
    const routeParts = route.split('/').filter(Boolean);

    if (pathParts.length !== routeParts.length) {
      return null;
    }

    const params: Record<string, string> = {};

    for (let i = 0; i < routeParts.length; i++) {
      if (routeParts[i].startsWith(':')) {
        const paramName = routeParts[i].slice(1);
        params[paramName] = pathParts[i];
      } else if (routeParts[i] !== pathParts[i]) {
        return null;
      }
    }

    return Object.keys(params).length > 0 ? params : null;
  }
}
