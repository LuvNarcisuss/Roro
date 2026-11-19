import ProfilePortrait from "./ProfilePortrait";
import { ActionButton } from "./Controls";
import SafetyMenu from "./SafetyMenu";
import React, { useRef, useState } from "react";
import { authorFor, commentsFor } from "./community";
import type { ShortActions } from "./Shorts";
type Comment = ReturnType<typeof commentsFor>[number];

function orderThread(comments: Comment[], byID: Map<string, Comment>) {
  const children = new Map<string, Comment[]>();
  const roots: Comment[] = [];
  for (const comment of comments) {
    if (comment.parentID && byID.has(comment.parentID)) {
      const siblings = children.get(comment.parentID);
      if (siblings) siblings.push(comment);
      else children.set(comment.parentID, [comment]);
    } else {
      roots.push(comment);
    }
  }
  const ordered: Comment[] = [];
  const stack = roots.reverse();
  while (stack.length) {
    const next = stack.pop()!;
    ordered.push(next);
    const replies = children.get(next.id);
    if (replies) stack.push(...replies.reverse());
  }
  return ordered;
}

export default function Comments({
  postID,
  profile,
  showStorageNotice = true,
  ...actions
}: ShortActions & {
  postID: string;
  showStorageNotice?: boolean;
  profile(id?: string): void;
}) {
  const [text, setText] = useState("");
  const input = useRef<HTMLTextAreaElement>(null);
  const [replyID, setReplyID] = useState<string>();
  const comments = commentsFor(postID, actions.state);
  const byID = new Map(comments.map(comment => [comment.id, comment]));
  const reply = replyID ? byID.get(replyID) : undefined;
  const replyName = reply && authorFor(reply.authorID, actions.state).name;
  return (
    <section className="community-comments">
      <h3>Comments · {comments.length}</h3>
      <div className="comment-list">
        {orderThread(comments, byID).map((comment) => {
          const author = authorFor(comment.authorID, actions.state);
          const parent = comment.parentID ? byID.get(comment.parentID) : undefined;
          const portrait = comment.local ? actions.state.profile : author;
          return (
            <article className={parent ? "community-comment comment-reply" : "community-comment"} key={comment.id}>
              <button
                className="comment-avatar"
                aria-label={`Open ${author.name}'s profile`}
                onClick={() => profile(comment.authorID)}
              >
                <ProfilePortrait avatar={portrait.avatar} name={portrait.name} />
              </button>
              <div>
                <button
                  className="comment-author"
                  onClick={() => profile(comment.authorID)}
                >
                  {author.name}
                </button>
                <p>{parent && <span className="reply-recipient">@{authorFor(parent.authorID, actions.state).name} </span>}{comment.text}</p>
                <div className="comment-actions">
                  <small>
                    {new Date(comment.createdAt).toLocaleDateString("en", { month: "short", day: "numeric" })}
                  </small>
                  <ActionButton icon="comment" aria-label={`Reply to ${author.name}`} disabled={actions.busy}
                    onClick={() => { setReplyID(comment.id); input.current?.focus(); }}>
                    Reply
                  </ActionButton>
                  <SafetyMenu postID={postID} commentID={comment.id} authorID={comment.authorID}
                    author={author.name} act={actions.act} busy={actions.busy}
                    remove={comment.local ? () => void actions.act("deleteComment", { id: comment.id }) : undefined} />
                </div>
              </div>
            </article>
          );
        })}
        {!comments.length && <p className="muted">Start with a little thought.</p>}
        {showStorageNotice && <p className="muted comment-local-note">Your comments are kept on this iPhone.</p>}
      </div>
      <form className="chat-composer comment-composer" onSubmit={async (event) => {
        event.preventDefault();
        const body = text.trim();
        if (!body || actions.busy || (replyID && !reply)) return;
        if (await actions.act("addComment", { id: crypto.randomUUID(), postID, text: body, parentID: replyID })) {
          setText("");
          setReplyID(undefined);
        }
      }}>
        {replyID && <div className="reply-target">
          <span role="status">{replyName ? `Replying to ${replyName}` : "Comment unavailable"}</span>
          <ActionButton icon="close" aria-label="Cancel reply" disabled={actions.busy}
            onClick={() => { setReplyID(undefined); input.current?.focus(); }}>Cancel reply</ActionButton>
        </div>}
        <textarea ref={input} aria-label={replyName ? `Reply to ${replyName}` : "Add a comment"} placeholder={replyName ? "Write a reply…" : "Add a comment…"} rows={1}
          maxLength={500} disabled={actions.busy} value={text}
          onChange={(event) => setText(event.target.value)} />
        <ActionButton type="submit" icon="send" disabled={actions.busy || !text.trim() || (!!replyID && !reply)}>
          Add comment
        </ActionButton>
      </form>
    </section>
  );
}
