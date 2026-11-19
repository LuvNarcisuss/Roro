import { confirmBlock } from "./confirmBlock";
import React from "react";
import { ActionButton } from "./Controls";
import { authorFor, isBlocked, totals } from "./community";
import type { ShortActions } from "./Shorts";
import WorkGrid from "./WorkGrid";
import type { Photo, ShortVideo } from "./types";
export default function MemberProfile({
  id,
  photos,
  shorts,
  open,
  openPhoto,
  message,
  ...actions
}: ShortActions & {
  id: string;
  message(id: string): void;
  photos: Photo[];
  shorts: ShortVideo[];
  open(id: string): void;
  openPhoto(id: string): void;
}) {
  const author = authorFor(id, actions.state);
  const images = photos.filter((item) => item.authorID === id);
  const clips = shorts.filter((item) => item.authorID === id);
  const counts = totals([...images, ...clips], actions.state);
  return (
    <>
      <div className="profile-cover member-profile">
        <img className="member-avatar" src={author.avatar} alt="" />
        <h1>{author.name}</h1>
        <span className="muted">@{author.handle}</span>
        <p>{author.bio}</p>
        <div className="stats">
          <span>
            <strong>{counts.works}</strong>Works
          </span>
          <span>
            <strong>{counts.likes}</strong>Likes
          </span>
          <span>
            <strong>{counts.saves}</strong>Saves
          </span>
        </div>
        <div className="member-actions">
          <ActionButton
            icon={actions.state.following.includes(id) ? "check" : "plus"}
            labelPosition="beside"
            disabled={actions.busy || isBlocked(id, actions.state)}
            aria-pressed={actions.state.following.includes(id)}
            onClick={() => void actions.act("toggleFollow", { id })}
          >
            {actions.state.following.includes(id) ? "Following" : actions.state.followers?.includes(id) ? "Follow back" : "Follow"}
          </ActionButton>
          <ActionButton
            icon="chat"
            labelPosition="beside"
            disabled={isBlocked(id, actions.state)}
            onClick={() => message(id)}
          >
            Message
          </ActionButton>
          <button
            className="block-action"
            disabled={actions.busy}
            aria-label={
              isBlocked(id, actions.state)
                ? `Unblock ${author.name}`
                : `Block ${author.name}`
            }
            aria-pressed={isBlocked(id, actions.state)}
            onClick={() => {
              if (
                isBlocked(id, actions.state) ||
                confirmBlock(author.name)
              )
                void actions.act("setBlock", { id, enabled: !isBlocked(id, actions.state) });
            }}
          >
            🚫
          </button>
        </div>
        {isBlocked(id, actions.state) && (
          <p className="muted">You’ve blocked {author.name}.</p>
        )}
      </div>
      {!!clips.length && (
        <section className="page">
          <h2>Shorts · {clips.length}</h2>
          <WorkGrid items={clips} open={open} />
        </section>
      )}
      {!!images.length && (
        <section className="page">
          <h2>Moments · {images.length}</h2>
          <WorkGrid items={images} open={openPhoto} />
        </section>
      )}
      {!counts.works && (
        <p className="page muted">
          No visible works. You can restore hidden works in Settings.
        </p>
      )}
    </>
  );
}
