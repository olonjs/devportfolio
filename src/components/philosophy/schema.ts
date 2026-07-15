import { z } from 'zod';
import { BaseSectionData, BaseArrayItem } from '@olonjs/core';

const PrincipleSchema = BaseArrayItem.extend({
  title: z.string().describe('ui:text'),
  body: z.string().describe('ui:textarea')
});

export const PhilosophySchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  description: z.string().optional().describe('ui:textarea'),
  items: z.array(PrincipleSchema).describe('ui:list')
});

