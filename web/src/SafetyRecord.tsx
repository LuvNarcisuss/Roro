import React, { useEffect, useRef } from "react";
import { Glyph } from "./Controls";

export default function SafetyRecord({ label, action, blocked, busy, openProfile, undo }: {
  label: string;
  action: string;
  blocked?: boolean;
  busy: boolean;
  openProfile?(): void;
  undo(): void;
}) {
  const timer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  const start = useRef({ x: 0, y: 0 });
  const held = useRef(false);
  function cancel() {
    clearTimeout(timer.current);
  }
  useEffect(() => cancel, []);
  function confirmUndo() {
    if (!busy && confirm(action + "?")) undo();
  }
  return (
    <div className="setting-row safety-record"
      onContextMenu={event => event.preventDefault()}
      onPointerDown={event => {
        cancel();
        held.current = false;
        start.current = { x: event.clientX, y: event.clientY };
        timer.current = setTimeout(() => { held.current = true; confirmUndo(); }, 600);
      }}
      onPointerMove={event => {
        if (Math.hypot(event.clientX - start.current.x, event.clientY - start.current.y) > 8) cancel();
      }}
      onPointerCancel={cancel} onPointerLeave={cancel} onPointerUp={cancel}
      onClickCapture={event => {
        if (held.current && event.detail !== 0) {
          event.preventDefault();
          event.stopPropagation();
        }
        held.current = false;
      }}>
      {openProfile ? <button className="author" onClick={openProfile}>{label}</button> : <span>{label}</span>}
      <button className="block-action" disabled={busy} aria-label={action} onClick={confirmUndo}>
        {blocked ? <span aria-hidden="true">🚫</span> : <Glyph name="close" />}
      </button>
    </div>
  );
}
