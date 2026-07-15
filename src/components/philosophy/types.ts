import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { PhilosophySchema } from './schema';

export type PhilosophyData = z.infer<typeof PhilosophySchema>;
export type PhilosophySettings = z.infer<typeof BaseSectionSettingsSchema>;

