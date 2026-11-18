import { build } from "esbuild";
import { cp, mkdir, readFile, writeFile, rm, readdir } from "node:fs/promises";
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import path from "node:path";
const root = path.resolve(import.meta.dirname, "..");
const out = path.join(root, ".build/web");
await rm(out, { recursive: true, force: true });
await mkdir(out, { recursive: true });
for (const directory of ["icons", "backgrounds", "photos", "fonts", "videos", "community"])
  await cp(
    path.join(root, "Assets", directory),
    path.join(out, "assets", directory),
    { recursive: true },
  );
await cp(
  path.join(root, "Assets/artwork-manifest.json"),
  path.join(out, "assets/artwork-manifest.json"),
);
await cp(path.join(root, "web/index.html"), path.join(out, "index.html"));
await build({
  entryPoints: [path.join(root, "web/src/main.tsx")],
  bundle: true,
  outfile: path.join(out, "app.js"),
  minify: true,
  platform: "browser",
  format: "iife",
  target: ["safari16"],
  loader: { ".ttf": "file" },
  external: ["./assets/*"],
  define: { "process.env.NODE_ENV": '"production"' },
});
const inputs = {};
async function collect(directory) {
  for (const entry of (
    await readdir(path.join(root, directory), { withFileTypes: true })
  ).sort((a, b) => a.name.localeCompare(b.name))) {
    const relative = path.posix.join(directory, entry.name);
    if (entry.isDirectory()) await collect(relative);
    else
      inputs[relative] = createHash("sha256")
        .update(await readFile(path.join(root, relative)))
        .digest("hex");
  }
}
await collect("web");
await collect("Assets");
await collect("Configuration");
await collect("scripts");
for (const file of ["package.json", "package-lock.json"])
  inputs[file] = createHash("sha256")
    .update(await readFile(path.join(root, file)))
    .digest("hex");
const version = createHash("sha256")
  .update(JSON.stringify(inputs))
  .digest("hex");
await writeFile(
  path.join(out, "manifest.json"),
  JSON.stringify({ version, inputs }, null, 2),
);
execFileSync(
  "python3",
  [
    path.join(root, "scripts/zip_web.py"),
    out,
    path.join(root, "ios/Roro/AppResources/RoroWeb.zip"),
  ],
  { stdio: "inherit" },
);
await writeFile(
  path.join(root, "ios/Roro/AppResources/RoroWeb.sha256"),
  createHash("sha256")
    .update(
      await readFile(path.join(root, "ios/Roro/AppResources/RoroWeb.zip")),
    )
    .digest("hex"),
);

for (const name of ["products", "agreements"])
  await cp(
    path.join(root, `Configuration/${name}.json`),
    path.join(root, `ios/Roro/AppResources/${name}.json`),
  );

await cp(
  path.join(root, "Assets/community/catalog.json"),
  path.join(root, "ios/Roro/AppResources/community.json"),
);
