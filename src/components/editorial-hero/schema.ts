import { z } from 'zod';
import { BaseSectionData, CtaSchema } from '@olonjs/core';

export const EditorialHeroSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  titleHighlight: z.string().optional().describe('ui:text'),
  description: z.string().describe('ui:textarea'),
  primaryCta: CtaSchema.optional(),
  secondaryCta: CtaSchema.optional(),
  status: z.string().optional().describe('ui:text')
});

