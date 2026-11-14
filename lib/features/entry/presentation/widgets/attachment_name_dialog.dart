// Edit a user-facing attachment label without changing its physical filename

import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

Future<String?> showAttachmentNameDialog(
  BuildContext context, {
  required String name,
  required bool isPhoto,
}) => showDialog<String>(
  context: context,
  builder: (_) => _NameDialog(name: name, isPhoto: isPhoto),
);

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.name, required this.isPhoto});
  final String name;
  final bool isPhoto;
  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.name);
  final _formKey = GlobalKey<FormState>();
  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, _controller.text.trim());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(
      widget.isPhoto
          ? AppLocalizations.of(context)!.imageCaption
          : AppLocalizations.of(context)!.audioName,
    ),
    content: Form(
      key: _formKey,
      child: TextFormField(
        controller: _controller,
        autofocus: true,
        maxLength: 120,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          hintText: widget.isPhoto
              ? AppLocalizations.of(context)!.optionalCaption
              : AppLocalizations.of(context)!.audioName,
        ),
        validator: (value) => !widget.isPhoto && (value?.trim().isEmpty ?? true)
            ? AppLocalizations.of(context)!.enterAnAudioName
            : null,
        onFieldSubmitted: (_) => _submit(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(AppLocalizations.of(context)!.cancel),
      ),
      FilledButton(
        onPressed: _submit,
        child: Text(AppLocalizations.of(context)!.done),
      ),
    ],
  );
}
