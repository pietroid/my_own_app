import { Controller, Get, UseGuards } from '@nestjs/common';
import { AuthUser } from '../auth/auth.tokens';
import { CurrentUser } from '../auth/current-user.decorator';
import { SessionGuard } from '../auth/session.guard';

/**
 * The signed-in person.
 *
 * Better Auth owns the user table and creates the row on the first sign-in,
 * so there is no sign-up step here: this reads back who the session
 * belongs to.
 */
@Controller('users')
@UseGuards(SessionGuard)
export class UsersController {
  @Get('me')
  me(@CurrentUser() user: AuthUser): AuthUser {
    return user;
  }
}
