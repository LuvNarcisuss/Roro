import type { ShortActions } from "./Shorts";

type ReportTarget = { kind: "video" | "post"; id: string } | { kind: "comment"; id: string; postID: string };

export async function reportContent(act: ShortActions["act"], target: ReportTarget) {
  if (!window.confirm(`Report this ${target.kind} and hide it for this account?`)) return false;
  if (!await act("setReport", { ...target, enabled: true })) return false;
  // Let WebKit paint the updated list before the native alert pauses the page.
  await new Promise<void>(resolve => requestAnimationFrame(() => requestAnimationFrame(() => resolve())));
  window.alert("Report saved for this account.");
  return true;
}
