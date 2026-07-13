import { CardPreviewModel, FormCardData } from './A2uiTypes';

export const SAMPLE_A2UI_JSONL: string =
  '{"version":"v0.9","createSurface":{"id":"card.main","catalogs":["https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json"]}}\n' +
  '{"version":"v0.9","updateDataModel":{"surface":"card.main","value":{"title":"Pura X 日程卡片","subtitle":"由 GLM 生成 A2UI DSL","body":"今天 18:30 前完成 MVP 骨架验证。","items":["应用内预览","桌面卡片入口","GLM endpoint 配置"]}}}';

export function defaultCardPreview(): CardPreviewModel {
  return {
    title: 'GLM A2UI Card',
    subtitle: '等待 A2UI DSL',
    body: '输入 prompt 后由 GLM 返回 DSL，应用投影成 ArkUI/Form 可渲染模型。',
    itemsText: '应用内预览\n桌面卡片入口\n本地 GLM 配置',
    updatedAt: Date.now().toString()
  };
}

function asRecord(value: Object | undefined): Record<string, Object> | undefined {
  if (value === undefined || value === null) {
    return undefined;
  }
  return value as Record<string, Object>;
}

function readString(map: Record<string, Object> | undefined, key: string): string {
  if (map === undefined) {
    return '';
  }
  let value: Object | undefined = map[key];
  if (typeof value === 'string') {
    return value;
  }
  return '';
}

function readItems(map: Record<string, Object> | undefined): string {
  if (map === undefined) {
    return '';
  }
  let value: Object | undefined = map['items'];
  if (!Array.isArray(value)) {
    return '';
  }
  let lines: string[] = [];
  value.forEach((item: Object) => {
    if (typeof item === 'string') {
      lines.push(item);
    }
  });
  return lines.join('\n');
}

function getUpdateDataValue(message: Record<string, Object>): Record<string, Object> | undefined {
  let updateDataModel: Record<string, Object> | undefined = asRecord(message['updateDataModel']);
  if (updateDataModel !== undefined) {
    return asRecord(updateDataModel['value']);
  }

  let typeValue: Object | undefined = message['type'];
  if (typeof typeValue === 'string' && typeValue === 'updateDataModel') {
    return asRecord(message['value']);
  }
  return undefined;
}

export function projectDslToCardPreview(rawDsl: string): CardPreviewModel {
  let preview: CardPreviewModel = defaultCardPreview();
  let lines: string[] = rawDsl.split('\n');

  lines.forEach((line: string) => {
    let trimmed: string = line.trim();
    if (trimmed.length === 0) {
      return;
    }

    try {
      let message: Record<string, Object> = JSON.parse(trimmed) as Record<string, Object>;
      let value: Record<string, Object> | undefined = getUpdateDataValue(message);
      let title: string = readString(value, 'title');
      let subtitle: string = readString(value, 'subtitle');
      let body: string = readString(value, 'body');
      let itemsText: string = readItems(value);

      if (title.length > 0) {
        preview.title = title;
      }
      if (subtitle.length > 0) {
        preview.subtitle = subtitle;
      }
      if (body.length > 0) {
        preview.body = body;
      }
      if (itemsText.length > 0) {
        preview.itemsText = itemsText;
      }
    } catch (e) {
      preview.subtitle = 'DSL 解析失败';
      preview.body = '请检查 JSONL 格式，每行一个 A2UI message。';
    }
  });

  preview.updatedAt = Date.now().toString();
  return preview;
}

export function isRenderableA2uiDsl(rawDsl: string): boolean {
  let lines: string[] = rawDsl.split('\n');
  for (let i = 0; i < lines.length; i++) {
    let trimmed: string = lines[i].trim();
    if (trimmed.length === 0) {
      continue;
    }
    try {
      let message: Record<string, Object> = JSON.parse(trimmed) as Record<string, Object>;
      let value: Record<string, Object> | undefined = getUpdateDataValue(message);
      if (value !== undefined) {
        return true;
      }
    } catch (e) {
      return false;
    }
  }
  return false;
}

export function toFormData(preview: CardPreviewModel): FormCardData {
  return {
    title: preview.title,
    subtitle: preview.subtitle,
    body: preview.body,
    itemsText: preview.itemsText,
    updatedAt: preview.updatedAt
  };
}
