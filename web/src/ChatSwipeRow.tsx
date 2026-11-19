import React, { useRef, useState } from "react";
import { ActionButton } from "./Controls";
import type { ShortActions } from "./Shorts";
import type { ChatEntry } from "./types";

type Props = Pick<ShortActions, "act" | "busy"> & {
  last: ChatEntry;
  name: string;
  pinned: boolean;
  unread: boolean;
  expanded: boolean;
  reveal(id: string | null): void;
  children: React.ReactNode;
};

export function ChatSwipeRow({ last, name, pinned, unread, expanded, reveal, busy, act, children }: Props) {
  const [drag, setDrag] = useState<number | null>(null);
  const rail = useRef<HTMLDivElement>(null);
  const gesture = useRef<{ id: number; x: number; y: number; horizontal: boolean } | null>(null);
  const suppressClick = useRef(false);
  const peerID = last.peerID;

  function move(event: React.PointerEvent<HTMLDivElement>) {
    const start = gesture.current;
    if (!start || event.pointerId !== start.id || !rail.current) return;
    const dx = event.clientX - start.x;
    const dy = event.clientY - start.y;
    if (!start.horizontal) {
      if (Math.max(Math.abs(dx), Math.abs(dy)) < 7) return;
      if (Math.abs(dx) <= Math.abs(dy)) { gesture.current = null; return; }
      start.horizontal = true;
      event.currentTarget.setPointerCapture(start.id);
      suppressClick.current = true;
    }
    const width = rail.current.offsetWidth;
    setDrag(Math.min(width, Math.max(0, (expanded ? width : 0) - dx)));
  }

  async function change(command: "setChatPinned" | "setChatUnread" | "deleteConversation") {
    if (busy) return;
    if (command === "deleteConversation" && !confirm(`Delete all messages with ${name} on this iPhone?`)) return;
    const payload = command === "deleteConversation" ? { peerID, lastEntryID: last.id }
      : { peerID, enabled: command === "setChatPinned" ? !pinned : !unread };
    if (await act(command, payload)) reveal(null);
  }

  const railID = "chat-actions-" + peerID;
  const style = drag === null ? undefined : { "--chat-reveal": drag + "px" } as React.CSSProperties;
  return <li data-chat-peer={peerID} className={`swipe-chat${expanded ? " expanded" : ""}${drag !== null ? " dragging" : ""}`}
    style={style} onKeyDown={event => { if (event.key === "Escape") { reveal(null); } }}>
    <div className="chat-foreground"
      onDragStart={event => event.preventDefault()}
      onContextMenu={event => { event.preventDefault(); reveal(peerID); }}
      onPointerDown={event => {
        if (!event.isPrimary || event.button !== 0) return;
        suppressClick.current = false;
        gesture.current = { id: event.pointerId, x: event.clientX, y: event.clientY, horizontal: false };
      }}
      onPointerMove={move}
      onPointerUp={event => {
        const start = gesture.current;
        if (!start || event.pointerId !== start.id) return;
        if (start.horizontal) {
          const dx = event.clientX - start.x;
          if (dx < -24) reveal(peerID);
          if (dx > 24) reveal(null);
        }
        setDrag(null);
        gesture.current = null;
      }}
      onPointerCancel={() => { gesture.current = null; setDrag(null); }}
      onClickCapture={event => {
        if ((suppressClick.current && event.detail !== 0) || expanded) {
          event.stopPropagation();
          if (!suppressClick.current || event.detail === 0) reveal(null);
          suppressClick.current = false;
        }
      }}>
      {children}
      <ActionButton icon="more" className="chat-access-actions" aria-expanded={expanded} aria-controls={railID}
        onClick={() => reveal(peerID)}>Actions for {name}</ActionButton>
    </div>
    <div ref={rail} className="chat-swipe-actions" id={railID} role="group" aria-label={`Conversation actions for ${name}`}
      aria-hidden={!expanded}>
      <button type="button" disabled={busy || !expanded} onClick={() => void change("setChatPinned")}>{pinned ? "Unpin" : "Pin"}</button>
      <button type="button" disabled={busy || !expanded} onClick={() => void change("setChatUnread")}>{unread ? "Mark read" : "Mark unread"}</button>
      <button type="button" className="chat-delete" disabled={busy || !expanded} onClick={() => void change("deleteConversation")}>Delete</button>
    </div>
  </li>;
}
