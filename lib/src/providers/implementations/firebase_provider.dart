// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show utf8;

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';

import '../interface/attachments.dart';
import '../interface/chat_message.dart';
import '../interface/llm_provider.dart';

/// A provider class for interacting with Firebase Vertex AI's language model.
///
/// This class extends [LlmProvider] and implements the necessary methods to
/// generate text using Firebase Vertex AI's generative model.
class FirebaseProvider extends LlmProvider with ChangeNotifier {
  /// Creates a new instance of [FirebaseProvider].
  ///
  /// [model] is an optional [GenerativeModel] instance for text generation. If
  /// provided, it will be used for chat-based interactions and text generation.
  ///
  /// [history] is an optional list of previous chat messages to initialize the
  /// chat session with.
  ///
  /// [chatSafetySettings] is an optional list of safety settings to apply to
  /// the model's responses.
  ///
  /// [chatGenerationConfig] is an optional configuration for controlling the
  /// model's generation behavior.
  ///
  /// [maxHistoryTurns] optionally limits how many recent user turns are sent
  /// in full to the API. Older turns are compacted into a text-only summary
  /// (dropping image/file bytes) to reduce token usage. The display history
  /// is preserved intact. A value of 0 or null disables compaction.
  FirebaseProvider({
    required GenerativeModel model,
    void Function(Iterable<FunctionCall>)? onFunctionCalls,
    Iterable<ChatMessage>? history,
    List<SafetySetting>? chatSafetySettings,
    GenerationConfig? chatGenerationConfig,
    Future<Map<String, Object?>?> Function(FunctionCall)? onFunctionCall,
    int? maxHistoryTurns,
  }) : _model = model,
       _history = history?.toList() ?? [],
       _chatSafetySettings = chatSafetySettings,
       _chatGenerationConfig = chatGenerationConfig,
       _onFunctionCall = onFunctionCall,
       _maxHistoryTurns = (maxHistoryTurns ?? 0) > 0 ? maxHistoryTurns : null {
    _chat = _startChat(_history);
    _compactChatSessionIfNeeded();
  }

  final GenerativeModel _model;
  final List<SafetySetting>? _chatSafetySettings;
  final GenerationConfig? _chatGenerationConfig;
  final List<ChatMessage> _history;
  final Future<Map<String, Object?>?> Function(FunctionCall)? _onFunctionCall;
  final int? _maxHistoryTurns;
  ChatSession? _chat;

  @override
  Stream<String> generateStream(
    String prompt, {
    Iterable<Attachment> attachments = const [],
  }) => _sendMessageStream(
    prompt: prompt,
    attachments: attachments,
    // we need a chat session to handle multiple turns with function calls, but
    // we don't want it to affect the main history that this provider is
    // managing. so we create a new chat session for this single request.
    chat: _startChat(null)!,
  );

  @override
  Stream<String> sendMessageStream(
    String prompt, {
    Iterable<Attachment> attachments = const [],
  }) async* {
    final userMessage = ChatMessage.user(prompt, attachments);
    final llmMessage = ChatMessage.llm();
    _history.addAll([userMessage, llmMessage]);

    final response = _sendMessageStream(
      prompt: prompt,
      attachments: attachments,
      chat: _chat!,
    );

    // don't write this code if you're targeting the web until this is fixed:
    // https://github.com/dart-lang/sdk/issues/47764
    // await for (final chunk in response) {
    //   llmMessage.append(chunk);
    //   yield chunk;
    // }
    yield* response.map((chunk) {
      llmMessage.append(chunk);
      return chunk;
    });

    // Compact the API chat session if history exceeds the turn limit.
    // The display history (_history) is preserved intact; only the
    // ChatSession is rebuilt with a compacted version to reduce API tokens.
    _compactChatSessionIfNeeded();

    // notify listeners that the history has changed when response is complete
    notifyListeners();
  }

