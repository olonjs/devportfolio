import { z } from 'zod';
import { BaseCollectionItem } from '@olonjs/core';

export const ProjectSchema = BaseCollectionItem.extend({
  slug: z.string().describe('ui:text'),
  title: z.string().describe('ui:text'),
  category: z.string().describe('ui:text'),
  year: z.string().describe('ui:text'),
  summary: z.string().describe('ui:textarea'),
  context: z.string().describe('ui:textarea'),
  problem: z.string().describe('ui:textarea'),
  architecture: z.string().describe('ui:textarea'),
  result: z.string().describe('ui:textarea'),
  outcomeLong: z.string().describe('ui:textarea'),
  stack: z.array(z.string()).describe('ui:list')
});

export const ProjectsCollectionSchema = z.record(z.string(), ProjectSchema);

