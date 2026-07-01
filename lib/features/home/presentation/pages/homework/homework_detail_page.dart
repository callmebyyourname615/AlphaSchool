import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../core/services/global_alert_service.dart';
import '../../../../../shared/models/student_card_item.dart';
import 'homework_models.dart';
import 'homework_service.dart';

// ── Palette (mirrors list page) ──────────────────────────────────────────────
const _kNavy = Color(0xFF1E2D5B);
const _kBlue = Color(0xFF3B82F6);
const _kGreen = Color(0xFF22C55E);
const _kOrange = Color(0xFFF59E0B);
const _kRed = Color(0xFFEF4444);
const _kBg = Color(0xFFF5F7FA);
const _kCardBg = Colors.white;
const _kBorder = Color(0xFFE8ECF0);
const _kMuted = Color(0xFF9CA3AF);
const _kText = Color(0xFF1F2937);

class HomeworkDetailPage extends StatefulWidget {
  final HomeworkItem item;
  final StudentCardItem student;

  const HomeworkDetailPage({
    super.key,
    required this.item,
    required this.student,
  });

  @override
  State<HomeworkDetailPage> createState() => _HomeworkDetailPageState();
}

class _HomeworkDetailPageState extends State<HomeworkDetailPage> {
  final _service = HomeworkService();
  final _picker = ImagePicker();
  bool _submitted = false;

  HomeworkItem get item => widget.item;

  HomeworkVisual get _visual =>
      _submitted ? HomeworkVisual.done : item.visual(DateTime.now());

  Color get _statusColor => switch (_visual) {
    HomeworkVisual.done => _kGreen,
    HomeworkVisual.pending => _kOrange,
    HomeworkVisual.overdue => _kRed,
  };

  String get _statusLabel => switch (_visual) {
    HomeworkVisual.done => 'Done',
    HomeworkVisual.pending => 'Pending',
    HomeworkVisual.overdue => 'Overdue',
  };

  IconData get _statusIcon => switch (_visual) {
    HomeworkVisual.done => LucideIcons.badgeCheck,
    HomeworkVisual.pending => LucideIcons.clock3,
    HomeworkVisual.overdue => LucideIcons.circleAlert,
  };

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final canSubmit = _visual == HomeworkVisual.pending;

