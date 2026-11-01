import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AssistantController } from './assistant.controller';
import { AssistantService } from './assistant.service';
import { OpenRouterClient } from './openrouter.client';

/** The assistant, through OpenRouter. */
@Module({
  imports: [ConfigModule],
  controllers: [AssistantController],
  providers: [AssistantService, OpenRouterClient],
})
export class AssistantModule {}
