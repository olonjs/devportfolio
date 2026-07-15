import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core';

export const PageHeroSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  description: z.string().describe('ui:textarea')
});

