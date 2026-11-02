import ivm from 'isolated-vm';

/** How much one action may use. */
const MEMORY_MB = 32;
const TIMEOUT_MS = 50;

/** Raised when an action failed to compile, threw, or ran too long. */
export class ActionFailedError extends Error {}

/**
 * Runs an action the assistant wrote, in its own V8 isolate.
 *
 * The code is untrusted (the person's words reached the model that wrote
 * it), so it never runs in this process's context: the isolate has no
 * `require`, no network and no clock beyond what V8 itself gives, a memory
 * cap and a timeout. Values cross as JSON strings, in and out.
 */
export function runAction(
  code: string,
  input: Record<string, unknown>,
  event: Record<string, unknown>,
): unknown {
  const isolate = new ivm.Isolate({ memoryLimit: MEMORY_MB });
  try {
    const context = isolate.createContextSync();
    context.global.setSync('__input', JSON.stringify(input));
    context.global.setSync('__event', JSON.stringify(event));
    const script = isolate.compileScriptSync(
      `${code}\n;JSON.stringify(run(JSON.parse(__input), JSON.parse(__event)) ?? [])`,
    );
    const out: unknown = script.runSync(context, { timeout: TIMEOUT_MS });
    if (typeof out !== 'string') throw new Error('run returned nothing');
    return JSON.parse(out);
  } catch (error) {
    throw new ActionFailedError(
      error instanceof Error ? error.message : String(error),
    );
  } finally {
    isolate.dispose();
  }
}

/** Whether [code] compiles and defines `run`, without calling it. */
export function checkAction(code: string): void {
  const isolate = new ivm.Isolate({ memoryLimit: MEMORY_MB });
  try {
    const context = isolate.createContextSync();
    const kind: unknown = isolate
      .compileScriptSync(`${code}\n;typeof run`)
      .runSync(context, { timeout: TIMEOUT_MS });
    if (kind !== 'function') throw new Error('run is not a function');
  } catch (error) {
    throw new ActionFailedError(
      error instanceof Error ? error.message : String(error),
    );
  } finally {
    isolate.dispose();
  }
}