    return Scaffold(
      backgroundColor: _kBg,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: canSubmit ? _showSubmitSheet : null,
              style: FilledButton.styleFrom(
                backgroundColor: _kBlue,
                disabledBackgroundColor: _kBorder,
                disabledForegroundColor: _kMuted,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              icon: Icon(
                _visual == HomeworkVisual.done
                    ? LucideIcons.circleCheck
                    : _visual == HomeworkVisual.overdue
                    ? LucideIcons.clock3
                    : LucideIcons.upload,
              ),
              label: Text(
                _visual == HomeworkVisual.done
                    ? 'Homework submitted'
                    : _visual == HomeworkVisual.overdue
                    ? 'Submission closed'
                    : 'Submit homework',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PageHeader(
              title: 'Homework Detail',
              onBack: () => Navigator.maybePop(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, 4, 16, 12 + bottomInset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HeroCard(
                          item: item,
                          statusColor: _statusColor,
                          statusLabel: _statusLabel,
                          statusIcon: _statusIcon,
                        )
                        .animate()
                        .fadeIn(duration: 240.ms)
                        .slideY(
                          begin: .04,
                          end: 0,
                          duration: 380.ms,
                          curve: Curves.easeOutCubic,
                        ),
                    const SizedBox(height: 14),
                    _InfoCard(
                      item: item,
                    ).animate().fadeIn(delay: 80.ms, duration: 220.ms),
                    if (_visual == HomeworkVisual.done) ...[
                      const SizedBox(height: 12),
                      _YourScoreChip(
                        score: item.yourScore,
                        totalScore: item.totalScore,
                        isGraded: item.isGraded,
                      ),
                      if (item.isGraded &&
                          item.items.any((s) => s.awardedScore != null)) ...[
                        const SizedBox(height: 10),
                        _ScoreBreakdownCard(
                          items: item.items,
                          totalScore: item.totalScore,
                        ).animate().fadeIn(delay: 100.ms, duration: 240.ms),
                      ],
                      if (item.isGraded &&
                          (item.teacherRemark ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _TeacherFeedbackCard(text: item.teacherRemark!.trim()),
                      ],
                    ],
                    if ((item.description ?? '').isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _InstructionCard(
                        text: item.description!,
                      ).animate().fadeIn(delay: 120.ms, duration: 220.ms),
                    ],
                    if (item.items.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const _SectionTitle(
                        title: 'Questions',
                        subtitle: 'Tasks in this homework',
                      ).animate().fadeIn(delay: 150.ms, duration: 220.ms),
                      const SizedBox(height: 12),
                      for (int i = 0; i < item.items.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _SubItemCard(index: i + 1, sub: item.items[i])
                              .animate()
                              .fadeIn(
                                delay: Duration(milliseconds: 180 + i * 60),
                                duration: 240.ms,
                              ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSubmitSheet() async {
    final source = await showModalBottomSheet<_UploadSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const _UploadSourceSheet(),
    );
    if (source == null || !mounted) return;

    try {
      if (source == _UploadSource.camera) {
        final image = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
          maxWidth: 2000,
        );
        if (image == null || !mounted) return;
        await _showPreviewSheet(
          _SelectedHomeworkFile(
            bytes: await image.readAsBytes(),
            name: image.name,
            isImage: true,
          ),
        );
      } else {
        final image = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 90,
          maxWidth: 2400,
        );
        if (image == null || !mounted) return;
        await _showPreviewSheet(
          _SelectedHomeworkFile(
            bytes: await image.readAsBytes(),
            name: image.name,
            isImage: true,
          ),
        );
      }
    } catch (error) {
      GlobalAlert.showError(
        title: 'Could not open file',
        message: error.toString(),
      );
    }
  }

  Future<void> _showPreviewSheet(_SelectedHomeworkFile file) async {
    var saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              20 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SheetHandle(),
                const SizedBox(height: 14),
                const Text(
                  'Review submission',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: _kText,
                  ),
                ),
                const SizedBox(height: 14),
                if (file.isImage)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.memory(
                      file.bytes,
                      height: 190,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: _kBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _kBorder),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          LucideIcons.fileText,
                          size: 38,
                          color: _kRed,
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            file.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _kText,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            setSheetState(() => saving = true);
                            try {
                              await _service.submitHomework(
                                homework: item,
                                studentId:
                                    widget.student.id ??
                                    widget.student.studentId,
                                classId: widget.student.classId,
                                branchId: widget.student.branchId,
                                fileBytes: file.bytes,
                                fileName: file.name,
                              );
                              if (!mounted || !sheetContext.mounted) return;
                              Navigator.pop(sheetContext);
                              setState(() => _submitted = true);
                              GlobalAlert.showSuccess(
                                title: 'Submitted',
                                message: 'Homework was submitted successfully.',
                              );
                            } catch (error) {
                              if (!mounted) return;
                              setSheetState(() => saving = false);
                              GlobalAlert.showError(
                                title: 'Submission failed',
                                message: error.toString(),
                              );
                            }
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: _kBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Confirm submission',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

Color _scoreColor(double? awarded, double? max) {
  if (awarded == null || max == null || max <= 0) return _kBlue;
  if (awarded <= 0) return _kRed;
  if (awarded >= max) return _kGreen;
  return _kOrange;
}

String _fmtScoreValue(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

class _ScoreBreakdownCard extends StatelessWidget {
  const _ScoreBreakdownCard({required this.items, required this.totalScore});

  final List<HomeworkSubItem> items;
  final double? totalScore;

  @override
  Widget build(BuildContext context) {
    final graded = items.where((s) => s.awardedScore != null).toList();
    final earned = graded.fold<double>(0, (s, i) => s + (i.awardedScore ?? 0));
    final maxTotal =
        totalScore ?? items.fold<double>(0, (s, i) => s + (i.score ?? 0));
    final ratio = maxTotal <= 0 ? 0.0 : (earned / maxTotal).clamp(0.0, 1.0);
    final barColor = ratio >= 0.8
        ? _kGreen
        : ratio >= 0.5
        ? _kOrange
        : _kRed;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: barColor.withValues(alpha: .14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  LucideIcons.chartNoAxesColumnIncreasing,
                  size: 16,
                  color: barColor,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Score breakdown',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  color: _kNavy,
                  letterSpacing: -.1,
                ),
              ),
              const Spacer(),
              Text(
                '${_fmtScoreValue(earned)} / ${_fmtScoreValue(maxTotal)}',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  color: barColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: const Color(0xFFF1F4F8),
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (int i = 0; i < items.length; i++)
                _QuestionScorePill(index: i + 1, sub: items[i]),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuestionScorePill extends StatelessWidget {
  const _QuestionScorePill({required this.index, required this.sub});

  final int index;
  final HomeworkSubItem sub;

  @override
  Widget build(BuildContext context) {
    final color = _scoreColor(sub.awardedScore, sub.score);
    final hasAwarded = sub.awardedScore != null;
    final label = hasAwarded
        ? '${_fmtScoreValue(sub.awardedScore!)}/${_fmtScoreValue(sub.score ?? 0)}'
        : '—/${_fmtScoreValue(sub.score ?? 0)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Q$index',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: .2,
            ),
          ),
          const SizedBox(width: 6),
          Container(width: 1, height: 11, color: color.withValues(alpha: .25)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _TeacherFeedbackCard extends StatelessWidget {
  const _TeacherFeedbackCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kBlue.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBlue.withValues(alpha: .22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.messageCircle, color: _kBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Teacher feedback',
                  style: TextStyle(color: _kNavy, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                Text(
                  text,
                  style: const TextStyle(
                    color: _kText,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _YourScoreChip extends StatelessWidget {
  const _YourScoreChip({
    required this.score,
    required this.totalScore,
    required this.isGraded,
  });

  final double? score;
  final double? totalScore;
  final bool isGraded;

  @override
  Widget build(BuildContext context) {
    final value = isGraded && score != null
        ? '${_format(score!)}${totalScore == null ? '' : ' / ${_format(totalScore!)}'}'
        : 'Pending';
    final color = isGraded ? _kGreen : _kOrange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .24)),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.award, size: 20, color: color),
          const SizedBox(width: 10),
          const Text(
            'Your Score',
            style: TextStyle(fontWeight: FontWeight.w800, color: _kText),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w900, color: color),
          ),
        ],
      ),
    );
  }

  static String _format(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}

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
          const _SheetHandle(),
          const SizedBox(height: 14),
          const Text(
            'Submit homework',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: _kText,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Choose how you want to attach your work.',
            style: TextStyle(color: _kMuted, fontWeight: FontWeight.w600),
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
            title: 'Upload from phone',
            onTap: () => Navigator.pop(context, _UploadSource.file),
          ),
        ],
      ),
    );
  }
}

enum _UploadSource { camera, file }

class _SelectedHomeworkFile {
  const _SelectedHomeworkFile({
    required this.bytes,
    required this.name,
    required this.isImage,
  });

  final Uint8List bytes;
  final String name;
  final bool isImage;
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: _kBorder,
        borderRadius: BorderRadius.circular(999),
      ),
    ),
  );
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(15),
    child: Container(
      padding: const EdgeInsets.all(15),
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
              color: _kBlue.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _kBlue),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: _kText,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Icon(LucideIcons.chevronRight, color: _kMuted),
        ],
      ),
    ),
  );
}

