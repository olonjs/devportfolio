import { z } from 'zod';
import { BaseSectionData, ImageSelectionSchema } from '@olonjs/core';

export const BioPanelSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  description: z.string().describe('ui:textarea'),
  image: ImageSelectionSchema.optional(),
  note: z.string().optional().describe('ui:textarea')
});

