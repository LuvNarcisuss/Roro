import type { ShortActions } from "./Shorts";

type ReportTarget = { kind: "video" | "post"; id: string } | { kind: "comment"; id: string; postID: string };

export async function reportContent(act: ShortActions["act"], target: ReportTarget) {
  if (!window.confirm(`Save a report on this iPhone and hide this ${target.kind}? Reports stay on this device.`)) return false;
  if (!await act("setReport", { ...target, enabled: true })) return false;
  // Let WebKit paint the updated list before the native alert pauses the page.
  await new Promise<void>(resolve => requestAnimationFrame(() => requestAnimationFrame(() => resolve())));
  window.alert("Report saved successfully. Your report is stored only on this iPhone.");
  return true;
}