  Stream<String> _sendMessageStream({
    required String prompt,
    required Iterable<Attachment> attachments,
    required ChatSession chat,
  }) async* {
    final content = Content('user', [
      TextPart(prompt),
      ...attachments.map(_partFrom),
    ]);

    // Get initial response stream
    var responseStream = chat.sendMessageStream(content);

    while (true) {
      final functionCalls = <FunctionCall>[];

      // Stream out all text and collect function calls
      await for (final chunk in responseStream) {
        if (chunk.text != null) {
          yield chunk.text!;
        }
        if (chunk.functionCalls.isNotEmpty) {
          functionCalls.addAll(chunk.functionCalls);
        }
      }

      // If no function calls were collected, we're done
      if (functionCalls.isEmpty) {
        break;
      }

      // Add newline between responses
      yield '\n';

      // Execute all function calls
      final functionResponses = <FunctionResponse>[];
      for (final functionCall in functionCalls) {
        try {
          functionResponses.add(
            FunctionResponse(
              functionCall.name,
              await _onFunctionCall?.call(functionCall) ?? {},
            ),
          );
        } catch (ex) {
          functionResponses.add(
            FunctionResponse(functionCall.name, {'error': ex.toString()}),
          );
        }
      }

      // Get the next response stream with function results
      responseStream = chat.sendMessageStream(
        Content.functionResponses(functionResponses),
      );
    }
  }

  @override
  Iterable<ChatMessage> get history => _history;

  @override
  set history(Iterable<ChatMessage> history) {
    _history.clear();
    _history.addAll(history);
    _chat = _startChat(history);
    _compactChatSessionIfNeeded();
    notifyListeners();
  }

  /// Rebuilds the [ChatSession] with a compacted history if the number of
  /// user turns exceeds [_maxHistoryTurns].
  ///
  /// Older turns are converted to a concise text-only summary (dropping
  /// binary attachments like images), while the most recent turns are kept
  /// in full with their original attachments. This bounds the per-request
  /// input token count to roughly O([_maxHistoryTurns]) instead of O(N).
  void _compactChatSessionIfNeeded() {
    final limit = _maxHistoryTurns;

    if (limit == null) {
      return;
    }

    final userTurns = _history.where((m) => m.origin.isUser).length;

    if (userTurns <= limit) {
      return;
    }

    // Walk backward to find the split point that keeps the last `limit`
    // user turns (plus their paired LLM responses).
    var kept = 0;
    var splitIndex = 0;

    for (var i = _history.length - 1; i >= 0; i--) {
      if (_history[i].origin.isUser) {
        kept++;

        if (kept >= limit) {
          splitIndex = i;
          break;
        }
      }
    }

    if (splitIndex <= 0) {
      return;
    }

    final older = _history.sublist(0, splitIndex);
    final recent = _history.sublist(splitIndex);

    // Build a concise text-only recap of older messages, capped in length.
    final recap = StringBuffer()
      ..writeln(
        "[Earlier conversation summary \u2014 "
        "${older.length} messages compacted]",
      );

    var recapLength = 0;
    const maxRecapChars = 4000;

    for (final msg in older) {
      if (recapLength >= maxRecapChars) {
        recap.writeln("...(earlier messages omitted)");
        break;
      }

      final role = msg.origin.isUser ? "User" : "Assistant";
      final text = msg.text?.trim();

      if (text != null && text.isNotEmpty) {
        final truncated =
            text.length > 200 ? "${text.substring(0, 200)}..." : text;
        final line = "$role: $truncated";
        recap.writeln(line);
        recapLength += line.length;
      }
    }

    final compactedContents = <Content>[
      // Inject the recap as a synthetic model message so the LLM retains
      // context from the earlier conversation.
      Content("model", [TextPart(recap.toString())]),
      // Recent turns in full (including attachments).
      ...recent.map(_contentFrom),
    ];

    _chat = _model.startChat(
      history: compactedContents,
      safetySettings: _chatSafetySettings,
      generationConfig: _chatGenerationConfig,
    );
  }

  ChatSession? _startChat(Iterable<ChatMessage>? history) => _model.startChat(
    history: history?.map(_contentFrom).toList(),
    safetySettings: _chatSafetySettings,
    generationConfig: _chatGenerationConfig,
  );

  static Part _partFrom(Attachment attachment) => switch (attachment) {
    (final FileAttachment a) => InlineDataPart(a.mimeType, a.bytes),
    (final LinkAttachment a) => TextPart(a.url.toString()),
    (final TextAttachment a) => InlineDataPart(
      'text/plain',
      utf8.encode(a.text),
    ),
  };

  static Content _contentFrom(ChatMessage message) => Content(
    message.origin.isUser ? 'user' : 'model',
    [TextPart(message.text ?? ''), ...message.attachments.map(_partFrom)],
  );
}
