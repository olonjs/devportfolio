import { BaseSectionData } from '@olonjs/core';
import { ProjectSchema } from '@/collections/projects';

export const ProjectDetailSchema = BaseSectionData.extend({
  item: ProjectSchema.describe('ui:collection-ref')
});

