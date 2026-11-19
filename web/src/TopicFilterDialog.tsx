import React, { useEffect, useRef } from "react";
import { ActionButton } from "./Controls";
import { topics } from "./catalog";

function ChoiceGroup({ title, name, options, initial }: {
  title: string;
  name: string;
  options: readonly string[];
  initial: string;
}) {
  return (
    <fieldset className="filter-group">
      <legend>{title}</legend>
      <div className="filter-choices">
        {options.map((value) => (
          <label key={value}>
            <input type="radio" name={name} value={value} defaultChecked={initial === value} />
            <span>{value || "All topics"}</span>
          </label>
        ))}
      </div>
    </fieldset>
  );
}

export default function TopicFilterDialog({ category, access, dismiss, apply }: {
  category: string;
  access: string;
  dismiss(): void;
  apply(category: string, access: string): void;
}) {
  const dialog = useRef<HTMLDialogElement>(null);
  useEffect(() => { dialog.current?.showModal(); }, []);
  return (
    <dialog className="topic-filters" ref={dialog} aria-labelledby="topic-filter-title" onClose={dismiss}>
      <form method="dialog" onSubmit={(event) => {
        const choices = new FormData(event.currentTarget);
        apply(String(choices.get("category")), String(choices.get("access")));
      }}>
        <div className="topic-filter-heading">
          <h2 id="topic-filter-title">Filter topics</h2>
          <ActionButton icon="close" onClick={() => dialog.current?.close()}>Cancel filters</ActionButton>
        </div>
        <ChoiceGroup title="Topic category" name="category" options={["", ...topics]} initial={category} />
        <ChoiceGroup title="Access" name="access" options={["All", "Free", "Paid"]} initial={access} />
        <div className="filter-apply">
          <ActionButton type="submit" icon="check">Apply filters</ActionButton>
        </div>
      </form>
    </dialog>
  );
}
