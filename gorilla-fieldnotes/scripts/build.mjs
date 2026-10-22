import { cp, mkdir, rm, copyFile, stat } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const outputDir = path.join(projectRoot, 'dist');
const publicFiles = ['index.html', 'login.html', '404.html', 'robots.txt', 'site.webmanifest', '_headers'];

await rm(outputDir, { recursive: true, force: true });
await mkdir(outputDir, { recursive: true });
for (const name of publicFiles) {
  const source = path.join(projectRoot, name);
  await stat(source);
  await copyFile(source, path.join(outputDir, name));
}
for (const directory of ['assets', 'pages']) {
  await cp(path.join(projectRoot, directory), path.join(outputDir, directory), { recursive: true });
}
console.log(`Built static site into ${path.relative(projectRoot, outputDir)} (public files only).`);