// ── Header ───────────────────────────────────────────────────────────────────

class _PageHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _PageHeader({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _kCardBg,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: _kBorder),
              ),
              child: const Icon(LucideIcons.arrowLeft, size: 18, color: _kNavy),
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 44),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: _kText,
                    letterSpacing: -.3,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero card ────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final HomeworkItem item;
  final Color statusColor;
  final String statusLabel;
  final IconData statusIcon;

  const _HeroCard({
    required this.item,
    required this.statusColor,
    required this.statusLabel,
    required this.statusIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withValues(alpha: .18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.subject,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: _kText,
                    letterSpacing: -.3,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 13, color: statusColor),
                    const SizedBox(width: 5),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: statusColor,
                        letterSpacing: .2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(LucideIcons.bookOpen, size: 14, color: _kMuted),
              const SizedBox(width: 6),
              Text(
                item.grade,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _kMuted,
                ),
              ),
              if ((item.teacher ?? '').isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '·',
                    style: TextStyle(color: _kMuted, fontSize: 14),
                  ),
                ),
                const Icon(LucideIcons.user, size: 14, color: _kBlue),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    item.teacher!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _kBlue,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ── Info card (Received · Due Date · Total) ──────────────────────────────────

class _InfoCard extends StatelessWidget {
  final HomeworkItem item;

  const _InfoCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final visual = item.visual(DateTime.now());
    final dueColor = visual == HomeworkVisual.overdue ? _kRed : _kText;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          _InfoRow(
            icon: LucideIcons.inbox,
            iconColor: _kBlue,
            label: 'Received',
            value: item.sentAt == null ? '—' : _fmtDate(item.sentAt!),
          ),
          const Divider(height: 1, color: _kBorder),
          _InfoRow(
            icon: LucideIcons.calendarDays,
            iconColor: dueColor == _kRed ? _kRed : _kOrange,
            label: 'Due Date',
            value: _fmtDate(item.deadline),
            valueColor: dueColor,
          ),
          const Divider(height: 1, color: _kBorder),
          _InfoRow(
            icon: LucideIcons.slidersHorizontal,
            iconColor: _kNavy,
            label: 'Total score',
            value: item.totalScore == null ? '—' : _fmtScore(item.totalScore!),
          ),
        ],
      ),
    );
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
  static String _fmtDate(DateTime d) =>
      '${_two(d.day)}/${_two(d.month)}/${d.year}  ${_two(d.hour)}:${_two(d.minute)}';
  static String _fmtScore(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _kMuted,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: valueColor ?? _kText,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Instruction card ─────────────────────────────────────────────────────────

class _InstructionCard extends StatelessWidget {
  final String text;

  const _InstructionCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _kBlue.withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.fileText,
                  size: 15,
                  color: _kBlue,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Instruction',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  color: _kNavy,
                  letterSpacing: -.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _kText,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section title ────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: _kNavy,
            letterSpacing: -.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: _kMuted,
          ),
        ),
      ],
    );
  }
}

