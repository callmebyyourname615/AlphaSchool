import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/services/global_alert_service.dart';
import '../../../../../core/services/session_service.dart';
import '../../../../../core/theme/app_icons.dart';
import '../../../../../shared/models/student_card_item.dart';
import 'parent_task_chat_service.dart';
import 'parent_task_list_page.dart';

// Same light, DESIGN.md-aligned palette as parent_task_list_page.dart /
// parent_task_detail_page.dart (re-declared per-file, matching this
// codebase's existing convention rather than a new shared constants file).
const _kNavy = Color(0xFF082653);
const _kBlue = Color(0xFF0756D1);
const _kBlueSoft = Color(0xFFEAF1FF);
const _kBg = Color(0xFFF5F8FE);
const _kBorder = Color(0xFFE3E9F2);
const _kMuted = Color(0xFF647594);
const _kMutedSoft = Color(0xFF8A98B0);

enum _LoadState { loading, loaded, error }

enum _ChatAttachmentKind { file, image }

class ParentTaskChatPage extends StatefulWidget {
  final ParentTaskItem task;
  final StudentCardItem student;

  const ParentTaskChatPage({
    super.key,
    required this.task,
    required this.student,
  });

  @override
  State<ParentTaskChatPage> createState() => _ParentTaskChatPageState();
}

class _ParentTaskChatPageState extends State<ParentTaskChatPage> {
  final _service = TaskChatService();
  final _scrollCtrl = ScrollController();
  final _inputCtrl = TextEditingController();
  final _picker = ImagePicker();
  final _recorder = AudioRecorder();

  _LoadState _loadState = _LoadState.loading;
  List<ChatMessage> _messages = const [];
  String? _parentId;
  bool _sending = false;
  ChatMessage? _replyingTo;
  bool _recording = false;
  final Map<String, GlobalKey> _messageKeys = {};
  String? _highlightedMessageId;

  String get _studentId => widget.student.id ?? widget.student.studentId;

