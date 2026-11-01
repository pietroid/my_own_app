import { analyticsFrom, NoAnalytics } from './analytics';
import { eventFor, routeOf } from './events';

describe('events', () => {
  it('drops the global prefix from a route', () => {
    expect(routeOf('/api/assistant/chat')).toBe('/assistant/chat');
    expect(routeOf('/api')).toBe('/');
    expect(routeOf(undefined)).toBeUndefined();
  });

  it('names a write by its method and route', () => {
    expect(eventFor('post', '/assistant/chat')).toBe('assistant_turn');
  });

  it('names no read', () => {
    expect(eventFor('GET', '/assistant/status')).toBeUndefined();
  });

  it('sends nothing without a key', () => {
    expect(analyticsFrom({})).toBeInstanceOf(NoAnalytics);
    expect(analyticsFrom({ POSTHOG_KEY: '  ' })).toBeInstanceOf(NoAnalytics);
  });
});
