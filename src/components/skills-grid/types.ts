import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { SkillsGridSchema } from './schema';

export type SkillsGridData = z.infer<typeof SkillsGridSchema>;
export type SkillsGridSettings = z.infer<typeof BaseSectionSettingsSchema>;