  @override
  void initState() {
    super.initState();
    _loadSession();
    _loadMessages(showLoading: true);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _inputCtrl.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _loadSession() async {
    final session = await SessionService().load();
    if (!mounted) return;
    setState(() => _parentId = session?.id);
  }

  Future<void> _loadMessages({bool showLoading = false}) async {
    if (showLoading) setState(() => _loadState = _LoadState.loading);
    try {
      final messages = await _service.fetchMessages(
        taskId: widget.task.id,
        studentId: _studentId,
        fallbackTeacherName: widget.task.teacher,
      );
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _loadState = _LoadState.loaded;
      });
      _scrollToBottom(animate: false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadState = _LoadState.error);
    }
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      final target = _scrollCtrl.position.maxScrollExtent;
      if (animate) {
        _scrollCtrl.animateTo(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      } else {
        _scrollCtrl.jumpTo(target);
      }
    });
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    final parentId = _parentId;
    if (parentId == null || parentId.isEmpty) {
      GlobalAlert.showError(
        title: 'Not signed in',
        message: 'Please sign in again to send messages.',
      );
      return;
    }

    setState(() => _sending = true);
    try {
      await _service.sendMessage(
        taskId: widget.task.id,
        parentId: parentId,
        studentId: _studentId,
        text: text,
        replyToId: _replyingTo?.id,
      );
      _inputCtrl.clear();
      _replyingTo = null;
      await _loadMessages();
      _scrollToBottom();
    } catch (_) {
      GlobalAlert.showError(
        title: 'Message not sent',
        message: 'Please check your connection and try again.',
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _react(ChatMessage message, String emoji) async {
    final parentId = _parentId;
    if (parentId == null) return;
    try {
      await _service.toggleReaction(
        commentId: message.id,
        parentId: parentId,
        emoji: emoji,
      );
      await _loadMessages();
    } catch (_) {
      _toast('Reaction failed. Please try again.');
    }
  }

  void _jumpToMessage(String id) {
    final ctx = _messageKeys[id]?.currentContext;
    if (ctx == null) {
      _toast('Original message not found.');
      return;
    }
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 300),
      alignment: 0.5,
    );
    setState(() => _highlightedMessageId = id);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted && _highlightedMessageId == id) {
        setState(() => _highlightedMessageId = null);
      }
    });
  }

  Future<void> _pickAndSendAttachment(_ChatAttachmentKind kind) async {
    try {
      XFile? file;
      if (kind == _ChatAttachmentKind.image) {
        file = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 90,
          maxWidth: 2400,
        );
      } else {
        file = await openFile(
          acceptedTypeGroups: const [
            XTypeGroup(
              label: 'Chat files',
              extensions: ['pdf', 'doc', 'docx', 'mp3', 'm4a', 'wav', 'ogg'],
            ),
          ],
        );
      }
      if (file == null) return;
      await _sendAttachment(await file.readAsBytes(), file.name);
    } catch (_) {
      _toast('Could not select this file.');
    }
  }

  Future<void> _sendAttachment(List<int> bytes, String fileName) async {
    final parentId = _parentId;
    if (parentId == null || parentId.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final messageId = await _service.createMessage(
        taskId: widget.task.id,
        parentId: parentId,
        studentId: _studentId,
        replyToId: _replyingTo?.id,
      );
      await _service.uploadAttachment(
        commentId: messageId,
        bytes: Uint8List.fromList(bytes),
        fileName: fileName,
      );
      _replyingTo = null;
      await _loadMessages();
      _scrollToBottom();
    } catch (_) {
      _toast('Attachment was not sent.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _toggleRecording() async {
    if (_recording) {
      final path = await _recorder.stop();
      if (mounted) setState(() => _recording = false);
      if (path != null) {
        final file = XFile(path);
        await _sendAttachment(
          await file.readAsBytes(),
          'voice-${DateTime.now().millisecondsSinceEpoch}.m4a',
        );
      }
      return;
    }
    if (!await _recorder.hasPermission()) {
      _toast('Microphone permission is required.');
      return;
    }
    final tempDir = await getTemporaryDirectory();
    await _recorder.start(
      RecordConfig(encoder: AudioEncoder.aacLc),
      path:
          '${tempDir.path}/voice-${DateTime.now().millisecondsSinceEpoch}.m4a',
    );
    if (mounted) setState(() => _recording = true);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ChatHeader(
              subtitle: widget.task.title,
              onMoreTap: () => _toast('More options coming soon'),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: TaskMiniCard(
                task: widget.task,
                onTap: () => Navigator.maybePop(context),
              ),
            ),
            Expanded(child: _buildBody()),
            Container(
              padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + bottomInset),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: _kBorder)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_replyingTo != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _kBlueSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Replying to ${_replyingTo!.senderName}: ${_replyingTo!.text}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: _kNavy,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(LucideIcons.x, size: 16),
                            onPressed: () => setState(() => _replyingTo = null),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      Material(
                        color: _kBg,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () =>
                              _pickAndSendAttachment(_ChatAttachmentKind.file),
                          child: const SizedBox(
                            width: 40,
                            height: 40,
                            child: Icon(
                              LucideIcons.upload,
                              size: 17,
                              color: _kMuted,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: _kBg,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _sending
                              ? null
                              : () => _pickAndSendAttachment(
                                  _ChatAttachmentKind.image,
                                ),
                          child: const SizedBox(
                            width: 40,
                            height: 40,
                            child: Icon(
                              LucideIcons.image,
                              size: 17,
                              color: _kMuted,
                            ),
                          ),
                        ),
                      ),
                      Material(
                        color: _recording ? Colors.red.shade50 : _kBg,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _sending ? null : _toggleRecording,
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: Icon(
                              _recording ? Icons.stop : Icons.mic,
                              size: 17,
                              color: _recording ? Colors.red : _kMuted,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _inputCtrl,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          enabled: !_sending,
                          style: const TextStyle(fontSize: 14, color: _kNavy),
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: const TextStyle(
                              color: _kMutedSoft,
                              fontSize: 14,
                            ),
                            filled: true,
                            fillColor: _kBg,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(999),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(999),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(999),
                              borderSide: const BorderSide(
                                color: _kBlue,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: _kBlue,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _sending ? null : _send,
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: _sending
                                ? const Padding(
                                    padding: EdgeInsets.all(11),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    LucideIcons.send,
                                    size: 17,
                                    color: Colors.white,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_loadState) {
      case _LoadState.loading:
        return const Center(child: CircularProgressIndicator(color: _kBlue));
      case _LoadState.error:
        return _ChatStatus(
          icon: LucideIcons.circleAlert,
          title: "Couldn't load messages",
          message: 'Check your connection and try again.',
          actionLabel: 'Retry',
          onAction: () => _loadMessages(showLoading: true),
        );
      case _LoadState.loaded:
        if (_messages.isEmpty) {
          return const _ChatStatus(
            icon: LucideIcons.messageCircle,
            title: 'No messages yet',
            message:
                'Send a message to start the conversation with the teacher.',
          );
        }
        return ListView(
          controller: _scrollCtrl,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: _buildMessageWidgets(),
        );
    }
  }

  List<Widget> _buildMessageWidgets() {
    final widgets = <Widget>[];
    DateTime? lastDate;

    for (final message in _messages) {
      final day = DateTime(
        message.createdAt.year,
        message.createdAt.month,
        message.createdAt.day,
      );
      if (lastDate == null || day != lastDate) {
        widgets.add(
          _DateSeparator(label: DateFormat('MMM d, yyyy').format(day)),
        );
        lastDate = day;
      }
      final key = _messageKeys.putIfAbsent(message.id, () => GlobalKey());
      final highlighted = _highlightedMessageId == message.id;
      widgets.add(
        GestureDetector(
          key: key,
          onLongPress: () => _showMessageActions(message),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: highlighted ? _kBlueSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: _MessageBubble(
              message: message,
              currentParentId: _parentId,
              onReplyTap: _jumpToMessage,
              onReactTap: (emoji) => _react(message, emoji),
              onStartReply: () => setState(() => _replyingTo = message),
              onOpenReactionPicker: () => _showMessageActions(message),
            ),
          ),
        ),
      );
      widgets.add(const SizedBox(height: 12));
    }
    return widgets;
  }

  Future<void> _showMessageActions(ChatMessage message) async {
    final parentId = _parentId;
    if (parentId == null) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final emoji in kReactionEmojis)
                    Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _react(message, emoji);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(sheetContext);
                setState(() => _replyingTo = message);
              },
            ),
            if (message.sender == ChatSenderType.parent)
              ListTile(
                leading: const Icon(LucideIcons.trash2, color: Colors.red),
                title: const Text(
                  'Delete message',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _service.deleteMessage(message.id);
                  await _loadMessages();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  final String subtitle;
  final VoidCallback onMoreTap;

  const _ChatHeader({required this.subtitle, required this.onMoreTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.maybePop(context),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(LucideIcons.chevronLeft, size: 24, color: _kNavy),
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                const Text(
                  'Task Chat',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _kNavy,
                  ),
                ),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: _kMuted),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onMoreTap,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.more_horiz, size: 22, color: _kNavy),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatStatus extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _ChatStatus({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: _kMutedSoft),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _kNavy,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: _kMuted),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _DateSeparator extends StatelessWidget {
  final String label;

  const _DateSeparator({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _kBorder),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, color: _kMutedSoft),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final String? currentParentId;
  final ValueChanged<String> onReplyTap;
  final ValueChanged<String> onReactTap;
  final VoidCallback onStartReply;
  final VoidCallback onOpenReactionPicker;

  const _MessageBubble({
    required this.message,
    required this.currentParentId,
    required this.onReplyTap,
    required this.onReactTap,
    required this.onStartReply,
    required this.onOpenReactionPicker,
  });

  @override
  Widget build(BuildContext context) {
    return message.sender == ChatSenderType.admin
        ? _TeacherBubble(
            message: message,
            currentParentId: currentParentId,
            onReplyTap: onReplyTap,
            onReactTap: onReactTap,
            onStartReply: onStartReply,
            onOpenReactionPicker: onOpenReactionPicker,
          )
        : _ParentBubble(
            message: message,
            currentParentId: currentParentId,
            onReplyTap: onReplyTap,
            onReactTap: onReactTap,
            onStartReply: onStartReply,
            onOpenReactionPicker: onOpenReactionPicker,
          );
  }
}

class _TeacherBubble extends StatelessWidget {
  final ChatMessage message;
  final String? currentParentId;
  final ValueChanged<String> onReplyTap;
  final ValueChanged<String> onReactTap;
  final VoidCallback onStartReply;
  final VoidCallback onOpenReactionPicker;

  const _TeacherBubble({
    required this.message,
    required this.currentParentId,
    required this.onReplyTap,
    required this.onReactTap,
    required this.onStartReply,
    required this.onOpenReactionPicker,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: _kBlueSoft,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(LucideIcons.user, size: 16, color: _kBlue),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      message.senderName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _kNavy,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('h:mm a').format(message.createdAt),
                    style: const TextStyle(fontSize: 11, color: _kMutedSoft),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (message.replyTo != null) ...[
                _ReplyPreview(
                  reply: message.replyTo!,
                  onDark: false,
                  onTap: () => onReplyTap(message.replyTo!.id),
                ),
                const SizedBox(height: 6),
              ],
              if (message.text.trim().isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxWidth: 280),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: _kBorder),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(6),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                    ),
                  ),
                  child: Text(
                    message.text,
                    style: const TextStyle(
                      fontSize: 14,
                      color: _kNavy,
                      height: 1.4,
                    ),
                  ),
                ),
              if (message.attachments.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final file in message.attachments)
                      _ChatAttachment(file: file),
                  ],
                ),
              ],
              if (message.reactions.isNotEmpty) ...[
                const SizedBox(height: 6),
                _ReactionPill(
                  reactions: message.reactions,
                  currentParentId: currentParentId,
                  onTap: onReactTap,
                ),
              ],
              _MessageQuickActions(
                onReply: onStartReply,
                onReact: onOpenReactionPicker,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ParentBubble extends StatelessWidget {
  final ChatMessage message;
  final String? currentParentId;
  final ValueChanged<String> onReplyTap;
  final ValueChanged<String> onReactTap;
  final VoidCallback onStartReply;
  final VoidCallback onOpenReactionPicker;

  const _ParentBubble({
    required this.message,
    required this.currentParentId,
    required this.onReplyTap,
    required this.onReactTap,
    required this.onStartReply,
    required this.onOpenReactionPicker,
  });

  @override
  Widget build(BuildContext context) {
    final hasText = message.text.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'You',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _kNavy,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              DateFormat('h:mm a').format(message.createdAt),
              style: const TextStyle(fontSize: 11, color: _kMutedSoft),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (message.replyTo != null) ...[
          _ReplyPreview(
            reply: message.replyTo!,
            onDark: false,
            onTap: () => onReplyTap(message.replyTo!.id),
          ),
          const SizedBox(height: 6),
        ],
        // Blue bubble only wraps real text — attachment-only sends (which the
        // API stores with a placeholder ' ' comment) skip it entirely instead
        // of showing an oversized blue box around near-empty content.
        if (hasText)
          Container(
            constraints: const BoxConstraints(maxWidth: 280),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: _kBlue,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(6),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: Text(
              message.text,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                height: 1.4,
              ),
            ),
          ),
        if (message.attachments.isNotEmpty) ...[
          SizedBox(height: hasText ? 6 : 0),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final file in message.attachments)
                _ChatAttachment(file: file),
            ],
          ),
        ],
        if (message.reactions.isNotEmpty) ...[
          const SizedBox(height: 6),
          _ReactionPill(
            reactions: message.reactions,
            currentParentId: currentParentId,
            onTap: onReactTap,
          ),
        ],
        _MessageQuickActions(
          onReply: onStartReply,
          onReact: onOpenReactionPicker,
          alignEnd: true,
        ),
      ],
    );
  }
}

