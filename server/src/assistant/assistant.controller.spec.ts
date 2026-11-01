import {
  BadRequestException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { AuthUser } from '../auth/auth.tokens';
import { AssistantController } from './assistant.controller';
import { AssistantService } from './assistant.service';
import { ModelOutcome, ModelUnavailableError } from './openrouter.client';

const user: AuthUser = { id: 'user-1', email: 'a@b.c', name: 'Ana' };

function controllerWith(
  generate: () => Promise<ModelOutcome>,
  configured = true,
): AssistantController {
  const model = { configured, model: 'test/model', generate };
  // The client's other members are never reached.
  return new AssistantController(new AssistantService(model as never));
}

describe('AssistantController', () => {
  it('answers with what the model said', async () => {
    const controller = controllerWith(() =>
      Promise.resolve({ kind: 'final', content: 'Olá!' }),
    );

    await expect(
      controller.chat(user, { messages: [{ role: 'user', content: 'Oi' }] }),
    ).resolves.toEqual({ reply: 'Olá!', model: undefined });
  });

  it.each([
    [undefined],
    [[]],
    [[{ role: 'system', content: 'x' }]],
    [[{ role: 'user', content: '   ' }]],
    [[{ role: 'assistant', content: 'last word is not theirs' }]],
  ])('refuses %j', async (messages) => {
    const controller = controllerWith(() => Promise.reject(new Error()));

    await expect(controller.chat(user, { messages })).rejects.toThrow(
      BadRequestException,
    );
  });

  it('says so when no model is connected', async () => {
    const controller = controllerWith(() => Promise.reject(new Error()), false);

    expect(controller.status()).toEqual({ configured: false });
    await expect(
      controller.chat(user, { messages: [{ role: 'user', content: 'Oi' }] }),
    ).rejects.toThrow(ServiceUnavailableException);
  });

  it('turns a model failure into a 503', async () => {
    const controller = controllerWith(() =>
      Promise.reject(new ModelUnavailableError('down', 502)),
    );

    await expect(
      controller.chat(user, { messages: [{ role: 'user', content: 'Oi' }] }),
    ).rejects.toThrow(ServiceUnavailableException);
  });
});
