import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../services/app_colors.dart';
import '../services/icon_utils.dart';

class SpeechTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final dynamic icon;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final bool enabled;
  final String? suffixText;

  const SpeechTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    required this.icon,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
    this.onChanged,
    this.enabled = true,
    this.suffixText,
  });

  @override
  State<SpeechTextField> createState() => _SpeechTextFieldState();
}

class _SpeechTextFieldState extends State<SpeechTextField> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    final bool available = await _speech.initialize(
      onError: (dynamic error) {
        debugPrint('Speech error: $error');
        if (mounted) setState(() => _isListening = false);
      },
      onStatus: (String status) {
        if ((status == 'done' || status == 'notListening') && mounted) {
          setState(() => _isListening = false);
        }
      },
    );
    if (mounted) setState(() => _speechAvailable = available);
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    if (!_speechAvailable) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: <Widget>[
              const Icon(Icons.mic_off_rounded, color: Colors.white),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'الإدخال الصوتي غير متاح. تأكد من منح صلاحية الميكروفون.',
                  style: GoogleFonts.cairo(),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (dynamic result) {
        if (!mounted || !result.finalResult) return;
        final String recognized = result.recognizedWords.toString().trim();
        if (recognized.isEmpty) return;

        final String previous = widget.controller.text.trim();
        widget.controller.text =
            previous.isEmpty ? recognized : '$previous $recognized';
        widget.controller.selection = TextSelection.fromPosition(
          TextPosition(offset: widget.controller.text.length),
        );
        widget.onChanged?.call(widget.controller.text);
        setState(() {});
      },
      localeId: 'ar-EG',
      listenMode: stt.ListenMode.dictation,
      cancelOnError: false,
      partialResults: true,
    );
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = AppColors.text(isDark);
    final Color secondaryColor = AppColors.textSecondary(isDark);
    final Color fillColor = _isListening
        ? Colors.red.withOpacity(isDark ? 0.10 : 0.06)
        : AppColors.inputFill(isDark);
    final Color borderColor = _isListening
        ? Colors.red.withOpacity(0.48)
        : AppColors.divider(isDark);

    final OutlineInputBorder border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: BorderSide(color: borderColor),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: widget.controller,
        enabled: widget.enabled,
        keyboardType: widget.keyboardType,
        validator: widget.validator,
        onChanged: widget.onChanged,
        maxLines: widget.maxLines,
        textInputAction: widget.maxLines > 1
            ? TextInputAction.newline
            : TextInputAction.next,
        style: GoogleFonts.cairo(color: textColor, fontSize: 13),
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: _isListening ? 'جاري الاستماع...' : widget.hint,
          labelStyle: GoogleFonts.cairo(
            color: secondaryColor,
            fontSize: 12,
          ),
          hintStyle: GoogleFonts.cairo(
            color: _isListening ? Colors.red.shade400 : AppColors.textHint(isDark),
            fontSize: 11.5,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(12),
            child: compatIcon(
              widget.icon,
              color: AppColors.goldDark,
              size: 19,
            ),
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (widget.suffixText != null)
                Padding(
                  padding: const EdgeInsets.only(right: 7),
                  child: Text(
                    widget.suffixText!,
                    style: GoogleFonts.cairo(
                      color: AppColors.goldDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              Tooltip(
                message: _isListening
                    ? 'إيقاف الاستماع'
                    : 'إدخال النص باستخدام الصوت',
                child: IconButton(
                  onPressed: widget.enabled ? _toggleListening : null,
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                      key: ValueKey<bool>(_isListening),
                      color: _isListening ? Colors.red : AppColors.goldDark,
                      size: 21,
                    ),
                  ),
                ),
              ),
            ],
          ),
          filled: true,
          fillColor: fillColor,
          contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: BorderSide(
              color: _isListening ? Colors.red : AppColors.gold,
              width: 1.5,
            ),
          ),
          errorBorder: border.copyWith(
            borderSide: BorderSide(color: Colors.red.shade500),
          ),
          focusedErrorBorder: border.copyWith(
            borderSide: BorderSide(color: Colors.red.shade500, width: 1.5),
          ),
          disabledBorder: border.copyWith(
            borderSide: BorderSide(
              color: AppColors.divider(isDark).withOpacity(0.55),
            ),
          ),
        ),
      ),
    );
  }
}
