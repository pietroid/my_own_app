import {
  BadRequestException,
  Body,
  ConflictException,
  Controller,
  Get,
  HttpCode,
  NotFoundException,
  Param,
  ParseIntPipe,
  ParseUUIDPipe,
  Patch,
  Post,
  ServiceUnavailableException,
  UnprocessableEntityException,
  UseGuards,
} from '@nestjs/common';
import { ModelUnavailableError } from '../assistant/openrouter.client';
import { AuthUser } from '../auth/auth.tokens';
import { CurrentUser } from '../auth/current-user.decorator';
import { SessionGuard } from '../auth/session.guard';
import { AppForm } from '../db/schema';
import {
  AppConflictError,
  AppNotFoundError,
  AppSnapshot,
  AppSummary,
  AppsService,
  EditOutcome,
  StateDelta,
  VersionSummary,
} from './apps.service';
import { InvalidBundleError } from './bundle';
import { PlatformCallError } from './platform';
import { ActionFailedError } from './runner';

/** How long a description of an app may be, in characters. */
const MAX_PROMPT = 2000;

/** The apps someone built, and the taps on them. */
@Controller('apps')
@UseGuards(SessionGuard)
export class AppsController {
  constructor(private readonly _apps: AppsService) {}

  @Get()
  list(@CurrentUser() user: AuthUser): Promise<AppSummary[]> {
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
    @Body() dto: { prompt?: unknown; form?: unknown },
  ): Promise<AppSnapshot> {
    const prompt = typeof dto?.prompt === 'string' ? dto.prompt.trim() : '';
    if (prompt === '' || prompt.length > MAX_PROMPT) {
      throw new BadRequestException('Descreva o app em poucas palavras.');
    }
    const form = dto.form === undefined ? 'mobile' : formOf(dto.form);
    if (!this._apps.configured) {
      throw new ServiceUnavailableException(
        'O assistente ainda não está conectado a um modelo.',
      );
    }
    return guard(() => this._apps.create(user.id, prompt, form));
  }

  /** Switches what the app is made for: a version without the model. */
  @Patch(':id')
  setForm(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: { form?: unknown },
  ): Promise<EditOutcome> {
    const form = formOf(dto?.form);
    return guard(() => this._apps.setForm(user.id, id, form));
  }

  /** The app's conversation: its versions, oldest first. */
  @Get(':id/versions')
  history(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ): Promise<{ current: number; versions: VersionSummary[] }> {
    return guard(() => this._apps.history(user.id, id));
  }

  /** The app as it was at version [n]. */
  @Get(':id/versions/:n')
  version(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Param('n', ParseIntPipe) n: number,
  ): Promise<AppSnapshot> {
    return guard(() => this._apps.version(user.id, id, n));
  }

  /**
   * One message about the app: the model changes it, and the change is a
   * new version. `focus` is the id of the component the person selected.
   */
  @Post(':id/messages')
  edit(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: { prompt?: unknown; focus?: unknown },
  ): Promise<EditOutcome> {
    const prompt = typeof dto?.prompt === 'string' ? dto.prompt.trim() : '';
    if (prompt === '' || prompt.length > MAX_PROMPT) {
      throw new BadRequestException('Diga o que mudar em poucas palavras.');
    }
    const focus = dto?.focus;
    if (focus !== undefined && focus !== null && typeof focus !== 'string') {
      throw new BadRequestException('Componente inválido.');
    }
    if (!this._apps.configured) {
      throw new ServiceUnavailableException(
        'O assistente ainda não está conectado a um modelo.',
      );
    }
    return guard(() =>
      this._apps.edit(user.id, id, prompt, focus ?? undefined),
    );
  }

  /** Brings version [n] back, as a new version. */
  @Post(':id/versions/:n/restore')
  restore(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Param('n', ParseIntPipe) n: number,
  ): Promise<EditOutcome> {
    return guard(() => this._apps.restore(user.id, id, n));
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
/** A form the app knows, or a refusal. */
function formOf(value: unknown): AppForm {
  if (value === 'mobile' || value === 'web') return value;
  throw new BadRequestException('Escolha celular ou web.');
}

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
    if (error instanceof PlatformCallError) {
      throw new UnprocessableEntityException(error.message);
    }
    if (error instanceof ActionFailedError) {
      throw new UnprocessableEntityException('Essa ação falhou.');
    }
    if (error instanceof InvalidBundleError) {
      throw new UnprocessableEntityException(
        'Não consegui fazer isso. Tente descrever de outro jeito.',
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
