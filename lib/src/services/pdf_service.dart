import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfService {
  Future<Uint8List> embedSignatures({
    required File pdfFile,
    required List<Map<String, dynamic>> signatures,
  }) async {
    final pdfBytes = await pdfFile.readAsBytes();

    // Load the existing PDF document
    final PdfDocument document = PdfDocument(inputBytes: pdfBytes);

    try {
      debugPrint(
        "EmbedSignatures: Processing ${signatures.length} signatures.",
      );
      for (final signature in signatures) {
        final Uint8List image = signature['image'];
        final double x = signature['x'];
        final double y = signature['y'];
        final double width = signature['width'];
        final double height = signature['height'];
        final int pageIndex = signature['pageIndex'];

        debugPrint(
          "Embedding Signature: Page=$pageIndex, X=$x, Y=$y, W=$width, H=$height",
        );

        final int index = (pageIndex > 0 && pageIndex <= document.pages.count)
            ? pageIndex - 1
            : 0;

        debugPrint(
          "Target PDF Page Index: $index (Total Pages: ${document.pages.count})",
        );

        final PdfPage page = document.pages[index];
        final Size pageSize = page.getClientSize();
        debugPrint("PDF Page Size: W=${pageSize.width}, H=${pageSize.height}");

        double finalX = x;
        double finalY = y;

        if (finalX < 0) finalX = 0;
        if (finalY < 0) finalY = 0;
        if (finalX + width > pageSize.width) finalX = pageSize.width - width;
        if (finalY + height > pageSize.height) {
          finalY = pageSize.height - height;
        }

        page.graphics.drawImage(
          PdfBitmap(image),
          Rect.fromLTWH(finalX, finalY, width, height),
        );
      }

      final List<int> bytes = await document.save();
      return Uint8List.fromList(bytes);
    } finally {
      document.dispose();
    }
  }
}
