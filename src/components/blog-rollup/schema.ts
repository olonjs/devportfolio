import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core';
import { PostSchema } from '@/collections/posts';

export const BlogRollupSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  description: z.string().optional().describe('ui:textarea'),
  items: z.record(z.string(), PostSchema).describe('ui:collection-ref')
});

