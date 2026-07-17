import { SemanticGalleryPage as Gallery } from '../semanticui/gallery/SemanticGalleryPage';

@ComponentV2
@Entry
export struct SemanticGalleryEntry {
  build() { Column() { Gallery(); }.width('100%').height('100%'); }
}
