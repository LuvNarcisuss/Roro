import React, { useRef } from "react";
import { flushSync } from "react-dom";
export function Glyph({ name }: { name: string }) {
  return <img className="icon" src={`assets/icons/${name}.png`} alt="" />;
}
const reactionIcons = {
  like: { selected: "heart", outline: "heart-outline" },
  save: { selected: "bookmark", outline: "bookmark-outline" },
};
export function ReactionButton({
  kind,
  selected,
  count,
  ...props
}: React.ButtonHTMLAttributes<HTMLButtonElement> & {
  kind: keyof typeof reactionIcons;
  selected: boolean;
  count: number;
  "aria-label": string;
}) {
  const icons = reactionIcons[kind];
  return (
    <button {...props} type="button" aria-pressed={selected}>
      <Glyph name={selected ? icons.selected : icons.outline} />
      <span className="action-count">{count}</span>
    </button>
  );
}
export function ActionButton({
  icon,
  children,
  className = "",
  labelPosition,
  count,
  ...props
}: React.ButtonHTMLAttributes<HTMLButtonElement> & {
  icon: string;
  labelPosition?: "beside" | "below";
  count?: number;
}) {
  return (
    <button
      {...props}
      type={props.type ?? "button"}
      className={`icon-action ${labelPosition ? `label-${labelPosition}` : ""} ${className}`}
    >
      <Glyph name={icon} />
      <span className={labelPosition ? "action-label" : "sr-only"}>{children}</span>
      {count !== undefined && <span className="action-count">{count}</span>}
    </button>
  );
}
export type SearchState = { open: boolean; query: string };
export const emptySearch: SearchState = { open: false, query: "" };
export function ToolbarSearch({
  value,
  change,
  label,
  focusChanged,
}: {
  value: SearchState;
  change(value: SearchState): void;
  label: string;
  focusChanged?(focused: boolean): void;
}) {
  const input = useRef<HTMLInputElement>(null);
  return (
    <form
      className={`toolbar-search ${value.open ? "is-open" : ""}`}
      role="search"
      onSubmit={(event) => {
        event.preventDefault();
        input.current?.blur();
        focusChanged?.(false);
      }}
    >
      {value.open && (
        <input
          ref={input}
          type="search"
          enterKeyHint="search"
          aria-label={label}
          placeholder={label}
          value={value.query}
          onChange={(event) => change({ ...value, query: event.target.value })}
          onFocus={() => focusChanged?.(true)}
          onBlur={() => focusChanged?.(false)}
        />
      )}
      <ActionButton
        icon={value.open ? "close" : "search"}
        aria-label={value.open ? "Close search" : label}
        aria-expanded={value.open}
        onClick={() => {
          if (value.open) {
            input.current?.blur();
            focusChanged?.(false);
            change(emptySearch);
          } else {
            // Focus in the original tap event so the iPhone keyboard can open.
            flushSync(() => change({ ...value, open: true }));
            input.current?.focus();
          }
        }}
      >
        {value.open ? "Close search" : label}
      </ActionButton>
    </form>
  );
}
