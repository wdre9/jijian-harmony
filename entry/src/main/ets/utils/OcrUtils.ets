/**
 * OCR 识别：本地 CoreVisionKit 文本识别，不上传任何数据。
 * 图片选取用 @ohos.file.picker 的 PhotoViewPicker（无需相机权限，从相册选图）；
 * 图片解码用 @kit.ImageKit image.createImageSource + createPixelMap。
 */
import { textRecognition } from '@kit.CoreVisionKit'
import { image } from '@kit.ImageKit'
import { picker } from '@kit.CoreFileKit'

/** 从相册选一张图片并识别文本（失败返回空串） */
export async function pickImageAndRecognize(): Promise<string> {
  const photoPicker = new picker.PhotoViewPicker()
  const options = new picker.PhotoSelectOptions()
  options.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE
  options.maxSelectNumber = 1
  const res = await photoPicker.select(options)
  if (!res || res.photoUris.length === 0) {
    return ''
  }
  const uri: string = res.photoUris[0]
  return await recognizeUri(uri)
}

/** 识别图片文件 URI（file:// 或沙箱路径） */
export async function recognizeUri(uri: string): Promise<string> {
  let source: image.ImageSource | null = null
  try {
    source = image.createImageSource(uri)
    const pixelMap: image.PixelMap = await source.createPixelMap()
    return await recognizePixelMap(pixelMap)
  } catch (e) {
    return ''
  } finally {
    if (source) {
      try {
        source.release()
      } catch (e) {
        // ignore
      }
    }
  }
}

/** 识别 PixelMap */
export async function recognizePixelMap(pixelMap: image.PixelMap): Promise<string> {
  textRecognition.init()
  try {
    const visionInfo: textRecognition.VisionInfo = {
      pixelMap: pixelMap
    }
    const config: textRecognition.TextRecognitionConfiguration = {
      isDirectionDetectionSupported: true
    }
    const result = await textRecognition.recognizeText(visionInfo, config)
    return result.value
  } catch (e) {
    return ''
  } finally {
    textRecognition.release()
  }
}
