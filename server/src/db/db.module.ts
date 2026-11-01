import {
  Global,
  Inject,
  Injectable,
  Module,
  OnModuleDestroy,
} from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { Pool } from 'pg';
import { createPool, Database, databaseOf, DB } from './db';

const POOL = Symbol('POOL');

/** Closes the pool when the app shuts down. */
@Injectable()
class PoolCloser implements OnModuleDestroy {
  constructor(@Inject(POOL) private readonly _pool: Pool) {}

  async onModuleDestroy(): Promise<void> {
    await this._pool.end();
  }
}

/** The database, available to every module without importing this one. */
@Global()
@Module({
  imports: [ConfigModule],
  providers: [
    {
      provide: POOL,
      inject: [ConfigService],
      useFactory: (config: ConfigService): Pool => {
        const url = config.get<string>('DATABASE_URL');
        if (!url) throw new Error('DATABASE_URL is not set');

        return createPool(url);
      },
    },
    {
      provide: DB,
      inject: [POOL],
      useFactory: (pool: Pool): Database => databaseOf(pool),
    },
    PoolCloser,
  ],
  exports: [DB],
})
export class DbModule {}
