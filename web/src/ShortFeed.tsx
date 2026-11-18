import React, { useEffect, useRef, useState } from "react";
import { native } from "./bridge";
import PullToRefresh from "./PullToRefresh";
import { rotateItems, topics } from "./catalog";
import { authorFor, engagement, visibleShorts } from "./community";
import Comments from "./Comments";
import PageHeader from "./PageHeader";
import { ActionButton, ReactionButton, ToolbarSearch, type SearchState } from "./Controls";
import type { ShortVideo } from "./types";
import type { ShortActions } from "./Shorts";

function Glyph({ name }: { name: string }) {
  return <img className="icon" src={`assets/icons/${name}.png`} alt="" />;
}
function clock(seconds: number) {
  const whole = Math.max(0, Math.floor(seconds));
  return `${Math.floor(whole / 60)}:${String(whole % 60).padStart(2, "0")}`;
}
function Panel({
  title,
  close,
  children,
}: {
  title: string;
  close(): void;
  children: React.ReactNode;
}) {
  const dialog = useRef<HTMLDialogElement>(null);
  useEffect(() => {
    dialog.current?.showModal();
  }, []);
  return (
    <dialog
      ref={dialog}
      className="feed-panel"
      aria-label={title}
      onCancel={(event) => {
        event.preventDefault();
        close();
      }}
    >
      <header>
        <h2>{title}</h2>
        <ActionButton icon="close" labelPosition="below" onClick={close}>
          Close
        </ActionButton>
      </header>
      {children}
    </dialog>
  );
}

// A single WKWebView video owns feed playback; native services export its saved file.
function FeedVideo({
  clip,
  paused,
  muted,
  videoRef,
  progress,
  failed,
  blocked,
}: {
  clip: ShortVideo;
  paused: boolean;
  muted: boolean;
  videoRef: React.RefObject<HTMLVideoElement | null>;
  progress(time: number, duration: number): void;
  failed(message: string): void;
  blocked(): void;
}) {
  const [source, setSource] = useState<string>();
  const [loading, setLoading] = useState(true);
  const callbacks = useRef({ failed, blocked });
  callbacks.current = { failed, blocked };
  useEffect(() => {
    let alive = true;
    native<string>("videoSource", { id: clip.id })
      .then((uri) => {
        if (alive) setSource(uri);
      })
      .catch((error: Error) => {
        if (alive) {
          setLoading(false);
          callbacks.current.failed(error.message);
        }
      });
    return () => {
      alive = false;
    };
  }, [clip.id]);
  useEffect(() => {
    const video = videoRef.current;
    if (!video || !source) return;
    let alive = true;
    let attempt = 0;
    function sync() {
      const current = ++attempt;
      if (paused || document.hidden || window.roroActive === false) {
        video!.pause();
        return;
      }
      void video!.play().catch(() => {
        if (
          alive &&
          current === attempt &&
          !document.hidden &&
          window.roroActive !== false
        )
          callbacks.current.blocked();
      });
    }
    sync();
    document.addEventListener("visibilitychange", sync);
    window.addEventListener("roro-playback", sync);
    return () => {
      alive = false;
      attempt += 1;
      video.pause();
      document.removeEventListener("visibilitychange", sync);
      window.removeEventListener("roro-playback", sync);
    };
  }, [paused, source, videoRef]);
  useEffect(() => {
    const element = videoRef.current;
    return () => {
      element?.pause();
      element?.removeAttribute("src");
      element?.load();
    };
  }, [videoRef]);
  return (
    <div className="feed-video-layer">
      <video
        ref={videoRef}
        src={source}
        poster={clip.poster}
        playsInline
        loop
        muted={muted}
        preload="auto"
        onLoadedMetadata={(event) => {
          const element = event.currentTarget;
          progress(
            0,
            Number.isFinite(element.duration)
              ? element.duration
              : clip.duration,
          );
        }}
        onCanPlay={() => setLoading(false)}
        onPlaying={() => setLoading(false)}
        onWaiting={() => setLoading(true)}
        onTimeUpdate={(event) => {
          const element = event.currentTarget;
          progress(
            element.currentTime,
            Number.isFinite(element.duration)
              ? element.duration
              : clip.duration,
          );
        }}
        onError={() => {
          setLoading(false);
          callbacks.current.failed(
            "This video could not be played. Try again.",
          );
        }}
      />
      {loading && (
        <span className="feed-loading" role="status">
          Opening video…
        </span>
      )}
    </div>
  );
}

