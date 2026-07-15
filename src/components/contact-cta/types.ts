import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { ContactCtaSchema } from './schema';

export type ContactCtaData = z.infer<typeof ContactCtaSchema>;
export type ContactCtaSettings = z.infer<typeof BaseSectionSettingsSchema>;

