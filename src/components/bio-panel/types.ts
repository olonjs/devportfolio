import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { BioPanelSchema } from './schema';

export type BioPanelData = z.infer<typeof BioPanelSchema>;
export type BioPanelSettings = z.infer<typeof BaseSectionSettingsSchema>;

