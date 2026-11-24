/** Audit native UI source without building or launching the application. */
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const root = path.resolve(__dirname, "..");
const read = file => fs.readFileSync(path.join(root, "ios/Roro/UI", file), "utf8");
const icons = new Set(fs.readdirSync(path.join(root, "Assets/icons")).map(file => path.parse(file).name));
const files = fs.readdirSync(path.join(root, "ios/Roro/UI")).filter(file => file.endsWith(".swift"));
const controls = ["JournalIcon", "PhotographyArt", "PhotographyLabeledAction", "PhotographyCountAction", "AccountGlyph", "railButton"];
const control = new RegExp("\\b(?:" + controls.join("|") + ')\\(\\s*(?:(?:icon|name):\\s*)?"([a-z-]+)"', "g");
const dialogActions = new Set(["Cancel", "Remove", "Delete", "Block", "Unlock", "Keep editing", "Leave", "Discard"]);
let count = 0;
for (const file of files) {
    const source = read(file);
    assert(!source.includes("🚫"), file + " must use the bundled block artwork");
    for (const hit of source.matchAll(control)) {
        assert(icons.has(hit[1]), file + " references missing icon " + hit[1]);
        count++;
    }
    for (const hit of source.matchAll(/\bButton\("([^"]+)"/g)) {
        assert(dialogActions.has(hit[1]), file + " has an unreviewed text action " + hit[1]);
    }
}
const library = read("PhotographyComponents.swift");
assert(library.includes(".onSubmit { focused = false }") && library.includes('query = ""'));
assert(library.includes("if below") && library.includes("VStack(spacing: 4) { artwork; Text(label)") &&
       library.includes("HStack(spacing: 5) { artwork; Text(label)"));
for (const file of ["PhotographyFeed.swift", "JournalShortsPanels.swift"]) {
    const sheet = file === "PhotographyFeed.swift" ? read(file).split("struct PhotographySafetySheet")[1].split("struct PhotographyUnlock")[0] : read(file);
    for (const line of sheet.split("\n").filter(line => line.includes("PhotographyLabeledAction("))) {
        assert(line.includes("below: true"), file + " needs a visible label below its option icon");
    }
}
const profile = read("PhotographyMember.swift");
assert(profile.includes('label: "Message"') && profile.includes('"Follow back"'));
const design = read("JournalDesign.swift");
assert(design.includes("minWidth: 44, minHeight: 44") && design.includes(".accessibilityLabel("));
const routes = fs.readFileSync(path.join(root, "ios/Roro/Native/JournalStore.swift"), "utf8").split("enum JournalTab")[0];
assert(!/case[^\n]*\bsearch\b/i.test(routes), "Search must expand inline");
assert(read("AccountChats.swift").includes(".swipeActions("));
const welcome = read("JournalRoot.swift");
assert(welcome.includes('TextField("name@example.com"') && welcome.includes('SecureField("Password"'));
assert(welcome.includes('"Logging in…" : "Log in"') && welcome.includes(".disabled(!canSubmit)"));
assert(welcome.includes("checked && !invalidEmail && !password.isEmpty && !app.authenticating"));
console.log(`Inspected ${files.length} SwiftUI files and ${count} literal icon references. Native control source checks passed.`);