export default function ShortFeed({
  reloadLibrary,
  initialTopic = "",
  selectedID,
  suspended,
  compose,
  profile,
  openTopic,
  onLeave,
  search,
  changeSearch,
  back,
  ...actions
}: ShortActions & {
  reloadLibrary(): Promise<void>;
  initialTopic?: string;
  selectedID?: string;
  suspended: boolean;
  compose(topic: string): void;
  profile(id?: string): void;
  openTopic(topic: string): void;
  onLeave(videoID: string, topic: string): void;
  search: SearchState;
  changeSearch(value: SearchState): void;
  back?(): void;
}) {
  const all = visibleShorts(actions.state);
  const [filter, setFilter] = useState(initialTopic);
  const [turn, setTurn] = useState(0);
  const items = rotateItems(all.filter(
    (clip) =>
      (!filter || clip.topic === filter) &&
      `${clip.caption} ${clip.topic} ${authorFor(clip.authorID, actions.state).name}`
        .toLowerCase()
        .includes(search.query.trim().toLowerCase()),
  ), turn);
  const [currentID, setCurrentID] = useState(selectedID);
  const index = Math.max(
    0,
    items.findIndex((clip) => clip.id === currentID),
  );
  const clip = items[index];
  const [paused, setPaused] = useState(false);
  const [muted, setMuted] = useState(true);
  const [panel, setPanel] = useState<"comments" | "notes" | "more">();
  const [searchFocused, setSearchFocused] = useState(false);
  const [note, setNote] = useState("");
  const [position, setPosition] = useState({ time: 0, duration: 0 });
  const [failure, setFailure] = useState("");
  const [retry, setRetry] = useState(0);
  const [offset, setOffset] = useState(0);
  const [settling, setSettling] = useState(false);
  const stage = useRef<HTMLDivElement>(null);
  const video = useRef<HTMLVideoElement>(null);
  const origin = useRef<
    { x: number; y: number; axis?: "vertical" | "horizontal" } | undefined
  >(undefined);
  const settleTimer = useRef<ReturnType<typeof setTimeout> | undefined>(
    undefined,
  );
  const tapTimer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  const lastTap = useRef(0);
  const lastSwipe = useRef(0);
  const settlingRef = useRef(false);
  const appliedSelection = useRef<string | undefined>(undefined);
  const reducedMotion = () =>
    window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  useEffect(() => {
    setPaused(false);
    setPosition({ time: 0, duration: clip?.duration ?? 0 });
    setFailure("");
    setNote("");
    return () => {
      if (tapTimer.current) clearTimeout(tapTimer.current);
    };
  }, [clip?.id]);
  useEffect(() => {
    if (!selectedID || appliedSelection.current === selectedID) return;
    const selected = visibleShorts(actions.state).find(
      (item) => item.id === selectedID,
    );
    if (!selected) return;
    appliedSelection.current = selectedID;
    if (filter && selected.topic !== filter) setFilter("");
    setCurrentID(selectedID);
  }, [selectedID, actions.state.shorts, filter]);
  useEffect(() => {
    origin.current = undefined;
    settlingRef.current = false;
    setSettling(false);
    setOffset(0);
    if (settleTimer.current) clearTimeout(settleTimer.current);
    if (tapTimer.current) clearTimeout(tapTimer.current);
    lastTap.current = 0;
  }, [panel, suspended, filter, clip?.id]);
  useEffect(
    () => () => {
      if (settleTimer.current) clearTimeout(settleTimer.current);
      if (tapTimer.current) clearTimeout(tapTimer.current);
    },
    [],
  );
  function settle(direction: number) {
    if (settlingRef.current || panel || suspended) return;
    const next = items[index + direction];
    const height = stage.current?.clientHeight ?? 0;
    settlingRef.current = true;
    setSettling(true);
    setOffset(next && direction ? -direction * height : 0);
    video.current?.pause();
    settleTimer.current = setTimeout(
      () => {
        if (next && direction) setCurrentID(next.id);
        setOffset(0);
        setSettling(false);
        settlingRef.current = false;
      },
      reducedMotion() ? 0 : 220,
    );
  }
  function move(x: number, y: number, end = false) {
    const start = origin.current;
    if (!start || settlingRef.current) return;
    if (end) origin.current = undefined;
    const dx = x - start.x,
      dy = y - start.y;
    if (!start.axis && Math.max(Math.abs(dx), Math.abs(dy)) > 8)
      start.axis = Math.abs(dy) > Math.abs(dx) ? "vertical" : "horizontal";
    if (!start.axis) return;
    lastSwipe.current = Date.now();
    if (tapTimer.current) clearTimeout(tapTimer.current);
    lastTap.current = 0;
    if (start.axis === "horizontal") return;
    if (end) {
      settle(
        Math.abs(dy) > 45 && items[index + (dy < 0 ? 1 : -1)]
          ? dy < 0
            ? 1
            : -1
          : 0,
      );
    } else {
      const height = stage.current?.clientHeight ?? 0;
      setOffset(
        Math.max(-height, Math.min(height, dy)) *
          (items[index + (dy < 0 ? 1 : -1)] ? 1 : 0.18),
      );
    }
  }
  function tap() {
    if (!clip || settlingRef.current || Date.now() - lastSwipe.current < 400)
      return;
    if (Date.now() - lastTap.current < 280) {
      if (tapTimer.current) clearTimeout(tapTimer.current);
      lastTap.current = 0;
      if (!actions.state.likes.includes(clip.id))
        void actions.act("toggleLike", { id: clip.id });
    } else {
      lastTap.current = Date.now();
      tapTimer.current = setTimeout(() => setPaused((value) => !value), 280);
    }
  }
  function visitProfile(id?: string) {
    if (clip) onLeave(clip.id, filter);
    profile(id);
  }
  const author = authorFor(clip?.authorID, actions.state);
  const counts = engagement(clip?.id ?? "", actions.state);
  const notes = actions.state.notes.filter((item) => item.postID === clip?.id);
  return (
    <div ref={stage} className={`short-feed ${settling ? "is-settling" : ""}`}>
      <PullToRefresh shorts refresh={async () => {
        await reloadLibrary();
        setCurrentID(undefined);
        setTurn((value) => value + 1);
      }} />
      <div
        className="feed-pages"
        style={{ transform: `translateY(${offset}px)` }}
      >
        {items[index - 1] && (
          <img
            className="feed-neighbor previous"
            src={items[index - 1].poster}
            alt=""
          />
        )}
        {clip && (
          <FeedVideo
            key={`${clip.id}-${retry}`}
            clip={clip}
            videoRef={video}
            paused={paused || !!panel || suspended || settling || searchFocused}
            muted={muted}
            progress={(time, duration) => setPosition({ time, duration })}
            failed={setFailure}
            blocked={() => setPaused(true)}
          />
        )}
        {items[index + 1] && (
          <img
            className="feed-neighbor next"
            src={items[index + 1].poster}
            alt=""
          />
        )}
      </div>
      <div className="feed-shade" aria-hidden="true" />
      {clip && (
        <button
          className="feed-surface"
          data-first-video={index === 0 && !suspended && !panel ? "" : undefined}
          aria-label={paused ? "Play video" : "Pause video"}
          aria-describedby="feed-gesture-hint"
          onClick={tap}
          onKeyDown={(event) => {
            if (event.key === "ArrowDown" || event.key === "ArrowUp") {
              event.preventDefault();
              settle(event.key === "ArrowDown" ? 1 : -1);
            }
          }}
          onTouchStart={(event) => {
            if (
              event.touches.length === 1 &&
              !settlingRef.current &&
              !panel &&
              !suspended
            )
              origin.current = {
                x: event.touches[0].clientX,
                y: event.touches[0].clientY,
              };
            else {
              origin.current = undefined;
              setOffset(0);
            }
          }}
          onTouchMove={(event) => {
            if (event.touches.length === 1)
              move(event.touches[0].clientX, event.touches[0].clientY);
          }}
          onTouchEnd={(event) => {
            if (event.changedTouches[0])
              move(
                event.changedTouches[0].clientX,
                event.changedTouches[0].clientY,
                true,
              );
          }}
          onTouchCancel={() => {
            origin.current = undefined;
            settle(0);
          }}
        >
          {paused && !failure && (
            <span className="feed-paused">
              <Glyph name="shorts" />
              <span className="sr-only">Tap to play</span>
            </span>
          )}
        </button>
      )}
      <span className="sr-only" id="feed-gesture-hint">
        Swipe up for the next video and down for the previous video. Pull down on the first video to refresh. Tap to
        pause. Double tap to like.
      </span>
      <PageHeader title="Shorts" back={back} showLogo={!back} overlay>
        <ToolbarSearch
          value={search}
          change={changeSearch}
          label="Search shorts or people"
          focusChanged={setSearchFocused}
        />
        <button aria-label="Add a short" onClick={() => compose(filter)}>
          <Glyph name="plus" />
        </button>
      </PageHeader>
      {!clip && (
        <div className="feed-empty">
          <Glyph name="shorts" />
          <h2>
            {search.query.trim()
              ? "No matching shorts"
              : filter
                ? "No shorts in this topic yet"
                : "A little life, in motion"}
          </h2>
          <p>
            {filter
              ? "Explore another topic or add your own clip."
              : search.query.trim()
                ? "Try another name, topic or detail."
                : "Add a favorite video from your camera roll to start watching."}
          </p>
          <ActionButton
            icon="plus"
            className="primary"
            onClick={() => compose(filter)}
          >
            Add a video
          </ActionButton>
          {filter && (
            <ActionButton icon="shorts" onClick={() => setFilter("")}>
              See all shorts
            </ActionButton>
          )}
        </div>
      )}
      {clip && (
        <>
          <div
            className="feed-footer"
            style={{ transform: `translateY(${offset}px)` }}
          >
            <div className="feed-caption">
              <small>
                {index + 1} of {items.length}
              </small>
              <button
                className="feed-author"
                onClick={() => visitProfile(clip.authorID)}
              >
                {author.name}
              </button>
              <p>{clip.caption || "A little moment, kept."}</p>
              {clip.topic && (
                <button
                  className="feed-topic"
                  onClick={() => {
                    onLeave(clip.id, filter);
                    openTopic(clip.topic);
                  }}
                >
                  {clip.topic}
                </button>
              )}
            </div>
            <aside className="feed-rail" aria-label="Video actions">
              <button
                className="feed-avatar"
                aria-label={`Open ${author.name}'s profile`}
                onClick={() => visitProfile(clip.authorID)}
              >
                <img src={author.avatar} alt="" />
              </button>
              <ReactionButton
                kind="like"
                aria-label="Like short"
                selected={actions.state.likes.includes(clip.id)}
                count={counts.likes}
                disabled={actions.busy}
                onClick={() => void actions.act("toggleLike", { id: clip.id })}
              />
              <button
                aria-label={`Open ${counts.comments} comments`}
                onClick={() => setPanel("comments")}
              >
                <Glyph name="chat" />
                <span>{counts.comments}</span>
              </button>
              <ReactionButton
                kind="save"
                aria-label="Save short"
                selected={actions.state.saves.includes(clip.id)}
                count={counts.saves}
                disabled={actions.busy}
                onClick={() => void actions.act("toggleSave", { id: clip.id })}
              />
              <button
                onClick={async () => {
                  setPaused(true);
                  try {
                    await native("sharePhoto", { image: clip.video });
                  } catch (error) {
                    actions.notify((error as Error).message);
                  }
                }}
              >
                <Glyph name="share" />
                <span className="sr-only">Share</span>
              </button>
              <ActionButton
                icon="more"
                aria-label="More video options"
                onClick={() => setPanel("more")}
              >
                More
              </ActionButton>
            </aside>
          </div>
          <div className="feed-transport">
            <div className="feed-timing">
              <ActionButton
                icon={muted ? "mute" : "sound"}
                aria-label={muted ? "Turn sound on" : "Mute video"}
                onClick={() => setMuted((value) => !value)}
              >
                {muted ? "Sound off" : "Sound on"}
              </ActionButton>
              <span>
                {clock(position.time)} /{" "}
                {clock(position.duration || clip.duration)}
              </span>
            </div>
            <input
              type="range"
              aria-label="Video progress"
              aria-valuetext={`${clock(position.time)} of ${clock(position.duration || clip.duration)}`}
              min={0}
              max={position.duration || clip.duration}
              step={0.1}
              value={Math.min(
                position.time,
                position.duration || clip.duration,
              )}
              onChange={(event) => {
                const element = video.current;
                if (element && Number.isFinite(element.duration)) {
                  element.currentTime = Number(event.target.value);
                  setPosition({
                    time: element.currentTime,
                    duration: element.duration,
                  });
                }
              }}
            />
          </div>
          <div className="sr-only">
            <button disabled={index === 0} onClick={() => settle(-1)}>
              Previous video
            </button>
            <button
              disabled={index === items.length - 1}
              onClick={() => settle(1)}
            >
              Next video
            </button>
          </div>
        </>
      )}
      {failure && (
        <div className="feed-error" role="alert">
          <p>{failure}</p>
          <ActionButton
            icon="shorts"
            onClick={() => {
              setFailure("");
              setPaused(false);
              setRetry((value) => value + 1);
            }}
          >
            Try again
          </ActionButton>
        </div>
      )}
      {panel === "comments" && clip && (
        <Panel
          title={`Comments · ${counts.comments}`}
          close={() => setPanel(undefined)}
        >
          <Comments
            key={clip.id}
            {...actions}
            postID={clip.id}
            profile={visitProfile}
          />
        </Panel>
      )}
      {panel === "notes" && clip && (
        <Panel title="Private notes" close={() => setPanel(undefined)}>
          <p className="muted">
            A few words for yourself. Notes stay on this iPhone.
          </p>
          <div className="feed-notes">
            {notes.map((item) => (
              <div key={item.id}>
                <p>{item.text}</p>
                <ActionButton
                  icon="trash"
                  disabled={actions.busy}
                  onClick={() =>
                    void actions.act("deleteNote", { id: item.id })
                  }
                >
                  Delete
                </ActionButton>
              </div>
            ))}
            {!notes.length && <p>No notes yet.</p>}
          </div>
          <label className="field">
            <span>Add a note</span>
            <textarea
              value={note}
              maxLength={500}
              onChange={(event) => setNote(event.target.value)}
            />
          </label>
          <ActionButton
            icon="bookmark"
            className="primary wide"
            disabled={actions.busy || !note.trim()}
            onClick={async () => {
              if (
                await actions.act("addNote", {
                  id: crypto.randomUUID(),
                  postID: clip.id,
                  text: note.trim(),
                })
              )
                setNote("");
            }}
          >
            Save note
          </ActionButton>
        </Panel>
      )}
      {panel === "more" && clip && (
        <Panel title="This short" close={() => setPanel(undefined)}>
          <p className="muted">
            {clip.authorID
              ? `Video by ${clip.sourceAuthor} · Pexels License`
              : "This video is saved in your personal Roro library."}
          </p>
          <div className="menu-actions">
            <ActionButton
              labelPosition="below"
              icon="edit"
              onClick={() => setPanel("notes")}
            >
              Private notes · {notes.length}
            </ActionButton>
            {clip.authorID ? (
              <>
                <ActionButton
                  labelPosition="below"
                  icon="share"
                  onClick={() =>
                    void native("openSource", { id: clip.id }).catch(
                      (error: Error) => actions.notify(error.message),
                    )
                  }
                >
                  View original source
                </ActionButton>
                <ActionButton
                  labelPosition="below"
                  icon="eye"
                  disabled={actions.busy}
                  onClick={async () => {
                    if (await actions.act("hide", { id: clip.id }))
                      setPanel(undefined);
                  }}
                >
                  Hide short
                </ActionButton>
              </>
            ) : (
              <ActionButton
                labelPosition="below"
                icon="trash"
                className="danger"
                disabled={actions.busy}
                onClick={async () => {
                  if (
                    !confirm(
                      "Delete this short from Roro? Your original video is kept.",
                    )
                  )
                    return;
                  video.current?.pause();
                  if (await actions.act("deleteShort", { id: clip.id })) {
                    await native("discardVideo", { video: clip.video }).catch(
                      () => {},
                    );
                    setPanel(undefined);
                    actions.notify("Short deleted.");
                  }
                }}
              >
                Delete short
              </ActionButton>
            )}
          </div>
        </Panel>
      )}
    </div>
  );
}
