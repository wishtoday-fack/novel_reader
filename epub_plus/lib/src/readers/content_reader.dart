import '../entities/epub_content_type.dart';
import '../ref_entities/epub_book_ref.dart';
import '../ref_entities/epub_byte_content_file_ref.dart';
import '../ref_entities/epub_content_file_ref.dart';
import '../ref_entities/epub_content_ref.dart';
import '../ref_entities/epub_text_content_file_ref.dart';

class ContentReader {
  static EpubContentRef parseContentMap(EpubBookRef bookRef) {
    final html = <String, EpubTextContentFileRef>{};
    final css = <String, EpubTextContentFileRef>{};
    final images = <String, EpubByteContentFileRef>{};
    final fonts = <String, EpubByteContentFileRef>{};
    final allFiles = <String, EpubContentFileRef>{};

    for (final manifestItem in bookRef.schema!.package!.manifest!.items) {
      var fileName = manifestItem.href ?? '';
      var contentMimeType = manifestItem.mediaType!;
      var contentType = EpubContentType.fromMimeType(contentMimeType);

      // Also create a decoded version of the filename for matching
      var decodedFileName = _safeDecodeUri(fileName);

      switch (contentType) {
        case EpubContentType.xhtml11:
        case EpubContentType.css:
        case EpubContentType.oeb1Document:
        case EpubContentType.oeb1CSS:
        case EpubContentType.xml:
        case EpubContentType.dtbook:
        case EpubContentType.dtbookNCX:
          var epubTextContentFile = EpubTextContentFileRef(
            epubBookRef: bookRef,
            fileName: fileName,
            contentMimeType: contentMimeType,
          );

          // Store both original and decoded versions for matching
          switch (contentType) {
            case EpubContentType.xhtml11:
              html[fileName] = epubTextContentFile;
              if (decodedFileName != fileName) {
                html[decodedFileName] = epubTextContentFile;
              }
            case EpubContentType.css:
              css[fileName] = epubTextContentFile;
              if (decodedFileName != fileName) {
                css[decodedFileName] = epubTextContentFile;
              }
            default:
              break;
          }
          allFiles[fileName] = epubTextContentFile;
          if (decodedFileName != fileName) {
            allFiles[decodedFileName] = epubTextContentFile;
          }
        default:
          var epubByteContentFile = EpubByteContentFileRef(
            epubBookRef: bookRef,
            fileName: fileName,
            contentMimeType: contentMimeType,
            contentType: contentType,
          );

          // Store both original and decoded versions for matching
          switch (contentType) {
            case EpubContentType.imageGIF:
            case EpubContentType.imageJPEG:
            case EpubContentType.imagePNG:
            case EpubContentType.imageSVG:
            case EpubContentType.imageBMP:
              images[fileName] = epubByteContentFile;
              if (decodedFileName != fileName) {
                images[decodedFileName] = epubByteContentFile;
              }
            case EpubContentType.fontTrueType:
            case EpubContentType.fontOpenType:
              fonts[fileName] = epubByteContentFile;
              if (decodedFileName != fileName) {
                fonts[decodedFileName] = epubByteContentFile;
              }
            default:
              break;
          }
          allFiles[fileName] = epubByteContentFile;
          if (decodedFileName != fileName) {
            allFiles[decodedFileName] = epubByteContentFile;
          }
      }
    }
    return EpubContentRef(
      html: html,
      css: css,
      images: images,
      fonts: fonts,
      allFiles: allFiles,
    );
  }

  /// Safely decode URI, handling invalid percent encoding
  static String _safeDecodeUri(String uri) {
    if (uri.isEmpty) return uri;
    try {
      return Uri.decodeFull(uri);
    } catch (e) {
      // Fix invalid percent encoding and try again
      final fixedUri = _fixInvalidPercentEncoding(uri);
      try {
        return Uri.decodeFull(fixedUri);
      } catch (_) {
        return uri;
      }
    }
  }

  /// Fix invalid percent encoding in a URI string
  static String _fixInvalidPercentEncoding(String uri) {
    final buffer = StringBuffer();
    int i = 0;

    while (i < uri.length) {
      if (uri[i] == '%') {
        if (i + 2 < uri.length) {
          final hex1 = uri[i + 1];
          final hex2 = uri[i + 2];

          if (_isHexDigit(hex1) && _isHexDigit(hex2)) {
            buffer.write(uri.substring(i, i + 3));
            i += 3;
          } else {
            buffer.write('%25');
            i += 1;
          }
        } else if (i + 1 < uri.length) {
          buffer.write('%25');
          buffer.write(uri[i + 1]);
          i += 2;
        } else {
          buffer.write('%25');
          i += 1;
        }
      } else {
        buffer.write(uri[i]);
        i += 1;
      }
    }

    return buffer.toString();
  }

  /// Check if a character is a valid hexadecimal digit
  static bool _isHexDigit(String char) {
    const hexDigits = '0123456789ABCDEFabcdef';
    return hexDigits.contains(char);
  }
}
