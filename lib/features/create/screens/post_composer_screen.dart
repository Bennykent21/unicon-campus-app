import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/create_provider.dart';

class PostComposerScreen extends ConsumerStatefulWidget {
  final String postType;
  const PostComposerScreen({super.key, required this.postType});

  @override
  ConsumerState<PostComposerScreen> createState() => _PostComposerScreenState();
}

class _PostComposerScreenState extends ConsumerState<PostComposerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _tagsController = TextEditingController();
  final _priceController = TextEditingController();
  final _jobLocationController = TextEditingController();
  final _salaryController = TextEditingController();
  final _eventLocationController = TextEditingController();

  bool _isInternship = false;
  DateTime? _eventDate;
  TimeOfDay? _eventTime;
  List<File> _pickedImages = [];

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _tagsController.dispose();
    _priceController.dispose();
    _jobLocationController.dispose();
    _salaryController.dispose();
    _eventLocationController.dispose();
    super.dispose();
  }

  String get _title => switch (widget.postType) {
        'question' => 'Ask a Question',
        'marketplace' => 'List an Item',
        'job' => 'Post a Job',
        'event' => 'Create an Event',
        'announcement' => 'Share Announcement',
        _ => 'Create Post',
      };

  String get _titleHint => switch (widget.postType) {
        'question' => 'What do you need help with?',
        'marketplace' => 'Item name',
        'job' => 'Job title',
        'event' => 'Event name',
        'announcement' => 'Announcement title',
        _ => 'Title',
      };

  String get _bodyHint => switch (widget.postType) {
        'question' => 'Describe your problem in detail...',
        'marketplace' => 'Describe the item, condition, etc.',
        'job' => 'Job description, requirements, how to apply...',
        'event' => 'What\'s happening, who should attend...',
        'announcement' => 'Write your announcement...',
        _ => 'What\'s on your mind?',
      };

  Color get _accentColor => switch (widget.postType) {
        'question' => const Color(0xFF3B82F6),
        'marketplace' => AppColors.marketplace,
        'job' => AppColors.job,
        'event' => AppColors.event,
        'announcement' => const Color(0xFFA855F7),
        _ => AppColors.primary,
      };

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 80);
    if (picked.isNotEmpty) {
      setState(() => _pickedImages = picked.map((x) => File(x.path)).toList());
    }
  }

  List<String> get _parsedTags => _tagsController.text
      .split(RegExp(r'[,\s]+'))
      .map((t) => t.trim().replaceAll('#', ''))
      .where((t) => t.isNotEmpty)
      .toList();

  /// Combines the picked date + time into a single DateTime.
  /// Defaults to midnight if no time was picked (keeps old behavior for
  /// anyone who only sets a date).
  DateTime? get _combinedEventDateTime {
    if (_eventDate == null) return null;
    final time = _eventTime ?? const TimeOfDay(hour: 0, minute: 0);
    return DateTime(
      _eventDate!.year,
      _eventDate!.month,
      _eventDate!.day,
      time.hour,
      time.minute,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final postId = await ref.read(createPostProvider.notifier).submit(
          type: widget.postType == 'announcement' ? 'general' : widget.postType,
          title: _titleController.text,
          body: _bodyController.text,
          tags: _parsedTags,
          images: _pickedImages,
          price: widget.postType == 'marketplace' &&
                  _priceController.text.isNotEmpty
              ? double.tryParse(_priceController.text)
              : null,
          jobLocation: widget.postType == 'job'
              ? _jobLocationController.text.trim()
              : null,
          isInternship: widget.postType == 'job' ? _isInternship : null,
          salary:
              widget.postType == 'job' ? _salaryController.text.trim() : null,
          eventDate: widget.postType == 'event' ? _combinedEventDateTime : null,
          eventLocation: widget.postType == 'event'
              ? _eventLocationController.text.trim()
              : null,
        );

    if (postId != null && mounted) {
      context.go('/home');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Posted successfully!')),
      );
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _eventDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _eventTime ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _eventTime = picked);
  }

  String _formatTime(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final createState = ref.watch(createPostProvider);
    final isLoading = createState.status == CreateStatus.loading;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: isLoading ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: _accentColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Post',
                      style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration:
                    InputDecoration(hintText: _titleHint, labelText: 'Title'),
                maxLines: 2,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Title is required'
                    : null,
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _bodyController,
                decoration:
                    InputDecoration(hintText: _bodyHint, labelText: 'Details'),
                maxLines: 6,
                validator: (v) {
                  if (widget.postType == 'question' &&
                      (v == null || v.trim().isEmpty)) {
                    return 'Please describe your question';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // ── Marketplace fields ──
              if (widget.postType == 'marketplace') ...[
                TextFormField(
                  controller: _priceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Price (₦)', prefixText: '₦ '),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter a price' : null,
                ),
                const SizedBox(height: 14),
              ],

              // ── Job fields ──
              if (widget.postType == 'job') ...[
                TextFormField(
                  controller: _jobLocationController,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _salaryController,
                  decoration: const InputDecoration(
                    labelText: 'Salary (optional)',
                    hintText: 'e.g. ₦150,000/month, Negotiable',
                    prefixIcon: Icon(Icons.payments_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 10),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('This is an internship',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  value: _isInternship,
                  activeThumbColor: AppColors.job,
                  onChanged: (v) => setState(() => _isInternship = v),
                ),
                const SizedBox(height: 4),
              ],

              // ── Event fields ──
              if (widget.postType == 'event') ...[
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _pickDate,
                        child: AbsorbPointer(
                          child: TextFormField(
                            decoration: InputDecoration(
                              labelText: 'Date',
                              hintText: _eventDate == null
                                  ? 'Pick a date'
                                  : '${_eventDate!.day}/${_eventDate!.month}/${_eventDate!.year}',
                              prefixIcon:
                                  const Icon(Icons.calendar_today, size: 20),
                            ),
                            controller: TextEditingController(
                              text: _eventDate == null
                                  ? ''
                                  : '${_eventDate!.day}/${_eventDate!.month}/${_eventDate!.year}',
                            ),
                            validator: (_) =>
                                _eventDate == null ? 'Pick a date' : null,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: _pickTime,
                        child: AbsorbPointer(
                          child: TextFormField(
                            decoration: InputDecoration(
                              labelText: 'Time',
                              hintText: _eventTime == null
                                  ? 'Pick a time'
                                  : _formatTime(_eventTime!),
                              prefixIcon:
                                  const Icon(Icons.access_time, size: 20),
                            ),
                            controller: TextEditingController(
                              text: _eventTime == null
                                  ? ''
                                  : _formatTime(_eventTime!),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _eventLocationController,
                  decoration: const InputDecoration(
                    labelText: 'Venue / Location',
                    prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Tags
              TextFormField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  labelText: 'Tags (optional)',
                  hintText: 'Flutter, JWT, Backend...',
                  prefixIcon: Icon(Icons.tag, size: 20),
                ),
              ),
              const SizedBox(height: 4),
              Text('Separate tags with commas or spaces',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),

              // ── Image picker — now available for EVERY post type ──
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _pickImages,
                icon: const Icon(Icons.image_outlined),
                label: Text(
                    _pickedImages.isEmpty ? 'Add Photos' : 'Change Photos'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: _accentColor),
                  foregroundColor: _accentColor,
                ),
              ),
              if (_pickedImages.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 90,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _pickedImages.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) => Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(_pickedImages[i],
                              width: 90, height: 90, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _pickedImages.removeAt(i)),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.close,
                                  size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              if (createState.status == CreateStatus.error) ...[
                const SizedBox(height: 12),
                Text(
                  createState.errorMessage ??
                      'Something went wrong. Try again.',
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ],

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
