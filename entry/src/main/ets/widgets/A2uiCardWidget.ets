@Entry
@Component
struct A2uiCardWidget {
  @LocalStorageProp('title') title: string = 'GLM A2UI Card';
  @LocalStorageProp('subtitle') subtitle: string = 'A2UI DSL preview';
  @LocalStorageProp('body') body: string = 'Open the app to generate a card from prompt.';
  @LocalStorageProp('itemsText') itemsText: string = 'GLM endpoint\nA2UI projection\nForm card';
  @LocalStorageProp('updatedAt') updatedAt: string = '';

  build() {
    Column({ space: 8 }) {
      Text(this.title)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(this.subtitle)
        .fontSize(12)
        .fontColor('#4B5563')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(this.body)
        .fontSize(14)
        .fontColor('#111827')
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(this.itemsText)
        .fontSize(12)
        .fontColor('#374151')
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Blank()

      Button('打开')
        .height(32)
        .fontSize(12)
        .onClick(() => {
          postCardAction(this, {
            action: 'router',
            abilityName: 'EntryAbility',
            params: {
              source: 'a2ui_card',
              updatedAt: this.updatedAt
            }
          });
        })
    }
    .width('100%')
    .height('100%')
    .padding(14)
    .backgroundColor('#F8FAFC')
  }
}
