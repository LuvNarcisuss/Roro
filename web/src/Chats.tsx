import React, { useEffect, useRef, useState } from "react";
import { ChatSwipeRow } from "./ChatSwipeRow";
import { ActionButton, Glyph } from "./Controls";
import { authors, isBlocked } from "./community";
import type { ShortActions } from "./Shorts";
import type { ChatEntry, Snapshot } from "./types";

export type ChatScope = "Recent" | "Friends" | "Archived";
type PeopleProps = {
  state: Snapshot;
  profile(id: string): void;
  open(id: string): void;
};
type Person = typeof authors[number];

function Avatar({ person, profile }: { person: Person; profile(id: string): void }) {
  return <button className="chat-avatar" aria-label={`View ${person.name}'s profile`} onClick={() => profile(person.id)}>
    <img src={person.avatar} alt="" />
  </button>;
}

function Stamp({ iso }: { iso: string }) {
  const date = new Date(iso);
  const label = date.toDateString() === new Date().toDateString()
    ? date.toLocaleTimeString("en", { hour: "numeric", minute: "2-digit" })
    : date.toLocaleDateString("en", { month: "short", day: "numeric" });
  return <time dateTime={iso} aria-label={date.toLocaleString("en")}>{label}</time>;
}

export function ChatList({ state, scope, select, query, open, profile, findFriends, act, busy }: PeopleProps & Pick<ShortActions, "act" | "busy"> & {
  scope: ChatScope; select(value: ChatScope): void; query: string; findFriends(): void;
}) {
  const [revealed, reveal] = useState<string | null>(null);
  useEffect(() => { reveal(null); }, [scope, query]);
  useEffect(() => {
    if (!revealed) return;
    function closeOutside(event: PointerEvent) {
      const row = event.target instanceof Element ? event.target.closest<HTMLElement>("[data-chat-peer]") : null;
      if (row?.dataset.chatPeer !== revealed) reveal(null);
    }
    document.addEventListener("pointerdown", closeOutside, true);
    return () => document.removeEventListener("pointerdown", closeOutside, true);
  }, [revealed]);
  const latest = new Map<string, ChatEntry>();
  for (const entry of state.chatEntries ?? []) latest.set(entry.peerID, entry);
  const term = query.trim().toLowerCase();
  const people = authors.filter(person => {
    if (isBlocked(person.id, state)) return false;
    const last = latest.get(person.id);
    const inScope = scope === "Friends" ? state.messagingPeers?.includes(person.id)
      : last && Boolean(state.archivedChats?.includes(person.id)) === (scope === "Archived");
    return inScope && [person.name, person.handle, last?.text].some(s => s?.toLowerCase().includes(term));
  });
  // The native journal appends entries in order, even when timestamps share a second.
  const recentOrder = new Map<string, number>();
  (state.chatEntries ?? []).forEach((entry, index) => recentOrder.set(entry.peerID, index));
  const pinRanks = new Map((state.pinnedChats ?? []).map((id, index) => [id, index + 1]));
  people.sort((a, b) => {
    const pinOrder = (pinRanks.get(b.id) ?? 0) - (pinRanks.get(a.id) ?? 0);
    if (pinOrder) return pinOrder;
    return scope === "Friends" ? a.name.localeCompare(b.name)
      : (recentOrder.get(b.id) ?? -1) - (recentOrder.get(a.id) ?? -1);
  });
  return <section className="chat-page">
    <div className="segmented chat-scopes" aria-label="Chat categories">
      {(["Recent", "Friends", "Archived"] as const).map(tab =>
        <button key={tab} className={scope === tab ? "selected" : ""} aria-pressed={scope === tab}
          onClick={() => select(tab)}>{tab}</button>)}
    </div>
    {people.length ? <ul className="chat-list">{people.map(person => {
      const last = latest.get(person.id);
      const pinned = pinRanks.has(person.id);
      const unread = !!state.unreadChats?.includes(person.id);
      const row = <>
        <Avatar person={person} profile={profile} />
        <button className="chat-row-body chat-inbox-body" onClick={() => open(person.id)}>
          <span className="chat-inbox-copy"><strong>{person.name}</strong>
            <span className="chat-snippet">{last?.text ?? "@"+person.handle}</span>
          </span>
          {last && <span className="chat-inbox-meta">
            <Stamp iso={last.createdAt} />
            {unread && <span className="chat-unread-mark" role="img" aria-label="1 unread">
              <Glyph name="chat" /><span aria-hidden="true">1</span>
            </span>}
          </span>}
          {pinned && <img className="chat-pin-mark" src="assets/icons/chat-pin.png" alt="Pinned" />}
        </button>
      </>;
      return last ? <ChatSwipeRow key={person.id} last={last} name={person.name} pinned={pinned} unread={unread}
        expanded={revealed === person.id} reveal={reveal} act={act} busy={busy}>{row}</ChatSwipeRow>
        : <li key={person.id}>{row}</li>;
    })}</ul> : <div className="chat-empty">
      <Glyph name={scope === "Friends" ? "add-friend" : "chat"} />
      <h2>{term ? "No matches" : scope === "Recent" ? "No conversations yet" : scope === "Friends" ? "No friends yet" : "No archived chats"}</h2>
      {!term && scope !== "Archived" && <ActionButton icon="add-friend" onClick={findFriends}>Find friends</ActionButton>}
    </div>}
  </section>;
}

type RelationshipProps = Pick<ShortActions, "act" | "busy"> & { state: Snapshot; person: Person };