// ── Sub-item card ────────────────────────────────────────────────────────────

class _SubItemCard extends StatelessWidget {
  final int index;
  final HomeworkSubItem sub;

  const _SubItemCard({required this.index, required this.sub});

  @override
  Widget build(BuildContext context) {
    final imageUrl = HomeworkService.resolveImageUrl(sub.imageUrl);

    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (imageUrl != null)
            _HomeworkQuestionImage(imageUrl: imageUrl, title: sub.title),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _kBlue.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$index',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          color: _kBlue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        sub.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: _kText,
                          letterSpacing: -.1,
                        ),
                      ),
                    ),
                    if (sub.score != null) ...[
                      const SizedBox(width: 8),
                      Builder(
                        builder: (_) {
                          final pillColor = _scoreColor(
                            sub.awardedScore,
                            sub.score,
                          );
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: pillColor.withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: pillColor.withValues(alpha: .22),
                              ),
                            ),
                            child: Text(
                              sub.awardedScore == null
                                  ? '${_fmtScore(sub.score!)} pts'
                                  : '${_fmtScore(sub.awardedScore!)} / ${_fmtScore(sub.score!)} pts',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                                color: pillColor,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
                if ((sub.instruction ?? '').isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    sub.instruction!,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: _kText,
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtScore(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

class _HomeworkQuestionImage extends StatelessWidget {
  const _HomeworkQuestionImage({required this.imageUrl, required this.title});

  final String imageUrl;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF1F4F8),
      child: InkWell(
        onTap: () => _showPreview(context),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Image.network(
              imageUrl,
              width: double.infinity,
              fit: BoxFit.fitWidth,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const SizedBox(
                  height: 220,
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: _kBlue,
                    ),
                  ),
                );
              },
              errorBuilder: (_, __, ___) => const SizedBox(
                height: 180,
                child: Center(
                  child: Icon(LucideIcons.imageOff, size: 32, color: _kMuted),
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.all(10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .62),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.zoomIn, size: 16, color: Colors.white),
                  SizedBox(width: 5),
                  Text(
                    'Preview',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPreview(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .9),
      builder: (dialogContext) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(LucideIcons.x),
                      color: Colors.white,
                    ),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => _saveImage(),
                      style: FilledButton.styleFrom(backgroundColor: _kBlue),
                      icon: const Icon(LucideIcons.download, size: 18),
                      label: const Text('Save'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: InteractiveViewer(
                  minScale: .5,
                  maxScale: 5,
                  child: Center(
                    child: Image.network(imageUrl, fit: BoxFit.contain),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveImage() async {
    GlobalAlert.showLoading(message: 'Saving image...');
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Could not download image (${response.statusCode}).');
      }

      final fileName = _downloadFileName(imageUrl);

      if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android) {
        final result = await ImageGallerySaverPlus.saveImage(
          response.bodyBytes,
          quality: 100,
          name: fileName.replaceFirst(RegExp(r'\.[^.]+$'), ''),
        );
        final saved = result is Map
            ? result['isSuccess'] == true || result['is_success'] == true
            : result != null;
        if (!saved) throw Exception('The image could not be saved.');
      } else {
        GlobalAlert.dismiss();
        final location = await getSaveLocation(
          suggestedName: fileName,
          acceptedTypeGroups: [
            XTypeGroup(label: 'Images', extensions: [_fileExtension(fileName)]),
          ],
        );
        if (location == null) return;

        await XFile.fromData(
          response.bodyBytes,
          name: fileName,
          mimeType: response.headers['content-type'] ?? 'image/jpeg',
        ).saveTo(location.path);
      }

      GlobalAlert.dismiss();
      GlobalAlert.showSuccess(
        title: 'Image saved',
        message:
            defaultTargetPlatform == TargetPlatform.iOS ||
                defaultTargetPlatform == TargetPlatform.android
            ? 'The homework image was saved to your gallery.'
            : 'The homework image was saved successfully.',
      );
    } catch (error) {
      GlobalAlert.dismiss();
      GlobalAlert.showError(
        title: 'Could not save image',
        message: error.toString(),
      );
    }
  }

  static String _downloadFileName(String url) {
    final rawName = Uri.tryParse(url)?.pathSegments.lastOrNull ?? '';
    if (rawName.contains('.')) return rawName;
    return 'homework_${DateTime.now().millisecondsSinceEpoch}.jpg';
  }

  static String _fileExtension(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return extension.isEmpty ? 'jpg' : extension;
  }
}
