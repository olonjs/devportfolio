import type { LucideIcon } from 'lucide-react';
import {
  Braces,
  Database,
  Server,
  Cpu,
  Workflow,
  Github,
  Linkedin,
  Rss,
  Mail
} from 'lucide-react';

export const iconMap: Record<string, LucideIcon> = {
  braces: Braces,
  database: Database,
  server: Server,
  cpu: Cpu,
  workflow: Workflow,
  github: Github,
  linkedin: Linkedin,
  rss: Rss,
  mail: Mail
};

export const IconResolver = iconMap;

