import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core';

const FooterMenuItemSchema = z.object({
  id: z.string().optional(),
  label: z.string().describe('ui:text'),
  href: z.string().describe('ui:text'),
  icon: z.string().optional().describe('ui:icon-picker')
});

export const FooterSchema = BaseSectionData.extend({
  brandText: z.string().describe('ui:text'),
  brandHighlight: z.string().optional().describe('ui:text'),
  summary: z.string().optional().describe('ui:textarea'),
  email: z.string().optional().describe('ui:text'),
  copyright: z.string().describe('ui:text'),
  menu: z.array(FooterMenuItemSchema).optional().describe('ui:list')
});

