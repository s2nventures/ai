// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

import '../../chat_view_model/chat_view_model_client.dart';
import '../../providers/interface/attachments.dart';
import '../../styles/text_attachment_style.dart';

/// A widget that displays a text attachment.
///
/// This widget creates a container with a text icon and information about the
/// attached text content, such as its name and a preview of the text.
@immutable
class TextAttachmentView extends StatelessWidget {
  /// Creates a TextAttachmentView.
  ///
  /// The [attachment] parameter must not be null and represents the
  /// text attachment to be displayed.
  const TextAttachmentView(this.attachment, {super.key});

  /// The text attachment to be displayed.
  final TextAttachment attachment;

  @override
  Widget build(BuildContext context) => ChatViewModelClient(
    builder: (context, viewModel, child) {
      final attachmentStyle = TextAttachmentStyle.resolve(
        viewModel.style?.textAttachmentStyle,
      );

      return Container(
        height: 80,
        padding: const EdgeInsets.all(8),
        decoration: attachmentStyle.decoration,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            Container(
              height: 64,
              padding: const EdgeInsets.all(10),
              decoration: attachmentStyle.iconDecoration,
              child: Icon(
                attachmentStyle.icon,
                color: attachmentStyle.iconColor,
                size: 24,
              ),
            ),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      attachment.name,
                      style: attachmentStyle.nameStyle,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      attachment.text.length > 50
                          ? "${attachment.text.substring(0, 50)}..."
                          : attachment.text,
                      style: attachmentStyle.previewStyle,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
