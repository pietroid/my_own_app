/** The Nest token the Better Auth instance is injected under. */
export const AUTH = Symbol('AUTH');

/** The signed-in person, as every controller reads them. */
export class AuthUser {
  declare id: string;
  declare email: string;
  declare name: string;
  declare image?: string;
}
