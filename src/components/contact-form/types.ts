import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { ContactFormSchema } from './schema';

export type ContactFormData = z.infer<typeof ContactFormSchema>;
export type ContactFormSettings = z.infer<typeof BaseSectionSettingsSchema>;

