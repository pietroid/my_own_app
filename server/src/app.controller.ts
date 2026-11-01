import { Controller, Get, HttpCode } from '@nestjs/common';

@Controller()
export class AppController {
  /**
   * Lightweight endpoint for verifying that the server is reachable, from
   * the Pi (`curl localhost:<port>/api/health`) or a browser.
   */
  @Get('health')
  @HttpCode(200)
  health(): { status: string; timestamp: string } {
    return { status: 'ok', timestamp: new Date().toISOString() };
  }
}
