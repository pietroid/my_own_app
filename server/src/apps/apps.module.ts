import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { OpenRouterClient } from '../assistant/openrouter.client';
import { AppsController } from './apps.controller';
import { AppsService } from './apps.service';

/** Apps as data: built once by the model, run by their own actions. */
@Module({
  imports: [ConfigModule],
  controllers: [AppsController],
  providers: [AppsService, OpenRouterClient],
})
export class AppsModule {}
