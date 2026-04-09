// Part of BeeSwift. Copyright Beeminder

import AlamofireImage

final public class ImageDownloadService {
  static public let shared = ImageDownloadService()
  public let downloader: ImageDownloader

  private init() { downloader = ImageDownloader.default }
}
