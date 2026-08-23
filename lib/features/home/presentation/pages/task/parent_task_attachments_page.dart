import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/services/global_alert_service.dart';
import '../../../../../core/services/session_service.dart';
import '../../../../../core/theme/app_icons.dart';
import '../../../../../shared/models/student_card_item.dart';
import 'parent_task_list_page.dart';
import 'parent_task_submission_service.dart';

// Same light, DESIGN.md-aligned palette as the other task pages
// (re-declared per-file, matching this codebase's existing convention).
const _kNavy = Color(0xFF082653);
const _kBlue = Color(0xFF0756D1);
const _kBlueSoft = Color(0xFFEAF1FF);
const _kRed = Color(0xFFEF4444);
const _kPurple = Color(0xFF7C3AED);
const _kBg = Color(0xFFF5F8FE);
const _kBorder = Color(0xFFE3E9F2);
const _kMuted = Color(0xFF647594);
const _kMutedSoft = Color(0xFF8A98B0);

class ParentTaskAttachmentsPage extends StatefulWidget {
  final ParentTaskItem task;
  final StudentCardItem student;

  const ParentTaskAttachmentsPage({
    super.key,
    required this.task,
    required this.student,
  });

  @override
  State<ParentTaskAttachmentsPage> createState() =>
      _ParentTaskAttachmentsPageState();
}

