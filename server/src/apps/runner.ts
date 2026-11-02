import { Injectable, Logger, OnModuleDestroy } from '@nestjs/common';
import { ChildProcessWithoutNullStreams, spawn } from 'node:child_process';
import { resolve } from 'node:path';
import { createInterface } from 'node:readline';

/** Raised when an action failed to compile, threw, or ran too long. */
export class ActionFailedError extends Error {}

/** How long one request may take before the process is taken as stuck. */
const COMPILE_TIMEOUT_MS = 10_000;
const RUN_TIMEOUT_MS = 2_000;

/** The process's heap, all requests together. Past it the process dies. */
const DEFAULT_HEAP_MB = 128;

/**
 * What a platform action's `call` reaches here: a name and its event,
 * answering anything JSON. A throw fails the action with its message.
 */
export type PlatformCall = (
  name: string,
  event: Record<string, unknown>,
) => Promise<unknown>;

interface Answer {
  id: number;
  call?: { seq: number; name: string; event: string };
  evc?: string;
  version?: string;
  patch?: string;
  error?: string;
  tooLong?: boolean;
}

interface Waiting {
  resolve: (answer: Answer) => void;
  reject: (error: Error) => void;
  timer?: NodeJS.Timeout;
  /** Starts (again) the clock on this request. */
  arm: () => void;
  onCall?: PlatformCall;
  /** Calls answered from here and not yet back: the clock stops for them. */
  calling: number;
}

/**
 * The actions' sandbox: one Dart process beside this one (`runner/`, the
 * same dart_eval the app runs), given an action's source to compile or its
 * bytecode to run, in JSON lines.
 *
 * The code is untrusted (the person's words reached the model that wrote
 * it), so it never runs in this process: dart_eval grants it no files,
 * network or processes, stops it past a step budget, and the process's
 * heap is capped. A process that dies or hangs fails what it was doing and
 * is started again on the next request.
 *
 * `ACTION_RUNNER` is the runner's executable (default: the one
 * `npm run runner:build` writes), `ACTION_RUNNER_HEAP_MB` its heap.
 */
@Injectable()
export class ActionRunner implements OnModuleDestroy {
  private readonly _log = new Logger(ActionRunner.name);
  private _process?: ChildProcessWithoutNullStreams;
  private readonly _waiting = new Map<number, Waiting>();
  private _next = 0;
  private _version?: Promise<string>;

  /**
   * Compiles [code] into the bytecode [run] and the app take, and says
   * which runner wrote it: bytecode only runs on the same one.
   */
  async compile(code: string): Promise<{ evc: string; version: string }> {
    const answer = await this._send(
      { type: 'compile', code },
      COMPILE_TIMEOUT_MS,
    );
    if (answer.evc === undefined || answer.version === undefined) {
      throw new ActionFailedError(answer.error ?? 'did not compile');
    }
    return { evc: answer.evc, version: answer.version };
  }

  /** Which runner this is; bytecode another one wrote must be rewritten. */
  async version(): Promise<string> {
    this._version ??= this._send({ type: 'version' }, COMPILE_TIMEOUT_MS).then(
      (answer) => {
        if (answer.version === undefined)
          throw new ActionFailedError('no version');
        return answer.version;
      },
    );
    return this._version.catch((error: unknown) => {
      this._version = undefined;
      throw error;
    });
  }

  /**
   * Runs the action in [evc] and answers with its JSON Patch. With
   * [onCall] (a platform action), its `call` reaches it; the time spent
   * waiting on it does not count against the run's.
   */
  async run(
    evc: string,
    input: Record<string, unknown>,
    event: Record<string, unknown>,
    onCall?: PlatformCall,
  ): Promise<unknown> {
    const answer = await this._send(
      {
        type: 'run',
        evc,
        input: JSON.stringify(input),
        event: JSON.stringify(event),
        ...(onCall ? { calls: true } : {}),
      },
      RUN_TIMEOUT_MS,
      onCall,
    );
    if (answer.patch === undefined) {
      throw new ActionFailedError(answer.error ?? 'no patch');
    }
    return JSON.parse(answer.patch);
  }

