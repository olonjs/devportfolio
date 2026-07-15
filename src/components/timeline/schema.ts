import { z } from 'zod';
import { BaseSectionData, BaseArrayItem } from '@olonjs/core';

const TimelineItemSchema = BaseArrayItem.extend({
  period: z.string().describe('ui:text'),
  title: z.string().describe('ui:text'),
  organization: z.string().describe('ui:text'),
  body: z.string().describe('ui:textarea')
});

export const TimelineSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  items: z.array(TimelineItemSchema).describe('ui:list')
});

