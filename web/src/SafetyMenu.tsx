import { confirmBlock } from "./confirmBlock";
import React, { useRef } from "react";
import { ActionButton } from "./Controls";
import { reportContent } from "./reportContent";
import type { ShortActions } from "./Shorts";

type Props = {
  postID: string;
  commentID?: string;
  authorID: string;
  author: string;
  act: ShortActions["act"];
  busy: boolean;
  share?(): void;
  hide?(): void;
  remove?(): void;
};

export default function SafetyMenu({ postID, commentID, authorID, author, act, busy, share, hide, remove }: Props) {
  const dialog = useRef<HTMLDialogElement>(null);
  const menuName = commentID ? `More options for comment by ${author}` : "More post options";
  const reportLabel = commentID ? "Report comment" : "Report post";
  const close = () => dialog.current?.close();
  function report() {
    close();
    void reportContent(act, commentID
      ? { kind: "comment", id: commentID, postID }
      : { kind: "post", id: postID });
  }
  function block() {
    close();
    if (confirmBlock(author)) {
      void act("setBlock", { id: authorID, enabled: true, postID, commentID });
    }
  }
  return <>
    <ActionButton icon="more" aria-label={menuName} aria-haspopup="dialog" disabled={busy}
      onClick={() => dialog.current?.showModal()}>More</ActionButton>
    <dialog ref={dialog} aria-label={menuName} className="feed-panel safety-menu">
      <div className="menu-actions">
        {remove ? <ActionButton icon="trash" labelPosition="below" disabled={busy}
          onClick={() => { close(); remove(); }}>Delete comment</ActionButton> : <>
        <ActionButton icon="info" labelPosition="below" disabled={busy} onClick={report}>{reportLabel}</ActionButton>
        <button type="button" className="safety-block" aria-label={`Block ${author}`} disabled={busy} onClick={block}>
          <span aria-hidden="true">🚫</span><span>Block</span>
        </button>
        </>}
        {share && <ActionButton icon="share" labelPosition="below" onClick={() => { close(); share(); }}>Share photo</ActionButton>}
        {hide && <ActionButton icon="eye" labelPosition="below" onClick={() => { close(); hide(); }}>Hide photo</ActionButton>}
        <ActionButton icon="close" labelPosition="below" onClick={close}>Cancel</ActionButton>
      </div>
    </dialog>
  </>;
}