  onModuleDestroy(): void {
    this._process?.kill();
  }

  private _send(
    request: Record<string, unknown>,
    timeoutMs: number,
    onCall?: PlatformCall,
  ): Promise<Answer> {
    const child = this._start();
    const id = this._next++;
    return new Promise<Answer>((resolve, reject) => {
      const waiting: Waiting = {
        resolve,
        reject,
        onCall,
        calling: 0,
        arm: () => {
          clearTimeout(waiting.timer);
          waiting.timer = setTimeout(() => {
            // Stuck: whatever it is doing, start over.
            this._log.warn(
              `action runner took over ${timeoutMs} ms; restarting`,
            );
            child.kill('SIGKILL');
          }, timeoutMs);
        },
      };
      waiting.arm();
      this._waiting.set(id, waiting);
      child.stdin.write(`${JSON.stringify({ ...request, id })}\n`);
    });
  }

  /** Answers a run's `call` with what [waiting.onCall] gives. */
  private async _answerCall(
    child: ChildProcessWithoutNullStreams,
    id: number,
    waiting: Waiting,
    call: NonNullable<Answer['call']>,
  ): Promise<void> {
    // The run waits on us, not on itself: its clock stops meanwhile.
    clearTimeout(waiting.timer);
    waiting.calling++;
    let reply: Record<string, unknown>;
    try {
      if (!waiting.onCall) throw new Error('this action calls nothing');
      const event = JSON.parse(call.event) as Record<string, unknown>;
      const result = await waiting.onCall(call.name, event);
      reply = { result: JSON.stringify(result ?? null) };
    } catch (error) {
      reply = { error: error instanceof Error ? error.message : String(error) };
    }
    waiting.calling--;
    if (this._waiting.get(id) !== waiting) return;
    if (waiting.calling === 0) waiting.arm();
    child.stdin.write(
      `${JSON.stringify({ id, type: 'answer', seq: call.seq, ...reply })}\n`,
    );
  }

  private _start(): ChildProcessWithoutNullStreams {
    if (this._process) return this._process;
    const heap = Number(process.env.ACTION_RUNNER_HEAP_MB) || DEFAULT_HEAP_MB;
    const child = spawn(
      process.env.ACTION_RUNNER ??
        resolve(process.cwd(), '../runner/build/runner'),
      [],
      {
        env: {
          PATH: process.env.PATH,
          DART_VM_OPTIONS: `--old_gen_heap_size=${heap}`,
        },
        stdio: 'pipe',
      },
    );
    this._process = child;
    // A write to a process that just died fails here; its exit fails the
    // requests.
    child.stdin.on('error', () => undefined);
    createInterface({ input: child.stdout }).on('line', (line) => {
      let answer: Answer;
      try {
        answer = JSON.parse(line) as Answer;
      } catch {
        return;
      }
      const waiting = this._waiting.get(answer.id);
      if (!waiting) return;
      if (answer.call) {
        void this._answerCall(child, answer.id, waiting, answer.call);
        return;
      }
      this._waiting.delete(answer.id);
      clearTimeout(waiting.timer);
      waiting.resolve(answer);
    });
    child.stderr.on('data', (chunk: Buffer) =>
      this._log.warn(chunk.toString().trim()),
    );
    const failAll = (why: string) => {
      if (this._process === child) this._process = undefined;
      for (const [id, waiting] of this._waiting) {
        clearTimeout(waiting.timer);
        waiting.reject(new ActionFailedError(why));
        this._waiting.delete(id);
      }
    };
    child.on('exit', (code, signal) =>
      failAll(`action runner exited (${signal ?? code})`),
    );
    child.on('error', (error) =>
      failAll(`action runner did not start: ${error.message}`),
    );
    return child;
  }
}
