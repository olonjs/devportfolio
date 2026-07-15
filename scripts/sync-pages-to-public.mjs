import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '..');
const sourceDir = path.join(rootDir, 'src', 'data', 'pages');
const targetDir = path.join(rootDir, 'public', 'pages');
const sourceCollectionsDir = path.join(rootDir, 'src', 'data', 'collections');
const targetCollectionsDir = path.join(rootDir, 'public', 'collections');
const sourceSiteConfigPath = path.join(rootDir, 'src', 'data', 'config', 'site.json');
const targetConfigDir = path.join(rootDir, 'public', 'config');
const targetSiteConfigPath = path.join(targetConfigDir, 'site.json');

if (!fs.existsSync(sourceDir)) {
  console.warn('[sync-pages-to-public] Source directory not found:', sourceDir);
  process.exit(0);
}

fs.rmSync(targetDir, { recursive: true, force: true });
fs.mkdirSync(targetDir, { recursive: true });
fs.cpSync(sourceDir, targetDir, { recursive: true });

fs.rmSync(targetCollectionsDir, { recursive: true, force: true });
if (fs.existsSync(sourceCollectionsDir)) {
  fs.mkdirSync(targetCollectionsDir, { recursive: true });
  fs.cpSync(sourceCollectionsDir, targetCollectionsDir, { recursive: true });
}

if (fs.existsSync(sourceSiteConfigPath)) {
  fs.mkdirSync(targetConfigDir, { recursive: true });
  fs.cpSync(sourceSiteConfigPath, targetSiteConfigPath);
}

console.log('[sync-pages-to-public] Synced pages, collections, and site config to public/');
