import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class SpeechTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData icon;
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
    _speechAvailable = await _speech.initialize(
      onError: (error) {
        debugPrint('Speech error: $error');
        setState(() => _isListening = false);
      },
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
    );
    setState(() {});
  }

  void _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      if (_speechAvailable) {
        setState(() => _isListening = true);
        await _speech.listen(
          onResult: (result) {
            setState(() {
              // لو فيه نص قبل كده نضيف عليه
              if (widget.controller.text.isNotEmpty && result.finalResult) {
                widget.controller.text += ' ${result.recognizedWords}';
              } else if (result.finalResult) {
                widget.controller.text = result.recognizedWords;
              }
              
              // نحرك الـ cursor لآخر النص
              widget.controller.selection = TextSelection.fromPosition(
                TextPosition(offset: widget.controller.text.length),
              );
            });
          },
          localeId: 'ar-EG',
          listenMode: stt.ListenMode.dictation,
          cancelOnError: false,
          partialResults: true,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'المايك غير متاح - تأكد من إعطاء الصلاحيات',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: widget.controller,
        style: GoogleFonts.cairo(color: Colors.white),
        keyboardType: widget.keyboardType,
        validator: widget.validator,
        onChanged: widget.onChanged,
        maxLines: widget.maxLines,
        enabled: widget.enabled,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: _isListening ? '🎤 بتكلم...' : widget.hint,
          labelStyle: GoogleFonts.cairo(color: Colors.grey),
          hintStyle: GoogleFonts.cairo(
            color: _isListening ? Colors.red : Colors.grey[600],
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(12),
            child: FaIcon(widget.icon, color: Colors.grey, size: 18),
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.suffixText != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    widget.suffixText!,
                    style: GoogleFonts.cairo(color: Colors.grey),
                  ),
                ),
              // ✅ زرار المايك
              GestureDetector(
                onTap: widget.enabled ? _toggleListening : null,
                child: Container(
                  margin: const EdgeInsets.only(left: 8, right: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _isListening
                        ? Colors.red.withOpacity(0.2)
                        : const Color(0xFFFFD700).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isListening
                          ? Colors.red.withOpacity(0.5)
                          : const Color(0xFFFFD700).withOpacity(0.3),
                    ),
                  ),
                  child: FaIcon(
                    _isListening
                        ? FontAwesomeIcons.stop
                        : FontAwesomeIcons.microphone,
                    color: _isListening ? Colors.red : const Color(0xFFFFD700),
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          filled: true,
          fillColor: _isListening
              ? Colors.red.withOpacity(0.05)
              : Colors.white.withOpacity(0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: _isListening
                  ? Colors.red.withOpacity(0.5)
                  : Colors.white.withOpacity(0.1),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: _isListening ? Colors.red : const Color(0xFFFFD700),
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
          ),
        ),
      ),
    );
  }
}