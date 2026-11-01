import { Injectable } from '@nestjs/common';
import { AuthUser } from '../auth/auth.tokens';
import { ChatMessage, OpenRouterClient } from './openrouter.client';

/** One message of a conversation, as the app sends and reads it. */
export interface AssistantMessage {
  role: 'user' | 'assistant';
  content: string;
}

/** What one turn answers with. */
export interface AssistantReply {
  reply: string;
  model?: string;
}

/**
 * The assistant: a plain conversation with the model, no tools yet.
 *
 * Nothing is stored. The app sends the whole conversation on every turn and
 * keeps it itself, so a new tool, a stored history or a domain prompt is
 * added here without touching the route.
 */
@Injectable()
export class AssistantService {
  constructor(private readonly _model: OpenRouterClient) {}

  /** Whether a model is connected. */
  get configured(): boolean {
    return this._model.configured;
  }

  get model(): string {
    return this._model.model;
  }

  async turn(
    user: AuthUser,
    messages: AssistantMessage[],
  ): Promise<AssistantReply> {
    const outcome = await this._model.generate(
      [{ role: 'system', content: systemPrompt(user) }, ...messages],
      [],
    );
    // With no tools offered, the model can only answer in words.
    const reply = outcome.kind === 'final' ? outcome.content : '';

    return { reply, model: outcome.usage?.model };
  }
}

/** Who the assistant is, what the app is for, and who it talks to. */
export function systemPrompt(user: AuthUser): string {
  return [
    'Você é o assistente do My Own App, um app para criar qualquer app que a pessoa quiser.',
    'Ajude a pessoa a transformar a ideia dela em um app: entender o que ela quer, sugerir funcionalidades e dar os próximos passos.',
    'Responda em português do Brasil, de forma curta e direta.',
    `Você está falando com ${user.name}.`,
  ].join('\n');
}

/** [ChatMessage]s are what OpenRouter takes; the app only sends these two. */
export function isAssistantMessage(value: unknown): value is AssistantMessage {
  const message = value as Partial<ChatMessage> | null;
  return (
    typeof message === 'object' &&
    message !== null &&
    (message.role === 'user' || message.role === 'assistant') &&
    typeof message.content === 'string' &&
    message.content.trim() !== ''
  );
}
