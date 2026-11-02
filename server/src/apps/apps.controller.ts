import {
  BadRequestException,
  Body,
  ConflictException,
  Controller,
  Get,
  HttpCode,
  NotFoundException,
  Param,
  ParseUUIDPipe,
  Post,
  ServiceUnavailableException,
  UnprocessableEntityException,
  UseGuards,
} from '@nestjs/common';
import { ModelUnavailableError } from '../assistant/openrouter.client';
import { AuthUser } from '../auth/auth.tokens';
import { CurrentUser } from '../auth/current-user.decorator';
import { SessionGuard } from '../auth/session.guard';
import {
  AppConflictError,
  AppNotFoundError,
  AppSnapshot,
  AppsService,
  StateDelta,
} from './apps.service';
import { InvalidBundleError } from './bundle';
import { ActionFailedError } from './runner';

/** How long a description of an app may be, in characters. */
const MAX_PROMPT = 2000;

/** The apps someone built, and the taps on them. */
@Controller('apps')
@UseGuards(SessionGuard)
export class AppsController {
  constructor(private readonly _apps: AppsService) {}

  @Get()
  list(@CurrentUser() user: AuthUser): Promise<{ id: string; name: string }[]> {
    return this._apps.list(user.id);
  }

  @Get(':id')
  get(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ): Promise<AppSnapshot> {
    return guard(() => this._apps.get(user.id, id));
  }

  /** Builds an app from what the person described. */
  @Post()
  create(
    @CurrentUser() user: AuthUser,
    @Body() dto: { prompt?: unknown },
  ): Promise<AppSnapshot> {
    const prompt = typeof dto?.prompt === 'string' ? dto.prompt.trim() : '';
    if (prompt === '' || prompt.length > MAX_PROMPT) {
      throw new BadRequestException('Descreva o app em poucas palavras.');
    }
    if (!this._apps.configured) {
      throw new ServiceUnavailableException(
        'O assistente ainda não está conectado a um modelo.',
      );
    }
    return guard(() => this._apps.create(user.id, prompt));
  }

  /** One tap: runs the action, answers with the patch it made. */
  @Post(':id/actions/:action')
  @HttpCode(200)
  act(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Param('action') action: string,
    @Body() dto: { event?: unknown },
  ): Promise<StateDelta> {
    const event = dto?.event ?? {};
    if (typeof event !== 'object' || event === null || Array.isArray(event)) {
      throw new BadRequestException('Evento inválido.');
    }
    return guard(() =>
      this._apps.act(user.id, id, action, event as Record<string, unknown>),
    );
  }
}

/** The service's failures, in the person's words. */
async function guard<T>(work: () => Promise<T>): Promise<T> {
  try {
    return await work();
  } catch (error) {
    if (error instanceof AppNotFoundError) {
      throw new NotFoundException('App não encontrado.');
    }
    if (error instanceof AppConflictError) {
      throw new ConflictException('O app mudou enquanto isso. Tente de novo.');
    }
    if (error instanceof ActionFailedError) {
      throw new UnprocessableEntityException('Essa ação falhou.');
    }
    if (error instanceof InvalidBundleError) {
      throw new UnprocessableEntityException(
        'Não consegui montar esse app. Tente descrever de outro jeito.',
      );
    }
    if (error instanceof ModelUnavailableError) {
      throw new ServiceUnavailableException(
        'O assistente não respondeu. Tente de novo.',
      );
    }
    throw error;
  }
}
