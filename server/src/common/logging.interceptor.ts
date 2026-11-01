import {
  CallHandler,
  ExecutionContext,
  Injectable,
  Logger,
  NestInterceptor,
} from '@nestjs/common';
import { Request, Response } from 'express';
import { Observable, throwError } from 'rxjs';
import { catchError, tap } from 'rxjs/operators';
import { NoAnalytics } from '../analytics/analytics';
import type { Analytics } from '../analytics/analytics';
import { eventFor, routeOf } from '../analytics/events';

interface RequestWithUser extends Request {
  user?: { id?: string };
}

/**
 * Logs every HTTP request/response pair with timing, user id, status code and
 * errors. This is the main server observability surface: keep it verbose.
 *
 * It also tells `Analytics` what happened: each write that succeeded as the
 * person's event (`analytics/events.ts`), and each failure that is not a
 * refusal (a 5xx, or an error with no status) as an exception. Only the
 * route and the status go along: never the url's query, never the body.
 */
@Injectable()
export class LoggingInterceptor implements NestInterceptor {
  private readonly logger = new Logger('HTTP');

  constructor(private readonly analytics: Analytics = new NoAnalytics()) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const http = context.switchToHttp();
    const req = http.getRequest<RequestWithUser>();
    const res = http.getResponse<Response>();

    const start = Date.now();
    const userId = req.user?.id ?? 'anonymous';
    const method = req.method;
    const url = req.originalUrl ?? req.url;
    // The route as declared (`/items/:id`), never the url and its query.
    const route = routeOf((req.route as { path?: string } | undefined)?.path);

    const logContext = {
      method,
      url,
      userId,
      query: req.query,
      body: this._sanitizeBody(req.body),
    };

    this.logger.log(`>> ${method} ${url} - user=${userId}`, logContext);

    return next.handle().pipe(
      tap(() => {
        const duration = Date.now() - start;
        const status = res.statusCode;
        this.logger.log(
          `<< ${method} ${url} - user=${userId} status=${status} duration=${duration}ms`,
        );
        const event = eventFor(method, route);
        if (event && req.user?.id) {
          this.analytics.capture(req.user.id, event, { route, status });
        }
      }),
      catchError((error: unknown) => {
        const duration = Date.now() - start;
        const failure = error as {
          status?: number;
          message?: string;
          stack?: string;
        };
        const status = failure.status ?? res.statusCode ?? 500;
        const message = failure.message ?? String(error);
        const stack = failure.stack;

        this.logger.error(
          `<< ${method} ${url} - user=${userId} status=${status} duration=${duration}ms error=${message}`,
          stack,
        );
        if (failure.status === undefined || failure.status >= 500) {
          this.analytics.captureException(error, req.user?.id, {
            method,
            route,
            status: failure.status ?? 500,
          });
        }

        return throwError(() => error);
      }),
    );
  }

  private _sanitizeBody(body: unknown): unknown {
    if (body === null || typeof body !== 'object') return body;

    const clone = { ...(body as Record<string, unknown>) };
    for (const key of Object.keys(clone)) {
      if (/token|password|secret|key|authorization/i.test(key)) {
        clone[key] = '<redacted>';
      }
    }
    return clone;
  }
}
