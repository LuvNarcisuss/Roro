import { ActionButton } from "./Controls";
import React, { useState } from "react";
import { authorFor, commentsFor } from "./community";
import type { ShortActions } from "./Shorts";
export default function Comments({
  postID,
  profile,
  ...actions
}: ShortActions & {
  postID: string;
  profile(id?: string): void;
}) {
  const [text, setText] = useState("");
  const comments = commentsFor(postID, actions.state);
  return (
    <section className="community-comments">
      <h3>Comments · {comments.length}</h3>
      <div className="comment-list">
        {comments.map((comment) => {
          const author = authorFor(comment.authorID, actions.state);
          return (
            <article className="community-comment" key={comment.id}>
              <button
                className="comment-avatar"
                aria-label={`Open ${author.name}'s profile`}
                onClick={() => profile(comment.authorID)}
              >
                <img src={author.avatar} alt="" />
              </button>
              <div>
                <button
                  className="comment-author"
                  onClick={() => profile(comment.authorID)}
                >
                  {author.name}
                </button>
                <p>{comment.text}</p>
                <small>
                  {new Date(comment.createdAt).toLocaleDateString("en", {
                    month: "short",
                    day: "numeric",
                  })}
                </small>
                {comment.local && (
                  <ActionButton
                    icon="trash"
                    className="text-button"
                    disabled={actions.busy}
                    onClick={() =>
                      void actions.act("deleteComment", { id: comment.id })
                    }
                  >
                    Delete
                  </ActionButton>
                )}
              </div>
            </article>
          );
        })}
      </div>
      {!comments.length && (
        <p className="muted">Start with a little thought.</p>
      )}
      <label className="field">
        <span>Add a comment</span>
        <textarea
          value={text}
          maxLength={500}
          placeholder="What caught your eye?"
          onChange={(event) => setText(event.target.value)}
        />
      </label>
      <ActionButton
        icon="send"
        className="primary wide"
        disabled={actions.busy || !text.trim()}
        onClick={async () => {
          if (
            await actions.act("addComment", {
              id: crypto.randomUUID(),
              postID,
              text: text.trim(),
            })
          )
            setText("");
        }}
      >
        Add comment
      </ActionButton>
      <p className="muted comment-local-note">
        Your comments are kept on this iPhone.
      </p>
    </section>
  );
}
