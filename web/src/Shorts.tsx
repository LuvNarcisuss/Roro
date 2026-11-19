import React, { useEffect, useRef, useState } from "react";
import ShortFeed from "./ShortFeed";
import PageHeader from "./PageHeader";
import { ActionButton, ReactionButton, type SearchState } from "./Controls";
import { native } from "./bridge";
import { topics } from "./catalog";
import { authorFor, engagement } from "./community";
import type { Command, ImportedVideo, ShortVideo, Snapshot } from "./types";

export type ShortActions = {
  state: Snapshot;
  busy: boolean;
  act(command: Command, payload?: Record<string, unknown>): Promise<boolean>;
  notify(message: string): void;
};
function durationLabel(seconds: number) {
  const rounded = Math.ceil(seconds);
  return `${Math.floor(rounded / 60)}:${String(rounded % 60).padStart(2, "0")}`;
}
async function play(video: string, notify: (text: string) => void) {
  try {
    await native("playVideo", { video });
  } catch (error) {
    notify((error as Error).message);
  }
}
export function ShortList({
  items,
  state,
  busy,
  act,
  notify,
  open,
  profile,
}: ShortActions & {
  items: ShortVideo[];
  open(id: string): void;
  profile(id?: string): void;
}) {
  return (
    <div className="short-list">
      {items.map((short) => (
        <article className="short-card" key={short.id}>
          <button
            className="short-cover"
            aria-label={`Play ${short.caption || "your short"}`}
            onClick={() => open(short.id)}
          >
            <img
              className="short-poster"
              src={short.poster}
              alt={short.caption || "Video cover"}
              loading="lazy"
            />
            <span className="short-play">
              <img src="assets/icons/shorts.png" alt="" />
              <span className="sr-only">Play</span>
            </span>
            <span className="short-duration">
              {durationLabel(short.duration)}
            </span>
          </button>
          <div className="short-copy">
            <div className="short-byline">
              <button
                className="short-member"
                onClick={() => profile(short.authorID)}
              >
                <img src={authorFor(short.authorID, state).avatar} alt="" />
                <strong>{authorFor(short.authorID, state).name}</strong>
              </button>
              <span>
                {new Date(short.createdAt).toLocaleDateString("en", {
                  month: "short",
                  day: "numeric",
                })}
              </span>
            </div>
            {short.caption && <p>{short.caption}</p>}
            {short.topic && <span className="short-topic">{short.topic}</span>}
            <div className="short-actions">
              <ReactionButton
                kind="like"
                aria-label="Like short"
                selected={state.likes.includes(short.id)}
                count={engagement(short.id, state).likes}
                disabled={busy}
                onClick={() => void act("toggleLike", { id: short.id })}
              />
              <ReactionButton
                kind="save"
                aria-label="Save short"
                selected={state.saves.includes(short.id)}
                count={engagement(short.id, state).saves}
                disabled={busy}
                onClick={() => void act("toggleSave", { id: short.id })}
              />
              <ActionButton
                icon="share"
                onClick={async () => {
                  try {
                    await native("sharePhoto", { image: short.video });
                  } catch (error) {
                    notify((error as Error).message);
                  }
                }}
              >
                Share
              </ActionButton>
              <ActionButton
                icon="chat"
                count={engagement(short.id, state).comments}
                onClick={() => open(short.id)}
                aria-label="Open short and comments"
              >
                {engagement(short.id, state).comments} comments
              </ActionButton>
              {!short.authorID && (
                <ActionButton
                  icon="trash"
                  className="danger"
                  disabled={busy}
                  onClick={async () => {
                    if (
                      confirm(
                        "Delete this short from Roro? Your original video is kept.",
                      )
                    ) {
                      if (await act("deleteShort", { id: short.id })) {
                        try {
                          await native("discardVideo", { video: short.video });
                        } catch {
                          /* Startup cleanup retries unreferenced media. */
                        }
                        notify("Short deleted.");
                      }
                    }
                  }}
                >
                  Delete
                </ActionButton>
              )}
            </div>
          </div>
        </article>
      ))}
    </div>
  );
}

