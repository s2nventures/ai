// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

import 'tookit_icons.dart';
import 'toolkit_colors.dart';
import 'toolkit_text_styles.dart';

/// Style for text attachments in the chat view.
@immutable
class TextAttachmentStyle {
  /// Creates a TextAttachmentStyle.
  const TextAttachmentStyle({
    this.decoration,
    this.icon,
    this.iconColor,
    this.iconDecoration,
    this.nameStyle,
    this.previewStyle,
  });

  /// Resolves the TextAttachmentStyle by combining the provided style with
  /// default values.
  ///
  /// This method takes an optional [style] and merges it with the
  /// [defaultStyle]. If [defaultStyle] is not provided, it uses
  /// [TextAttachmentStyle.defaultStyle].
  ///
  /// [style] - The custom TextAttachmentStyle to apply. Can be null.
  /// [defaultStyle] - The default TextAttachmentStyle to use as a base. If
  /// null, uses [TextAttachmentStyle.defaultStyle].
  ///
  /// Returns a new [TextAttachmentStyle] instance with resolved properties.
  factory TextAttachmentStyle.resolve(
    TextAttachmentStyle? style, {
    TextAttachmentStyle? defaultStyle,
  }) {
    defaultStyle ??= TextAttachmentStyle.defaultStyle();
    return TextAttachmentStyle(
      decoration: style?.decoration ?? defaultStyle.decoration,
      icon: style?.icon ?? defaultStyle.icon,
      iconColor: style?.iconColor ?? defaultStyle.iconColor,
      iconDecoration: style?.iconDecoration ?? defaultStyle.iconDecoration,
      nameStyle: style?.nameStyle ?? defaultStyle.nameStyle,
      previewStyle: style?.previewStyle ?? defaultStyle.previewStyle,
    );
  }

  /// Provides a default style.
  factory TextAttachmentStyle.defaultStyle() =>
      TextAttachmentStyle._lightStyle();

  /// Provides a default light style.
  factory TextAttachmentStyle._lightStyle() => TextAttachmentStyle(
    decoration: ShapeDecoration(
      color: ToolkitColors.fileContainerBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    icon: ToolkitIcons.attach_file,
    iconColor: ToolkitColors.darkIcon,
    iconDecoration: ShapeDecoration(
      color: ToolkitColors.fileAttachmentIconBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    nameStyle: ToolkitTextStyles.filename,
    previewStyle: ToolkitTextStyles.filetype,
  );

  /// The decoration for the text attachment container.
  final Decoration? decoration;

  /// The icon to display for the text attachment.
  final IconData? icon;

  /// The color of the text attachment icon.
  final Color? iconColor;

  /// The decoration for the text attachment icon container.
  final Decoration? iconDecoration;

  /// The text style for the attachment name.
  final TextStyle? nameStyle;

  /// The text style for the text preview.
  final TextStyle? previewStyle;
}
