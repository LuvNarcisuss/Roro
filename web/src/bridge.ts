import type { Command } from "./types";
declare global {
  interface Window {
    roroActive?: boolean;
    ReactNativeWebView?: { postMessage(message: string): void };
    roroReply?: (reply: {
      id: string;
      result?: unknown;
      error?: string;
    }) => void;
  }
}
const pending = new Map<
  string,
  {
    resolve(value: unknown): void;
    reject(reason: Error): void;
    timer: ReturnType<typeof setTimeout>;
  }
>();
window.roroReply = (reply) => {
  const request = pending.get(reply.id);
  if (!request) return;
  clearTimeout(request.timer);
  pending.delete(reply.id);
  if (reply.error) request.reject(new Error(reply.error));
  else request.resolve(reply.result);
};
export function native<T>(
  command: Command,
  payload: Record<string, unknown> = {},
): Promise<T> {
  return new Promise((resolve, reject) => {
    if (!window.ReactNativeWebView)
      return reject(
        new Error("Open Roro on your iPhone to access your library."),
      );
    const id = crypto.randomUUID();
    const timer = setTimeout(
      () => {
        pending.delete(id);
        reject(
          new Error(
            "This is taking longer than expected. Your saved moments are safe.",
          ),
        );
      },
      command === "pickVideo" ? 900000 : 180000,
    );
    pending.set(id, { resolve: (value) => resolve(value as T), reject, timer });
    window.ReactNativeWebView.postMessage(
      JSON.stringify({ id, command, payload }),
    );
  });
}