function ShortComposer({
  initialTopic,
  onClose,
  ...actions
}: ShortActions & { initialTopic: string; onClose(savedID?: string): void }) {
  const [video, setVideo] = useState<ImportedVideo>();
  const [caption, setCaption] = useState("");
  const [topic, setTopic] = useState(initialTopic);
  const [importing, setImporting] = useState(false);
  const [error, setError] = useState("");
  const dialog = useRef<HTMLDialogElement>(null);
  const id = useRef(crypto.randomUUID());
  const pending = importing || actions.busy;
  useEffect(() => {
    dialog.current?.showModal();
  }, []);
  async function close() {
    if (pending) return;
    if (
      (video || caption) &&
      !confirm("Discard this short? Your original video is kept.")
    )
      return;
    if (video) {
      try {
        await native("discardVideo", { video: video.video });
      } catch {
        /* Unreferenced app-owned copies are retried by startup cleanup. */
      }
    }
    onClose();
  }
  async function choose() {
    setImporting(true);
    setError("");
    try {
      const selected = await native<ImportedVideo | null>("pickVideo");
      if (selected) {
        if (video)
          await native("discardVideo", { video: video.video }).catch(() => {});
        setVideo(selected);
      }
    } catch (failure) {
      setError((failure as Error).message);
    } finally {
      setImporting(false);
    }
  }
  return (
    <dialog
      ref={dialog}
      className="short-composer"
      onCancel={(event) => {
        event.preventDefault();
        void close();
      }}
      aria-labelledby="short-composer-title"
    >
      <PageHeader title="A little motion" titleId="short-composer-title">
        <ActionButton
          icon="close"
          disabled={pending}
          onClick={() => void close()}
        >
          Close
        </ActionButton>
      </PageHeader>
      <div className="short-compose-body">
        <p className="muted">
          Keep a little piece of your day. Up to 60 seconds.
        </p>
        {video && (
          <button
            className="short-preview"
            aria-label="Preview selected video"
            onClick={() => void play(video.video, setError)}
          >
            <img src={video.poster} alt="Selected video cover" />
            <span>
              <img className="icon" src="assets/icons/shorts.png" alt="" />
              <span className="sr-only">Preview</span>{" "}
              {durationLabel(video.duration)}
            </span>
          </button>
        )}
        <ActionButton
          icon="plus"
          className="secondary wide"
          disabled={pending}
          onClick={() => void choose()}
        >
          {importing
            ? "Preparing your video…"
            : video
              ? "Choose another video"
              : "Choose a video"}
        </ActionButton>
        <p role="status" className="short-error">
          {error}
        </p>
        <label className="field">
          <span>A few words</span>
          <textarea
            disabled={pending}
            value={caption}
            maxLength={500}
            placeholder="The little things in motion…"
            onChange={(event) => setCaption(event.target.value)}
          />
        </label>
        <label className="field">
          <span>Topic · optional</span>
          <select
            disabled={pending}
            value={topic}
            onChange={(event) => setTopic(event.target.value)}
          >
            <option value="">No topic</option>
            {topics.map((item) => (
              <option key={item}>{item}</option>
            ))}
          </select>
        </label>
        <p className="muted">
          Your short stays in your library on this iPhone.
        </p>
        <ActionButton
          icon="check"
          className="primary wide"
          disabled={pending || !video}
          onClick={async () => {
            if (!video) return;
            if (
              await actions.act("saveShort", {
                id: id.current,
                ...video,
                caption,
                topic,
              })
            ) {
              actions.notify("Short saved to your library.");
              onClose(id.current);
            } else
              setError(
                "Your short could not be saved. Keep this page open and try again.",
              );
          }}
        >
          {actions.busy ? "Saving…" : "Save short"}
        </ActionButton>
      </div>
    </dialog>
  );
}

export default function Shorts({
  reloadLibrary,
  initialTopic = "",
  selectedID,
  profile,
  openTopic,
  onLeave,
  search,
  changeSearch,
  back,
  ...actions
}: ShortActions & {
  reloadLibrary(): Promise<Snapshot>;
  initialTopic?: string;
  selectedID?: string;
  profile(id?: string): void;
  openTopic(topic: string): void;
  onLeave(videoID: string, topic: string): void;
  search: SearchState;
  changeSearch(value: SearchState): void;
  back?(): void;
}) {
  const [composing, setComposing] = useState(false);
  const [composeTopic, setComposeTopic] = useState(initialTopic);
  const [savedID, setSavedID] = useState(selectedID);
  return (
    <>
      <ShortFeed
        reloadLibrary={reloadLibrary}
        {...actions}
        initialTopic={initialTopic}
        selectedID={savedID}
        suspended={composing}
        profile={profile}
        openTopic={openTopic}
        onLeave={onLeave}
        search={search}
        changeSearch={changeSearch}
        back={back}
        compose={(topic) => {
          setComposeTopic(topic);
          setComposing(true);
        }}
      />
      {composing && (
        <ShortComposer
          {...actions}
          initialTopic={composeTopic}
          onClose={(id) => {
            if (id) {
              changeSearch({ open: false, query: "" });
              setSavedID(id);
            }
            setComposing(false);
          }}
        />
      )}
    </>
  );
}
