import React, { useEffect, useRef, useState } from "react";

const threshold = 64;
const minimumSpinMs = 550;
const labels = {
  idle: "",
  pulling: "Pull to refresh",
  ready: "Release to refresh",
  refreshing: "Refreshing…",
  updated: "Updated",
};
type Status = keyof typeof labels | { error: string };

export default function PullToRefresh({
  refresh,
  shorts = false,
}: {
  refresh(): Promise<void>;
  shorts?: boolean;
}) {
  const anchor = useRef<HTMLDivElement>(null);
  const refreshRef = useRef(refresh);
  refreshRef.current = refresh;
  const [status, setStatus] = useState<Status>("idle");
  const message = typeof status === "string" ? labels[status] : status.error;
  const spinning = status === "pulling" || status === "ready" || status === "refreshing";

  useEffect(() => {
    const content = anchor.current?.parentElement;
    if (!content) return;
    let start: { x: number; y: number; id: number } | undefined;
    let refreshing = false;
    let active = true;
    let dismiss: ReturnType<typeof setTimeout> | undefined;

    function cancel() {
      if (start) setStatus("idle");
      start = undefined;
    }

    function begin(event: TouchEvent) {
      cancel();
      const target = event.target;
      if (refreshing || event.touches.length !== 1 || content!.scrollTop > 0 ||
          !(target instanceof Element) || target.closest("input, textarea, select, dialog")) return;
      if (shorts && !target.closest(".feed-surface[data-first-video], .feed-empty")) return;
      const touch = event.touches[0];
      start = { x: touch.clientX, y: touch.clientY, id: touch.identifier };
    }

    function distance(touch: Touch) {
      if (!start || start.id !== touch.identifier) return 0;
      const dy = touch.clientY - start.y;
      const dx = Math.abs(touch.clientX - start.x);
      if (dy < -7 || (dx > 7 && dx >= Math.abs(dy))) {
        cancel();
        return 0;
      }
      return dy > dx ? dy : 0;
    }

    function move(event: TouchEvent) {
      if (event.touches.length !== 1) return cancel();
      const dy = distance(event.touches[0]);
      if (dy <= 7) {
        if (start) setStatus("idle");
        return;
      }
      if (event.cancelable) event.preventDefault();
      clearTimeout(dismiss);
      setStatus(dy >= threshold ? "ready" : "pulling");
    }

    async function finish(event: TouchEvent) {
      if (!start) return;
      const dy = event.changedTouches.length ? distance(event.changedTouches[0]) : 0;
      cancel();
      if (dy < threshold || refreshing) return;
      refreshing = true;
      clearTimeout(dismiss);
      setStatus("refreshing");
      const started = performance.now();
      let result: Status = "updated";
      try {
        await refreshRef.current();
      } catch (error) {
        result = { error: error instanceof Error ? error.message : "Could not refresh." };
      }
      if (!active) return;
      // Let fast local reads show a visible turn without delaying the data update.
      dismiss = setTimeout(() => {
        refreshing = false;
        setStatus(result);
        dismiss = setTimeout(() => setStatus("idle"), 1800);
      }, Math.max(0, minimumSpinMs - (performance.now() - started)));
    }

    content.addEventListener("touchstart", begin, { passive: true });
    content.addEventListener("touchmove", move, { passive: false });
    content.addEventListener("touchend", finish);
    content.addEventListener("touchcancel", cancel);
    return () => {
      active = false;
      clearTimeout(dismiss);
      content.removeEventListener("touchstart", begin);
      content.removeEventListener("touchmove", move);
      content.removeEventListener("touchend", finish);
      content.removeEventListener("touchcancel", cancel);
    };
  }, [shorts]);

  return (
    <div ref={anchor} className="pull-refresh" role="status" aria-live="polite" aria-atomic="true">
      {message && (
        <span className="pull-refresh-label">
          {spinning && <span className="pull-refresh-spinner" aria-hidden="true" />}
          {message}
        </span>
      )}
    </div>
  );
}
