import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { TimelineSchema } from './schema';

export type TimelineData = z.infer<typeof TimelineSchema>;
export type TimelineSettings = z.infer<typeof BaseSectionSettingsSchema>;