class _MessageQuickActions extends StatelessWidget {
  const _MessageQuickActions({
    required this.onReply,
    required this.onReact,
    this.alignEnd = false,
  });

  final VoidCallback onReply;
  final VoidCallback onReact;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) => Align(
    alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Reply',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.reply_outlined, size: 19, color: _kMutedSoft),
          onPressed: onReply,
        ),
        IconButton(
          tooltip: 'React',
          visualDensity: VisualDensity.compact,
          icon: const Icon(
            Icons.sentiment_satisfied_alt_outlined,
            size: 20,
            color: _kMutedSoft,
          ),
          onPressed: onReact,
        ),
      ],
    ),
  );
}

class _ReactionPill extends StatelessWidget {
  final List<ChatReaction> reactions;
  final String? currentParentId;
  final ValueChanged<String> onTap;

  const _ReactionPill({
    required this.reactions,
    required this.currentParentId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [for (final r in reactions) _pill(r)],
    );
  }

  Widget _pill(ChatReaction r) {
    final mine = r.reactedBy(currentParentId);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => onTap(r.emoji),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: mine ? _kBlueSoft : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: mine ? _kBlue : _kBorder),
          ),
          child: Text(
            '${r.emoji} ${r.count}',
            style: TextStyle(
              fontSize: 12,
              color: mine ? _kBlue : _kNavy,
              fontWeight: mine ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReplyPreview extends StatelessWidget {
  final ChatReply reply;
  final bool onDark;
  final VoidCallback? onTap;

  const _ReplyPreview({required this.reply, required this.onDark, this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        // Capped to match the sent-message bubble's own maxWidth (280) so the
        // quote reads as an attachment to that bubble instead of stretching
        // across the whole chat row.
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        decoration: BoxDecoration(
          color: onDark ? Colors.white.withValues(alpha: .16) : _kBlueSoft,
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(color: onDark ? Colors.white : _kBlue, width: 3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.reply, size: 14, color: onDark ? Colors.white : _kBlue),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    reply.senderName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: onDark ? Colors.white : _kBlue,
                    ),
                  ),
                  Text(
                    reply.text.trim().isEmpty ? 'Attachment' : reply.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: onDark ? Colors.white70 : _kMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ChatAttachment extends StatelessWidget {
  final TaskFileRef file;

  const _ChatAttachment({required this.file});

  Future<void> _open() async {
    final uri = Uri.tryParse(file.url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final ext = file.name.split('.').last.toLowerCase();
    final isImage = const ['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext);
    if (isImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          file.url,
          width: 180,
          height: 130,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _documentTile(context, ext),
        ),
      );
    }
    return _documentTile(context, ext);
  }

  Widget _documentTile(BuildContext context, String ext) {
    const fg = _kNavy;
    const bg = _kBg;
    final icon = ext == 'pdf'
        ? Icons.picture_as_pdf
        : (ext == 'doc' || ext == 'docx'
              ? Icons.description
              : Icons.insert_drive_file);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: _open,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
