import {
  CanActivate,
  ExecutionContext,
  Inject,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import type { Request } from 'express';
import type { Auth } from './auth';
import { AUTH, AuthUser } from './auth.tokens';

/**
 * Lets a request through when it carries a live Better Auth session.
 *
 * Either kind: the session cookie the web app gets from the redirect flow,
 * or the bearer token the phones keep. Better Auth tells them apart itself.
 *
 * Only the type of `Auth` is imported: Jest's CommonJS sandbox cannot load
 * `better-auth`, which is ESM-only.
 */
@Injectable()
export class SessionGuard implements CanActivate {
  constructor(@Inject(AUTH) private readonly _auth: Auth) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context
      .switchToHttp()
      .getRequest<Request & { user?: AuthUser }>();

    const session = await this._auth.api.getSession({
      headers: headersOf(request),
    });
    if (session === null) throw new UnauthorizedException();

    const { user } = session;
    request.user = {
      id: user.id,
      email: user.email,
      name: user.name,
      image: user.image ?? undefined,
    };

    return true;
  }
}

/** Node's headers as the Fetch API's, which is what Better Auth reads. */
function headersOf(request: Request): Headers {
  const headers = new Headers();

  for (const [key, value] of Object.entries(request.headers)) {
    if (value === undefined) continue;
    if (Array.isArray(value)) {
      for (const item of value) headers.append(key, item);
    } else {
      headers.set(key, value);
    }
  }

  return headers;
}
