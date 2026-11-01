import {
  BadRequestException,
  Body,
  Controller,
  Get,
  HttpCode,
  Post,
  ServiceUnavailableException,
  UseGuards,
} from '@nestjs/common';
import { AuthUser } from '../auth/auth.tokens';
import { CurrentUser } from '../auth/current-user.decorator';
import { SessionGuard } from '../auth/session.guard';
import {
  AssistantReply,
  AssistantService,
  isAssistantMessage,
} from './assistant.service';
import { ModelUnavailableError } from './openrouter.client';

/** How long a conversation the app may send, in messages. */
const MAX_MESSAGES = 40;

/** How long one message may be, in characters. */
const MAX_LENGTH = 4000;

/** Talking to the assistant. */
@Controller('assistant')
@UseGuards(SessionGuard)
export class AssistantController {
  constructor(private readonly _assistant: AssistantService) {}

  /** Whether the assistant can answer, so the app can say so up front. */
  @Get('status')
  status(): { configured: boolean; model?: string } {
    return this._assistant.configured
      ? { configured: true, model: this._assistant.model }
      : { configured: false };
  }

  /** One turn: the conversation so far, the last message the person's. */
  @Post('chat')
  @HttpCode(200)
  async chat(
    @CurrentUser() user: AuthUser,
    @Body() dto: { messages?: unknown },
  ): Promise<AssistantReply> {
    const messages = dto?.messages;
    if (
      !Array.isArray(messages) ||
      messages.length === 0 ||
      messages.length > MAX_MESSAGES ||
      !messages.every(isAssistantMessage) ||
      messages.some((message) => message.content.length > MAX_LENGTH) ||
      messages[messages.length - 1].role !== 'user'
    ) {
      throw new BadRequestException('Conversa inválida.');
    }

    if (!this._assistant.configured) {
      throw new ServiceUnavailableException(
        'O assistente ainda não está conectado a um modelo.',
      );
    }

    try {
      return await this._assistant.turn(user, messages);
    } catch (error) {
      if (error instanceof ModelUnavailableError) {
        throw new ServiceUnavailableException(
          'O assistente não respondeu. Tente de novo.',
        );
      }
      throw error;
    }
  }
}
