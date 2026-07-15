import { z } from 'zod';
import { BaseSectionData, BaseArrayItem } from '@olonjs/core';

const ContactLinkSchema = BaseArrayItem.extend({
  label: z.string().describe('ui:text'),
  href: z.string().describe('ui:text'),
  icon: z.string().describe('ui:icon-picker')
});

export const ContactFormSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  description: z.string().describe('ui:textarea'),
  email: z.string().describe('ui:text'),
  formNote: z.string().optional().describe('ui:textarea'),
  links: z.array(ContactLinkSchema).describe('ui:list')
});