class _ParentTaskAttachmentsPageState extends State<ParentTaskAttachmentsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);
  final _service = TaskSubmissionService();
  final _picker = ImagePicker();

  bool _loadingSubmission = true;
  String? _submissionId;
  List<TaskFileRef> _submissionFiles = const [];
  List<TaskSubmissionSlot> _slots = const [];
  int? _selectedSlotIndex;
  bool _uploading = false;

  // A picked-but-not-yet-uploaded file — browsing only stages it here, the
  // parent must explicitly tap Upload to actually submit it.
  Uint8List? _stagedBytes;
  String? _stagedFileName;

  String get _studentId => widget.student.id ?? widget.student.studentId;

  @override
  void initState() {
    super.initState();
    _loadSubmission();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadSubmission() async {
    setState(() => _loadingSubmission = true);
    try {
      final submission = await _service.fetchSubmission(
        taskId: widget.task.id,
        studentId: _studentId,
      );
      final id = submission?['id']?.toString();
      final files = (id != null && id.isNotEmpty)
          ? await _service.fetchSubmissionFiles(id)
          : const <TaskFileRef>[];
      final slots = widget.task.submissionPlanDates.isEmpty
          ? const <TaskSubmissionSlot>[]
          : await _service.syncSlots(
              taskId: widget.task.id,
              studentId: _studentId,
            );
      if (!mounted) return;
      setState(() {
        _submissionId = id;
        _submissionFiles = files;
        _slots = _deduplicateSlots(slots);
        if (_slots.isEmpty) _slots = _scheduledFallbackSlots;
        _selectedSlotIndex = _nextUploadSlot(_slots);
        _loadingSubmission = false;
      });
    } catch (_) {
      if (!mounted) return;
      final fallbackSlots = _scheduledFallbackSlots;
      setState(() {
        _slots = fallbackSlots;
        _selectedSlotIndex = _nextUploadSlot(fallbackSlots);
        _loadingSubmission = false;
      });
    }
  }

  List<TaskSubmissionSlot> _deduplicateSlots(List<TaskSubmissionSlot> slots) {
    final expectedDates = widget.task.submissionPlanDates;
    final byRound = <int, List<TaskSubmissionSlot>>{};
    for (final slot in slots) {
      byRound.putIfAbsent(slot.scheduleIndex, () => []).add(slot);
    }
    final result = <TaskSubmissionSlot>[];
    for (var index = 1; index <= expectedDates.length; index++) {
      final candidates = byRound[index] ?? const <TaskSubmissionSlot>[];
      if (candidates.isEmpty) continue;
      final expected = expectedDates[index - 1];
      result.add(
        candidates.firstWhere(
          (slot) => _sameDay(slot.dueAt, expected),
          orElse: () => candidates.last,
        ),
      );
    }
    // Keep a graceful fallback for older tasks whose plan dates are absent.
    if (result.isEmpty) {
      result.addAll(byRound.values.map((items) => items.last));
    }
    result.sort((a, b) => a.scheduleIndex.compareTo(b.scheduleIndex));
    return result;
  }

  List<TaskSubmissionSlot> get _scheduledFallbackSlots => widget
      .task
      .submissionPlanDates
      .asMap()
      .entries
      .map(
        (entry) => TaskSubmissionSlot(
          scheduleIndex: entry.key + 1,
          dueAt: entry.value,
          status: 'pending',
        ),
      )
      .toList();

  bool _sameDay(DateTime left, DateTime right) =>
      left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;

  // The plan is sequential: parents are always guided to the earliest round
  // they can still submit, rather than choosing a checkpoint themselves.
  int? _nextUploadSlot(List<TaskSubmissionSlot> slots) {
    for (final slot in slots) {
      final isLockedMissed =
          slot.status == 'missed' && !widget.task.allowLateSubmission;
      if (!slot.isSubmitted && !isLockedMissed) {
        return slot.scheduleIndex;
      }
    }
    return slots.isEmpty ? null : slots.last.scheduleIndex;
  }

  TaskSubmissionSlot? get _selectedSlot {
    for (final slot in _slots) {
      if (slot.scheduleIndex == _selectedSlotIndex) return slot;
    }
    return null;
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _openFile(TaskFileRef file) async {
    final uri = file.url.isEmpty ? null : Uri.tryParse(file.url);
    final opened =
        uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !mounted) return;
    _toast('Could not open ${file.name}');
  }

  Future<void> _showUploadSheet() async {
    final source = await showModalBottomSheet<_UploadSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _UploadSourceSheet(),
    );
    if (source == null || !mounted) return;

    try {
      XFile? picked;
      if (source == _UploadSource.camera) {
        picked = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
          maxWidth: 2000,
        );
      } else if (source == _UploadSource.gallery) {
        picked = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 90,
          maxWidth: 2400,
        );
      } else {
        picked = await openFile(
          acceptedTypeGroups: const [
            XTypeGroup(label: 'Documents', extensions: ['pdf', 'doc', 'docx']),
          ],
        );
      }
      if (picked == null || !mounted) return;
      final bytes = await picked.readAsBytes();
      setState(() {
        _stagedBytes = bytes;
        _stagedFileName = picked!.name;
      });
    } catch (error) {
      if (!mounted) return;
      GlobalAlert.showError(
        title: 'Could not open file',
        message: error.toString(),
      );
    }
  }

  void _clearStagedFile() {
    setState(() {
      _stagedBytes = null;
      _stagedFileName = null;
    });
  }

  Future<void> _previewStagedFile() async {
    final bytes = _stagedBytes;
    final fileName = _stagedFileName;
    if (bytes == null || fileName == null) return;

    final extension = fileName.split('.').last.toLowerCase();
    final isImage = const {
      'jpg',
      'jpeg',
      'png',
      'gif',
      'webp',
    }.contains(extension);
    if (!isImage && extension != 'pdf') {
      _toast('Preview supports images and PDF files.');
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 900,
          height: 720,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(LucideIcons.x),
                      tooltip: 'Close preview',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: isImage
                    ? InteractiveViewer(
                        child: Image.memory(bytes, fit: BoxFit.contain),
                      )
                    : SfPdfViewer.memory(bytes),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmUpload() async {
    final bytes = _stagedBytes;
    final fileName = _stagedFileName;
    if (bytes == null || fileName == null || _uploading) return;
    if (_selectedSlot?.isSubmitted == true ||
        (_selectedSlot?.status == 'missed' &&
            !widget.task.allowLateSubmission)) {
      _toast('This submission round is locked. Choose an open round.');
      return;
    }
    final success = await _uploadBytes(bytes, fileName);
    if (success && mounted) {
      setState(() {
        _stagedBytes = null;
        _stagedFileName = null;
      });
    }
  }

  Future<bool> _uploadBytes(Uint8List bytes, String fileName) async {
    final studentId = _studentId;
    if (studentId.isEmpty) {
      GlobalAlert.showError(
        title: 'Missing student',
        message: 'No student is selected for this task.',
      );
      return false;
    }

    setState(() => _uploading = true);
    GlobalAlert.showLoading(message: 'Uploading…');
    try {
      final submissionId =
          _submissionId ??
          await _service.ensureSubmission(
            taskId: widget.task.id,
            studentId: studentId,
          );
      final fileId = await _service.uploadFile(
        submissionId: submissionId,
        fileBytes: bytes,
        fileName: fileName,
      );
      final slot = _selectedSlot;
      if (slot != null) {
        final session = await SessionService().load();
        final updatedSlot = await _service.submitSlot(
          taskId: widget.task.id,
          studentId: studentId,
          scheduleIndex: slot.scheduleIndex,
          fileIds: [...slot.fileIds, fileId],
          submittedById: session?.id,
        );
        _slots = _slots
            .map(
              (item) => item.scheduleIndex == updatedSlot.scheduleIndex
                  ? updatedSlot
                  : item,
            )
            .toList();
      }
      final files = await _service.fetchSubmissionFiles(submissionId);
      GlobalAlert.dismiss();
      if (!mounted) return true;
      setState(() {
        _submissionId = submissionId;
        _submissionFiles = files;
        _selectedSlotIndex = _nextUploadSlot(_slots);
        _uploading = false;
      });
      await GlobalAlert.showSuccess(
        title: 'Uploaded',
        message: slot == null
            ? '$fileName was submitted successfully.'
            : '$fileName was submitted for checkpoint ${slot.scheduleIndex}.',
      );
      return true;
    } catch (error) {
      GlobalAlert.dismiss();
      if (!mounted) return false;
      setState(() => _uploading = false);
      GlobalAlert.showError(title: 'Upload failed', message: error.toString());
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final teacherFiles = widget.task.files;

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AttachmentsHeader(
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
            if (_loadingSubmission)
              const SizedBox.shrink()
            else if (_slots.isNotEmpty)
              _SubmissionPlanStrip(
                slots: _slots,
                selectedIndex: _selectedSlotIndex,
                allowLateSubmission: widget.task.allowLateSubmission,
              ),
            Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: _kBorder)),
              ),
              child: TabBar(
                controller: _tab,
                indicatorColor: _kBlue,
                indicatorWeight: 2,
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: Colors.transparent,
                labelColor: _kBlue,
                unselectedLabelColor: _kMuted,
                labelStyle: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
                tabs: [
                  Tab(text: 'From Teacher (${teacherFiles.length})'),
                  Tab(text: 'From You (${_submissionFiles.length})'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _FilesTab(
                    title: 'Files from Teacher',
                    files: teacherFiles,
                    emptyMessage:
                        'The teacher hasn\'t uploaded any files for this task yet.',
                    bottomInset: bottomInset,
                    onOpen: _openFile,
                    showSubmitSection: true,
                    uploading: _uploading,
                    onBrowse: _showUploadSheet,
                    stagedBytes: _stagedBytes,
                    stagedFileName: _stagedFileName,
                    onCancelStaged: _clearStagedFile,
                    onPreviewStaged: _previewStagedFile,
                    onConfirmUpload: _confirmUpload,
                  ),
                  _loadingSubmission
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: _kBlue,
                            strokeWidth: 2.4,
                          ),
                        )
                      : _FilesTab(
                          title: 'Your Submitted Files',
                          files: _submissionFiles,
                          emptyMessage:
                              'You haven\'t submitted any files for this task yet.',
                          bottomInset: bottomInset,
                          onOpen: _openFile,
                          showSubmitSection: true,
                          uploading: _uploading,
                          onBrowse: _showUploadSheet,
                          stagedBytes: _stagedBytes,
                          stagedFileName: _stagedFileName,
                          onCancelStaged: _clearStagedFile,
                          onPreviewStaged: _previewStagedFile,
                          onConfirmUpload: _confirmUpload,
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentsHeader extends StatelessWidget {
  final String subtitle;
  final VoidCallback onMoreTap;

  const _AttachmentsHeader({required this.subtitle, required this.onMoreTap});

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
                  'Attachments',
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

class _SubmissionPlanStrip extends StatelessWidget {
  const _SubmissionPlanStrip({
    required this.slots,
    required this.selectedIndex,
    required this.allowLateSubmission,
  });

  final List<TaskSubmissionSlot> slots;
  final int? selectedIndex;
  final bool allowLateSubmission;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Submission plan',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _kNavy,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Your next available checkpoint is selected automatically.',
            style: TextStyle(fontSize: 12.5, color: _kMuted),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final slot in slots) ...[
                  _CheckpointChip(
                    slot: slot,
                    selected: selectedIndex == slot.scheduleIndex,
                    disabled:
                        slot.isSubmitted ||
                        (slot.status == 'missed' && !allowLateSubmission),
                  ),
                  if (slot != slots.last) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckpointChip extends StatelessWidget {
  const _CheckpointChip({
    required this.slot,
    required this.selected,
    required this.disabled,
  });

  final TaskSubmissionSlot slot;
  final bool selected;
  final bool disabled;

  bool get _isSubmittedLate {
    if (slot.status == 'late') return true;
    final submittedAt = slot.submittedAt;
    if (!slot.isSubmitted || submittedAt == null) return false;
    return submittedAt.isAfter(_effectiveDueAt(slot.dueAt));
  }

  Color get _color => switch (slot.status) {
    'submitted' || 'reviewed' =>
      _isSubmittedLate ? const Color(0xFFB45309) : const Color(0xFF16A34A),
    'late' => const Color(0xFFB45309),
    'missed' => _kRed,
    _ => _kBlue,
  };

  String get _label => switch (slot.status) {
    'submitted' ||
    'reviewed' => _isSubmittedLate ? 'Late Submitted' : 'Early Submitted',
    'late' => 'Late Submitted',
    'missed' => 'Missed',
    _ => 'Due Date',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 138,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: disabled
            ? const Color(0xFFF8FAFC)
            : selected
            ? _kBlueSoft
            : Colors.white,
        border: Border.all(
          color: disabled
              ? _kBorder
              : selected
              ? _kBlue
              : _kBorder,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${slot.scheduleIndex}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _color,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: _color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${slot.dueAt.day.toString().padLeft(2, '0')}/${slot.dueAt.month.toString().padLeft(2, '0')}/${slot.dueAt.year}',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: _kNavy,
            ),
          ),
        ],
      ),
    );
  }
}

DateTime _effectiveDueAt(DateTime dueAt) {
  final hasExplicitTime =
      dueAt.hour != 0 ||
      dueAt.minute != 0 ||
      dueAt.second != 0 ||
      dueAt.millisecond != 0 ||
      dueAt.microsecond != 0;
  if (hasExplicitTime) return dueAt;
  return DateTime(dueAt.year, dueAt.month, dueAt.day, 23, 59, 59, 999, 999);
}

class _FilesTab extends StatelessWidget {
  final String title;
  final List<TaskFileRef> files;
  final String emptyMessage;
  final double bottomInset;
  final ValueChanged<TaskFileRef> onOpen;
  final bool showSubmitSection;
  final bool uploading;
  final VoidCallback onBrowse;
  final Uint8List? stagedBytes;
  final String? stagedFileName;
  final VoidCallback onCancelStaged;
  final VoidCallback onPreviewStaged;
  final VoidCallback onConfirmUpload;

  const _FilesTab({
    required this.title,
    required this.files,
    required this.emptyMessage,
    required this.bottomInset,
    required this.onOpen,
    required this.showSubmitSection,
    required this.uploading,
    required this.onBrowse,
    required this.stagedBytes,
    required this.stagedFileName,
    required this.onCancelStaged,
    required this.onPreviewStaged,
    required this.onConfirmUpload,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottomInset),
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: _kNavy,
          ),
        ),
        const SizedBox(height: 12),
        if (files.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kBorder),
            ),
            child: Text(
              emptyMessage,
              style: const TextStyle(
                fontSize: 13.5,
                color: _kMuted,
                height: 1.4,
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kBorder),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < files.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: _kBorder),
                  _FileRow(file: files[i], onTap: () => onOpen(files[i])),
                ],
              ],
            ),
          ),
        if (showSubmitSection) ...[
          const SizedBox(height: 24),
          const Text(
            'Submit Your Work',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _kNavy,
            ),
          ),
          const SizedBox(height: 12),
          if (stagedBytes == null) ...[
            Material(
              color: _kBlueSoft,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: uploading ? null : onBrowse,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _kBlue, width: 1.4),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          LucideIcons.upload,
                          size: 22,
                          color: _kBlue,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Upload your work here',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _kBlue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Photos, PDF, or other files',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: _kMuted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Material(
              color: _kBlue,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: uploading ? null : onBrowse,
                child: Container(
                  height: 54,
                  alignment: Alignment.center,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.upload, size: 17, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Choose File',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ] else ...[
            // A file has been picked but not uploaded yet — the parent must
            // explicitly confirm before it's actually submitted.
            _StagedFilePreview(bytes: stagedBytes!, fileName: stagedFileName!),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: uploading ? null : onCancelStaged,
                      child: Container(
                        height: 50,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _kBorder),
                        ),
                        child: const Text(
                          'Remove',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: _kMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Material(
                    color: _kBlueSoft,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: uploading ? null : onPreviewStaged,
                      child: Container(
                        height: 50,
                        alignment: Alignment.center,
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.eye, size: 16, color: _kBlue),
                            SizedBox(width: 7),
                            Text(
                              'Preview',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: _kBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Material(
                    color: _kBlue,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: uploading ? null : onConfirmUpload,
                      child: Container(
                        height: 50,
                        alignment: Alignment.center,
                        child: uploading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    LucideIcons.upload,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 7),
                                  Text(
                                    'Upload',
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }
}

class _StagedFilePreview extends StatelessWidget {
  final Uint8List bytes;
  final String fileName;

  const _StagedFilePreview({required this.bytes, required this.fileName});

  bool get _isImage {
    final dot = fileName.lastIndexOf('.');
    final ext = dot >= 0 ? fileName.substring(dot + 1).toLowerCase() : '';
    return ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBlue, width: 1.4),
      ),
      child: Row(
        children: [
          if (_isImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                bytes,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _kBlueSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: const Icon(LucideIcons.fileText, size: 22, color: _kBlue),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _kNavy,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Ready to upload',
                  style: TextStyle(fontSize: 12, color: _kMutedSoft),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  final TaskFileRef file;
  final VoidCallback onTap;

  const _FileRow({required this.file, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dot = file.name.lastIndexOf('.');
    final ext = dot >= 0 ? file.name.substring(dot + 1).toLowerCase() : '';

    final (badge, badgeBg, badgeFg, typeLabel) = switch (ext) {
      'pdf' => ('PDF', _kRed, Colors.white, 'PDF file'),
      'jpg' ||
      'jpeg' ||
      'png' ||
      'gif' ||
      'webp' => ('IMG', const Color(0xFFF1F5F9), _kMutedSoft, 'Image'),
      'mp4' || 'webm' || 'mov' => ('VID', _kPurple, Colors.white, 'Video'),
      'doc' || 'docx' => ('DOC', _kBlue, Colors.white, 'Document'),
      _ => ('FILE', const Color(0xFFF1F5F9), _kMutedSoft, 'File'),
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: badgeFg,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _kNavy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      typeLabel,
                      style: const TextStyle(fontSize: 12, color: _kMutedSoft),
                    ),
                  ],
                ),
              ),
              const Icon(LucideIcons.download, size: 18, color: _kNavy),
            ],
          ),
        ),
      ),
    );
  }
}

enum _UploadSource { camera, gallery, file }

class _UploadSourceSheet extends StatelessWidget {
  const _UploadSourceSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _kBorder,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Submit your work',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _kNavy,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Choose how you want to attach your work.',
            style: TextStyle(fontSize: 13, color: _kMuted),
          ),
          const SizedBox(height: 18),
          _SourceTile(
            icon: LucideIcons.camera,
            title: 'Take a photo',
            onTap: () => Navigator.pop(context, _UploadSource.camera),
          ),
          const SizedBox(height: 10),
          _SourceTile(
            icon: LucideIcons.images,
            title: 'Choose from gallery',
            onTap: () => Navigator.pop(context, _UploadSource.gallery),
          ),
          const SizedBox(height: 10),
          _SourceTile(
            icon: LucideIcons.fileText,
            title: 'Choose a file (PDF, DOC)',
            onTap: () => Navigator.pop(context, _UploadSource.file),
          ),
        ],
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _SourceTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: _kBorder),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _kBlueSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 19, color: _kBlue),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: _kNavy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: _kMutedSoft,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
