import { ProjectsCollectionSchema } from '@/collections/projects';
import { PostsCollectionSchema } from '@/collections/posts';

export const CollectionRegistry = {
  projects: ProjectsCollectionSchema,
  posts: PostsCollectionSchema
} as const;

export type CollectionType = keyof typeof CollectionRegistry;

