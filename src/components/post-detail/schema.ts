import { BaseSectionData } from '@olonjs/core';
import { PostSchema } from '@/collections/posts';

export const PostDetailSchema = BaseSectionData.extend({
  item: PostSchema.describe('ui:collection-ref')
});

