import { z } from 'zod';
import { BaseSectionData, BaseArrayItem } from '@olonjs/core';

const SkillItemSchema = BaseArrayItem.extend({
  category: z.string().describe('ui:text'),
  label: z.string().describe('ui:text'),
  icon: z.string().describe('ui:icon-picker'),
  body: z.string().describe('ui:textarea')
});

export const SkillsGridSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  items: z.array(SkillItemSchema).describe('ui:list')
});