function RequestActions({ state, person, act, busy }: RelationshipProps) {
  const peerID = person.id;
  if (state.incomingRequests?.includes(peerID)) return <>
    <ActionButton icon="check" disabled={busy} onClick={() => void act("respondFriendRequest", {peerID, accept: true})}>Accept request from {person.name}</ActionButton>
    <ActionButton icon="close" disabled={busy} onClick={() => void act("respondFriendRequest", {peerID, accept: false})}>Decline request from {person.name}</ActionButton>
  </>;
  if (state.verifiedFriends?.includes(peerID)) return <ActionButton icon="close" disabled={busy}
    onClick={() => { if (confirm(`Remove ${person.name} from friends?`)) void act("removeFriend", {peerID}); }}>Remove {person.name} from friends</ActionButton>;
  const pending = !!state.contacts?.includes(peerID);
  if (!pending && state.messagingPeers?.includes(peerID)) return null;
  return <ActionButton icon={pending ? "close" : "add-friend"} disabled={busy}
    onClick={() => void act("setContact", {peerID, enabled: !pending})}>{pending ? "Cancel request to" : "Send friend request to"} {person.name}</ActionButton>;
}

function relationshipLabel(person: Person, state: Snapshot) {
  if (state.incomingRequests?.includes(person.id)) return "Friend request";
  if (state.verifiedFriends?.includes(person.id)) return "Friends";
  if (state.messagingPeers?.includes(person.id)) return "Mutual follow";
  if (state.contacts?.includes(person.id)) return "Request pending";
  if (state.followers?.includes(person.id)) return "Follows you";
  return "@" + person.handle;
}

export function FindFriends({ state, query, profile, open, act, busy }: PeopleProps & Pick<ShortActions, "act" | "busy"> & { query: string }) {
  const term = query.trim().replace(/^@/, "").toLowerCase();
  const people = authors.filter(person => !isBlocked(person.id, state) && (term
    ? (person.name + " " + person.handle).toLowerCase().includes(term)
    : state.incomingRequests?.includes(person.id) || state.contacts?.includes(person.id)));
  return <section className="chat-page"><h2>{term ? "Search results" : "Friend requests"}</h2><ul className="chat-list">{people.map(person =>
    <li key={person.id}>
      <Avatar person={person} profile={profile} />
      <button className="chat-row-body" onClick={() => profile(person.id)}>
        <strong>{person.name}</strong><span className="chat-snippet">{relationshipLabel(person, state)}</span>
      </button>
      {state.messagingPeers?.includes(person.id) && <ActionButton icon="chat" onClick={() => open(person.id)}>Message {person.name}</ActionButton>}
      <RequestActions {...{state, person, act, busy}} />
    </li>
  )}</ul>{!people.length && <p className="chat-empty">{term ? "No matching people." : "No friend requests."}</p>}</section>;
}

export function Conversation({ state, peerID, profile, act, busy, preview }: Pick<PeopleProps,"state" | "profile"> & Pick<ShortActions,"act" | "busy"> & {
  peerID: string; preview(peerID: string, mode: "voice" | "video"): void;
}) {
  const [text, setText] = useState("");
  const end = useRef<HTMLDivElement>(null);
  const pendingID = useRef("");
  const saving = useRef(false);
  const person = authors.find(p => p.id === peerID);
  const entries = (state.chatEntries ?? []).filter(m => m.peerID === peerID);
  const eligible = !!state.messagingPeers?.includes(peerID);
  const archived = !!state.archivedChats?.includes(peerID);
  useEffect(() => { end.current?.scrollIntoView({ block: "nearest" }); }, [entries.length]);
  if (!person || isBlocked(peerID,state)) return <p className="chat-empty">Conversation unavailable.</p>;
  async function save() {
    if (!eligible || !text.trim() || busy || saving.current) return;
    saving.current = true;
    try {
      pendingID.current ||= crypto.randomUUID();
      if (await act("saveChatEntry", { id: pendingID.current, peerID, text: text.trim() })) {
        setText(""); pendingID.current = "";
      }
    } finally { saving.current = false; }
  }
  return <section className="chat-thread">
    <div className="chat-identity">
      <Avatar person={person} profile={profile}/>
      <div className="chat-row-body"><strong>{person.name}</strong><span className="chat-snippet">@{person.handle}</span></div>
      {eligible && <>
        <ActionButton icon="voice-call" disabled={busy} onClick={() => preview(peerID, "voice")}>Voice call</ActionButton>
        <ActionButton icon="video-call" disabled={busy} onClick={() => preview(peerID, "video")}>Video call</ActionButton>
      </>}
      {!!entries.length && <ActionButton icon={archived ? "bookmark" : "bookmark-outline"} aria-pressed={archived} disabled={busy}
        onClick={() => void act("setChatArchived", { peerID, enabled: !archived })}>{archived ? "Unarchive conversation" : "Archive conversation"}</ActionButton>}
    </div>
    <div className="chat-timeline">
      {!entries.length && <p className="chat-empty">No messages yet</p>}
      {entries.map(m => <div className="chat-bubble" key={m.id}><p>{m.text}</p><Stamp iso={m.createdAt}/></div>)}
      <div ref={end} />
    </div>
    {eligible ? <form className="chat-composer" onSubmit={e => { e.preventDefault(); void save(); }}>
      <textarea aria-label="Message" placeholder="Write a message…" rows={1} maxLength={2000} disabled={busy}
        value={text} onChange={e => { pendingID.current = ""; setText(e.target.value); }} />
      <ActionButton type="submit" icon="check" disabled={busy || !text.trim()}>Send message</ActionButton>
    </form> : <div className="chat-composer chat-request">
      <span>{state.incomingRequests?.includes(peerID) || state.contacts?.includes(peerID) ? relationshipLabel(person, state) : "Friend approval required"}</span>
      <RequestActions {...{state, person, act, busy}} />
    </div>}
  </section>;
}
