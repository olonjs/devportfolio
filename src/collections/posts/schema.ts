import { z } from 'zod';
import { BaseCollectionItem } from '@olonjs/core';

export const PostSchema = BaseCollectionItem.extend({
  slug: z.string().describe('ui:text'),
  title: z.string().describe('ui:text'),
  dek: z.string().describe('ui:textarea'),
  date: z.string().describe('ui:text'),
  readingTime: z.string().describe('ui:text'),
  tags: z.array(z.string()).describe('ui:list'),
  related: z.array(z.string()).describe('ui:list'),
  content: z.array(z.string()).describe('ui:list')
});

export const PostsCollectionSchema = z.record(z.string(), PostSchema);

