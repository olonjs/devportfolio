import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core';
import { ProjectSchema } from '@/collections/projects';

export const FeaturedProjectsSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  description: z.string().optional().describe('ui:textarea'),
  items: z.record(z.string(), ProjectSchema).describe('ui:collection-ref')
});

