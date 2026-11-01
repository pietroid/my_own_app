import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

/** One chat message, as OpenRouter's OpenAI-compatible API takes it. */
export interface ChatMessage {
  role: 'system' | 'user' | 'assistant' | 'tool';
  content: string;
  tool_call_id?: string;
  tool_calls?: ToolCall[];
}

/** One tool call the model asked for. */
export interface ToolCall {
  id: string;
  type: 'function';
  function: {
    name: string;
    /** JSON-encoded arguments, as the model emitted them. */
    arguments: string;
  };
}

/** A tool, as the model sees it. */
export interface ToolDefinition {
  type: 'function';
  function: {
    name: string;
    description: string;
    parameters: Record<string, unknown>;
  };
}

/** What one call cost, as OpenRouter reports it. */
export interface ModelUsage {
  promptTokens: number;
  completionTokens: number;
  /** Prompt tokens a provider served from its cache. */
  cachedTokens: number;
  /** USD. */
  cost: number;
  /** The model that answered, which a fallback may have changed. */
  model?: string;
}

/** What one generation came back with. */
export type ModelOutcome = (
  | { kind: 'final'; content: string }
  | { kind: 'tool_calls'; toolCalls: ToolCall[] }
) & { usage?: ModelUsage };

/** Raised when OpenRouter could not answer, or is not configured. */
export class ModelUnavailableError extends Error {
  constructor(
    message: string,
    public readonly status?: number,
  ) {
    super(message);
  }
}

/** Raised when the model answered with nothing at all, twice. */
export class ModelEmptyError extends Error {}

/**
 * How long one call may take. OpenRouter's fallbacks fire on errors but not
 * on timeouts, so a short wait and one retry beats one long wait.
 */
const TIMEOUT_MS = 20_000;

/**
 * The model, through OpenRouter's chat completions API.
 *
 * Off until `OPENROUTER_API_KEY` and `OPENROUTER_MODEL` are both set.
 */
@Injectable()
export class OpenRouterClient {
  private readonly _url = 'https://openrouter.ai/api/v1/chat/completions';

  constructor(private readonly _config: ConfigService) {}

  /** Whether there is a key and a model to call. */
  get configured(): boolean {
    return this._apiKey !== '' && this.model !== '';
  }

  get model(): string {
    return this._config.get<string>('OPENROUTER_MODEL') ?? '';
  }

  /** Models OpenRouter falls back to when [model] errs, in order. */
  private get _fallbacks(): string[] {
    return (this._config.get<string>('OPENROUTER_FALLBACK_MODELS') ?? '')
      .split(',')
      .map((it) => it.trim())
      .filter((it) => it !== '' && it !== this.model);
  }

  /** How hard the model thinks: low unless the env says otherwise. */
  private get _effort(): string {
    return this._config.get<string>('OPENROUTER_REASONING') ?? 'low';
  }

  private get _apiKey(): string {
    return this._config.get<string>('OPENROUTER_API_KEY') ?? '';
  }

  /** Public origin sent to OpenRouter as the HTTP referer. */
  private get _referer(): string {
    const urls = (this._config.get<string>('BETTER_AUTH_URL') ?? '')
      .split(',')
      .map((u) => u.trim())
      .filter((u) => u !== '');
    return urls[0] ?? 'https://my-own-app.pietroteruya.dev';
  }

  private get _appName(): string {
    return this._config.get<string>('OPENROUTER_APP_NAME') ?? 'My Own App';
  }

  /**
   * One generation, asked again once when OpenRouter errs, times out or
   * answers with nothing.
   */
  async generate(
    messages: ChatMessage[],
    tools: ToolDefinition[],
  ): Promise<ModelOutcome> {
    if (!this.configured) {
      throw new ModelUnavailableError('OpenRouter is not configured');
    }

    try {
      return await this._once(messages, tools);
    } catch (error) {
      const again =
        error instanceof ModelEmptyError ||
        (error instanceof ModelUnavailableError &&
          (error.status === undefined ||
            error.status === 429 ||
            error.status >= 500));
      if (!again) throw error;

      return this._once(messages, tools);
    }
  }

  private async _once(
    messages: ChatMessage[],
    tools: ToolDefinition[],
  ): Promise<ModelOutcome> {
    let response: Response;
    let data: Record<string, unknown>;
    try {
      response = await fetch(this._url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${this._apiKey}`,
          'HTTP-Referer': this._referer,
          'X-Title': this._appName,
        },
        body: JSON.stringify({
          model: this.model,
          ...(this._fallbacks.length > 0
            ? { models: [this.model, ...this._fallbacks] }
            : {}),
          messages,
          ...(tools.length > 0 ? { tools, tool_choice: 'auto' } : {}),
          temperature: 0.3,
          reasoning: { effort: this._effort },
          provider: { sort: 'latency' },
          usage: { include: true },
        }),
        signal: AbortSignal.timeout(TIMEOUT_MS),
      });
      data = (await response.json()) as Record<string, unknown>;
    } catch (error) {
      throw new ModelUnavailableError(
        error instanceof Error ? error.message : String(error),
      );
    }

    if (!response.ok) {
      const error = data.error as { message?: string } | undefined;
      throw new ModelUnavailableError(
        error?.message ?? `OpenRouter returned ${response.status}`,
        response.status,
      );
    }

    const usage = usageOf(data);
    const choice = (data.choices as Record<string, unknown>[] | undefined)?.[0];
    const message = choice?.message as Record<string, unknown> | undefined;

    if (Array.isArray(message?.tool_calls) && message.tool_calls.length > 0) {
      return {
        kind: 'tool_calls',
        toolCalls: toolCallsOf(message.tool_calls),
        usage,
      };
    }

    const content = message?.content;
    if (typeof content !== 'string' || content.trim() === '') {
      throw new ModelEmptyError('OpenRouter returned an empty reply');
    }

    return { kind: 'final', content, usage };
  }
}

function usageOf(data: Record<string, unknown>): ModelUsage | undefined {
  const usage = data.usage as Record<string, unknown> | undefined;
  if (usage === undefined) return undefined;
  const details = usage.prompt_tokens_details as
    Record<string, unknown> | undefined;
  const number = (value: unknown) => (typeof value === 'number' ? value : 0);

  return {
    promptTokens: number(usage.prompt_tokens),
    completionTokens: number(usage.completion_tokens),
    cachedTokens: number(details?.cached_tokens),
    cost: number(usage.cost),
    model: typeof data.model === 'string' ? data.model : undefined,
  };
}

function toolCallsOf(value: unknown[]): ToolCall[] {
  return value.flatMap((item) => {
    const call = item as Record<string, unknown>;
    const fn = call.function as Record<string, unknown> | undefined;
    if (typeof call.id !== 'string' || fn === undefined) return [];

    return [
      {
        id: call.id,
        type: 'function' as const,
        function: {
          name: typeof fn.name === 'string' ? fn.name : '',
          arguments: typeof fn.arguments === 'string' ? fn.arguments : '{}',
        },
      },
    ];
  });
}
