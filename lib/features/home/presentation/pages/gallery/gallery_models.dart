import 'package:flutter/material.dart';
import '../../../../../core/theme/app_icons.dart';

enum GalleryTag { taskDone, event }

class GalleryItemModel {
  final String id;
  final String imageUrl; // online (unsplash)
  final GalleryTag tag;

  // ✅ NEW meta
  final String uploadedBy;
  final DateTime uploadedAt;

  // ✅ NEW content
  final String title;
  final String description;

  const GalleryItemModel({
    required this.id,
    required this.imageUrl,
    required this.tag,
    required this.uploadedBy,
    required this.uploadedAt,
    required this.title,
    required this.description,
  });
}

// ===== Helpers =====

String galleryTagText(GalleryTag tag) =>
    tag == GalleryTag.taskDone ? 'Task Done' : 'Event';

IconData galleryTagIcon(GalleryTag tag) => tag == GalleryTag.taskDone
    ? LucideIcons.circleCheck
    : LucideIcons.calendarDays;

String two(int n) => n.toString().padLeft(2, '0');

String fmtDateTime(DateTime d) =>
    '${two(d.day)}/${two(d.month)}/${d.year} • ${two(d.hour)}:${two(d.minute)}';
